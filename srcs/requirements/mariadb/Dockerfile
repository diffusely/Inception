# Debian 12 "bookworm" - the penultimate stable release (current stable is 13 "trixie").
# The "latest" tag is forbidden by the subject, so the version is pinned explicitly.
FROM debian:bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends mariadb-server \
    && rm -rf /var/lib/apt/lists/*

COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY tools/init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

EXPOSE 3306

# init.sh prepares the database and finally starts the server as the main process (PID 1)
ENTRYPOINT ["/usr/local/bin/init.sh"]
