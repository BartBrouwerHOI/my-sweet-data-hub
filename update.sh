#!/bin/bash
set -euo pipefail

APP_DIR="/opt/lovable-app"
SUPABASE_DIR="/opt/supabase"

echo "=== Lovable App Updater ==="
echo ""

# Pull latest code
echo "[1/4] Code ophalen van GitHub..."
cd "$APP_DIR"
git pull

# Rebuild frontend
echo "[2/4] Frontend opnieuw bouwen..."
docker build -t lovable-frontend -f Dockerfile .

# Restart frontend container
echo "[3/4] Frontend herstarten..."
docker stop lovable-frontend 2>/dev/null || true
docker rm lovable-frontend 2>/dev/null || true
docker run -d \
  --name lovable-frontend \
  --restart unless-stopped \
  -p 3000:80 \
  lovable-frontend

# Run new migrations if any
echo "[4/4] Database migraties controleren..."
if [[ -d "$APP_DIR/supabase/migrations" ]]; then
  for migration in "$APP_DIR/supabase/migrations/"*.sql; do
    if [[ -f "$migration" ]]; then
      echo "  Migratie uitvoeren: $(basename "$migration")"
      docker exec supabase-db psql -U supabase -d postgres -f "/docker-entrypoint-initdb.d/$(basename "$migration")" 2>/dev/null || true
    fi
  done
fi

echo ""
echo "✅ Update compleet! De app draait weer."
