

## Analyse: gevonden problemen

### Kritieke fouten

**1. Fake infra-repo URL overal hardcoded**
`https://github.com/lovable-vps/lovable-infra.git` bestaat niet. Dit staat in de handleiding, INSTALL.md, en codeblokken. De gebruiker moet de echte URL van dit project invullen, of het moet configureerbaar zijn.

**2. Split mode Server A: migraties onmogelijk**
De handleiding (regel 543-550) zegt op Server A: `cd /opt/lovable-app && git pull` — maar in database mode wordt `clone_app` overgeslagen. Die map bestaat niet op Server A.

**3. Database mode: kapot update-script**
`create_update_script()` gebruikt `$PROJECT_TYPE` en `$APP_DIR`, maar in database mode zijn die leeg. Het gegenereerde `lovable-update` commando zou falen.

**4. `sudo chown $USER:$USER` is zinloos als root**
De handleiding begint met `ssh root@...`. Als je als root inlogt is `$USER=root` en doet chown niets. Bovendien draait `install.sh` al als root, dus de mkdir+chown stap is overbodig — het script doet dit zelf.

### Logica/volgorde problemen

**5. Handleiding clone-stappen te veel ruis**
De drie regels `mkdir -p`, `chown`, `git clone` kunnen één regel zijn: `git clone ... /opt/lovable-infra`. Git maakt de map zelf aan. Als root heb je geen chown nodig.

**6. Split mode mist een duidelijke "checklist" tussenstap**
Na Server A installatie moet je gegevens noteren (Anon Key, Server A IP). De handleiding vermeldt dit, maar het zit verstopt in een waarschuwingsblok. Een expliciete "noteer deze gegevens" checklist is duidelijker.

**7. Migraties zijn niet idempotent**
Het update-script draait ALLE migraties opnieuw bij elke update. Supabase migraties bevatten vaak `CREATE TABLE` die falen bij tweede run. De `|| true` onderdrukt de fout, maar dat verbergt ook echte fouten.

### Kleine verbeteringen

**8. Handleiding verwijst naar `JOUW_ANON_KEY` in na-installatie stap** — maar die key staat in `/opt/supabase/credentials.txt`. Zou helpen om dat expliciet te zeggen.

**9. De infra-repo URL moet in het configuratieformulier** — of je hardcode de echte URL van dit project.

---

## Plan: fixes

### A. Infra-repo URL oplossen
Twee opties:
- **Optie 1**: Voeg `infraUrl` veld toe aan het configuratieformulier (simpelste)
- **Optie 2**: Hardcode de echte GitHub URL van dit project

Ik ga voor **optie 1** — een extra veld "Infra-repo URL" met placeholder `https://github.com/USER/REPO.git`. De handleiding-codeblokken gebruiken dan `fill()` om de URL in te vullen.

### B. Database mode fix in install.sh
- `create_update_script`: als `INSTALL_MODE=database`, genereer een update-script dat alleen `git pull` in infra doet + `docker compose restart` — geen frontend rebuild.
- Of: sla `create_update_script` over in database mode.

### C. Split mode migraties fix in handleiding
- Server A: voeg instructie toe om de app-repo te clonen (alleen voor migraties), of geef een alternatief commando dat de SQL direct van Server B kopieert via scp.

### D. Vereenvoudig clone-instructies
Van:
```bash
sudo mkdir -p /opt/lovable-infra
sudo chown $USER:$USER /opt/lovable-infra
git clone https://... /opt/lovable-infra
```
Naar:
```bash
git clone https://... /opt/lovable-infra
```

### E. Na-installatie: verwijs naar credentials.txt
Vervang `JOUW_ANON_KEY` placeholder door:
```bash
# Je Anon Key vind je in:
cat /opt/supabase/credentials.txt | grep "Anon Key"
```

### F. Migraties idempotent maken
Voeg `--single-transaction` toe en track welke migraties al gedraaid zijn via een simpele marker-file, of gebruik `IF NOT EXISTS` hint in de documentatie.

---

## Bestanden

| Bestand | Wijziging |
|---|---|
| `src/routes/handleiding.tsx` | InfraUrl veld toevoegen, clone-stappen vereenvoudigen, na-installatie credentials.txt referentie, split Server A migratie-fix |
| `install.sh` | Database mode: skip of pas create_update_script aan |
| `update.sh` | Migraties: track al-gedraaide migraties |
| `INSTALL.md` | Clone-stappen vereenvoudigen, placeholder URL aanpassen |

