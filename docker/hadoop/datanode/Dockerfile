FROM bde2020/hadoop-datanode:2.0.0-hadoop3.2.1-java8

# Set environment variables
ENV HDFS_CONF_dfs_datanode_data_dir=file:///hadoop/dfs/data
ENV HDFS_CONF_dfs_permissions=false
ENV HDFS_CONF_dfs_permissions_enabled=false

# Create directories
RUN mkdir -p /hadoop/dfs/data

# Add healthcheck script
COPY healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=5 CMD /healthcheck.sh

# Expose ports
EXPOSE 9864
