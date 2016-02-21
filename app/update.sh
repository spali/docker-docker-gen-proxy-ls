#!/bin/sh
set -e
# reset dummy trigger for docker-gen to ask this script everytime a docker event occurs
rm -f /tmp/dummy


# generate string based on modification time and file size
file_stat_ident() {
    local file=${1?missing file}
    stat -Lc "%y%s" ${file} 2>/dev/null | sed 's/[^0-9]//g' || true
}

# call to docker api
docker_api() {
    local scheme
    local curl_opts="-s --write-out '%{http_code}\\n'"
    local uri=${1?missing uri}
    local method=${2:-GET}
    local data=${3:-}
    # data to POST
    if [[ -n "${data}" ]]; then
        curl_opts="${curl_opts} -d '${data}'"
    fi
    case ${DOCKER_HOST} in
        unix://*)
            curl_opts="${curl_opts} --unix-socket ${DOCKER_HOST#unix://}"
            scheme='http:'
        ;;
        *)
            scheme="http://${DOCKER_HOST#*://}"
        ;;
    esac
    [[ ${method} = "POST" ]] && curl_opts="${curl_opts} -H 'Content-Type: application/json'"
    result="$(eval "curl ${curl_opts} -X${method} ${scheme}${uri}")"
    status_code="$(echo "${result}" | tail -n 1)"
    result="$(echo "${result}" | head -n -1)"
    echo "${result}"
    return ${status_code}
}

# execute command in container
docker_exec() {
    local exitcode=0
    local id="${1?missing id}"
    local cmd=""
    shift
    for arg in "${@}"; do
      cmd="${cmd}, \"${arg}\""
    done
    cmd="${cmd:2}"
    local data=$(printf '{ "AttachStdin": false, "AttachStdout": true, "AttachStderr": true, "Tty":false,"Cmd": [ %s ] }' "${cmd}")
    result="$(docker_api "/containers/${id}/exec" "POST" "${data}")" && status_code=${?} || status_code=${?}
    case ${status_code} in
      201) true;;
      404) echo "ERROR no such container: " >&2
           echo "${result}" >&2
           return ${status_code};;
        *) echo "ERROR unknown error code ${status_code}" >&2
           echo "${result}" >&2
           return ${status_code};;
    esac
    #exec_id=$(echo ${result} | jq -r .Id) || exitcode=${?}
    exec_id=$(echo ${result} | sed 's/{.*"Id"\s*:\s*"\(.*\)".*}/\1/i') || exitcode=${?}
    if [[ -n "${exec_id}" ]]; then
        docker_api /exec/${exec_id}/start "POST" '{"Detach": false, "Tty":false}' && status_code=${?} || status_code=${?}
        echo "${result}"
    fi
}

# send a signal to a container
docker_signal() {
    local id="${1?missing id}"
    local signal="${2?missing signal}"
    result="$(docker_api /containers/${id}/kill?signal=${signal} "POST")" && status_code=${?} || status_code=${?}
    case ${status_code} in
      204) echo "${id} successfully signaled";;
      404) echo "ERROR no such container: " >&2
           echo "${result}" >&2
           return ${status_code};;
      500) echo "ERROR unknown server error:" >&2
           echo "${result}" >&2
           return ${status_code};;
        *) echo "ERROR unknown error code ${status_code}" >&2
           echo "${result}" >&2
           return ${status_code};;
    esac
}

# notify nginx to reload configuration
notify_nginx() {
    if [[ -n "${NGINX_PROXY_CID:-}" ]]; then
        echo "Notify nginx proxy..."
        docker_signal ${NGINX_PROXY_CID} SIGHUP
    else
        echo "ERROR NGINX_PROXY_CID not defined" >&2
        return 1
    fi
}

# generate proxy configuration
gen_proxy_config() {
    echo "Generate proxy config"
    local filestat=$(file_stat_ident /etc/nginx/conf.d/docker-proxy.conf)
    /usr/local/bin/docker-gen -only-exposed /etc/docker-gen/templates/docker-proxy.tmpl /etc/nginx/conf.d/docker-proxy.conf && result=${?} || result=${?}
    if [ ${result} -ne 0 ]; then
        echo "ERROR during proxy config generation: exit code ${result}" >&2
        return ${result}
    fi
    if [ "${filestat}" != "$(file_stat_ident /etc/nginx/conf.d/docker-proxy.conf)" ]; then
        echo "Proxy config changed"
    else
        echo "Proxy config did not change"
    fi
}

# generate certificate domain list and update certs if required
gen_cert_domain_list() {
    echo "Generate certificate domain list"
    local filestat=$(file_stat_ident /app/domains.txt)
    /usr/local/bin/docker-gen -only-exposed /app/domains.tmpl /app/domains.txt && result=${?} || result=${?}
    if [ ${result} -ne 0 ]; then
        echo "ERROR during certificate domain list generation: exit code ${result}" >&2
        return ${result}
    fi
    if [ "${filestat}" != "$(file_stat_ident /app/domains.txt)" ]; then
        echo "Certificate domain list changed"
        update_certs
    else
        echo "Certificate domain list did not change"
    fi
}

# update certificates
update_certs() {
    for domain in `cat /app/domains.txt`; do
        echo "Prepare domain location configuration: ${domain}"
        cp -vf /app/acme-challenge.conf "${VHOST_DIR}/${domain}.acme-challenge.conf"
    done
    gen_proxy_config
    # notify nginx always, because a not changed config file does not always mean no changes in general (depends on the template, i.e. includes)
    notify_nginx
    # be sure the acme challenge directory exits
    mkdir -p ${ACME_CHALLENGE_DIR}
    echo "Refresh certificates"
    /app/letsencrypt.sh --config /app/config.sh --cron && result=${?} || result=${?}
    if [ ${result} -ne 0 ]; then
        echo "ERROR during certificate refresh: exit code ${result}" >&2
        return ${result}
    fi
    for domain in `cat /app/domains.txt`; do
        echo "copy certificate files and create symlink's: ${domain}"
        cp -vr /app/certs/${domain} /etc/nginx/certs/
        (
            cd /etc/nginx/certs
            ln -vfs ${domain}/fullchain.pem ${domain}.crt
            ln -vfs ${domain}/privkey.pem ${domain}.key
            ln -vfs dhparam.pem ${domain}.dhparam.pem
        )
        echo "cleanup domain location configuration: ${domain}"
        rm -vf "${VHOST_DIR}/${domain}.acme-challenge.conf"
    done
    gen_proxy_config
    # notify nginx always, because a not changed config file does not always mean no changes in general (depends on the template, i.e. includes)
    notify_nginx
}
    
gen_cert_domain_list


