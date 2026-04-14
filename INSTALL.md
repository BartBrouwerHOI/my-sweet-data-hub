# 🚀 Lovable VPS Installatie Handleiding

## Over dit project

Dit project is een **universele deployment-toolkit** voor Lovable-projecten. Het bevat de infrastructuur (installer, Supabase stack, Dockerfiles) om elk Lovable-project te deployen op een VPS — zonder dat het doel-project zelf deployment-bestanden nodig heeft.

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
lovable-update
```

Dit haalt updates op voor zowel de infra-repo als de app-repo, herbouwt de frontend en draait nieuwe migraties (reeds gedraaide migraties worden overgeslagen).

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
