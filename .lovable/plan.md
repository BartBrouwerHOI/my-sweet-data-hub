

## Migratie-patch toevoegen aan install.sh en update.sh

### Probleem

Migratie `20260119083612_fc4680d3-...` bevat een harde `INSERT INTO user_roles` met een UUID die alleen in Lovable Cloud bestaat. Op verse self-hosted installaties faalt deze migratie en stopt de runner — een nieuwe "fix"-migratie erna wordt nooit bereikt.

Access Guardian kan het originele migratiebestand niet wijzigen (read-only in Lovable). De infra-repo moet het bestand **on-the-fly patchen** vóór het draaien van migraties.

### Oplossing

Een `patch_known_migrations()` functie toevoegen die vóór `run_migrations()` / `run_strict_migrations()` wordt aangeroepen. Deze functie vervangt de bekende problematische INSERT met de conditionele variant, direct in het geclonede bestand op disk.

### Concrete wijziging

**Nieuwe functie** (in beide `install.sh` en `update.sh`):

```bash
patch_known_migrations() {
  local target="$APP_DIR/supabase/migrations/20260119083612_fc4680d3-4321-408e-ac77-817040a08a81.sql"
  if [[ -f "$target" ]] && grep -q "VALUES ('fa761b51-" "$target"; then
    echo "  Migratie-patch: conditionele super_admin INSERT"
    sed -i "s|INSERT INTO user_roles (user_id, role).*VALUES.*('fa761b51-9489-4289-917b-d1818f3cd508'.*|INSERT INTO user_roles (user_id, role) SELECT 'fa761b51-9489-4289-917b-d1818f3cd508', 'super_admin'::app_role WHERE EXISTS (SELECT 1 FROM public.profiles WHERE id = 'fa761b51-9489-4289-917b-d1818f3cd508') ON CONFLICT (user_id, role) DO NOTHING;|" "$target"
  fi
}
```

**Aanroepen:**
- `install.sh`: vóór `run_migrations()` (rond regel 494)
- `update.sh`: vóór `run_strict_migrations()` in alle drie de modi (database, frontend, full)

### Bestanden

| Bestand | Wijziging |
|---------|-----------|
| `install.sh` | `patch_known_migrations()` functie + aanroep vóór migraties |
| `update.sh` | Zelfde functie + aanroep vóór elke `run_strict_migrations()` |

### Resultaat

- Verse self-hosted installaties draaien foutloos door
- Bestaande installaties (waar de migratie al is gedraaid) worden niet geraakt
- Het originele migratiebestand in de app-repo hoeft niet aangepast te worden
- De patch is idempotent — draait alleen als het bekende patroon aanwezig is

