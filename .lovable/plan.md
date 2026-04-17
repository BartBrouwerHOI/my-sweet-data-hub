

## Wat de gebruiker vraagt

"Wat kan ik aan de app-repo (Access-Guardian) doorgeven over wat **wij** (infra) doen en wat **zij** (app) moeten doen?" — dus: een duidelijk contract / handover-document dat de app-developer kan lezen om hun migraties + scripts correct te maken.

## Antwoord-strategie

Ik geef een kant-en-klare **"Contract voor app-repo's"** tekst die je 1-op-1 kunt doorsturen of in de Access-Guardian README/docs kunt plakken. Geen code-wijzigingen nodig — dit is puur communicatie.

Daarnaast bied ik aan om dit contract als markdown-bestand (`docs/APP-CONTRACT.md`) in deze infra-repo te zetten zodat het altijd vindbaar is en je er gewoon naar kunt linken.

## Inhoud van het contract (samenvatting)

**Wat de infra-repo (`my-sweet-data-hub`) regelt:**
- Postgres, Auth (GoTrue), PostgREST, Kong, Storage, Realtime
- Docker, Nginx, SSL (Let's Encrypt), Firewall
- Frontend build (SPA of SSR autodetect)
- Migratie-runner (`supabase/migrations/*.sql` op alfabetische volgorde)
- Tracking via `.migrations_done/` (geen dubbel draaien)
- Aanroep van `$APP_DIR/scripts/bootstrap.sh` + `lovable-update.sh` als die bestaan

**Wat de app-repo (Access-Guardian) zelf moet regelen:**
1. **Idempotente migraties** — geen hardcoded user_ids, gebruik `IF NOT EXISTS`, `ON CONFLICT DO NOTHING`, `WHERE EXISTS (...)` guards
2. **Geen FK-violations op verse DB** — een verse install heeft géén users/profiles; seed-data moet defensief zijn of in een aparte seed-migratie die alleen draait als de tabel leeg is
3. **Eerste-admin-pattern** — gebruik een trigger op `auth.users` (eerste user wordt admin) i.p.v. hardcoded ID
4. **Edge functions setup** in `scripts/bootstrap.sh` (eenmalig: edge-runtime container, Kong-route, secrets)
5. **Edge functions sync** in `scripts/lovable-update.sh` (recurring: code sync + restart)
6. **Geen hardcoded URLs naar Lovable Cloud** — gebruik `VITE_SUPABASE_URL` env-var
7. **App-secrets** in `scripts/bootstrap.sh` (vraag interactief of lees uit env)

## Wijzigingen

| Bestand | Wijziging |
|---|---|
| `docs/APP-CONTRACT.md` (nieuw) | Volledig contract: wat infra doet, wat app moet doen, do's & don'ts voor migraties, scripts-conventie, voorbeelden van defensieve SQL-patterns |
| `INSTALL.md` | Korte verwijzing toevoegen: "Bouw je een app-repo die hierop draait? Lees `docs/APP-CONTRACT.md`" |
| `src/routes/handleiding.tsx` | Link naar het contract in de troubleshooting-sectie + nieuwe FAQ "Mijn migratie faalt op verse DB" |

## Resultaat

Je hebt één URL die je naar Access-Guardian (of welke andere Lovable-app dan ook) kunt sturen: `github.com/.../my-sweet-data-hub/blob/main/docs/APP-CONTRACT.md`. Daar staat exact wat zij moeten leveren zodat hun app probleemloos op onze infra draait — inclusief het soort fix dat de zojuist gefaalde migratie nodig heeft.

