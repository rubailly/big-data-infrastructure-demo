#!/bin/bash
set -e

echo "Starting Phase 1 infrastructure..."
docker-compose -f compose/stage-1-minimal.yaml up -d

echo "Waiting for services to initialize..."
echo "This may take a minute or two..."

# Wait for MySQL to be ready
until docker exec mysql mysqladmin ping -h localhost -u root -popenmrs --silent; do
    echo "Waiting for MySQL to be ready..."
    sleep 5
done
echo "MySQL is ready!"

# Wait for Kafka Connect to be ready
until docker exec kafka-connect curl -s http://localhost:8083/ > /dev/null; do
    echo "Waiting for Kafka Connect to be ready..."
    sleep 5
done
echo "Kafka Connect is ready!"

# Register the Debezium connector
echo "Registering Debezium connector for OpenMRS..."
docker exec kafka-connect curl -X POST -H "Content-Type: application/json" \
  --data @/kafka-connect-configs/debezium-openmrs-source.json \
  http://localhost:8083/connectors

# Wait for connector to be fully initialized
sleep 10

echo "Loading OpenMRS sample data..."
docker exec -i mysql mysql -u root -popenmrs openmrs < ./data/openmrs_sample_dump.sql

echo "Inserting a test patient record..."
docker exec -i mysql mysql -u root -popenmrs << EOF
USE openmrs;
INSERT INTO patient (patient_id, gender, birthdate, creator, date_created)
VALUES (90001, 'F', '1987-05-12', 1, NOW());

INSERT INTO person_name (person_name_id, person_id, given_name, family_name, creator, date_created)
VALUES (80001, 90001, 'Amina', 'Tshisekedi', 1, NOW());
EOF

echo "Waiting for CDC events to propagate to Kafka (10 seconds)..."
sleep 10

echo "Checking Kafka for CDC events..."
docker exec kafka-broker kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic dbserver1.openmrs.patient \
  --from-beginning \
  --max-messages 1 \
  --timeout-ms 10000

echo "Checking Kafka for person_name CDC events..."
docker exec kafka-broker kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic dbserver1.openmrs.person_name \
  --from-beginning \
  --max-messages 1 \
  --timeout-ms 10000

echo "Phase 1 test completed successfully!"
echo "The minimal pipeline with MySQL, Debezium, and Kafka is now working."
