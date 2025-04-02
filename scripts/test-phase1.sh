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
echo "Waiting for connector to initialize (15 seconds)..."
sleep 15

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
PATIENT_EVENTS=$(docker exec kafka-broker kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic dbserver1.openmrs.patient \
  --from-beginning \
  --max-messages 1 \
  --timeout-ms 15000 2>/dev/null || echo "ERROR")

if [ "$PATIENT_EVENTS" = "ERROR" ] || [ -z "$PATIENT_EVENTS" ]; then
    echo "❌ No patient events found in Kafka. CDC pipeline may not be working correctly."
    exit 1
else
    echo "✅ Patient CDC events found in Kafka!"
    echo "$PATIENT_EVENTS" | grep -q "90001" && echo "✅ Test patient record was captured correctly!"
fi

echo "Checking Kafka for person_name CDC events..."
PERSON_NAME_EVENTS=$(docker exec kafka-broker kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic dbserver1.openmrs.person_name \
  --from-beginning \
  --max-messages 1 \
  --timeout-ms 15000 2>/dev/null || echo "ERROR")

if [ "$PERSON_NAME_EVENTS" = "ERROR" ] || [ -z "$PERSON_NAME_EVENTS" ]; then
    echo "❌ No person_name events found in Kafka. CDC pipeline may not be working correctly."
    exit 1
else
    echo "✅ Person_name CDC events found in Kafka!"
    echo "$PERSON_NAME_EVENTS" | grep -q "Tshisekedi" && echo "✅ Test person_name record was captured correctly!"
fi

echo "🎉 Phase 1 test completed successfully!"
echo "The minimal pipeline with MySQL, Debezium, and Kafka is now working."
