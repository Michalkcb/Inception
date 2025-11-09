#!/bin/bash
set -euo pipefail

log(){ printf "[%s] %s\n" "$(date +'%Y-%m-%d %H:%M:%S')" "$*"; }

DOMAIN="${DOMAIN_NAME:-localhost}"

# 1. Generuj cert jeśli brak
if [ ! -f /etc/ssl/certs/nginx.crt ] || [ ! -f /etc/ssl/certs/nginx.key ]; then
  log "Generuję self-signed cert dla ${DOMAIN}..."
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/certs/nginx.key \
    -out /etc/ssl/certs/nginx.crt \
    -subj "/C=PL/ST=MA/L=Warsaw/O=42School/OU=IT/CN=${DOMAIN}"
fi

# 2. Renderuj konfigurację z szablonu jeśli nie zrobione
if [ -f /etc/nginx/sites-available/default.template ]; then
  envsubst '${DOMAIN_NAME}' < /etc/nginx/sites-available/default.template > /etc/nginx/sites-available/default
fi

# 3. Test konfiguracji
log "Waliduję konfigurację Nginx..."
nginx -t

# 4. Start w foreground
log "Start Nginx (foreground)"
exec nginx -g 'daemon off;'
