FROM apache/hadoop:3.3.4

# Set environment variables
ENV HDFS_CONF_dfs_namenode_name_dir=file:///hadoop/dfs/name
ENV HDFS_CONF_dfs_replication=2
ENV HDFS_CONF_dfs_permissions=false
ENV HDFS_CONF_dfs_permissions_enabled=false
ENV HDFS_CONF_dfs_webhdfs_enabled=true

# Create directories
RUN mkdir -p /hadoop/dfs/name

# Add healthcheck script
COPY healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=5 CMD /healthcheck.sh

# Expose ports
EXPOSE 9870 9000
