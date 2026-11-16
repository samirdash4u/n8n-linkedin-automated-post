# Post-install

Goal: one manual run publishes a post. Keep the workflow inactive until then.

## 1. Models and health check

```bash
docker compose up -d
./scripts/post-setup.sh
```

The script waits for Ollama, pulls every model in `OLLAMA_MODELS` (`.env`), downloads the Stable Diffusion 1.5 checkpoint (about 2 GB) to `comfy/models/checkpoints/`, then runs `scripts/healthcheck.sh`. It is safe to re-run; finished downloads are skipped.

All lines should show `[PASS]`. If not, see [troubleshooting.md](troubleshooting.md). On first boot ComfyUI installs packages and can take several minutes before it answers.

## 2. Set up n8n

1. Open `N8N_PUBLIC_URL` and create the owner account.
2. **Import:** Workflows -> Import from file -> `workflows/linkedin-autopost.json`.
3. **Ollama credential:** Credentials -> Add credential -> Ollama. Base URL `http://ollama:11434` (not `localhost`). Open `Ollama Chat Model`, `Ollama Model` and `Ollama Chat Model1` and select it.
4. **LinkedIn credential:** create the OAuth2 API credential as in [linkedin-app-setup.md](linkedin-app-setup.md#4-create-the-credential-in-n8n). Select it in `Get LinkedIn profile`, `Init image upload`, `Upload image` and `Create LinkedIn post`.
5. Open the `Config` node and check `linkedinVersion` is a recent `YYYYMM` LinkedIn API version.
6. Edit the topic prompt in `Content topic generator` for your own brand ([configuration.md](configuration.md)).

## 3. Smoke test without posting

1. Right-click `Create LinkedIn post` -> **Deactivate**.
2. Click **Execute workflow**.
3. Check each node's output:

| Node | Expect |
| --- | --- |
| Content topic generator | An array of `{title, rationale, hook}` |
| Content creator | `post title`, `post content`, `image description` |
| Build final post | `post_text` ending in 8 to 10 hashtags |
| Get LinkedIn profile | A `sub` field (your member id) |
| Download image | A PNG in the `data` binary field |

4. Look at the image in `comfy/output/`.

## 4. First real post

1. Re-activate `Create LinkedIn post` and run once.
2. Confirm the post on your LinkedIn profile.

## 5. Go live

1. Set the interval in `Schedule Trigger`. The default is every 6 hours (4 posts a day); once a day is usually better for reach.
2. Toggle the workflow **Active**.
3. Recommended: Workflow settings -> **Error workflow**, pointing to a small workflow that emails or messages you, so a failed run does not go unnoticed.
4. Set a reminder about 50 days out to reconnect the LinkedIn credential (tokens expire after 60 days).
