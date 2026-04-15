# 🚀 Lovable VPS Installatie Handleiding

## Over dit project

Dit project is een **universele deployment-toolkit** voor Lovable-projecten. Het bevat de infrastructuur (installer, Supabase stack, Dockerfiles) om elk Lovable-project te deployen op een VPS — zonder dat het doel-project zelf deployment-bestanden nodig heeft.

> ⚠️ **Deze repository is publiek.** Zet hier **nooit** wachtwoorden, API keys, tokens of andere geheimen in. Alle secrets worden pas gegenereerd op de server door `install.sh` en staan alleen in `/opt/supabase/.env` en `/opt/supabase/credentials.txt` (beide `chmod 600`).

### Architectuur

```
/opt/lovable-infra/    ← Dit project (publiek, via HTTPS gecloned)
/opt/lovable-app/      ← Jouw Lovable app (privé, via SSH deploy key)
/opt/supabase/         ← Supabase config + data (gegenereerd)
```

Het script detecteert automatisch of je app een **SPA** (Vite + React) of **SSR** (TanStack Start) project is.

## Vereisten

| Vereiste | Minimum |
|----------|---------|
| OS | Ubuntu 24.04 LTS |
| RAM | 4 GB |
| Opslag | 20 GB SSD |
| Netwerk | Publiek IP-adres |
| Domeinnaam | Aanbevolen (voor SSL) |

## Snelle Installatie

```bash
# 1. Clone de infra-repo (publiek, geen key nodig)
git clone INFRA-REPO-URL /opt/lovable-infra

# 2. Start de installer (vraagt om de SSH URL van je APP-repo)
sudo bash /opt/lovable-infra/install.sh
```

Het script vraagt om:
- **Installatiemodus** — full / database / frontend
- **Domeinnaam** — of laat leeg voor IP
- **Admin e-mail** — voor SSL certificaten
- **Database + Dashboard wachtwoord**
- **GitHub repo URL** — SSH URL van je **app-project** (privé)

> **Tip:** De infra-repo is publiek — je hebt alleen een deploy key nodig voor je privé app-repo.

## Updates

```bash
# Volledige update (infra + app + migraties):
lovable-update

# Snelle app-only update (alleen app rebuilden):
lovable-update --app-only

# Volledige update zonder migraties:
lovable-update --skip-migrations

# Migratie handmatig als gedaan markeren (bij vastlopende migratie):
lovable-update --mark-done <migratiebestand.sql>
```

| Commando | Wat het doet |
|----------|-------------|
| `lovable-update` | Haalt infra + app op, herbouwt frontend, draait migraties |
| `lovable-update --app-only` | Alleen app-repo pullen + frontend rebuilden (geen infra, geen migraties) |
| `lovable-update --skip-migrations` | Volledige update maar slaat database migraties over |
| `lovable-update --mark-done <file>` | Markeer een migratie als uitgevoerd zonder deze te draaien |

## Interactieve Handleiding

Dit project bevat een uitgebreide interactieve handleiding op `/handleiding` met:
- Stap-voor-stap instructies
- Automatisch ingevulde commando's
- Single server en split-setup ondersteuning
- Ubuntu/Debian en CentOS/RHEL ondersteuning

## Bestanden

| Bestand | Doel |
|---------|------|
| `install.sh` | Hoofdinstaller (v3.0) |
| `update.sh` | Standalone update-fallback |
| `Dockerfile.spa` | Build template voor SPA projecten |
| `Dockerfile.ssr` | Build template voor SSR projecten |
| `docker-compose.yml` | Self-hosted Supabase stack |
| `volumes/kong/kong.yml` | API gateway configuratie |
| `nginx/frontend-spa.conf` | Nginx config voor SPA (in container) |
