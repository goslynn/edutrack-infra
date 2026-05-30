FROM openresty/openresty:1.25.3.2-alpine

# lua-resty-jwt: validación RS256
RUN opm get cdbattags/lua-resty-jwt

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

COPY nginx.conf.template /etc/nginx/nginx.conf.template
COPY lua/ /etc/nginx/lua/

EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
