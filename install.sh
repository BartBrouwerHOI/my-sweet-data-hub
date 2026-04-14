#!/bin/bash
set -euo pipefail

# ============================================================
# Lovable VPS Installer — Ubuntu 24 + Self-Hosted Supabase
# ============================================================
# Dit script installeert alles automatisch:
# - Docker + Docker Compose
# - Nginx + Certbot (SSL)
# - Self-hosted Supabase (PostgreSQL, Auth, API, Storage, Realtime)
# - Je Lovable frontend app
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_banner() {
  echo -e "${BLUE}"
  echo "╔══════════════════════════════════════════════╗"
  echo "║     Lovable VPS Installer v1.0               ║"
  echo "║     Ubuntu 24 + Self-Hosted Supabase         ║"
  echo "╚══════════════════════════════════════════════╝"
  echo -e "${NC}"
}

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Pre-flight checks ---
check_requirements() {
  if [[ $EUID -ne 0 ]]; then
    log_error "Dit script moet als root gedraaid worden. Gebruik: sudo bash install.sh"
    exit 1
  fi

  if ! grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
    log_warn "Dit script is ontworpen voor Ubuntu 24. Andere distro's kunnen problemen geven."
  fi

  local mem_mb
  mem_mb=$(free -m | awk '/^Mem:/{print $2}')
  if [[ $mem_mb -lt 3500 ]]; then
    log_warn "Minimaal 4GB RAM aanbevolen. Gedetecteerd: ${mem_mb}MB"
    read -p "Wil je toch doorgaan? (j/n): " confirm
    [[ "$confirm" != "j" ]] && exit 1
  fi
}

# --- User input ---
gather_input() {
  echo ""
  read -p "GitHub repo URL (bijv. https://github.com/user/repo.git): " GITHUB_REPO
  read -p "Domeinnaam (bijv. mijnapp.nl, of laat leeg voor IP): " DOMAIN
  read -p "Admin e-mailadres: " ADMIN_EMAIL
  read -sp "Kies een database wachtwoord: " DB_PASSWORD
  echo ""
  read -sp "Kies een admin dashboard wachtwoord: " DASHBOARD_PASSWORD
  echo ""

  APP_DIR="/opt/lovable-app"
  SUPABASE_DIR="/opt/supabase"
}

# --- Install system dependencies ---
install_dependencies() {
  log_info "Systeem updaten en dependencies installeren..."
  apt-get update -qq
  apt-get install -y -qq curl git nginx certbot python3-certbot-nginx ufw jq openssl

  # Docker
  if ! command -v docker &>/dev/null; then
    log_info "Docker installeren..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
  else
    log_info "Docker is al geïnstalleerd."
  fi

  # Docker Compose plugin
  if ! docker compose version &>/dev/null; then
    log_info "Docker Compose plugin installeren..."
    apt-get install -y -qq docker-compose-plugin
  fi
}

# --- Generate secrets ---
generate_secrets() {
  log_info "Beveiligingssleutels genereren..."

  JWT_SECRET=$(openssl rand -hex 32)
  ANON_KEY=$(generate_jwt "anon")
  SERVICE_ROLE_KEY=$(generate_jwt "service_role")
  POSTGRES_PASSWORD="$DB_PASSWORD"
  DASHBOARD_PASSWORD_HASH=$(docker run --rm supabase/gotrue:latest htpasswd -nbBC 10 "" "$DASHBOARD_PASSWORD" | tr -d ':\n' | sed 's/$2y/$2a/')
  SECRET_KEY_BASE=$(openssl rand -hex 64)
  LOGFLARE_API_KEY=$(openssl rand -hex 32)
}

generate_jwt() {
  local role=$1
  local header
  local payload
  header=$(echo -n '{"alg":"HS256","typ":"JWT"}' | base64 -w0 | tr '+/' '-_' | tr -d '=')
  payload=$(echo -n "{\"role\":\"$role\",\"iss\":\"supabase\",\"iat\":$(date +%s),\"exp\":$(($(date +%s) + 157680000))}" | base64 -w0 | tr '+/' '-_' | tr -d '=')
  local signature
  signature=$(echo -n "${header}.${payload}" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | base64 -w0 | tr '+/' '-_' | tr -d '=')
  echo "${header}.${payload}.${signature}"
}

# --- Clone app ---
clone_app() {
  log_info "App clonen van GitHub..."
  if [[ -d "$APP_DIR" ]]; then
    log_info "App directory bestaat al, git pull uitvoeren..."
    cd "$APP_DIR" && git pull
  else
    git clone "$GITHUB_REPO" "$APP_DIR"
  fi
}

# --- Setup Supabase ---
setup_supabase() {
  log_info "Self-hosted Supabase configureren..."

  mkdir -p "$SUPABASE_DIR"

  # Determine API URL
  local api_url
  if [[ -n "$DOMAIN" ]]; then
    api_url="https://$DOMAIN"
  else
    api_url="http://$(curl -s ifconfig.me)"
  fi

  # Create .env for Supabase
  cat > "$SUPABASE_DIR/.env" <<ENVEOF
# === Auto-generated Supabase Environment ===
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
JWT_SECRET=$JWT_SECRET
ANON_KEY=$ANON_KEY
SERVICE_ROLE_KEY=$SERVICE_ROLE_KEY
DASHBOARD_PASSWORD=$DASHBOARD_PASSWORD
SECRET_KEY_BASE=$SECRET_KEY_BASE
LOGFLARE_API_KEY=$LOGFLARE_API_KEY

# URLs
API_EXTERNAL_URL=$api_url
SUPABASE_PUBLIC_URL=$api_url

# SMTP (configureer later voor e-mail)
SMTP_ADMIN_EMAIL=$ADMIN_EMAIL
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=
SMTP_PASS=
SMTP_SENDER_NAME=Lovable App

# Site
SITE_URL=$api_url
ADDITIONAL_REDIRECT_URLS=
ENVEOF

  # Copy docker-compose for supabase
  cp "$APP_DIR/docker-compose.yml" "$SUPABASE_DIR/docker-compose.yml"

  # Create volumes directory
  mkdir -p "$SUPABASE_DIR/volumes/db/data"
  mkdir -p "$SUPABASE_DIR/volumes/storage"
  mkdir -p "$SUPABASE_DIR/volumes/db/init"

  # Copy migrations if they exist
  if [[ -d "$APP_DIR/supabase/migrations" ]]; then
    log_info "Database migraties kopiëren..."
    cp "$APP_DIR/supabase/migrations/"*.sql "$SUPABASE_DIR/volumes/db/init/" 2>/dev/null || true
  fi
}

# --- Build frontend ---
build_frontend() {
  log_info "Frontend bouwen..."

  local api_url
  if [[ -n "$DOMAIN" ]]; then
    api_url="https://$DOMAIN"
  else
    api_url="http://$(curl -s ifconfig.me)"
  fi

  # Create production env for the frontend
  cat > "$APP_DIR/.env.production" <<ENVEOF
VITE_SUPABASE_URL=$api_url
VITE_SUPABASE_PUBLISHABLE_KEY=$ANON_KEY
ENVEOF

  cd "$APP_DIR"
  docker build -t lovable-frontend -f Dockerfile .
}

# --- Start services ---
start_services() {
  log_info "Services starten..."

  cd "$SUPABASE_DIR"
  docker compose up -d

  log_info "Wachten tot services klaar zijn..."
  sleep 15

  # Start frontend container
  docker run -d \
    --name lovable-frontend \
    --restart unless-stopped \
    -p 3000:80 \
    lovable-frontend

  log_info "Services zijn gestart!"
}

# --- Configure Nginx ---
configure_nginx() {
  log_info "Nginx configureren..."

  local server_name
  if [[ -n "$DOMAIN" ]]; then
    server_name="$DOMAIN"
  else
    server_name="_"
  fi

  cat > /etc/nginx/sites-available/lovable <<NGINXEOF
# Lovable App + Supabase Reverse Proxy
server {
    listen 80;
    server_name $server_name;

    client_max_body_size 100M;

    # Frontend
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Supabase Auth
    location /auth/ {
        proxy_pass http://127.0.0.1:9999/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Supabase REST API (PostgREST)
    location /rest/ {
        proxy_pass http://127.0.0.1:3001/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Authorization \$http_authorization;
        proxy_set_header apikey \$http_apikey;
    }

    # Supabase Realtime
    location /realtime/ {
        proxy_pass http://127.0.0.1:4000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }

    # Supabase Storage
    location /storage/ {
        proxy_pass http://127.0.0.1:5000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Supabase Studio (Admin Dashboard)
    location /studio/ {
        proxy_pass http://127.0.0.1:8000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
NGINXEOF

  ln -sf /etc/nginx/sites-available/lovable /etc/nginx/sites-enabled/lovable
  rm -f /etc/nginx/sites-enabled/default
  nginx -t && systemctl reload nginx
}

# --- SSL ---
setup_ssl() {
  if [[ -n "$DOMAIN" ]]; then
    log_info "SSL certificaat aanvragen via Let's Encrypt..."
    certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$ADMIN_EMAIL" || {
      log_warn "SSL setup mislukt. Je kunt dit later handmatig doen met: certbot --nginx -d $DOMAIN"
    }
  else
    log_warn "Geen domeinnaam opgegeven, SSL overgeslagen. Configureer later met certbot."
  fi
}

# --- Firewall ---
configure_firewall() {
  log_info "Firewall configureren..."
  ufw --force enable
  ufw allow ssh
  ufw allow http
  ufw allow https
  ufw reload
}

# --- Create update script ---
create_update_script() {
  cat > "$APP_DIR/update.sh" <<'UPDATEEOF'
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
  # Copy new migrations
  cp "$APP_DIR/supabase/migrations/"*.sql "$SUPABASE_DIR/volumes/db/init/" 2>/dev/null || true

  # Run migrations via psql in the postgres container
  for migration in "$APP_DIR/supabase/migrations/"*.sql; do
    if [[ -f "$migration" ]]; then
      echo "  Migratie uitvoeren: $(basename "$migration")"
      docker exec supabase-db psql -U supabase -d postgres -f "/docker-entrypoint-initdb.d/$(basename "$migration")" 2>/dev/null || true
    fi
  done
fi

echo ""
echo "✅ Update compleet! De app draait weer."
UPDATEEOF

  chmod +x "$APP_DIR/update.sh"
  ln -sf "$APP_DIR/update.sh" /usr/local/bin/lovable-update
}

# --- Print summary ---
print_summary() {
  local url
  if [[ -n "$DOMAIN" ]]; then
    url="https://$DOMAIN"
  else
    url="http://$(curl -s ifconfig.me)"
  fi

  echo ""
  echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║         ✅ INSTALLATIE COMPLEET!              ║${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  🌐 App URL:        ${BLUE}$url${NC}"
  echo -e "  📊 Supabase Studio: ${BLUE}$url/studio/${NC}"
  echo ""
  echo -e "  🔑 Supabase Keys (bewaar deze!):"
  echo -e "     Anon Key:         ${YELLOW}$ANON_KEY${NC}"
  echo -e "     Service Role Key: ${YELLOW}$SERVICE_ROLE_KEY${NC}"
  echo -e "     JWT Secret:       ${YELLOW}$JWT_SECRET${NC}"
  echo -e "     DB Wachtwoord:    ${YELLOW}$POSTGRES_PASSWORD${NC}"
  echo ""
  echo -e "  📁 Bestanden:"
  echo -e "     App:       $APP_DIR"
  echo -e "     Supabase:  $SUPABASE_DIR"
  echo -e "     Env:       $SUPABASE_DIR/.env"
  echo ""
  echo -e "  🔄 Updates:"
  echo -e "     ${BLUE}lovable-update${NC}  (of: $APP_DIR/update.sh)"
  echo ""
  echo -e "  ⚠️  Bewaar bovenstaande keys veilig!"
  echo ""

  # Save credentials to file
  cat > "$SUPABASE_DIR/credentials.txt" <<CREDEOF
=== Lovable Supabase Credentials ===
Generated: $(date)

App URL: $url
Supabase Studio: $url/studio/

Anon Key: $ANON_KEY
Service Role Key: $SERVICE_ROLE_KEY
JWT Secret: $JWT_SECRET
Database Password: $POSTGRES_PASSWORD
Dashboard Password: $DASHBOARD_PASSWORD
Admin Email: $ADMIN_EMAIL

WAARSCHUWING: Bewaar dit bestand veilig en verwijder het van de server na het opslaan!
CREDEOF
  chmod 600 "$SUPABASE_DIR/credentials.txt"
  log_info "Credentials opgeslagen in: $SUPABASE_DIR/credentials.txt"
}

# === Main ===
main() {
  print_banner
  check_requirements
  gather_input
  install_dependencies
  clone_app
  generate_secrets
  setup_supabase
  build_frontend
  start_services
  configure_nginx
  setup_ssl
  configure_firewall
  create_update_script
  print_summary
}

main "$@"
