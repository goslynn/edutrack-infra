-- Rutas protegidas: resuelve upstream + valida JWT RS256 + propaga claims como headers internos.

-- 1. Upstream dinámico (misma lógica que upstream.lua)
local path = ngx.var.uri
local service = path:match("^/([^/]+)")

if not service or service == "" then
  return ngx.exit(ngx.HTTP_NOT_FOUND)
end

local pattern = os.getenv("UPSTREAM_HOST_PATTERN") or "{service}:8080"
ngx.var.upstream_host = pattern:gsub("{service}", service)

-- 2. Validación JWT RS256
local function respond_unauthorized(msg)
  ngx.status = ngx.HTTP_UNAUTHORIZED
  ngx.header["Content-Type"] = "application/json"
  ngx.say('{"status":401,"error":"Unauthorized","message":"' .. msg .. '"}')
  return ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

local auth_header = ngx.req.get_headers()["Authorization"]
if not auth_header then
  return respond_unauthorized("Missing Authorization header")
end

local token = auth_header:match("^[Bb]earer%s+(.+)$")
if not token then
  return respond_unauthorized("Invalid Authorization format")
end

local public_key = os.getenv("JWT_PUBLIC_KEY")
if not public_key then
  ngx.log(ngx.ERR, "JWT_PUBLIC_KEY not configured")
  return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

local jwt_lib   = require("resty.jwt")
local validators = require("resty.jwt-validators")

local jwt_obj = jwt_lib:verify(public_key, token, {
  exp = validators.is_not_expired(),
})

if not jwt_obj.valid then
  return respond_unauthorized("Invalid or expired token")
end

-- 3. Propaga claims como headers internos; elimina Authorization
local payload = jwt_obj.payload

ngx.req.set_header("X-User-Id", payload.sub or "")

if type(payload.roles) == "table" then
  ngx.req.set_header("X-User-Roles", table.concat(payload.roles, ","))
elseif payload.roles then
  ngx.req.set_header("X-User-Roles", tostring(payload.roles))
end

ngx.req.clear_header("Authorization")
