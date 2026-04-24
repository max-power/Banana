#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "Stopping Banana..."
docker compose down
echo "Done. Your data is safe."
