# Open WebUI — Pre-Configured Deployment

A ready-to-deploy [Open WebUI](https://github.com/open-webui/open-webui) setup with **Docker Compose**, pre-configured for **OpenRouter** and **Ollama**, featuring a custom terminal-styled theme and automated model renaming.

---

## What's Included

| Component | Description |
|---|---|
| **Docker Compose** | Single-command deployment of Open WebUI + Ollama |
| **OpenRouter** | Pre-wired to `https://openrouter.ai/api/v1` with auto-routing model |
| **Ollama** | Local model server running alongside Open WebUI |
| **Custom Theme** | JetBrains Mono font, yellowish accent color, faded model parameters |
| **Admin Account** | Auto-created on first launch via environment variables |
| **Model Renamer** | Script to rename models to a clean `ModelName 70B` format with faded params |
| **Auto-Routing** | Default model set to `openrouter/auto` for intelligent model selection |

---

## Quick Start

### Prerequisites

Docker and Docker Compose must be installed on your server. That's it.

### 1. Clone and Configure

```bash
git clone <this-repo-url> open-webui-setup
cd open-webui-setup
cp .env.example .env
```

Edit `.env` and set your values:

```env
WEBUI_SECRET_KEY=<random-secret-string>
WEBUI_ADMIN_EMAIL=you@example.com
WEBUI_ADMIN_PASSWORD=<strong-password>
OPENAI_API_KEY=<your-openrouter-api-key>
```

### 2. Build and Launch

```bash
docker compose build
docker compose up -d
```

Open WebUI will be available at **http://localhost:3000**. The admin account is created automatically on first launch.

### 3. Rename Models (Optional)

After Open WebUI is running and models are loaded, run the renamer to apply clean display names:

```bash
pip install requests
python3 scripts/rename_models.py --wait 30
```

This converts raw model IDs like `meta-llama/llama-3.1-70b-instruct` into clean names like **Llama 3.1** with a faded **70B** parameter badge.

Preview changes without applying:

```bash
python3 scripts/rename_models.py --dry-run
```

### Alternative: One-Command Setup

```bash
bash scripts/setup.sh
```

The setup script handles everything interactively — creating `.env`, prompting for secrets, building, and launching.

---

## Custom Theme

The theme applies three main customizations:

### JetBrains Mono Font

All UI text uses [JetBrains Mono](https://www.jetbrains.com/mono/), a monospaced typeface designed for developers. It loads from Google Fonts and applies globally across the interface, including chat messages, code blocks, and the sidebar.

### Yellowish Accent Color

Interactive elements use a warm yellow (`#f5c518`) as the accent color. This includes the send button, toggle switches, focus rings, scrollbar thumbs, tooltips, and active sidebar items.

### Faded Model Parameters

Model names display the parameter count (e.g., `70B`) in a faded, lighter style next to the model name. This keeps the interface clean while still showing model size at a glance. The fading is handled by a small JavaScript observer (`model_param_fader.js`) that watches for Unicode markers in model names and wraps them in styled `<span>` elements.

---

## Model Naming Format

The renamer script converts model IDs into human-readable names:

| Raw Model ID | Display Name |
|---|---|
| `meta-llama/llama-3.1-70b-instruct` | Llama 3.1 **⸨70B⸩** |
| `mistral:7b` | Mistral **⸨7B⸩** |
| `anthropic/claude-3.5-sonnet` | Claude 3.5 Sonnet |
| `openrouter/auto` | Auto Router |
| `deepseek/deepseek-r1:32b` | Deepseek R1 **⸨32B⸩** |

The text between **⸨** and **⸩** is rendered faded in the UI by the custom CSS and JavaScript.

---

## Project Structure

```
open-webui-setup/
├── docker-compose.yml        # Docker Compose services (Open WebUI + Ollama)
├── Dockerfile                # Custom Open WebUI image with theme injection
├── custom.css                # JetBrains Mono + yellow accent + faded params
├── .env.example              # Template config (safe to commit)
├── .env                      # Your actual config (git-ignored)
├── .gitignore
├── README.md
├── assets/                   # Custom favicons (optional)
└── scripts/
    ├── setup.sh              # Interactive first-time setup
    ├── rename_models.py      # Model display name renamer
    └── model_param_fader.js  # DOM observer for fading param text
```

---

## Configuration Reference

All configuration is done through the `.env` file. Key variables:

| Variable | Description | Default |
|---|---|---|
| `WEBUI_NAME` | Name shown in the UI header | `AI Chat` |
| `WEBUI_SECRET_KEY` | Secret for JWT tokens (must change) | — |
| `WEBUI_ADMIN_EMAIL` | Admin account email | — |
| `WEBUI_ADMIN_PASSWORD` | Admin account password | — |
| `OPENAI_API_BASE_URL` | OpenRouter endpoint | `https://openrouter.ai/api/v1` |
| `OPENAI_API_KEY` | Your OpenRouter API key | — |
| `DEFAULT_MODELS` | Default model for new chats | `openrouter/auto` |
| `TASK_MODEL_EXTERNAL` | Model for title/tag generation | `openrouter/auto` |
| `ENABLE_SIGNUP` | Allow new user registration | `false` |

For the full list of environment variables, see the [Open WebUI documentation](https://docs.openwebui.com/reference/env-configuration/).

---

## GPU Support (Ollama)

To enable NVIDIA GPU passthrough for Ollama, uncomment the `deploy` section in `docker-compose.yml`:

```yaml
ollama:
  image: ollama/ollama:latest
  deploy:
    resources:
      reservations:
        devices:
          - driver: nvidia
            count: all
            capabilities: [gpu]
```

Make sure the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) is installed on your host.

---

## Updating

```bash
docker compose pull
docker compose build --no-cache
docker compose up -d
```

Your data persists in Docker volumes (`open_webui_data` and `ollama_data`), so updates are safe.

---

## Troubleshooting

**Models not loading from OpenRouter:** Verify your `OPENAI_API_KEY` in `.env` is a valid OpenRouter key. Check logs with `docker compose logs open-webui`.

**Admin account not created:** This only happens on a fresh database. If you've run before, the account already exists. To reset, stop containers and remove the volume: `docker volume rm open-webui-setup_open_webui_data`.

**Custom CSS not applied:** Rebuild the image with `docker compose build --no-cache` and restart.

**Model renamer fails:** Ensure Open WebUI is fully started before running the script. Use `--wait 60` for slower machines.
