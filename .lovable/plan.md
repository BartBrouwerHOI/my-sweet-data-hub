

## Analyse: huidige staat

Na het doorlopen van alle bestanden is de werkwijze nu grotendeels logisch en goed kopieerbaar. Er zijn nog **7 concrete problemen** die de beheerderservaring verstoren:

### Gevonden problemen

**1. Volgorde vragen install.sh is onlogisch voor database mode**
In database mode vraagt het script eerst `gather_input()` (domein, email, wachtwoorden), daarna pas "Wil je de app-repo clonen?" (regel 820-829), en pas DAN `clone_app()` die om de GitHub URL vraagt. De beheerder krijgt de vragen in een vreemde volgorde: wachtwoord → clone ja/nee → repo URL. Beter: alle vragen eerst, dan alle acties.

**2. Database mode: `setup_supabase()` gebruikt `$APP_DIR/supabase/migrations` (regel 369)**
Als de beheerder "nee" zegt bij "clone voor migraties?", bestaat `$APP_DIR` niet. `setup_supabase()` doet `cp "$APP_DIR/supabase/migrations/"*.sql` — dit faalt niet (door `|| true`), maar het is rommelig. Geen fout, maar onnodig verwarrend in de logs.

**3. Frontend mode: `create_update_script()` genereert update-script met migratie-logica (stap 5/5)**
In frontend mode is er geen database — toch bevat het gegenereerde `lovable-update` script migratie-stappen die naar `/opt/supabase` verwijzen. Die map bestaat niet op een frontend-only server. Het werkt (dankzij `-d` checks) maar is verwarrend output.

**4. `print_summary()` toont `Project Type:` ook in database mode (regel 758)**
In database mode is `$PROJECT_TYPE` leeg — de output toont `Type: ` met een lege waarde. Ziet er kapot uit.

**5. Handleiding split mode: Server A "deploy key" is onnodig als je "nee" zegt bij migraties**
De handleiding zegt "herhaal deze stap op beide servers" voor de deploy key. Maar als de beheerder op Server A "nee" zegt bij "app-repo clonen voor migraties?", dan is er geen deploy key nodig op Server A. De handleiding zou dit conditioneel moeten vermelden.

**6. `credentials.txt` bevat `App Dir: /opt/lovable-app` ook in database mode zonder clone**
Als de beheerder geen app-repo cloned, staat er toch `App Dir: /opt/lovable-app` in credentials.txt — misleidend.

**7. Handleiding: "Na installatie" sectie heeft geen instructie voor wanneer iets NIET werkt**
De checks (`docker ps`, `curl`) worden getoond, maar er staat niet wat je moet doen als `docker ps` 0 containers toont of `curl` faalt. Een simpele "Werkt het niet? Zie Troubleshooting" link zou helpen.

---

## Plan: fixes

### A. install.sh: volgorde verbeteren
- Verplaats de "wil je app-repo clonen?" vraag naar `gather_input()`, zodat alle vragen bij elkaar staan
- Sla het resultaat op in een variabele `CLONE_FOR_MIGRATIONS`
- De daadwerkelijke clone gebeurt later op dezelfde plek (regel 816+)

### B. install.sh: `print_summary()` fix voor database mode
- Verberg de `Type:` regel als `$PROJECT_TYPE` leeg is
- Verberg `App Dir:` in `credentials.txt` als er geen app-dir is

### C. install.sh: frontend mode update-script zonder migraties
- Splits `create_update_script()` in drie varianten: full (5 stappen), database (4 stappen), frontend (3 stappen — geen migraties)

### D. Handleiding: deploy key conditioneel voor split mode
- Bij split mode: vermeld dat Server A alleen een deploy key nodig heeft als je migraties wilt draaien

### E. Handleiding: "Werkt het niet?" link na de checks
- Voeg onder elk na-installatie blok een korte zin toe: "Werkt iets niet? Zie stap X (Troubleshooting)."

---

## Bestanden

| Bestand | Wijziging |
|---|---|
| `install.sh` | Volgorde vragen verbeteren, print_summary leeg type fixen, frontend update-script zonder migraties, credentials.txt conditioneel |
| `src/routes/handleiding.tsx` | Deploy key conditioneel bij split, "werkt het niet?" link bij na-installatie |

