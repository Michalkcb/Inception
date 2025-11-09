FROM debian:bookworm
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

# Pobieranie WordPressa i ustawienie katalogu roboczego
WORKDIR /var/www/html
RUN wget https://wordpress.org/latest.tar.gz && \
    tar -xzf latest.tar.gz && \
    mv wordpress/* . && \
    rm -rf latest.tar.gz wordpress && \
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
