FROM spali/docker-gen:latest

ENV ACME_CA_URI=https://acme-staging.api.letsencrypt.org/directory
ENV ACME_CHALLENGE_DIR=/usr/share/nginx/html/.well-known/acme-challenge
ENV VHOST_DIR=/etc/nginx/vhost.d

WORKDIR /app

# Install simp_le
RUN apk --update add bash grep curl openssl ca-certificates git \
    && git clone https://github.com/lukas2511/letsencrypt.sh.git /tmp/letsencrypt.sh \
    && cp /tmp/letsencrypt.sh/letsencrypt.sh /app/letsencrypt.sh \
    && cp /tmp/letsencrypt.sh/config.sh.example /app/config.sh \
    && echo 'CA="${ACME_CA_URI}"' >>/app/config.sh \
    && echo 'WELLKNOWN="${ACME_CHALLENGE_DIR}"' >>/app/config.sh \
    && rm -rf /tmp/letsencrypt.sh \
    && apk del git \
    && rm /var/cache/apk/*

COPY /app/ /app/
RUN chmod +x /app/*.sh

ENTRYPOINT [ "/app/docker-entrypoint.sh" ]
CMD [ "/usr/local/bin/docker-gen", "-watch", "-notify", "/app/update.sh", "-notify-output", "/app/dummy.tmpl", "/tmp/dummy" ]

