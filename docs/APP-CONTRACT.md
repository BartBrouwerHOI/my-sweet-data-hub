# Contract: Lovable App-repo ↔ Infra-repo

> **Voor wie?** Developers van een Lovable-app die gedeployed wordt op een VPS via [`my-sweet-data-hub`](https://github.com/BartBrouwerHOI/my-sweet-data-hub) (de infra-repo).
>
> **Doel:** afspraken zodat élke Lovable-app probleemloos op deze infra draait — zonder dat de infra-repo aangepast hoeft te worden voor app-specifieke kwesties.

---

## 1. Verantwoordelijkheidsverdeling

### Wat de infra-repo (`my-sweet-data-hub`) regelt

De infra is **100% generiek**. Hij weet niets van jouw app-specifieke tabellen, edge functions of business-logica.

- **Server provisioning** — Docker, Nginx, SSL (Let's Encrypt), firewall (ufw/firewalld)
- **Supabase stack** — PostgreSQL, GoTrue (auth), PostgREST, Kong (API gateway), Storage, Realtime, Studio
- **Frontend hosting** — autodetect SPA (Vite + React → Nginx) of SSR (TanStack Start → Node), bouwt en runt in Docker
- **Reverse proxy** — host-Nginx routeert `/auth/v1/`, `/rest/v1/`, `/storage/v1/`, `/realtime/v1/`, `/functions/v1/` naar Kong; rest naar frontend (same-origin, geen `:8000`)
- **Secrets generatie** — JWT secret, anon key, service-role key, DB-wachtwoord (eenmalig, opgeslagen in `/opt/supabase/.env` + `credentials.txt`)
- **Migratie-runner** — draait `supabase/migrations/*.sql` in alfabetische volgorde, tracking via `/opt/supabase/.migrations_done/`, stopt bij eerste fout
- **Updates** — `lovable-update` commando: pull infra + app, rebuild frontend, run nieuwe migraties, roept `scripts/lovable-update.sh` van app aan
- **App-script hooks** — roept automatisch `$APP_DIR/scripts/bootstrap.sh` (eenmalig) en `$APP_DIR/scripts/lovable-update.sh` (recurring) aan als die bestaan

### Wat jouw app-repo zelf moet regelen

Alles wat **specifiek** is voor jouw app:

1. Idempotente, defensieve database-migraties
2. Edge function deployment (via `scripts/bootstrap.sh` + `scripts/lovable-update.sh`)
3. App-specifieke secrets (Stripe keys, OpenAI keys, etc.)
4. Eerste-admin/seed-data flow die werkt op een **lege** database
5. Geen hardcoded URLs naar `*.lovable.app` of `*.supabase.co`

---

## 2. Database-migraties: do's & don'ts

De infra-runner draait elke `.sql` in `supabase/migrations/` één keer, in alfabetische volgorde, en **stopt bij de eerste fout**. Een verse install heeft een lege database — geen users, geen profiles, geen seed-data.

### ❌ Don't: hardcoded user_ids

Migraties uit Lovable Cloud bevatten vaak hardcoded user-IDs van de cloud-omgeving. Op een verse self-hosted DB bestaan die users niet → foreign key violation → installatie faalt.

```sql
-- ❌ FOUT: deze user bestaat niet op een verse DB
INSERT INTO user_roles (user_id, role)
VALUES ('fa761b51-9489-4289-917b-d1818f3cd508', 'admin');
```

### ✅ Do: defensief inserten

```sql
-- ✅ GOED: alleen inserten als de user bestaat
INSERT INTO user_roles (user_id, role)
SELECT 'fa761b51-9489-4289-917b-d1818f3cd508', 'admin'
WHERE EXISTS (
  SELECT 1 FROM auth.users WHERE id = 'fa761b51-9489-4289-917b-d1818f3cd508'
)
ON CONFLICT (user_id, role) DO NOTHING;
```

### ✅ Beter: eerste-admin via trigger

Hardcode geen user-IDs. Maak de eerste user automatisch admin via een trigger:

```sql
CREATE OR REPLACE FUNCTION public.handle_first_user()
RETURNS TRIGGER AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.user_roles WHERE role = 'admin') THEN
    INSERT INTO public.user_roles (user_id, role)
    VALUES (NEW.id, 'admin');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER on_auth_user_created_first_admin
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_first_user();
```

### Algemene regels

| Pattern | Gebruik |
|---|---|
| `CREATE TABLE IF NOT EXISTS` | Altijd |
| `CREATE INDEX IF NOT EXISTS` | Altijd |
| `DROP POLICY IF EXISTS` vóór `CREATE POLICY` | Altijd (RLS-policies zijn niet idempotent) |
| `ON CONFLICT DO NOTHING` / `DO UPDATE` | Bij elke `INSERT` |
| `CREATE OR REPLACE FUNCTION` | Voor functions/triggers |
| FK-violations bij seed-data | Voorkom met `WHERE EXISTS (...)` |
| Seed-data | Alleen als tabel leeg is (`WHERE NOT EXISTS (SELECT 1 FROM ...)`) |

### RLS & user_roles

Volg het Lovable-pattern: aparte `user_roles` tabel + `has_role()` security-definer function. Sla **nooit** rollen op in de `profiles` of `users` tabel — dat opent privilege-escalation.

---

## 3. Scripts-conventie (`scripts/` in jouw app-repo)

De infra detecteert deze twee bestanden automatisch en draait ze met `sudo`:

### `scripts/bootstrap.sh` — eenmalig, na eerste install

Voor zaken die maar één keer hoeven:
- Edge runtime container starten (Deno/Supabase Edge Functions)
- Kong-routes voor `/functions/v1/*` toevoegen
- App-secrets aanmaken (vraag interactief of lees uit env)
- Cronjobs registreren

### `scripts/lovable-update.sh` — bij elke `lovable-update`

Voor zaken die telkens moeten syncen:
- Edge function code kopiëren naar runtime container
- Edge runtime herstarten
- App-cache flushen

### Voorbeeld-skelet

```bash
#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/lovable-app}"
SUPABASE_DIR="${SUPABASE_DIR:-/opt/supabase}"

# Lees infra-secrets indien nodig
source "$SUPABASE_DIR/.env"

# ... jouw app-specifieke logica ...
```

**Belangrijk:** maak ze idempotent. `bootstrap.sh` kan opnieuw gedraaid worden zonder schade.

---

## 4. Frontend: environment variabelen

De infra zet automatisch `.env.production` met:

```
VITE_SUPABASE_URL=http://<DOMAIN_OR_IP>     # same-origin, GEEN :8000
VITE_SUPABASE_ANON_KEY=<gegenereerde anon key>
VITE_SUPABASE_PROJECT_ID=<willekeurige id>
```

### ❌ Don't

```ts
const supabase = createClient(
  "https://abcd1234.supabase.co",        // ❌ hardcoded cloud-URL
  "eyJhbG..."                            // ❌ hardcoded key
);
```

### ✅ Do

```ts
const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY
);
```

---

## 5. Checklist vóór deployment

- [ ] Alle migraties draaien op een **lege** Postgres zonder fouten
- [ ] Geen hardcoded user-IDs in seed-migraties
- [ ] Eerste-admin via trigger (of handmatig via Studio na install)
- [ ] Geen hardcoded `*.lovable.app` of `*.supabase.co` URLs in code
- [ ] Edge functions hebben een `scripts/bootstrap.sh` + `scripts/lovable-update.sh`
- [ ] App-secrets staan **niet** in de repo (`.env*` in `.gitignore`)
- [ ] RLS aan op alle tabellen met user-data
- [ ] `user_roles` in aparte tabel, met `has_role()` security-definer

---

## 6. Wat te doen bij een mislukte migratie?

De infra meldt: `⚠️ INSTALLATIE DEELS VOLTOOID`. De stack draait, maar één migratie faalde.

**Opties:**

1. **Fix in app-repo** (aanbevolen): pas migratie aan volgens de patterns hierboven, push, draai op server: `sudo lovable-update`
2. **Skip op de server** (snel, eenmalig):
   ```bash
   sudo lovable-update --mark-done <migratiebestand.sql>
   sudo lovable-update
   ```
3. **Volledige reset** (alle data weg):
   ```bash
   cd /opt/supabase && sudo docker compose down -v
   sudo rm -rf /opt/supabase/volumes/db/data /opt/supabase/.migrations_done
   sudo bash /opt/lovable-infra/install.sh
   ```

---

## 7. Vragen?

Zie de [interactieve handleiding](https://github.com/BartBrouwerHOI/my-sweet-data-hub) of de troubleshooting-sectie daarin.
