# n8n + Ollama + SearXNG + Sandbox

Deployment guide for the RHEL 8 Docker Compose stack on

## 1. Services

  ---------------------------------------------------------------------------
  Service                 Purpose                 Internal endpoint
  ----------------------- ----------------------- ---------------------------
  n8n                     Workflow automation     `http://n8n:5678`

  Ollama                  Local LLM inference     `http://ollama:11434`

  SearXNG (`searchbox`)   Web search              `http://searchbox:8080`

  n8n task runners        n8n task execution      Broker: `http://n8n:5679`

  Sandbox API             AI Assistant code       `http://sandbox-api:8080`
                          sandbox API             

  Sandbox runner          Executes isolated       `sandbox-api:9090`
                          sandbox workloads       registration; control on
                                                  `sandbox-runner-1:9091`

  sandbox-certs           Generates API/runner    One-shot init; `Exited (0)`
                          mTLS certificates       is expected
  ---------------------------------------------------------------------------

The deployment directory used during setup:

``` text
/
├── docker-compose.yml
├── .env
├── n8n/
├── ollama/
├── searxng/
└── sandboxtls/
```

The versions observed during setup were n8n `2.45.4` and sandbox
API/runner/sandbox `1.9.0`. Verify the actual image tags in your Compose
file. Pin tested versions for production; avoid unreviewed `latest`
tags.

## 2. Prerequisites

-   RHEL 8, Docker Engine and Docker Compose plugin.
-   Adequate RAM, disk space and (optionally) supported GPU access.
-   Access to the configured image registry for initial pulls, or
    preloaded images.
-   Firewall rules limiting access to service ports.

The sandbox runner uses privileged Docker-in-Docker. Isolate it from
sensitive workloads. Never expose its Docker daemon ports publicly.

## 3. Environment configuration

Create `.env` beside `docker-compose.yml`. Example template:

``` dotenv
TZ=Asia/Kolkata

N8N_HOST=<server-hostname-or-ip>
N8N_PROTOCOL=http
N8N_ENCRYPTION_KEY=<unique-random-secret>
N8N_RUNNERS_AUTH_TOKEN=<different-random-secret>

# n8n -> Sandbox API
SANDBOX_API_KEYS=<sandbox-api-key>
N8N_SANDBOX_SERVICE_API_KEY=<same-value-as-SANDBOX_API_KEYS>

# API -> runner registration
SANDBOX_API_RUNNER_REGISTRATION_TOKEN=<registration-secret>
SANDBOX_RUNNER_REGISTRATION_TOKEN=<same-value-as-SANDBOX_API_RUNNER_REGISTRATION_TOKEN>

# API -> runner control API
SANDBOX_API_RUNNER_API_KEY=<runner-control-secret>
SANDBOX_RUNNER_API_KEYS=<same-value-as-SANDBOX_API_RUNNER_API_KEY>
```

Generate random secrets on the host:

``` bash
openssl rand -hex 32
```

Credential pairs must match exactly:

  -----------------------------------------------------------------------------
  Pair                                      Must match?
  ----------------------------------------- -----------------------------------
  `SANDBOX_API_KEYS` ↔                      Yes
  `N8N_SANDBOX_SERVICE_API_KEY`             

  `SANDBOX_API_RUNNER_REGISTRATION_TOKEN` ↔ Yes
  `SANDBOX_RUNNER_REGISTRATION_TOKEN`       

  `SANDBOX_API_RUNNER_API_KEY` ↔            Yes
  `SANDBOX_RUNNER_API_KEYS`                 

  `N8N_RUNNERS_AUTH_TOKEN`                  Must match between n8n and n8n
                                            task-runner service
  -----------------------------------------------------------------------------

Use a different secret for each purpose. Do not reuse one token for all
variables.

Protect `.env` and exclude it from source control:

``` bash
chmod 600 .env
printf '\n.env\n' >> .gitignore
```

Never paste secret values into tickets, chat, screenshots or logs.

## 4. Start, stop and inspect Compose

``` bash
cd /root/Samir/n8n-setup

# Validate Compose configuration
docker compose config -q

# Start all services
docker compose up -d

# List running and stopped services
docker compose ps -a

# Follow all logs
docker compose logs -f

# Follow selected service logs
docker compose logs -f n8n ollama searchbox sandbox-api sandbox-runner-1

# Restart a service
docker compose restart n8n

# Recreate after environment/config changes
docker compose up -d --force-recreate sandbox-api sandbox-runner-1

# Stop containers; retain persistent data
docker compose down
```

Do not use `docker compose down -v` unless you intentionally want to
delete named volumes. Host bind-mounted directories also contain
persistent data.

Expected status: - Long-running services: `Up`. - Health-checked
services: `Up (healthy)`. - `sandbox-certs`: `Exited (0)` is normal; it
is a one-shot initialization service.

## 5. Sandbox certificates and n8n configuration

The `sandbox-certs` service creates mutual-TLS material used by the API
and runner. On initial deployment:

``` bash
docker compose up -d
docker compose ps -a sandbox-certs
docker compose logs sandbox-certs
find sandboxtls -maxdepth 3 -type f -print
```

Do not regenerate certificates casually while the stack is running.
Rotate them only with a coordinated plan and recreate both API and
runner so they use the same CA and matching certificates.

In n8n's AI Assistant / code sandbox settings select **n8n Sandbox** and
configure:

-   Service URL: `http://sandbox-api:8080/`
-   API key: value of `N8N_SANDBOX_SERVICE_API_KEY`, equal to
    `SANDBOX_API_KEYS`.

Use the internal Docker service name and port. Do not use `localhost`,
the host-published port, or the n8n task-runner broker URL
(`http://n8n:5679`).

### Sandbox troubleshooting

``` bash
docker compose ps -a sandbox-api sandbox-runner-1
docker compose logs --since=10m sandbox-api sandbox-runner-1
```

Compare API/runner control keys without revealing their values:

``` bash
docker compose exec sandbox-api sh -c 'printf "%s" "$SANDBOX_API_RUNNER_API_KEY" | sha256sum'
docker compose exec sandbox-runner-1 sh -c 'printf "%s" "$SANDBOX_RUNNER_API_KEYS" | sha256sum'
```

Hashes must match.

Compare registration tokens similarly:

``` bash
docker compose exec sandbox-api sh -c 'printf "%s" "$SANDBOX_API_RUNNER_REGISTRATION_TOKEN" | sha256sum'
docker compose exec sandbox-runner-1 sh -c 'printf "%s" "$SANDBOX_RUNNER_REGISTRATION_TOKEN" | sha256sum'
```

Hashes must match.

  --------------------------------------------------------------------------------------
  Error                                              Check
  -------------------------------------------------- -----------------------------------
  `Invalid url`                                      Use `http://sandbox-api:8080/`

  HTTP `401` from `/sandboxes`                       Compare n8n
                                                     `N8N_SANDBOX_SERVICE_API_KEY` with
                                                     API `SANDBOX_API_KEYS`

  `no sandbox runners are registered or available`   Check runner startup, registration
                                                     token and runner health

  `invalid api key` during `runner control create`   Compare API control key with runner
                                                     accepted key

  `tls: bad certificate`                             Check client/server cert and key,
                                                     CA trust and certificate SAN names

  Runner bridge-netfilter error                      Check host `br_netfilter` and RHEL
                                                     8 nested-Docker/network-namespace
                                                     compatibility for the exact runner
                                                     image tag
  --------------------------------------------------------------------------------------

Never disable TLS verification to work around a certificate error.

## 6. Ollama models

Start Ollama and check its status:

``` bash
docker compose ps ollama
docker compose exec ollama ollama --version
docker compose exec ollama ollama list
```

Recommended starter models:

``` bash
# General-purpose chat and agent workflows
docker compose exec ollama ollama pull qwen3:8b

# Code generation, debugging and scripting
docker compose exec ollama ollama pull qwen2.5-coder:7b

# Embeddings for RAG / vector search
docker compose exec ollama ollama pull nomic-embed-text
```

  -------------------------------------------------------------------------
  Model                 Recommended use             Approx. download size\*
  --------------------- ---------------------- ----------------------------
  `qwen3:8b`            General chat,                             \~5--6 GB
                        reasoning, agent       
                        workflows              

  `qwen2.5-coder:7b`    Python, shell, SQL,                       \~4--5 GB
                        code                   
                        generation/debugging   

  `nomic-embed-text`    Embeddings for                             \~0.3 GB
                        document retrieval /   
                        RAG                    
  -------------------------------------------------------------------------

\*Actual size depends on the model manifest and quantization. Check the
current Ollama model catalogue and `ollama list` before sizing storage.

You do not need all three immediately. Start with `qwen3:8b`. Add the
coder model for code-centric workflows. Pull the embedding model only if
using a vector database or RAG.

### Hardware considerations

Model performance depends on RAM/VRAM, context length, quantization and
concurrent requests.

-   CPU-only or limited memory: start with a smaller model such as
    `qwen3:4b` or `qwen2.5:3b`; generation may be slower.
-   Around 16 GB system RAM: an 8B quantized model may run, but reserve
    memory for n8n, Docker and other services.
-   32 GB+ RAM or suitable GPU VRAM: 8B models are a more comfortable
    starting point; larger models need more memory.
-   GPU acceleration requires compatible host drivers and container GPU
    access; installing a driver alone does not ensure Ollama can use the
    GPU.

Check host resources:

``` bash
free -h
df -h
docker stats
```

Test Ollama:

``` bash
docker compose exec ollama ollama list
docker compose exec ollama ollama run qwen3:8b
curl http://localhost:11434/api/tags
```

From n8n, use:

``` text
http://ollama:11434
```

Use the exact model tag shown by `ollama list`.

## 7. SearXNG

Host endpoint is normally `http://<server>:8080` based on the current
port mapping. From other Compose services, use:

``` text
http://searchbox:8080
```

Test JSON search:

``` bash
curl -sS "http://localhost:8080/search?q=kubernetes&format=json" | head
```

JSON output must be enabled in SearXNG's settings. An HTTP `403` can
indicate JSON format is disabled or the limiter is rejecting the
request. Inspect configuration and logs:

``` bash
docker compose logs --tail=100 searchbox
```

## 8. n8n task runners vs Sandbox

These are separate components:

-   n8n task runners connect to the n8n broker at `http://n8n:5679`.
-   The AI Assistant's code sandbox provider connects to
    `http://sandbox-api:8080/`.
-   Do not enter `http://n8n:5679` as the Sandbox service URL; it is not
    the Sandbox API.

Inspect task-runner logs:

``` bash
docker compose logs --tail=100 n8n-runners
```

If your Compose service has a different name, get it with:

``` bash
docker compose config --services
```

## 9. Backups, upgrades and monitoring

Back up at least:

-   `n8n/`: workflows, credentials database and n8n state.
-   `searxng/`: SearXNG configuration.
-   `sandboxtls/`: TLS private keys and certificates; protect as
    sensitive.
-   `.env`: deployment secrets; store encrypted and separately.
-   `ollama/`: model data (optional if models can be downloaded again).

For consistent backups, quiesce or stop services that are actively
writing before copying data. Test restoration.

Upgrade only after reviewing compatibility and release notes:

``` bash
docker compose pull
docker compose up -d
```

Keep n8n task-runner versions compatible with n8n, and keep sandbox API,
runner and sandbox images on compatible release tags. Test upgrades
before production rollout.

Useful monitoring commands:

``` bash
docker compose ps
docker stats
df -h
free -h
```

Monitor CPU and memory per container, host memory pressure, Docker disk
usage, model storage, container restarts, health status, sandbox
creation failures, and Ollama inference latency/errors.

## 10. Security checklist

-   [ ] Use unique, random secrets for every credential purpose.
-   [ ] Keep `.env` out of Git and set restrictive permissions.
-   [ ] Back up `N8N_ENCRYPTION_KEY`; losing it can make stored
    credentials unusable.
-   [ ] Do not expose Ollama, Sandbox API gRPC, runner control gRPC or
    Docker daemon ports publicly.
-   [ ] Restrict n8n and SearXNG host ports to trusted networks or
    protect them behind an authenticated TLS reverse proxy.
-   [ ] Isolate the privileged sandbox runner from sensitive host
    workloads.
-   [ ] Pin image versions and test upgrades before deployment.
-   [ ] Configure Docker log rotation and disk-space alerts.
-   [ ] Test backup restoration and host reboot recovery.
-   [ ] Rotate any credentials exposed in terminals, screenshots, logs
    or chat.

## 11. Quick start

For an already configured host:

``` bash
cd /root/Samir/n8n-setup

docker compose config -q
docker compose up -d
docker compose ps -a

# First-time model downloads
docker compose exec ollama ollama pull qwen3:8b
docker compose exec ollama ollama pull qwen2.5-coder:7b
docker compose exec ollama ollama pull nomic-embed-text

docker compose logs --tail=100 n8n ollama searchbox sandbox-api sandbox-runner-1
```

Configure endpoints in n8n:

  Integration   URL
  ------------- ----------------------------
  Ollama        `http://ollama:11434`
  SearXNG       `http://searchbox:8080`
  n8n Sandbox   `http://sandbox-api:8080/`

