
## Plan: installer robuust maken voor bestaande /opt/lovable-app map

### Diagnose
De SSH-verbinding werkt nu wel:  
`Hi BartBrouwerHOI/Access-Guardian! You've successfully authenticated...`

De nieuwe fout komt door iets anders:

1. `git clone` faalt omdat `/opt/lovable-app` al bestaat en niet leeg is
2. daarna is `/opt/lovable-app` handmatig verwijderd terwijl de shell nog **in die map** stond
3. daardoor krijg je:
   - `getcwd: cannot access parent directories`
   - `bash: install.sh: No such file or directory`

Met andere woorden: niet SSH is nu het probleem, maar de installer-flow rond een half-bestaande app-map.

### Aanpak

#### 1. `install.sh` veiliger maken bij bestaande app-map
In `clone_app()` de huidige check uitbreiden:

- als `/opt/lovable-app` een geldige git repo is: `git pull`
- als `/opt/lovable-app` bestaat maar **geen** geldige repo is:
  - duidelijke melding tonen
  - uitleggen dat dit meestal een lege/incomplete map van een eerdere poging is
  - vragen of het script de map veilig mag verwijderen en opnieuw clonen
- vóór verwijderen eerst naar een veilige map gaan (bijv. `/`) zodat het script nooit “zijn eigen werkdirectory” kwijt raakt
- daarna pas opnieuw `git clone`

Dit voorkomt dat gebruikers zelf `rm -rf /opt/lovable-app` hoeven uit te voeren vanuit de verkeerde directory.

#### 2. Handleiding corrigeren voor handmatige `install.sh` flow
In `src/routes/handleiding.tsx` de fallback-instructies aanscherpen:

- vóór `nano /opt/lovable-app/install.sh` eerst de map aanmaken:
  - `sudo mkdir -p /opt/lovable-app`
- starten met een **absoluut pad**:
  - `sudo bash /opt/lovable-app/install.sh`
  - niet afhankelijk van de huidige directory
- extra waarschuwing toevoegen:
  - als je `/opt/lovable-app` verwijdert terwijl je daarin staat, doe eerst `cd ~` of `cd /root`

#### 3. Embedded `installScript` synchroniseren
De ingebouwde `installScript` string in `InstallShMissing` updaten met dezelfde robuustere logica als de echte `install.sh`, zodat handmatig gekopieerde versies exact hetzelfde gedrag hebben.

#### 4. Troubleshooting aanvullen
Een korte troubleshooting-blok toevoegen voor deze 3 concrete meldingen:

- `destination path '/opt/lovable-app' already exists and is not an empty directory`
- `getcwd: cannot access parent directories`
- `bash: install.sh: No such file or directory`

Met bijbehorende uitleg in gewone taal:
- map bestaat al/incompleet
- je staat in een map die je net verwijderd hebt
- daarom is `install.sh` ook weg of niet meer bereikbaar

### Bestanden
| Bestand | Actie |
|---|---|
| `install.sh` | bestaande/incomplete app-map detecteren, veilige cleanup prompt, daarna opnieuw clonen |
| `src/routes/handleiding.tsx` | handmatige stappen aanpassen: map aanmaken, absoluut pad gebruiken, waarschuwing over verwijderen vanuit huidige map |
| `src/routes/handleiding.tsx` | embedded `installScript` gelijktrekken met de echte fix |
| `src/routes/handleiding.tsx` | troubleshooting uitbreiden met deze specifieke foutmeldingen |

### Technische details
- Gebruik een repo-check die echt onderscheid maakt tussen:
  - bestaande geldige repo
  - bestaande map zonder repo
- Bij cleanup eerst uit de doelmap weg:
  ```text
  cd /
  rm -rf /opt/lovable-app
  ```
- Gebruik in documentatie consequent:
  ```text
  sudo bash /opt/lovable-app/install.sh
  ```
  in plaats van:
  ```text
  sudo bash install.sh
  ```

### Resultaat
Na deze wijziging:
1. blokkeert de installer niet meer onduidelijk op een half-bestaande `/opt/lovable-app`
2. hoeven gebruikers niet meer handmatig in een kapotte shell-state terecht te komen
3. is de handleiding veilig om opnieuw te starten, ook na een mislukte eerdere poging
4. is duidelijk dat de SSH-check nu geslaagd is en dat alleen de map-/rerun-flow nog opgelost moest worden
