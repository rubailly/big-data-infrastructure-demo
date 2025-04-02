FROM debezium/connect:2.1

# Add custom configurations if needed
COPY connect-distributed.properties /etc/kafka/connect-distributed.properties.template

# Add health check script - using bash script that's already executable
COPY --chmod=755 healthcheck.sh /healthcheck.sh

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=5 CMD /healthcheck.sh
