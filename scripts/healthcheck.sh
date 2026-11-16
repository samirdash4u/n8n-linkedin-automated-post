#!/usr/bin/env bash
# One-shot status of every service the workflow depends on.
# Checks run from inside the n8n container, i.e. the same network the workflow uses.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

fails=0
pass() { printf '  [PASS] %s\n' "$*"; }
bad()  { printf '  [FAIL] %s\n' "$*"; fails=$((fails + 1)); }

# Fetch a URL from inside the n8n container (the n8n image may not ship wget/curl).
probe() {
  docker compose exec -T n8n node -e "fetch(process.argv[1]).then(async r=>{const t=await r.text();if(!r.ok){console.error('HTTP '+r.status);process.exit(1)}process.stdout.write(t)}).catch(e=>{console.error(e.message);process.exit(1)})" "$1" 2>&1
}

echo "Containers:"
for svc in n8n n8n-runners ollama comfyui; do
  state=$(docker compose ps --format '{{.State}} {{.Health}}' "$svc" 2>/dev/null | head -n1)
  case "$state" in
    running*unhealthy*) bad "$svc: $state" ;;
    running*) pass "$svc: $state" ;;
    *) bad "$svc: ${state:-not created}" ;;
  esac
done

echo "Endpoints (from inside n8n):"
if out=$(probe http://127.0.0.1:5678/healthz); then pass "n8n /healthz"; else bad "n8n /healthz: $out"; fi

if out=$(probe http://ollama:11434/api/tags); then
  pass "Ollama reachable at http://ollama:11434"
  models=$(sed -n 's/^OLLAMA_MODELS=//p' .env 2>/dev/null | tr -d '"')
  for m in ${models:-gemma4:e2b phi4-mini:latest qwen2.5:1.5b}; do
    if grep -q "\"$m\"" <<<"$out"; then pass "model $m"; else bad "model $m not pulled (run ./scripts/post-setup.sh)"; fi
  done
else
  bad "Ollama: $out"
fi

if out=$(probe http://comfyui:8188/object_info/CheckpointLoaderSimple); then
  if grep -q '\.safetensors\|\.ckpt' <<<"$out"; then pass "ComfyUI reachable, checkpoint installed"
  else bad "ComfyUI reachable but no checkpoint in comfy/models/checkpoints"; fi
else
  bad "ComfyUI at http://comfyui:8188: $out (first boot can take several minutes)"
fi

echo
if [ "$fails" -eq 0 ]; then echo "All checks passed."; else echo "$fails check(s) failed. See docs/troubleshooting.md."; exit 1; fi
