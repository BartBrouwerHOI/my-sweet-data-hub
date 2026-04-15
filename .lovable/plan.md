

## Probleem

De "⚠️ INSTALLATIE DEELS VOLTOOID" sectie (regels 1098-1144) toont alleen credentials en `Updates: lovable-update`, maar mist de App URL, Studio, Infra en App regels. Die staan alleen in `print_summary()` die wordt overgeslagen bij migratiefout.

## Plan

### 1. URL's en paden toevoegen aan het failure-pad

In `install.sh`, regels 1140-1143: vóór de `Updates` regel, dezelfde URL/pad-regels toevoegen als in `print_summary()`:

```bash
    # Na credentials, vóór Updates:
    echo ""
    local url="${PROTOCOL}://${DOMAIN}"
    if [[ "$INSTALL_MODE" != "database" ]]; then
      echo -e "  🌐 App URL: ${YELLOW}$url${NC}"
    fi
    if [[ "$INSTALL_MODE" != "frontend" ]]; then
      echo -e "  📊 Studio:  ${YELLOW}$url:8080${NC}"
    fi
    echo ""
    echo -e "  📂 Infra:   ${YELLOW}$INFRA_DIR${NC}"
    if [[ -d "$APP_DIR/.git" ]]; then
      echo -e "  📂 App:     ${YELLOW}$APP_DIR${NC}"
    fi
    echo -e "  🔄 Updates: ${YELLOW}lovable-update${NC}"
```

### 2. Fix `${BLUE}` op regel 1109 en 1142

Regels 1109 (`Volgende stappen`) en 1142 (`lovable-update`) gebruiken nog `${BLUE}` → vervangen door `${YELLOW}`.

| Bestand | Wijziging |
|---|---|
| `install.sh` | Regels 1109, 1140-1143: URL's/paden toevoegen + `${BLUE}` → `${YELLOW}` |

