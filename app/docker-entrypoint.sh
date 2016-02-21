#!/bin/sh

if [ ! -f /etc/nginx/certs/dhparam.pem ]; then
    echo "Creating Diffie-Hellman group (can take several minutes...)"
    openssl dhparam -out /etc/nginx/certs/.dhparam.pem.tmp 2048 2>/dev/null
    mv /etc/nginx/certs/.dhparam.pem.tmp /etc/nginx/certs/dhparam.pem || exit 1
fi

if [ ! -f /etc/docker-gen/templates/docker-proxy.tmpl ]; then
    echo "Copy initial docker-proxy.tmpl"
    mkdir -p /etc/docker-gen/templates
    cp /app/docker-proxy.tmpl /etc/docker-gen/templates/docker-proxy.tmpl
fi

exec "$@"
