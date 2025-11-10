#!/bin/sh
set -eu

# Generate a simple JSON status file with current UTC time
mkdir -p /var/www/html
cat > /var/www/html/status.json <<EOF
{"service":"uptime","status":"ok","time":"$(date -u +"%Y-%m-%dT%H:%M:%SZ")"}
EOF

# Serve the directory using python3's simple HTTP server (foreground)
exec python3 -m http.server 80 --directory /var/www/html
