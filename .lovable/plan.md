

## Probleem

`update.sh` kopieert het init SQL niet en vervangt `CHANGEME` niet door het werkelijke wachtwoord. Alleen `install.sh` doet dat. Als de gebruiker via `git pull` + `docker compose` update (of `update.sh` gebruikt), blijven de passwords op `CHANGEME` staan.

## Oplossing

### 1. `update.sh` — sed stap toevoegen

In alle drie de modi (database, frontend, full), na `git pull` van de infra-repo, het init SQL kopiëren en `CHANGEME` vervangen:

```bash
# Na git pull van infra-repo
if [[ -f "$INFRA_DIR/volumes/db/init/00-supabase-init.sql" ]] && [[ -d "$SUPABASE_DIR" ]]; then
  source "$SUPABASE_DIR/.env"
  cp "$INFRA_DIR/volumes/db/init/00-supabase-init.sql" "$SUPABASE_DIR/volumes/db/init/00-supabase-init.sql"
  sed -i "s/CHANGEME/$POSTGRES_PASSWORD/g" "$SUPABASE_DIR/volumes/db/init/00-supabase-init.sql"
fi
```

Voeg dit toe in de `database` sectie (na regel 60-61) en de `full` sectie (na regel 146).

### 2. `update.sh` — psql met `-h localhost`

De bestaande migratie-commando's (regels 78 en 177) gebruiken `psql -U supabase` zonder `-h localhost`, wat peer auth failures geeft. Fix:

```bash
# Was:
docker exec -i supabase-db psql -U supabase -d postgres --single-transaction < "$migration"
# Wordt:
docker exec -i supabase-db bash -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -U supabase -d postgres -h localhost --single-transaction' < "$migration"
```

### Bestanden

| Bestand | Wijziging |
|---|---|
| `update.sh` | Init SQL kopiëren+sed in database en full mode; psql `-h localhost` fix |

