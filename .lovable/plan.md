

## Analyse: huidige pijnpunten

Na het doorlopen van alle bestanden zie ik drie grote problemen voor beheerders:

### 1. Twee deploy keys / twee repo's = verwarring
De handleiding vraagt om infra-repo EN app-repo velden, legt uit dat GitHub dezelfde deploy key niet op twee repo's toelaat, en verwijst naar machine users en PATs. Dit is de grootste bron van complexiteit. **De infra-repo bevat geen geheimen** (docker-compose.yml gebruikt env vars, geen hardcoded secrets). Er is geen reden om deze privé te houden.

**Oplossing:** Maak de infra-repo **publiek**. Dan:
- Clone via HTTPS zonder authenticatie: `git clone https://github.com/USER/REPO.git`
- Beheerder heeft alleen een deploy key nodig voor de **app-repo**
- Formulier in handleiding wordt simpeler (geen infra-user/infra-repo velden meer)

### 2. Te veel configuratievelden in de handleiding
Het formulier vraagt 7 velden (infraUser, infraRepo, appUser, appRepo, serverIp, domain, serverAIp). Met een publieke infra-repo en de infra-URL hardcoded in de handleiding worden infraUser/infraRepo overbodig.

### 3. `update.sh` in de repo root is een dode stub
Het bestand doet niets behalve doorverwijzen naar `lovable-update`. Verwarrend als iemand het per ongeluk draait.

### 4. `nginx/frontend-ssr.conf` wordt nooit gebruikt
De SSR Dockerfile draait Node.js direct — er is geen nginx nodig in de container. De host-nginx (geconfigureerd door install.sh) proxied al naar poort 3000. Dit bestand is misleidend.

### 5. Troubleshooting item verwijst nog naar `/opt/lovable-app/install.sh`
Regel 707-709 verwijst naar het oude pad, moet `/opt/lovable-infra/install.sh` zijn.

---

## Plan: vereenvoudiging

### A. install.sh — infra-clone via HTTPS (geen deploy key nodig)
- Hardcode de infra-repo URL als HTTPS (public) bovenaan het script
- Verwijder de noodzaak voor een deploy key op de infra-repo
- De `clone_app()` functie blijft SSH vragen (die repo is privé)
- Voeg een `INFRA_REPO_URL` variabele toe bovenaan zodat het makkelijk aanpasbaar is

### B. handleiding.tsx — formulier versimpelen
- Verwijder `infraUser` en `infraRepo` velden
- Hardcode de infra clone-URL in de codeblokken (HTTPS, publiek)
- Houd alleen: `appUser`, `appRepo`, `serverIp`, `domain`, `serverAIp`
- Deploy key sectie: verwijder "Optie B: PAT" en "machine user" — er is maar één privé repo, dus één deploy key werkt altijd
- Verwijder de waarschuwing over "GitHub staat dezelfde deploy key niet toe op twee repo's"

### C. Verwijder `nginx/frontend-ssr.conf`
- Wordt nergens gebruikt (SSR draait op Node.js, host-nginx doet de proxy)
- Verwijder het bestand

### D. Vervang `update.sh` door directe instructie
- Verwijder de stub, of maak er een werkend fallback-script van dat zelfstandig werkt (zonder dat `lovable-update` al geregistreerd is)

### E. Fix troubleshooting pad
- Regel 707: verander `/opt/lovable-app/install.sh` naar `/opt/lovable-infra/install.sh`

### F. index.tsx — landingspagina updaten
- Architectuurdiagram: voeg de twee-map structuur toe (infra + app)
- Feature "SPA + SSR" benoemen

---

## Bestanden

| Bestand | Actie |
|---|---|
| `install.sh` | Voeg `INFRA_REPO_URL` variabele toe, clone via HTTPS |
| `src/routes/handleiding.tsx` | Formulier versimpelen, deploy key sectie verkorten, fix troubleshooting pad |
| `nginx/frontend-ssr.conf` | Verwijderen (ongebruikt) |
| `update.sh` | Werkend maken als standalone fallback |
| `src/routes/index.tsx` | Architectuur-diagram updaten |

