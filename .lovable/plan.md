
## Diagnose

De kern is nu duidelijk:

- jouw server draait **niet** `update.sh`
- jouw commando gebruikt het gegenereerde bestand **`/usr/local/bin/lovable-update`**
- dat script wordt opgebouwd vanuit **`install.sh` → `create_update_script()`**
- in dat gegenereerde updater-script ontbreekt de nieuwe `patch_known_migrations()`-logica nog steeds

Dat past exact bij je log:
- je ziet `=== Lovable App Updater ===` → dat is het **gegenereerde updater-script**
- je ziet **geen** regel zoals `Migratie-patch: ...` → de patchfunctie wordt daar helemaal niet aangeroepen
- daardoor draait de originele kapotte migratie ongewijzigd en faalt hij opnieuw

## Plan

### 1. De echte fix in `install.sh` zetten
Ik pas **`create_update_script()`** in `install.sh` aan, zodat het gegenereerde `/usr/local/bin/lovable-update` zelf ook:

- `patch_known_migrations()` bevat
- vóór de migratie-loop `patch_known_migrations` aanroept
- dezelfde robuuste multiline-patch gebruikt als in `update.sh`

Belangrijkste doel:
- niet alleen de fallback `update.sh` fixen
- maar juist de **gegenereerde updater**, want die gebruik jij op de server

### 2. Beide relevante updater-varianten aanpassen
Ik werk in `install.sh` de templates bij voor:

- **database mode**
- **full mode**

Daar zit de migratie-runner in.  
`frontend mode` hoeft geen migratie-patch te krijgen.

### 3. Patch robuuster maken en verifiëren
Ik maak de patch niet alleen multiline-safe, maar ook controleerbaar:

- eerst checken of targetbestand bestaat
- checken of UUID aanwezig is
- checken of `WHERE EXISTS` nog niet aanwezig is
- patch toepassen
- daarna **verifiëren dat de file echt gewijzigd is**
- alleen dan `✅ toegepast` loggen

Zo voorkomen we een vals succesbericht.

### 4. Logging en foutmelding gelijk trekken
Ik zorg dat zowel `install.sh` als het gegenereerde `lovable-update` duidelijk loggen:

- doelbestand niet gevonden
- al gepatcht
- UUID niet gevonden
- patch toegepast
- patch geprobeerd maar patroon niet vervangen

En bij migratiefouten komt expliciet de herstelroute in beeld:

```bash
lovable-update --mark-done 20260119083612_fc4680d3-4321-408e-ac77-817040a08a81.sql
```

### 5. Direct herstelpad voor jouw server
Na de codewijziging is de beoogde volgorde:

```text
git pull infra-repo
sudo bash /opt/lovable-infra/install.sh --refresh-updater
sudo lovable-update
```

Waarom deze extra stap:
- jouw `lovable-update` moet eerst opnieuw gegenereerd worden uit de **nieuwe** `install.sh`
- daarna pas bevat het command de patchlogica

## Verwacht resultaat

Na deze wijziging:

- gebruikt het echte server-commando eindelijk dezelfde patchlogica
- wordt de kapotte migratie vooraf on-the-fly aangepast
- stopt een verse self-hosted installatie niet meer op `20260119083612...`
- is in logs meteen zichtbaar of de patch echt is uitgevoerd

## Technische details

Het echte probleem zit dus niet meer alleen in de regex of multiline-match, maar vooral hier:

```text
install.sh
└── create_update_script()
    └── schrijft /usr/local/bin/lovable-update
        └── daarin ontbrak de patch_known_migrations()-aanroep
```

`update.sh` als fallback was al dichter bij goed, maar jouw serverpad gebruikt het gegenereerde updater-script. Daarom werkte de eerdere fix in de praktijk nog niet.
