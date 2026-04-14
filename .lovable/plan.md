
## Plan: GitHub repo URL prompt ondubbelzinnig maken

### Probleem
De flow is nog verwarrend bij handmatig aangemaakte `install.sh`:

- De gebruiker start `install.sh` correct
- Daarna vraagt het script om de **GitHub repo URL**
- Omdat niet duidelijk is wat daar verwacht wordt, plakt de gebruiker de **inhoud van het script** in plaats van een repo-URL

De handleiding legt nu niet expliciet genoeg uit dat handmatig `install.sh` aanmaken alleen het installer-bestand toevoegt — het script moet daarna nog steeds de **hele app-repo via SSH clonen**.

### Aanpak

#### 1. `install.sh` duidelijker maken
In `clone_app()` de repo-invoer uitbreiden van een kale prompt naar een korte uitleg vóór de prompt:

- uitleg dat het script nu de **hele GitHub repo** gaat clonen
- expliciet zeggen: **plak hier niet de inhoud van `install.sh`**
- exact voorbeeld tonen:
  `git@github.com:JOUW-USER/JOUW-REPO.git`

Daarna de invoer valideren vóór de SSH-test / `git clone`:

- leeg invoerblok afwijzen
- invoer met meerdere regels of `#!/bin/bash` afwijzen
- alleen SSH-format accepteren, zoals:
  `git@github.com:gebruiker/repo.git`

Bij foute invoer een duidelijke melding tonen en opnieuw vragen.

#### 2. Handleiding aanpassen in `InstallShMissing`
In de handmatige flow een extra expliciete stap toevoegen ná `sudo bash install.sh`:

- “Als het script vraagt om **GitHub repo URL**, plak dan de SSH URL van je repo”
- erbij vermelden waar je die vindt:
  **GitHub → Code → SSH**
- voorbeeld tonen:
  `git@github.com:JOUW-USER/JOUW-REPO.git`
- extra waarschuwing:
  “Plak hier niet opnieuw de tekst van `install.sh`”

#### 3. Embedded `installScript` synchroniseren
De `installScript` string in `src/routes/handleiding.tsx` gelijk trekken met de echte `install.sh`, zodat de handmatig gekopieerde versie exact dezelfde duidelijke prompt en validatie gebruikt.

### Bestanden
| Bestand | Actie |
|---|---|
| `install.sh` | Repo-prompt uitbreiden met uitleg + voorbeeld + invoervalidatie |
| `src/routes/handleiding.tsx` | `InstallShMissing` aanvullen met expliciete repo-URL stap en waarschuwing |
| `src/routes/handleiding.tsx` | Embedded `installScript` updaten met dezelfde verbeterde prompt/validatie |

### Technische details
- Validatie op SSH repo-formaat, bijvoorbeeld:
  `git@github.com:owner/repo.git`
- Expliciet blokkeren van invoer die lijkt op geplakte scriptinhoud:
  - begint met `#!/bin/bash`
  - bevat regeleinden
  - bevat geen geldig `git@github.com:` patroon

### Resultaat
Na deze wijziging is voor gebruikers meteen duidelijk:
1. `install.sh` is alleen de installer
2. daarna moet nog de **repo-URL** ingevuld worden
3. de juiste waarde is de **SSH clone URL**, niet de scriptinhoud
