#!/bin/bash
set -euo pipefail

log(){ printf "[%s] %s\n" "$(date +'%Y-%m-%d %H:%M:%S')" "$*"; }

DATADIR=/var/lib/mysql
SOCKET=/run/mysqld/mysqld.sock

# Export sensible defaults if env vars missing
: "${MYSQL_DATABASE:=wordpress_db}"
: "${MYSQL_USER:=wp_user}"
: "${MYSQL_PASSWORD:=}"
: "${MYSQL_ROOT_PASSWORD:=}"

# Security: do not provide default passwords in repository; require MYSQL_PASSWORD to be set
if [ -z "${MYSQL_PASSWORD:-}" ]; then
    log "ERROR: MYSQL_PASSWORD is not set. Set it in srcs/.env or environment before starting the container." >&2
    exit 1
fi

mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld
chown -R mysql:mysql "$DATADIR" || true

cd "$DATADIR"

if [ ! -d "${DATADIR}/mysql" ] || [ -z "$(ls -A ${DATADIR} 2>/dev/null || true)" ]; then
    log "Initializing MariaDB data directory (first start)..."
    mariadb-install-db --user=mysql --datadir="${DATADIR}"

    # Start temporary server (skip networking for safety)
    log "Starting temporary mariadbd for initial setup..."
    mariadbd --user=mysql --datadir="${DATADIR}" --skip-networking --socket="${SOCKET}" &
    MARIADB_PID=$!

    # wait for socket
    for i in $(seq 1 30); do
        if mysql --protocol=socket -uroot -e "SELECT 1;" >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done

    if ! mysql --protocol=socket -uroot -e "SELECT 1;" >/dev/null 2>&1; then
        log "Temporary mariadbd did not become available" >&2
        kill "$MARIADB_PID" || true
        wait "$MARIADB_PID" 2>/dev/null || true
        exit 1
    fi

    # Prepare SQL to create root, database and app user (idempotent)
    DB_NAME="${MYSQL_DATABASE}"
    DB_USER="${MYSQL_USER}"
    DB_PASS="${MYSQL_PASSWORD}"
    ROOT_PASS="${MYSQL_ROOT_PASSWORD}"

    TSQL=$(mktemp)
    cat > "$TSQL" <<-SQL
        USE mysql;
        DELETE FROM mysql.user WHERE User='';
        DROP DATABASE IF EXISTS test;
SQL

    if [ -n "$ROOT_PASS" ]; then
    cat >> "$TSQL" <<-SQL
        CREATE USER IF NOT EXISTS 'root'@'localhost' IDENTIFIED BY '${ROOT_PASS}';
        CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '${ROOT_PASS}';
        GRANT ALL ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
        GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION;
        FLUSH PRIVILEGES;
SQL
    else
    cat >> "$TSQL" <<-SQL
        -- No MYSQL_ROOT_PASSWORD provided; keep default socket auth for localhost root if present
        FLUSH PRIVILEGES;
SQL
    fi

    cat >> "$TSQL" <<-SQL
        CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
        CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';
        GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
        FLUSH PRIVILEGES;
SQL

    log "Applying initial SQL statements..."
    mysql --protocol=socket -uroot < "$TSQL" || { log "Initial SQL failed" >&2; cat "$TSQL"; rm -f "$TSQL"; kill "$MARIADB_PID" || true; wait "$MARIADB_PID" 2>/dev/null || true; exit 1; }
    rm -f "$TSQL"

    # Shutdown temporary server cleanly
    log "Shutting down temporary mariadbd..."
    mysqladmin --protocol=socket -uroot shutdown || { kill "$MARIADB_PID" || true; }
    wait "$MARIADB_PID" 2>/dev/null || true

    log "MariaDB initialization finished."
else
    log "MariaDB data directory already initialized; ensuring required DB/user exist (idempotent check)..."

    # Start temporary mariadbd to be able to run idempotent CREATE USER / CREATE DATABASE
    log "Starting temporary mariadbd for post-init checks..."
    mariadbd --user=mysql --datadir="${DATADIR}" --socket="${SOCKET}" &
    MARIADB_PID=$!

    # wait for socket (try both socket and tcp-root access depending on server config)
    for i in $(seq 1 30); do
        if command -v mysql >/dev/null 2>&1; then
            if [ -n "${ROOT_PASS:-}" ]; then
                if mysql --protocol=socket -uroot -p"${ROOT_PASS}" -e 'SELECT 1;' >/dev/null 2>&1; then
                    break
                fi
            else
                if mysql --protocol=socket -uroot -e 'SELECT 1;' >/dev/null 2>&1; then
                    break
                fi
            fi
        fi
        sleep 1
    done

    if ! (command -v mysql >/dev/null 2>&1 && mysql --protocol=socket -uroot -p"${ROOT_PASS:-}" -e 'SELECT 1;' >/dev/null 2>&1) && ! (command -v mysql >/dev/null 2>&1 && mysql --protocol=socket -uroot -e 'SELECT 1;' >/dev/null 2>&1); then
        log "Temporary mariadbd did not become available for checks; proceeding to start foreground server." >&2
        # try to kill temp process if it's running
        kill "${MARIADB_PID}" >/dev/null 2>&1 || true
        wait "${MARIADB_PID}" 2>/dev/null || true
    else
        # Prepare SQL that ensures DB and user exist (idempotent)
        DB_NAME="${MYSQL_DATABASE}"
        DB_USER="${MYSQL_USER}"
        DB_PASS="${MYSQL_PASSWORD}"

          TSQL=$(mktemp)
          cat > "${TSQL}" <<-SQL
              CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
              CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';
              GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
              FLUSH PRIVILEGES;
SQL

        log "Applying idempotent DB/user creation SQL..."
        if command -v mysql >/dev/null 2>&1; then
            # prefer socket root if available, else try root with password
            if mysql --protocol=socket -uroot -e 'SELECT 1;' >/dev/null 2>&1; then
                mysql --protocol=socket -uroot < "${TSQL}" || log "Warning: applying SQL via socket failed"
            else
                mysql --protocol=socket -uroot -p"${ROOT_PASS:-}" < "${TSQL}" || log "Warning: applying SQL via root+password failed"
            fi
        else
            log "mysql client not available inside container; cannot apply DB/user checks." >&2
        fi
        rm -f "${TSQL}"

        # Shutdown temporary server started for checks
        log "Shutting down temporary mariadbd used for post-init checks..."
        mysqladmin --protocol=socket -uroot shutdown >/dev/null 2>&1 || { kill "${MARIADB_PID}" || true; }
        wait "${MARIADB_PID}" 2>/dev/null || true
    fi
fi

log "Starting MariaDB in foreground..."
exec mariadbd --user=mysql --datadir="${DATADIR}" --bind-address=0.0.0.0 --socket="${SOCKET}"