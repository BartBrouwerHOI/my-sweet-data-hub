
## Wat de log nu aantoont

De oorspronkelijke DB-health bug is opgelost:
- `supabase-db` wordt healthy
- alle Supabase services starten
- bootstrap-checks slagen
- migraties draaien nu strikt en stoppen op de eerste echte fout

De huidige blokkades zijn nu andere, duidelijk afgebakende problemen:

1. **App-migratie faalt**
   - `20260119083612_fc4680d3-4321-408e-ac77-817040a08a81.sql`
   - probeert een `user_roles` record te inserten voor een hardcoded `user_id`
   - die `user_id` bestaat niet in `profiles`
   - dit is seed/dev-data in de app-repo, niet een infra/bootstrap-probleem

2. **Installer meldt ten onrechte “installatie compleet”**
   - `run_migrations()` faalt wel, maar `main()` stopt daarna niet
   - daardoor lopen frontend/Nginx/firewall/summary alsnog door
   - dat is misleidend, want de backend is dan functioneel onvolledig

3. **IP-adres wordt behandeld als domeinnaam**
   - in de log is `192.168.200.185` ingevuld bij “Domeinnaam”
   - `setup_ssl()` probeert daarom Let’s Encrypt op een IP aan te vragen
   - daarna toont de summary ook `https://192.168.200.185`, wat fout/misleidend is

## Plan

### 1. Fix de echte blocker in de app-repo
Ik pas in **Access-Guardian** de migratie `20260119083612_fc4680d3-4321-408e-ac77-817040a08a81.sql` aan zodat die geen harde FK-fout meer veroorzaakt.

Aanpak:
- hardcoded admin/seed insert conditioneel maken via `WHERE EXISTS (...)`
- of dev-seed volledig verwijderen als die niet in productie thuishoort
- checken of dezelfde UUID of vergelijkbare seed-inserts nog in andere migraties voorkomen

Voorbeeld richting:
```sql
INSERT INTO user_roles (user_id, role)
SELECT 'fa761b51-9489-4289-917b-d1818f3cd508', 'admin'
WHERE EXISTS (
  SELECT 1 FROM profiles WHERE id = 'fa761b51-9489-4289-917b-d1818f3cd508'
);
```

### 2. `install.sh` correct laten falen bij mislukte migraties
Ik maak de installer transactioneel op flow-niveau:
- `run_migrations` moet een non-zero status teruggeven bij fout
- `main()` moet dan stoppen vóór `start_frontend`, `configure_nginx`, `setup_ssl`, `configure_firewall`, `print_summary`
- de eindsamenvatting moet alleen verschijnen als de installatie echt geslaagd is

Effect:
- geen “✅ INSTALLATIE COMPLEET!” meer bij een kapotte migratie
- gebruiker ziet direct dat de app-repo eerst gefixt moet worden

### 3. IP en domeinnaam robuust onderscheiden
Ik pas de input- en URL-logica aan zodat:
- een IPv4/IPv6 invoer bij het domeinveld automatisch als **geen domeinnaam** wordt behandeld
- SSL dan wordt overgeslagen
- de summary `http://IP` toont in plaats van `https://IP`
- dezelfde logica wordt gebruikt in:
  - `.env` URL’s
  - frontend build env
  - SSL setup
  - eindsamenvatting

### 4. Duidelijkere validatie en messaging in installer
Ik verbeter de prompts en meldingen:
- bij `Domeinnaam` expliciet aangeven: “voer hier géén IP-adres in”
- als toch een IP wordt ingevuld: waarschuwing tonen en automatisch naar IP-modus schakelen
- bij migratiefout expliciet melden: “infra is gezond, maar app-migratie blokkeert afronding”

### 5. Handleiding/documentatie bijwerken
Ik werk de docs/handleiding bij zodat ze overeenkomen met het echte gedrag:
- domeinnaam optioneel, IP = geen SSL
- Let’s Encrypt werkt alleen met een echte DNS-naam
- installatie is pas voltooid als migraties slagen
- bij mislukte migratie: fix in app-repo en daarna `lovable-update`

## Bestanden

| Bestand | Wijziging |
|---|---|
| `install.sh` | Stoppen bij migratiefout, IP-vs-domein detectie, correcte URL/SSL/summary |
| `src/routes/handleiding.tsx` | Tekst verduidelijken over domeinnaam/IP en migratie-fouten |
| `INSTALL.md` of `docs/PROJECT.md` | Korte troubleshooting/notitie over IP en SSL |
| `Access-Guardian/supabase/migrations/20260119083612_fc4680d3-4321-408e-ac77-817040a08a81.sql` | Hardcoded seed insert conditioneel maken of verwijderen |

## Technische details

- Ik voeg een helper toe voor “is dit een IP-adres?”
- Alle URL-beslissingen gaan via één centrale helper, zodat `setup_supabase`, `build_frontend`, `setup_ssl` en `print_summary` consistent blijven
- `main()` krijgt strikte flow-control, zodat mislukte migraties de installatie echt aborten
- De app-migratie blijft inhoudelijk in de **app-repo**, niet in deze infra-repo

## Verwacht resultaat

Na deze ronde:
- de installer geeft geen vals succes meer
- IP-gebaseerde installs tonen correcte `http://...` output en proberen geen certificaat meer aan te vragen
- de enige resterende blocker wordt netjes opgelost in de app-repo
- daarna kan `lovable-update` de resterende migraties afronden zonder handmatig gepruts
