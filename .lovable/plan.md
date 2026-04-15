
## Diagnose

De patch is al aanwezig in `install.sh` en `update.sh`, maar hij heeft niet gewerkt.

Waarschijnlijk oorzaak:
- de huidige check zoekt op `grep -q "VALUES ('fa761b51-"`, en/of
- de huidige `sed`-replace verwacht dat de hele `INSERT ... VALUES ...` op één regel matcht.

Bij echte SQL-migraties staat zo’n statement vaak over meerdere regels. Dan triggert de patch niet. Dat past ook bij jouw log: de regel `Migratie-patch: conditionele super_admin INSERT` verschijnt nergens, dus de functie is wel aangeroepen maar heeft niets aangepast.

## Plan

### 1. Patchfunctie robuust maken in beide scripts
Ik pas `patch_known_migrations()` aan in:
- `install.sh`
- `update.sh`

Nieuwe aanpak:
- niet meer zoeken op een fragiele `VALUES (`-substring
- wel zoeken op:
  - bestandsnaam van de bekende migratie
  - aanwezigheid van de problematische UUID
  - afwezigheid van `WHERE EXISTS` zodat de patch idempotent blijft
- de SQL vervangen met een multiline-veilige aanpak in plaats van de huidige één-regelige `sed`

### 2. Multiline-safe replacement gebruiken
In plaats van de huidige `sed`-regel gebruik ik een veiligere vervanging die ook werkt als de SQL over meerdere regels staat.

Doelvervanging:

```sql
INSERT INTO user_roles (user_id, role)
SELECT 'fa761b51-9489-4289-917b-d1818f3cd508', 'super_admin'::app_role
WHERE EXISTS (
  SELECT 1 FROM public.profiles
  WHERE id = 'fa761b51-9489-4289-917b-d1818f3cd508'
)
ON CONFLICT (user_id, role) DO NOTHING;
```

### 3. Logging verbeteren
Ik laat de scripts duidelijk melden:
- wanneer de patch wordt geprobeerd
- wanneer de migratie al gepatcht is
- wanneer de target-file wel bestaat maar het verwachte patroon niet matcht

Zo is in serverlogs meteen zichtbaar waarom het wel of niet werkte.

### 4. Foutmelding uitbreiden met workaround
Bij mislukte migraties voeg ik expliciet deze herstelroute toe in `update.sh`:
- `lovable-update --mark-done <bestandsnaam>`

Dat lost de hoofdoorzaak niet op, maar maakt herstel veel duidelijker als iemand al in deze situatie zit.

## Verwacht resultaat

Na deze wijziging:
- werkt de on-the-fly patch ook als de SQL multiline is
- stopt een verse self-hosted installatie niet meer op `20260119083612...`
- zijn bestaande installaties niet geraakt
- is het debuggen van toekomstige migratieproblemen eenvoudiger

## Technische notitie

De kernfout zit dus niet meer in het idee van de patch, maar in de implementatie van de match:
- huidige patroon is te strikt
- `sed` met `.*` werkt hier niet betrouwbaar over meerdere regels
- daarom moet de patchfunctie inhoudelijk slimmer en multiline-bestendig worden
