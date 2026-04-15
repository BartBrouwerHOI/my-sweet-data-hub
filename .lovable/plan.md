

## Fix: `.app_env` altijd poort 8000 meegeven bij IP-gebaseerde installatie

### Probleem
Bij installatie zonder domein wordt `APP_API_URL` opgeslagen als `http://IP` zonder `:8000`. De updater leest dit terug en overschrijft elke handmatige fix.

### Wijzigingen

**`install.sh` — `build_frontend()` (regel 554, 560)**

Waar de `api_url` wordt bepaald bij IP-gebaseerde installaties, `:8000` toevoegen:

- Regel 554: `api_url="http://$DB_SERVER_IP:8000"` → al correct (frontend-modus)
- Regel 560: `api_url="http://$(curl -s ifconfig.me)"` → wijzigen naar `api_url="http://$(curl -s ifconfig.me):8000"`

Zo wordt de `:8000` ook in `.app_env` opgeslagen en overleeft hij updates.

**`update.sh` — `write_env_production()` fallback (regel 90-91)**

Zelfde fix in de fallback: als er geen `.app_domain` is en de URL van `ifconfig.me` komt, `:8000` toevoegen:

- Regel 91: `api_url="http://$(curl -sf ifconfig.me 2>/dev/null || echo localhost)"` → wijzigen naar `api_url="http://$(curl -sf ifconfig.me 2>/dev/null || echo localhost):8000"`

**`install.sh` — gegenereerde updater-scripts (regels 996, 1082 (approx), 1147 (approx))**

Alle drie de plekken waar de gegenereerde `lovable-update` de fallback-URL bepaalt, `:8000` toevoegen aan de `ifconfig.me`-regel.

### Geen wijziging nodig als domein is geconfigureerd
Bij een domein met reverse proxy (Caddy/Nginx) proxyt poort 443 naar Kong 8000, dus daar is geen `:8000` nodig — die paden blijven ongewijzigd.

### Bestanden

| Bestand | Wijziging |
|---------|-----------|
| `install.sh` | `:8000` toevoegen bij IP-gebaseerde URL in `build_frontend()` + alle gegenereerde updater-templates |
| `update.sh` | `:8000` toevoegen bij IP-gebaseerde fallback in `write_env_production()` |

