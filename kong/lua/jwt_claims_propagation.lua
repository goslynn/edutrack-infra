-- Extrae claims del JWT ya validado y los propaga como headers internos.
-- Corre DESPUÉS del plugin jwt (post-function priority=0 < jwt priority=1005).
-- Elimina Authorization antes de llegar al microservicio.

local token = kong.request.get_header("authorization")
if not token then return end

local stripped = token:match("^[Bb]earer%s+(.+)$")
if not stripped then return end

local _, payload_b64 = stripped:match("^([^.]+)%.([^.]+)")
if not payload_b64 then return end

local pad = (4 - #payload_b64 % 4) % 4
local b64 = payload_b64:gsub("%-", "+"):gsub("_", "/") .. ("="):rep(pad)

local decoded = ngx.decode_base64(b64)
if not decoded then return end

local ok, claims = pcall(require("cjson").decode, decoded)
if not ok or not claims then return end

kong.service.request.set_header("X-User-Id", claims.sub or "")

if type(claims.roles) == "table" then
  kong.service.request.set_header("X-User-Roles", table.concat(claims.roles, ","))
elseif claims.roles then
  kong.service.request.set_header("X-User-Roles", tostring(claims.roles))
end

kong.service.request.clear_header("authorization")
