

## Plan: Eén-klik VPS Installer — Full-Stack Lovable + Self-Hosted Supabase

### Wat je krijgt

Een enkel `install.sh` script dat je op een verse Ubuntu 24 VPS draait. Het installeert alles automatisch via Docker en haalt je code uit GitHub. Bij updates in Lovable doe je gewoon `git pull` en de app herstart automatisch.

### Hoe het werkt

```text
Browser → Nginx (SSL/port 443)
            ├── / → Frontend container (je Lovable React app)
            └── /api, /auth, /rest, /storage → Supabase containers
                    ├── PostgreSQL
                    ├── GoTrue (auth)
                    ├── PostgREST (API)
                    ├── Storage
                    └── Realtime
```

### Wat het install-script doet

1. Vraagt om: GitHub repo URL, domeinnaam, admin e-mail
2. Installeert Docker + Docker Compose + Nginx + Certbot
3. Cloned je GitHub repo
4. Genereert veilige JWT secrets, anon key, service role key automatisch
5. Bouwt de frontend als Docker container (Node build → Nginx static)
6. Start Supabase stack via Docker Compose (PostgreSQL, Auth, API, Storage)
7. Draait alle SQL migrations uit `supabase/migrations/`
8. Configureert Nginx als reverse proxy met SSL (Let's Encrypt)
9. Maakt een `update.sh` script voor snelle updates

### Update-workflow (na wijzigingen in Lovable)

Lovable pusht automatisch naar GitHub. Op je VPS:

```bash
./update.sh
# Dit doet: git pull → rebuild frontend → restart → klaar
```

Of automatisch via een GitHub Actions webhook (optioneel).

### Bestanden die worden aangemaakt

| Bestand | Doel |
|---------|------|
| `install.sh` | Hoofdinstallatiescript — alles in één |
| `update.sh` | Update-script na Lovable wijzigingen |
| `docker-compose.yml` | Volledige stack: frontend + Supabase |
| `Dockerfile` | Frontend container (build + Nginx) |
| `nginx/nginx.conf` | Nginx reverse proxy config |
| `nginx/app.conf` | Site-specifieke Nginx config |
| `.env.production` | Alle environment variabelen (auto-gegenereerd) |
| `INSTALL.md` | Volledige handleiding als backup |

### Wat er in de handleiding (INSTALL.md) staat

- Vereisten (Ubuntu 24, minimaal 4GB RAM, domeinnaam)
- Stap-voor-stap uitleg van wat het script doet
- Hoe je data exporteert uit Lovable Cloud en importeert
- Hoe je gebruikers migreert (wachtwoord-reset flow)
- Hoe je OAuth providers (Google etc.) herconfigureert
- Troubleshooting sectie
- Hoe je automatische updates instelt via GitHub webhook

### Belangrijk

- **Supabase client code blijft ongewijzigd** — alleen de URL/keys wijzen naar je eigen server
- **Alle migraties werken automatisch** — het script draait ze in de juiste volgorde
- **SSL wordt automatisch ingesteld** via Let's Encrypt
- **Minimaal 4GB RAM nodig** voor de volledige Supabase stack
- **Updates zijn simpel** — `git pull` + rebuild, de Supabase database blijft intact

