
## Diagnose
- `git clone` slaagt nu, dus SSH en map-cleanup werken.
- Het probleem zit waarschijnlijk in de **self-update check** van `clone_app()`.
- Nu wordt na het clonen vergeleken met:
  ```bash
  cmp -s "$0" "$APP_DIR/install.sh"
  ```
- Als je het script start vanaf `/opt/lovable-app/install.sh` en die map daarna wordt verwijderd en opnieuw gecloned, wijst `$0` na de clone óók naar het nieuwe bestand op hetzelfde pad.
- Daardoor vergelijkt het script in feite **nieuw bestand met nieuw bestand**, dus er volgt geen restart.
- Resultaat: de **oude, al draaiende shell-versie** van `install.sh` loopt door, terwijl de repo inmiddels vervangen is. Dat verklaart waarom de flow nog “oud” gedrag vertoont.

## Plan
1. **Self-update in `install.sh` echt betrouwbaar maken**
   - Vóór het verwijderen/clonen van `$APP_DIR` de checksum van het nu draaiende script opslaan.
   - Na clone/pull de checksum van de nieuw gekloonde `install.sh` vergelijken met die opgeslagen checksum, in plaats van met `$0`.
   - Als de repo-versie anders is: duidelijk loggen en automatisch herstarten met de nieuwe `install.sh`.

2. **Repo-validatie verbeteren**
   - In `clone_app()` een repo niet meer als “ongeldig” bestempelen puur omdat `docker-compose.yml` ontbreekt.
   - `.git` gebruiken als hoofdcheck voor “dit is een echte clone”.
   - Daarna een aparte validatiestap doen op vereiste bestanden zoals:
     - `install.sh`
     - `docker-compose.yml`
     - `Dockerfile`
     - `volumes/kong/kong.yml`
   - Zo wordt meteen duidelijk of het probleem in de repo zit of in de installer-flow.

3. **Foutmelding in `setup_supabase()` nuttiger maken**
   - De huidige guard laten staan.
   - De fout uitbreiden met concretere uitleg:
     - of de repo is incompleet
     - of de installer is niet overgeschakeld naar de nieuw gekloonde versie
   - Exact pad tonen dat gecontroleerd wordt.

4. **Embedded script in `src/routes/handleiding.tsx` synchroniseren**
   - Dezelfde checksum-gebaseerde self-update toepassen in de getoonde `installScript` string.
   - Zo blijft de handmatig gekopieerde versie gelijk aan de echte `install.sh`.

5. **Handleiding aanvullen**
   - Bij de fallback “install.sh handmatig kopiëren” expliciet vermelden:
     - eerste run kan de repo clonen
     - daarna kan de installer zichzelf één keer opnieuw starten
     - daarna moet de gebruiker eventueel de prompts nogmaals invullen
   - Troubleshooting aanvullen met deze specifieke oorzaak.

## Technische details
```text
Huidige flow:
handmatig /opt/lovable-app/install.sh starten
→ repo wordt naar /opt/lovable-app gecloned
→ install.sh op dat pad wordt vervangen
→ cmp "$0" "$APP_DIR/install.sh"
→ vergelijking ziet hetzelfde pad / hetzelfde bestand
→ geen restart
→ oude shell-versie draait verder
```

```text
Nieuwe flow:
checksum huidige script opslaan vóór clone
→ clone repo
→ checksum repo/install.sh berekenen
→ als checksum verschilt: exec bash /opt/lovable-app/install.sh
```

## Bestanden
- `install.sh`
- `src/routes/handleiding.tsx`

## Verwacht resultaat
- Na een handmatig geplaatste bootstrap-`install.sh` schakelt de installer na de eerste succesvolle clone correct over naar de repo-versie.
- De fout rond `docker-compose.yml` wordt óf opgelost, óf veel duidelijker verklaard als de repo het bestand echt mist.
- De handleiding en embedded script blijven exact in sync.
