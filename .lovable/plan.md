

## Wijziging

De `infraUrl` in de handleiding standaard vullen met `https://github.com/BartBrouwerHOI/my-sweet-data-hub` zodat gebruikers dit niet handmatig hoeven in te typen.

## Aanpak

**Bestand:** `src/routes/handleiding.tsx`

In de `useState` initialisatie (regel 25) en de `useEffect` migratie (regel 40), de default waarde van `infraUrl` wijzigen van `""` naar `"https://github.com/BartBrouwerHOI/my-sweet-data-hub"`.

Zo wordt het veld altijd vooringevuld, tenzij de gebruiker het eerder heeft overschreven in localStorage.

