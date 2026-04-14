

## Plan: Kopieerknop altijd zichtbaar + inline code klikbaar maken

### Probleem

De `CodeBlock` component heeft al een kopieerknop, maar die is alleen zichtbaar bij hover (`opacity-0 group-hover:opacity-100`). Op mobiel werkt hover niet, en ook op desktop is het niet duidelijk dat je kunt kopiëren. Daarnaast zijn er ~47 inline `<code>` elementen (zoals `mijnapp.nl`, `JOUW-USER`, etc.) die niet kopieerbaar zijn.

### Wijzigingen in `src/routes/handleiding.tsx`

1. **CodeBlock kopieerknop altijd zichtbaar maken** — verwijder `opacity-0 group-hover:opacity-100`, maak de knop permanent zichtbaar met subtiele styling
2. **Inline `<code>` klikbaar maken** — nieuw `CopyCode` component dat bij klik de tekst kopieert en kort "Gekopieerd!" feedback toont (via een kleine tooltip of kleurflash). Vervangt de huidige `<code className="rounded bg-muted...">` elementen
3. **Cursor aanpassen** — `cursor-pointer` op kopieerbare elementen zodat duidelijk is dat je kunt klikken

### Technisch

```text
CopyCode component:
- Rendert <code> met cursor-pointer + hover-effect
- Bij klik: navigator.clipboard.writeText(children)
- Kort visueel feedback (achtergrond flash of ✓ icoon)

CodeBlock wijziging:
- Kopieerknop: opacity altijd 100
- Optioneel: "Klik om te kopiëren" tooltip bij hover
```

### Bestand

| Bestand | Actie |
|---------|-------|
| `src/routes/handleiding.tsx` | `CopyCode` component toevoegen, `CodeBlock` knop altijd tonen, ~47 inline `<code>` elementen vervangen door `<CopyCode>` |

