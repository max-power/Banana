#!/bin/bash

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$APP_DIR"

notify() {
  if command -v notify-send > /dev/null; then
    notify-send --icon="$APP_DIR/icon.png" --app-name="Banana" "$1" "$2"
  fi
}

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  notify "Docker is not running" "Start Docker first: sudo systemctl start docker"
  exit 1
fi

# Check if the app container is up
if docker compose ps --status running | grep -q "app"; then
  docker compose down
  notify "Banana stopped" "Your data is safe."
else
  bash "$APP_DIR/start.sh"
  notify "Banana is running" "Opening in your browser…"
fi
