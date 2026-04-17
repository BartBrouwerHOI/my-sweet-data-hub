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

## Snelle Installatie (één commando)

```bash
curl -fsSL https://raw.githubusercontent.com/BartBrouwerHOI/my-sweet-data-hub/main/bootstrap.sh | sudo bash
```

Dat is het. Het script:
1. Installeert `git` + `curl` als die ontbreken
2. Cloned de infra-repo naar `/opt/lovable-infra`
3. Start `install.sh` — die regelt de Supabase-stack, Nginx, SSL, je app-repo én roept aan het eind automatisch app-eigen scripts aan (`scripts/bootstrap.sh` en `scripts/lovable-update.sh` als die in je app-repo bestaan — voor edge functions, secrets, cronjobs)

De installer vraagt interactief om:
- **Installatiemodus** — full / database / frontend
- **Domeinnaam** — of laat leeg voor IP
- **Admin e-mail** — voor SSL certificaten
- **Database + Dashboard wachtwoord**
- **GitHub repo URL** — SSH URL van je **app-project** (privé)

> **Tip:** De infra-repo is publiek — je hebt alleen een deploy key nodig voor je privé app-repo.

### Geavanceerd: handmatig clonen

Liever zelf controle? Kan ook:

```bash
git clone https://github.com/BartBrouwerHOI/my-sweet-data-hub /opt/lovable-infra
sudo bash /opt/lovable-infra/install.sh
```

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

# Updater zelf vernieuwen (na infra-update met nieuwe flags):
sudo bash /opt/lovable-infra/install.sh --refresh-updater
```

> **Let op:** `lovable-update` op de server is een gegenereerd script in `/usr/local/bin/`. Bij een normale update wordt dit script automatisch vernieuwd na `git pull` van de infra-repo. Mocht een nieuwe flag (zoals `--mark-done`) niet werken, vernieuw de updater handmatig:
> ```bash
> sudo bash /opt/lovable-infra/install.sh --refresh-updater
> ```

| Commando | Wat het doet |
|----------|-------------|
| `lovable-update` | Haalt infra + app op, herbouwt frontend, draait migraties |
| `lovable-update --app-only` | Alleen app-repo pullen + frontend rebuilden (geen infra, geen migraties) |
| `lovable-update --skip-migrations` | Volledige update maar slaat database migraties over |
| `lovable-update --mark-done <file>` | Markeer een migratie als uitgevoerd zonder deze te draaien |
| `install.sh --refresh-updater` | Vernieuw het `lovable-update` commando zonder herinstallatie |

## Edge Functions & app-eigen setup (automatisch)

Onze installer is **generiek** — hij zet Postgres, Auth, Kong, Storage en Realtime neer voor élk Lovable-project. **App-eigen zaken** (edge functions, secrets, cronjobs) horen in de **app-repo** zelf via de conventie:

- `scripts/bootstrap.sh` — eenmalige setup (edge-runtime container, Kong-route, secrets)
- `scripts/lovable-update.sh` — sync van functions code, herstart runtime

Aan het eind van de installatie detecteert `install.sh` deze scripts in `/opt/lovable-app/scripts/` en biedt aan ze automatisch te draaien. Bij elke `lovable-update` wordt `scripts/lovable-update.sh` óók automatisch aangeroepen — geen handwerk meer.

Wil je het handmatig draaien (bijv. na het toevoegen van een nieuwe function):

```bash
sudo bash /opt/lovable-app/scripts/lovable-update.sh
```

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
| `volumes/kong/kong.yml` | API gateway template — wordt op de server gerenderd met echte keys uit `/opt/supabase/.env` |
| `nginx/frontend-spa.conf` | Nginx config voor SPA (in container, port 3000) |

> **Routing:** Host-Nginx (port 80) proxyt API-routes (`/auth/v1/`, `/rest/v1/`, `/storage/v1/`, `/realtime/v1/`, `/functions/v1/`) naar Kong (`127.0.0.1:8000`) en de rest naar de frontend-container (`127.0.0.1:3000`). De app gebruikt daarom `VITE_SUPABASE_URL=http://<DOMAIN_OR_IP>` (same-origin, zonder `:8000`).
