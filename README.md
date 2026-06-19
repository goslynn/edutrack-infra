# infra — API Gateway

Único punto de entrada de la plataforma EduTrack. Basado en **OpenResty** (Nginx + LuaJIT): valida JWT RS256, propaga la identidad autenticada como headers internos, enruta dinámicamente al microservicio correspondiente, gestiona CORS y aplica rate limiting.

- **Puerto local:** `8080`
- **App Fly.io:** `edutrack-gateway`

---

## Qué hace

| Responsabilidad | Detalle |
|---|---|
| Enrutamiento dinámico | Extrae el primer segmento del path (`/auth/*` → servicio `auth`) y construye el upstream. Sin lista estática de servicios. |
| Validación JWT RS256 | Verifica firma y expiración. Rechaza con `401` si inválido o ausente (excepto rutas públicas). |
| Propagación de identidad | Extrae `sub` → `X-User-Id` y `roles[]` → `X-User-Roles`. Elimina el header `Authorization` antes de pasar al MS. |
| CORS | Centralizado. Refleja el origin solo si coincide con `CORS_ALLOW_ORIGIN`. |
| Rate limiting | 200 req/min por IP. Bursts diferenciados por tipo de ruta. |
| Correlation ID | Genera `X-Correlation-Id` si el request no lo trae. |

---

## Rutas

### Públicas (sin JWT)

| Método | Patrón | Descripción |
|---|---|---|
| `POST` | `/{servicio}/login` | Login — rate limit burst 20 |
| `POST` | `/{servicio}/refresh` | Refresh token — rate limit burst 20 |
| `GET` | `/{servicio}/.well-known/*` | JWKS — rate limit burst 10 |
| `GET` | `/{servicio}/meta/*` | Metadatos del MS — rate limit burst 20 |

### Protegidas (JWT requerido)

| Método | Patrón | Descripción |
|---|---|---|
| `*` | `/*` | Cualquier otra ruta — JWT validado, rate limit burst 50 |

---

## Contrato de naming (no negociable)

El gateway **no tiene lista de servicios**. El nombre del primer segmento del path es el nombre del servicio:

```
/auth/login     → upstream: auth:8080        (local) / edutrack-auth.fly.internal:8080 (Fly.io)
/course/cursos  → upstream: course:8080      (local) / edutrack-course.fly.internal:8080 (Fly.io)
```

Si el MS se llama `edutrack-courses` en Fly.io, todos sus endpoints deben ir bajo `/courses/` y el contenedor local debe llamarse `courses`.

---

## Stack

| Componente | Versión |
|---|---|
| OpenResty | 1.25.3.1 (Nginx + LuaJIT) |
| lua-resty-jwt | última vía OPM |
| DNS en Fly.io | DNS interno Fly (sin Consul) |

---

## Archivos clave

```
gateway/
├── Dockerfile              ← multi-stage: instala deps + lua-resty-jwt via opm
├── entrypoint.sh           ← extrae DNS resolver, carga JWT_PUBLIC_KEY, envsubst → nginx.conf, inicia openresty
├── nginx.conf.template     ← rate limit, CORS, rutas públicas/protegidas, proxy_pass
└── lua/
    ├── jwt.lua             ← validación RS256, propagación X-User-Id / X-User-Roles
    └── upstream.lua        ← resolución dinámica del upstream por primer segmento del path
```

---

## Variables de entorno

| Variable | Default | Descripción |
|---|---|---|
| `JWT_PUBLIC_KEY` | — | Clave pública RS256 en formato PEM (contenido del archivo) |
| `JWT_PUBLIC_KEY_FILE` | — | Ruta a archivo PEM (el entrypoint carga su contenido en `JWT_PUBLIC_KEY`) |
| `UPSTREAM_HOST_PATTERN` | `{service}:8080` | Template del upstream. En Fly.io: `edutrack-{service}.fly.internal:8080` |
| `CORS_ALLOW_ORIGIN` | `http://localhost:5173` | Origin permitido para CORS |

En desarrollo local, las llaves RS256 se montan desde `.certs/` del monorepo (ver `docker-compose.yml`):

```yaml
volumes:
  - ./.certs:/certs:ro
environment:
  JWT_PUBLIC_KEY_FILE: /certs/publicKey.pem
```

---

## Levantar localmente

Desde la raíz del monorepo (requiere `.certs/publicKey.pem` y `.env` configurados):

```bash
docker compose up gateway
```

El gateway queda disponible en `http://localhost:8080`.

### Generar llaves RS256 (si no existen)

```bash
mkdir .certs
openssl genrsa -out .certs/privateKey.pem 2048
openssl rsa -in .certs/privateKey.pem -pubout -out .certs/publicKey.pem
```

Auth Service usa la clave privada para firmar; el gateway usa la pública para validar. Ambos montan el mismo directorio `.certs/`.

---

## Headers internos propagados

Los microservicios **nunca ven el JWT**. El gateway lo consume y propaga la identidad ya validada:

| Header | Contenido |
|---|---|
| `X-User-Id` | UUID del usuario autenticado (claim `sub`) |
| `X-User-Roles` | UUIDs de roles, separados por coma (claim `roles[]`) |
| `X-Correlation-Id` | ID de trazabilidad (generado si no viene en el request) |

Los MS leen estos headers vía `RequestContext` de `edutrack-ms-commons`. Leerlos a mano está prohibido por convención del equipo.
