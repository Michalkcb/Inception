#!/bin/sh
set -eu

# Entry point creates an ftp user if FTP_USER and FTP_PASS are provided
FTP_USER=${FTP_USER:-ftpuser}
FTP_PASS=${FTP_PASS:-ftp_pass}
FTP_HOME=/home/ftpusers/${FTP_USER}

# Ensure ftpusers root exists
mkdir -p /home/ftpusers
chown root:root /home/ftpusers || true

# If the user directory is not present (bind mount empty), create user and home
if ! id "$FTP_USER" >/dev/null 2>&1; then
    adduser -D -h "$FTP_HOME" -s /sbin/nologin "$FTP_USER"
fi

# Set password
echo "${FTP_USER}:${FTP_PASS}" | chpasswd || true

# Ensure ownership
mkdir -p "$FTP_HOME"
chown -R "$FTP_USER":"$FTP_USER" "$FTP_HOME" || true

# If a host bind-mounted dir exists at /host_ftp (created in compose), sync it
if [ -d "/host_ftp" ]; then
    # copy existing files into user home if empty
    if [ -z "$(ls -A "$FTP_HOME")" ]; then
        cp -a /host_ftp/. "$FTP_HOME" || true
        chown -R "$FTP_USER":"$FTP_USER" "$FTP_HOME" || true
    fi
fi

# Start vsftpd in foreground
exec /usr/sbin/vsftpd /etc/vsftpd/vsftpd.conf
