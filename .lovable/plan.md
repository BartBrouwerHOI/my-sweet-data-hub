

## Diagnose

Het werkende `lovable-update.sh` van Access-Guardian doet 3 dingen die mijn `install.sh` mist:

| | Mijn install.sh (nu) | Werkende script |
|---|---|---|
| `VITE_SUPABASE_URL` | `http://IP:8000` (direct naar Kong) | `http://IP` (same-origin via Nginx) |
| Variabele-naam | `VITE_SUPABASE_ANON_KEY` + `VITE_SUPABASE_PUBLISHABLE_KEY` | `VITE_SUPABASE_PUBLISHABLE_KEY` (de app verwacht deze) |
| Reverse proxy | Geen — frontend draait standalone in Docker op :3000, host-Nginx alleen op :80 voor SPA | Host-Nginx proxyt `/auth/v1/`, `/rest/v1/`, `/storage/v1/`, `/realtime/v1/`, `/functions/v1/` → Kong `127.0.0.1:8000` |

Waarom dit faalt: browser doet `POST http://IP/auth/v1/signup`. Bij mij komt die call bij de frontend-Nginx terecht (geen `/auth/v1/`-locatie) → die serveert `index.html` → JSON-parse error in de browser.

## Plan

### 1. `install.sh` — host-Nginx wordt full reverse-proxy
- Vervang de huidige host-Nginx config (die alleen SPA serveert) door een config met:
  - `location /auth/v1/`, `/rest/v1/`, `/storage/v1/`, `/realtime/v1/` (websocket), `/functions/v1/` → `proxy_pass http://127.0.0.1:8000/...` (Kong)
  - `location /` → `proxy_pass http://127.0.0.1:3000/` (frontend container) **of** direct `try_files` als we ook de SPA via host-Nginx serveren
- Beslissing: SPA blijft in zijn eigen Docker-container op `:3000`, host-Nginx proxyt alles (auth/rest/etc → Kong, rest → frontend). Dat is consistent met de huidige Docker-aanpak en vermijdt dat we de `dist` map naar de host moeten kopiëren.

### 2. `install.sh` — `.env.production` aanpassen
- `VITE_SUPABASE_URL=http://<DOMAIN_OR_IP>` (zonder `:8000`, want same-origin via Nginx).
- Schrijf alleen `VITE_SUPABASE_PUBLISHABLE_KEY` (niet meer `VITE_SUPABASE_ANON_KEY`).
- `update.sh` `write_env_production()` idem aanpassen.
- Gegenereerde `lovable-update`-heredocs in `install.sh` idem.

### 3. `update.sh` — Nginx-config ook bij update herschrijven
- Bij `full` en `frontend` mode: render dezelfde host-Nginx config (zodat updates aan de proxy-rules meekomen).

### 4. Documentatie
- `INSTALL.md` + `docs/PROJECT.md`: korte regel "Host-Nginx proxyt API-routes (/auth, /rest, /storage, /realtime, /functions) naar Kong; VITE_SUPABASE_URL is same-origin zonder poort."
- `mem://reference/project-context` updaten.

### Bestanden

| Bestand | Wijziging |
|---|---|
| `install.sh` | Nieuwe host-Nginx template (proxy + SPA), `.env.production` zonder `:8000` en alleen `PUBLISHABLE_KEY`, zelfde snippets in 3 lovable-update-heredocs |
| `update.sh` | `write_env_production()` zonder `:8000` en alleen `PUBLISHABLE_KEY`; nieuwe `write_host_nginx()` aangeroepen in full/frontend mode |
| `nginx/frontend-spa.conf` | Vervangen of nieuwe `nginx/host-proxy.conf` met de proxy-config |
| `INSTALL.md` + `docs/PROJECT.md` | Korte uitleg |

### Resultaat
Na een verse `install.sh` werkt signup direct, zonder dat de Access-Guardian `lovable-update.sh` nog hoeft te draaien. De browser doet `POST http://IP/auth/v1/signup` → host-Nginx → Kong → GoTrue → JSON terug.

