import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/handleiding")({
  head: () => ({
    meta: [
      { title: "Handleiding — Lovable VPS Installer" },
      { name: "description", content: "Stap-voor-stap handleiding om je Lovable app met Supabase te deployen op je eigen Proxmox server." },
      { property: "og:title", content: "Handleiding — Lovable VPS Installer" },
      { property: "og:description", content: "Complete installatiehandleiding voor self-hosted Lovable + Supabase." },
    ],
  }),
  component: HandleidingPage,
});

function HandleidingPage() {
  return (
    <div className="mx-auto max-w-3xl px-6 py-12">
      <h1 className="mb-2 text-3xl font-bold text-foreground">Installatiehandleiding</h1>
      <p className="mb-10 text-muted-foreground">Van lege Proxmox VM tot werkende applicatie — stap voor stap.</p>

      <nav className="mb-12 rounded-lg border border-border bg-muted/50 p-5">
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-muted-foreground">Inhoud</h2>
        <ol className="list-inside list-decimal space-y-1 text-sm text-primary">
          {[
            "Vereisten",
            "Architectuur kiezen",
            "GitHub deploy key instellen",
            "Single-server installatie",
            "Split: Database-server",
            "Split: Frontend-server",
            "Na installatie",
            "Updates draaien",
            "Data migreren uit Lovable Cloud",
            "SMTP & OAuth instellen",
            "Troubleshooting",
            "Backup",
          ].map((item, i) => (
            <li key={i}>
              <a href={`#stap-${i + 1}`} className="hover:underline">{item}</a>
            </li>
          ))}
        </ol>
      </nav>

      {/* Stap 1 */}
      <Section id="stap-1" number={1} title="Vereisten">
        <p>Wat je nodig hebt voordat je begint:</p>
        <ul className="list-inside list-disc space-y-1">
          <li><strong>Proxmox host</strong> met voldoende resources</li>
          <li><strong>Ubuntu 24.04 VM</strong> — minimaal 4GB RAM (single) of 2× 2GB (split)</li>
          <li><strong>2 vCPU</strong> per VM (aanbevolen)</li>
          <li><strong>20GB+ disk</strong> per VM</li>
          <li><strong>SSH-toegang</strong> tot de VM(s)</li>
          <li><strong>Privé GitHub repo</strong> met je Lovable project</li>
          <li><strong>Domeinnaam</strong> (optioneel, kan ook op IP)</li>
        </ul>
        <Tip>Bij een split-setup: zorg dat beide VM's elkaar kunnen bereiken via het interne netwerk (vmbr0).</Tip>
      </Section>

      {/* Stap 2 */}
      <Section id="stap-2" number={2} title="Architectuur kiezen">
        <p>Je hebt twee opties:</p>

        <h4 className="mt-4 font-semibold text-foreground">Optie A: Single server</h4>
        <p>Alles draait op één VM: frontend, Supabase, PostgreSQL. Simpelst om op te zetten.</p>
        <CodeBlock>{`[VM - 4GB RAM]
├── Frontend (Docker)
├── Supabase Auth, REST, Storage, Realtime (Docker)
├── PostgreSQL (Docker)
└── Nginx + SSL`}</CodeBlock>

        <h4 className="mt-6 font-semibold text-foreground">Optie B: Split setup</h4>
        <p>Database op Server A, frontend op Server B. Beter schaalbaar en makkelijker te back-uppen.</p>
        <CodeBlock>{`[Server A - Database - 2GB RAM]       [Server B - Frontend - 2GB RAM]
├── PostgreSQL (Docker)                ├── Frontend (Docker)
├── Supabase Auth, REST, etc.          ├── Nginx + SSL
└── Firewall: poort 8000 open          └── .env → wijst naar Server A`}</CodeBlock>
      </Section>

      {/* Stap 3 */}
      <Section id="stap-3" number={3} title="GitHub deploy key instellen">
        <p>Om je privé repo te clonen op de VM zonder wachtwoord:</p>
        <CodeBlock title="Op de VM">{`# SSH key genereren (geen wachtwoord)
ssh-keygen -t ed25519 -C "deploy@vps" -f ~/.ssh/deploy_key -N ""

# Publieke key tonen
cat ~/.ssh/deploy_key.pub`}</CodeBlock>
        <p>Kopieer de output en ga naar je GitHub repo:</p>
        <ol className="list-inside list-decimal space-y-1">
          <li>Ga naar <strong>Settings → Deploy keys → Add deploy key</strong></li>
          <li>Plak de publieke key, geef een naam (bijv. "VPS"), vink <strong>"Allow write access"</strong> niet aan</li>
          <li>Klik <strong>Add key</strong></li>
        </ol>
        <CodeBlock title="SSH config aanmaken op de VM">{`cat > ~/.ssh/config << 'EOF'
Host github.com
  IdentityFile ~/.ssh/deploy_key
  IdentitiesOnly yes
EOF
chmod 600 ~/.ssh/config

# Test de verbinding
ssh -T git@github.com`}</CodeBlock>
        <Tip>Je zou moeten zien: "Hi user/repo! You've successfully authenticated"</Tip>
      </Section>

      {/* Stap 4 */}
      <Section id="stap-4" number={4} title="Single-server installatie">
        <p>Voor een volledige installatie op één VM:</p>
        <CodeBlock>{`# Repo clonen
git clone git@github.com:JOUW-USER/JOUW-REPO.git /opt/lovable-app

# Installer draaien
cd /opt/lovable-app
sudo bash install.sh`}</CodeBlock>
        <p>Het script vraagt om:</p>
        <ul className="list-inside list-disc space-y-1">
          <li><strong>Installatiemodus</strong> — kies "Volledige installatie"</li>
          <li><strong>Domeinnaam</strong> — of laat leeg voor IP</li>
          <li><strong>Admin e-mail</strong> — voor SSL certificaat</li>
          <li><strong>Database wachtwoord</strong> — kies iets sterks</li>
          <li><strong>Dashboard wachtwoord</strong> — voor Supabase Studio</li>
        </ul>
        <p className="mt-2">Het script doet de rest: Docker installeren, secrets genereren, containers starten, Nginx + SSL configureren.</p>
      </Section>

      {/* Stap 5 */}
      <Section id="stap-5" number={5} title="Split: Database-server">
        <p>Op Server A (de database-VM):</p>
        <CodeBlock>{`git clone git@github.com:JOUW-USER/JOUW-REPO.git /opt/lovable-app
cd /opt/lovable-app
sudo bash install.sh
# Kies: "Alleen database"`}</CodeBlock>
        <p>Dit start alleen de Supabase containers (PostgreSQL, Auth, REST, Storage, Realtime, Kong).</p>

        <h4 className="mt-4 font-semibold text-foreground">Firewall instellen</h4>
        <p>Zorg dat de frontend-server erbij kan:</p>
        <CodeBlock>{`# Sta de frontend-server toe op poort 8000 (Kong API Gateway)
sudo ufw allow from FRONTEND_SERVER_IP to any port 8000

# Optioneel: direct PostgreSQL toegang (poort 5432)
sudo ufw allow from FRONTEND_SERVER_IP to any port 5432`}</CodeBlock>
        <Tip>Noteer de Anon Key en Service Role Key uit de output — die heb je nodig op de frontend-server.</Tip>
      </Section>

      {/* Stap 6 */}
      <Section id="stap-6" number={6} title="Split: Frontend-server">
        <p>Op Server B (de frontend-VM):</p>
        <CodeBlock>{`git clone git@github.com:JOUW-USER/JOUW-REPO.git /opt/lovable-app
cd /opt/lovable-app
sudo bash install.sh
# Kies: "Alleen frontend"
# Voer het IP/domein van de database-server in wanneer gevraagd
# Voer de Anon Key in van de database-server`}</CodeBlock>
        <p>Dit bouwt alleen de frontend container en configureert Nginx met SSL.</p>
      </Section>

      {/* Stap 7 */}
      <Section id="stap-7" number={7} title="Na installatie">
        <p>Controleer of alles werkt:</p>
        <CodeBlock>{`# Controleer draaiende containers
docker ps

# Check de frontend
curl -I http://localhost:3000

# Check Supabase API (single-server of database-server)
curl http://localhost:8000/rest/v1/ -H "apikey: JOUW_ANON_KEY"

# Open in je browser
# https://jouw-domein.nl        → je app
# https://jouw-domein.nl:8080   → Supabase Studio`}</CodeBlock>
      </Section>

      {/* Stap 8 */}
      <Section id="stap-8" number={8} title="Updates draaien">
        <p>Na wijzigingen in Lovable (die automatisch naar GitHub pusht):</p>
        <CodeBlock>{`# Op de server(s):
lovable-update

# Of handmatig:
cd /opt/lovable-app
git pull
docker build -t lovable-frontend -f Dockerfile .
docker stop lovable-frontend && docker rm lovable-frontend
docker run -d --name lovable-frontend --restart unless-stopped -p 3000:80 lovable-frontend`}</CodeBlock>
        <p>Bij een split-setup: draai <code className="rounded bg-muted px-1.5 py-0.5 text-sm">lovable-update</code> op de frontend-server. Database migraties worden automatisch meegenomen.</p>
        <Tip>De Supabase containers en database blijven intact bij een update — alleen de frontend wordt opnieuw gebouwd.</Tip>
      </Section>

      {/* Stap 9 */}
      <Section id="stap-9" number={9} title="Data migreren uit Lovable Cloud">
        <p>Als je bestaande data hebt in Lovable Cloud:</p>
        <ol className="list-inside list-decimal space-y-2">
          <li>Ga naar <strong>Lovable → Cloud → Database → Tables</strong></li>
          <li>Exporteer elke tabel als CSV</li>
          <li>Kopieer de CSV-bestanden naar je server</li>
          <li>Importeer ze:</li>
        </ol>
        <CodeBlock>{`# Kopieer CSV naar server
scp tabel.csv root@jouw-server:/tmp/

# Importeer in PostgreSQL
docker exec -i supabase-db psql -U supabase -d postgres \\
  -c "\\COPY public.tabel_naam FROM '/tmp/tabel.csv' WITH CSV HEADER"`}</CodeBlock>
        <Warn>Gebruikerswachtwoorden kunnen niet gemigreerd worden. Gebruikers moeten een wachtwoord-reset doen na migratie.</Warn>
      </Section>

      {/* Stap 10 */}
      <Section id="stap-10" number={10} title="SMTP & OAuth instellen">
        <h4 className="font-semibold text-foreground">E-mail (SMTP)</h4>
        <p>Bewerk de Supabase environment file:</p>
        <CodeBlock>{`sudo nano /opt/supabase/.env

# Pas deze regels aan:
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=jouw-email@gmail.com
SMTP_PASS=jouw-app-wachtwoord
SMTP_SENDER_NAME=Mijn App

# Herstart auth container
cd /opt/supabase && docker compose restart auth`}</CodeBlock>

        <h4 className="mt-6 font-semibold text-foreground">Google OAuth</h4>
        <ol className="list-inside list-decimal space-y-1">
          <li>Ga naar <a href="https://console.cloud.google.com" className="text-primary hover:underline" target="_blank" rel="noopener noreferrer">Google Cloud Console</a></li>
          <li>Maak OAuth 2.0 credentials aan</li>
          <li>Redirect URI: <code className="rounded bg-muted px-1.5 py-0.5 text-sm">https://jouw-domein.nl/auth/v1/callback</code></li>
          <li>Voeg toe aan <code className="rounded bg-muted px-1.5 py-0.5 text-sm">/opt/supabase/.env</code>:</li>
        </ol>
        <CodeBlock>{`GOTRUE_EXTERNAL_GOOGLE_ENABLED=true
GOTRUE_EXTERNAL_GOOGLE_CLIENT_ID=jouw-client-id
GOTRUE_EXTERNAL_GOOGLE_SECRET=jouw-secret
GOTRUE_EXTERNAL_GOOGLE_REDIRECT_URI=https://jouw-domein.nl/auth/v1/callback`}</CodeBlock>
      </Section>

      {/* Stap 11 */}
      <Section id="stap-11" number={11} title="Troubleshooting">
        <div className="space-y-4">
          <TroubleItem q="Container start niet op" a="Check logs: docker logs supabase-db (of andere container naam). Vaak is het een verkeerd wachtwoord of poort-conflict." />
          <TroubleItem q="Frontend laadt niet" a="Check of poort 3000 open is: curl http://localhost:3000. Check Nginx config: sudo nginx -t" />
          <TroubleItem q="SSL werkt niet" a="Controleer of poort 80 en 443 open staan in je Proxmox firewall én in UFW. Draai: sudo certbot --nginx -d jouw-domein.nl" />
          <TroubleItem q="Database connectie mislukt" a="Check of PostgreSQL draait: docker exec supabase-db pg_isready -U supabase. Bij split-setup: check firewall regels." />
          <TroubleItem q="Git pull mislukt" a="Check je deploy key: ssh -T git@github.com. Controleer ~/.ssh/config." />
          <TroubleItem q="Supabase API geeft 401" a="Controleer of ANON_KEY in .env.production overeenkomt met de key in /opt/supabase/.env" />
        </div>
      </Section>

      {/* Stap 12 */}
      <Section id="stap-12" number={12} title="Backup">
        <p>Maak regelmatig backups van je database:</p>
        <CodeBlock title="Database dump">{`# Volledige backup
docker exec supabase-db pg_dump -U supabase postgres > backup_$(date +%Y%m%d).sql

# Backup met compressie
docker exec supabase-db pg_dump -U supabase -Fc postgres > backup_$(date +%Y%m%d).dump

# Restore
docker exec -i supabase-db psql -U supabase -d postgres < backup_20240101.sql`}</CodeBlock>

        <CodeBlock title="Automatische backup (cron)">{`# Dagelijkse backup om 3:00 's nachts
sudo crontab -e

# Voeg toe:
0 3 * * * docker exec supabase-db pg_dump -U supabase -Fc postgres > /opt/backups/db_$(date +\\%Y\\%m\\%d).dump 2>&1`}</CodeBlock>

        <CodeBlock title="Storage backup">{`# Supabase Storage bestanden
tar -czf storage_backup_$(date +%Y%m%d).tar.gz /opt/supabase/volumes/storage/`}</CodeBlock>
        <Tip>Bewaar backups op een andere locatie dan de server zelf — gebruik rsync naar een andere Proxmox VM of externe opslag.</Tip>
      </Section>

      <footer className="mt-16 border-t border-border pt-8 pb-12 text-center text-sm text-muted-foreground">
        Lovable VPS Installer — Self-hosted deployment toolkit
      </footer>
    </div>
  );
}

/* ── Helper components ── */

function Section({ id, number, title, children }: { id: string; number: number; title: string; children: React.ReactNode }) {
  return (
    <section id={id} className="mb-14 scroll-mt-20">
      <h3 className="mb-4 flex items-baseline gap-3 text-xl font-semibold text-foreground">
        <span className="inline-flex h-7 w-7 flex-shrink-0 items-center justify-center rounded-full bg-primary text-xs font-bold text-primary-foreground">
          {number}
        </span>
        {title}
      </h3>
      <div className="space-y-3 text-sm leading-relaxed text-muted-foreground">{children}</div>
    </section>
  );
}

function CodeBlock({ children, title }: { children: string; title?: string }) {
  return (
    <div className="my-3 overflow-x-auto rounded-lg border border-border bg-muted/60">
      {title && (
        <div className="border-b border-border px-4 py-1.5 text-xs font-medium text-muted-foreground">{title}</div>
      )}
      <pre className="p-4 text-xs leading-relaxed text-foreground"><code>{children}</code></pre>
    </div>
  );
}

function Tip({ children }: { children: React.ReactNode }) {
  return (
    <div className="my-3 rounded-lg border border-primary/20 bg-primary/5 px-4 py-3 text-sm text-foreground">
      <strong className="text-primary">💡 Tip:</strong> {children}
    </div>
  );
}

function Warn({ children }: { children: React.ReactNode }) {
  return (
    <div className="my-3 rounded-lg border border-destructive/20 bg-destructive/5 px-4 py-3 text-sm text-foreground">
      <strong className="text-destructive">⚠️ Let op:</strong> {children}
    </div>
  );
}

function TroubleItem({ q, a }: { q: string; a: string }) {
  return (
    <div className="rounded-lg border border-border bg-muted/30 p-4">
      <p className="font-medium text-foreground">{q}</p>
      <p className="mt-1 text-sm text-muted-foreground">{a}</p>
    </div>
  );
}
