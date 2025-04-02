# Big Data Infrastructure Demo

This repository demonstrates a complete big data infrastructure using containerized components to process healthcare data from OpenMRS.

## Overview

This project simulates a real-time health data pipeline, transforming clinical records into queryable datasets using tools from the modern data engineering stack.

Key components:
- MySQL with OpenMRS database
- Debezium for Change Data Capture (CDC)
- Kafka for real-time data streaming
- Hadoop HDFS for distributed storage
- Hive for SQL querying on big data
- Prometheus and Grafana for monitoring (optional)

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
├── roadmap.md               # Phase-by-phase project goals
└── LICENSE                  # License information
```

## Getting Started

This project follows a phase-by-phase approach as outlined in the roadmap.md file. Each phase builds on the previous one to create a complete big data infrastructure.

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
3. Load sample data into the OpenMRS database
4. Insert a test patient record
5. Verify that CDC events are captured in Kafka

When successful, you'll see CDC events for both patient and person_name tables in Kafka.

## Prerequisites

- Docker and Docker Compose
- Git
- Basic understanding of big data components

## License

[MIT License](LICENSE)
