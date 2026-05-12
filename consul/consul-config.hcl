# Consul agent — configuración para entorno de desarrollo local (single-node)
# En producción → Helm chart multi-node en EKS con TLS y ACLs habilitados.

datacenter = "edutrack-local"
data_dir   = "/consul/data"
log_level  = "INFO"

# ─── Servicios registrados estáticamente ────────────────────────────────────
# En producción, los microservicios se auto-registran via quarkus-consul-client.
# En dev se registran aquí para evitar dependencia de la extensión Quarkus.

services {
  id      = "auth-1"
  name    = "auth"
  address = "auth"
  port    = 8080
  tags    = ["ms", "auth", "jwt-issuer"]

  meta = {
    version = "1"
    schema  = "auth"
  }

  check {
    id       = "auth-health-live"
    name     = "Auth Service — liveness"
    http     = "http://auth:8080/q/health/live"
    interval = "10s"
    timeout  = "5s"
    deregister_critical_service_after = "2m"
  }

  check {
    id       = "auth-health-ready"
    name     = "Auth Service — readiness (DB)"
    http     = "http://auth:8080/q/health/ready"
    interval = "15s"
    timeout  = "5s"
  }
}
