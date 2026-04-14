#!/bin/bash
set -euo pipefail

# ============================================================
# Lovable App Updater — Standalone Fallback
# ============================================================
# Gebruik bij voorkeur: lovable-update (aangemaakt door install.sh)
# Dit script werkt als fallback als lovable-update niet bestaat.
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Probeer eerst het geregistreerde commando
if command -v lovable-update &>/dev/null; then
  echo -e "${BLUE}lovable-update gevonden, doorverwijzen...${NC}"
  exec lovable-update
fi

echo -e "${BLUE}=== Lovable App Updater (fallback) ===${NC}"
echo ""

# Detecteer paden
INFRA_DIR="${INFRA_DIR:-/opt/lovable-infra}"
APP_DIR="${APP_DIR:-/opt/lovable-app}"
SUPABASE_DIR="${SUPABASE_DIR:-/opt/supabase}"

# Detecteer projecttype
if [[ -f "$APP_DIR/package.json" ]] && grep -q '"@tanstack/react-start"' "$APP_DIR/package.json" 2>/dev/null; then
  PROJECT_TYPE="ssr"
else
  PROJECT_TYPE="spa"
fi

echo "  Infra:  $INFRA_DIR"
echo "  App:    $APP_DIR"
echo "  Type:   $PROJECT_TYPE"
echo ""

# 1. Update infra-repo
echo -e "${GREEN}[1/5]${NC} Infra-repo updaten..."
cd "$INFRA_DIR" && git pull

# 2. Update app-repo
echo -e "${GREEN}[2/5]${NC} App-code ophalen van GitHub..."
cd "$APP_DIR" && git pull

# 3. Rebuild frontend
echo -e "${GREEN}[3/5]${NC} Frontend opnieuw bouwen (type: $PROJECT_TYPE)..."
if [[ "$PROJECT_TYPE" == "spa" ]]; then
  cp "$INFRA_DIR/nginx/frontend-spa.conf" "$APP_DIR/nginx.conf"
  docker build -t lovable-frontend -f "$INFRA_DIR/Dockerfile.spa" "$APP_DIR"
else
  docker build -t lovable-frontend -f "$INFRA_DIR/Dockerfile.ssr" "$APP_DIR"
fi

# 4. Restart frontend container
echo -e "${GREEN}[4/5]${NC} Frontend herstarten..."
docker stop lovable-frontend 2>/dev/null || true
docker rm lovable-frontend 2>/dev/null || true
docker run -d \
  --name lovable-frontend \
  --restart unless-stopped \
  -p 3000:3000 \
  lovable-frontend

# 5. Database migraties
echo -e "${GREEN}[5/5]${NC} Database migraties controleren..."
if [[ -d "$APP_DIR/supabase/migrations" ]]; then
  cp "$APP_DIR/supabase/migrations/"*.sql "$SUPABASE_DIR/volumes/db/init/" 2>/dev/null || true
  for migration in "$APP_DIR/supabase/migrations/"*.sql; do
    if [[ -f "$migration" ]]; then
      echo "  Migratie: $(basename "$migration")"
      docker exec supabase-db psql -U supabase -d postgres -f "/docker-entrypoint-initdb.d/$(basename "$migration")" 2>/dev/null || true
    fi
  done
fi

echo ""
echo -e "${GREEN}✅ Update compleet!${NC}"
