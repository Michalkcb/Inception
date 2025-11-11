FROM debian:12

RUN apt-get update -y \
  && apt-get install -y nginx \
  && rm -rf /var/lib/apt/lists/*

COPY index.html /var/www/html/index.html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
