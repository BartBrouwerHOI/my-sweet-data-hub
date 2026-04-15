# Lovable VPS Installer — Projectdocumentatie

## Wat is dit project?

Dit is een **universele self-hosted deployment toolkit** waarmee beheerders elk Lovable-project (React SPA of TanStack Start SSR) met een volledige Supabase backend kunnen deployen op een eigen VPS of Proxmox server — zonder dat het doelproject zelf deployment-bestanden nodig heeft.

> ⚠️ **Deze repository is publiek.** Zet hier **nooit** wachtwoorden, API keys, tokens of andere geheimen in. Alle secrets worden pas gegenereerd op de server door `install.sh` en opgeslagen in `/opt/supabase/.env` en `/opt/supabase/credentials.txt` (beide `chmod 600`). Bestanden zoals `docker-compose.yml` en `kong.yml` gebruiken `${VARIABELE}` placeholders die pas op de server worden ingevuld.

## Doelgroep

Systeembeheerders die Lovable-projecten willen hosten op eigen infrastructuur in plaats van Lovable Cloud. Het project is in het **Nederlands** geschreven, gericht op Nederlandse/Belgische beheerders.

## Architectuur

### Twee repo's, één (of twee) server(s)

```
/opt/lovable-infra/   ← DIT project (publiek, via HTTPS gecloned)
│  install.sh           — Hoofdinstaller (distro-detectie, mode-selectie, secrets, Docker, Nginx, SSL, firewall)
│  update.sh            — Standalone update-fallback (leest .install_mode marker)
│  Dockerfile.spa       — Multi-stage build voor SPA (Vite + React → Nginx)
│  Dockerfile.ssr       — Multi-stage build voor SSR (TanStack Start → Node)
│  docker-compose.yml   — Volledige self-hosted Supabase stack
│  volumes/kong/kong.yml — API Gateway configuratie
│  nginx/frontend-spa.conf — Nginx config voor SPA container
│  .install_mode        — Marker geschreven na installatie (full/database/frontend)

/opt/lovable-app/     ← Het DOEL-project van de gebruiker (privé, via SSH deploy key)
│  package.json, src/, supabase/migrations/

/opt/supabase/        ← Gegenereerd door install.sh
│  .env                 — Secrets (JWT, keys, wachtwoorden)
│  docker-compose.yml   — Kopie uit infra-repo
│  credentials.txt      — Alle keys + paden (chmod 600)
│  .migrations_done/    — Tracking van al-gedraaide migraties
│  volumes/             — Database data, storage, kong config
```

### Drie installatiemodi

| Modus | Wat het doet | Gebruik |
|-------|-------------|---------|
| **full** | Frontend + Supabase + Database op één server | Single server setup |
| **database** | Alleen Supabase stack (+ optioneel app-clone voor migraties) | Server A in split setup |
| **frontend** | Alleen React app + Nginx reverse proxy | Server B in split setup |

### Supabase stack (Docker Compose)

- **Kong** — API Gateway (poort 8000), valideert API keys
- **PostgreSQL** — Database
- **GoTrue** — Authenticatie (login/registratie)
- **PostgREST** — REST API
- **Storage** — Bestandsopslag
- **Realtime** — WebSocket verbindingen
- **Studio** — Admin dashboard (poort 8080)

### Request flow

```
Browser → Nginx (SSL/443)
          ├── /          → Frontend container (poort 3000, SPA of SSR)
          └── /auth      → Kong (8000) → GoTrue
              /rest      → Kong (8000) → PostgREST
              /storage   → Kong (8000) → Storage
              /realtime  → Kong (8000) → Realtime (WebSocket)
```

## Bestanden in dit project

### Scripts

| Bestand | Doel |
|---------|------|
| `install.sh` | Hoofdinstaller v3.0 — detecteert distro (Debian/RHEL), vraagt input, installeert Docker, genereert JWT secrets, cloned app-repo, bouwt frontend, start Supabase, configureert Nginx + SSL + firewall, schrijft `lovable-update` commando |
| `update.sh` | Standalone fallback als `lovable-update` niet bestaat. Leest `.install_mode` marker om de juiste update-stappen te kiezen |

### Docker

| Bestand | Doel |
|---------|------|
| `Dockerfile.spa` | Multi-stage: `bun install` → `vite build` → Nginx serving |
| `Dockerfile.ssr` | Multi-stage: `bun install` → `vite build` → Node.js server |
| `docker-compose.yml` | Volledige Supabase stack (9 services) |

### Configuratie

| Bestand | Doel |
|---------|------|
| `volumes/kong/kong.yml` | Kong API Gateway routes + JWT validatie |
| `nginx/frontend-spa.conf` | Nginx config voor SPA container (gzip, fallback naar index.html) |

### Website (dit project IS ook een website)

| Bestand | Doel |
|---------|------|
| `src/routes/index.tsx` | Landingspagina met architectuurdiagram |
| `src/routes/handleiding.tsx` | **Interactieve installatiehandleiding** — de kern van de site |

## De interactieve handleiding (`/handleiding`)

De handleiding is een React-pagina met:

### Configureerbare toggles
- **Setup mode**: Single server / Split (2 servers)
- **Linux distro**: Ubuntu/Debian / CentOS/AlmaLinux/Rocky
- **Formulier**: Infra-repo URL, app-repo user/naam, server IP, domein, Server A IP

### Placeholder-systeem
De `fill()` functie vervangt placeholders in alle codeblokken:
- `INFRA-REPO-URL` → ingevulde infra URL
- `APP-USER` / `APP-REPO` → GitHub gebruiker/repo
- `JOUW-SERVER-IP` → server IP
- `jouw-domein.nl` → domeinnaam
- `SERVER_A_IP` → backend server IP (split mode)

### Stappen (single mode)
1. Vereisten
2. Architectuur
3. GitHub deploy key instellen
4. Installatie (clone infra + run install.sh)
5. Na installatie (checks + troubleshooting link)
6. Updates draaien (`lovable-update`)
7. Data migreren uit Lovable Cloud (optioneel)
8. SMTP & OAuth instellen
9. Troubleshooting
10. Backup

### Stappen (split mode)
Zelfde, maar stap 4 wordt: Server A (database) + Server B (frontend)

## Belangrijke ontwerpbeslissingen

1. **Infra-repo is publiek (HTTPS), app-repo is privé (SSH deploy key)** — voorkomt de "twee deploy keys op GitHub"-complexiteit
2. **Geen secrets in de codebase** — alle wachtwoorden, JWT secrets en API keys worden pas op de server gegenereerd door `install.sh`. De bestanden in deze repo (`docker-compose.yml`, `kong.yml`) gebruiken `${VARIABELE}` placeholders. Commit nooit echte waarden.
3. **Markerbestand `.install_mode`** — geschreven door install.sh, gelezen door update.sh fallback voor correcte mode-detectie
4. **Migratie-tracking via `.migrations_done/`** — voorkomt dubbel draaien van SQL migraties
5. **Drie varianten `lovable-update`** — install.sh genereert een mode-specifiek update-script (full=5 stappen, database=4, frontend=3)
6. **`JOUW_ANON_KEY` staat NIET in kopieerbare blokken** — beheerder moet key uit `credentials.txt` halen om copy-paste fouten te voorkomen
7. **Autodetectie SPA vs SSR** — via `package.json` check op `@tanstack/react-start`
8. **Autodetectie Debian vs RHEL** — via `/etc/os-release`, kiest juiste package manager en firewall
9. **IP-detectie bij domeinnaam** — als een IP-adres wordt ingevuld bij "Domeinnaam" schakelt het script automatisch naar HTTP (geen SSL). Let's Encrypt kan geen certificaten uitgeven voor IP-adressen.
10. **Migratie-fouten blokkeren succes** — als een app-migratie faalt, meldt het script "INSTALLATIE DEELS VOLTOOID" in plaats van vals succes

## Tech stack

- **Framework**: TanStack Start v1 (React 19, SSR)
- **Styling**: Tailwind CSS v4
- **UI**: shadcn/ui componenten
- **Build**: Vite 7
- **Runtime**: Bun

## Taal

Alle UI-teksten, handleiding, scripts en documentatie zijn in het **Nederlands**.
