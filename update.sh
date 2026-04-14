#!/bin/bash
set -euo pipefail

# ============================================================
# Lovable App Updater — Universele Deployment Toolkit
# ============================================================
# Dit is een fallback. De installer maakt een lovable-update
# commando aan met de juiste paden en projecttype.
# Gebruik bij voorkeur: lovable-update
# ============================================================

echo "=== Lovable App Updater ==="
echo ""
echo "💡 Gebruik bij voorkeur het commando: lovable-update"
echo "   Dat bevat de juiste configuratie voor jouw installatie."
echo ""

if command -v lovable-update &>/dev/null; then
  exec lovable-update
fi

echo "[ERROR] lovable-update niet gevonden."
echo "  Draai eerst de installer opnieuw, of gebruik:"
echo "  sudo bash /opt/lovable-infra/install.sh"
exit 1
