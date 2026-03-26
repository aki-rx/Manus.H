#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Open WebUI Setup Script
# ============================================================
# This script:
#   1. Checks prerequisites (Docker, Docker Compose)
#   2. Copies .env.example -> .env if .env doesn't exist
#   3. Prompts for required secrets
#   4. Builds and starts the containers
#   5. Waits for Open WebUI to be ready
#   6. Optionally runs the model renamer
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "============================================"
echo "  Open WebUI Setup"
echo "============================================"
echo ""

# --- Check prerequisites ---
for cmd in docker; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: '$cmd' is not installed. Please install it first."
    exit 1
  fi
done

if ! docker compose version &>/dev/null && ! docker-compose version &>/dev/null; then
  echo "ERROR: Docker Compose is not installed. Please install it first."
  exit 1
fi

# --- Create .env if needed ---
if [ ! -f .env ]; then
  echo "Creating .env from .env.example..."
  cp .env.example .env
  echo ""
  echo "IMPORTANT: Edit .env and set your values before continuing."
  echo "  Required:"
  echo "    - WEBUI_SECRET_KEY    (random secret string)"
  echo "    - WEBUI_ADMIN_EMAIL   (your admin email)"
  echo "    - WEBUI_ADMIN_PASSWORD (your admin password)"
  echo "    - OPENAI_API_KEY      (your OpenRouter API key)"
  echo ""
  read -rp "Press Enter after editing .env, or Ctrl+C to abort... "
fi

# --- Validate .env ---
source .env 2>/dev/null || true

if [ "${WEBUI_SECRET_KEY:-}" = "CHANGE_ME_TO_A_RANDOM_SECRET_KEY" ]; then
  echo ""
  echo "WARNING: WEBUI_SECRET_KEY is still the default placeholder."
  echo "  Generating a random key for you..."
  NEW_KEY=$(openssl rand -hex 32 2>/dev/null || head -c 64 /dev/urandom | base64 | tr -d '=/+' | head -c 64)
  sed -i "s|WEBUI_SECRET_KEY=CHANGE_ME_TO_A_RANDOM_SECRET_KEY|WEBUI_SECRET_KEY=${NEW_KEY}|" .env
  echo "  Done. Key saved to .env"
fi

if [ "${OPENAI_API_KEY:-}" = "YOUR_OPENROUTER_API_KEY_HERE" ]; then
  echo ""
  read -rp "Enter your OpenRouter API key: " OR_KEY
  sed -i "s|OPENAI_API_KEY=YOUR_OPENROUTER_API_KEY_HERE|OPENAI_API_KEY=${OR_KEY}|" .env
fi

if [ "${WEBUI_ADMIN_PASSWORD:-}" = "CHANGE_ME_STRONG_PASSWORD" ]; then
  echo ""
  read -rsp "Enter admin password: " ADMIN_PASS
  echo ""
  sed -i "s|WEBUI_ADMIN_PASSWORD=CHANGE_ME_STRONG_PASSWORD|WEBUI_ADMIN_PASSWORD=${ADMIN_PASS}|" .env
fi

# --- Build and start ---
echo ""
echo "Building custom Open WebUI image..."
docker compose build --no-cache

echo ""
echo "Starting services..."
docker compose up -d

echo ""
echo "Waiting for Open WebUI to be ready..."
RETRIES=60
for i in $(seq 1 $RETRIES); do
  if curl -sf http://localhost:3000/api/version &>/dev/null; then
    VERSION=$(curl -sf http://localhost:3000/api/version | grep -o '"version":"[^"]*"' | head -1)
    echo "  Open WebUI is ready! ($VERSION)"
    break
  fi
  if [ "$i" -eq "$RETRIES" ]; then
    echo "  WARNING: Timed out. Check 'docker compose logs open-webui' for details."
  fi
  sleep 3
done

# --- Model renaming ---
echo ""
echo "============================================"
echo "  Setup Complete!"
echo "============================================"
echo ""
echo "  URL:   http://localhost:3000"
echo "  Admin: Check your .env for credentials"
echo ""
echo "  To rename models to the clean format, run:"
echo "    python3 scripts/rename_models.py --wait 10"
echo ""
echo "  To stop:   docker compose down"
echo "  To update: docker compose pull && docker compose build && docker compose up -d"
echo ""
