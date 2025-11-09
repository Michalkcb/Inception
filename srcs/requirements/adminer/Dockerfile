FROM debian:bookworm

RUN apt-get update -y \
  && apt-get install -y apache2 php php-mysql wget \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/html

# Pobierz najnowszego Adminera
RUN wget -O adminer.php https://www.adminer.org/latest.php

EXPOSE 80

CMD ["apachectl", "-D", "FOREGROUND"]
