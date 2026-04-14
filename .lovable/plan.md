

## Probleem 1: SSH deploy key niet beschikbaar voor root

Het script draait als `sudo` maar de deploy key staat in `/home/bartbrouwer/.ssh/`. Het script moet automatisch de key kopiëren naar `/root/.ssh/` als het via sudo draait.

## Probleem 2: supabase-db unhealthy

De meest waarschijnlijke oorzaak: de migratie-bestanden uit `supabase/migrations/` worden naar `volumes/db/init/` gekopieerd en draaien als init-scripts. Als die migraties refereren aan tabellen/schema's die GoTrue nog niet heeft aangemaakt (zoals `auth.users`), faalt de database-initialisatie en wordt de container unhealthy.

Init-scripts in `/docker-entrypoint-initdb.d/` draaien alfabetisch. De migraties (met timestamps als `20240101...`) komen NA `00-supabase-init.sql`, maar GoTrue migraties draaien pas als de auth-container start — dus auth-afhankelijke migraties falen.

## Aanpak

### 1. `install.sh` — Auto-copy SSH key bij sudo (regel ~273)

Vóór de SSH-test, detecteer de oorspronkelijke gebruiker via `$SUDO_USER` en kopieer automatisch de deploy key + config naar `/root/.ssh/`:

```bash
# Als we via sudo draaien, kopieer SSH keys van de oorspronkelijke gebruiker
if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
  local user_home
  user_home=$(eval echo "~$SUDO_USER")
  if [[ -d "$user_home/.ssh" ]]; then
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    for f in deploy_key deploy_key.pub config id_ed25519 id_ed25519.pub id_rsa id_rsa.pub; do
      if [[ -f "$user_home/.ssh/$f" && ! -f "/root/.ssh/$f" ]]; then
        cp "$user_home/.ssh/$f" "/root/.ssh/$f"
      fi
    done
    chmod 600 /root/.ssh/deploy_key 2>/dev/null || true
    chmod 600 /root/.ssh/id_ed25519 2>/dev/null || true
    chmod 600 /root/.ssh/id_rsa 2>/dev/null || true
    log_info "SSH keys gekopieerd van $SUDO_USER naar root"
  fi
fi
```

### 2. `install.sh` — Migraties NIET naar init-dir kopiëren

De huidige regel ~387-392 kopieert migraties naar `volumes/db/init/`. Dit moet veranderen: migraties moeten NA het opstarten via `docker exec` worden uitgevoerd, niet als init-scripts.

**Was (regel 387-392):**
```bash
if [[ -d "$APP_DIR/supabase/migrations" ]]; then
    log_info "Database migraties kopiëren vanuit app-repo..."
    cp "$APP_DIR/supabase/migrations/"*.sql "$SUPABASE_DIR/volumes/db/init/" 2>/dev/null || true
```

**Wordt:**
Verwijder het kopiëren naar init-dir. Voeg in plaats daarvan een `run_migrations()` functie toe die na `start_supabase()` draait:

```bash
run_migrations() {
  if [[ ! -d "$APP_DIR/supabase/migrations" ]]; then return; fi
  log_info "Database migraties uitvoeren..."
  mkdir -p "$SUPABASE_DIR/.migrations_done"
  for migration in "$APP_DIR/supabase/migrations/"*.sql; do
    [[ -f "$migration" ]] || continue
    local name="$(basename "$migration")"
    if [[ ! -f "$SUPABASE_DIR/.migrations_done/$name" ]]; then
      log_info "  Migratie: $name"
      if docker exec -i supabase-db bash -c \
        'PGPASSWORD=$POSTGRES_PASSWORD psql -U supabase -d postgres -h localhost --single-transaction' \
        < "$migration"; then
        touch "$SUPABASE_DIR/.migrations_done/$name"
        echo "    ✅ Succesvol"
      else
        echo "    ❌ Mislukt"
      fi
    fi
  done
}
```

### 3. `install.sh` — Orchestratie aanpassen

In de `main()` functie, na `start_supabase` een pauze + `run_migrations` toevoegen zodat GoTrue eerst zijn eigen schema's kan aanmaken.

### Bestanden

| Bestand | Wijziging |
|---|---|
| `install.sh` | SSH auto-copy, migraties niet naar init-dir, run_migrations na start |

