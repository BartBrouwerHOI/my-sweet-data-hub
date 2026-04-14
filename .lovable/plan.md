

## Probleem

De `docker-compose.yml` laat alle services verbinden als DB-gebruiker `supabase`, maar:
- **GoTrue (auth)** heeft `supabase_auth_admin` nodig om het `auth` schema te beheren
- **Storage** heeft `supabase_storage_admin` nodig voor het `storage` schema
- **Realtime** heeft `supabase_admin` nodig

Omdat deze services crashen, starten kong en studio ook niet (dependency chain). Het script stopt dan vóór frontend-start en credentials-schrijven.

## Aanpak

### 1. `docker-compose.yml` — Correcte DB-gebruikers

**Auth service:**
```
GOTRUE_DB_DATABASE_URL: postgres://supabase_auth_admin:${POSTGRES_PASSWORD}@db:5432/postgres?sslmode=disable
```

**Storage service:**
```
DATABASE_URL: postgres://supabase_storage_admin:${POSTGRES_PASSWORD}@db:5432/postgres
```

**Realtime service:**
```
DB_USER: supabase_admin
DB_PASSWORD: ${POSTGRES_PASSWORD}
```

### 2. `00-supabase-init.sql` — supabase_admin LOGIN + wachtwoord

De `supabase_admin` rol heeft momenteel geen LOGIN en geen wachtwoord. Realtime moet er als kunnen inloggen:
```sql
CREATE ROLE supabase_admin LOGIN CREATEROLE CREATEDB PASSWORD 'CHANGEME';
```

### 3. `install.sh` — Script niet laten stoppen bij compose-fout

`docker compose up -d` kan falen als containers even nodig hebben. Voeg `|| true` toe en wacht op health in een loop, zodat het script niet voortijdig stopt.

### Bestanden

| Bestand | Wijziging |
|---|---|
| `docker-compose.yml` | Correcte DB users voor auth, storage, realtime |
| `volumes/db/init/00-supabase-init.sql` | `supabase_admin` LOGIN + wachtwoord |
| `install.sh` | `docker compose up -d` niet fataal laten falen |

