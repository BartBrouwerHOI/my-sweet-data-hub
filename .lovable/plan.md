

## Plan: Alle secties labelen als verplicht/aanbevolen/optioneel

### Analyse — wat zou een specialist opmerken?

| Sectie | Huidige status | Probleem |
|--------|---------------|----------|
| Vereisten | Geen label | OK — impliciet verplicht |
| Architectuur | Geen label | OK — uitleg, geen actie |
| Deploy key | Geen label | Moet "Verplicht" badge krijgen — zonder dit werkt niets |
| Installatie | Geen label | Moet "Verplicht" badge |
| Na installatie | Geen label | Moet "Verplicht" — verificatiestap |
| Updates | Geen label | Moet "Wanneer nodig" label — alleen na wijzigingen |
| **Data migratie** | **Geen label** | **Moet "Optioneel" — alleen als je bestaande data hebt in Lovable Cloud** |
| SMTP | "Aanbevolen voor productie" ✓ | OK |
| OAuth | "Optioneel" ✓ | OK |
| Troubleshooting | Geen label | OK — naslagwerk |
| **Backup** | **Geen label** | **Database backup = Aanbevolen, Auto-cron + Storage backup = Optioneel** |

### Wat een specialist zou zeggen

1. **Data migratie** staat als gewone stap — een beginner denkt dat dit verplicht is. Moet duidelijk zeggen: "Sla deze stap over als je een nieuwe app start zonder bestaande data."
2. **Backup sectie** mist prioriteit — database backup is essentieel, maar de cron en storage-backup zijn nice-to-have. Onderscheid ontbreekt.
3. **Single vs Split keuze** — er staat geen advies wanneer welke optie geschikt is. Een beginner weet niet wat te kiezen.
4. **Updates sectie** — lijkt verplicht maar is alleen relevant na wijzigingen. Moet "Wanneer nodig" label.

### Wijzigingen

1. **Data migratie**: "Optioneel" badge + intro-zin: "Alleen als je bestaande data hebt in Lovable Cloud. Start je een nieuwe app? Sla deze stap over."
2. **Backup sectie**: Database dump krijgt "Aanbevolen" badge. Cron en Storage backup krijgen "Optioneel" sub-labels.
3. **Mode toggle**: Korte aanbeveling toevoegen: "Twijfel je? Kies Single server — je kunt later altijd splitsen."
4. **Updates**: "Wanneer nodig" label toevoegen met uitleg dat dit alleen na Lovable-wijzigingen hoeft.
5. **Deploy key + Installatie + Na installatie**: Subtiele "Verplicht" badge zodat de flow duidelijk is.

### Bestand

| Bestand | Actie |
|---------|-------|
| `src/routes/handleiding.tsx` | Labels toevoegen aan Data migratie, Backup, Updates, mode-toggle advies, en verplicht-badges bij kernstappen |

