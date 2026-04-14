

## Plan: Fix SSH-check false negative in install.sh

### Probleem

`ssh -T git@github.com` retourneert **altijd exit code 1** — ook bij succesvolle authenticatie. Door `set -euo pipefail` bovenaan het script wordt de exit code van `ssh` (1) doorgepropageerd door de pipe, waardoor `grep -q` wel matcht maar de pipe toch exit code 1 retourneert. Resultaat: de SSH-check faalt altijd, zelfs als de verbinding werkt.

### Oplossing

Vang de output op in een variabele in plaats van een pipe te gebruiken:

```bash
local ssh_output
ssh_output=$(ssh -T -o ConnectTimeout=10 git@github.com 2>&1 || true)
if ! echo "$ssh_output" | grep -q "successfully authenticated"; then
```

De `|| true` voorkomt dat `set -e` het script afbreekt bij exit code 1 van ssh.

### Wijzigingen

| Bestand | Actie |
|---------|-------|
| `install.sh` | Regel 203: SSH-check herschrijven met variabele + `\|\| true` |
| `src/routes/handleiding.tsx` | Embedded `installScript` string updaten met dezelfde fix |

