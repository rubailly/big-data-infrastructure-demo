#!/bin/bash
set -e

# Wait for Kafka Connect to be ready
until curl -s http://kafka-connect:8083/ > /dev/null; do
    echo "Waiting for Kafka Connect to be ready..."
    sleep 5
done

# Register the OpenMRS connector
echo "Registering OpenMRS connector..."
curl -X POST -H "Content-Type: application/json" --data @/kafka-connect-configs/debezium-openmrs-source.json http://kafka-connect:8083/connectors

echo "Connector registration completed!"
