#!/usr/bin/env bash
# init.sh — Genera kong/kong.yaml embebiendo la clave pública RS256 del Auth Service.
# Debe ejecutarse ANTES de `docker-compose up`.
#
# Uso:
#   ./kong/scripts/init.sh
#   AUTH_SERVICE_PATH=/ruta/personalizada ./kong/scripts/init.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"   # raíz de edutrack-infra/
AUTH_PATH="${AUTH_SERVICE_PATH:-$(dirname "$INFRA_ROOT")/edutrack-ms-auth}"
PUBKEY_PATH="$AUTH_PATH/src/main/resources/publicKey.pem"
TEMPLATE="$SCRIPT_DIR/../kong.yaml.template"
OUTPUT="$SCRIPT_DIR/../kong.yaml"

# Validaciones
if [ ! -f "$PUBKEY_PATH" ]; then
  echo "ERROR: publicKey.pem no encontrado en: $PUBKEY_PATH"
  echo ""
  echo "Opciones:"
  echo "  1) Ajusta AUTH_SERVICE_PATH apuntando al repo edutrack-ms-auth:"
  echo "     AUTH_SERVICE_PATH=/ruta/a/edutrack-ms-auth $0"
  echo "  2) Asegúrate que el Auth Service generó las llaves (cd auth && openssl genrsa...)"
  exit 1
fi

if [ ! -f "$TEMPLATE" ]; then
  echo "ERROR: template no encontrado en: $TEMPLATE"
  exit 1
fi

echo "→ Usando clave pública desde: $PUBKEY_PATH"

# Genera kong.yaml insertando la clave pública con indentación YAML correcta (6 espacios)
python3 - <<PYEOF
import sys, textwrap

template_path = "$TEMPLATE"
pubkey_path   = "$PUBKEY_PATH"
output_path   = "$OUTPUT"

with open(template_path) as f:
    template = f.read()

with open(pubkey_path) as f:
    pubkey = f.read().rstrip()

# Indenta cada línea de la clave pública con 6 espacios (nivel YAML correcto para rsa_public_key: |)
indented = "\n".join("      " + line for line in pubkey.splitlines())

result = template.replace("__PUBLIC_KEY__", indented)

with open(output_path, "w") as f:
    f.write(result)

print(f"→ Generado: {output_path}")
PYEOF

echo "✓ kong/kong.yaml listo. Ahora puedes ejecutar: docker-compose up -d"
