#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Open WebUI First-Time Setup
# ============================================================
# Builds the custom image and then delegates to start.sh
# for the actual launch with runtime-only secrets.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "============================================"
echo "  Open WebUI — First-Time Setup"
echo "============================================"
echo ""

# --- Check prerequisites ---
if ! command -v docker &>/dev/null; then
  echo "ERROR: Docker is not installed."
  exit 1
fi

if ! docker compose version &>/dev/null && ! docker-compose version &>/dev/null; then
  echo "ERROR: Docker Compose is not installed."
  exit 1
fi

# --- Build ---
echo "Building custom Open WebUI image..."
docker compose build --no-cache
echo ""
echo "Build complete. Launching..."
echo ""

# --- Delegate to start.sh ---
exec bash start.sh
