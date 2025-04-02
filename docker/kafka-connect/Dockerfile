FROM debezium/connect:2.1

# Install the Confluent HDFS Sink Connector
RUN mkdir -p /kafka/connect/hdfs-sink-connector && \
    cd /kafka/connect/hdfs-sink-connector && \
    curl -O https://packages.confluent.io/maven/io/confluent/kafka-connect-hdfs/10.0.3/kafka-connect-hdfs-10.0.3.jar && \
    curl -O https://packages.confluent.io/maven/io/confluent/kafka-connect-storage-common/10.0.3/kafka-connect-storage-common-10.0.3.jar && \
    curl -O https://packages.confluent.io/maven/io/confluent/kafka-connect-storage-core/10.0.3/kafka-connect-storage-core-10.0.3.jar && \
    curl -O https://packages.confluent.io/maven/io/confluent/kafka-connect-storage-format/10.0.3/kafka-connect-storage-format-10.0.3.jar && \
    curl -O https://packages.confluent.io/maven/io/confluent/kafka-connect-storage-partitioner/10.0.3/kafka-connect-storage-partitioner-10.0.3.jar

# Add Hadoop libraries
RUN mkdir -p /kafka/connect/hadoop-libs && \
    cd /kafka/connect/hadoop-libs && \
    curl -O https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-client/3.2.1/hadoop-client-3.2.1.jar && \
    curl -O https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-common/3.2.1/hadoop-common-3.2.1.jar && \
    curl -O https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-hdfs/3.2.1/hadoop-hdfs-3.2.1.jar && \
    curl -O https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-hdfs-client/3.2.1/hadoop-hdfs-client-3.2.1.jar

# Add custom configurations if needed
COPY connect-distributed.properties /etc/kafka/connect-distributed.properties.template

# Add health check script - using bash script that's already executable
COPY --chmod=755 healthcheck.sh /healthcheck.sh

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=5 CMD /healthcheck.sh
