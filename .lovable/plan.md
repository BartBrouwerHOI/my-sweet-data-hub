

## Plan: Handleiding verduidelijken — twee repo's, twee deploy keys

### Probleem
De handleiding heeft nu één set GitHub-velden (`JOUW-USER`/`JOUW-REPO`) maar er zijn **twee** repo's nodig:
1. **Infra-repo** — dit project (installer, docker-compose, Dockerfiles)
2. **App-repo** — het Lovable-project dat je wilt deployen (bijv. Access Guardian)

De deploy key stap noemt ook maar één repo, terwijl beide repo's een deploy key nodig hebben (of dezelfde key moet aan beide worden toegevoegd).

### Aanpassingen

#### 1. Config-formulier: aparte velden voor infra en app
Huidige velden `githubUser` + `repoName` worden vervangen door:
- **Infra-repo** — `infraUser` + `infraRepo` (met standaardwaarde dit project)
- **App-repo** — `appUser` + `appRepo` (het project dat je wilt deployen)

De `fill()` functie krijgt nieuwe placeholders: `INFRA-USER`, `INFRA-REPO`, `APP-USER`, `APP-REPO`.

#### 2. Deploy key stap: uitleggen dat beide repo's toegang nodig hebben
- Eén SSH key genereren (zoals nu)
- Die key toevoegen aan **beide** GitHub repo's (infra + app)
- Of: als het dezelfde GitHub-eigenaar is, een personal access token gebruiken (optioneel tip)

#### 3. Installatie stap: duidelijke twee-staps flow
```text
Stap 1: Clone de INFRA-repo
  git clone git@github.com:INFRA-USER/INFRA-REPO.git /opt/lovable-infra

Stap 2: Start de installer
  sudo bash /opt/lovable-infra/install.sh

  → Het script vraagt om de SSH URL van je APP-repo
  → Voorbeeld: git@github.com:APP-USER/APP-REPO.git
```

Met duidelijke labels welke URL van welk project is.

#### 4. Architectuur diagram: expliciete twee-repo structuur
Het bestaande diagram al updaten zodat het laat zien:
```text
/opt/lovable-infra/  ← INFRA-repo (installer, Dockerfiles, Supabase stack)
/opt/lovable-app/    ← APP-repo (jouw Lovable project, bijv. Access Guardian)
```

### Bestanden
| Bestand | Actie |
|---|---|
| `src/routes/handleiding.tsx` | Config-formulier splitsen, deploy key stap uitbreiden, installatie stappen verduidelijken |

