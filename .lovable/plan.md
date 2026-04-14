

## Plan: Linux distro-selectie toevoegen

### Analyse

Het install script heeft 4 distro-specifieke onderdelen:

| Onderdeel | Ubuntu/Debian | CentOS/AlmaLinux/Rocky |
|-----------|--------------|----------------------|
| Packages | `apt-get install nginx certbot...` | `dnf install nginx certbot...` |
| Firewall | `ufw` | `firewalld` |
| Nginx config pad | `/etc/nginx/sites-available/` | `/etc/nginx/conf.d/` |
| Certbot | `python3-certbot-nginx` (apt) | `certbot-nginx` (dnf) |
| Docker Compose | `docker-compose-plugin` (apt) | `docker-compose-plugin` (dnf) |

Docker zelf (`get.docker.com`) werkt op alle distro's. De rest van het script (secrets, Supabase, frontend build) is distro-onafhankelijk.

### Ondersteunde distro's

1. **Ubuntu 22.04 / 24.04** — huidige standaard
2. **Debian 11 / 12** — bijna identiek aan Ubuntu (apt, ufw)
3. **CentOS Stream 9 / AlmaLinux 9 / Rocky Linux 9** — dnf, firewalld, andere nginx paden

### Wijzigingen

**`install.sh`**
- Distro auto-detectie toevoegen via `/etc/os-release` (ID veld: ubuntu, debian, centos, almalinux, rocky)
- `install_dependencies()` splitsen: apt-variant en dnf-variant
- `configure_firewall()` splitsen: ufw-variant en firewalld-variant
- `configure_nginx()` pad aanpassen: `sites-available` (Debian/Ubuntu) vs `conf.d` (RHEL-familie)
- Geen gebruikersinput nodig — script detecteert automatisch

**`src/routes/handleiding.tsx`**
- Distro-keuze toggle toevoegen (naast de single/split toggle): "Ubuntu/Debian" | "CentOS/AlmaLinux/Rocky"
- Vereisten-stap aanpassen per distro (minimale OS-versie)
- SSH-commando's blijven hetzelfde
- Alleen de package-install en firewall-stappen tonen relevante commando's per gekozen distro
- InfoTooltip toevoegen dat het script de distro automatisch detecteert

### Bestanden

| Bestand | Actie |
|---------|-------|
| `install.sh` | Auto-detectie + distro-specifieke functies voor packages, firewall, nginx paden |
| `src/routes/handleiding.tsx` | Distro-toggle UI + conditionele weergave van commando's per distro |

