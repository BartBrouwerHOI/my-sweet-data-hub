

## Plan: Fix git clone commando's — SSH key probleem oplossen

### Probleem (zichtbaar in screenshot)

Alle drie de methoden falen:
- `sudo -u $USER git clone ... /opt/lovable-app` → Permission denied (kan niet schrijven naar `/opt/`)
- `git clone ... /tmp/lovable-app && sudo mv` → Repository not found (SSH key config issue)
- `sudo git clone` → Permission denied (publickey) — root heeft geen SSH key

### Oplossing

Twee stappen: eerst directory aanmaken met `sudo`, dan clonen als gewone gebruiker:

```bash
# Maak de map aan en geef jezelf rechten
sudo mkdir -p /opt/lovable-app
sudo chown $USER:$USER /opt/lovable-app

# Clone als huidige gebruiker (die de SSH key heeft)
git clone git@github.com:JOUW-USER/JOUW-REPO.git /opt/lovable-app

# Start de installer
cd /opt/lovable-app
sudo bash install.sh
```

### Wijzigingen in `src/routes/handleiding.tsx`

1. **Single mode** (regel 333-339): Vervang `sudo git clone` door de `mkdir + chown + git clone` aanpak
2. **Split mode Server A** (regel 363-364): Zelfde fix
3. **Split mode Server B** (regel 398-399): Zelfde fix
4. **Verwijder** het voorbeeld-commentaar (`# Voorbeeld: sudo git clone...`) — de invulvelden maken dit overbodig
5. **Voeg een Warn toe** die uitlegt: "Gebruik NIET `sudo git clone` — sudo draait als root en heeft geen toegang tot jouw SSH key"

### Bestand

| Bestand | Actie |
|---------|-------|
| `src/routes/handleiding.tsx` | Clone-commando's aanpassen op 3 plekken + waarschuwing toevoegen |

