#!/bin/bash
set -euo pipefail

log() { printf "[%s] %s\n" "$(date +'%Y-%m-%d %H:%M:%S')" "$*"; }

# Sprawdzenie krytycznych zmiennych środowiskowych (tylko ostrzeżenie jeśli puste)
required_env=(MYSQL_DATABASE MYSQL_USER MYSQL_PASSWORD WP_ADMIN_USER WP_ADMIN_PASSWORD WP_ADMIN_EMAIL WP_USER WP_EMAIL WP_PASSWORD DOMAIN_NAME)
for var in "${required_env[@]}"; do
  if [ -z "${!var:-}" ]; then
    log "[WARN] Zmienna $var jest pusta lub niezdefiniowana. Może być wymagana do pełnej konfiguracji."
  fi
done

# 1. Oczekiwanie na MariaDB z limitem prób
log "Czekam na MariaDB..."
RETRIES=60
COUNT=0
if ! command -v mysqladmin >/dev/null 2>&1; then
    log "Brak mysqladmin (klient MariaDB). Zainstaluj mariadb-client." >&2
    exit 1
fi
while true; do
    # Prefer using the mysql client for a lightweight TCP check (works with older clients).
    if command -v mysql >/dev/null 2>&1; then
        if [ -n "${MYSQL_USER:-}" ] && [ -n "${MYSQL_PASSWORD:-}" ]; then
            if MYSQL_PWD="${MYSQL_PASSWORD}" mysql -hmariadb -u"${MYSQL_USER}" -e 'SELECT 1' -N -s >/dev/null 2>&1; then
                break
            fi
        fi
        if [ -n "${MYSQL_ROOT_PASSWORD:-}" ]; then
            if mysql -hmariadb -uroot -p"${MYSQL_ROOT_PASSWORD}" -e 'SELECT 1' -N -s >/dev/null 2>&1; then
                break
            fi
        fi
    fi

    # Fallback to mysqladmin ping (without ssl-mode flag to support older clients)
    if command -v mysqladmin >/dev/null 2>&1; then
        if [ -n "${MYSQL_USER:-}" ] && [ -n "${MYSQL_PASSWORD:-}" ]; then
            if MYSQL_PWD="${MYSQL_PASSWORD}" mysqladmin -h mariadb -u "${MYSQL_USER}" ping --silent >/dev/null 2>&1; then
                break
            fi
        fi
        if [ -n "${MYSQL_ROOT_PASSWORD:-}" ]; then
            if mysqladmin -h mariadb -u root -p"${MYSQL_ROOT_PASSWORD}" ping --silent >/dev/null 2>&1; then
                break
            fi
        fi
    fi

    COUNT=$((COUNT+1))
    if [ "$COUNT" -ge "$RETRIES" ]; then
        log "MariaDB nieosiągalna po $RETRIES próbach." >&2
        exit 1
    fi
    sleep 3
done
log "MariaDB gotowa!"
log "MariaDB gotowa!"

# Ensure the WordPress database exists (try with provided DB user, fall back to root). This avoids races
# where the DB directory exists but the DB wasn't created by the server bootstrap.
DB_READY=0
CREATE_RETRIES=6
for i in $(seq 1 $CREATE_RETRIES); do
    if command -v mysql >/dev/null 2>&1; then
        # Try with app user first
        if [ -n "${MYSQL_USER:-}" ] && [ -n "${MYSQL_PASSWORD:-}" ]; then
            if MYSQL_PWD="${MYSQL_PASSWORD}" mysql --ssl-mode=DISABLED -hmariadb -u"${MYSQL_USER}" -e "CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" >/dev/null 2>&1; then
                DB_READY=1; break
            fi
        fi
        # Try as root if app user failed and root password available
        if [ -n "${MYSQL_ROOT_PASSWORD:-}" ]; then
            if mysql --ssl-mode=DISABLED -hmariadb -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" >/dev/null 2>&1; then
                DB_READY=1; break
            fi
        fi
    else
        log "Klient mysql nie jest dostępny w obrazie - nie mogę automatycznie utworzyć bazy."
        break
    fi
    log "Próba utworzenia bazy ($i/$CREATE_RETRIES) nieudana, czekam..."
    sleep 2
done
if [ "$DB_READY" -eq 1 ]; then
    log "Baza ${MYSQL_DATABASE} jest dostępna lub została utworzona."
else
    log "Nie udało się utworzyć bazy danych przez TCP. Jeśli nadal brak połączenia, sprawdź uprawnienia użytkownika w MariaDB." >&2
fi

# 2. Instalacja / konfiguracja WordPress jeśli brak wp-config.php
if [ ! -f /var/www/html/wp-config.php ]; then
    log "Rozpoczynam pierwszą konfigurację WordPress..."
    if ! command -v wp >/dev/null 2>&1; then
        log "Brak wp-cli. Skrypt nie może kontynuować." >&2
        exit 1
    fi

    chown -R www-data:www-data /var/www/html

    # Jeśli bind-mount hosta nadpisuje katalog i motyw nie istnieje, skopiuj motyw z obrazu
    if [ ! -d /var/www/html/wp-content/themes/aegean-mbany ] && [ -d /usr/src/aegean-mbany ]; then
        log "Kopiuję motyw aegean-mbany do wp-content/themes (host volume jest pusty lub nadpisany)"
        cp -a /usr/src/aegean-mbany /var/www/html/wp-content/themes/ || true
        chown -R www-data:www-data /var/www/html/wp-content/themes/aegean-mbany || true
    fi

    log "Tworzenie wp-config.php..."
    wp config create --allow-root \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${MYSQL_PASSWORD}" \
        --dbhost="mariadb" \
        --skip-check

    SITE_URL="https://${DOMAIN_NAME}"
    log "Instalacja rdzenia WordPress (${SITE_URL})..."
    wp core install --allow-root \
        --url="${SITE_URL}" \
        --title="Inception Project" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email

    log "Tworzenie dodatkowego użytkownika (author)..."
    wp user create "${WP_USER}" "${WP_EMAIL}" \
        --role=author \
        --user_pass="${WP_PASSWORD}" \
        --allow-root || log "Użytkownik już istnieje, pomijam."

    # Dodatkowe ustawienia (idempotentne)
    wp option update blogdescription "Inception environment" --allow-root || true
    wp rewrite structure '/%postname%/' --allow-root || true
    wp rewrite flush --allow-root || true

    log "WordPress zainstalowany pomyślnie."
else
    log "wp-config.php istnieje - pomijam instalację."
fi

# Jeśli motyw nie istnieje w zmapowanym wolumenie, skopiuj go z obrazu (zabezpieczenie przy bind-mount)
if [ -d /usr/src/aegean-mbany ]; then
    log "Synchronizuję motyw aegean-mbany z /usr/src do /var/www/html/wp-content/themes"
    mkdir -p /var/www/html/wp-content/themes/aegean-mbany || true
    # Użyj tar aby niezawodnie skopiować pliki (zastąpi brakujące/nowsze) bez zależności od cp -n
    tar -C /usr/src/aegean-mbany -cf - . | tar -C /var/www/html/wp-content/themes/aegean-mbany -xpf - || true
    chown -R www-data:www-data /var/www/html/wp-content/themes/aegean-mbany || true
fi

# --- Redis integration: ensure plugin and constants are present (idempotent)
if command -v wp >/dev/null 2>&1 && wp core is-installed --allow-root >/dev/null 2>&1; then
    log "Sprawdzam integrację Redis..."
    # Add WP_REDIS_HOST/PORT to wp-config.php if missing
    if [ -f /var/www/html/wp-config.php ] && ! grep -q "WP_REDIS_HOST" /var/www/html/wp-config.php; then
        log "Dodaję stałe WP_REDIS_HOST i WP_REDIS_PORT do wp-config.php"
        CONFIG="/var/www/html/wp-config.php"
        # Insert constants before the "/* That's all, stop editing" marker using sed for portability
        sed -e "/\/\* That's all, stop editing/i\\
define('WP_REDIS_HOST', 'redis');\\
define('WP_REDIS_PORT', 6379);" "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG" || true
        chown www-data:www-data /var/www/html/wp-config.php || true
    fi

    # Install & activate redis-cache plugin idempotently
    if ! wp plugin is-installed redis-cache --allow-root >/dev/null 2>&1; then
        log "Instaluję i aktywuję wtyczkę redis-cache..."
        wp plugin install redis-cache --activate --allow-root || log "Nie udało się zainstalować wtyczki redis-cache"
    else
        log "Wtyczka redis-cache już zainstalowana."
    fi

    # Try to enable Redis via WP-CLI (if plugin provides command)
    set +e
    wp redis enable --allow-root >/dev/null 2>&1 && log "Redis enabled via wp-cli" || log "wp redis enable nie powiodło się lub nie jest dostępne (to może być normalne)"
    set -e
fi

# --- Ensure secondary WP user and static front page (idempotent)
if command -v wp >/dev/null 2>&1 && wp core is-installed --allow-root >/dev/null 2>&1; then
    # Defaults for front page (can be overridden via env)
    : "${WP_FRONT_PAGE_TITLE:=Strona Główna}"
    : "${WP_FRONT_PAGE_CONTENT:=Wersja statyczna front page wygenerowana automatycznie.}"

    # Ensure secondary author user exists (idempotent)
    if [ -n "${WP_USER:-}" ]; then
        if ! wp user get "${WP_USER}" --field=ID --allow-root >/dev/null 2>&1; then
            log "Tworzę użytkownika ${WP_USER}..."
            wp user create "${WP_USER}" "${WP_EMAIL:-}" --role=author --user_pass="${WP_PASSWORD:-}" --allow-root || log "Nie udało się utworzyć użytkownika ${WP_USER}"
        else
            log "Użytkownik ${WP_USER} już istnieje, pomijam."
        fi
    fi

    # Ensure a static front page exists and is assigned (idempotent)
    CURRENT_FRONT=$(wp option get show_on_front --allow-root 2>/dev/null || echo '')
    CURRENT_PAGE_ON_FRONT=$(wp option get page_on_front --allow-root 2>/dev/null || echo '')
    PAGE_OK=0
    if [ -n "$CURRENT_PAGE_ON_FRONT" ] && [ "$CURRENT_PAGE_ON_FRONT" != "0" ]; then
        if wp post get "$CURRENT_PAGE_ON_FRONT" --post_type=page --allow-root >/dev/null 2>&1; then
            PAGE_OK=1
        fi
    fi

    if [ "$CURRENT_FRONT" != "page" ] || [ "$PAGE_OK" -ne 1 ]; then
        log "Konfiguruję stronę główną (static front page)..."
        # Try to find an existing page with the desired title
        PAGE_ID=$(wp post list --post_type=page --fields=ID,post_title --format=csv --allow-root 2>/dev/null | awk -F',' -v title="$WP_FRONT_PAGE_TITLE" 'BEGIN{IGNORECASE=1} $2==title{print $1; exit}') || true

        if [ -z "$PAGE_ID" ]; then
            log "Tworzę stronę o tytule: $WP_FRONT_PAGE_TITLE"
            PAGE_ID=$(wp post create --post_type=page --post_title="$WP_FRONT_PAGE_TITLE" --post_status=publish --post_content="$WP_FRONT_PAGE_CONTENT" --allow-root --porcelain) || true
        else
            log "Znaleziono istniejącą stronę front page (ID: $PAGE_ID)"
        fi

        if [ -n "$PAGE_ID" ]; then
            wp option update show_on_front 'page' --allow-root || true
            wp option update page_on_front "$PAGE_ID" --allow-root || true
                # Ensure comments are open for the front page so comment form is available
                wp post update "$PAGE_ID" --comment_status=open --allow-root || true
            log "Ustawiono stronę główną na ID: $PAGE_ID"
        else
            log "Nie udało się utworzyć ani znaleźć strony front page"
        fi
    else
        log "Strona główna już ustawiona (show_on_front=page, page_on_front=$CURRENT_PAGE_ON_FRONT)."
    fi
fi

# Aktywuj motyw aegean-mbany jeśli WordPress jest zainstalowany i motyw jest obecny
if command -v wp >/dev/null 2>&1 && wp core is-installed --allow-root >/dev/null 2>&1; then
    if [ -d /var/www/html/wp-content/themes/aegean-mbany ]; then
        log "Aktywuję motyw aegean-mbany"
        wp theme activate aegean-mbany --allow-root || log "Aktywacja motywu nie powiodła się lub motyw już aktywny"
    fi
fi

# 3. Uruchomienie PHP-FPM na pierwszym planie
log "Uruchamiam PHP-FPM..."
if command -v php-fpm8.2 >/dev/null 2>&1; then
    exec php-fpm8.2 -F
elif command -v php-fpm >/dev/null 2>&1; then
    exec php-fpm -F
else
    log "Nie znaleziono binarki php-fpm." >&2
    exit 1
fi