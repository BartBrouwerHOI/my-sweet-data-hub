

## Plan: Verbeterde SSH troubleshooting en verificatie toevoegen

### Kernprobleem

"Repository not found" ≠ "geen toegang tot de server". Het betekent: SSH-authenticatie slaagt, maar met een key die **geen toegang heeft tot deze specifieke repo**. De handleiding mist verificatiestappen tussen "key aanmaken" en "clone uitvoeren".

### Wijzigingen in `src/routes/handleiding.tsx`

**1. Verificatiestap uitbreiden na SSH config (regel 323-325)**

De huidige "Test de verbinding" (`ssh -T git@github.com`) is te summier. Uitbreiden met:

```bash
# Test de verbinding — controleer welke key wordt gebruikt
ssh -vT git@github.com 2>&1 | grep "Offering\|authenticated"

# Als het niet werkt, forceer de deploy key:
ssh -T -i ~/.ssh/deploy_key git@github.com
```

**2. Warn toevoegen na de test** met uitleg over veelvoorkomende fouten:

| Foutmelding | Betekenis | Oplossing |
|-------------|-----------|-----------|
| "Repository not found" | SSH werkt, maar de key heeft geen toegang tot deze repo | Controleer of de deploy key aan de **juiste repo** is toegevoegd op GitHub |
| "Permission denied (publickey)" | SSH kan helemaal niet authenticeren | De key is niet gevonden — controleer `~/.ssh/config` |
| "Hi USERNAME! You've successfully authenticated" | Alles werkt | Ga door naar de clone stap |

**3. Tip toevoegen over bestaande SSH keys**

Als de gebruiker al een `~/.ssh/id_ed25519` of `id_rsa` heeft, kan SSH die prefereren boven `deploy_key`. De `IdentitiesOnly yes` in de config moet dit voorkomen, maar voeg een expliciete check toe:

```bash
# Controleer of er al andere SSH keys bestaan
ls ~/.ssh/*.pub
```

Met uitleg: "Als je hier meerdere keys ziet, zorg dat `IdentitiesOnly yes` in je config staat — anders kan SSH de verkeerde key pakken."

**4. chmod toevoegen voor de deploy key zelf (regel 299-303)**

Na het genereren van de key:
```bash
chmod 600 ~/.ssh/deploy_key
```
Sommige SSH-versies weigeren keys met te brede permissions.

### Bestand

| Bestand | Actie |
|---------|-------|
| `src/routes/handleiding.tsx` | Verificatiestappen uitbreiden, troubleshooting tabel toevoegen, chmod fix, waarschuwing over meerdere keys |

