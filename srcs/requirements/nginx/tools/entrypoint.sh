#!/bin/bash
set -e

SSL_DIR=/etc/nginx/ssl
mkdir -p "${SSL_DIR}"

# 1) Self-signed certificate (the browser will show a warning - normal for a learning project)
if [ ! -f "${SSL_DIR}/inception.crt" ]; then
    echo "[nginx] generating certificate for ${DOMAIN_NAME}"
    openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
        -keyout "${SSL_DIR}/inception.key" \
        -out "${SSL_DIR}/inception.crt" \
        -subj "/C=FR/O=42/CN=${DOMAIN_NAME}" \
        -addext "subjectAltName=DNS:${DOMAIN_NAME}"
fi

# 2) nginx cannot read environment variables itself, so the domain is substituted into the template.
#    The variable list is explicit so envsubst does not touch $uri, $args etc.
envsubst '${DOMAIN_NAME}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

# 3) foreground mode: nginx is PID 1
echo "[nginx] starting"
exec nginx -g 'daemon off;'
