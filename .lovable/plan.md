

## Plan: Handleiding herstructureren + technische fixes

### Probleem 1: Handleiding is verwarrend
Single-server en split-server stappen staan door elkaar. De gebruiker moet eerst kiezen en dan alleen relevante stappen zien.

### Probleem 2: Technische fouten in de deployment stack

Na onderzoek heb ik deze kritische fouten gevonden:

**A. Dockerfile klopt niet voor TanStack Start**
Het project gebruikt TanStack Start (SSR framework), maar de Dockerfile behandelt het als een statische site. TanStack Start bouwt naar `dist/` (client + server bundles), niet `.output/public`. Het is een Node.js server, geen statische Nginx site. De Dockerfile moet de app als Node.js process draaien, niet via Nginx.

**B. Nginx full-mode slaat Kong over**
In full-mode proxy't Nginx rechtstreeks naar individuele services (poort 9999, 3001, 4000, 5000). Dit omzeilt Kong's API key validatie — een beveiligingsprobleem. Alle API-calls moeten via Kong (poort 8000) lopen.

**C. Frontend container zit niet in het Docker netwerk**
De frontend draait als losse `docker run`, niet in docker-compose. Daardoor kan het geen services bereiken via containernamen. Dit moet opgelost worden door de frontend aan het docker-compose netwerk toe te voegen, of alles via localhost+ports te doen (wat nu al deels gebeurt).

### Oplossing

**1. Handleiding herstructureren met keuze-UI**
- Bovenaan een toggle: "Single server" / "Split setup"
- React state bepaalt welke stappen zichtbaar zijn
- Gedeelde stappen (vereisten, deploy key, updates, backup) altijd zichtbaar
- Single-specifieke stap: "Installatie" (één blok)
- Split-specifieke stappen: "Server A (backend)" en "Server B (frontend)" apart
- Inhoudsopgave past zich aan op basis van keuze

**2. Dockerfile fixen**
- TanStack Start draait als Node.js server, niet als statische Nginx site
- Build output in `dist/`, start met `node dist/server/index.mjs` (of via het start script)
- Alternatief: als het project puur client-side rendering doet (geen SSR server functions), dan kan het wel als statische site, maar dan moet de build output path kloppen

**3. Nginx config fixen (full mode)**
- Alle Supabase API calls via Kong (poort 8000) routeren in plaats van individuele poorten
- Consistent met hoe split-mode al werkt

**4. Kleinere verbeteringen**
- Kopieer-knop toevoegen aan codeblokken
- Stappen nummering dynamisch maken op basis van keuze
- Warning toevoegen dat SMTP moet geconfigureerd worden voor e-mail verificatie (nu staat `GOTRUE_MAILER_AUTOCONFIRM: true` wat onveilig is in productie)

### Bestanden

| Bestand | Actie |
|---------|-------|
| `src/routes/handleiding.tsx` | Herstructureren met single/split toggle + dynamische stappen |
| `Dockerfile` | Fixen voor TanStack Start (Node.js server i.p.v. statische Nginx) |
| `nginx/frontend.conf` | Aanpassen als reverse proxy naar Node.js app |
| `install.sh` | Nginx full-mode fixen: API via Kong |

