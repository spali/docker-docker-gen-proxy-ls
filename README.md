# docker-docker-gen-proxy-ls
lightweight docker-gen docker image for an nginx-proxy with letsencrypt support.

## Features
 - automated nginx proxy 
 - Automatic creation/renewal of Let's Encrypt certificates
 - Automatically creation of a Strong Diffie-Hellman Group (for having an A+ Rate on the [Qualsys SSL Server Test](https://www.ssllabs.com/ssltest/))
 - configuration allows for customize almost anything

## Usage
nginx official nginx image can be used or the my extremly lightweight spali/nginx based on alpine linux.
just fire up nginx with at least the follwing shares in common with this container:
 - ```/etc/nginx/certs``` used to store the certificates and keys
 - ```/etc/nginx/conf.d``` used to store the generated configuration
 - ```/etc/nginx/vhost.d``` used to setup virtual host settings, especially for the temporary acme-challenge config
 - ```/usr/share/nginx/html``` used to store and serve the temporary acme-challenge files
```
docker run -d --name proxy-nginx \
	-v /etc/nginx/certs
	-v /etc/nginx/conf.d
	-v /etc/nginx/vhost.d
	-v /usr/share/nginx/html
	spali/nginx
```

start this docker image with the common shares and additional volume ```/var/run/docker.sock:/tmp/docker.sock:ro``` and with the following environment variables:
 - ```NGINX_PROXY_CID=<proxy-nginx-container>``` defines the nginx container name which has to be notified for reloading the configuration
 - ```ACME_CA_URI=https://acme-v01.api.letsencrypt.org/directory``` to define usage of the production let's encrypt server. Defaults to the staging server for testing if not set
```
docker run -d --name proxy-docker-gen-ls \
	--volumes-from proxy-nginx
	-v /var/run/docker.sock:/tmp/docker.sock:ro
	-e NGINX_PROXY_CID=proxy-nginx
	-e ACME_CA_URI=https://acme-v01.api.letsencrypt.org/directory
	spali/docker-gen-proxy-ls
```

__Example ```docker-compose.yml```__
```
proxy-nginx:
  container_name: proxy-nginx
  image: spali/nginx
  volumes:
  - /etc/nginx/certs
  - /etc/nginx/conf.d
  - /etc/nginx/vhost.d
  - /usr/share/nginx/html
  ports:
  - "80:80"
  - "443:443"
proxy-docker-gen-ls:
  container_name: proxy-docker-gen-ls
  image: spali/docker-gen-proxy-ls
  environment:
    NGINX_PROXY_CID: proxy-nginx
    ACME_CA_URI: https://acme-staging.api.letsencrypt.org/directory
  volumes_from:
  - proxy-nginx
  volumes:
  - /var/run/docker.sock:/tmp/docker.sock:ro
```



## Credits
 - thanks to [lukas2511](https://github.com/lukas2511) for the bash based [ACME client](https://github.com/lukas2511/letsencrypt.sh)
 - thanks to [jwilder](https://github.com/jwilder) for docker-gen and nginx-proxy
 - thanks to [JrCs](https://github.com/JrCs) for the base of the idea and some code from [JrCs/docker-letsencrypt-nginx-proxy-companion](https://github.com/JrCs/docker-letsencrypt-nginx-proxy-companion)

