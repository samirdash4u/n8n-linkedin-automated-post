# Configuration

## Brand and topics

The topic agent (`Content topic generator`) carries the brand prompt: who you are, your audience and six content themes. It is written for a fictional agency ("Agentic Vibe"). Replace the company description and themes with your own. Keep the output format section unchanged; the next nodes depend on `title`, `rationale` and `hook`.

The post style (length under 1,300 characters, closing question, no hashtags in the body) is set in `Content creator`.

## Schedule

`Schedule Trigger` -> interval. Default every 6 hours.

## Models

| Node | Default model | Role |
| --- | --- | --- |
| Ollama Chat Model | `gemma4:e2b` | Topic ideas (agent) |
| Ollama Model | `phi4-mini:latest` | Post text and image brief |
| Ollama Chat Model1 | `qwen2.5:1.5b` | Hashtags and output auto-fix |

To change a model: pull it (`docker compose exec ollama ollama pull <tag>`), select it in the node, and update `OLLAMA_MODELS` in `.env` so `post-setup.sh` and `healthcheck.sh` stay in sync.

Small models are fast on CPU but sometimes return invalid JSON. If a parser fails often, move that node to a larger model (for example `qwen3:4b` or an 8B model if you have 32 GB RAM). `numCtx` is 8192 on all three; lowering it to 4096 saves memory and time.

## Image

Edit the constants at the top of `Build ComfyUI request`:

| Constant | Default | Notes |
| --- | --- | --- |
| `CHECKPOINT` | `''` (first installed) | File name in `comfy/models/checkpoints/` |
| `WIDTH`, `HEIGHT` | 768 x 400 | Multiples of 8; use 1024 x 536 for SDXL |
| `STEPS` | 20 | Fewer is faster on CPU, lower quality |
| `CFG` | 7 | Prompt adherence |

`Check ComfyUI result` polls every 8 seconds up to `MAX_POLLS = 90` (12 minutes). Raise it on slow hardware.

## ComfyUI startup script

`comfy/supervisor-comfyui.sh` is mounted read-only over the ai-dock image's own startup script. If you change the ComfyUI image tag, compare the two and carry over any changes.
