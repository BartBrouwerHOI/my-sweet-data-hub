

## Plan: Waarschuwingsblok leesbaarder maken

### Probleem

De gele waarschuwing onderaan de "install.sh handmatig kopiëren" sectie (regel 1208-1210) gebruikt `text-yellow-200` — dat is bijna wit op een lichtgele achtergrond, waardoor het onleesbaar is.

### Oplossing

**In `src/routes/handleiding.tsx` (regel 1208):**

Verander de styling van het gele waarschuwingsblok naar donkerdere, leesbare kleuren:

- `text-yellow-200` → `text-foreground` (past bij het thema)
- `bg-yellow-500/10` → `bg-yellow-500/10` (behouden)
- `border-yellow-500/30` → `border-yellow-500/30` (behouden)
- De `<strong>` en `<code>` elementen erven dan automatisch leesbare kleuren

### Wijzigingen

| Bestand | Actie |
|---------|-------|
| `src/routes/handleiding.tsx` | Regel 1208: `text-yellow-200` vervangen door `text-foreground` zodat de tekst leesbaar is op zowel licht als donker thema |

