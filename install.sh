#!/bin/bash
set -euo pipefail

# ============================================================
# Lovable VPS Installer — Universele Deployment Toolkit
# ============================================================
# Dit project is de INFRASTRUCTUUR-laag.
# Het app-project wordt apart gecloned naar /opt/lovable-app.
#
# Ondersteunt:
#   - SPA projecten (Vite + React)
#   - SSR projecten (TanStack Start)
#   - Drie modi: full / database / frontend
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DISTRO_FAMILY=""
DISTRO_ID=""

INSTALL_MODE=""
GITHUB_REPO=""
DOMAIN=""
ADMIN_EMAIL=""
DB_PASSWORD=""
DASHBOARD_PASSWORD=""
DB_SERVER_IP=""
DB_SERVER_ANON_KEY=""

# Twee aparte directories: infra (dit project) en app (gebruikersproject)
INFRA_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="/opt/lovable-app"
SUPABASE_DIR="/opt/supabase"

# Gedetecteerd projecttype: "spa" of "ssr"
PROJECT_TYPE=""

JWT_SECRET=""
ANON_KEY=""
SERVICE_ROLE_KEY=""
POSTGRES_PASSWORD=""
SECRET_KEY_BASE=""
LOGFLARE_API_KEY=""

print_banner() {
  echo -e "${BLUE}"
  echo "╔══════════════════════════════════════════════╗"
  echo "║     Lovable VPS Installer v3.0               ║"
  echo "║     Universele Deployment Toolkit             ║"
  echo "║     SPA + SSR · Single + Split Server         ║"
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
CLONE_FOR_MIGRATIONS=""

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

  # In database mode: vraag hier al of de beheerder migraties wil
  if [[ "$INSTALL_MODE" == "database" ]]; then
    echo ""
    echo -e "${BLUE}Wil je de app-repo clonen voor automatische migraties?${NC}"
    echo "  Dit is nodig als je app database-migraties heeft."
    echo "  Het script cloned de app-repo naar $APP_DIR (alleen voor migraties, geen build)."
    echo ""
    read -p "App-repo clonen voor migraties? (j/n): " CLONE_FOR_MIGRATIONS
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

# --- Clone app (het DOEL-project, niet de infra) ---
clone_app() {
  log_info "App-project clonen van GitHub..."

  # --- Bestaande map afhandelen ---
  if [[ -d "$APP_DIR" ]]; then
    if [[ -d "$APP_DIR/.git" ]]; then
      log_info "App directory bestaat al met geldige repo, git pull uitvoeren..."
      cd "$APP_DIR" && git pull
      return
    else
      log_warn "Map $APP_DIR bestaat al maar is geen geldige git-repo."
      echo ""
      echo -e "  ${YELLOW}Dit komt meestal door een eerdere mislukte installatie.${NC}"
      echo "  Het script kan deze map veilig verwijderen en opnieuw beginnen."
      echo ""
      read -p "  Mag ik $APP_DIR verwijderen en opnieuw clonen? (j/n): " confirm
      if [[ "$confirm" == "j" ]]; then
        cd /
        rm -rf "$APP_DIR"
        log_info "Map verwijderd. Opnieuw clonen..."
      else
        log_error "Kan niet doorgaan met een onvolledige app-map."
        echo "  Verwijder de map handmatig:"
        echo "    cd ~ && sudo rm -rf $APP_DIR"
        exit 1
      fi
    fi
  fi

  # --- Repo URL vragen en clonen ---
  echo ""
  echo -e "${BLUE}Het script gaat nu je app-code clonen van GitHub.${NC}"
  echo "  Plak de SSH URL van je app-repo. Die vind je op GitHub → Code → SSH."
  echo "  Voorbeeld: git@github.com:JOUW-USER/JOUW-REPO.git"
  echo ""
  echo -e "  ${YELLOW}⚠ Dit is de URL van je APP-project, niet van de infra-repo!${NC}"
  echo ""

  while true; do
    read -p "GitHub repo URL (SSH): " GITHUB_REPO

    if [[ -z "$GITHUB_REPO" ]]; then
      log_error "Invoer is leeg. Plak de SSH URL van je GitHub repo."
      continue
    fi
    if [[ "$GITHUB_REPO" == *"#!/bin/bash"* || "$GITHUB_REPO" == *$'\n'* ]]; then
      log_error "Het lijkt erop dat je de inhoud van een script hebt geplakt!"
      echo "  Plak alleen de SSH URL, bijv.: git@github.com:user/repo.git"
      continue
    fi
    if [[ ! "$GITHUB_REPO" =~ ^git@github\.com:.+/.+\.git$ ]]; then
      log_error "Ongeldig formaat. Verwacht: git@github.com:USER/REPO.git"
      echo "  Gevonden: $GITHUB_REPO"
      read -p "Toch doorgaan met deze URL? (j/n): " confirm
      [[ "$confirm" != "j" ]] && continue
    fi
    break
  done

  # Test SSH-verbinding met GitHub vóór clone
  log_info "SSH-verbinding met GitHub testen..."
  local ssh_output
  ssh_output=$(ssh -T -o ConnectTimeout=10 git@github.com 2>&1 || true)
  if ! echo "$ssh_output" | grep -q "successfully authenticated"; then
    log_error "SSH-verbinding met GitHub mislukt!"
    echo ""
    echo "  Mogelijke oorzaken:"
    echo "  1. Geen deploy key aangemaakt — voer uit:"
    echo "     ssh-keygen -t ed25519 -C deploy@vps -f ~/.ssh/deploy_key -N \"\""
    echo "  2. Deploy key niet toegevoegd aan GitHub repo → Settings → Deploy keys"
    echo "  3. SSH config ontbreekt — maak ~/.ssh/config aan met:"
    echo "     Host github.com"
    echo "       IdentityFile ~/.ssh/deploy_key"
    echo "       IdentitiesOnly yes"
    echo ""
    echo "  💡 Draai je dit script met sudo? Dan moet de deploy key"
    echo "     ook beschikbaar zijn voor root. Kopieer hem:"
    echo "     sudo cp ~/.ssh/deploy_key /root/.ssh/deploy_key"
    echo "     sudo cp ~/.ssh/config /root/.ssh/config"
    echo ""
    echo "  Test handmatig: ssh -T git@github.com"
    echo "  Test als root:  sudo ssh -T git@github.com"
    echo ""
    read -p "Wil je toch doorgaan met clonen? (j/n): " confirm
    [[ "$confirm" != "j" ]] && exit 1
  fi

  git clone "$GITHUB_REPO" "$APP_DIR"
}

# --- Detect project type (SPA vs SSR) ---
detect_project_type() {
  log_info "Projecttype detecteren..."

  if [[ ! -f "$APP_DIR/package.json" ]]; then
    log_error "Geen package.json gevonden in $APP_DIR"
    echo "  Is dit wel een JavaScript/TypeScript project?"
    exit 1
  fi

  # Check for TanStack Start (SSR)
  if grep -q '"@tanstack/react-start"' "$APP_DIR/package.json" 2>/dev/null; then
    PROJECT_TYPE="ssr"
    log_info "Projecttype: SSR (TanStack Start)"
  else
    PROJECT_TYPE="spa"
    log_info "Projecttype: SPA (Vite + React)"
  fi
}

# --- Setup Supabase (bestanden komen uit INFRA_DIR) ---
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

  # docker-compose.yml en kong.yml komen uit de INFRA-repo, niet uit de app-repo
  if [[ ! -f "$INFRA_DIR/docker-compose.yml" ]]; then
    log_error "docker-compose.yml niet gevonden in $INFRA_DIR"
    echo ""
    echo "  Dit bestand hoort in de infra-repo (dit project) te staan."
    echo "  Controleer of je de infra-repo correct hebt gecloned."
    echo ""
    echo "  Bestanden in $INFRA_DIR:"
    ls -la "$INFRA_DIR/" 2>/dev/null || echo "  (map niet gevonden)"
    exit 1
  fi

  cp "$INFRA_DIR/docker-compose.yml" "$SUPABASE_DIR/docker-compose.yml"

  mkdir -p "$SUPABASE_DIR/volumes/storage"
  mkdir -p "$SUPABASE_DIR/volumes/db/init"
  mkdir -p "$SUPABASE_DIR/volumes/kong"

  if [[ -f "$INFRA_DIR/volumes/kong/kong.yml" ]]; then
    cp "$INFRA_DIR/volumes/kong/kong.yml" "$SUPABASE_DIR/volumes/kong/kong.yml"
  fi

  # Kopieer database init script (rollen, schema's, extensions)
  if [[ -f "$INFRA_DIR/volumes/db/init/00-supabase-init.sql" ]]; then
    cp "$INFRA_DIR/volumes/db/init/00-supabase-init.sql" "$SUPABASE_DIR/volumes/db/init/00-supabase-init.sql"
  fi

  # Migraties komen uit de APP-repo (als die gecloned is)
  if [[ -d "$APP_DIR/supabase/migrations" ]]; then
    log_info "Database migraties kopiëren vanuit app-repo..."
    cp "$APP_DIR/supabase/migrations/"*.sql "$SUPABASE_DIR/volumes/db/init/" 2>/dev/null || true
  else
    log_info "Geen app-repo gevonden — migraties overgeslagen."
  fi
}

# --- Build frontend (SPA of SSR, Dockerfile uit INFRA_DIR) ---
build_frontend() {
  log_info "Frontend bouwen (type: $PROJECT_TYPE)..."

  local api_url anon_key
  if [[ "$INSTALL_MODE" == "frontend" ]]; then
    api_url="http://$DB_SERVER_IP:8000"
    anon_key="$DB_SERVER_ANON_KEY"
  else
    if [[ -n "$DOMAIN" ]]; then
      api_url="https://$DOMAIN"
    else
      api_url="http://$(curl -s ifconfig.me)"
    fi
    anon_key="$ANON_KEY"
  fi

  # .env.production schrijven in de app-directory
  cat > "$APP_DIR/.env.production" <<ENVEOF
VITE_SUPABASE_URL=$api_url
VITE_SUPABASE_PUBLISHABLE_KEY=$anon_key
ENVEOF

  # Selecteer het juiste Dockerfile en kopieer nginx config indien SPA
  local dockerfile
  if [[ "$PROJECT_TYPE" == "spa" ]]; then
    dockerfile="$INFRA_DIR/Dockerfile.spa"
    # SPA heeft een nginx.conf nodig in de app-dir voor de Docker COPY
    cp "$INFRA_DIR/nginx/frontend-spa.conf" "$APP_DIR/nginx.conf"
  else
    dockerfile="$INFRA_DIR/Dockerfile.ssr"
  fi

  if [[ ! -f "$dockerfile" ]]; then
    log_error "Dockerfile niet gevonden: $dockerfile"
    echo "  Verwacht projecttype: $PROJECT_TYPE"
    echo "  Controleer of de infra-repo compleet is."
    exit 1
  fi

  log_info "Bouwen met: $dockerfile"
  cd "$APP_DIR"
  docker build -t lovable-frontend -f "$dockerfile" .
}

# --- Start services ---
start_supabase() {
  log_info "Supabase services starten..."
  cd "$SUPABASE_DIR"
  docker compose up -d
  log_info "Wachten tot database klaar is..."
  local max_wait=30
  local waited=0
  while [ $waited -lt $max_wait ]; do
    if docker exec supabase-db pg_isready -U postgres >/dev/null 2>&1; then
      log_info "Database is klaar (na ${waited}s)"
      break
    fi
    sleep 1
    waited=$((waited + 1))
  done
  if [ $waited -ge $max_wait ]; then
    log_warn "Database niet klaar na ${max_wait}s — ga toch door"
  fi
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
  if [[ "$INSTALL_MODE" == "database" ]]; then
    # Database-only mode: infra + app pull (voor migraties) + supabase restart
    cat > /usr/local/bin/lovable-update <<UPDATEEOF
#!/bin/bash
set -euo pipefail

INFRA_DIR="$INFRA_DIR"
APP_DIR="$APP_DIR"
SUPABASE_DIR="$SUPABASE_DIR"
MIGRATIONS_DONE_DIR="$SUPABASE_DIR/.migrations_done"

echo "=== Lovable Supabase Updater ==="
echo ""

echo "[1/4] Infra-repo updaten..."
cd "\$INFRA_DIR" && git pull

echo "[2/4] App-repo updaten (voor migraties)..."
if [[ -d "\$APP_DIR/.git" ]]; then
  cd "\$APP_DIR" && git pull
else
  echo "  ⚠ App-repo niet gevonden in \$APP_DIR — migraties overgeslagen"
fi

echo "[3/4] Database migraties controleren..."
mkdir -p "\$MIGRATIONS_DONE_DIR"
if [[ -d "\$APP_DIR/supabase/migrations" ]]; then
  for migration in "\$APP_DIR/supabase/migrations/"*.sql; do
    if [[ -f "\$migration" ]]; then
      local_name="\$(basename "\$migration")"
      if [[ ! -f "\$MIGRATIONS_DONE_DIR/\$local_name" ]]; then
        echo "  Nieuwe migratie: \$local_name"
        cp "\$migration" "\$SUPABASE_DIR/volumes/db/init/\$local_name"
        if docker exec -i supabase-db psql -U supabase -d postgres --single-transaction < "\$migration"; then
          touch "\$MIGRATIONS_DONE_DIR/\$local_name"
          echo "    ✅ Succesvol"
        else
          echo "    ❌ Mislukt — controleer handmatig"
        fi
      fi
    fi
  done
fi

echo "[4/4] Supabase stack herstarten..."
cd "\$SUPABASE_DIR" && docker compose up -d

echo ""
echo "✅ Update compleet!"
UPDATEEOF
  elif [[ "$INSTALL_MODE" == "frontend" ]]; then
    # Frontend-only mode: geen migraties, geen database
    cat > /usr/local/bin/lovable-update <<UPDATEEOF
#!/bin/bash
set -euo pipefail

INFRA_DIR="$INFRA_DIR"
APP_DIR="$APP_DIR"
PROJECT_TYPE="$PROJECT_TYPE"

echo "=== Lovable Frontend Updater ==="
echo ""

# 1. Update infra-repo
echo "[1/3] Infra-repo updaten..."
cd "\$INFRA_DIR" && git pull

# 2. Update app-repo + rebuild
echo "[2/3] App-code ophalen en bouwen (type: \$PROJECT_TYPE)..."
cd "\$APP_DIR" && git pull
if [[ "\$PROJECT_TYPE" == "spa" ]]; then
  cp "\$INFRA_DIR/nginx/frontend-spa.conf" "\$APP_DIR/nginx.conf"
  docker build -t lovable-frontend -f "\$INFRA_DIR/Dockerfile.spa" "\$APP_DIR"
else
  docker build -t lovable-frontend -f "\$INFRA_DIR/Dockerfile.ssr" "\$APP_DIR"
fi

# 3. Restart frontend container
echo "[3/3] Frontend herstarten..."
docker stop lovable-frontend 2>/dev/null || true
docker rm lovable-frontend 2>/dev/null || true
docker run -d \\
  --name lovable-frontend \\
  --restart unless-stopped \\
  -p 3000:3000 \\
  lovable-frontend

echo ""
echo "✅ Update compleet!"
UPDATEEOF
  else
    # Full mode: frontend + database + migraties
    cat > /usr/local/bin/lovable-update <<UPDATEEOF
#!/bin/bash
set -euo pipefail

INFRA_DIR="$INFRA_DIR"
APP_DIR="$APP_DIR"
SUPABASE_DIR="$SUPABASE_DIR"
PROJECT_TYPE="$PROJECT_TYPE"
MIGRATIONS_DONE_DIR="$SUPABASE_DIR/.migrations_done"

echo "=== Lovable App Updater ==="
echo ""

# 1. Update infra-repo
echo "[1/5] Infra-repo updaten..."
cd "\$INFRA_DIR" && git pull

# 2. Update app-repo
echo "[2/5] App-code ophalen van GitHub..."
cd "\$APP_DIR" && git pull

# 3. Rebuild frontend met Dockerfile uit infra-repo
echo "[3/5] Frontend opnieuw bouwen (type: \$PROJECT_TYPE)..."
if [[ "\$PROJECT_TYPE" == "spa" ]]; then
  cp "\$INFRA_DIR/nginx/frontend-spa.conf" "\$APP_DIR/nginx.conf"
  docker build -t lovable-frontend -f "\$INFRA_DIR/Dockerfile.spa" "\$APP_DIR"
else
  docker build -t lovable-frontend -f "\$INFRA_DIR/Dockerfile.ssr" "\$APP_DIR"
fi

# 4. Restart frontend container
echo "[4/5] Frontend herstarten..."
docker stop lovable-frontend 2>/dev/null || true
docker rm lovable-frontend 2>/dev/null || true
docker run -d \\
  --name lovable-frontend \\
  --restart unless-stopped \\
  -p 3000:3000 \\
  lovable-frontend

# 5. Database migraties (alleen nieuwe)
echo "[5/5] Database migraties controleren..."
mkdir -p "\$MIGRATIONS_DONE_DIR"
if [[ -d "\$APP_DIR/supabase/migrations" ]]; then
  for migration in "\$APP_DIR/supabase/migrations/"*.sql; do
    if [[ -f "\$migration" ]]; then
      local_name="\$(basename "\$migration")"
      if [[ ! -f "\$MIGRATIONS_DONE_DIR/\$local_name" ]]; then
        echo "  Nieuwe migratie: \$local_name"
        cp "\$migration" "\$SUPABASE_DIR/volumes/db/init/\$local_name"
        if docker exec -i supabase-db psql -U supabase -d postgres --single-transaction < "\$migration"; then
          touch "\$MIGRATIONS_DONE_DIR/\$local_name"
          echo "    ✅ Succesvol"
        else
          echo "    ❌ Mislukt — controleer handmatig"
        fi
      fi
    fi
  done
fi

echo ""
echo "✅ Update compleet!"
UPDATEEOF
  fi

  chmod +x /usr/local/bin/lovable-update
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
  if [[ -n "$PROJECT_TYPE" ]]; then
    echo -e "${GREEN}║         Type:  $(printf '%-30s' "$PROJECT_TYPE") ║${NC}"
  fi
  echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
  echo ""

  if [[ "$INSTALL_MODE" != "frontend" ]]; then
    echo -e "  🔑 Supabase Keys (BEWAAR DEZE!):"
    echo -e "     Anon Key:         ${YELLOW}$ANON_KEY${NC}"
    echo -e "     Service Role Key: ${YELLOW}$SERVICE_ROLE_KEY${NC}"
    echo -e "     JWT Secret:       ${YELLOW}$JWT_SECRET${NC}"
    echo -e "     DB Wachtwoord:    ${YELLOW}$POSTGRES_PASSWORD${NC}"
    echo ""

    {
      echo "=== Lovable Supabase Credentials ==="
      echo "Generated: $(date)"
      echo "Mode: $INSTALL_MODE"
      [[ -n "$PROJECT_TYPE" ]] && echo "Project Type: $PROJECT_TYPE"
      echo ""
      echo "Anon Key: $ANON_KEY"
      echo "Service Role Key: $SERVICE_ROLE_KEY"
      echo "JWT Secret: $JWT_SECRET"
      echo "Database Password: $POSTGRES_PASSWORD"
      echo "Dashboard Password: $DASHBOARD_PASSWORD"
      echo "Admin Email: $ADMIN_EMAIL"
      echo ""
      echo "Infra Dir: $INFRA_DIR"
      [[ -d "$APP_DIR/.git" ]] && echo "App Dir: $APP_DIR"
    } > "$SUPABASE_DIR/credentials.txt"
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
  echo -e "  📂 Infra:   ${BLUE}$INFRA_DIR${NC}"
  if [[ -d "$APP_DIR/.git" ]]; then
    echo -e "  📂 App:     ${BLUE}$APP_DIR${NC}"
  fi
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

  # Clone het app-project (de infra-repo is al aanwezig — dat is waar dit script vandaan draait)
  if [[ "$INSTALL_MODE" != "database" ]]; then
    clone_app
    detect_project_type
  elif [[ "$CLONE_FOR_MIGRATIONS" == "j" ]]; then
    clone_app
  fi

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

  # Schrijf install-mode marker zodat update.sh (fallback) de juiste modus kent
  echo "$INSTALL_MODE" > "$INFRA_DIR/.install_mode"

  print_summary
}

main "$@"
