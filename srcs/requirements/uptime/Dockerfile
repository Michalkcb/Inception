FROM alpine:3.18.2

WORKDIR /var/www/html

# Zainstalujemy python3, użyjemy prostego serwera HTTP z python3, aby mieć pewny, działający
# foreground process bez zależności od specyficznych wersji busybox/httpd
RUN apk add --no-cache python3

# Kopiujemy prosty skrypt startowy, który generuje status.json i uruchamia serwer (foreground)
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 80

CMD ["/start.sh"]
