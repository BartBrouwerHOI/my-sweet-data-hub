

## Plan: Handleiding-pagina met Proxmox/Split-Server Setup

### Wat wordt gebouwd

Twee nieuwe pagina's in de app plus een navigatie-header:

**1. Landingspagina (`src/routes/index.tsx`)** — vervangt placeholder
- Korte uitleg: wat dit project is (self-hosted Lovable + Supabase)
- Knop naar `/handleiding`
- Architectuuroverzicht

**2. Handleiding (`src/routes/handleiding.tsx`)** — stap-voor-stap guide

Secties:

1. **Vereisten** — Ubuntu 24 VM in Proxmox, minimaal 4GB RAM (of 2x 2GB bij split), SSH-toegang, privé GitHub repo
2. **Architectuur kiezen** — Twee opties uitgelegd:
   - **Single server**: alles op één VM
   - **Split setup**: Server A = database (Supabase/PostgreSQL), Server B = frontend (Node.js + Nginx)
3. **GitHub deploy key instellen** — SSH key aanmaken op de VM, toevoegen als deploy key in je privé repo, zodat `git clone` werkt zonder wachtwoord
4. **Single-server installatie** — `git clone` → `bash install.sh` → klaar
5. **Split-server: Database-server** — Alleen PostgreSQL + Supabase containers draaien, firewall openzetten voor poort 5432/8000
6. **Split-server: Frontend-server** — Frontend container + Nginx, `.env.production` wijst naar de database-server IP
7. **Na installatie** — Controleren, Studio dashboard, app URL
8. **Updates draaien** — `git pull` + `lovable-update`, wat er gebeurt
9. **Data migreren uit Lovable Cloud** — Export/import stappen
10. **SMTP & OAuth** — E-mail en Google login configureren
11. **Troubleshooting** — Veelvoorkomende problemen
12. **Backup** — Database dump commando's

**3. Header (`src/components/Header.tsx`)** — simpele navigatie Home / Handleiding

**4. Root layout update (`src/routes/__root.tsx`)** — Header toevoegen

### Aanpassingen aan install-scripts

- **`install.sh`** krijgt een keuzemenu: "Volledige installatie" / "Alleen database" / "Alleen frontend"
- Bij "Alleen frontend" vraagt het script om het IP/domein van de database-server
- Bij "Alleen database" worden alleen de Supabase Docker containers gestart + firewall-regels
- GitHub clone via SSH deploy key (instructies in de handleiding)
- Geen VPS-provider aanbevelingen — gaat ervan uit dat je al een Proxmox VM hebt

### Bestanden

| Bestand | Actie |
|---------|-------|
| `src/routes/index.tsx` | Vervangen — landingspagina |
| `src/routes/handleiding.tsx` | Nieuw — complete handleiding |
| `src/components/Header.tsx` | Nieuw — navigatie |
| `src/routes/__root.tsx` | Aangepast — Header toevoegen |
| `install.sh` | Aangepast — keuzemenu single/split |
| `docker-compose.yml` | Aangepast — split-mode support |
| `INSTALL.md` | Bijgewerkt — verwijst naar de website |

