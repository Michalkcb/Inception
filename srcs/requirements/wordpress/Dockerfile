# Use Debian as base
FROM debian:12
ARG WORDPRESS_VERSION
# Użyj Debiana jako obrazu bazowego [cite: 249]
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
# Instalacja PHP-FPM, klienta MariaDB, Wget i niezbędnych rozszerzeń
RUN apt update -y && \
    apt install -y \
    php-fpm \
    php-mysql \
    php-redis \
    wget \
    vim \
    php-cli \
    mariadb-client \
    && rm -rf /var/lib/apt/lists/*

# Pobieranie WordPress CLI
RUN wget -O /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x /usr/local/bin/wp

# Pobieranie WordPressa w wersji określonej przez build-arg WORDPRESS_VERSION
WORKDIR /var/www/html
RUN if [ -z "${WORDPRESS_VERSION:-}" ]; then echo "ERROR: WORDPRESS_VERSION build-arg not set"; exit 1; fi && \
    wget -O /tmp/wordpress.tar.gz "https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz" && \
    tar -xzf /tmp/wordpress.tar.gz && \
    mv wordpress/* . && \
    rm -rf /tmp/wordpress.tar.gz wordpress && \
    chown -R www-data:www-data /var/www/html

# Kopiuj motyw z repo do obrazu (jeśli istnieje)
COPY ./wp-content/themes/aegean-mbany /var/www/html/wp-content/themes/aegean-mbany
COPY ./wp-content/themes/aegean-mbany /usr/src/aegean-mbany
RUN chown -R www-data:www-data /var/www/html/wp-content/themes/aegean-mbany /usr/src/aegean-mbany || true

# Kopiowanie konfiguracji PHP-FPM i skryptu inicjującego
COPY ./www.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY ./wp-setup.sh /usr/local/bin/wp-setup.sh
RUN chmod +x /usr/local/bin/wp-setup.sh

EXPOSE 9000

# Wywołanie skryptu inicjującego przy starcie
CMD ["/usr/local/bin/wp-setup.sh"]
