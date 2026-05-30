#!/bin/sh
set -eu

# Extrae el DNS resolver del sistema (Docker y Fly.io lo configuran en /etc/resolv.conf)
RESOLVER=$(awk '/^nameserver/{print $2; exit}' /etc/resolv.conf)
export RESOLVER

envsubst '${RESOLVER}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

exec openresty -g 'daemon off;'
