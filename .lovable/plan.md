

## Plan: Privé repo fix + betere fallback voor install.sh

### Probleem 1: curl fallback werkt niet voor privé repo's

De handleiding suggereert `curl -O https://raw.githubusercontent.com/...` als fallback, maar dit werkt **alleen voor publieke repo's**. Jouw repo (BartBrouwerHOI/Access-Guardian) is privé — curl haalt dan een 404-pagina op (14 bytes).

### Probleem 2: install.sh ontbreekt in de GitHub repo

De Lovable sync staat op "Connected" maar het bestand is niet in de repo gepusht. Dit kan komen doordat de sync bepaalde bestanden overslaat, of doordat er een sync-probleem is.

### Oplossing

**In `src/routes/handleiding.tsx`:**

1. **Curl fallback vervangen** door instructies die werken voor privé repo's:
   - Optie A: Gebruik `curl` met een GitHub Personal Access Token (PAT) voor privé repo's
   - Optie B: Kopieer het script handmatig — toon een "Kopieer install.sh" knop op de handleiding-pagina zelf die de volledige inhoud van `install.sh` toont/kopieert
   - Optie C: Gebruik `gh` CLI (GitHub CLI) die al geauthenticeerd kan zijn

2. **"Sync troubleshooting" blok uitbreiden** met concrete stappen:
   - Controleer of de Lovable sync daadwerkelijk bestanden pusht (kijk naar recente commits op GitHub)
   - Als install.sh ontbreekt: disconnect en reconnect de GitHub connector
   - Als dat niet werkt: gebruik de handmatige kopie-optie

3. **Volledige inhoud van install.sh beschikbaar maken** op de handleiding-pagina via een expandable/collapsible sectie, zodat gebruikers het altijd handmatig kunnen kopiëren — onafhankelijk van GitHub sync of repo-toegang.

### Wijzigingen

| Bestand | Actie |
|---------|-------|
| `src/routes/handleiding.tsx` | Curl fallback updaten voor privé repos (3 plekken); expandable "install.sh handmatig kopiëren" sectie toevoegen |

### Details

**Curl met token (voor privé repos):**
```bash
curl -H "Authorization: token JOUW_GITHUB_TOKEN" -O https://raw.githubusercontent.com/JOUW-USER/JOUW-REPO/main/install.sh
```

**Fallback volgorde (nieuw):**
1. Controleer of install.sh in de repo staat (GitHub website)
2. Zo niet: disconnect/reconnect Lovable GitHub sync
3. Zo niet: kopieer install.sh handmatig vanaf de handleiding-pagina (collapsible code block met de volledige inhoud van install.sh)
4. Of gebruik curl met een Personal Access Token voor privé repos

