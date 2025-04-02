#!/bin/bash
# Check if the DataNode process is running
pgrep -f "org.apache.hadoop.hdfs.server.datanode.DataNode" > /dev/null || exit 1
# Check if the DataNode port is listening
nc -z localhost 9864 > /dev/null || exit 1
