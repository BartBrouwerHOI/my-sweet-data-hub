

## Doel

Eén commando dat **alles** doet: infra + app + edge functions + secrets. Geen handmatige clones, geen tweede script.

## Voorgestelde flow

```bash
curl -fsSL https://raw.githubusercontent.com/BartBrouwerHOI/my-sweet-data-hub/main/bootstrap.sh | sudo bash
```

Dat is het. De rest is interactief (paar prompts: domein, e-mail, app-repo URL).

## Hoe het werkt onder water

```text
bootstrap.sh (curl-pipe, ~20 regels)
  ├─ installeert git als die ontbreekt
  ├─ git clone infra-repo → /opt/lovable-infra
  └─ exec /opt/lovable-infra/install.sh

install.sh (bestaand, generiek)
  ├─ vraagt: modus, domein, e-mail, wachtwoord, app-repo URL
  ├─ installeert: docker, nginx, certbot
  ├─ zet Supabase stack neer (Postgres, Auth, Kong, Storage, Realtime)
  ├─ cloned app-repo → /opt/lovable-app
  ├─ bouwt frontend container (SPA of SSR auto-detect)
  ├─ draait migraties uit app-repo
  └─ NIEUW: detecteert app-eigen scripts en draait ze automatisch
       ├─ als $APP_DIR/scripts/bootstrap.sh bestaat → draaien
       └─ als $APP_DIR/scripts/lovable-update.sh bestaat → draaien
       (edge functions, app-secrets, cronjobs — alles app-eigen)
```

## Waarom dit schoon blijft

| Verantwoordelijkheid | Waar |
|---|---|
| Docker, Nginx, SSL, Supabase stack | **infra-repo** (generiek) |
| Frontend build templates (Dockerfile, nginx.conf) | **infra-repo** (generiek) |
| Edge functions code, app-secrets, cronjobs | **app-repo** (`scripts/`) |
| Aanroepen van app-scripts | **infra-repo** detecteert + draait |

Onze installer hardcodeert **geen** Access-Guardian URLs. Hij kijkt alleen of `$APP_DIR/scripts/bootstrap.sh` of `$APP_DIR/scripts/lovable-update.sh` bestaat. Werkt dus voor élke app die deze conventie volgt.

## Wijzigingen

| Bestand | Wijziging |
|---|---|
| `bootstrap.sh` (nieuw, repo-root) | ~20 regels: git installeren, infra-repo clonen, `install.sh` aanroepen |
| `install.sh` | Aan het eind (na "INSTALLATIE COMPLEET"): detecteer `$APP_DIR/scripts/bootstrap.sh` en `lovable-update.sh`, vraag bevestiging "Nu app-specifieke setup draaien? [Y/n]", draai ze |
| `update.sh` + gegenereerde `/usr/local/bin/lovable-update` | Idem: na infra+app update, als `$APP_DIR/scripts/lovable-update.sh` bestaat → automatisch aanroepen |
| `INSTALL.md` | Eén-commando install bovenaan als primaire flow; oude 2-staps blijft als fallback |
| `src/routes/handleiding.tsx` | Eén-commando install tonen; oude flow als "geavanceerd" inklapbaar |

## Resultaat voor de gebruiker

**Voor:** clone infra → install.sh → handmatig bootstrap.sh van app → handmatig lovable-update.sh van app = **4 commando's**

**Na:** `curl ... | sudo bash` → paar prompts beantwoorden → één bevestiging "edge functions ook installeren? Y" = **1 commando + interactie**

Bij elke toekomstige update geldt hetzelfde: `lovable-update` doet infra + app + edge functions in één klap.

