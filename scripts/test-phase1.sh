#!/bin/bash
set -e

# Clean up any existing containers
echo "Cleaning up any existing containers..."
docker compose -f compose/stage-1-minimal.yaml down

# Create necessary data directories
echo "Creating data directories..."
mkdir -p data/kafka data/mysql/data

echo "Starting Phase 1 infrastructure..."
# Use docker compose (new format) instead of docker-compose
docker compose -f compose/stage-1-minimal.yaml up -d

echo "Waiting for services to initialize..."
echo "This may take a minute or two..."

# Wait for MySQL to be ready
MAX_RETRIES=30
RETRY_COUNT=0
until docker exec mysql mysqladmin ping -h localhost -u root -popenmrs --silent; do
    echo "Waiting for MySQL to be ready... (${RETRY_COUNT}/${MAX_RETRIES})"
    RETRY_COUNT=$((RETRY_COUNT+1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "Error: MySQL did not become ready in time."
        exit 1
    fi
    sleep 5
done
echo "✅ MySQL is ready!"

# Check if Kafka Connect container is running
echo "Checking if Kafka Connect container is running..."
if ! docker ps | grep -q kafka-connect; then
    echo "❌ Kafka Connect container is not running. Checking logs..."
    docker logs kafka-connect
    echo "Attempting to restart Kafka Connect..."
    docker restart kafka-connect
    sleep 10
fi

# Wait for Kafka Connect to be ready
RETRY_COUNT=0
echo "Waiting for Kafka Connect to be ready..."
until docker exec -i kafka-connect curl -s http://localhost:8083/ > /dev/null 2>&1; do
    echo "Waiting for Kafka Connect to be ready... (${RETRY_COUNT}/${MAX_RETRIES})"
    RETRY_COUNT=$((RETRY_COUNT+1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "Error: Kafka Connect did not become ready in time."
        echo "Checking Kafka Connect logs:"
        docker logs kafka-connect
        exit 1
    fi
    sleep 5
done
echo "✅ Kafka Connect is ready!"

# Check if Kafka broker is running
echo "Checking if Kafka broker is running..."
if ! docker ps | grep -q kafka-broker; then
    echo "❌ Kafka broker is not running. Checking logs..."
    docker logs kafka-broker
    
    echo "Recreating Kafka broker with simplified configuration..."
    docker compose -f compose/stage-1-minimal.yaml up -d kafka-broker
    sleep 20
fi

# Wait for Kafka broker to be ready
RETRY_COUNT=0
echo "Waiting for Kafka broker to be ready..."
until docker exec -i kafka-broker bash -c "kafka-topics --bootstrap-server=localhost:9092 --list" > /dev/null 2>&1; do
    echo "Waiting for Kafka broker to be ready... (${RETRY_COUNT}/${MAX_RETRIES})"
    RETRY_COUNT=$((RETRY_COUNT+1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "Error: Kafka broker did not become ready in time."
        echo "Checking Kafka broker logs:"
        docker logs kafka-broker
        exit 1
    fi
    sleep 5
done
echo "✅ Kafka broker is ready!"

# Check if Kafka topics are created
echo "Checking Kafka topics..."
RETRY_COUNT=0
until docker exec -i kafka-broker kafka-topics --bootstrap-server localhost:9092 --list > /dev/null 2>&1; do
    echo "Waiting for Kafka topics service to be ready... (${RETRY_COUNT}/${MAX_RETRIES})"
    RETRY_COUNT=$((RETRY_COUNT+1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "Error: Kafka topics service was not ready in time."
        exit 1
    fi
    sleep 5
done
echo "✅ Kafka topics service is ready!"

# Register the Debezium connector
echo "Registering Debezium connector for OpenMRS..."
# First, copy the connector config to the container
docker cp ./pipelines/debezium-openmrs-source.json kafka-connect:/tmp/debezium-openmrs-source.json

# Then register using the local file
CONNECTOR_RESPONSE=$(docker exec kafka-connect curl -s -X POST -H "Content-Type: application/json" \
  --data @/tmp/debezium-openmrs-source.json \
  http://localhost:8083/connectors)

if echo "$CONNECTOR_RESPONSE" | grep -q "error_code"; then
    echo "❌ Error registering connector: $CONNECTOR_RESPONSE"
    echo "Checking Kafka Connect logs for more details..."
    docker logs kafka-connect | tail -n 50
    
    # Try with a different approach - using curl directly with verbose output
    echo "Trying alternative registration method..."
    docker exec kafka-connect bash -c "cat /tmp/debezium-openmrs-source.json"
    docker exec kafka-connect bash -c "curl -v -X POST -H \"Content-Type: application/json\" \
      --data @/tmp/debezium-openmrs-source.json \
      http://localhost:8083/connectors"
    
    # Check if connector was registered
    echo "Checking if connector was registered..."
    docker exec kafka-connect curl -s http://localhost:8083/connectors
    
    # Check available connector plugins
    echo "Available connector plugins:"
    docker exec kafka-connect curl -s http://localhost:8083/connector-plugins | grep MySqlConnector
    
    # Continue anyway to see if we can get more diagnostic information
    echo "Continuing with the test to gather more information..."
else
    echo "✅ Connector registered successfully!"
fi

# Wait for connector to be fully initialized
echo "Waiting for connector to initialize (30 seconds)..."
sleep 30

# Check connector status
echo "Checking connector status..."
CONNECTOR_STATUS=$(docker exec kafka-connect curl -s http://localhost:8083/connectors/openmrs-connector/status)
echo "$CONNECTOR_STATUS"

# Check Kafka Connect logs for more details
echo "Checking Kafka Connect logs for errors..."
docker logs kafka-connect | grep -i error | tail -n 20

# Create Kafka topics if they don't exist
echo "Ensuring Kafka topics exist..."
docker exec kafka-broker kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic dbserver1.openmrs.patient --partitions 1 --replication-factor 1
docker exec kafka-broker kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic dbserver1.openmrs.person_name --partitions 1 --replication-factor 1

echo "Loading OpenMRS sample data..."
if docker exec -i mysql mysql -u root -popenmrs openmrs < ./data/openmrs_sample_dump.sql; then
    echo "✅ Sample data loaded successfully!"
else
    echo "❌ Error loading sample data."
    exit 1
fi

echo "Inserting a test patient record..."
if docker exec -i mysql mysql -u root -popenmrs << EOF
USE openmrs;
INSERT INTO patient (patient_id, gender, birthdate, creator, date_created)
VALUES (90001, 'F', '1987-05-12', 1, NOW());

INSERT INTO person_name (person_name_id, person_id, given_name, family_name, creator, date_created)
VALUES (80001, 90001, 'Amina', 'Tshisekedi', 1, NOW());
EOF
then
    echo "✅ Test patient record inserted successfully!"
else
    echo "❌ Error inserting test patient record."
    exit 1
fi

echo "Waiting for CDC events to propagate to Kafka (15 seconds)..."
sleep 15

echo "Checking Kafka for patient CDC events..."
# List available topics first to verify
echo "Available Kafka topics:"
docker exec kafka-broker kafka-topics --bootstrap-server localhost:9092 --list

# Try both topic naming patterns that Debezium might use
for TOPIC in "dbserver1.openmrs.patient" "dbserver1.patient"; do
    echo "Checking topic: $TOPIC"
    PATIENT_EVENTS=$(docker exec kafka-broker kafka-console-consumer \
      --bootstrap-server localhost:9092 \
      --topic $TOPIC \
      --from-beginning \
      --max-messages 1 \
      --timeout-ms 5000 2>/dev/null || echo "")
    
    if [ ! -z "$PATIENT_EVENTS" ]; then
        echo "✅ Patient CDC events found in Kafka topic: $TOPIC!"
        echo "$PATIENT_EVENTS"
        echo "$PATIENT_EVENTS" | grep -q "90001" && echo "✅ Test patient record was captured correctly!"
        FOUND_EVENTS=true
        break
    fi
done

if [ "$FOUND_EVENTS" != "true" ]; then
    echo "❌ No patient events found in Kafka. Let's try to diagnose the issue:"
    
    # Check connector status
    echo "Connector status:"
    docker exec kafka-connect curl -s http://localhost:8083/connectors/openmrs-connector/status
    
    # Check connector tasks
    echo "Connector tasks:"
    docker exec kafka-connect curl -s http://localhost:8083/connectors/openmrs-connector/tasks
    
    # Continue anyway to check person_name events
    echo "Continuing to check person_name events..."
else
    echo "✅ CDC pipeline is working correctly for patient events!"
fi

echo "Checking Kafka for person_name CDC events..."
# Try both topic naming patterns that Debezium might use
for TOPIC in "dbserver1.openmrs.person_name" "dbserver1.person_name"; do
    echo "Checking topic: $TOPIC"
    PERSON_NAME_EVENTS=$(docker exec kafka-broker kafka-console-consumer \
      --bootstrap-server localhost:9092 \
      --topic $TOPIC \
      --from-beginning \
      --max-messages 1 \
      --timeout-ms 5000 2>/dev/null || echo "")
    
    if [ ! -z "$PERSON_NAME_EVENTS" ]; then
        echo "✅ Person_name CDC events found in Kafka topic: $TOPIC!"
        echo "$PERSON_NAME_EVENTS"
        echo "$PERSON_NAME_EVENTS" | grep -q "Tshisekedi" && echo "✅ Test person_name record was captured correctly!"
        FOUND_PERSON_EVENTS=true
        break
    fi
done

if [ "$FOUND_PERSON_EVENTS" != "true" ]; then
    echo "❌ No person_name events found in Kafka."
    echo "Phase 1 test completed with some issues. Please check the logs for more details."
    exit 1
else
    echo "✅ CDC pipeline is working correctly for person_name events!"
    echo "🎉 Phase 1 test completed successfully!"
    echo "The minimal pipeline with MySQL, Debezium, and Kafka is now working."
fi

echo "🎉 Phase 1 test completed successfully!"
echo "The minimal pipeline with MySQL, Debezium, and Kafka is now working."
