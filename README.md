# n8n LinkedIn automated post

A self-hosted n8n workflow that writes and publishes a LinkedIn post with an AI-generated image, on a schedule. Text comes from local LLMs in Ollama, the image from Stable Diffusion in ComfyUI, and the post goes out through the official LinkedIn API. No paid AI APIs are needed.

## How it works

```
Schedule (every 6 h)
  -> Ollama: topic ideas        (gemma4:e2b)
  -> Ollama: post + image brief (phi4-mini)
  -> Ollama: hashtags           (qwen2.5:1.5b)  -> clean and cap at 10
  -> ComfyUI: render image      (Stable Diffusion 1.5, CPU)
  -> LinkedIn API: upload image, publish post
```

| Service | Purpose | Address used by n8n |
| --- | --- | --- |
| `n8n` | Runs the workflow | `http://<server>:5678` (browser) |
| `n8n-runners` | Executes the workflow's Code nodes | broker `http://n8n:5679` |
| `ollama` | Local LLM inference | `http://ollama:11434` |
| `comfyui` | Image generation | `http://comfyui:8188` |
| `searchbox` (optional) | SearXNG web search | `http://searchbox:8080` |
| `sandbox-*` (optional) | n8n AI Assistant code sandbox | `http://sandbox-api:8080/` |

The optional services are not used by the LinkedIn workflow and only start with `--profile search` or `--profile sandbox`. See [docs/optional-services.md](docs/optional-services.md).

## Requirements

| Item | Minimum |
| --- | --- |
| OS | Linux (tested on RHEL 8); any host with Docker should work |
| Docker | Engine 24+ with the Compose v2 plugin (`docker compose`) |
| RAM | 16 GB (Ollama and ComfyUI both run on CPU) |
| Disk | 20 GB free (models about 6 GB, checkpoint 2 GB, images) |
| LinkedIn | A personal account, plus a Company Page you admin to own the developer app |

## Quick start

```bash
git clone https://github.com/samirdash4u/n8n-linkedin-automated-post.git
cd n8n-linkedin-automated-post

./scripts/pre-setup.sh      # checks host, creates folders and .env
vi .env                     # set N8N_HOST and N8N_PUBLIC_URL
./scripts/pre-setup.sh      # validates .env

docker compose up -d
./scripts/post-setup.sh     # pulls models, downloads checkpoint, runs health check
```

Then:

1. Create the LinkedIn developer app: [docs/linkedin-app-setup.md](docs/linkedin-app-setup.md).
2. Open `N8N_PUBLIC_URL`, create the owner account, and import `workflows/linkedin-autopost.json`.
3. Create the Ollama and LinkedIn credentials and do a test run: [docs/post-install.md](docs/post-install.md).

## Documentation

| Page | What it covers |
| --- | --- |
| [docs/pre-install.md](docs/pre-install.md) | Host checks, folders, `.env`, firewall |
| [docs/linkedin-app-setup.md](docs/linkedin-app-setup.md) | LinkedIn developer app, products, scopes, redirect URL |
| [docs/post-install.md](docs/post-install.md) | Models, n8n credentials, smoke test, going live |
| [docs/configuration.md](docs/configuration.md) | Brand prompt, schedule, models, image size |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Debug guide and symptom tables |
| [docs/operations.md](docs/operations.md) | Backups, upgrades, monitoring, security checklist |
| [docs/optional-services.md](docs/optional-services.md) | SearXNG and the n8n Sandbox |

## Customise

The topic prompt is written for a fictional agency ("Agentic Vibe"). Change it to your own brand, audience and themes before going live. Schedule, models and image settings are covered in [docs/configuration.md](docs/configuration.md).

## License

GPL-3.0. See [LICENSE](LICENSE).
