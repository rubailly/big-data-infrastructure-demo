#!/bin/bash
hdfs dfsadmin -report > /dev/null 2>&1 || exit 1
