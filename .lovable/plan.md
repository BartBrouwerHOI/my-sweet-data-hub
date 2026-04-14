

## Probleem

Migratie `20260119083612` faalt omdat het een `INSERT INTO user_roles` doet met een hardcoded `user_id` (`fa761b51-...`) die niet in `profiles` bestaat. Dit is seed-data uit development die niet op een schone productie-database werkt.

## Goede nieuws

De database is **healthy**, alle Supabase services draaien, en 22 van de ~50 migraties zijn succesvol uitgevoerd. Alleen deze ene migratie blokkeert de rest.

## Aanpak

### 1. Fix de migratie in de app-repo

De migratie `20260119083612_fc4680d3-4321-408e-ac77-817040a08a81.sql` bevat waarschijnlijk iets als:
```sql
INSERT INTO user_roles (user_id, role) VALUES ('fa761b51-...', 'admin');
```

Dit moet conditioneel worden:
```sql
INSERT INTO user_roles (user_id, role)
SELECT 'fa761b51-...', 'admin'
WHERE EXISTS (SELECT 1 FROM profiles WHERE id = 'fa761b51-...');
```

Of helemaal verwijderd als het puur development seed-data is.

### 2. Opnieuw draaien

Na de fix in de app-repo:
```bash
cd /opt/lovable-app && git pull
lovable-update
```

De migratie-runner pakt alleen de niet-voltooide migraties op (alles vanaf `20260119083612`).

## Bestanden

| Bestand | Wijziging |
|---|---|
| `supabase/migrations/20260119083612_fc4680d3-4321-408e-ac77-817040a08a81.sql` | INSERT conditioneel maken of seed-data verwijderen |

## Alternatief (sneller, geen code-wijziging)

Als je niet wilt wachten op een code-push, kun je op de VPS handmatig de INSERT-regel overslaan:
1. Open de migratie: `nano /opt/lovable-app/supabase/migrations/20260119083612_fc4680d3-4321-408e-ac77-817040a08a81.sql`
2. Verwijder of comment de `INSERT INTO user_roles` regel met de hardcoded UUID
3. Draai `lovable-update`

