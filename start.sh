#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Open WebUI Launcher
# ============================================================
# Prompts for API keys and secrets at runtime, exports them as
# shell environment variables, and starts Docker Compose.
# Nothing secret is written to disk.
# ============================================================

echo "============================================"
echo "  Open WebUI — Secure Launcher"
echo "============================================"
echo ""

# --- Check prerequisites ---
if ! command -v docker &>/dev/null; then
  echo "ERROR: Docker is not installed."
  exit 1
fi

# --- Prompt for secrets if not already set ---

if [ -z "${OPENAI_API_KEY:-}" ]; then
  echo "Enter your OpenRouter API key"
  read -rsp "  OPENAI_API_KEY: " OPENAI_API_KEY
  echo ""
  export OPENAI_API_KEY
fi

if [ -z "${WEBUI_SECRET_KEY:-}" ]; then
  echo ""
  echo "Generating a random WEBUI_SECRET_KEY..."
  WEBUI_SECRET_KEY="$(openssl rand -hex 32 2>/dev/null || head -c 64 /dev/urandom | base64 | tr -d '=/+' | head -c 64)"
  export WEBUI_SECRET_KEY
  echo "  Done (stored in memory only)."
fi

if [ -z "${WEBUI_ADMIN_PASSWORD:-}" ]; then
  echo ""
  echo "Set the admin account password"
  read -rsp "  WEBUI_ADMIN_PASSWORD: " WEBUI_ADMIN_PASSWORD
  echo ""
  export WEBUI_ADMIN_PASSWORD
fi

# --- Optional overrides ---
export WEBUI_ADMIN_EMAIL="${WEBUI_ADMIN_EMAIL:-admin@example.com}"
export WEBUI_ADMIN_NAME="${WEBUI_ADMIN_NAME:-Admin}"
export WEBUI_NAME="${WEBUI_NAME:-AI Chat}"
export OPENAI_API_BASE_URL="${OPENAI_API_BASE_URL:-https://openrouter.ai/api/v1}"

echo ""
echo "  API Endpoint:  $OPENAI_API_BASE_URL"
echo "  Admin Email:   $WEBUI_ADMIN_EMAIL"
echo "  Admin Name:    $WEBUI_ADMIN_NAME"
echo ""

# --- Build if needed ---
if ! docker image inspect open-webui-setup-open-webui &>/dev/null 2>&1; then
  echo "Building custom Open WebUI image..."
  docker compose build
  echo ""
fi

# --- Start ---
echo "Starting services..."
docker compose up -d

echo ""
echo "Waiting for Open WebUI..."
RETRIES=40
for i in $(seq 1 $RETRIES); do
  if curl -sf http://localhost:3000/api/version &>/dev/null; then
    VERSION=$(curl -sf http://localhost:3000/api/version 2>/dev/null || echo "unknown")
    echo "  Ready! ($VERSION)"
    break
  fi
  [ "$i" -eq "$RETRIES" ] && echo "  Timed out — check: docker compose logs open-webui"
  sleep 3
done

echo ""
echo "============================================"
echo "  Open WebUI is running"
echo "============================================"
echo ""
echo "  URL:    http://localhost:3000"
echo "  Admin:  $WEBUI_ADMIN_EMAIL"
echo ""
echo "  Secrets are in memory only."
echo "  They will be lost when this terminal closes."
echo "  Re-run this script to restart with fresh keys."
echo ""
echo "  Stop:   docker compose down"
echo "  Logs:   docker compose logs -f open-webui"
echo ""
