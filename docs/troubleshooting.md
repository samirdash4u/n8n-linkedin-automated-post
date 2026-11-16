# Troubleshooting

Work from the bottom of the stack up: containers, then service endpoints, then n8n credentials, then the failing node. Most problems show up in the first two steps.

## Step 1: Are the containers healthy?

```bash
./scripts/healthcheck.sh          # one-shot summary
docker compose ps -a
docker compose logs --tail=100 <service>
docker stats --no-stream
```

Expected: `n8n` and `ollama` are `running (healthy)`, `comfyui` and `n8n-runners` are `running`. With the sandbox profile, `sandbox-certs` showing `Exited (0)` is normal. A service in `Restarting` means: read its logs before anything else.

## Step 2: Can n8n reach each service?

Test from inside the n8n container, because that is the network the workflow uses. The n8n image may not include `wget` or `curl`, so use Node:

```bash
probe() { docker compose exec -T n8n node -e "fetch(process.argv[1]).then(r=>r.text()).then(t=>console.log(t.slice(0,300))).catch(e=>{console.error(e.message);process.exit(1)})" "$1"; }
probe http://ollama:11434/api/tags
probe http://comfyui:8188/object_info/CheckpointLoaderSimple
probe http://127.0.0.1:5678/healthz
```

The first must list every model the workflow uses; the second must list a `.safetensors` file.

## Step 3: Find the failing node

1. In n8n open **Executions** and open the failed run.
2. Click the red node. The error panel shows the request and the response body.
3. To iterate quickly, open the last good node, **pin** its output, and run again from the failing node. You skip the LLM and image steps each time.
4. For more detail, set `N8N_LOG_LEVEL: debug` in `docker-compose.yaml` and run `docker compose up -d n8n`, then `docker compose logs -f n8n`.

## Install and containers

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `required variable N8N_ENCRYPTION_KEY is missing` (or another `Set ... in .env`) | No `.env`, or Compose run from another folder | Run `./scripts/pre-setup.sh` and run Compose from the repo root |
| n8n logs `EACCES: permission denied` on `/home/node/.n8n` | `n8n/` created by Docker as root | `sudo chown -R 1000:1000 n8n && docker compose restart n8n` |
| `permission denied` on bind mounts although ownership is right (RHEL) | SELinux label | `sudo chcon -Rt container_file_t n8n ollama comfy searxng sandboxtls`, or add `:z` to the volume lines |
| `Mismatching encryption keys` or stored credentials no longer decrypt | `N8N_ENCRYPTION_KEY` changed | Restore the original key from backup. There is no other way back; otherwise re-create credentials |
| Code nodes hang or fail with task runner errors | Token or version mismatch between `n8n` and `n8n-runners` | Same `N8N_RUNNERS_AUTH_TOKEN` (both read `.env`) and same `N8N_VERSION`; `docker compose up -d --force-recreate n8n n8n-runners` |
| A container keeps restarting; `docker inspect <name> --format '{{.State.OOMKilled}}'` is `true` | Out of memory (Ollama and ComfyUI together) | Smaller models, `numCtx` 4096, add swap, or more RAM |
| `no space left on device` | Models, images, old Docker layers | `docker system df`, `docker image prune`, clean `comfy/output/` |
| n8n waits forever on `sandbox-api` | Old compose file with the sandbox in `depends_on` | Use the current `docker-compose.yaml`; the sandbox is now an optional profile |

## Ollama nodes

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `model "<name>" not found` | Not pulled, or tag differs from the node | `docker compose exec ollama ollama list`; pull the exact tag shown in the node |
| `ECONNREFUSED 127.0.0.1:11434` | Credential uses `localhost` | Base URL `http://ollama:11434` |
| Node runs for minutes or times out | CPU inference with large context | Lower `numCtx` to 4096; keep one model loaded at a time |
| `Failed to parse` / output parser error | Small model returned invalid JSON | Re-run; turn on auto-fix in the parser; move that node to a larger model |
| `Cannot read properties of undefined (reading 'title')` in `Content creator` | Topic agent returned an object instead of an array | Check the topic output is `[{"title":..., "rationale":..., "hook":...}]` |
| Hashtags missing or odd | Model ignored the format | `Build final post` pads to 8 tags from a fallback list; change the fallback there |

## ComfyUI image

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `No checkpoint found in ComfyUI` | Checkpoint missing or in the wrong folder | File must be in `comfy/models/checkpoints/`; re-run `./scripts/post-setup.sh`; `docker compose restart comfyui` |
| `ECONNREFUSED` or timeout on `comfyui:8188` | ComfyUI still starting (first boot installs packages) | `docker compose logs -f comfyui` and wait for "Starting ComfyUI" |
| `Timed out waiting for ComfyUI` after 12 minutes | CPU too slow or the queue is stuck | Open `http://127.0.0.1:8188` on the server (or via SSH tunnel) and check the queue; lower `STEPS` or size; raise `MAX_POLLS` |
| `ComfyUI reported an error` | Bad checkpoint or out of memory | `docker compose logs --tail=200 comfyui` |
| `No image binary found on "Download image"` | ComfyUI returned no file | Check `Download image` output and the file in `comfy/output/` |

## LinkedIn API

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| OAuth popup: `The redirect_uri does not match the registered value` | Redirect URL in the LinkedIn app differs from n8n's | Copy "OAuth Redirect URL" from the n8n credential into the app's Auth tab exactly; check `N8N_PUBLIC_URL` |
| OAuth popup: `unauthorized_scope_error` | Product not added to the app | Add both products ([linkedin-app-setup.md](linkedin-app-setup.md#2-add-products)) |
| Popup closes, credential still not connected | Browser URL differs from `N8N_PUBLIC_URL`, or popup blocked | Open n8n using exactly `N8N_PUBLIC_URL`; allow popups |
| LinkedIn rejects the `http://` redirect URL | Non-localhost HTTP redirect | Use an SSH tunnel and `http://localhost:5678`, or HTTPS ([pre-install.md](pre-install.md#2-decide-the-public-url)) |
| `401` on `Get LinkedIn profile` or later nodes | Token expired (60 days) or `openid profile` missing | Reconnect the credential |
| `403 ACCESS_DENIED` on `/rest/images` or `/rest/posts` | `w_member_social` scope missing | Add the scope, reconnect |
| `426` or `NONEXISTENT_VERSION` | `LinkedIn-Version` header retired | Set a recent `YYYYMM` in `linkedinVersion` in the `Config` node |
| `422` on `Create LinkedIn post` | Text over 3,000 characters, or unescaped reserved characters | Check `post_text` length; keep the escape regex in the node body |
| `Upload image` fails, or post fails with a media error | Upload URL stale or image still processing | Re-run. The upload is initialised only after the image is ready, so a repeat failure usually means a network or token problem; check the node's response body |
| `429` | Rate limit | Post less often |
| Same post published twice | A manual re-run after a timeout on `Create LinkedIn post` | Check your profile before re-running; that node is deliberately not retried |

## Before asking for help

```bash
docker compose version
docker compose ps -a
./scripts/healthcheck.sh
docker compose logs --since=30m n8n n8n-runners ollama comfyui > debug-logs.txt
```

Add the failing node's name and error text from the Executions view. Remove tokens, client secrets and `.env` values before sharing anything.
