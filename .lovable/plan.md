

## Analyse: huidige staat

De werkwijze is nu goed en logisch. Scripts en handleiding zijn gesynchroniseerd. Er zijn nog **4 kleine problemen**:

### Gevonden problemen

**1. install.sh: database mode Nginx config is overbodig**
In database mode (regel 514-526) wordt een Nginx config aangemaakt die alleen `{"status":"ok"}` teruggeeft. Maar de beheerder heeft ook al Nginx als dependency geïnstalleerd (regel 166). In database mode is Nginx niet nodig — Kong (poort 8000) handelt alles af. Dit is verwarrend: waarom draait er een webserver die niets doet?

Twee opties:
- A) Skip Nginx installatie + config helemaal in database mode
- B) Laat het, want het doet geen kwaad en SSL voor Studio is handig

**Aanbeveling:** Laat het staan — het is nuttig als health-check endpoint en voor eventuele SSL op Studio later. Geen actie nodig.

**2. install.sh: `sleep 15` na `start_supabase()` (regel 440)**
Hardcoded sleep is fragiel. Beter: een poll-loop die wacht tot de database daadwerkelijk klaar is. Maar dit is een minor improvement, niet een bug.

**3. Handleiding: Server B codeblok bevat commentaar dat niet kopieerbaar is**
Regel 484-488 in handleiding.tsx — het codeblok voor Server B bevat:
```
# Kies: 3) Alleen frontend
# Voer de SSH URL van je APP-repo in: ...
# Voer het IP-adres van Server A in wanneer gevraagd
# Voer de Anon Key in die je bij Server A hebt genoteerd
```
Dit zijn instructies vermomd als commentaar in een kopieerbaar blok. Als de beheerder dit blok kopieert en plakt, worden de comments mee-geplakt. Beter: verplaats deze instructies naar gewone tekst ONDER het codeblok, en houd het codeblok clean (alleen de daadwerkelijke commando's).

**4. Handleiding: `<ANON_KEY>` placeholder in na-installatie is inconsistent**
Bij "API testen" staat `curl ... -H "apikey: <ANON_KEY>"`. De `<ANON_KEY>` wordt NIET vervangen door de `fill()` functie (die vervangt alleen `JOUW-SERVER-IP`, `APP-USER` etc.). Dit is bewust (de beheerder moet de key uit credentials.txt halen), maar de handleiding legt dit niet uit bij de eerste keer dat het voorkomt. Een korte uitleg zou helpen.

---

## Plan: fixes

### A. Handleiding: Server B codeblok opschonen
- Verplaats de 4 commentaarregels uit het codeblok naar een `<ul>` eronder
- Codeblok bevat alleen de 3 daadwerkelijke commando's

### B. Handleiding: verduidelijk `<ANON_KEY>` bij eerste gebruik
- De tekst "Kopieer de Anon Key uit de output hierboven en plak die in het volgende commando" staat er al. Dit is voldoende — geen wijziging nodig.

### C. install.sh: `sleep 15` vervangen door poll-loop
- Vervang de hardcoded sleep door een loop die `pg_isready` checkt (max 30 seconden)

**Conclusie:** Alleen 2 kleine wijzigingen nodig.

---

## Bestanden

| Bestand | Wijziging |
|---|---|
| `src/routes/handleiding.tsx` | Server B codeblok: verplaats instructie-comments naar tekst |
| `install.sh` | Vervang `sleep 15` door `pg_isready` poll-loop |

