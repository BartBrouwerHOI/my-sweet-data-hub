

## Plan

De URL's en paden onderaan de installer-summary (App URL, Studio, Infra, App, Updates) staan in `${BLUE}` — donkerblauw op een zwarte terminal is onleesbaar.

### Wijziging

In `install.sh`, regels 1031-1042: vervang alle `${BLUE}` door `${YELLOW}` in de summary-output na de credentials. `YELLOW` is al gedefinieerd op regel 18.

| Bestand | Wijziging |
|---|---|
| `install.sh` | Regels 1031-1042: `${BLUE}` → `${YELLOW}` voor App URL, Studio, Infra, App, Updates |

