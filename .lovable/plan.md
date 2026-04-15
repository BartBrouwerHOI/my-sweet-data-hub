

## Diagnose & Fix: 3 problemen gevonden

Uit de output blijkt:

### Probleem 1: Kong weigert de anon key ("Invalid authentication credentials")
GoTrue is gezond (200 OK), maar Kong weigert het request. Dit betekent dat de `ANON_KEY` waarmee de frontend is gebouwd **niet overeenkomt** met de key die Kong verwacht. De `.app_env` is onleesbaar (permission denied), dus `write_env_production()` valt terug op de fallback — maar de key uit `/opt/supabase/.env` zou wél kloppen. Vermoedelijk is `.app_env` ooit geschreven met een andere key, en de updater gebruikt die (met `source`) zonder te controleren of hij nog klopt.

### Probleem 2: `.app_domain` bevat een IP-adres
`.app_domain` bevat `192.168.200.185`. De updater-logica leest dit en maakt er `https://192.168.200.185` van (HTTPS op een kaal IP — werkt niet). Dit bestand hoort alleen een echt domein te bevatten, of niet te bestaan bij IP-installaties.

### Probleem 3: Realtime crasht (`_realtime` schema ontbreekt)
De `DB_AFTER_CONNECT_QUERY` is `SET search_path TO _realtime`, maar dat schema bestaat niet in de database. Dit moet aangemaakt worden via een init-script.

---

### Wijzigingen

**1. `update.sh` — `write_env_production()` robuuster maken**

Nieuwe logica:
- Altijd `ANON_KEY` uit `/opt/supabase/.env` als primaire bron (als die bestaat)
- `.app_env` alleen als fallback, en alleen als keys overeenkomen
- `.app_domain` alleen gebruiken als het GEEN IP-adres is
- Als `.app_env` afwijkt van de werkelijke waarden: automatisch bijwerken

**2. `install.sh` — `.app_domain` NIET schrijven bij IP-adressen**

Regel 590-592: alleen schrijven als `$DOMAIN` geen IP is. Toevoegen:
```bash
if [[ -n "$DOMAIN" && ! "$DOMAIN" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
```

Dezelfde check in alle gegenereerde updater-templates.

**3. `volumes/db/roles.sql` — `_realtime` schema aanmaken**

Toevoegen:
```sql
CREATE SCHEMA IF NOT EXISTS _realtime;
GRANT ALL ON SCHEMA _realtime TO supabase_admin;
```

**4. Directe fix-instructies voor de server**

Na de code-wijzigingen geef ik je commando's om:
- `.app_domain` te verwijderen (bevat IP, niet nodig)
- `.app_env` permissions te fixen
- `_realtime` schema handmatig aan te maken in de draaiende database
- Realtime container te herstarten
- Frontend te rebuilden met correcte key

### Bestanden

| Bestand | Wijziging |
|---------|-----------|
| `update.sh` | Key-validatie + `.app_domain` IP-check + auto-sync `.app_env` |
| `install.sh` | `.app_domain` niet schrijven bij IP + zelfde logica in updater-templates |
| `volumes/db/roles.sql` | `_realtime` schema aanmaken |

