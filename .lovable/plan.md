

## Plan: SSH-check toevoegen aan install.sh + duidelijkere foutmelding

### Probleem

De screenshot toont `Permission denied (publickey)` tijdens het uitvoeren van `install.sh`. Het script's `clone_app` functie probeert `git clone git@github.com:...` maar faalt omdat:
1. De deploy key niet (correct) is ingesteld, of
2. De SSH config niet naar de juiste key wijst

Het script geeft geen duidelijke foutmelding en de gebruiker weet niet wat er mis is.

### Wijzigingen

| Bestand | Actie |
|---------|-------|
| `install.sh` | SSH-connectiviteitscheck toevoegen vóór `git clone` in `clone_app()` |
| `src/routes/handleiding.tsx` | (1) Waarschuwing toevoegen bij InstallShMissing dat deploy key alsnog nodig is; (2) De embedded `installScript` string in InstallShMissing updaten met dezelfde SSH-check |

### Detail: `install.sh` — `clone_app()` functie

Vóór de `git clone` regel, een SSH-test toevoegen:

```bash
clone_app() {
  log_info "App clonen van GitHub..."
  if [[ -d "$APP_DIR" && -f "$APP_DIR/docker-compose.yml" ]]; then
    log_info "App directory bestaat al, git pull uitvoeren..."
    cd "$APP_DIR" && git pull
  else
    read -p "GitHub repo URL (SSH, bijv. git@github.com:user/repo.git): " GITHUB_REPO

    # Test SSH-verbinding met GitHub vóór clone
    log_info "SSH-verbinding met GitHub testen..."
    if ! ssh -T -o ConnectTimeout=10 git@github.com 2>&1 | grep -q "successfully authenticated"; then
      log_error "SSH-verbinding met GitHub mislukt!"
      echo ""
      echo "  Mogelijke oorzaken:"
      echo "  1. Geen deploy key aangemaakt — voer uit: ssh-keygen -t ed25519 -C deploy@vps -f ~/.ssh/deploy_key -N \"\""
      echo "  2. Deploy key niet toegevoegd aan GitHub repo → Settings → Deploy keys"
      echo "  3. SSH config ontbreekt — maak ~/.ssh/config aan met:"
      echo "     Host github.com"
      echo "       IdentityFile ~/.ssh/deploy_key"
      echo "       IdentitiesOnly yes"
      echo ""
      echo "  Test handmatig: ssh -T git@github.com"
      echo ""
      read -p "Wil je toch doorgaan met clonen? (j/n): " confirm
      [[ "$confirm" != "j" ]] && exit 1
    fi

    git clone "$GITHUB_REPO" "$APP_DIR"
  fi
}
```

### Detail: `src/routes/handleiding.tsx`

1. In de `InstallShMissing` component, een extra waarschuwing toevoegen:
   > **Let op:** Ook als je install.sh handmatig hebt aangemaakt, vraagt het script om je GitHub repo URL en probeert het te clonen via SSH. Zorg dat je de **deploy key stap** hierboven eerst hebt uitgevoerd.

2. De embedded `installScript` string in dezelfde component updaten met de SSH-check zodat de handmatig gekopieerde versie ook de betere foutmelding bevat.

