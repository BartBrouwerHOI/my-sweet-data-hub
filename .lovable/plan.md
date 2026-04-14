

## Plan: docker-compose.yml check toevoegen aan install.sh

### Probleem
Na een succesvolle `git clone` crasht `setup_supabase()` met `cp: cannot stat` als `docker-compose.yml` om welke reden dan ook niet in de repo zit. Daarnaast draait de gebruiker mogelijk een oudere versie van `install.sh` die niet overeenkomt met de repo-versie.

### Aanpak

#### 1. `install.sh` — check in `setup_supabase()`
Vóór het `cp` commando controleren of het bestand bestaat:

```bash
if [[ ! -f "$APP_DIR/docker-compose.yml" ]]; then
  log_error "docker-compose.yml niet gevonden in $APP_DIR"
  log_error "Controleer of je repo dit bestand bevat."
  exit 1
fi
```

#### 2. `install.sh` — self-update mechanisme
Na succesvolle clone/pull, als de repo een nieuwere `install.sh` bevat, het lopende script vervangen door de repo-versie en opnieuw starten:

```bash
# Na clone/pull in clone_app():
if [[ -f "$APP_DIR/install.sh" ]]; then
  cp "$APP_DIR/install.sh" /usr/local/bin/lovable-install
  chmod +x /usr/local/bin/lovable-install
  log_info "install.sh bijgewerkt vanuit repo."
  # Herstart met de nieuwe versie als die verschilt
  if ! cmp -s "$0" "$APP_DIR/install.sh"; then
    log_info "Nieuwere versie gevonden, herstart met bijgewerkte installer..."
    exec bash "$APP_DIR/install.sh" "$@"
  fi
fi
```

#### 3. `src/routes/handleiding.tsx` — embedded script synchroniseren
De embedded `installScript` string bijwerken met dezelfde checks.

### Bestanden
| Bestand | Actie |
|---|---|
| `install.sh` | Bestandscheck vóór cp + self-update na clone |
| `src/routes/handleiding.tsx` | Embedded script synchroniseren |

### Directe oplossing voor nu
De gebruiker kan nu al verder met:
```bash
cd ~
sudo bash /opt/lovable-app/install.sh
```

