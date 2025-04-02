# Project Roadmap

This document outlines the phase-by-phase development approach for building our big data infrastructure.

## Phase 1: Minimal Pipeline — MySQL + Debezium + Kafka ✅

- MySQL container with OpenMRS sample dump
- Debezium running inside Kafka Connect container
- Kafka and Zookeeper for messaging
- Goal: Insert into DB → See CDC event in Kafka

**Key Files**: 
- `compose/stage-1-minimal.yaml`
- `pipelines/debezium-openmrs-source.json`
- `scripts/test-phase1.sh`

**Status**: Completed and working! The test script successfully:
- Starts all required containers
- Configures Debezium connector
- Loads sample data
- Verifies CDC events in Kafka

## Phase 2: Add Hadoop — Stream into HDFS

- Deploy Hadoop (NameNode + 2 DataNodes)
- Kafka Connect uses HDFS Sink connector
- JSON/Avro events written to HDFS

**Key Files**:
- `compose/stage-2-hdfs.yaml`
- `pipelines/kafka-connect-hdfs-sink.json`

## Phase 3: Add Hive — Query via SQL

- Launch Hive Metastore + HiveServer2
- Create Hive external table over HDFS data
- Use Beeline or JDBC to query patient data

**Key Files**:
- `compose/stage-3-hive.yaml`
- `sql/hive-create-table.sql`

## Phase 4: Monitoring (Optional)

- Prometheus scrapes metrics from Kafka, Hadoop, Debezium
- Grafana visualizes ingestion rate, disk usage, job status
- JMX exporters or Prometheus exporters installed

**Key File**: `compose/stage-4-monitoring.yaml`

## Phase 5: GitHub CI/CD & Final Composition

- GitHub Actions: validate docker-compose + lint configs
- All phases documented and runnable
- Easy-to-clone, run, and test anywhere

**Key Files**: 
- `compose/stage-final.yaml`
- `.github/workflows/ci.yaml`
