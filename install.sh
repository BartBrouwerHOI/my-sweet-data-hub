#!/bin/bash
set -euo pipefail

# ============================================================
# Lovable VPS Installer — Ubuntu 24 + Self-Hosted Supabase
# ============================================================
# Ondersteunt drie modi:
#   1) Volledige installatie (frontend + database)
#   2) Alleen database (Supabase stack)
#   3) Alleen frontend (React app + Nginx)
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DISTRO_FAMILY=""  # "debian" or "rhel"
DISTRO_ID=""

INSTALL_MODE=""
GITHUB_REPO=""
DOMAIN=""
ADMIN_EMAIL=""
DB_PASSWORD=""
DASHBOARD_PASSWORD=""
DB_SERVER_IP=""
DB_SERVER_ANON_KEY=""
APP_DIR="/opt/lovable-app"
SUPABASE_DIR="/opt/supabase"

JWT_SECRET=""
ANON_KEY=""
SERVICE_ROLE_KEY=""
POSTGRES_PASSWORD=""
SECRET_KEY_BASE=""
LOGFLARE_API_KEY=""

print_banner() {
  echo -e "${BLUE}"
  echo "╔══════════════════════════════════════════════╗"
  echo "║     Lovable VPS Installer v2.0               ║"
  echo "║     Ubuntu 24 + Self-Hosted Supabase         ║"
  echo "║     Single / Split Server Support            ║"
  echo "╚══════════════════════════════════════════════╝"
  echo -e "${NC}"
}

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Detect Linux distro ---
detect_distro() {
  if [[ -f /etc/os-release ]]; then
    DISTRO_ID=$(. /etc/os-release && echo "$ID")
  else
    log_error "Kan /etc/os-release niet lezen. Welk besturingssysteem gebruik je?"
    exit 1
  fi

  case "$DISTRO_ID" in
    ubuntu|debian)
      DISTRO_FAMILY="debian"
      log_info "Gedetecteerd: $DISTRO_ID (Debian-familie — apt/ufw)"
      ;;
    centos|almalinux|rocky|rhel|fedora)
      DISTRO_FAMILY="rhel"
      log_info "Gedetecteerd: $DISTRO_ID (RHEL-familie — dnf/firewalld)"
      ;;
    *)
      log_warn "Onbekende distro: $DISTRO_ID. Probeer als Debian-familie..."
      DISTRO_FAMILY="debian"
      ;;
  esac
}

# --- Pre-flight checks ---
check_requirements() {
  if [[ $EUID -ne 0 ]]; then
    log_error "Dit script moet als root gedraaid worden. Gebruik: sudo bash install.sh"
    exit 1
  fi

  local mem_mb
  mem_mb=$(free -m | awk '/^Mem:/{print $2}')
  local min_ram=2000
  [[ "$INSTALL_MODE" == "full" ]] && min_ram=3500

  if [[ $mem_mb -lt $min_ram ]]; then
    log_warn "Minimaal $((min_ram/1000+1))GB RAM aanbevolen voor deze modus. Gedetecteerd: ${mem_mb}MB"
    read -p "Wil je toch doorgaan? (j/n): " confirm
    [[ "$confirm" != "j" ]] && exit 1
  fi
}

# --- Install mode selection ---
select_mode() {
  echo ""
  echo -e "${BLUE}Welke installatie wil je uitvoeren?${NC}"
  echo ""
  echo "  1) Volledige installatie  — Frontend + Supabase + Database (single server)"
  echo "  2) Alleen database        — Supabase + PostgreSQL (voor split-setup)"
  echo "  3) Alleen frontend        — React app + Nginx (voor split-setup)"
  echo ""
  read -p "Keuze [1/2/3]: " mode_choice

  case "$mode_choice" in
    1) INSTALL_MODE="full" ;;
    2) INSTALL_MODE="database" ;;
    3) INSTALL_MODE="frontend" ;;
    *) log_error "Ongeldige keuze"; exit 1 ;;
  esac

  log_info "Modus: $INSTALL_MODE"
}

# --- User input ---
gather_input() {
  echo ""

  if [[ "$INSTALL_MODE" == "frontend" ]]; then
    read -p "IP of domein van de database-server: " DB_SERVER_IP
    read -p "Anon Key van de database-server: " DB_SERVER_ANON_KEY
  fi

  read -p "Domeinnaam (bijv. mijnapp.nl, of laat leeg voor IP): " DOMAIN
  read -p "Admin e-mailadres: " ADMIN_EMAIL

  if [[ "$INSTALL_MODE" != "frontend" ]]; then
    read -sp "Kies een database wachtwoord: " DB_PASSWORD
    echo ""
    read -sp "Kies een admin dashboard wachtwoord: " DASHBOARD_PASSWORD
    echo ""
  fi
}

# --- Install system dependencies ---
install_dependencies() {
  log_info "Systeem updaten en dependencies installeren..."

  if [[ "$DISTRO_FAMILY" == "debian" ]]; then
    apt-get update -qq
    apt-get install -y -qq curl git nginx certbot python3-certbot-nginx ufw jq openssl
  elif [[ "$DISTRO_FAMILY" == "rhel" ]]; then
    dnf install -y -q epel-release
    dnf install -y -q curl git nginx certbot certbot-nginx firewalld jq openssl
    systemctl enable --now firewalld
  fi

  if ! command -v docker &>/dev/null; then
    log_info "Docker installeren..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
  else
    log_info "Docker is al geïnstalleerd."
  fi

  if ! docker compose version &>/dev/null; then
    log_info "Docker Compose plugin installeren..."
    if [[ "$DISTRO_FAMILY" == "debian" ]]; then
      apt-get install -y -qq docker-compose-plugin
    elif [[ "$DISTRO_FAMILY" == "rhel" ]]; then
      dnf install -y -q docker-compose-plugin
    fi
  fi
}

# --- Generate secrets ---
generate_secrets() {
  log_info "Beveiligingssleutels genereren..."

  JWT_SECRET=$(openssl rand -hex 32)
  ANON_KEY=$(generate_jwt "anon")
  SERVICE_ROLE_KEY=$(generate_jwt "service_role")
  POSTGRES_PASSWORD="$DB_PASSWORD"
  SECRET_KEY_BASE=$(openssl rand -hex 64)
  LOGFLARE_API_KEY=$(openssl rand -hex 32)
}

generate_jwt() {
  local role=$1
  local header payload signature
  header=$(echo -n '{"alg":"HS256","typ":"JWT"}' | base64 -w0 | tr '+/' '-_' | tr -d '=')
  payload=$(echo -n "{\"role\":\"$role\",\"iss\":\"supabase\",\"iat\":$(date +%s),\"exp\":$(($(date +%s) + 157680000))}" | base64 -w0 | tr '+/' '-_' | tr -d '=')
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
    read -p "GitHub repo URL (SSH, bijv. git@github.com:user/repo.git): " GITHUB_REPO
    git clone "$GITHUB_REPO" "$APP_DIR"
  fi
}

# --- Setup Supabase ---
setup_supabase() {
  log_info "Self-hosted Supabase configureren..."

  mkdir -p "$SUPABASE_DIR"

  local api_url
  if [[ -n "$DOMAIN" ]]; then
    api_url="https://$DOMAIN"
  else
    api_url="http://$(curl -s ifconfig.me)"
  fi

  cat > "$SUPABASE_DIR/.env" <<ENVEOF
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
JWT_SECRET=$JWT_SECRET
ANON_KEY=$ANON_KEY
SERVICE_ROLE_KEY=$SERVICE_ROLE_KEY
DASHBOARD_PASSWORD=$DASHBOARD_PASSWORD
SECRET_KEY_BASE=$SECRET_KEY_BASE
LOGFLARE_API_KEY=$LOGFLARE_API_KEY
API_EXTERNAL_URL=$api_url
SUPABASE_PUBLIC_URL=$api_url
SMTP_ADMIN_EMAIL=$ADMIN_EMAIL
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=
SMTP_PASS=
SMTP_SENDER_NAME=Lovable App
SITE_URL=$api_url
ADDITIONAL_REDIRECT_URLS=
ENVEOF

  cp "$APP_DIR/docker-compose.yml" "$SUPABASE_DIR/docker-compose.yml"

  mkdir -p "$SUPABASE_DIR/volumes/db/data"
  mkdir -p "$SUPABASE_DIR/volumes/storage"
  mkdir -p "$SUPABASE_DIR/volumes/db/init"
  mkdir -p "$SUPABASE_DIR/volumes/kong"

  if [[ -f "$APP_DIR/volumes/kong/kong.yml" ]]; then
    cp "$APP_DIR/volumes/kong/kong.yml" "$SUPABASE_DIR/volumes/kong/kong.yml"
  fi

  if [[ -d "$APP_DIR/supabase/migrations" ]]; then
    log_info "Database migraties kopiëren..."
    cp "$APP_DIR/supabase/migrations/"*.sql "$SUPABASE_DIR/volumes/db/init/" 2>/dev/null || true
  fi
}

# --- Build frontend ---
build_frontend() {
  log_info "Frontend bouwen..."

  local api_url
  if [[ "$INSTALL_MODE" == "frontend" ]]; then
    api_url="http://$DB_SERVER_IP:8000"
    local anon_key="$DB_SERVER_ANON_KEY"
  else
    if [[ -n "$DOMAIN" ]]; then
      api_url="https://$DOMAIN"
    else
      api_url="http://$(curl -s ifconfig.me)"
    fi
    local anon_key="$ANON_KEY"
  fi

  cat > "$APP_DIR/.env.production" <<ENVEOF
VITE_SUPABASE_URL=$api_url
VITE_SUPABASE_PUBLISHABLE_KEY=$anon_key
ENVEOF

  cd "$APP_DIR"
  docker build -t lovable-frontend -f Dockerfile .
}

# --- Start services ---
start_supabase() {
  log_info "Supabase services starten..."
  cd "$SUPABASE_DIR"
  docker compose up -d
  log_info "Wachten tot database klaar is..."
  sleep 15
}

start_frontend() {
  log_info "Frontend container starten..."
  docker stop lovable-frontend 2>/dev/null || true
  docker rm lovable-frontend 2>/dev/null || true
  docker run -d \
    --name lovable-frontend \
    --restart unless-stopped \
    -p 3000:3000 \
    lovable-frontend
}

# --- Configure Nginx ---
configure_nginx() {
  log_info "Nginx configureren..."

  local server_name nginx_conf_path
  if [[ -n "$DOMAIN" ]]; then
    server_name="$DOMAIN"
  else
    server_name="_"
  fi

  # Distro-specifiek pad
  if [[ "$DISTRO_FAMILY" == "rhel" ]]; then
    nginx_conf_path="/etc/nginx/conf.d/lovable.conf"
  else
    nginx_conf_path="/etc/nginx/sites-available/lovable"
  fi

  if [[ "$INSTALL_MODE" == "frontend" ]]; then
    cat > "$nginx_conf_path" <<NGINXEOF
server {
    listen 80;
    server_name $server_name;
    client_max_body_size 100M;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /auth/ {
        proxy_pass http://$DB_SERVER_IP:8000/auth/v1/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location /rest/ {
        proxy_pass http://$DB_SERVER_IP:8000/rest/v1/;
        proxy_set_header Host \$host;
        proxy_set_header Authorization \$http_authorization;
        proxy_set_header apikey \$http_apikey;
    }

    location /storage/ {
        proxy_pass http://$DB_SERVER_IP:8000/storage/v1/;
        proxy_set_header Host \$host;
    }

    location /realtime/ {
        proxy_pass http://$DB_SERVER_IP:8000/realtime/v1/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
}
NGINXEOF
  elif [[ "$INSTALL_MODE" == "database" ]]; then
    cat > "$nginx_conf_path" <<NGINXEOF
server {
    listen 80;
    server_name $server_name;
    client_max_body_size 100M;

    location / {
        return 200 '{"status":"ok","service":"supabase-database"}';
        add_header Content-Type application/json;
    }
}
NGINXEOF
  else
    cat > "$nginx_conf_path" <<NGINXEOF
server {
    listen 80;
    server_name $server_name;
    client_max_body_size 100M;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location /auth/ {
        proxy_pass http://127.0.0.1:8000/auth/v1/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location /rest/ {
        proxy_pass http://127.0.0.1:8000/rest/v1/;
        proxy_set_header Host \$host;
        proxy_set_header Authorization \$http_authorization;
        proxy_set_header apikey \$http_apikey;
    }

    location /realtime/ {
        proxy_pass http://127.0.0.1:8000/realtime/v1/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }

    location /storage/ {
        proxy_pass http://127.0.0.1:8000/storage/v1/;
        proxy_set_header Host \$host;
    }

    location /studio/ {
        proxy_pass http://127.0.0.1:8080/;
        proxy_set_header Host \$host;
    }
}
NGINXEOF
  fi

  # Symlink voor Debian/Ubuntu
  if [[ "$DISTRO_FAMILY" == "debian" ]]; then
    ln -sf /etc/nginx/sites-available/lovable /etc/nginx/sites-enabled/lovable
    rm -f /etc/nginx/sites-enabled/default
  fi

  nginx -t && systemctl reload nginx
}

# --- SSL ---
setup_ssl() {
  if [[ -n "$DOMAIN" ]]; then
    log_info "SSL certificaat aanvragen via Let's Encrypt..."
    certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$ADMIN_EMAIL" || {
      log_warn "SSL setup mislukt. Later handmatig: certbot --nginx -d $DOMAIN"
    }
  else
    log_warn "Geen domeinnaam opgegeven, SSL overgeslagen."
  fi
}

# --- Firewall ---
configure_firewall() {
  log_info "Firewall configureren..."

  if [[ "$DISTRO_FAMILY" == "rhel" ]]; then
    # firewalld (CentOS/AlmaLinux/Rocky)
    systemctl enable --now firewalld
    firewall-cmd --permanent --add-service=ssh
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https

    if [[ "$INSTALL_MODE" == "database" ]]; then
      log_info "Database-modus: poort 8000 (Kong) openzetten..."
      firewall-cmd --permanent --add-port=8000/tcp
      log_warn "Beperk poort 8000 tot je frontend-server IP voor betere beveiliging:"
      log_warn "  firewall-cmd --permanent --remove-port=8000/tcp"
      log_warn "  firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=FRONTEND_IP port port=8000 protocol=tcp accept'"
    fi

    firewall-cmd --reload
  else
    # ufw (Ubuntu/Debian)
    ufw --force enable
    ufw allow ssh
    ufw allow http
    ufw allow https

    if [[ "$INSTALL_MODE" == "database" ]]; then
      log_info "Database-modus: poort 8000 (Kong) openzetten..."
      ufw allow 8000
      log_warn "Beperk poort 8000 tot je frontend-server IP voor betere beveiliging:"
      log_warn "  ufw delete allow 8000 && ufw allow from FRONTEND_IP to any port 8000"
    fi

    ufw reload
  fi
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

echo "[1/4] Code ophalen van GitHub..."
cd "$APP_DIR"
git pull

echo "[2/4] Frontend opnieuw bouwen..."
docker build -t lovable-frontend -f Dockerfile .

echo "[3/4] Frontend herstarten..."
docker stop lovable-frontend 2>/dev/null || true
docker rm lovable-frontend 2>/dev/null || true
docker run -d \
  --name lovable-frontend \
  --restart unless-stopped \
  -p 3000:3000 \
  lovable-frontend

echo "[4/4] Database migraties controleren..."
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
echo "✅ Update compleet!"
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
  echo -e "${GREEN}║         Modus: $(printf '%-30s' "$INSTALL_MODE") ║${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
  echo ""

  if [[ "$INSTALL_MODE" != "frontend" ]]; then
    echo -e "  🔑 Supabase Keys (BEWAAR DEZE!):"
    echo -e "     Anon Key:         ${YELLOW}$ANON_KEY${NC}"
    echo -e "     Service Role Key: ${YELLOW}$SERVICE_ROLE_KEY${NC}"
    echo -e "     JWT Secret:       ${YELLOW}$JWT_SECRET${NC}"
    echo -e "     DB Wachtwoord:    ${YELLOW}$POSTGRES_PASSWORD${NC}"
    echo ""

    cat > "$SUPABASE_DIR/credentials.txt" <<CREDEOF
=== Lovable Supabase Credentials ===
Generated: $(date)
Mode: $INSTALL_MODE

Anon Key: $ANON_KEY
Service Role Key: $SERVICE_ROLE_KEY
JWT Secret: $JWT_SECRET
Database Password: $POSTGRES_PASSWORD
Dashboard Password: $DASHBOARD_PASSWORD
Admin Email: $ADMIN_EMAIL
CREDEOF
    chmod 600 "$SUPABASE_DIR/credentials.txt"
    log_info "Credentials opgeslagen in: $SUPABASE_DIR/credentials.txt"
  fi

  if [[ "$INSTALL_MODE" != "database" ]]; then
    echo -e "  🌐 App URL: ${BLUE}$url${NC}"
  fi
  if [[ "$INSTALL_MODE" != "frontend" ]]; then
    echo -e "  📊 Studio:  ${BLUE}$url:8080${NC}"
  fi

  echo ""
  echo -e "  🔄 Updates: ${BLUE}lovable-update${NC}"
  echo ""
}

# === Main ===
main() {
  print_banner
  detect_distro
  select_mode
  check_requirements
  gather_input
  install_dependencies
  clone_app

  case "$INSTALL_MODE" in
    full)
      generate_secrets
      setup_supabase
      build_frontend
      start_supabase
      start_frontend
      ;;
    database)
      generate_secrets
      setup_supabase
      start_supabase
      ;;
    frontend)
      build_frontend
      start_frontend
      ;;
  esac

  configure_nginx
  setup_ssl
  configure_firewall
  create_update_script
  print_summary
}

main "$@"
