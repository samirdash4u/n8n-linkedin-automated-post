#!/usr/bin/env bash
# Post-install: download the Ollama models and the ComfyUI checkpoint the
# workflow needs, then run the health check. Safe to re-run.
set -euo pipefail
cd "$(dirname "$0")/.."

# Models the workflow uses. Override with OLLAMA_MODELS in .env.
OLLAMA_MODELS_DEFAULT="gemma4:e2b phi4-mini:latest qwen2.5:1.5b"
if [ -f .env ]; then
  OLLAMA_MODELS=$(sed -n 's/^OLLAMA_MODELS=//p' .env | tr -d '"')
fi
OLLAMA_MODELS=${OLLAMA_MODELS:-$OLLAMA_MODELS_DEFAULT}

CKPT_URL="https://huggingface.co/Comfy-Org/stable-diffusion-v1-5-archive/resolve/main/v1-5-pruned-emaonly-fp16.safetensors"
CKPT="comfy/models/checkpoints/v1-5-pruned-emaonly-fp16.safetensors"

echo "Waiting for Ollama to be ready..."
for _ in $(seq 1 60); do
  docker compose exec -T ollama ollama list >/dev/null 2>&1 && break
  sleep 5
done
docker compose exec -T ollama ollama list >/dev/null 2>&1 || { echo "Ollama did not become ready; check: docker compose logs ollama"; exit 1; }

for m in $OLLAMA_MODELS; do
  echo "Pulling Ollama model $m..."
  docker compose exec -T ollama ollama pull "$m"
done

mkdir -p "$(dirname "$CKPT")"
if [ -s "$CKPT" ]; then
  echo "ComfyUI checkpoint already present: $CKPT"
else
  echo "Downloading ComfyUI checkpoint (about 2 GB)..."
  if command -v wget >/dev/null 2>&1; then
    wget -c -O "$CKPT.part" "$CKPT_URL"
  else
    curl -fL -C - -o "$CKPT.part" "$CKPT_URL"
  fi
  mv "$CKPT.part" "$CKPT"
fi

echo
./scripts/healthcheck.sh
