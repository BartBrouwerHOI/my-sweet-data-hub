# 🚀 Lovable VPS Installatie Handleiding

## Vereisten

| Vereiste | Minimum |
|----------|---------|
| OS | Ubuntu 24.04 LTS |
| RAM | 4 GB |
| Opslag | 20 GB SSD |
| Netwerk | Publiek IP-adres |
| Domeinnaam | Aanbevolen (voor SSL) |

## Snelle Installatie (Eén Commando)

SSH naar je VPS en draai:

```bash
# Download en start het install-script
git clone https://github.com/JOUW-USER/JOUW-REPO.git /opt/lovable-app
cd /opt/lovable-app
sudo bash install.sh
```

Het script vraagt om:
- **GitHub repo URL** — de URL van je Lovable project repository
- **Domeinnaam** — je domein (of laat leeg voor IP-adres)
- **Admin e-mail** — voor SSL certificaten en notificaties
- **Database wachtwoord** — kies een sterk wachtwoord
- **Dashboard wachtwoord** — voor Supabase Studio toegang

## Wat wordt geïnstalleerd

| Component | Versie | Poort |
|-----------|--------|-------|
| PostgreSQL | 15.6 | 5432 |
| GoTrue (Auth) | v2.164 | 9999 |
| PostgREST (API) | v12.2 | 3001 |
| Realtime | v2.30 | 4000 |
| Storage | v1.11 | 5000 |
| Kong (API Gateway) | 2.8 | 8000 |
| Studio (Dashboard) | latest | 8080 |
| Frontend (Nginx) | latest | 3000 |
| Nginx (proxy) | system | 80/443 |

## Architectuur

```
Browser → Nginx (:80/:443)
            ├── / → Frontend container (:3000)
            ├── /auth/ → GoTrue (:9999)
            ├── /rest/ → PostgREST (:3001)
            ├── /realtime/ → Realtime (:4000)
            ├── /storage/ → Storage (:5000)
            └── /studio/ → Studio (:8080)
```

## Updates na Lovable Wijzigingen

Wanneer je wijzigingen maakt in Lovable (die automatisch naar GitHub pushen):

```bash
# Optie 1: Gebruik het update commando
lovable-update

# Optie 2: Handmatig
cd /opt/lovable-app
./update.sh
```

Dit doet:
1. `git pull` — haalt de laatste code op
2. Bouwt de frontend opnieuw
3. Herstart de frontend container
4. Draait eventuele nieuwe database migraties

**De database data blijft behouden** — alleen de frontend wordt opnieuw gebouwd.

## Data Migreren vanuit Lovable Cloud

### Stap 1: Database Schema Exporteren

Je database schema zit al in je GitHub repo onder `supabase/migrations/`. Het install-script draait deze automatisch.

### Stap 2: Data Exporteren

1. Ga naar **Lovable Cloud → Database → Tables**
2. Selecteer een tabel
3. Klik op **Export** (CSV)
4. Herhaal voor elke tabel

### Stap 3: Data Importeren

```bash
# Kopieer CSV naar de server
scp data.csv root@jouw-server:/tmp/

# Importeer in PostgreSQL
docker exec -i supabase-db psql -U supabase -d postgres -c "\COPY tabelnaam FROM '/tmp/data.csv' WITH CSV HEADER"
```

### Stap 4: Gebruikers

Gebruikerswachtwoorden kunnen **niet** geëxporteerd worden (ze zijn gehasht). Opties:
- Vraag gebruikers om een nieuw wachtwoord in te stellen via de "Wachtwoord vergeten" flow
- Of maak nieuwe accounts aan

## E-mail Configureren (SMTP)

Bewerk het `.env` bestand in `/opt/supabase/`:

```bash
nano /opt/supabase/.env
```

Vul de SMTP-instellingen in:
```
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=jouw-email@gmail.com
SMTP_PASS=jouw-app-wachtwoord
SMTP_SENDER_NAME=Mijn App
```

Herstart auth:
```bash
cd /opt/supabase && docker compose restart auth
```

## OAuth Providers (Google, Apple)

### Google Login

1. Ga naar [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Maak een OAuth 2.0 Client ID
3. Voeg je domein toe als Authorized redirect URI: `https://jouw-domein.nl/auth/v1/callback`
4. Bewerk `/opt/supabase/.env`:

```
GOTRUE_EXTERNAL_GOOGLE_ENABLED=true
GOTRUE_EXTERNAL_GOOGLE_CLIENT_ID=jouw-client-id
GOTRUE_EXTERNAL_GOOGLE_SECRET=jouw-secret
GOTRUE_EXTERNAL_GOOGLE_REDIRECT_URI=https://jouw-domein.nl/auth/v1/callback
```

5. Herstart: `cd /opt/supabase && docker compose restart auth`

## Troubleshooting

### Services controleren

```bash
# Alle containers bekijken
docker ps

# Logs van een specifieke service
docker logs supabase-db
docker logs supabase-auth
docker logs lovable-frontend

# Alle Supabase logs
cd /opt/supabase && docker compose logs -f
```

### Database connectie testen

```bash
docker exec -it supabase-db psql -U supabase -d postgres -c "SELECT 1"
```

### Frontend opnieuw bouwen

```bash
cd /opt/lovable-app
docker build -t lovable-frontend -f Dockerfile .
docker restart lovable-frontend
```

### SSL vernieuwen

```bash
certbot renew
```

Certbot installeert automatisch een cron job voor vernieuwing.

### Alles opnieuw starten

```bash
cd /opt/supabase && docker compose restart
docker restart lovable-frontend
systemctl restart nginx
```

## Bestandslocaties

| Wat | Waar |
|-----|------|
| App code | `/opt/lovable-app/` |
| Supabase config | `/opt/supabase/` |
| Database data | `/opt/supabase/volumes/db/data/` |
| Storage bestanden | `/opt/supabase/volumes/storage/` |
| Nginx config | `/etc/nginx/sites-available/lovable` |
| Credentials | `/opt/supabase/credentials.txt` |
| Env variabelen | `/opt/supabase/.env` |

## Backup

### Database backup

```bash
docker exec supabase-db pg_dump -U supabase postgres > backup_$(date +%Y%m%d).sql
```

### Volledig backup

```bash
# Database + storage + config
tar czf lovable-backup_$(date +%Y%m%d).tar.gz /opt/supabase/volumes/ /opt/supabase/.env
```

### Restore

```bash
# Database
docker exec -i supabase-db psql -U supabase -d postgres < backup_20240101.sql

# Volledig
tar xzf lovable-backup_20240101.tar.gz -C /
cd /opt/supabase && docker compose restart
```

## Automatische Updates (Optioneel)

Maak een cron job die automatisch updates draait:

```bash
# Elke 5 minuten checken op updates
crontab -e
# Voeg toe:
*/5 * * * * cd /opt/lovable-app && git fetch && [ $(git rev-parse HEAD) != $(git rev-parse @{u}) ] && /opt/lovable-app/update.sh >> /var/log/lovable-update.log 2>&1
```

Of gebruik een GitHub webhook voor instant updates.
