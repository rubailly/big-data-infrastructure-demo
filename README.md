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

Follow the phase-by-phase approach in the roadmap.md file to build and understand each component of the infrastructure.

## Prerequisites

- Docker and Docker Compose
- Git
- Basic understanding of big data components

## License

[MIT License](LICENSE)
