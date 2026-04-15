

## Analyse

Het goede nieuws: `install.sh` schrijft **al** een `.env.production` met de juiste self-hosted URL en anon key (regel 546-549). Vite pikt dit op tijdens de Docker build en de waarden worden ingebakken in de frontend.

Er zijn echter **twee bugs** waardoor dit in de praktijk niet werkt:

### Bug 1: Update-script schrijft `.env.production` niet opnieuw

Bij `lovable-update` wordt de app opnieuw gebouwd (`docker build`), maar de `.env.production` wordt **niet** herschreven. Als `git pull` een `.env` of `.env.production` uit de app-repo haalt (met Lovable Cloud waarden), overschrijft dat jouw self-hosted waarden.

### Bug 2: Variabelenaam mismatch

Het install-script schrijft `VITE_SUPABASE_PUBLISHABLE_KEY`, maar Lovable-apps gebruiken standaard `VITE_SUPABASE_ANON_KEY`. Als de app de verkeerde naam zoekt, vindt hij niets en valt terug op een hardcoded waarde (de Lovable Cloud URL).

## Plan

### 1. Update-script: `.env.production` herschrijven vóór elke build

In de gegenereerde `lovable-update` wrapper (in `create_update_script()`) toevoegen dat `.env.production` opnieuw wordt geschreven vóór `docker build`, zowel in de volledige update als in `--app-only`.

Dit zorgt ervoor dat de self-hosted waarden altijd winnen, ook als de app-repo eigen `.env` bestanden meebrengt.

### 2. Beide variabelenamen schrijven

`.env.production` krijgt beide varianten:
```
VITE_SUPABASE_URL=https://jouw-domein.nl
VITE_SUPABASE_ANON_KEY=<key>
VITE_SUPABASE_PUBLISHABLE_KEY=<key>
```
Dan werkt het ongeacht welke naam de app gebruikt.

### 3. Dockerfile: `.env*` niet uitsluiten

Controleren dat `.dockerignore` (als die bestaat in de app) geen `.env.production` uitsluit.

## Bestanden

- `install.sh` — variabelenaam toevoegen + update-script aanpassen zodat `.env.production` bij elke build wordt herschreven

## Resultaat

Na deze wijziging hoeft de gebruiker **niets handmatig aan te passen** in de app-repo. Het install- en update-script zorgen er automatisch voor dat de frontend altijd de self-hosted Supabase URL en key gebruikt.

