FROM debian:12
# Użyj Debiana jako obrazu bazowego [cite: 249]

RUN apt update -y && \
    apt install -y mariadb-server mariadb-client wget vim && \
    rm -rf /var/lib/apt/lists/*

# Konfiguracja serwera (TCP/IP) i skrypt inicjujący
COPY ./50-server.cnf /etc/mysql/conf.d/50-server.cnf
COPY ./setup.sh /usr/local/bin/setup.sh
RUN chmod +x /usr/local/bin/setup.sh

EXPOSE 3306

HEALTHCHECK --interval=5s --timeout=3s --retries=20 CMD mysqladmin ping -h 127.0.0.1 --silent || exit 1

CMD ["/usr/local/bin/setup.sh"]
