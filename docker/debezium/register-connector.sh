#!/bin/bash
set -e

# Wait for Kafka Connect to be ready
until curl -s http://kafka-connect:8083/ > /dev/null; do
    echo "Waiting for Kafka Connect to be ready..."
    sleep 5
done

# Check if connector already exists
CONNECTOR_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://kafka-connect:8083/connectors/openmrs-connector)

if [ "$CONNECTOR_STATUS" == "200" ]; then
    echo "OpenMRS connector already exists. Skipping registration."
else
    # Register the OpenMRS connector
    echo "Registering OpenMRS connector..."
    curl -X POST -H "Content-Type: application/json" --data @/kafka-connect-configs/debezium-openmrs-source.json http://kafka-connect:8083/connectors
    
    if [ $? -eq 0 ]; then
        echo "Connector registration completed successfully!"
    else
        echo "Failed to register connector. Check Kafka Connect logs for details."
        exit 1
    fi
fi
