#!/bin/bash
set -e

cd "$(dirname "$0")"

# ── Check Docker is running ──────────────────────────────────────────────────
if ! docker info > /dev/null 2>&1; then
  echo "Docker is not running. Please start Docker and try again."
  exit 1
fi

# ── Generate secrets on first run ────────────────────────────────────────────
if [ ! -f .env ]; then
  echo "First run — generating secrets (this only happens once)..."
  {
    echo "DATABASE_PASSWORD=$(openssl rand -hex 20)"
    echo "SECRET_KEY_BASE=$(openssl rand -hex 64)"
  } > .env
  echo "Secrets saved to .env"
  FIRST_RUN=true
fi

# ── Ensure storage directory exists and is writable by the container user ────
# The app runs as uid 1000 inside the container.
mkdir -p storage
chmod 775 storage

# ── Build image if not built yet ─────────────────────────────────────────────
if [[ "$FIRST_RUN" == "true" ]] || ! docker image inspect banana-app > /dev/null 2>&1; then
  echo "Building Banana (this takes a few minutes the first time)..."
  docker compose build
fi

# ── Start services ───────────────────────────────────────────────────────────
echo "Starting Banana..."
docker compose up -d

# ── Wait for the app to respond ──────────────────────────────────────────────
echo "Waiting for app to be ready..."
until curl -sf http://localhost:3000/up > /dev/null 2>&1; do
  sleep 2
done

echo ""
echo "✓ Banana is running at http://localhost:3000"
if [[ "$FIRST_RUN" == "true" ]]; then
  echo ""
  echo "  First run: open the link below and create your account."
  echo "  You only need to do this once."
  echo ""
fi

# ── Open browser ─────────────────────────────────────────────────────────────
if command -v xdg-open > /dev/null; then
  xdg-open http://localhost:3000
elif command -v open > /dev/null; then
  open http://localhost:3000   # macOS fallback
fi
