#!/bin/bash
set -e

# Check if a container name was provided
if [ $# -eq 0 ]; then
  echo "Usage: $0 <container-name> [path-in-hdfs]"
  echo "Example: $0 hadoop-namenode /kafka/openmrs.patient"
  exit 1
fi

CONTAINER=$1
HDFS_PATH=${2:-/}

echo "Checking HDFS directory: $HDFS_PATH"
echo "----------------------------------------"

# List files in the specified HDFS path
echo "Files in $HDFS_PATH:"
docker exec $CONTAINER hdfs dfs -ls -R $HDFS_PATH

# Check if there are any files with .json extension
JSON_FILES=$(docker exec $CONTAINER hdfs dfs -ls -R $HDFS_PATH | grep "\.json" | awk '{print $8}')

if [ -z "$JSON_FILES" ]; then
  echo "No JSON files found in $HDFS_PATH"
else
  echo "----------------------------------------"
  echo "Found JSON files:"
  echo "$JSON_FILES"
  
  # Display content of the first JSON file
  FIRST_FILE=$(echo "$JSON_FILES" | head -n 1)
  echo "----------------------------------------"
  echo "Content of $FIRST_FILE:"
  docker exec $CONTAINER hdfs dfs -cat $FIRST_FILE | head -n 10
  
  # Count total records
  TOTAL_RECORDS=$(docker exec $CONTAINER hdfs dfs -cat $FIRST_FILE | wc -l)
  echo "----------------------------------------"
  echo "Total records in $FIRST_FILE: $TOTAL_RECORDS"
fi

# Check HDFS disk usage
echo "----------------------------------------"
echo "HDFS disk usage:"
docker exec $CONTAINER hdfs dfs -du -s -h $HDFS_PATH

# Check HDFS status
echo "----------------------------------------"
echo "HDFS status:"
docker exec $CONTAINER hdfs dfsadmin -report | head -n 20
