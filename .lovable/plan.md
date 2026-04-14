

## Plan: Duidelijkere instructies voor handmatig aanmaken + uitvoeren van install.sh

### Probleem

Uit de screenshot blijkt:
1. De gebruiker maakt `install.sh` aan met `nano`, maar voert daarna `sudo install.sh` of `install.sh` uit — dat geeft "command not found" omdat het geen `bash` ervoor zet
2. De `InstallShMissing` component vertelt wel hoe je het bestand moet plakken/opslaan, maar het run-commando staat er niet duidelijk onder als apart kopieerbaar commando

### Oplossing

**In `src/routes/handleiding.tsx` — component `InstallShMissing` (regel 1178-1181):**

De huidige "Gebruik:" tekst onderaan het collapsible blok is:
> `nano /opt/lovable-app/install.sh` → plak → opslaan → `chmod +x install.sh`

Dit vervangen door een duidelijke stap-voor-stap met het run-commando als apart code block:

**Nieuwe instructie (3 stappen):**
1. Maak het bestand aan: `nano /opt/lovable-app/install.sh`
2. Plak de inhoud → opslaan met Ctrl+O, Enter, Ctrl+X
3. Maak uitvoerbaar en start:

```bash
chmod +x /opt/lovable-app/install.sh
sudo bash /opt/lovable-app/install.sh
```

Het run-commando (`sudo bash install.sh`) wordt een apart `<CodeBlock>` zodat het kopieerbaar en onmisbaar zichtbaar is — niet langer verborgen in een tekstregel.

Daarnaast een `<Warn>` toevoegen:
> **Let op:** Gebruik altijd `sudo bash install.sh` — niet `sudo install.sh` of `./install.sh`. Zonder `bash` herkent Linux het commando niet.

### Wijzigingen

| Bestand | Actie |
|---------|-------|
| `src/routes/handleiding.tsx` | InstallShMissing component: vervang de "Gebruik:" regel (regel 1178-1181) door duidelijke stappen met apart kopieerbaar run-commando + waarschuwing over `bash` |

