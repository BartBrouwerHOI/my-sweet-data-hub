

## Probleem

Het init SQL script heeft twee fouten:

1. **`supabase_admin` creatie faalt** — `CREATE ROLE ... REPLICATION BYPASSRLS` vereist superuser-privileges. De `supabase` user heeft die niet wanneer je via TCP (`-h localhost`) verbindt. Oplossing: verwijder `REPLICATION BYPASSRLS` (niet nodig voor de applicatie).

2. **`authenticator` wachtwoord wordt niet gezet** — het script gebruikt `current_setting('password.superuser', true)` wat NULL retourneert. PostgREST verbindt als `authenticator` en kan dus niet inloggen. Oplossing: gebruik `POSTGRES_PASSWORD` als environment variabele via een shell-wrapper, of zet een fallback wachtwoord.

3. **`pgjwt` extension bestaat niet** in deze Postgres image — niet kritiek, kan overgeslagen worden met `IF NOT EXISTS` (faalt stil als het niet beschikbaar is).

## Oplossing: `volumes/db/init/00-supabase-init.sql` herschrijven

### Wijzigingen:

**a) `supabase_admin` — verwijder onmogelijke attributen:**
```sql
-- Was: CREATE ROLE supabase_admin LOGIN CREATEROLE CREATEDB REPLICATION BYPASSRLS;
-- Wordt:
CREATE ROLE supabase_admin LOGIN CREATEROLE CREATEDB;
```

**b) `authenticator` wachtwoord — gebruik hardcoded fallback + instructie:**
```sql
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'authenticator') THEN
    CREATE ROLE authenticator NOINHERIT LOGIN PASSWORD 'CHANGEME';
  END IF;
END $$;
```
Plus een apart `ALTER ROLE` statement dat het wachtwoord zet op basis van de `POSTGRES_PASSWORD` env var. Omdat SQL geen toegang heeft tot shell env vars, passen we `install.sh` aan om het wachtwoord via `sed` of een template in te vullen vóór het script gekopieerd wordt.

**c) `pgjwt` — maak niet-kritiek:**
Verwijder de `pgjwt` regel of wrap in een `DO $$ BEGIN ... EXCEPTION WHEN OTHERS THEN NULL; END $$;` blok.

**d) `supabase_auth_admin` — voeg LOGIN toe:**
GoTrue's migraties vereisen dat `supabase_auth_admin` kan inloggen:
```sql
CREATE ROLE supabase_auth_admin NOINHERIT LOGIN CREATEROLE;
```

### `install.sh` aanpassen:

Voeg een stap toe die `CHANGEME` vervangt door het werkelijke `POSTGRES_PASSWORD` in de gekopieerde init SQL:
```bash
sed -i "s/CHANGEME/$POSTGRES_PASSWORD/g" "$SUPABASE_DIR/volumes/db/init/00-supabase-init.sql"
```

En voeg een extra `ALTER ROLE authenticator PASSWORD` en `ALTER ROLE supabase_auth_admin PASSWORD` toe via `psql` na `docker compose up`.

## Directe fix voor de server

Na deze codewijzigingen, op de server:
```bash
# 1. Maak supabase_admin aan (zonder REPLICATION/BYPASSRLS)
sudo docker exec -i supabase-db bash -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -U supabase -d postgres -h localhost' <<'SQL'
CREATE ROLE supabase_admin LOGIN CREATEROLE CREATEDB;
ALTER ROLE authenticator WITH PASSWORD 'VULT_INSTALL_IN';
ALTER ROLE supabase_auth_admin WITH LOGIN PASSWORD 'VULT_INSTALL_IN';
SQL
```
(Vervang `VULT_INSTALL_IN` door het POSTGRES_PASSWORD uit `/opt/supabase/.env`)

```bash
# 2. Restart
cd /opt/supabase && sudo docker compose restart
```

## Handleiding bijwerken

Voeg aan de troubleshooting in `handleiding.tsx` toe:
- Tip over `supabase_admin` fout en hoe handmatig te fixen
- Waarschuwing dat wachtwoorden uit `.env` moeten komen

## Bestanden

| Bestand | Wijziging |
|---|---|
| `volumes/db/init/00-supabase-init.sql` | Fix supabase_admin attributen, authenticator wachtwoord, pgjwt error handling, supabase_auth_admin LOGIN |
| `install.sh` | `sed` stap om CHANGEME te vervangen door werkelijk wachtwoord, post-init password setup |
| `src/routes/handleiding.tsx` | Troubleshooting: supabase_admin fout, wachtwoord-tip |

