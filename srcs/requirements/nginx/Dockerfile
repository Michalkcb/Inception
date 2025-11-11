FROM debian:12
# Użyj Debiana jako obrazu bazowego [cite: 249]

# Instalacja NGINX, OpenSSL oraz envsubst (gettext-base)
RUN apt update -y && \
    apt install -y nginx \
    openssl \
    gettext-base \
    vim \
    && rm -rf /var/lib/apt/lists/*

# Kopiujemy szablon konfiguracji (zawiera ${DOMAIN_NAME}) oraz entrypoint
COPY ./nginx.conf /etc/nginx/sites-available/default.template
COPY ./docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh && \
    rm -f /etc/nginx/sites-enabled/default && \
    ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# Wystawienie portu
EXPOSE 443

# Uruchamianie przez nasz entrypoint (generuje cert i plik konfiguracyjny z env)
CMD ["/usr/local/bin/docker-entrypoint.sh"]
