

## Plan: SMTP & OAuth sectie verduidelijken (verplicht vs optioneel)

### Probleem

De SMTP- en OAuth-stap staan nu als één blok, zonder duidelijk onderscheid tussen wat **noodzakelijk** is en wat **optioneel** is. Dit is verwarrend.

### Analyse

- **SMTP**: Noodzakelijk voor productie — zonder SMTP staat autoconfirm aan (onveilig)
- **Google OAuth**: Optioneel — alleen nodig als je "Inloggen met Google" wilt aanbieden. De app werkt prima met alleen e-mail/wachtwoord login

### Wijzigingen in `src/routes/handleiding.tsx`

1. **SMTP sectie**: Markeren als "Aanbevolen voor productie" met een duidelijke waarschuwing dat het onveilig is zonder
2. **Google OAuth sectie**: Toevoegen van een duidelijke zin bovenaan: _"Dit is optioneel. Als je app geen Google-login nodig heeft, kun je deze stap overslaan en doorgaan naar de volgende stap."_
3. Visueel onderscheid: OAuth-blok in een apart kader zetten met een "Optioneel" badge, zodat het er anders uitziet dan de verplichte stappen
4. Eventueel de stap-titel splitsen: "SMTP instellen" als hoofdtitel, en "Google OAuth" als sub-sectie met optioneel-label

### Bestand

| Bestand | Actie |
|---------|-------|
| `src/routes/handleiding.tsx` | SMTP/OAuth sectie herstructureren met verplicht/optioneel labels |

