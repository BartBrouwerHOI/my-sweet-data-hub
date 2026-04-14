

## Root Cause Analyse

Er zijn **drie fundamentele problemen** waardoor de DB unhealthy blijft:

### 1. `POSTGRES_USER: supabase` is verkeerd
De officiële Supabase postgres image is gebouwd met `postgres` als superuser. De image heeft ingebouwde init-scripts die `postgres` als eigenaar verwachten. Door `POSTGRES_USER: supabase` te zetten probeer je een andere gebruiker als superuser te gebruiken — dit conflicteert met de ingebouwde scripts in de image die `postgres` verwachten.

De officiële `.env.example` heeft helemaal geen `POSTGRES_USER` — het gebruikt gewoon de standaard `postgres` user.

### 2. Ontbrekende init-scripts: `roles.sql` en `jwt.sql`
De officiële Supabase docker-compose mount **specifieke SQL-bestanden** die wachtwoorden configureren:
- `roles.sql` — zet het `POSTGRES_PASSWORD` op de service-rollen (`authenticator`, `supabase_auth_admin`, `supabase_storage_admin`)
- `jwt.sql` — configureert `app.settings.jwt_secret` op database-niveau (PostgREST heeft dit nodig)

Zonder `roles.sql` kennen de service-rollen geen wachtwoord → GoTrue, Storage, PostgREST kunnen niet inloggen → ze crashen → Kong start niet → Studio start niet.

### 3. Ons custom `00-supabase-init.sql` overschrijft de hele init-dir
We mounten `./volumes/db/init:/docker-entrypoint-initdb.d` — dit **vervangt de hele init-directory** van de image. De ingebouwde init-scripts van de image worden niet meer gevonden. Onze `00-supabase-init.sql` is een gebrekkige copy van wat de image zelf al doet, maar mist cruciale stukken.

### 4. Healthcheck gebruiker klopt niet
De officiële healthcheck gebruikt `pg_isready -U postgres`, niet `-U supabase`. 

## Plan

### 1. `docker-compose.yml` — Afstemmen op officiële Supabase config

**db service:**
- Verwijder `POSTGRES_USER: supabase` (gebruik standaard `postgres`)
- Verwijder de brede `./volumes/db/init:/docker-entrypoint-initdb.d` mount
- Mount in plaats daarvan specifieke bestanden zoals de officiële compose doet:
  - `./volumes/db/roles.sql:/docker-entrypoint-initdb.d/init-scripts/99-roles.sql`
  - `./volumes/db/jwt.sql:/docker-entrypoint-initdb.d/init-scripts/99-jwt.sql`
- Healthcheck: `pg_isready -U postgres -h localhost`
- Retries: 10 (was 5)
- Voeg `JWT_SECRET` en `JWT_EXP` toe als environment variables (nodig voor jwt.sql)

**rest service:**
- Verander `PGRST_DB_URI` user van `authenticator` (klopt al)

**meta service:**
- Verander `PG_META_DB_USER` van `supabase` naar `supabase_admin` (of `postgres`)

### 2. Nieuwe bestanden: `volumes/db/roles.sql` en `volumes/db/jwt.sql`

**`roles.sql`** (exact zoals officieel):
```sql
\set pgpass `echo "$POSTGRES_PASSWORD"`
ALTER USER authenticator WITH PASSWORD :'pgpass';
ALTER USER supabase_auth_admin WITH PASSWORD :'pgpass';
ALTER USER supabase_storage_admin WITH PASSWORD :'pgpass';
```

**`jwt.sql`** (exact zoals officieel):
```sql
\set jwt_secret `echo "$JWT_SECRET"`
\set jwt_exp `echo "$JWT_EXP"`
ALTER DATABASE postgres SET "app.settings.jwt_secret" TO :'jwt_secret';
ALTER DATABASE postgres SET "app.settings.jwt_exp" TO :'jwt_exp';
```

### 3. `install.sh` — Aanpassen

- Stop met kopiëren en bewerken van `00-supabase-init.sql`
- Kopieer in plaats daarvan `roles.sql` en `jwt.sql` naar de Supabase dir
- Voeg `JWT_EXP=3600` toe aan de `.env` file
- Pas de `wait_for_bootstrap()` aan om `postgres` user te gebruiken i.p.v. `supabase`

### 4. `update.sh` — Aanpassen

- Verwijder referenties naar `00-supabase-init.sql`

### 5. `00-supabase-init.sql` — Kan weg

Dit bestand is niet meer nodig. De image regelt alles zelf; `roles.sql` en `jwt.sql` vullen de wachtwoorden aan.

## Bestanden

| Bestand | Wijziging |
|---|---|
| `docker-compose.yml` | Correcte user, healthcheck, specifieke volume mounts, JWT env vars |
| `volumes/db/roles.sql` | Nieuw — wachtwoorden voor service-rollen |
| `volumes/db/jwt.sql` | Nieuw — JWT configuratie op DB-niveau |
| `install.sh` | Stop met init-sql bewerking, kopieer roles.sql + jwt.sql |
| `update.sh` | Verwijder init-sql referenties |
| `volumes/db/init/00-supabase-init.sql` | Verwijderen (niet meer nodig) |

## Verwacht resultaat

Na reset (`docker compose down -v && rm -rf volumes/db/data`) en herinstallatie:
- De image draait zijn eigen ingebouwde init-scripts (rollen, schema's, extensions)
- `roles.sql` zet de juiste wachtwoorden op alle service-rollen
- `jwt.sql` configureert JWT op database-niveau
- DB wordt healthy, alle services starten correct
- GoTrue maakt het `auth` schema klaar, waarna migraties succesvol kunnen draaien

