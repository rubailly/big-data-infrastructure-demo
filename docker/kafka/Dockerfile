FROM confluentinc/cp-kafka:7.3.0

# Add custom configurations if needed
COPY server.properties /etc/kafka/server.properties.template

# Add health check script
COPY healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=5 CMD /healthcheck.sh
