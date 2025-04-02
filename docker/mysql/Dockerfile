FROM mysql:8.0

# Add custom MySQL configuration if needed
COPY my.cnf /etc/mysql/conf.d/

# Enable binary logging for Debezium CDC
RUN echo "[mysqld]" >> /etc/mysql/conf.d/mysql.cnf && \
    echo "server-id=1" >> /etc/mysql/conf.d/mysql.cnf && \
    echo "log_bin=mysql-bin" >> /etc/mysql/conf.d/mysql.cnf && \
    echo "binlog_format=ROW" >> /etc/mysql/conf.d/mysql.cnf && \
    echo "binlog_row_image=FULL" >> /etc/mysql/conf.d/mysql.cnf && \
    echo "expire_logs_days=10" >> /etc/mysql/conf.d/mysql.cnf

# Add initialization script
COPY init-openmrs.sh /docker-entrypoint-initdb.d/
RUN chmod +x /docker-entrypoint-initdb.d/init-openmrs.sh

# Health check script
COPY healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 CMD /healthcheck.sh
