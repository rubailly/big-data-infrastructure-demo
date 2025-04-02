#!/bin/bash
set -e

echo "Starting Phase 1 infrastructure..."
docker-compose -f compose/stage-1-minimal.yaml up -d

echo "Waiting for services to initialize (60 seconds)..."
sleep 60

echo "Loading OpenMRS sample data..."
docker cp ./data/openmrs_sample_dump.sql mysql:/openmrs.sql
docker exec -i mysql sh -c 'exec mysql -u root -p$MYSQL_ROOT_PASSWORD openmrs' < ./data/openmrs_sample_dump.sql

echo "Inserting a test patient record..."
docker exec -i mysql mysql -u root -popenmrs << EOF
USE openmrs;
INSERT INTO patient (patient_id, gender, birthdate, creator, date_created)
VALUES (90001, 'F', '1987-05-12', 1, NOW());

INSERT INTO person_name (person_name_id, person_id, given_name, family_name, creator, date_created)
VALUES (80001, 90001, 'Amina', 'Tshisekedi', 1, NOW());
EOF

echo "Checking Kafka for CDC events..."
docker exec -it kafka-broker kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic dbserver1.openmrs.patient \
  --from-beginning \
  --max-messages 1

echo "Phase 1 test completed!"
