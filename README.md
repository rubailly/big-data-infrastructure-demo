# Big Data Infrastructure Demo

This repository demonstrates a complete big data infrastructure using containerized components to process healthcare data.

## Overview

This project simulates a real-time health data pipeline, transforming clinical records into queryable datasets using tools from the modern data engineering stack.

Key components:
- MySQL with sample healthcare database
- Debezium for Change Data Capture (CDC)
- Kafka for real-time data streaming
- Hadoop HDFS for distributed storage
- Hive for SQL querying on big data
- Prometheus and Grafana for monitoring (optional)

## Project Roadmap

This project follows a phase-by-phase development approach:

### Phase 1: Minimal Pipeline — MySQL + Debezium + Kafka ✅

- MySQL container with sample healthcare data
- Debezium running inside Kafka Connect container
- Kafka and Zookeeper for messaging
- Goal: Insert into DB → See CDC event in Kafka

**Key Files**: 
- `compose/stage-1-minimal.yaml`
- `pipelines/debezium-openmrs-source.json`
- `scripts/test-phase1.sh`

**Status**: Completed and working!

### Phase 2: Add Hadoop — Stream into HDFS ✅

- Deploy Hadoop (NameNode + 2 DataNodes)
- Kafka Connect uses HDFS Sink connector
- JSON/Avro events written to HDFS

**Key Files**:
- `compose/stage-2-hdfs.yaml`
- `pipelines/kafka-connect-hdfs-sink.json`
- `scripts/test-phase2.sh`

**Status**: Completed and working!

### Phase 3: Add Hive — Query via SQL

- Launch Hive Metastore + HiveServer2
- Create Hive external table over HDFS data
- Use Beeline or JDBC to query patient data

**Key Files**:
- `compose/stage-3-hive.yaml`
- `sql/hive-create-table.sql`

### Phase 4: Monitoring (Optional)

- Prometheus scrapes metrics from Kafka, Hadoop, Debezium
- Grafana visualizes ingestion rate, disk usage, job status
- JMX exporters or Prometheus exporters installed

**Key File**: `compose/stage-4-monitoring.yaml`

### Phase 5: GitHub CI/CD & Final Composition

- GitHub Actions: validate docker-compose + lint configs
- All phases documented and runnable
- Easy-to-clone, run, and test anywhere

**Key Files**: 
- `compose/stage-final.yaml`
- `.github/workflows/ci.yaml`

## Repository Structure

```
big-data-infrastructure-demo/
├── docker/                  # Dockerfiles & config for each service
├── compose/                 # Docker Compose configurations
├── pipelines/               # Debezium + Kafka Connect configs
├── sql/                     # SQL scripts (e.g., Hive table creation)
├── data/                    # Sample data
├── .github/workflows/       # GitHub Actions (CI/CD)
├── README.md                # Main instructions
└── LICENSE                  # License information
```

## Getting Started

This project follows a phase-by-phase approach as outlined in the roadmap section above. Each phase builds on the previous one to create a complete big data infrastructure.

### Phase 1: MySQL + Debezium + Kafka

To run the minimal pipeline with MySQL, Debezium, and Kafka:

```bash
# Run the test script for Phase 1
chmod +x scripts/test-phase1.sh
./scripts/test-phase1.sh
```

This script will:
1. Start the necessary containers (MySQL, Zookeeper, Kafka, Kafka Connect)
2. Configure Debezium to monitor the MySQL database
3. Load sample data into the database
4. Insert a test patient record
5. Verify that CDC events are captured in Kafka

When successful, you'll see CDC events for both patient and person_name tables in Kafka.

### Phase 2: Adding Hadoop HDFS

To extend the pipeline with Hadoop HDFS for data storage:

```bash
# Run the test script for Phase 2
chmod +x scripts/test-phase2.sh
./scripts/test-phase2.sh
```

This script will:
1. Deploy a Hadoop cluster with NameNode and 2 DataNodes
2. Configure the HDFS Sink connector for Kafka Connect
3. Stream CDC events from Kafka to HDFS
4. Insert test data and verify it flows through the entire pipeline

#### Verifying Phase 2 Setup

After running the Phase 2 script, you can verify the setup with these commands:

```bash
# Check data directories in HDFS
docker exec hadoop-namenode hdfs dfs -ls -R /kafka/

# View sample patient data in HDFS
docker exec hadoop-namenode hdfs dfs -cat /kafka/openmrs.patient/*/part-*.json | head -5

# View sample person_name data in HDFS
docker exec hadoop-namenode hdfs dfs -cat /kafka/openmrs.person_name/*/part-*.json | head -5

# Check HDFS Sink connector status
docker exec kafka-connect curl -s http://localhost:8083/connectors/hdfs-sink/status

# Check HDFS disk usage
docker exec hadoop-namenode hdfs dfs -du -s -h /kafka/
```

You can also use the provided utility script to check HDFS:

```bash
# Check HDFS content
./scripts/check-hdfs.sh hadoop-namenode /kafka/openmrs.patient
```

## Prerequisites

- Docker and Docker Compose
- Git
- Basic understanding of big data components

## License

[MIT License](LICENSE)
