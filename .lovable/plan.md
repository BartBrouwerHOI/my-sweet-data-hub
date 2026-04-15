

## Analyse: Waarom werkt login nog steeds niet?

### Wat ik gevonden heb in de Access Guardian app

1. **`src/integrations/supabase/client.ts`** leest `import.meta.env.VITE_SUPABASE_URL` en `import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY` — geen hardcoded URLs, goed.
2. **`.env`** in de app-repo bevat Lovable Cloud waarden: `wupvrwoquyyhgsrtcbpm.supabase.co`
3. Geen `.dockerignore` — `.env.production` wordt meegenomen in de Docker build
4. Vite gebruikt `.env.production` boven `.env` bij productie-builds

### Het mechanisme is correct — maar werkt het in de praktijk?

De `write_env_production()` in `update.sh` schrijft `.env.production` vóór `docker build`. Vite zou dit moeten oppikken. **Maar de kans is groot dat `.app_env` niet goed is aangemaakt op de server** — het `$(grep ...)` commando in de heredoc kan verkeerd zijn geëvalueerd.

### Wat er moet gebeuren — twee kanten

#### Kant 1: Deze infra-repo (kleine verbeteringen)

1. **Verificatiestap toevoegen aan `update.sh`** — na `write_env_production()` een check printen die laat zien welke URL wordt gebruikt, zodat de gebruiker direct ziet of de juiste waarden worden ingebakken
2. **Fallback in `write_env_production()`** — als `.app_env` niet bestaat, direct uit `/opt/supabase/.env` lezen als fallback (voor het geval `.app_env` niet is aangemaakt)

#### Kant 2: Access Guardian app-repo (coördinatie)

De Access Guardian app hoeft **niet** te worden aangepast — de `client.ts` leest al uit env vars. Het probleem zit niet in de code maar in de deployment-pipeline.

De `npm run local:setup` scripts die het Access Guardian team voorstelt zijn nuttig voor **lokale ontwikkeling**, maar lossen het productie-probleem niet op. Dat wordt opgelost door de infra-repo.

### Concrete wijzigingen in deze repo

**`update.sh`:**

1. `write_env_production()` uitbreiden met een fallback die direct `/opt/supabase/.env` leest als `.app_env` ontbreekt:
```bash
write_env_production() {
  local api_url=""
  local anon_key=""

  if [[ -f "$INFRA_DIR/.app_env" ]]; then
    source "$INFRA_DIR/.app_env"
    api_url="$APP_API_URL"
    anon_key="$APP_ANON_KEY"
  elif [[ -f "$SUPABASE_DIR/.env" ]]; then
    # Fallback: lees direct uit Supabase .env
    anon_key=$(grep "^ANON_KEY=" "$SUPABASE_DIR/.env" | cut -d= -f2-)
    # URL afleiden uit install_mode marker of domein
    if [[ -f "$INFRA_DIR/.app_domain" ]]; then
      api_url="https://$(cat "$INFRA_DIR/.app_domain")"
    else
      api_url="http://$(curl -sf ifconfig.me 2>/dev/null || echo localhost)"
    fi
  fi

  if [[ -n "$api_url" && -n "$anon_key" ]]; then
    cat > "$APP_DIR/.env.production" <<EOF
VITE_SUPABASE_URL=$api_url
VITE_SUPABASE_ANON_KEY=$anon_key
VITE_SUPABASE_PUBLISHABLE_KEY=$anon_key
EOF
    echo "  .env.production → $api_url"
  else
    echo "  ⚠️  Kan .env.production niet schrijven — .app_env en .env ontbreken"
  fi
}
```

2. **Domein opslaan bij installatie** — `install.sh` moet het domein bewaren in `.app_domain` zodat de fallback werkt

3. **Verificatie na build** — een `echo` toevoegen die de gebruikte Supabase URL toont

### Resultaat

- `.env.production` wordt altijd correct geschreven, ook als `.app_env` niet handmatig is aangemaakt
- De Access Guardian app hoeft niet aangepast te worden — env vars werken al
- De gebruiker ziet in de terminal welke Supabase URL wordt ingebakken

### Wat je het Access Guardian team kunt vertellen

> De `client.ts` is al correct opgezet met env vars. Het probleem is dat `.env.production` niet goed werd geschreven op de server. De infra-repo krijgt nu een robuustere fallback. Na `git pull` van de infra + `lovable-update --app-only` zou login moeten werken. Jullie `npm run local:setup` scripts zijn een goed idee voor lokale ontwikkeling, maar los van het productie-probleem.

