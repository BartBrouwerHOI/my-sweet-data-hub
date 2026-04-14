
## Wat er nu echt misgaat

De belangrijkste fout zit niet meer in de compose-credentials, maar in de **migratie-flow**:

1. `install.sh` draait app-migraties terwijl de Supabase bootstrap nog niet aantoonbaar klaar is.
2. De migraties worden **ten onrechte als succesvol gemarkeerd**:
   - `psql` draait zonder `ON_ERROR_STOP=1`
   - daarna wordt toch `.migrations_done/<bestand>` aangemaakt
   - daardoor krijg je tientallen `ERROR:` regels, maar toch `✅ Succesvol`
3. Bij een herstart op een eerder mislukte installatie blijft `/opt/supabase/volumes/db/data` bestaan, waardoor init-scripts niet opnieuw draaien en je op een half-lege DB blijft doorbouwen.

De log bevestigt dat precies:
- eerst faalt `schema "auth" does not exist`
- daarna faalt alles wat daarvan afhankelijk is
- toch markeert het script elke migratie als klaar

## Plan

### 1. `install.sh` — migraties strikt en betrouwbaar maken
Ik pas `run_migrations()` aan zodat het:
- **wacht op echte readiness**, niet alleen `sleep 10`
- vóór migraties controleert of cruciale objecten bestaan:
  - schema's: `auth`, `storage`
  - rollen: `anon`, `authenticated`, `service_role`, `supabase_admin`
- migraties uitvoert met strikte foutafhandeling:
  - `psql -v ON_ERROR_STOP=1 -X --single-transaction`
- **alleen** `.migrations_done/<bestand>` schrijft als de migratie echt zonder SQL-fouten klaar is
- stopt op de **eerste mislukte migratie** met een duidelijke foutmelding en bestandsnaam

### 2. `install.sh` — betere startup-checks voor Supabase
Ik maak `start_supabase()` robuuster:
- niet alleen wachten op `pg_isready`
- ook controleren of de bootstrap-objecten in Postgres echt aanwezig zijn
- pas daarna app-migraties starten
- als bootstrap niet compleet is binnen timeout: installer netjes afbreken met duidelijke uitleg i.p.v. doorrennen

### 3. `install.sh` — herstelpad voor mislukte eerdere installaties
Ik voeg logica toe voor het veelvoorkomende scenario “opnieuw draaien na half-mislukte eerste run”:
- detecteer bestaande `volumes/db/data`
- leg uit dat init-scripts dan niet opnieuw draaien
- bied een duidelijke reset-flow voor full/database mode
- voorkom dat een oude kapotte DB stilzwijgend opnieuw gebruikt wordt

### 4. `update.sh` en gegenereerde `lovable-update` — dezelfde bug ook daar oplossen
Deze paden hebben nu nog dezelfde zwakke plekken:
- ze kopiëren migraties nog naar `volumes/db/init/`
- ze draaien `psql` nog zonder strikte foutafhandeling

Ik trek dit gelijk:
- geen app-migraties meer kopiëren naar `docker-entrypoint-initdb.d`
- dezelfde strikte migratie-uitvoering als in `install.sh`
- dezelfde `.migrations_done`-regels
- dezelfde stop-op-eerste-fout aanpak

### 5. Optioneel: korte troubleshooting-aanvulling in docs/handleiding
Ik voeg desnoods een korte waarschuwing toe in de handleiding/documentatie:
- “Bij een mislukte eerste database-initialisatie moet je de DB-data resetten voordat init-wijzigingen effect hebben.”

## Bestanden

| Bestand | Wijziging |
|---|---|
| `install.sh` | readiness-checks, strikte migratie-runner, correcte `.migrations_done`, recovery bij oude DB-data |
| `update.sh` | zelfde strikte migratie-aanpak, geen copy naar init-dir |
| `install.sh` gegenereerde `lovable-update` | zelfde fixes als `update.sh` |
| eventueel `src/routes/handleiding.tsx` of `docs/PROJECT.md` | korte troubleshooting-notitie |

## Technische details

- Ik gebruik een DB-self-check vóór migraties, bijvoorbeeld via queries op:
  - `to_regnamespace('auth')`
  - `to_regnamespace('storage')`
  - `pg_roles`
- `psql` wordt strikt, zodat SQL-errors echt non-zero exit codes geven
- succesvolle migraties worden pas daarna gemarkeerd
- bij een fout zie je nog maar **één echte blocker**, in plaats van honderden afgeleide errors

## Verwacht resultaat

Na deze wijziging krijg je:
- geen “fake success” meer bij mislukte migraties
- geen doorlopende cascade van irrelevante fouten
- een installer die ofwel correct doorloopt, of exact zegt **welke eerste voorwaarde/migratie faalt**
- veel betrouwbaardere reruns na een eerdere mislukte setup
