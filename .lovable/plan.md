

## Plan: Verificatiestap toevoegen na git clone + troubleshooting voor ontbrekend install.sh

### Probleem

Na een succesvolle `git clone` geeft `bash install.sh` de fout "No such file or directory". Dit kan twee oorzaken hebben:

1. **Het bestand is niet gecommit naar GitHub** — Lovable heeft het lokaal, maar het is mogelijk niet gepusht naar de repo
2. **De gebruiker staat niet in de juiste directory** — onwaarschijnlijk gezien de screenshot

### Wijzigingen in `src/routes/handleiding.tsx`

**1. Verificatiestap toevoegen na elke git clone** (3 plekken: single, split A, split B)

Na het clone-commando en vóór `sudo bash install.sh`, een controle toevoegen:

```bash
# Controleer of install.sh aanwezig is
ls install.sh
```

**2. Warn/Tip toevoegen** na de clone-stappen met troubleshooting als het bestand ontbreekt:

> **install.sh niet gevonden?** Dan is het bestand waarschijnlijk niet mee-gepusht naar GitHub. Controleer in je GitHub repo of `install.sh` in de root staat. Zo niet:
> 1. Ga naar Lovable → Connectors → GitHub en controleer of de sync actief is
> 2. Of download `install.sh` handmatig: `curl -O https://raw.githubusercontent.com/JOUW-USER/JOUW-REPO/main/install.sh`

**3. Fallback curl-commando** toevoegen als alternatief voor als het bestand ontbreekt.

### Bestand

| Bestand | Actie |
|---------|-------|
| `src/routes/handleiding.tsx` | Verificatiestap + troubleshooting tip na git clone op 3 plekken |

