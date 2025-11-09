FROM debian:bookworm

RUN apt-get update -y \
  && apt-get install -y redis-server \
  && rm -rf /var/lib/apt/lists/*

COPY redis.conf /etc/redis/redis.conf

EXPOSE 6379

CMD ["redis-server", "/etc/redis/redis.conf", "--bind", "0.0.0.0"]
