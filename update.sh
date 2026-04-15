#!/bin/bash
set -euo pipefail

# ============================================================
# Lovable App Updater — Standalone Fallback
# ============================================================
# Gebruik bij voorkeur: lovable-update (aangemaakt door install.sh)
# Dit script werkt als fallback als lovable-update niet bestaat.
#
# Flags:
#   --app-only          Alleen app updaten + rebuilden (geen infra pull, geen migraties)
#   --skip-migrations   Volledige update maar migraties overslaan
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Probeer eerst het geregistreerde commando — maar NIET bij --mark-done
# (het bestaande script op de server kan verouderd zijn en --mark-done niet kennen)
USES_LOCAL_FALLBACK=false
for _arg in "$@"; do
  if [[ "$_arg" == "--mark-done" ]]; then
    USES_LOCAL_FALLBACK=true
    break
  fi
done

if [[ "$USES_LOCAL_FALLBACK" == false ]] && command -v lovable-update &>/dev/null; then
  echo -e "${BLUE}lovable-update gevonden, doorverwijzen...${NC}"
  exec lovable-update "$@"
fi

echo -e "${BLUE}=== Lovable App Updater (fallback) ===${NC}"
echo ""

# --- Parse flags ---
APP_ONLY=false
SKIP_MIGRATIONS=false
MARK_DONE=""
for arg in "$@"; do
  case "$arg" in
    --app-only) APP_ONLY=true ;;
    --skip-migrations) SKIP_MIGRATIONS=true ;;
    --mark-done) MARK_DONE="next" ;;
    *)
      if [[ "$MARK_DONE" == "next" ]]; then
        MARK_DONE="$arg"
      fi
      ;;
  esac
done

# Detecteer paden (MOET vóór mark-done staan)
INFRA_DIR="${INFRA_DIR:-/opt/lovable-infra}"
APP_DIR="${APP_DIR:-/opt/lovable-app}"
SUPABASE_DIR="${SUPABASE_DIR:-/opt/supabase}"
MIGRATIONS_DONE_DIR="$SUPABASE_DIR/.migrations_done"

# --- Mark-done shortcut ---
if [[ -n "$MARK_DONE" && "$MARK_DONE" != "next" ]]; then
  mkdir -p "$MIGRATIONS_DONE_DIR"
  touch "$MIGRATIONS_DONE_DIR/$MARK_DONE"
  echo -e "${GREEN}✅ Migratie '$MARK_DONE' gemarkeerd als gedaan.${NC}"
  exit 0
fi

# --- .env.production herschrijven met self-hosted waarden ---
write_env_production() {
  local api_url=""
  local anon_key=""

  if [[ -f "$INFRA_DIR/.app_env" ]]; then
    source "$INFRA_DIR/.app_env"
    api_url="$APP_API_URL"
    anon_key="$APP_ANON_KEY"
  elif [[ -f "$SUPABASE_DIR/.env" ]]; then
    # Fallback: lees direct uit Supabase .env
    anon_key=$(grep "^ANON_KEY=" "$SUPABASE_DIR/.env" | cut -d= -f2-)
    if [[ -f "$INFRA_DIR/.app_domain" ]]; then
      api_url="https://$(cat "$INFRA_DIR/.app_domain")"
    else
      api_url="http://$(curl -sf ifconfig.me 2>/dev/null || echo localhost):8000"
    fi
  fi

  if [[ -n "$api_url" && -n "$anon_key" ]]; then
    cat > "$APP_DIR/.env.production" <<_ENVEOF
VITE_SUPABASE_URL=$api_url
VITE_SUPABASE_ANON_KEY=$anon_key
VITE_SUPABASE_PUBLISHABLE_KEY=$anon_key
_ENVEOF
    echo -e "  ${GREEN}.env.production → $api_url${NC}"
  else
    echo -e "  ${YELLOW}⚠️  Kan .env.production niet schrijven — .app_env en supabase/.env ontbreken${NC}"
  fi
}

# --- Patch known problematic migrations before running ---
patch_known_migrations() {
  local target="$APP_DIR/supabase/migrations/20260119083612_fc4680d3-4321-408e-ac77-817040a08a81.sql"
  if [[ ! -f "$target" ]]; then
    echo "  Migratie-patch: doelbestand niet gevonden (overgeslagen)"
    return 0
  fi
  if grep -q "WHERE EXISTS" "$target"; then
    echo "  Migratie-patch: al gepatcht (overgeslagen)"
    return 0
  fi
  if ! grep -q "fa761b51-9489-4289-917b-d1818f3cd508" "$target"; then
    echo "  Migratie-patch: UUID niet gevonden in doelbestand (overgeslagen)"
    return 0
  fi
  echo "  Migratie-patch: conditionele super_admin INSERT toepassen..."
  perl -0777 -i -pe "s/INSERT INTO user_roles \(user_id, role\)[\s\S]*?VALUES[\s\S]*?\('fa761b51-9489-4289-917b-d1818f3cd508'[\s\S]*?;/INSERT INTO user_roles (user_id, role)\nSELECT 'fa761b51-9489-4289-917b-d1818f3cd508', 'super_admin'::app_role\nWHERE EXISTS (\n  SELECT 1 FROM public.profiles\n  WHERE id = 'fa761b51-9489-4289-917b-d1818f3cd508'\n)\nON CONFLICT (user_id, role) DO NOTHING;/" "$target"
  echo "  Migratie-patch: ✅ toegepast"
}

# --- Strikte migratie-runner (gedeeld) ---
run_strict_migrations() {
  if [[ ! -d "$APP_DIR/supabase/migrations" ]]; then return 0; fi

  echo "  Database migraties controleren..."
  mkdir -p "$MIGRATIONS_DONE_DIR"

  for migration in "$APP_DIR/supabase/migrations/"*.sql; do
    [[ -f "$migration" ]] || continue
    local_name="$(basename "$migration")"
    if [[ ! -f "$MIGRATIONS_DONE_DIR/$local_name" ]]; then
      echo "  Nieuwe migratie: $local_name"
      if docker exec -i supabase-db bash -c \
        'PGPASSWORD=$POSTGRES_PASSWORD psql -U postgres -d postgres -h localhost -v ON_ERROR_STOP=1 -X --single-transaction' \
        < "$migration"; then
        touch "$MIGRATIONS_DONE_DIR/$local_name"
        echo "    ✅ Succesvol"
      else
        echo "    ❌ Mislukt — stoppen bij eerste fout"
        echo ""
        echo "  De migratie '$local_name' is mislukt."
        echo "  Dit is waarschijnlijk een probleem in de app-repo, niet in de infra."
        echo "  Los het probleem op en draai daarna opnieuw: lovable-update"
        echo ""
        echo "  Workaround: als je zeker weet dat de migratie handmatig al is opgelost:"
        echo "    lovable-update --mark-done $local_name"
        return 1
      fi
    fi
  done
  return 0
}

# Detecteer installatiemodus via marker (geschreven door install.sh)
if [[ -f "$INFRA_DIR/.install_mode" ]]; then
  INSTALL_MODE="$(cat "$INFRA_DIR/.install_mode")"
else
  # Fallback: probeer te raden op basis van aanwezige directories
  if [[ -d "$SUPABASE_DIR" && ! -d "$APP_DIR" ]]; then
    INSTALL_MODE="database"
  elif [[ ! -d "$SUPABASE_DIR" && -d "$APP_DIR" ]]; then
    INSTALL_MODE="frontend"
  elif [[ -d "$SUPABASE_DIR" && -d "$APP_DIR" ]]; then
    if docker ps -a --format '{{.Names}}' | grep -q '^lovable-frontend$'; then
      INSTALL_MODE="full"
    else
      INSTALL_MODE="database"
    fi
  else
    echo -e "${RED}[ERROR] Kan installatiemodus niet detecteren.${NC}"
    echo "  Draai eerst install.sh of controleer de paden."
    exit 1
  fi
fi

echo "  Modus: $INSTALL_MODE"
echo ""

# === DATABASE MODE ===
if [[ "$INSTALL_MODE" == "database" ]]; then
  echo -e "${GREEN}[1/4]${NC} Infra-repo updaten..."
  cd "$INFRA_DIR" && git pull

  # roles.sql en jwt.sql bijwerken vanuit infra-repo
  if [[ -d "$SUPABASE_DIR/volumes/db" ]]; then
    cp "$INFRA_DIR/volumes/db/roles.sql" "$SUPABASE_DIR/volumes/db/roles.sql" 2>/dev/null || true
    cp "$INFRA_DIR/volumes/db/jwt.sql" "$SUPABASE_DIR/volumes/db/jwt.sql" 2>/dev/null || true
    echo "  Init-scripts bijgewerkt"
  fi

  if [[ -d "$APP_DIR/.git" ]]; then
    echo -e "${GREEN}[2/4]${NC} App-repo updaten (voor migraties)..."
    cd "$APP_DIR" && git pull
  else
    echo -e "${GREEN}[2/4]${NC} App-repo niet gevonden — migraties overgeslagen"
  fi

  if [[ "$SKIP_MIGRATIONS" == true ]]; then
    echo -e "${GREEN}[3/4]${NC} Database migraties overgeslagen (--skip-migrations)"
  else
    echo -e "${GREEN}[3/4]${NC} Database migraties controleren..."
    patch_known_migrations
    run_strict_migrations || exit 1
  fi

  echo -e "${GREEN}[4/4]${NC} Supabase stack herstarten..."
  cd "$SUPABASE_DIR" && docker compose up -d

  echo ""
  echo -e "${GREEN}✅ Update compleet (database)!${NC}"
  exit 0
fi

# === FRONTEND MODE ===
if [[ "$INSTALL_MODE" == "frontend" ]]; then
  # Detecteer projecttype
  if grep -q '"@tanstack/react-start"' "$APP_DIR/package.json" 2>/dev/null; then
    PROJECT_TYPE="ssr"
  else
    PROJECT_TYPE="spa"
  fi

  if [[ "$APP_ONLY" == true ]]; then
    echo -e "${GREEN}[1/3]${NC} App-code ophalen en bouwen (type: $PROJECT_TYPE)..."
    cd "$APP_DIR" && git pull
  else
    echo -e "${GREEN}[1/3]${NC} Infra-repo updaten..."
    cd "$INFRA_DIR" && git pull

    echo -e "${GREEN}[2/3]${NC} App-code ophalen en bouwen (type: $PROJECT_TYPE)..."
    cd "$APP_DIR" && git pull
  fi

  write_env_production
  if [[ "$PROJECT_TYPE" == "spa" ]]; then
    cp "$INFRA_DIR/nginx/frontend-spa.conf" "$APP_DIR/nginx.conf"
    docker build -t lovable-frontend -f "$INFRA_DIR/Dockerfile.spa" "$APP_DIR"
  else
    docker build -t lovable-frontend -f "$INFRA_DIR/Dockerfile.ssr" "$APP_DIR"
  fi

  echo -e "${GREEN}[3/3]${NC} Frontend herstarten..."
  docker stop lovable-frontend 2>/dev/null || true
  docker rm lovable-frontend 2>/dev/null || true
  docker run -d \
    --name lovable-frontend \
    --restart unless-stopped \
    -p 3000:3000 \
    lovable-frontend

  echo ""
  echo -e "${GREEN}✅ Update compleet (frontend)!${NC}"
  exit 0
fi

# === FULL MODE ===
# Detecteer projecttype
if grep -q '"@tanstack/react-start"' "$APP_DIR/package.json" 2>/dev/null; then
  PROJECT_TYPE="ssr"
else
  PROJECT_TYPE="spa"
fi

# --- App-only shortcut ---
if [[ "$APP_ONLY" == true ]]; then
  echo "=== Lovable App Updater (app-only) ==="
  echo ""

  echo -e "${GREEN}[1/3]${NC} App-code ophalen van GitHub..."
  cd "$APP_DIR" && git pull

  echo -e "${GREEN}[2/3]${NC} Frontend opnieuw bouwen (type: $PROJECT_TYPE)..."
  write_env_production
  if [[ "$PROJECT_TYPE" == "spa" ]]; then
    cp "$INFRA_DIR/nginx/frontend-spa.conf" "$APP_DIR/nginx.conf"
    docker build -t lovable-frontend -f "$INFRA_DIR/Dockerfile.spa" "$APP_DIR"
  else
    docker build -t lovable-frontend -f "$INFRA_DIR/Dockerfile.ssr" "$APP_DIR"
  fi

  echo -e "${GREEN}[3/3]${NC} Frontend herstarten..."
  docker stop lovable-frontend 2>/dev/null || true
  docker rm lovable-frontend 2>/dev/null || true
  docker run -d \
    --name lovable-frontend \
    --restart unless-stopped \
    -p 3000:3000 \
    lovable-frontend

  echo ""
  echo -e "${GREEN}✅ Update compleet (app-only)!${NC}"
  exit 0
fi

echo "  Infra:  $INFRA_DIR"
echo "  App:    $APP_DIR"
echo "  Type:   $PROJECT_TYPE"
echo ""

echo -e "${GREEN}[1/5]${NC} Infra-repo updaten..."
cd "$INFRA_DIR" && git pull

  # roles.sql en jwt.sql bijwerken vanuit infra-repo
  if [[ -d "$SUPABASE_DIR/volumes/db" ]]; then
    cp "$INFRA_DIR/volumes/db/roles.sql" "$SUPABASE_DIR/volumes/db/roles.sql" 2>/dev/null || true
    cp "$INFRA_DIR/volumes/db/jwt.sql" "$SUPABASE_DIR/volumes/db/jwt.sql" 2>/dev/null || true
    echo "  Init-scripts bijgewerkt"
  fi

echo -e "${GREEN}[2/5]${NC} App-code ophalen van GitHub..."
cd "$APP_DIR" && git pull

echo -e "${GREEN}[3/5]${NC} Frontend opnieuw bouwen (type: $PROJECT_TYPE)..."
write_env_production
if [[ "$PROJECT_TYPE" == "spa" ]]; then
  cp "$INFRA_DIR/nginx/frontend-spa.conf" "$APP_DIR/nginx.conf"
  docker build -t lovable-frontend -f "$INFRA_DIR/Dockerfile.spa" "$APP_DIR"
else
  docker build -t lovable-frontend -f "$INFRA_DIR/Dockerfile.ssr" "$APP_DIR"
fi

echo -e "${GREEN}[4/5]${NC} Frontend herstarten..."
docker stop lovable-frontend 2>/dev/null || true
docker rm lovable-frontend 2>/dev/null || true
docker run -d \
  --name lovable-frontend \
  --restart unless-stopped \
  -p 3000:3000 \
  lovable-frontend

if [[ "$SKIP_MIGRATIONS" == true ]]; then
  echo -e "${GREEN}[5/5]${NC} Database migraties overgeslagen (--skip-migrations)"
else
  echo -e "${GREEN}[5/5]${NC} Database migraties controleren..."
  patch_known_migrations
  run_strict_migrations || exit 1
fi

echo ""
echo -e "${GREEN}✅ Update compleet!${NC}"
