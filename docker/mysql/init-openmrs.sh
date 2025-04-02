#!/bin/bash
set -e

# Wait for MySQL to be ready
until mysqladmin ping -h localhost -u root -p$MYSQL_ROOT_PASSWORD --silent; do
    echo "Waiting for MySQL to be ready..."
    sleep 2
done

# Check if the database is already initialized
INITIALIZED=$(mysql -u root -p$MYSQL_ROOT_PASSWORD -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'openmrs'" | grep -v COUNT)

if [ "$INITIALIZED" -eq "0" ]; then
    echo "Initializing OpenMRS database..."
    mysql -u root -p$MYSQL_ROOT_PASSWORD openmrs < /docker-entrypoint-initdb.d/openmrs_sample_dump.sql
    echo "OpenMRS database initialized successfully!"
else
    echo "OpenMRS database already initialized."
fi
