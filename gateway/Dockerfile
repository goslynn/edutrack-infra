FROM openresty/openresty:1.25.3.1-alpine

# gettext provee envsubst (usado en entrypoint para inyectar el DNS resolver)
# perl y curl son requeridos por `opm` (es un script Perl que descarga con curl);
#   sin ellos `opm get` falla ("can't execute 'perl'" / "curl: not found") y la
#   imagen no construye.
# lua-resty-jwt: validación RS256
RUN apk add --no-cache gettext perl curl && opm get cdbattags/lua-resty-jwt

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

COPY nginx.conf.template /etc/nginx/nginx.conf.template
COPY lua/ /etc/nginx/lua/

EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
