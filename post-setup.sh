#!/bin/bash


docker exec ollama ollama pull phi4-mini:latest
docker exec ollama ollama pull qwen2.5:1.5b
docker exec ollama ollama pull gemma4:e2b

cd comfy/models/checkpoints
wget https://huggingface.co/Comfy-Org/stable-diffusion-v1-5-archive/resolve/main/v1-5-pruned-emaonly-fp16.safetensors
