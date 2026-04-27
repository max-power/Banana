#!/bin/bash

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
DESKTOP_DIR="$HOME/Desktop"
APPS_DIR="$HOME/.local/share/applications"

ICON=""
if [ -f "$APP_DIR/icon.png" ]; then
  ICON="$APP_DIR/icon.png"
fi

DESKTOP_ENTRY="[Desktop Entry]
Name=Banana
Comment=Start or stop the Banana cycling app
Exec=bash $APP_DIR/toggle.sh
Icon=$ICON
Terminal=false
Type=Application
Categories=Utility;
"

# Install to applications menu
mkdir -p "$APPS_DIR"
echo "$DESKTOP_ENTRY" > "$APPS_DIR/banana.desktop"
chmod +x "$APPS_DIR/banana.desktop"

# Also drop one on the Desktop if it exists
if [ -d "$DESKTOP_DIR" ]; then
  echo "$DESKTOP_ENTRY" > "$DESKTOP_DIR/banana.desktop"
  chmod +x "$DESKTOP_DIR/banana.desktop"
  # Mark as trusted so GNOME allows launching it
  gio set "$DESKTOP_DIR/banana.desktop" metadata::trusted true 2>/dev/null || true
  echo "Shortcut added to your Desktop."
fi

echo "Done. You can also find Banana in your applications menu."
