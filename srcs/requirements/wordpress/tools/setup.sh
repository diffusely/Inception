#!/bin/bash
# First-time WordPress install (done once, skipped afterwards), then start php-fpm.
set -e

WP_PATH=/var/www/html
DB_PASSWORD="$(cat /run/secrets/db_password)"
WP_ADMIN_PASSWORD="$(cat /run/secrets/wp_admin_password)"
WP_USER_PASSWORD="$(cat /run/secrets/wp_user_password)"

# 1) Wait until MariaDB accepts connections (host name "mariadb" = service name in compose)
echo "[wordpress] waiting for MariaDB..."
until mariadb -h mariadb -u"${MYSQL_USER}" -p"${DB_PASSWORD}" "${MYSQL_DATABASE}" -e "SELECT 1" > /dev/null 2>&1; do
    sleep 2
done

mkdir -p "${WP_PATH}"
cd "${WP_PATH}"

# 2) Download WordPress into the volume if it is not there yet
if [ ! -f wp-load.php ]; then
    echo "[wordpress] downloading WordPress"
    wp core download --allow-root
fi

# 3) Config with database access
if [ ! -f wp-config.php ]; then
    echo "[wordpress] creating wp-config.php"
    wp config create --allow-root \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${DB_PASSWORD}" \
        --dbhost=mariadb
fi

# 4) Install the site + two users (administrator and a regular author)
if ! wp core is-installed --allow-root; then
    echo "[wordpress] installing site https://${DOMAIN_NAME}"
    wp core install --allow-root \
        --url="https://${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email
    wp user create "${WP_USER}" "${WP_USER_EMAIL}" --allow-root \
        --role=author --user_pass="${WP_USER_PASSWORD}"
fi

# 5) Files must belong to www-data, otherwise WordPress cannot write to them (plugins, uploads)
chown -R www-data:www-data "${WP_PATH}"

# 6) php-fpm in foreground (-F) with logs to stderr (-O): it becomes PID 1 and the container lives as long as it runs
mkdir -p /run/php
echo "[wordpress] starting php-fpm"
exec php-fpm8.2 -F -O
