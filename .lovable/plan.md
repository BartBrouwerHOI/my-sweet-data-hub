

## Analyse

De handleiding gaat ervan uit dat de gebruiker als `root` is ingelogd (`ssh root@JOUW-SERVER-IP`), maar in de praktijk loggen veel beheerders in als een gewone gebruiker. Daardoor falen commando's die schrijven naar `/opt/` of Docker aanroepen.

**Commando's die `sudo` missen in `handleiding.tsx`:**

| Regel | Commando | Probleem |
|-------|----------|----------|
| 409 | `git clone ... /opt/lovable-infra` | Schrijft naar `/opt/` |
| 440-441 | `git clone ... /opt/lovable-infra` (Server A) | Idem |
| 479-480 | `git clone ... /opt/lovable-infra` (Server B) | Idem |
| 501-502 | `docker ps` | Docker vereist sudo of groepslidmaatschap |
| 505 | `curl -I http://localhost:3000` | OK, geen sudo nodig |
| 508 | `cat /opt/supabase/credentials.txt` | Bestand is `chmod 600` owned by root |
| 511-512 | `curl ... -H "apikey: ..."` | OK |
| 523-524 | `docker ps` (split) | Docker |
| 527 | `cat /opt/supabase/credentials.txt` (split) | chmod 600 |
| 530-531 | `curl ...` | OK |
| 536-538 | `docker ps`, `curl` (Server B) | Docker |
| 554-555 | `lovable-update` | Draait docker + git pull in /opt/ |
| 567-568 | `lovable-update` (split frontend) | Idem |
| 572-573 | `lovable-update` (split backend) | Idem |
| 636 | `cd /opt/supabase && docker compose restart auth` | Docker + /opt/ |
| 670 | `cd /opt/supabase && docker compose restart auth` | Idem |
| 704-714 | Backup: `docker exec ...`, `pg_dump`, restore | Docker |
| 730-731 | `tar -czf ... /opt/supabase/...` | Leest /opt/ |

## Plan

### Bestand: `src/routes/handleiding.tsx`

Alle bovenstaande commando's krijgen `sudo` prefix waar nodig:

- `git clone ... /opt/lovable-infra` → `sudo git clone ... /opt/lovable-infra`
- `docker ps` → `sudo docker ps`
- `cat /opt/supabase/credentials.txt` → `sudo cat /opt/supabase/credentials.txt`
- `lovable-update` → `sudo lovable-update`
- `cd /opt/supabase && docker compose restart auth` → `cd /opt/supabase && sudo docker compose restart auth`
- Backup `docker exec` commando's → `sudo docker exec`
- `tar -czf` → `sudo tar -czf`

Totaal: ~15 commando's aanpassen in de handleiding.

### Bestand: `update.sh`

Geen wijzigingen nodig — `update.sh` gebruikt al `docker` en `git` commando's die als root draaien (het wordt aangeroepen via `sudo lovable-update`).

