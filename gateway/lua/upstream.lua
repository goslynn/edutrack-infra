-- Resuelve el upstream destino a partir del primer segmento del path.
-- /auth/login  → auth  → UPSTREAM_HOST_PATTERN con {service}=auth
-- /.well-known → usa JWKS_SERVICE (default: auth)

local path = ngx.var.uri
local service = path:match("^/([^/]+)")

if not service or service == "" then
  return ngx.exit(ngx.HTTP_NOT_FOUND)
end

local pattern = os.getenv("UPSTREAM_HOST_PATTERN") or "{service}:8080"
ngx.var.upstream_host = pattern:gsub("{service}", service)
