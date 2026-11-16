# Pre-install

Goal: a host where `docker compose up -d` works the first time, with folders, permissions and a filled-in `.env`.

## 1. Check the host

| Check | Command | Need |
| --- | --- | --- |
| Docker Engine | `docker version` | 24 or newer, daemon running |
| Compose plugin | `docker compose version` | v2 |
| RAM | `free -h` | 16 GB recommended |
| Disk | `df -h .` | 20 GB free |
| openssl | `openssl version` | any (used to generate secrets) |

`scripts/pre-setup.sh` runs all of these for you and stops on the first hard failure.

## 2. Decide the public URL

Pick the URL you will type in the browser to reach n8n, for example `http://192.168.1.20:5678`. Put it in `N8N_PUBLIC_URL`. LinkedIn redirects back to this URL after sign-in, so it must match exactly.

LinkedIn may refuse plain `http://` redirect URLs that are not `localhost`. If it does, either open n8n through an SSH tunnel (`ssh -L 5678:localhost:5678 <server>` and use `http://localhost:5678`) or put n8n behind a reverse proxy with TLS and use the `https://` URL.

## 3. Run pre-setup

```bash
./scripts/pre-setup.sh
```

First run:

- creates `n8n/`, `ollama/`, `searxng/`, `sandboxtls/` and `comfy/{workspace,models/checkpoints,output}`
- gives `n8n/` to uid 1000 (the user n8n runs as inside the container)
- copies `.env.example` to `.env`, fills `N8N_ENCRYPTION_KEY`, `N8N_RUNNERS_AUTH_TOKEN` and `SEARXNG_SECRET` with random values, and sets mode 600

Edit `.env`, set `N8N_HOST` and `N8N_PUBLIC_URL`, then run the script again. The second run fails if any `<placeholder>` is left and validates the Compose file.

Back up `N8N_ENCRYPTION_KEY` now. If it is lost, every credential stored in n8n has to be re-created.

## 4. Create the LinkedIn app

Do this before post-install so the Client ID and Secret are ready: [linkedin-app-setup.md](linkedin-app-setup.md).

## 5. Firewall

Only port 5678 (n8n) needs to be reachable, and only from your own network. Ollama, ComfyUI, SearXNG and the sandbox are reached by n8n over the internal Docker network. ComfyUI and SearXNG are published on `127.0.0.1` only.

On RHEL with firewalld:

```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=192.168.1.0/24 port port=5678 protocol=tcp accept'
sudo firewall-cmd --reload
```

On SELinux-enforcing hosts, if containers get `permission denied` on the bind-mounted folders, see [troubleshooting.md](troubleshooting.md#install-and-containers).

Next: `docker compose up -d`, then [post-install.md](post-install.md).
