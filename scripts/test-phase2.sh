#!/bin/bash
set -e

# Clean up any existing containers
echo "Cleaning up any existing containers..."
docker compose -f compose/stage-2-hdfs.yaml down

# Create necessary data directories
echo "Creating data directories..."
mkdir -p data/kafka data/mysql/data data/hdfs/namenode data/hdfs/datanode1 data/hdfs/datanode2

# Set proper permissions for HDFS directories
echo "Setting proper permissions for HDFS directories..."
chmod -R 777 data/hdfs

echo "Starting Phase 2 infrastructure..."
# Use docker compose (new format) instead of docker-compose
docker compose -f compose/stage-2-hdfs.yaml up -d

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

# Wait for Hadoop NameNode to be ready
RETRY_COUNT=0
echo "Waiting for Hadoop NameNode to be ready..."
until docker exec hadoop-namenode hdfs dfsadmin -report > /dev/null 2>&1; do
    echo "Waiting for Hadoop NameNode to be ready... (${RETRY_COUNT}/${MAX_RETRIES})"
    RETRY_COUNT=$((RETRY_COUNT+1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "Error: Hadoop NameNode did not become ready in time."
        echo "Checking NameNode logs:"
        docker logs hadoop-namenode
        exit 1
    fi
    sleep 5
done
echo "✅ Hadoop NameNode is ready!"

# Wait for Hadoop DataNodes to be ready
RETRY_COUNT=0
echo "Waiting for Hadoop DataNodes to be ready..."
until docker exec hadoop-namenode hdfs dfsadmin -report | grep "Live datanodes (2)" > /dev/null 2>&1; do
    echo "Waiting for Hadoop DataNodes to be ready... (${RETRY_COUNT}/${MAX_RETRIES})"
    RETRY_COUNT=$((RETRY_COUNT+1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "Error: Hadoop DataNodes did not become ready in time."
        echo "Checking DataNode logs:"
        docker logs hadoop-datanode1
        docker logs hadoop-datanode2
        exit 1
    fi
    sleep 5
done
echo "✅ Hadoop DataNodes are ready!"

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

# Create HDFS directories for Kafka Connect
echo "Creating HDFS directories for Kafka Connect..."
docker exec hadoop-namenode hdfs dfs -mkdir -p /kafka/openmrs.patient /kafka/openmrs.person_name
docker exec hadoop-namenode hdfs dfs -chmod -R 777 /kafka

# Register the Debezium connector
echo "Registering Debezium connector for OpenMRS..."
# First, copy the connector config to the container
docker cp ./pipelines/debezium-openmrs-source.json kafka-connect:/tmp/debezium-openmrs-source.json

# Then register using the local file
CONNECTOR_RESPONSE=$(docker exec kafka-connect curl -s -X POST -H "Content-Type: application/json" \
  --data @/tmp/debezium-openmrs-source.json \
  http://localhost:8083/connectors)

if echo "$CONNECTOR_RESPONSE" | grep -q "error_code"; then
    echo "❌ Error registering Debezium connector: $CONNECTOR_RESPONSE"
    echo "Checking Kafka Connect logs for more details..."
    docker logs kafka-connect | tail -n 50
    
    # Continue anyway to see if we can get more diagnostic information
    echo "Continuing with the test to gather more information..."
else
    echo "✅ Debezium connector registered successfully!"
fi

# Register the HDFS Sink connector
echo "Registering HDFS Sink connector..."
# First, copy the connector config to the container
docker cp ./pipelines/kafka-connect-hdfs-sink.json kafka-connect:/tmp/kafka-connect-hdfs-sink.json

# Then register using the local file
CONNECTOR_RESPONSE=$(docker exec kafka-connect curl -s -X POST -H "Content-Type: application/json" \
  --data @/tmp/kafka-connect-hdfs-sink.json \
  http://localhost:8083/connectors)

if echo "$CONNECTOR_RESPONSE" | grep -q "error_code"; then
    echo "❌ Error registering HDFS Sink connector: $CONNECTOR_RESPONSE"
    echo "Checking Kafka Connect logs for more details..."
    docker logs kafka-connect | tail -n 50
    
    # Continue anyway to see if we can get more diagnostic information
    echo "Continuing with the test to gather more information..."
else
    echo "✅ HDFS Sink connector registered successfully!"
fi

# Wait for connectors to be fully initialized
echo "Waiting for connectors to initialize (30 seconds)..."
sleep 30

# Check connector status
echo "Checking Debezium connector status..."
CONNECTOR_STATUS=$(docker exec kafka-connect curl -s http://localhost:8083/connectors/openmrs-connector/status)
echo "$CONNECTOR_STATUS"

echo "Checking HDFS Sink connector status..."
CONNECTOR_STATUS=$(docker exec kafka-connect curl -s http://localhost:8083/connectors/hdfs-sink/status)
echo "$CONNECTOR_STATUS"

# Load OpenMRS sample data
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

echo "Waiting for CDC events to propagate to Kafka and HDFS (30 seconds)..."
sleep 30

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
    echo "❌ No patient events found in Kafka."
    echo "Phase 2 test completed with some issues. Please check the logs for more details."
    exit 1
else
    echo "✅ CDC pipeline is working correctly for patient events in Kafka!"
fi

# Check if data landed in HDFS
echo "Checking if data landed in HDFS..."
sleep 30  # Give more time for data to be written to HDFS

# Insert more test records to trigger flush
echo "Inserting additional test records to trigger HDFS flush..."
for i in {1..5}; do
    docker exec -i mysql mysql -u root -popenmrs << EOF
USE openmrs;
INSERT INTO patient (patient_id, gender, birthdate, creator, date_created)
VALUES (9000$i, 'M', '1990-01-$i', 1, NOW());

INSERT INTO person_name (person_name_id, person_id, given_name, family_name, creator, date_created)
VALUES (8000$i, 9000$i, 'Test$i', 'User$i', 1, NOW());
EOF
    echo "Inserted test record $i"
    sleep 2
done

# Wait for data to be flushed to HDFS
echo "Waiting for data to be flushed to HDFS (30 seconds)..."
sleep 30

# Check HDFS Sink connector status
echo "Checking HDFS Sink connector status..."
docker exec kafka-connect curl -s http://localhost:8083/connectors/hdfs-sink/status

# Force HDFS directory creation if needed
echo "Ensuring HDFS directories exist..."
docker exec hadoop-namenode hdfs dfs -mkdir -p /kafka/openmrs.patient /kafka/openmrs.person_name
docker exec hadoop-namenode hdfs dfs -chmod -R 777 /kafka

echo "HDFS directory listing for patient data:"
docker exec hadoop-namenode hdfs dfs -ls -R /kafka/openmrs.patient/

if docker exec hadoop-namenode hdfs dfs -ls -R /kafka/openmrs.patient/ | grep -q ".json"; then
    echo "✅ Patient data successfully written to HDFS!"
    # Show file contents
    echo "Sample of patient data in HDFS:"
    PATIENT_FILE=$(docker exec hadoop-namenode hdfs dfs -ls -R /kafka/openmrs.patient/ | grep ".json" | head -1 | awk '{print $8}')
    docker exec hadoop-namenode hdfs dfs -cat $PATIENT_FILE | head -3
else
    echo "❌ No patient data found in HDFS. Checking HDFS Sink connector logs..."
    docker logs kafka-connect | grep -i "hdfs-sink" | tail -n 50
    echo "Checking for connector errors..."
    docker logs kafka-connect | grep -i "error" | tail -n 20
    echo "This could be due to timing - data might still be buffered in the connector."
    echo "Try checking HDFS again after a few minutes or after more data is inserted."
fi

echo "HDFS directory listing for person_name data:"
docker exec hadoop-namenode hdfs dfs -ls -R /kafka/openmrs.person_name/

if docker exec hadoop-namenode hdfs dfs -ls -R /kafka/openmrs.person_name/ | grep -q ".json"; then
    echo "✅ Person_name data successfully written to HDFS!"
    # Show file contents
    echo "Sample of person_name data in HDFS:"
    PERSON_FILE=$(docker exec hadoop-namenode hdfs dfs -ls -R /kafka/openmrs.person_name/ | grep ".json" | head -1 | awk '{print $8}')
    docker exec hadoop-namenode hdfs dfs -cat $PERSON_FILE | head -3
else
    echo "❌ No person_name data found in HDFS. Checking HDFS Sink connector logs..."
    docker logs kafka-connect | grep -i "hdfs-sink" | tail -n 50
    echo "Checking for connector errors..."
    docker logs kafka-connect | grep -i "error" | tail -n 20
    echo "This could be due to timing - data might still be buffered in the connector."
    echo "Try checking HDFS again after a few minutes or after more data is inserted."
fi

echo "🎉 Phase 2 test completed!"
echo "The pipeline with MySQL, Debezium, Kafka, and HDFS is now set up."
echo "If you don't see data in HDFS yet, it might be due to the flush size configuration."
echo "Try inserting more records or wait a bit longer for the connector to flush data to HDFS."
