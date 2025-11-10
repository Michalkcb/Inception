FROM alpine:3.18

RUN apk add --no-cache vsftpd shadow bash

# Copy config and entrypoint
COPY vsftpd.conf /etc/vsftpd/vsftpd.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 21 30000-30009

VOLUME ["/home/ftpusers"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
