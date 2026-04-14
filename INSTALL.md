# 🚀 Lovable VPS Installatie Handleiding

## Over dit project

Dit project is een **universele deployment-toolkit** voor Lovable-projecten. Het bevat de infrastructuur (installer, Supabase stack, Dockerfiles) om elk Lovable-project te deployen op een VPS — zonder dat het doel-project zelf deployment-bestanden nodig heeft.

### Architectuur

```
/opt/lovable-infra/    ← Dit project (installer + infra)
/opt/lovable-app/      ← Jouw Lovable app (apart gecloned)
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
# 1. Clone de infra-repo
sudo mkdir -p /opt/lovable-infra
sudo chown $USER:$USER /opt/lovable-infra
git clone git@github.com:INFRA-USER/INFRA-REPO.git /opt/lovable-infra

# 2. Start de installer (vraagt om je APP-repo URL)
sudo bash /opt/lovable-infra/install.sh
```

Het script vraagt om:
- **Installatiemodus** — full / database / frontend
- **GitHub repo URL** — SSH URL van je **app-project**
- **Domeinnaam** — of laat leeg voor IP
- **Admin e-mail** — voor SSL certificaten
- **Database + Dashboard wachtwoord**

## Updates

```bash
lovable-update
```

Dit haalt updates op voor zowel de infra-repo als de app-repo, herbouwt de frontend en draait migraties.

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
| `Dockerfile.spa` | Build template voor SPA projecten |
| `Dockerfile.ssr` | Build template voor SSR projecten |
| `docker-compose.yml` | Self-hosted Supabase stack |
| `volumes/kong/kong.yml` | API gateway configuratie |
| `nginx/frontend-spa.conf` | Nginx config voor SPA (in container) |
| `nginx/frontend-ssr.conf` | Nginx config voor SSR (in container) |
