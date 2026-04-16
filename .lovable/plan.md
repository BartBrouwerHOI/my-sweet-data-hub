

## Wat klopt nog niet

- `install.sh` regel 437 kopieert `volumes/kong/kong.yml` letterlijk → placeholders `${SUPABASE_ANON_KEY}` en `${SUPABASE_SERVICE_KEY}` blijven staan.
- `update.sh` rendert Kong niet (0 hits op `kong`/`envsubst`).
- De gegenereerde `lovable-update`-templates in `install.sh` (regels ~1001–1208) doen het ook niet.
- Resultaat: een verse installatie via deze infra-handleiding loopt opnieuw tegen "Invalid authentication credentials" aan, totdat de app-repo bootstrap toevallig de Kong-config repareert.

## Plan: Kong-rendering in de infra zelf

### 1. `install.sh` — `render_kong_config()` toevoegen
- Nieuwe functie die `$SUPABASE_DIR/volumes/kong/kong.yml` overschrijft door `$INFRA_DIR/volumes/kong/kong.yml` te lezen en `${SUPABASE_ANON_KEY}` / `${SUPABASE_SERVICE_KEY}` te vervangen met `sed`, met waarden uit `$SUPABASE_DIR/.env` (fallback: in-memory `$ANON_KEY` / `$SERVICE_ROLE_KEY` die install.sh genereert).
- Aanroepen vlak na regel 437 (eerste install) zodat Kong meteen met echte keys start.

### 2. `update.sh` — zelfde rendering vóór elke restart
- Voeg `render_kong_config()` toe (gedeelde helper-stijl).
- Aanroepen in:
  - `database` mode vóór `docker compose up -d`
  - `full` mode vóór `docker compose up -d` (als die call ontbreekt: toevoegen na rendering)
- `frontend` / `--app-only` blijven ongewijzigd (raken Kong niet).

### 3. Gegenereerde updater-templates in `install.sh`
- Dezelfde rendering-snippet inbakken in de heredocs rond regels 1001, 1101 en 1179, zodat `lovable-update` na elke `git pull` van de infra-repo de Kong-config altijd opnieuw rendert.

### 4. Veiligheids-check (klein)
- Na render in `update.sh`: korte health-check  
  `curl -s -o /dev/null -w "%{http_code}" -H "apikey: $ANON_KEY" http://localhost:8000/auth/v1/health`  
  → bij ≠ 200 een waarschuwing tonen (niet falen).

### 5. Documentatie
- Korte regel toevoegen in `INSTALL.md` en `docs/PROJECT.md`: "Kong-config wordt op de server gerenderd uit `volumes/kong/kong.yml` met keys uit `/opt/supabase/.env`."
- Memory `mem://reference/project-context` updaten met deze beslissing.

### Bestanden

| Bestand | Wijziging |
|---------|-----------|
| `install.sh` | `render_kong_config()` toevoegen + aanroepen na regel 437; zelfde snippet in 3 updater-heredocs |
| `update.sh` | `render_kong_config()` toevoegen + aanroepen in `database` en `full` mode + health-check |
| `INSTALL.md` | Korte uitleg over Kong-rendering |
| `docs/PROJECT.md` | Idem |
| `mem://reference/project-context` | Beslissing vastleggen |

### Resultaat
Na deze wijziging is één commando (`install.sh` → bij update `lovable-update`) genoeg. De Access-Guardian `bootstrap.sh` blijft werken als extra vangnet maar is niet meer nodig om Kong werkend te krijgen.

