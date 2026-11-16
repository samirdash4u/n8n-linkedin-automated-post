#!/usr/bin/env bash
# Pre-install checks and one-time setup.
# Run from anywhere: ./scripts/pre-setup.sh
#   1st run: checks the host, creates folders, creates .env with generated secrets.
#   2nd run (after you edit .env): validates .env and the Compose file.
set -euo pipefail
cd "$(dirname "$0")/.."

ok()   { printf '  [OK]   %s\n' "$*"; }
warn() { printf '  [WARN] %s\n' "$*"; }
fail() { printf '  [FAIL] %s\n' "$*"; exit 1; }

echo "Checking host..."
command -v docker >/dev/null 2>&1 || fail "Docker is not installed"
docker info >/dev/null 2>&1 || fail "Docker daemon is not running, or this user cannot use it (try sudo or add yourself to the docker group)"
docker compose version >/dev/null 2>&1 || fail "Docker Compose v2 plugin is missing (docker compose ...)"
command -v openssl >/dev/null 2>&1 || fail "openssl is required to generate secrets"
ok "Docker $(docker version --format '{{.Server.Version}}' 2>/dev/null), $(docker compose version --short)"

if [ -r /proc/meminfo ]; then
  mem_gb=$(awk '/MemTotal/ {print int($2/1024/1024 + 0.5)}' /proc/meminfo)
  if [ "$mem_gb" -ge 16 ]; then ok "${mem_gb} GB RAM"; else warn "${mem_gb} GB RAM; 16 GB recommended (Ollama + ComfyUI on CPU)"; fi
fi
free_gb=$(df -Pk . | awk 'NR==2 {print int($4/1024/1024)}')
if [ "$free_gb" -ge 20 ]; then ok "${free_gb} GB free disk"; else warn "${free_gb} GB free disk; 20 GB recommended (models + images)"; fi

echo "Creating folders..."
mkdir -p n8n ollama searxng sandboxtls \
         comfy/workspace comfy/models/checkpoints comfy/output
# n8n runs as uid 1000 inside the container and must own its data folder.
if [ "$(stat -c %u n8n)" != "1000" ]; then
  if [ "$(id -u)" -eq 0 ]; then chown -R 1000:1000 n8n; else sudo chown -R 1000:1000 n8n; fi
fi
ok "n8n/ ollama/ searxng/ sandboxtls/ comfy/{workspace,models/checkpoints,output}"

if [ ! -f .env ]; then
  echo "Creating .env..."
  cp .env.example .env
  for v in N8N_ENCRYPTION_KEY N8N_RUNNERS_AUTH_TOKEN SEARXNG_SECRET; do
    sed -i "s|^$v=.*|$v=$(openssl rand -hex 32)|" .env
  done
  chmod 600 .env
  ok ".env created with generated secrets (back up N8N_ENCRYPTION_KEY somewhere safe)"
  echo
  echo "Next: edit .env and set N8N_HOST and N8N_PUBLIC_URL, then run this script again."
  exit 0
fi

echo "Validating .env..."
if grep -Ev '^\s*#' .env | grep -q '<'; then
  grep -Ev '^\s*#' .env | grep -n '<' | sed 's/=.*/=<placeholder>/' || true
  fail ".env still contains <placeholders>; replace them"
fi
[ "$(stat -c %a .env)" = "600" ] || { chmod 600 .env; warn "tightened .env permissions to 600"; }
docker compose config -q || fail "docker compose config failed; see the error above"
ok ".env and docker-compose.yaml are valid"

echo
echo "Pre-setup complete. Next:"
echo "  docker compose up -d"
echo "  ./scripts/post-setup.sh"
