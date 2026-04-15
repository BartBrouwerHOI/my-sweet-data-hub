

## Situatie

De Access-Guardian app is geüpdatet naar v1.5.2 met een nieuwe migratie die rollen automatisch toekent. Maar op de server staat nog de oude mislukte migratie `20260119083612` in `/opt/supabase/.migrations_done/` als "niet gedaan", waardoor `lovable-update` daar elke keer op vastloopt.

De oplossing is tweeledig:

1. **Nu op de server**: markeer de oude migratie als gedaan en draai de update
2. **In de infra-repo**: voeg een `--mark-done` flag toe aan de updater zodat dit in de toekomst makkelijker is

## Plan

### 1. Directe fix — draai dit op de server

```bash
# Markeer de oude kapotte migratie als "gedaan" (skip)
sudo touch /opt/supabase/.migrations_done/20260119083612_fc4680d3-4321-408e-ac77-817040a08a81.sql

# Draai nu de update — de nieuwe v1.5.2 migratie wordt wel uitgevoerd
sudo lovable-update
```

### 2. `--mark-done` flag toevoegen aan updater

Voeg aan zowel `install.sh` (`create_update_script`) als `update.sh` een nieuwe flag toe:

```bash
lovable-update --mark-done 20260119083612_fc4680d3-4321-408e-ac77-817040a08a81.sql
```

Dit doet alleen `touch $MIGRATIONS_DONE_DIR/<naam>` en stopt — geen pull, geen build.

| Bestand | Wijziging |
|---|---|
| `install.sh` | Flag `--mark-done <file>` toevoegen aan generated update script |
| `update.sh` | Zelfde flag in fallback script |
| `INSTALL.md` | Documentatie voor `--mark-done` |

### 3. GOTRUE_MAILER_AUTOCONFIRM

De app zegt dat `GOTRUE_MAILER_AUTOCONFIRM=true` in de `.env` moet staan. Dit is al standaard `true` in de Supabase docker-compose — maar ik verifieer dat en voeg een check toe aan `install.sh` zodat het altijd expliciet gezet wordt.

