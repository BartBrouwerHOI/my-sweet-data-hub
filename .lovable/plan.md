

## Plan: Invulvelden bovenaan de handleiding voor automatische commando's

### Idee

Bovenaan de handleiding komen invulvelden waar je je eigen gegevens invult. Alle commando's en links in de hele handleiding worden automatisch bijgewerkt met jouw waarden, zodat je ze direct kunt kopiëren en plakken zonder iets te vervangen.

### Invulvelden

| Veld | Placeholder | Voorbeeld |
|------|------------|-----------|
| GitHub gebruikersnaam | `JOUW-USER` | `jandevries` |
| Repository naam | `JOUW-REPO` | `mijn-app` |
| Server IP | `JOUW-SERVER-IP` | `192.168.1.100` |
| Domeinnaam | `jouw-domein.nl` | `mijnapp.nl` |
| Server A IP (split mode) | `SERVER_A_IP` | `192.168.1.101` |

### Hoe het werkt

1. **State toevoegen** — `useState` voor elk veld, standaard leeg
2. **Invulformulier** — compact formulier boven de inhoudsopgave met labels en input-velden. Waarden worden opgeslagen in `localStorage` zodat ze bewaard blijven bij pagina-refresh
3. **Template functie** — een `fill(text)` helper die alle placeholders vervangt door de ingevulde waarden. Als een veld leeg is, blijft de placeholder staan (bijv. `JOUW-USER`)
4. **CodeBlock updaten** — `CodeBlock` en `CopyCode` renderen de `fill()`-versie van hun content. De kopieerknop kopieert ook de ingevulde versie
5. **~60 plekken** in de handleiding waar placeholders voorkomen worden automatisch bijgewerkt (geen handmatige vervangingen nodig — het gaat via de `fill()` functie)

### Visueel

```text
┌─────────────────────────────────────────┐
│ 🔧 Jouw gegevens                        │
│                                         │
│ GitHub user:  [jandevries    ]           │
│ Repo naam:    [mijn-app      ]           │
│ Server IP:    [192.168.1.100 ]           │
│ Domein:       [mijnapp.nl    ]           │
│                                         │
│ 💡 Vul je gegevens in — alle commando's │
│    worden automatisch aangepast.         │
└─────────────────────────────────────────┘
```

### Bestand

| Bestand | Actie |
|---------|-------|
| `src/routes/handleiding.tsx` | State + localStorage + invulformulier + `fill()` helper + doorvoeren in CodeBlock/CopyCode |

