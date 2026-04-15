

## Fix: Dubbele poort voorkomen + firewall regel voor full-modus

### Probleem
1. **Dubbele `:8000`**: Als `.app_env` al `:8000` bevat en de updater/installer opnieuw `:8000` toevoegt, krijg je `http://IP:8000:8000`.
2. **Firewall**: Poort 8000 wordt alleen geopend in `database`-modus, maar in `full`-modus zonder domein (IP-gebaseerd) moet de browser ook direct Kong bereiken op poort 8000.

### Wijzigingen

**`install.sh` — nieuwe helper `ensure_kong_port()`** (bij de andere helpers bovenin):
```bash
ensure_kong_port() {
  local url="$1"
  if [[ "$url" =~ ://[^/]*:[0-9]+ ]]; then
    echo "$url"
  else
    echo "${url%/}:8000"
  fi
}
```
Gebruik in `build_frontend()` regels 554 en 560:
- `api_url="$(ensure_kong_port "http://$DB_SERVER_IP")"`
- `api_url="$(ensure_kong_port "http://$(curl -s ifconfig.me)")"`

**`install.sh` — `configure_firewall()` (regel 832-852)**:
Poort 8000 ook openen in `full`-modus wanneer er geen domein is (IP-gebaseerde installatie). Wijzig de `if`-conditie van alleen `database` naar `database` OF (`full` zonder domein):
```bash
if [[ "$INSTALL_MODE" == "database" ]] || { [[ "$INSTALL_MODE" == "full" ]] && [[ -z "$DOMAIN" || "$IS_IP_ADDRESS" == true ]]; }; then
```

**`install.sh` — gegenereerde updater-templates (regels 996, 1083, 1149)**:
Inline poort-check toevoegen zodat dubbele `:8000` niet kan:
```bash
_api_url="http://$(curl -sf ifconfig.me 2>/dev/null || echo localhost)"
[[ ! "$_api_url" =~ :[0-9]+$ ]] && _api_url="${_api_url}:8000"
```

**`update.sh` — `write_env_production()` fallback (regel 85)**:
Zelfde inline check toevoegen:
```bash
api_url="http://$(curl -sf ifconfig.me 2>/dev/null || echo localhost)"
[[ ! "$api_url" =~ :[0-9]+$ ]] && api_url="${api_url}:8000"
```

### Bestanden

| Bestand | Wijziging |
|---------|-----------|
| `install.sh` | `ensure_kong_port()` helper + gebruik in `build_frontend()` + poort 8000 firewall in full-modus zonder domein + inline check in gegenereerde updater-templates |
| `update.sh` | Inline poort-check in `write_env_production()` fallback |

