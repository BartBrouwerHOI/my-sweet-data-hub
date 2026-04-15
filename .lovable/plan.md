
## Bevindingen

- Ja: in **full mode** haalt `lovable-update` nu bewust **zowel infra als app** op. Dat is geen bug in Git, maar de huidige opzet van `install.sh` die `/usr/local/bin/lovable-update` genereert.
- Het haalt niet “alles opnieuw binnen” als verse install; het doet gewoon `git pull` op beide repo’s, bouwt daarna de frontend opnieuw en draait nog niet-verwerkte migraties.
- De **echte blocker** is nog steeds de app-migratie `20260119083612_fc4680d3-4321-408e-ac77-817040a08a81.sql`: die probeert een rol toe te voegen voor een hardcoded `user_id` die niet in `profiles` bestaat.
- Online/Postgres-best-practice bevestigt dit patroon: dit is een **seed-data / foreign-key probleem**, geen Supabase-health of Docker-probleem. Zulke inserts moeten conditioneel zijn of uit schema-migraties gehaald worden.

## Plan

### 1. Update-flow verbeteren in deze infra-repo
Ik pas de updater aan zodat je niet vastzit aan één “full sync” pad.

- `lovable-update` blijft de **veilige volledige update**
- daarnaast komt een **app-only update-optie** voor snelle app-deploys zonder infra-pull
  - bijvoorbeeld `lovable-update --app-only` of een apart commando zoals `lovable-update-app`
- die app-only flow doet alleen:
  1. app-repo updaten
  2. frontend rebuilden
  3. frontend herstarten
  4. optioneel migraties overslaan of expliciet apart draaien

Zo kun je een app-fix deployen zonder elke keer eerst infra te pullen.

### 2. Fallback en documentatie gelijk trekken
Ik werk daarna ook de fallback en docs bij zodat alles consistent is:

- `install.sh` (`create_update_script`) aanpassen
- `update.sh` fallback dezelfde flags/flow geven
- `INSTALL.md` en handleidingtekst verduidelijken:
  - wat full mode doet
  - wat app-only doet
  - wanneer je welke gebruikt

### 3. De kapotte migratie echt oplossen in de app-repo
De blijvende fout moet in de **app-repo** worden opgelost.

Aanpak:
- de echte gedeployde Access-Guardian repo/branch controleren, want de workspace-kopie die ik nu kan lezen bevat deze specifieke oude migratie niet
- de foutieve migratie aanpassen zodat de insert **niet meer hardcoded en onvoorwaardelijk** draait
- aanbevolen fix:
  - `INSERT INTO user_roles ... SELECT ... WHERE EXISTS (...)`
  - of de seed-regel helemaal verwijderen uit de migratie
- als die rol echt nodig is voor een eerste admin, dan hoort dat in een **bootstrap/seed stap** thuis, niet in een schema-migratie

### 4. Verifiëren van de nieuwe flow
Na implementatie test ik 2 paden:

1. **App-only update**
   - bevestigen dat alleen app/build/restart gebeurt
   - geen infra `git pull` meer in die flow

2. **Volledige update**
   - bevestigen dat full mode nog steeds infra + app + migraties doet
   - bevestigen dat de migratiefout weg is zodra de app-repo fix live staat

## Technische details

- De relevante logica zit in:
  - `install.sh` → `create_update_script()`
  - `update.sh` → standalone fallback
- Alleen `update.sh` aanpassen is niet genoeg, want jouw echte `lovable-update` wordt gegenereerd door `install.sh`.
- De root cause is functioneel:
  ```text
  user_roles.user_id -> foreign key naar profiles.id
  hardcoded user_id bestaat niet in profiles
  => insert faalt
  ```
- De juiste structurele oplossing is:
  ```text
  schema-migraties = tabellen / policies / functies
  seed-data = conditioneel of apart bootstrap-script
  ```

## Verwacht resultaat

Na deze ronde heb je:

- een updater die niet onnodig eerst infra hoeft te pullen voor app-wijzigingen
- een duidelijk onderscheid tussen full update en app-only update
- een echte fix voor de vastlopende migratie in de app-repo
- daarna weer een `lovable-update` die schoon doorloopt zonder steeds op dezelfde oude migratie stuk te gaan
