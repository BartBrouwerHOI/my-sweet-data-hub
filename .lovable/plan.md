
## Probleem

`--mark-done` werkt op jouw server nog niet, ook al staat de code wel in deze repo.

De oorzaak is niet de migratie zelf, maar de updater-architectuur:

- `lovable-update` op de server is een **gegenereerd script** in `/usr/local/bin/lovable-update`
- dat script wordt alleen opnieuw aangemaakt door `install.sh` via `create_update_script()`
- een normale `sudo lovable-update` doet wel `git pull` van de infra-repo, maar **regenereert zichzelf niet**
- daardoor draait jouw server nog steeds een **oude wrapper**, die `--mark-done` niet echt afhandelt en gewoon de volledige flow uitvoert

Ik zie dat ook terug in de code:
- `install.sh` bevat wel de nieuwe `--mark-done` logica in `create_update_script()`
- `update.sh` bevat die ook
- maar `update.sh` doet bovenaan eerst:
  - `if command -v lovable-update ... exec lovable-update "$@"`
- dus zolang het oude `/usr/local/bin/lovable-update` bestaat, kom je alsnog weer in dat verouderde script terecht

## Plan

### 1. Handleiding en documentatie corrigeren
Ik pas de documentatie aan zodat die niet suggereert dat `--mark-done` meteen werkt na alleen een gewone update.

Concreet:
- in `INSTALL.md` verduidelijken dat nieuwe flags pas actief zijn nadat de updater zelf is vernieuwd
- in `/handleiding` een korte waarschuwing toevoegen bij `--mark-done`:
  - als `lovable-update --mark-done ...` toch een volledige update start, draait de server nog een oudere gegenereerde updater

### 2. Updater self-refresh oplossen
Ik pas de updateflow aan zodat een infra-update ook de echte `/usr/local/bin/lovable-update` opnieuw kan genereren zonder volledige herinstallatie.

Waarschijnlijke aanpak:
- een aparte refresh-stap toevoegen, bijvoorbeeld:
  - `install.sh --refresh-updater`
  - of een klein los script dat alleen `create_update_script`-achtige logica uitvoert
- doel:
  - bestaande paden/mode uitlezen
  - `/usr/local/bin/lovable-update` herschrijven
  - geen Docker/Supabase reinstall
  - geen secrets regenereren

### 3. Fallback veiliger maken
Ik pas `update.sh` aan zodat die niet blind doorstuurt naar een bestaande `lovable-update` als juist die wrapper mogelijk verouderd is.

Mogelijke veilige variant:
- alleen doorverwijzen als expliciet gewenst
- of bij `--mark-done` juist de fallback-logica lokaal afhandelen
- of een versie/check toevoegen zodat een stale wrapper wordt omzeild

### 4. Directe server-herstelroute opnemen
Omdat jij nu vastzit, neem ik ook een praktische herstelroute mee in de docs en flow:

```text
doel:
1. updater wrapper vernieuwen
2. daarna pas:
   lovable-update --mark-done <migratie.sql>
3. daarna:
   lovable-update
```

Daarmee voorkom je dat mensen opnieuw denken dat `--mark-done` kapot is, terwijl in werkelijkheid alleen de oude wrapper nog actief is.

## Bestanden

- `install.sh` — mechanisme toevoegen om `/usr/local/bin/lovable-update` veilig te vernieuwen zonder herinstallatie
- `update.sh` — fallback/doorverwijslogica verbeteren
- `INSTALL.md` — uitleg corrigeren
- `src/routes/handleiding.tsx` — waarschuwing + juiste herstelstappen toevoegen

## Technische details

Huidige keten:

```text
server commando
  -> /usr/local/bin/lovable-update   (gegenereerd, mogelijk oud)
     -> git pull infra repo
     -> nieuwe install.sh komt binnen
     -> maar wrapper blijft oud
```

Gewenste keten:

```text
server commando
  -> updater ververst eerst zichzelf of kan apart ververst worden
  -> daarna werken nieuwe flags echt
```

Extra detail:
- `update.sh` heeft nu ook de bug dat het `MIGRATIONS_DONE_DIR` gebruikt vóór die variabele wordt gezet
- maar in jouw geval is dat niet eens de hoofdroute, omdat het script meteen doorstuurt naar het bestaande `lovable-update`
- de echte kern is dus: **stale generated updater**

## Verwacht resultaat

Na implementatie kun je lokaal op de server updaten zonder herinstallatie én zonder vast te lopen op een oude wrapper:

- infra-update haalt nieuwe updatercode op
- updater kan zichzelf vernieuwen
- `--mark-done` werkt daarna echt
- de geblokkeerde migratie kan worden overgeslagen
- daarna kan `lovable-update` de resterende nieuwe migraties normaal uitvoeren
