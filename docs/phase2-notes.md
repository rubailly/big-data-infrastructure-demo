# Phase 2: Hadoop HDFS Integration - Implementation Notes

This document contains important notes and troubleshooting tips for Phase 2 of the big data infrastructure project.

## Architecture

Phase 2 extends the CDC pipeline with Hadoop HDFS:

- **MySQL + Debezium + Kafka**: (from Phase 1) Captures database changes
- **Hadoop HDFS**: Distributed file system for storing CDC events
- **Kafka Connect HDFS Sink**: Connector that streams data from Kafka to HDFS
- **NameNode**: Manages the HDFS namespace and regulates access to files
- **DataNodes**: Store and retrieve blocks as directed by the NameNode

## Key Configuration Points

### Hadoop Configuration

Important Hadoop configuration settings:

- `dfs.replication`: Number of replicas for each block (set to 2 for our 2 DataNodes)
- `dfs.permissions.enabled`: Set to false for simplicity in this demo
- `fs.defaultFS`: Set to hdfs://hadoop-namenode:9000

### HDFS Sink Connector Configuration

Critical settings in the HDFS Sink connector:

- `hdfs.url`: HDFS connection URL (hdfs://hadoop-namenode:9000)
- `flush.size`: Number of records before writing to HDFS (set to 1 for demo purposes)
- `format.class`: Format for storing data (JsonFormat in our case)
- `topics`: Kafka topics to consume from
- `path.format`: Directory structure in HDFS

## Troubleshooting

Common issues encountered during Phase 2 implementation:

1. **HDFS Permission Issues**:
   - Ensure proper permissions on HDFS directories
   - Use `hdfs dfs -chmod -R 777 /kafka` for testing purposes

2. **Connector Registration Failures**:
   - Check if required Hadoop libraries are available in the Kafka Connect classpath
   - Verify HDFS is accessible from the Kafka Connect container

3. **No Data in HDFS**:
   - Check if the connector is in RUNNING state
   - Verify flush.size configuration (smaller values flush more frequently)
   - Check for errors in Kafka Connect logs
   - Ensure HDFS directories exist and are writable

4. **Container Startup Issues**:
   - Hadoop containers may take longer to initialize
   - Use healthchecks to ensure proper startup sequence

## Verification

To verify Phase 2 is working correctly:

1. Run the test script: `./scripts/test-phase2.sh`
2. Check for data in HDFS:
   ```bash
   # List directories
   docker exec hadoop-namenode hdfs dfs -ls -R /kafka/
   
   # View file contents
   docker exec hadoop-namenode hdfs dfs -cat /kafka/openmrs.patient/*/part-*.json | head
   ```
3. Check connector status:
   ```bash
   docker exec kafka-connect curl -s http://localhost:8083/connectors/hdfs-sink/status
   ```
4. Use the utility script:
   ```bash
   ./scripts/check-hdfs.sh hadoop-namenode /kafka/openmrs.patient
   ```

## Next Steps

✅ Phase 2 is complete! Proceed to Phase 3 to add Hive for SQL querying capabilities over the HDFS data.
