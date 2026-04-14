
## Architectuur — Universele Deployment Toolkit

Dit project is de **infrastructuur-laag** voor het deployen van elk Lovable-project op een VPS.

```text
/opt/lovable-infra/          ← DIT project (installer, Supabase stack, Dockerfiles)
  ├── install.sh             ← Hoofdinstaller (v3.0)
  ├── update.sh              ← Fallback naar lovable-update
  ├── docker-compose.yml     ← Supabase stack
  ├── volumes/kong/kong.yml  ← API gateway config
  ├── Dockerfile.spa         ← Multi-stage: node build → nginx serve
  ├── Dockerfile.ssr         ← Multi-stage: node build → node server
  ├── nginx/frontend-spa.conf ← SPA fallback (try_files → index.html)
  ├── nginx/frontend-ssr.conf ← SSR reverse proxy (proxy_pass → :3000)
  └── src/routes/handleiding.tsx ← Interactieve handleiding

/opt/lovable-app/             ← Het DOEL-project (elk Lovable-project)
  ├── src/
  ├── package.json
  └── ...
```

### Projecttype detectie
- **SPA**: `package.json` bevat GEEN `@tanstack/react-start` → `Dockerfile.spa`
- **SSR**: `package.json` bevat `@tanstack/react-start` → `Dockerfile.ssr`

### Installatie flow
1. Gebruiker cloned infra-repo naar `/opt/lovable-infra`
2. `sudo bash /opt/lovable-infra/install.sh`
3. Script vraagt om app-repo URL en cloned naar `/opt/lovable-app`
4. Automatische detectie SPA/SSR
5. Build met juiste Dockerfile, Supabase stack uit infra-repo
6. `lovable-update` commando aangemaakt voor toekomstige updates
