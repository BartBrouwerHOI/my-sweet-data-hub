

## Analyse: wat goed is en wat beter kan

### Wat al goed werkt
- install.sh is solide: distro-detectie, mode-selectie, deploy key validatie, error handling
- Database-only update script is correct (alleen infra pull + docker compose)
- Migratie-tracking via `.migrations_done/` werkt
- Troubleshooting sectie is uitgebreid en praktisch

### Problemen gevonden

**1. `JOUW_ANON_KEY` placeholder niet automatisch ingevuld**
In de na-installatie stap (regel 494, 510, 519) staat `JOUW_ANON_KEY` als hardcoded tekst. Dit wordt NIET vervangen door de `fill()` functie — die kent alleen `INFRA-REPO-URL`, `APP-USER`, `APP-REPO`, `JOUW-SERVER-IP`, `jouw-domein.nl`, en `SERVER_A_IP`. De beheerder moet dit handmatig opzoeken. 

**Oplossing:** Verwijder de losse `curl` test met `JOUW_ANON_KEY` en verwijs alleen naar `credentials.txt`. Of splits het blok zodat de test apart staat met duidelijke instructie "vervang dit handmatig".

**2. Split mode migraties: onpraktisch scp-commando**
Regel 551-563: De migratie-instructie voor split mode is verwarrend — drie opties door elkaar (scp via eigen computer, scp direct, clone op Server A). Dit is te veel keuze.

**Oplossing:** Eén simpele aanpak: clone de app-repo op Server A (eenmalig), daarna `git pull` + migraties draaien. De scp-variant verwijderen.

**3. `gather_input()` vraagt GEEN repo URL in full mode**
In `gather_input()` (regel 129-146) wordt de GitHub repo URL alleen gevraagd in `clone_app()`. Maar de volgorde `gather_input()` → later `clone_app()` maakt dat de beheerder eerst alle andere vragen beantwoordt en dan pas de repo URL. Dit is logisch maar de handleiding (stap Installatie, regel 408-415) zet de repo URL als laatste bullet — dat klopt.

**4. `print_summary()` toont `APP_DIR` ook in database mode**
Regel 770: `📂 App: /opt/lovable-app` wordt altijd getoond, ook in database mode waar er geen app-dir is.

**5. Na-installatie codeblok combineert checks + tests in één kopieerbaar blok**
Het blok op regel 484-494 bevat zowel `docker ps` als de API-test met placeholder. Als een beheerder het hele blok kopieert en plakt, faalt het op de `JOUW_ANON_KEY` regel.

**Oplossing:** Splits in twee blokken: (1) basis-checks (docker ps, curl frontend), (2) API-test apart met instructie "vervang de key handmatig".

**6. Volgorde handleiding stappen is goed maar deploy key stap mist sudo-waarschuwing vroeg genoeg**
De handleiding begint met `ssh root@...` (als root inloggen), maar de deploy key wordt aangemaakt als root. Dat werkt, maar de troubleshooting over "sudo ssh werkt niet" (regel 676) is dan irrelevant. Kleine inconsistentie.

**7. `infraUrl` veld heeft geen voorbeeld-formaat**
De placeholder is `INFRA-REPO-URL` maar een beheerder weet niet of dit `https://github.com/user/repo.git` of `https://github.com/user/repo` moet zijn.

**Oplossing:** Placeholder aanpassen naar `https://github.com/user/repo.git`.

---

## Plan: fixes

### A. Na-installatie codeblok splitsen
- Blok 1: `docker ps` + `curl localhost:3000` + `cat credentials.txt | grep "Anon Key"`
- Blok 2 (apart): "Test de API" met uitleg dat je de key uit blok 1 moet invullen
- Verwijder `JOUW_ANON_KEY` uit kopieerbare blokken

### B. Split mode migraties vereenvoudigen
- Verwijder het scp-commando
- Eén aanpak: "Clone de app-repo op Server A (eenmalig), daarna `git pull && lovable-update`"
- Voeg toe: `install.sh` in database mode zou ook de app-repo moeten clonen (alleen voor migraties)

### C. `print_summary()` fix
- Verberg `APP_DIR` regel als `INSTALL_MODE=database`

### D. `infraUrl` placeholder verbeteren
- Verander placeholder van `INFRA-REPO-URL` naar `https://github.com/user/repo.git`

### E. install.sh database mode: ook app clonen (voor migraties)
- In database mode: vraag optioneel om de app-repo URL, clone naar `/opt/lovable-app` zodat migraties lokaal beschikbaar zijn
- Pas `create_update_script` aan: in database mode ook `git pull` in app-dir + migraties draaien

---

## Bestanden

| Bestand | Wijziging |
|---|---|
| `src/routes/handleiding.tsx` | Na-installatie blok splitsen, JOUW_ANON_KEY verwijderen uit kopieerblokken, split migratie vereenvoudigen, infraUrl placeholder verbeteren |
| `install.sh` | `print_summary`: verberg APP_DIR in database mode. Database mode: optioneel app-repo clonen voor migraties. Update script in database mode: migraties toevoegen |

