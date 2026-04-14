

## Plan: Fouten in het installatieproces fixen

### Gevonden problemen

**1. `ls install.sh` staat op de verkeerde plek (Split mode A en B)**

In de single mode staat de volgorde correct (`cd` → `ls`), maar bij Split Server A (regel 424-428) en Split Server B (regel 469-473) wordt `ls install.sh` uitgevoerd VÓÓR `cd /opt/lovable-app`. Daardoor controleert het in de verkeerde directory.

Huidige volgorde (fout):
```
git clone ... /opt/lovable-app
ls install.sh              ← VERKEERD: nog niet in /opt/lovable-app!
cd /opt/lovable-app
sudo bash install.sh
```

Correcte volgorde:
```
git clone ... /opt/lovable-app
cd /opt/lovable-app
ls install.sh              ← NU in de juiste map
sudo bash install.sh
```

**2. curl fallback URL hardcodeert `/main/` branch**

De fallback `curl -O https://raw.githubusercontent.com/.../main/install.sh` gaat ervan uit dat de default branch `main` heet. Lovable's GitHub sync kan ook `master` of een andere branch gebruiken. In de screenshot van de gebruiker haalde curl 14 bytes op (een 404-pagina), wat betekent dat het bestand niet op die URL staat.

Oplossing: Tip toevoegen dat de branch kan afwijken, en de gebruiker aanraden om eerst op GitHub te controleren welke branch het is.

**3. `install.sh` bestaat mogelijk niet in de GitHub repo**

Het bestand `install.sh` staat wél in het Lovable-project, maar als de GitHub sync niet up-to-date is, mist het in de repo. De handleiding vermeldt dit al als troubleshooting, maar de curl-fallback werkt dan ook niet (zelfde repo). 

Oplossing: Voeg een extra fallback optie toe — kopieer het script handmatig vanuit de handleiding-pagina zelf, of verwijs naar het "rauw" bekijken op GitHub om de branch te controleren.

### Wijzigingen

| Bestand | Actie |
|---------|-------|
| `src/routes/handleiding.tsx` | Fix `cd`/`ls` volgorde in Split A en B; verbeter curl fallback met branch-tip |

### Details

**Split Server A (regel ~417-431):** Verplaats `cd /opt/lovable-app` naar vóór `ls install.sh`

**Split Server B (regel ~462-478):** Zelfde fix

**Curl fallback (3 plekken):** Voeg opmerking toe: "Controleer op GitHub welke branch je gebruikt (main of master)" en pas de URL aan zodat de branchnaam ook vervangbaar is.

