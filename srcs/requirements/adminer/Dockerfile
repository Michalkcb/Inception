FROM debian:12

RUN apt-get update -y \
  && apt-get install -y apache2 php php-mysql wget \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/html

# Pobierz najnowszego Adminera
RUN wget -O adminer.php https://www.adminer.org/latest.php \
  && rm -f index.html || true \
  && cp adminer.php index.php || true \
  && chown -R www-data:www-data /var/www/html || true

EXPOSE 80

CMD ["apachectl", "-D", "FOREGROUND"]
