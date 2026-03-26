#!/usr/bin/env python3
"""
Open WebUI Model Renamer
========================
Renames models to the format:  ModelName  <faded>ParamSize</faded>

Examples:
  - llama3.1:70b        -> Llama 3.1 70B
  - mistral:7b          -> Mistral 7B
  - openrouter/auto     -> Auto Router
  - anthropic/claude-3.5-sonnet -> Claude 3.5 Sonnet

The parameter size (e.g. 70B) will appear faded in the UI via custom CSS
that targets a Unicode marker character wrapping the param text.

Usage:
  python3 rename_models.py [--url URL] [--token TOKEN]

If --token is not provided, the script will authenticate using
WEBUI_ADMIN_EMAIL and WEBUI_ADMIN_PASSWORD from the .env file.
"""

import argparse
import json
import os
import re
import sys
import time

try:
    import requests
except ImportError:
    print("ERROR: 'requests' package is required. Install with: pip install requests")
    sys.exit(1)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def load_env(env_path=".env"):
    """Load key=value pairs from a .env file."""
    env = {}
    if not os.path.exists(env_path):
        return env
    with open(env_path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip().strip('"').strip("'")
    return env


def authenticate(base_url: str, email: str, password: str) -> str:
    """Sign in and return a JWT token."""
    resp = requests.post(
        f"{base_url}/api/v1/auths/signin",
        json={"email": email, "password": password},
    )
    resp.raise_for_status()
    return resp.json()["token"]


def get_models(base_url: str, token: str) -> list:
    """Fetch all models from Open WebUI."""
    resp = requests.get(
        f"{base_url}/api/models",
        headers={"Authorization": f"Bearer {token}"},
    )
    resp.raise_for_status()
    return resp.json().get("data", [])


def update_model(base_url: str, token: str, model_id: str, name: str, meta: dict | None = None):
    """Update a model's display name and metadata."""
    payload = {
        "id": model_id,
        "name": name,
        "meta": meta or {"description": ""},
        "params": {},
    }
    resp = requests.post(
        f"{base_url}/api/v1/models/model/update?id={model_id}",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        json=payload,
    )
    if resp.status_code == 200:
        return True
    else:
        print(f"  WARNING: Could not update '{model_id}' (HTTP {resp.status_code}): {resp.text}")
        return False


# ---------------------------------------------------------------------------
# Name formatting
# ---------------------------------------------------------------------------

# Common provider prefixes to strip from display name
PROVIDER_PREFIXES = [
    "openrouter/",
    "anthropic/",
    "openai/",
    "google/",
    "meta-llama/",
    "mistralai/",
    "microsoft/",
    "deepseek/",
    "cohere/",
    "perplexity/",
    "qwen/",
    "nvidia/",
    "nousresearch/",
    "01-ai/",
    "databricks/",
    "x-ai/",
]

# Regex to extract parameter size from model ID (e.g. :70b, -8b, :7b-instruct)
PARAM_RE = re.compile(r"[:\-](\d+\.?\d*[bB])", re.IGNORECASE)

# Regex to clean up version/variant suffixes
VARIANT_RE = re.compile(r"[:\-](instruct|chat|latest|fp16|q4_0|q4_k_m|q5_k_m|q8_0|gguf|preview|turbo|pro|plus|mini|nano|small|medium|large|xl|xxl)$", re.IGNORECASE)


def humanize_model_name(model_id: str) -> str:
    """
    Convert a raw model ID into a human-friendly display name.

    Format:  ModelName ParamSize
    The ParamSize portion is wrapped with a special Unicode marker (⸨...⸩)
    so that CSS can target it and render it faded.

    Examples:
      llama3.1:70b-instruct  ->  Llama 3.1 ⸨70B⸩
      mistral:7b             ->  Mistral ⸨7B⸩
      openrouter/auto        ->  Auto Router
      anthropic/claude-3.5-sonnet:latest -> Claude 3.5 Sonnet
    """
    raw = model_id

    # Strip provider prefix
    for prefix in PROVIDER_PREFIXES:
        if raw.lower().startswith(prefix):
            raw = raw[len(prefix):]
            break

    # Extract parameter size before cleaning
    param_match = PARAM_RE.search(raw)
    param_str = ""
    if param_match:
        param_str = param_match.group(1).upper()
        # Remove the param portion from the name
        raw = raw[:param_match.start()] + raw[param_match.end():]

    # Remove variant suffixes
    raw = VARIANT_RE.sub("", raw)

    # Remove trailing colons, dashes, dots
    raw = raw.strip(":-./")

    # Replace separators with spaces
    raw = raw.replace("-", " ").replace("_", " ").replace(".", " ")

    # Title-case each word
    words = raw.split()
    name_parts = []
    for w in words:
        # Keep version numbers as-is (e.g. "3", "3.5")
        if re.match(r"^\d+\.?\d*$", w):
            name_parts.append(w)
        else:
            name_parts.append(w.capitalize())

    name = " ".join(name_parts)

    # Special cases
    if name.lower() in ("auto", "auto router"):
        name = "Auto Router"

    # Append faded parameter size using Unicode markers
    # CSS will target text between ⸨ and ⸩ to make it faded
    if param_str:
        name = f"{name} ⸨{param_str}⸩"

    return name


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Rename Open WebUI models to a clean display format")
    parser.add_argument("--url", default="http://localhost:3000", help="Open WebUI base URL")
    parser.add_argument("--token", default=None, help="API token (JWT or API key)")
    parser.add_argument("--env", default=".env", help="Path to .env file for credentials")
    parser.add_argument("--dry-run", action="store_true", help="Preview renames without applying")
    parser.add_argument("--wait", type=int, default=0, help="Seconds to wait for Open WebUI to be ready")
    args = parser.parse_args()

    base_url = args.url.rstrip("/")

    # Wait for Open WebUI to be ready
    if args.wait > 0:
        print(f"Waiting up to {args.wait}s for Open WebUI at {base_url}...")
        deadline = time.time() + args.wait
        while time.time() < deadline:
            try:
                r = requests.get(f"{base_url}/api/version", timeout=5)
                if r.status_code == 200:
                    print(f"  Open WebUI is ready (version: {r.json().get('version', '?')})")
                    break
            except Exception:
                pass
            time.sleep(3)
        else:
            print("  WARNING: Timed out waiting for Open WebUI. Proceeding anyway...")

    # Authenticate
    token = args.token
    if not token:
        env = load_env(args.env)
        email = env.get("WEBUI_ADMIN_EMAIL", "")
        password = env.get("WEBUI_ADMIN_PASSWORD", "")
        if not email or not password:
            print("ERROR: No --token provided and WEBUI_ADMIN_EMAIL/PASSWORD not found in .env")
            sys.exit(1)
        print(f"Authenticating as {email}...")
        try:
            token = authenticate(base_url, email, password)
            print("  Authenticated successfully.")
        except Exception as e:
            print(f"  ERROR: Authentication failed: {e}")
            sys.exit(1)

    # Fetch models
    print("Fetching models...")
    try:
        models = get_models(base_url, token)
    except Exception as e:
        print(f"  ERROR: Could not fetch models: {e}")
        sys.exit(1)

    if not models:
        print("  No models found.")
        return

    print(f"  Found {len(models)} model(s).\n")

    # Rename each model
    renamed = 0
    for model in models:
        model_id = model.get("id", "")
        current_name = model.get("name", model_id)
        new_name = humanize_model_name(model_id)

        if not new_name or new_name == current_name:
            continue

        if args.dry_run:
            print(f"  [DRY RUN] {model_id}")
            print(f"            Current: {current_name}")
            print(f"            New:     {new_name}")
            print()
            renamed += 1
        else:
            print(f"  Renaming: {model_id}")
            print(f"    From: {current_name}")
            print(f"    To:   {new_name}")
            if update_model(base_url, token, model_id, new_name):
                renamed += 1
                print(f"    OK")
            print()

    action = "would rename" if args.dry_run else "renamed"
    print(f"Done. {action} {renamed}/{len(models)} model(s).")


if __name__ == "__main__":
    main()
