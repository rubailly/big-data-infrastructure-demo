#!/bin/bash
set -e

# Wait for MySQL to be ready
MAX_RETRIES=30
RETRY_COUNT=0
until mysqladmin ping -h localhost -u root -p$MYSQL_ROOT_PASSWORD --silent; do
    echo "Waiting for MySQL to be ready... (${RETRY_COUNT}/${MAX_RETRIES})"
    RETRY_COUNT=$((RETRY_COUNT+1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "Error: MySQL did not become ready in time."
        exit 1
    fi
    sleep 2
done

# Check if the database is already initialized
INITIALIZED=$(mysql -u root -p$MYSQL_ROOT_PASSWORD -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'openmrs'" | grep -v COUNT)

if [ "$INITIALIZED" -eq "0" ]; then
    echo "Initializing OpenMRS database..."
    # Check if the sample dump file exists
    if [ -f "/docker-entrypoint-initdb.d/openmrs_sample_dump.sql" ]; then
        mysql -u root -p$MYSQL_ROOT_PASSWORD openmrs < /docker-entrypoint-initdb.d/openmrs_sample_dump.sql
        echo "OpenMRS database initialized successfully!"
    else
        echo "Warning: Sample dump file not found. Creating empty tables..."
        # Create basic tables if sample dump is not available
        mysql -u root -p$MYSQL_ROOT_PASSWORD openmrs << EOF
CREATE TABLE IF NOT EXISTS patient (
  patient_id INT PRIMARY KEY,
  gender CHAR(1),
  birthdate DATE,
  creator INT,
  date_created DATETIME
);

CREATE TABLE IF NOT EXISTS person_name (
  person_name_id INT PRIMARY KEY,
  person_id INT,
  given_name VARCHAR(50),
  family_name VARCHAR(50),
  creator INT,
  date_created DATETIME,
  FOREIGN KEY (person_id) REFERENCES patient(patient_id)
);
EOF
        echo "Empty tables created successfully!"
    fi
else
    echo "OpenMRS database already initialized."
fi
