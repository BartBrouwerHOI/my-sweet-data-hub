

## Plan: Info-tooltips toevoegen aan technische termen

### Wat wordt gebouwd

Een `InfoTooltip` component dat bij technische termen een ℹ️-icoon toont. Bij hover verschijnt een korte uitleg. Dit maakt de handleiding begrijpelijk voor leken zonder de tekst te vervuilen met lange uitleg.

### Technisch

- Nieuw component `InfoTooltip` in `handleiding.tsx` — simpele CSS hover tooltip (geen extra dependency nodig)
- Inline `<InfoTooltip term="..." />` naast technische begrippen

### Waar komen tooltips

| Term | Uitleg in tooltip |
|------|-------------------|
| SSH | Veilige verbinding met je server op afstand, zoals remote desktop maar dan via tekst |
| Deploy key | Een SSH-sleutel die alleen leesrechten heeft op één specifieke GitHub repo |
| Docker / Docker container | Software die in een afgesloten "doos" draait, zodat het overal hetzelfde werkt |
| Docker Compose | Tool om meerdere Docker containers tegelijk te starten met één configuratiebestand |
| Nginx | Webserver die bezoekers doorstuurt naar de juiste service (reverse proxy) |
| Kong | API Gateway — controleert of API-verzoeken een geldige sleutel hebben |
| SSL / Let's Encrypt | Versleutelde verbinding (https), gratis via Let's Encrypt |
| PostgreSQL | De database waar al je data in wordt opgeslagen |
| GoTrue | Supabase service die login, registratie en wachtwoord-reset regelt |
| PostgREST | Zet je database automatisch om naar een REST API |
| Anon Key | Publieke sleutel waarmee de frontend met de Supabase API praat |
| Service Role Key | Geheime sleutel met volledige database-toegang — nooit in de frontend gebruiken |
| JWT | Token (digitaal pasje) waarmee een gebruiker bewijst dat hij ingelogd is |
| Firewall / UFW | Bepaalt welke poorten open of dicht staan op je server |
| SMTP | Protocol voor het versturen van e-mails (verificatie, wachtwoord-reset) |
| OAuth | Inloggen via een derde partij zoals Google |
| Cron | Geplande taken die automatisch draaien op vaste tijden |
| pg_dump | PostgreSQL commando om een volledige backup van je database te maken |
| SCP | Bestanden kopiëren tussen je computer en een server via SSH |
| Reverse proxy | Nginx stuurt verkeer door naar de juiste service op basis van de URL |

### Component design

```tsx
function InfoTooltip({ text }: { text: string }) {
  return (
    <span className="relative inline-flex group cursor-help">
      <Info className="h-3.5 w-3.5 text-muted-foreground/60 hover:text-primary" />
      <span className="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 
        hidden group-hover:block w-56 rounded-md border bg-popover p-2 
        text-xs text-popover-foreground shadow-md z-50">
        {text}
      </span>
    </span>
  );
}
```

### Bestanden

| Bestand | Actie |
|---------|-------|
| `src/routes/handleiding.tsx` | `InfoTooltip` component toevoegen + ~20 tooltips plaatsen bij technische termen door de hele handleiding |

