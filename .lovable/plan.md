

## Probleem

De database draait, maar mist alle Supabase-specifieke rollen (`anon`, `authenticated`, `authenticator`, `service_role`) en schema's (`auth`, `storage`, `realtime`). Dit komt door twee oorzaken:

1. **`install.sh` maakt `volumes/db/data` aan vóór de container start** (regel 371). PostgreSQL ziet een niet-lege data directory en slaat alle init scripts over — inclusief de ingebouwde Supabase init scripts uit de image.

2. **Geen init SQL voor Supabase rollen/schema's** in de infra-repo. De `supabase/postgres` image heeft ingebouwde scripts, maar die draaien alleen als de data directory leeg is bij eerste start.

3. **`realtime` mist `APP_NAME`** environment variabele.

## Oplossing

### 1. Nieuw bestand: `volumes/db/init/00-supabase-init.sql`

SQL script dat de essentiële Supabase rollen, schema's, extensions en grants aanmaakt (idempotent met `IF NOT EXISTS`):

- **Rollen:** `anon`, `authenticated`, `authenticator`, `service_role`, `supabase_admin`, `dashboard_user`, `supabase_auth_admin`, `supabase_storage_admin`, `supabase_realtime_admin`
- **Schema's:** `auth`, `storage`, `extensions`, `realtime`, `_realtime`  
- **Extensions:** `uuid-ossp`, `pgcrypto`, `pgjwt` (in `extensions` schema)
- **Grants:** juiste schema-eigenaarschap en search_path per rol

### 2. `install.sh` aanpassen

- **Verwijder `mkdir -p volumes/db/data`** (regel 371) — laat Docker/PostgreSQL de data directory zelf aanmaken bij eerste start
- **Kopieer init SQL** naar `$SUPABASE_DIR/volumes/db/init/` vóór `docker compose up`

### 3. `docker-compose.yml` aanpassen

- Voeg `APP_NAME: supabase_realtime` toe aan de `realtime` service environment

### 4. Handleiding: troubleshooting sectie

Voeg een "Database resetten" stap toe aan de troubleshooting sectie in `handleiding.tsx`:

```bash
cd /opt/supabase && sudo docker compose down
sudo rm -rf /opt/supabase/volumes/db/data
sudo docker compose up -d
```

## Jouw server nu fixen

Na deze wijzigingen voer je op je server uit:

```bash
cd /opt/supabase && sudo docker compose down
sudo rm -rf /opt/supabase/volumes/db/data
cd /opt/lovable-infra && sudo git pull
sudo cp /opt/lovable-infra/docker-compose.yml /opt/supabase/docker-compose.yml
sudo cp /opt/lovable-infra/volumes/db/init/00-supabase-init.sql /opt/supabase/volumes/db/init/
sudo cp /opt/lovable-infra/volumes/kong/kong.yml /opt/supabase/volumes/kong/kong.yml
cd /opt/supabase && sudo docker compose up -d
```

## Bestanden

| Bestand | Wijziging |
|---|---|
| `volumes/db/init/00-supabase-init.sql` | **Nieuw** — rollen, schema's, extensions, grants |
| `docker-compose.yml` | `APP_NAME` toevoegen aan realtime |
| `install.sh` | Verwijder premature `mkdir volumes/db/data`, kopieer init SQL |
| `src/routes/handleiding.tsx` | Troubleshooting: database resetten |

