FROM bde2020/hadoop-namenode:2.0.0-hadoop3.2.1-java8

# Set environment variables
ENV CLUSTER_NAME=hadoop-cluster
ENV HDFS_CONF_dfs_namenode_name_dir=file:///hadoop/dfs/name
ENV HDFS_CONF_dfs_replication=2
ENV HDFS_CONF_dfs_permissions=false
ENV HDFS_CONF_dfs_permissions_enabled=false
ENV HDFS_CONF_dfs_webhdfs_enabled=true
ENV CORE_CONF_fs_defaultFS=hdfs://hadoop-namenode:9000
ENV CORE_CONF_hadoop_http_staticuser_user=root
ENV CORE_CONF_hadoop_proxyuser_hue_hosts=*
ENV CORE_CONF_hadoop_proxyuser_hue_groups=*

# Create directories
RUN mkdir -p /hadoop/dfs/name

# Add healthcheck script
COPY healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=5 CMD /healthcheck.sh

# Expose ports
EXPOSE 9870 9000
