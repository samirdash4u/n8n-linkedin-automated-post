#!/bin/bash

# Create required folder structure for comfyui
for folder in comfy/workspace comfy/models/checkpoints comfy/output
do
	echo mkdir -p $folder
done

# Folder structure for n8n,ollama

for folder in n8n ollama searxng sandboxtls
do
    echo mkdir -p $folder
done
