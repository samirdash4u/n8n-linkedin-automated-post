# Operations

## Start, stop, inspect

```bash
docker compose config -q                 # validate
docker compose up -d                     # start core services
docker compose --profile search up -d    # also start SearXNG
docker compose ps -a
docker compose logs -f n8n
docker compose restart n8n
docker compose up -d --force-recreate n8n n8n-runners   # after .env changes
docker compose down                      # stop; data in the bind-mounted folders is kept
```

Data lives in host folders (`n8n/`, `ollama/`, `comfy/`, `searxng/`, `sandboxtls/`), not named volumes. `docker compose down -v` does not delete them, but `rm -rf` on those folders does.

## Backups

| Path | Contains | Priority |
| --- | --- | --- |
| `.env` | Secrets, including `N8N_ENCRYPTION_KEY` | Critical; store encrypted, separately |
| `n8n/` | Workflows, credentials database, executions | Critical |
| `sandboxtls/` | Sandbox TLS keys (if used) | Sensitive |
| `searxng/` | SearXNG settings (if used) | Low |
| `ollama/`, `comfy/models/` | Downloaded models | Optional; can be downloaded again |

Stop n8n (`docker compose stop n8n`) before copying `n8n/` so the SQLite database is consistent. Test a restore at least once.

Also export the workflow from the n8n UI after changes and commit it to `workflows/`.

## Upgrades

1. Read the n8n release notes for every version between yours and the target.
2. Back up `n8n/` and `.env`.
3. Set `N8N_VERSION` in `.env` (this moves both `n8n` and `n8n-runners`).
4. `docker compose pull && docker compose up -d`.
5. Run `./scripts/healthcheck.sh` and one manual workflow execution.

`OLLAMA_VERSION` and `SEARXNG_VERSION` default to `latest`; pin them in `.env` once you have a known-good version.

## Monitoring

```bash
docker compose ps
docker stats --no-stream
df -h
free -h
```

Watch for container restarts, memory pressure, disk use by `ollama/` and `comfy/output/`, and failed executions in n8n. An Error Workflow in n8n is the simplest alert for failed posts.

Configure Docker log rotation in `/etc/docker/daemon.json`:

```json
{ "log-driver": "json-file", "log-opts": { "max-size": "10m", "max-file": "3" } }
```

## Security checklist

- [ ] Unique random secrets for every purpose (pre-setup generates them).
- [ ] `.env` mode 600 and never committed.
- [ ] `N8N_ENCRYPTION_KEY` backed up.
- [ ] Only port 5678 reachable, and only from trusted networks; use a TLS reverse proxy for anything wider.
- [ ] Ollama, ComfyUI, SearXNG and the sandbox not exposed publicly.
- [ ] The privileged sandbox runner (if used) isolated from sensitive workloads.
- [ ] Image versions pinned; upgrades tested.
- [ ] Log rotation and disk alerts configured.
- [ ] Any secret that appeared in a terminal, screenshot, log or chat rotated.
