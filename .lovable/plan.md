

## Plan: Dit project als universele deployment-toolkit

### Idee
In plaats van deployment-bestanden naar elk project te kopiëren, wordt dit project de **infrastructuur-laag** die elk Lovable-project kan deployen. De app-code wordt apart gecloned.

### Architectuur

```text
/opt/lovable-infra/          ← DIT project (installer, docker-compose, kong, etc.)
  ├── install.sh
  ├── update.sh
  ├── docker-compose.yml
  ├── volumes/kong/kong.yml
  ├── Dockerfile.spa          ← voor Vite/React SPA projecten
  ├── Dockerfile.ssr          ← voor TanStack Start projecten
  ├── nginx/frontend-spa.conf
  ├── nginx/frontend-ssr.conf
  └── src/routes/handleiding.tsx

/opt/lovable-app/             ← Het DOEL-project (Access Guardian, of elk ander)
  ├── src/
  ├── package.json
  └── ...
```

### Wat verandert in `install.sh`

1. **Twee aparte clone-stappen**:
   - Infra-repo → `/opt/lovable-infra/` (dit project, bevat installer + Supabase stack)
   - App-repo → `/opt/lovable-app/` (het gebruikersproject, alleen app-code)

2. **Projecttype detectie**:
   - Installer kijkt of het doel-project een SPA of SSR app is
   - SPA: `vite.config.ts` zonder TanStack Start → `Dockerfile.spa` + `nginx/frontend-spa.conf`
   - SSR: TanStack Start aanwezig → `Dockerfile.ssr` + `nginx/frontend-ssr.conf`

3. **Build gebruikt Dockerfile uit infra-repo**:
   ```bash
   docker build -t lovable-frontend -f /opt/lovable-infra/Dockerfile.spa /opt/lovable-app
   ```

4. **Supabase stack draait vanuit infra-repo**:
   ```bash
   cd /opt/lovable-infra && docker compose up -d
   ```

### Wat verandert in de handleiding

- Gebruiker hoeft alleen de **app-repo URL** in te vullen
- Infra-repo URL is hardcoded in het script (dit project)
- Stap: "Welk type project? SPA / SSR" of automatische detectie

### Voordelen
- Elk Lovable-project is deployable zonder extra bestanden
- Infra-updates (security, nieuwe Supabase versie) hoeven maar op één plek
- Handleiding blijft centraal in dit project

### Bestanden te wijzigen/maken

| Bestand | Actie |
|---|---|
| `install.sh` | Opsplitsen in infra-clone + app-clone, projecttype detectie |
| `Dockerfile` | Hernoemen naar `Dockerfile.ssr`, nieuwe `Dockerfile.spa` maken |
| `nginx/frontend.conf` | Splitsen in `frontend-spa.conf` en `frontend-ssr.conf` |
| `update.sh` | Aanpassen: git pull in app-dir, rebuild met infra Dockerfile |
| `src/routes/handleiding.tsx` | Instructies aanpassen voor twee-repo model |
| `docker-compose.yml` | Blijft, geen wijzigingen |
| `volumes/kong/kong.yml` | Blijft, geen wijzigingen |

