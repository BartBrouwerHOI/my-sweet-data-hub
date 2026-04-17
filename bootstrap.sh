#!/bin/bash
# ============================================================
# Lovable VPS Bootstrap — één-commando installer
# ============================================================
# Gebruik:
#   curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/main/bootstrap.sh | sudo bash
#
# Wat dit script doet:
#   1. Installeert git + curl als die ontbreken
#   2. Clones de infra-repo naar /opt/lovable-infra
#   3. Roept install.sh aan — die regelt de rest (Supabase, Nginx, app, edge functions)
# ============================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- Config (overridable via env) ---
INFRA_REPO="${INFRA_REPO:-https://github.com/BartBrouwerHOI/my-sweet-data-hub.git}"
INFRA_BRANCH="${INFRA_BRANCH:-main}"
INFRA_DIR="${INFRA_DIR:-/opt/lovable-infra}"

echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       🚀 Lovable VPS Bootstrap                ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo ""

# --- Root check ---
if [[ "$EUID" -ne 0 ]]; then
  echo -e "${RED}[ERROR]${NC} Dit script moet als root draaien."
  echo "  Probeer opnieuw met:  curl ... | sudo bash"
  exit 1
fi

# --- git/curl installeren als nodig ---
ensure_pkg() {
  local pkg="$1"
  if command -v "$pkg" &>/dev/null; then return 0; fi
  echo -e "${YELLOW}[INFO]${NC} $pkg ontbreekt — installeren..."
  if command -v apt-get &>/dev/null; then
    apt-get update -qq && apt-get install -y -qq "$pkg"
  elif command -v dnf &>/dev/null; then
    dnf install -y -q "$pkg"
  elif command -v yum &>/dev/null; then
    yum install -y -q "$pkg"
  else
    echo -e "${RED}[ERROR]${NC} Geen package manager gevonden (apt/dnf/yum). Installeer $pkg handmatig."
    exit 1
  fi
}

ensure_pkg git
ensure_pkg curl

# --- Clone of update infra-repo ---
if [[ -d "$INFRA_DIR/.git" ]]; then
  echo -e "${GREEN}[INFO]${NC} Infra-repo bestaat al — bijwerken..."
  cd "$INFRA_DIR" && git fetch --quiet && git reset --hard "origin/$INFRA_BRANCH"
elif [[ -e "$INFRA_DIR" ]]; then
  echo -e "${RED}[ERROR]${NC} $INFRA_DIR bestaat maar is geen git-repo."
  echo "  Verwijder het of zet INFRA_DIR=<andere-pad> en probeer opnieuw."
  exit 1
else
  echo -e "${GREEN}[INFO]${NC} Infra-repo clonen naar $INFRA_DIR..."
  git clone --quiet --branch "$INFRA_BRANCH" "$INFRA_REPO" "$INFRA_DIR"
fi

# --- Installer aanroepen ---
if [[ ! -f "$INFRA_DIR/install.sh" ]]; then
  echo -e "${RED}[ERROR]${NC} $INFRA_DIR/install.sh ontbreekt."
  exit 1
fi

echo ""
echo -e "${GREEN}[INFO]${NC} Bootstrap voltooid — installer starten..."
echo ""

# --- Stdin teruggeven aan de installer (anders kan hij niet vragen stellen via curl-pipe) ---
exec </dev/tty bash "$INFRA_DIR/install.sh" "$@"
