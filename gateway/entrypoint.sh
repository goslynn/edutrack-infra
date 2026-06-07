#!/bin/sh
set -eu

# Extrae el DNS resolver del sistema (Docker y Fly.io lo configuran en /etc/resolv.conf)
RESOLVER=$(awk '/^nameserver/{print $2; exit}' /etc/resolv.conf)
export RESOLVER

# Clave pública RS256 (validación de tokens).
#   - Dev local: se monta el archivo físico desde el .certs/ de la raíz
#     (EDUTRACK_CERTS_DIR) en /certs y su ruta se inyecta en JWT_PUBLIC_KEY_FILE;
#     aquí se carga su contenido en
#     JWT_PUBLIC_KEY, que es lo que consume el Lua (os.getenv). Evita el frágil
#     PEM multilínea en .env (compose env_file no soporta valores multilínea).
#   - Fly.io: NO se monta archivo. JWT_PUBLIC_KEY ya viene como secret
#     (fly secrets set JWT_PUBLIC_KEY="$(cat publicKey.pem)") y este bloque se
#     omite, preservando el comportamiento productivo sin tocar el Lua.
if [ -n "${JWT_PUBLIC_KEY_FILE:-}" ]; then
  if [ ! -f "$JWT_PUBLIC_KEY_FILE" ]; then
    echo "entrypoint: JWT_PUBLIC_KEY_FILE='$JWT_PUBLIC_KEY_FILE' no existe (¿montaste EDUTRACK_CERTS_DIR, por defecto ./.certs?)" >&2
    exit 1
  fi
  JWT_PUBLIC_KEY=$(cat "$JWT_PUBLIC_KEY_FILE")
  export JWT_PUBLIC_KEY
fi

envsubst '${RESOLVER}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

# -c es obligatorio: sin él openresty carga su config por defecto
#   (/usr/local/openresty/nginx/conf/nginx.conf, listen 80) e ignora la nuestra.
exec openresty -c /etc/nginx/nginx.conf -g 'daemon off;'
