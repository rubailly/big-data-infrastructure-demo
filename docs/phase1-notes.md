# Phase 1: MySQL + Debezium + Kafka - Implementation Notes

This document contains important notes and troubleshooting tips for Phase 1 of the big data infrastructure project.

## Architecture

Phase 1 implements a Change Data Capture (CDC) pipeline with:

- **MySQL**: Source database with OpenMRS schema
- **Debezium**: CDC connector that monitors MySQL binary logs
- **Kafka Connect**: Framework that runs the Debezium connector
- **Kafka**: Message broker that stores the CDC events
- **Zookeeper**: Required for Kafka coordination

## Key Configuration Points

### MySQL Configuration

MySQL must be configured with binary logging enabled for CDC to work:

```
binlog_format=ROW
binlog_row_image=FULL
```

### Debezium Connector Configuration

Critical settings in the Debezium connector configuration:

- `schema.history.internal.kafka.bootstrap.servers`: Kafka connection for schema history
- `schema.history.internal.kafka.topic`: Topic to store schema changes
- `database.allowPublicKeyRetrieval`: Must be set to "true" for MySQL 8+
- `snapshot.mode`: Controls how initial data is captured
- `snapshot.locking.mode`: Controls table locking during snapshot

## Troubleshooting

Common issues encountered during Phase 1 implementation:

1. **Connector Registration Failures**:
   - Check Kafka Connect logs for detailed error messages
   - Verify MySQL is accessible from the Kafka Connect container
   - Ensure all required configuration parameters are present

2. **MySQL Connection Issues**:
   - "Public Key Retrieval is not allowed" - Add `database.allowPublicKeyRetrieval=true`
   - Verify MySQL user has proper permissions

3. **No CDC Events in Kafka**:
   - Check if connector is in RUNNING state
   - Verify binary logging is enabled in MySQL
   - Check if the table is included in the connector configuration

4. **Container Startup Issues**:
   - Ensure proper dependencies between containers
   - Add healthchecks to ensure services are ready before dependent services start

## Verification

To verify Phase 1 is working correctly:

1. Run the test script: `./scripts/test-phase1.sh`
2. Check for CDC events in Kafka topics:
   ```bash
   docker exec kafka-broker kafka-console-consumer \
     --bootstrap-server localhost:9092 \
     --topic dbserver1.openmrs.patient \
     --from-beginning
   ```

## Next Steps

✅ Phase 1 is complete! Proceed to Phase 2 to add Hadoop HDFS for storing the CDC events.
