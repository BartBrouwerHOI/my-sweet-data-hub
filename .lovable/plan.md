

## Plan: Terminologie verduidelijken in handleiding

### Probleem
De handleiding noemt "database" en "Supabase" apart, wat verwarrend is. Supabase bevat de database + auth + API + storage.

### Aanpassing

In `src/routes/handleiding.tsx` de terminologie consistent maken:

- **Server A → "Backend-server"** (of "Supabase-server") — draait de volledige Supabase stack (PostgreSQL, Auth, API, Storage, Realtime)
- **Server B → "Frontend-server"** — draait alleen de React app + Nginx

Specifieke wijzigingen:
1. **Stap 2 (Architectuur kiezen)**: ASCII-diagrammen aanpassen — "Database-server" hernoemen naar "Supabase-server (backend)" met duidelijke opsomming dat PostgreSQL daar onderdeel van is
2. **Stap 5**: Titel wijzigen van "Split: Database-server" naar "Split: Supabase-server (backend)"
3. **Stap 6**: Verduidelijken dat de frontend alleen de React app is
4. **Inhoudsopgave**: Titels meenemen
5. Korte uitleg toevoegen bovenaan stap 2 over wat Supabase allemaal bevat (niet alleen database)

### Bestanden
| Bestand | Actie |
|---------|-------|
| `src/routes/handleiding.tsx` | Terminologie aanpassen in stap 2, 5, 6 en inhoudsopgave |

