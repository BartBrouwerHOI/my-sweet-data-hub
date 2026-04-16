

## Korte analyse

Je hebt twee scripts in de Access-Guardian repo:
- `scripts/bootstrap.sh` — voegt edge-runtime container toe aan docker-compose + Kong-route + secrets
- `scripts/lovable-update.sh` — sync't de functions code + restart

**Mijn advies:** Ja, dit kan, **maar één optimalisatie**: laat onze `install.sh` aan het eind detecteren of de app `supabase/functions/` heeft, en zo ja **automatisch deze twee commando's tonen** (of zelfs aanbieden te draaien). Dan hoeft de gebruiker niets te onthouden.

## Voorstel

### Wijziging in `install.sh` (één klein blok aan het eind)

Na de "INSTALLATIE COMPLEET" banner:

```bash
if [[ -d "$APP_DIR/supabase/functions" ]]; then
  echo ""
  echo "  ⚡ Edge functions gedetecteerd in je app."
  echo "     Draai deze 2 commando's om ze te activeren:"
  echo ""
  echo "     curl -fsSL https://raw.githubusercontent.com/BartBrouwerHOI/Access-Guardian/main/scripts/bootstrap.sh | sudo bash"
  echo "     sudo bash $APP_DIR/scripts/lovable-update.sh"
  echo ""
fi
```

### Waarom niet zelf inbouwen?

- `bootstrap.sh` injecteert een edge-runtime service met **Access-Guardian-specifieke secrets** (`ENCRYPTION_KEY`, `RESEND_API_KEY`, `TURNSTILE_SECRET_KEY`)
- `lovable-update.sh` weet welke functions er zijn en hoe ze gedeployed moeten worden
- Onze `install.sh` blijft **generiek/universeel** voor élk Lovable-project
- Scheiding: wij = infra, app-repo = app-specifieke deployment

### Wijziging in documentatie

| Bestand | Wijziging |
|---|---|
| `install.sh` | Detectie-blok aan het eind dat de 2 commando's toont als `supabase/functions/` bestaat |
| `INSTALL.md` | Nieuwe sectie "Edge Functions" met de 2 commando's en uitleg |

### Antwoord op je vraag

**Ja, deze twee commando's na onze install zijn correct en voldoende** voor Access-Guardian. Mijn enige toevoeging is dat we ze automatisch laten tonen aan het eind van onze installer — dan hoef je ze nooit meer op te zoeken.

