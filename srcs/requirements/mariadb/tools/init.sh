#!/bin/bash
# Prepare MariaDB on first start, then run the server.
set -e

# Passwords come from Docker secrets (files), not from environment variables
DB_ROOT_PASSWORD="$(cat /run/secrets/db_root_password)"
DB_PASSWORD="$(cat /run/secrets/db_password)"

mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld /var/lib/mysql

# 1) System tables - only if the volume is empty (first start)
if [ ! -d /var/lib/mysql/mysql ]; then
    echo "[mariadb] first start: creating system tables"
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql \
        --skip-test-db --auth-root-authentication-method=normal > /dev/null
fi

# 2) Database and user for WordPress - only if not created yet.
#    --bootstrap runs SQL without starting the network server.
if [ ! -d "/var/lib/mysql/${MYSQL_DATABASE}" ]; then
    echo "[mariadb] creating database ${MYSQL_DATABASE} and user ${MYSQL_USER}"
    mariadbd --user=mysql --bootstrap <<EOF
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
CREATE DATABASE \`${MYSQL_DATABASE}\`;
CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOF
fi

# 3) exec replaces the script with the server itself: it becomes PID 1 and receives stop signals correctly
echo "[mariadb] starting server"
exec mariadbd --user=mysql
