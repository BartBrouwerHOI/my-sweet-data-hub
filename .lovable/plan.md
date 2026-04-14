

## Plan: Handleiding 100% correct maken + beginner-friendly

### Gevonden bugs (kritiek)

**1. Verkeerde port mapping in install.sh**
`docker run ... -p 3000:80` maar de Dockerfile draait Node.js op poort 3000, niet 80. Moet `-p 3000:3000` zijn. Dit staat op twee plekken: `start_frontend()` (regel 262) en in `update.sh` (regel 447). De handleiding noemt ook `-p 3000:80` bij handmatige updates.

**2. Data migratie COPY-commando klopt niet**
De handleiding zegt `\COPY ... FROM '/tmp/tabel.csv'` via `docker exec`, maar `/tmp/tabel.csv` is een pad op de HOST, niet in de container. Moet eerst `docker cp` doen naar de container, of stdin gebruiken:
```
cat /tmp/tabel.csv | docker exec -i supabase-db psql -U supabase -d postgres -c "\COPY public.tabel FROM STDIN WITH CSV HEADER"
```

**3. Dubbele clone-stap**
De handleiding zegt "clone je repo" EN daarna `install.sh` dat opnieuw probeert te clonen via `clone_app()`. Verwarrend — de handleiding moet kloppen met wat het script doet.

**4. Backup directory bestaat niet**
Cron-job schrijft naar `/opt/backups/` maar die map wordt nergens aangemaakt.

### Verbeteringen voor leken

**5. "Waar doe je dit?" labels toevoegen**
Elke stap krijgt een duidelijke indicator:
- `📍 Terminal op je VM` — voor commandos
- `📍 GitHub.com` — voor deploy key toevoegen
- `📍 Je eigen computer` — voor browser/SSH verbinding

**6. Meer uitleg toevoegen**
- Wat is een terminal en hoe open je die (SSH uitleg)
- Wat betekent `JOUW-USER/JOUW-REPO` — expliciet uitleggen dat je je eigen GitHub naam invult
- Wat is een deploy key en waarom heb je die nodig
- Bij split setup: duidelijk aangeven welke Anon Key je moet bewaren en waar die terugkomt

**7. Stap volgorde verduidelijken**
- Clone-stap verwijderen uit handleiding (het script doet dit zelf)
- OF `clone_app()` uit install.sh verwijderen en handleiding de clone laten doen
- Ik kies: handleiding laat de user clonen, script detecteert bestaande dir en doet `git pull`

### Alle bestanden

| Bestand | Wijziging |
|---------|-----------|
| `install.sh` | Fix `-p 3000:80` → `-p 3000:3000` op 2 plekken. Backup dir aanmaken. |
| `src/routes/handleiding.tsx` | Locatie-labels per stap. COPY-commando fixen. Uitleg voor leken toevoegen. Handmatige update-commando port fixen. Backup mkdir toevoegen. |

### Wat al correct is (geverifieerd)
- Kong config + environment variable substitution: correct
- PostgREST `authenticator` role: standaard aanwezig in supabase/postgres image
- JWT generatie in bash: werkend (HS256 met openssl)
- Nginx routing via Kong poort 8000: correct
- Deploy keys: twee verschillende keys op twee servers, beide als deploy key op dezelfde repo — GitHub staat dit toe
- Docker Compose service dependencies + healthchecks: correct
- TanStack Start SSR Dockerfile met `.output/server/index.mjs`: correct

