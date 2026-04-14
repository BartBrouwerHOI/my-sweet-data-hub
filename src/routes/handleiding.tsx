import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { Copy, Check } from "lucide-react";

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

type SetupMode = "single" | "split";

function HandleidingPage() {
  const [mode, setMode] = useState<SetupMode>("single");

  const singleSteps = [
    { id: "vereisten", title: "Vereisten" },
    { id: "architectuur", title: "Architectuur" },
    { id: "deploy-key", title: "GitHub deploy key instellen" },
    { id: "installatie", title: "Installatie" },
    { id: "na-installatie", title: "Na installatie" },
    { id: "updates", title: "Updates draaien" },
    { id: "data-migratie", title: "Data migreren uit Lovable Cloud" },
    { id: "smtp-oauth", title: "SMTP & OAuth instellen" },
    { id: "troubleshooting", title: "Troubleshooting" },
    { id: "backup", title: "Backup" },
  ];

  const splitSteps = [
    { id: "vereisten", title: "Vereisten" },
    { id: "architectuur", title: "Architectuur" },
    { id: "deploy-key", title: "GitHub deploy key instellen" },
    { id: "split-backend", title: "Server A — Supabase backend" },
    { id: "split-frontend", title: "Server B — React frontend" },
    { id: "na-installatie", title: "Na installatie" },
    { id: "updates", title: "Updates draaien" },
    { id: "data-migratie", title: "Data migreren uit Lovable Cloud" },
    { id: "smtp-oauth", title: "SMTP & OAuth instellen" },
    { id: "troubleshooting", title: "Troubleshooting" },
    { id: "backup", title: "Backup" },
  ];

  const steps = mode === "single" ? singleSteps : splitSteps;

  return (
    <div className="mx-auto max-w-3xl px-6 py-12">
      <h1 className="mb-2 text-3xl font-bold text-foreground">Installatiehandleiding</h1>
      <p className="mb-8 text-muted-foreground">Van lege Proxmox VM tot werkende applicatie — stap voor stap.</p>

      {/* Mode toggle */}
      <div className="mb-10 rounded-lg border border-border bg-muted/50 p-4">
        <p className="mb-3 text-sm font-medium text-foreground">Welke setup wil je?</p>
        <div className="flex gap-2">
          <button
            onClick={() => setMode("single")}
            className={`rounded-md px-4 py-2 text-sm font-medium transition-colors ${
              mode === "single"
                ? "bg-primary text-primary-foreground"
                : "bg-muted text-muted-foreground hover:bg-muted/80"
            }`}
          >
            Single server
          </button>
          <button
            onClick={() => setMode("split")}
            className={`rounded-md px-4 py-2 text-sm font-medium transition-colors ${
              mode === "split"
                ? "bg-primary text-primary-foreground"
                : "bg-muted text-muted-foreground hover:bg-muted/80"
            }`}
          >
            Split setup (2 servers)
          </button>
        </div>
        <p className="mt-2 text-xs text-muted-foreground">
          {mode === "single"
            ? "Alles op één VM: React frontend + volledige Supabase stack."
            : "Server A draait Supabase (backend), Server B draait de React frontend."}
        </p>
      </div>

      {/* Table of contents */}
      <nav className="mb-12 rounded-lg border border-border bg-muted/50 p-5">
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-muted-foreground">Inhoud</h2>
        <ol className="list-inside list-decimal space-y-1 text-sm text-primary">
          {steps.map((step, i) => (
            <li key={step.id}>
              <a href={`#${step.id}`} className="hover:underline">{step.title}</a>
            </li>
          ))}
        </ol>
      </nav>

      {/* Stap: Vereisten */}
      <Step id="vereisten" number={steps.findIndex(s => s.id === "vereisten") + 1} title="Vereisten">
        <p>Wat je nodig hebt voordat je begint:</p>
        <ul className="list-inside list-disc space-y-1">
          <li><strong>Proxmox host</strong> met voldoende resources</li>
          {mode === "single" ? (
            <li><strong>Ubuntu 24.04 VM</strong> — minimaal 4GB RAM, 2 vCPU, 20GB disk</li>
          ) : (
            <>
              <li><strong>Ubuntu 24.04 VM (Server A)</strong> — minimaal 2GB RAM, 2 vCPU, 20GB disk — voor Supabase</li>
              <li><strong>Ubuntu 24.04 VM (Server B)</strong> — minimaal 2GB RAM, 2 vCPU, 10GB disk — voor de frontend</li>
            </>
          )}
          <li><strong>SSH-toegang</strong> tot de VM{mode === "split" ? "'s" : ""}</li>
          <li><strong>Privé GitHub repo</strong> met je Lovable project</li>
          <li><strong>Domeinnaam</strong> (optioneel, kan ook op IP)</li>
        </ul>
        {mode === "split" && (
          <Tip>Zorg dat beide VM's elkaar kunnen bereiken via het interne Proxmox netwerk (vmbr0).</Tip>
        )}
      </Step>

      {/* Stap: Architectuur */}
      <Step id="architectuur" number={steps.findIndex(s => s.id === "architectuur") + 1} title="Architectuur">
        <Tip>
          <strong>Wat is Supabase?</strong> Supabase is een complete backend-stack: PostgreSQL (database), GoTrue (authenticatie), PostgREST (API), Storage (bestanden) en Realtime (websockets). Al deze services draaien als Docker containers.
        </Tip>

        {mode === "single" ? (
          <>
            <p>Alles draait op één VM:</p>
            <CodeBlock>{`[VM - 4GB RAM]
├── Nginx (SSL termination)
│   ├── /           → Node.js frontend (poort 3000)
│   └── /auth, /rest, /storage, /realtime → Kong API Gateway (poort 8000)
│
├── React Frontend (Node.js, Docker)
│
└── Supabase stack (Docker Compose)
    ├── Kong (API Gateway, poort 8000)
    ├── PostgreSQL (database)
    ├── GoTrue (authenticatie)
    ├── PostgREST (REST API)
    ├── Storage (bestanden)
    ├── Realtime (websockets)
    └── Studio (admin dashboard, poort 8080)`}</CodeBlock>
          </>
        ) : (
          <>
            <p>Twee servers, gescheiden verantwoordelijkheden:</p>
            <CodeBlock>{`[Server A - Supabase backend - 2GB RAM]
├── Kong API Gateway (poort 8000) ← Frontend praat hiermee
├── PostgreSQL (database)
├── GoTrue (authenticatie)
├── PostgREST (REST API)
├── Storage (bestanden)
├── Realtime (websockets)
├── Studio (admin dashboard, poort 8080)
└── Firewall: poort 8000 alleen open voor Server B

[Server B - React frontend - 2GB RAM]
├── Node.js frontend (Docker, poort 3000)
├── Nginx (SSL + reverse proxy)
│   ├── /           → localhost:3000 (frontend)
│   └── /auth, /rest, /storage, /realtime → Server A:8000
└── .env → VITE_SUPABASE_URL wijst naar Server A`}</CodeBlock>
          </>
        )}
      </Step>

      {/* Stap: Deploy key */}
      <Step id="deploy-key" number={steps.findIndex(s => s.id === "deploy-key") + 1} title="GitHub deploy key instellen">
        <p>Om je privé repo te clonen op de VM{mode === "split" ? "'s" : ""} zonder wachtwoord:</p>
        {mode === "split" && (
          <Warn>Herhaal deze stap op <strong>beide servers</strong> (A en B).</Warn>
        )}
        <CodeBlock title="Op de VM">{`# SSH key genereren (geen wachtwoord)
ssh-keygen -t ed25519 -C "deploy@vps" -f ~/.ssh/deploy_key -N ""

# Publieke key tonen
cat ~/.ssh/deploy_key.pub`}</CodeBlock>
        <p>Kopieer de output en ga naar je GitHub repo:</p>
        <ol className="list-inside list-decimal space-y-1">
          <li>Ga naar <strong>Settings → Deploy keys → Add deploy key</strong></li>
          <li>Plak de publieke key, geef een naam (bijv. "VPS{mode === "split" ? " - Server A" : ""}"), vink <strong>"Allow write access"</strong> niet aan</li>
          <li>Klik <strong>Add key</strong></li>
        </ol>
        <CodeBlock title="SSH config aanmaken">{`cat > ~/.ssh/config << 'EOF'
Host github.com
  IdentityFile ~/.ssh/deploy_key
  IdentitiesOnly yes
EOF
chmod 600 ~/.ssh/config

# Test de verbinding
ssh -T git@github.com`}</CodeBlock>
        <Tip>Je zou moeten zien: "Hi user/repo! You've successfully authenticated"</Tip>
      </Step>

      {/* === SINGLE MODE: Installatie === */}
      {mode === "single" && (
        <Step id="installatie" number={steps.findIndex(s => s.id === "installatie") + 1} title="Installatie">
          <p>Clone je repo en draai het install-script:</p>
          <CodeBlock>{`# Repo clonen
git clone git@github.com:JOUW-USER/JOUW-REPO.git /opt/lovable-app

# Installer draaien
cd /opt/lovable-app
sudo bash install.sh`}</CodeBlock>
          <p>Het script vraagt om:</p>
          <ul className="list-inside list-disc space-y-1">
            <li><strong>Installatiemodus</strong> — kies <code className="rounded bg-muted px-1.5 py-0.5 text-sm">1) Volledige installatie</code></li>
            <li><strong>Domeinnaam</strong> — of laat leeg voor IP</li>
            <li><strong>Admin e-mail</strong> — voor SSL certificaat</li>
            <li><strong>Database wachtwoord</strong> — kies iets sterks</li>
            <li><strong>Dashboard wachtwoord</strong> — voor Supabase Studio</li>
          </ul>
          <p className="mt-2">Het script doet de rest: Docker installeren, secrets genereren, containers starten, Nginx + SSL configureren.</p>
          <Warn>Het script zet <code className="rounded bg-muted px-1.5 py-0.5 text-sm">GOTRUE_MAILER_AUTOCONFIRM: true</code>. Dit bevestigt e-mailadressen automatisch zonder verificatie. Voor productie: stel SMTP in (stap {steps.findIndex(s => s.id === "smtp-oauth") + 1}) en zet dit op <code className="rounded bg-muted px-1.5 py-0.5 text-sm">false</code>.</Warn>
        </Step>
      )}

      {/* === SPLIT MODE: Server A (Backend) === */}
      {mode === "split" && (
        <Step id="split-backend" number={steps.findIndex(s => s.id === "split-backend") + 1} title="Server A — Supabase backend">
          <p>Op Server A draai je de volledige Supabase stack (PostgreSQL, Auth, API, Storage, Realtime):</p>
          <CodeBlock>{`# Repo clonen
git clone git@github.com:JOUW-USER/JOUW-REPO.git /opt/lovable-app

# Installer draaien
cd /opt/lovable-app
sudo bash install.sh

# Kies: 2) Alleen Supabase (backend)`}</CodeBlock>
          <p>Het script start alle Supabase containers en Kong (API Gateway op poort 8000).</p>

          <h4 className="mt-4 font-semibold text-foreground">Firewall instellen</h4>
          <p>Beperk toegang tot de API Gateway zodat alleen Server B erbij kan:</p>
          <CodeBlock>{`# Sta ALLEEN de frontend-server toe op poort 8000
sudo ufw allow from SERVER_B_IP to any port 8000

# Optioneel: directe PostgreSQL toegang (voor migraties/debugging)
sudo ufw allow from SERVER_B_IP to any port 5432`}</CodeBlock>
          <Tip>Noteer de <strong>Anon Key</strong> uit de output — die heb je nodig bij het installeren van Server B.</Tip>
          <Warn>Zet poort 8000 <strong>niet</strong> open voor iedereen. Beperk het tot het IP van Server B.</Warn>
        </Step>
      )}

      {/* === SPLIT MODE: Server B (Frontend) === */}
      {mode === "split" && (
        <Step id="split-frontend" number={steps.findIndex(s => s.id === "split-frontend") + 1} title="Server B — React frontend">
          <p>Op Server B draait alleen de React app — geen database, geen Supabase services:</p>
          <CodeBlock>{`# Repo clonen
git clone git@github.com:JOUW-USER/JOUW-REPO.git /opt/lovable-app

# Installer draaien
cd /opt/lovable-app
sudo bash install.sh

# Kies: 3) Alleen frontend
# Voer het IP of domein van Server A in wanneer gevraagd
# Voer de Anon Key in die je bij Server A hebt genoteerd`}</CodeBlock>
          <p>Het script bouwt de React app als Docker container, configureert Nginx als reverse proxy (frontend + API doorsturen naar Server A) en regelt SSL.</p>
        </Step>
      )}

      {/* Stap: Na installatie */}
      <Step id="na-installatie" number={steps.findIndex(s => s.id === "na-installatie") + 1} title="Na installatie">
        <p>Controleer of alles werkt:</p>
        {mode === "single" ? (
          <CodeBlock>{`# Draaiende containers bekijken
docker ps

# Frontend testen
curl -I http://localhost:3000

# Supabase API testen
curl http://localhost:8000/rest/v1/ -H "apikey: JOUW_ANON_KEY"

# Open in je browser:
# https://jouw-domein.nl        → je app
# https://jouw-domein.nl:8080   → Supabase Studio (admin)`}</CodeBlock>
        ) : (
          <>
            <CodeBlock title="Op Server A (backend)">{`# Controleer of alle Supabase containers draaien
docker ps

# API testen
curl http://localhost:8000/rest/v1/ -H "apikey: JOUW_ANON_KEY"

# Studio openen: http://SERVER_A_IP:8080`}</CodeBlock>
            <CodeBlock title="Op Server B (frontend)">{`# Controleer of de frontend draait
docker ps
curl -I http://localhost:3000

# Test of de API via Nginx bereikbaar is
curl http://localhost/rest/v1/ -H "apikey: JOUW_ANON_KEY"

# Open in je browser: https://jouw-domein.nl`}</CodeBlock>
          </>
        )}
      </Step>

      {/* Stap: Updates */}
      <Step id="updates" number={steps.findIndex(s => s.id === "updates") + 1} title="Updates draaien">
        <p>Na wijzigingen in Lovable (die automatisch naar GitHub pusht):</p>
        {mode === "single" ? (
          <CodeBlock>{`# Eén commando:
lovable-update

# Of handmatig:
cd /opt/lovable-app
git pull
docker build -t lovable-frontend -f Dockerfile .
docker stop lovable-frontend && docker rm lovable-frontend
docker run -d --name lovable-frontend --restart unless-stopped -p 3000:80 lovable-frontend`}</CodeBlock>
        ) : (
          <>
            <CodeBlock title="Op Server B (frontend)">{`# Update de frontend:
lovable-update

# Dit doet: git pull → docker build → restart container`}</CodeBlock>
            <CodeBlock title="Op Server A (backend, alleen bij database-wijzigingen)">{`# Nieuwe migraties toepassen:
cd /opt/lovable-app
git pull

# Migraties handmatig draaien:
for f in supabase/migrations/*.sql; do
  docker exec -i supabase-db psql -U supabase -d postgres < "$f"
done`}</CodeBlock>
          </>
        )}
        <Tip>De Supabase containers en database blijven intact bij een update — alleen de frontend wordt opnieuw gebouwd.</Tip>
      </Step>

      {/* Stap: Data migratie */}
      <Step id="data-migratie" number={steps.findIndex(s => s.id === "data-migratie") + 1} title="Data migreren uit Lovable Cloud">
        <p>Als je bestaande data hebt in Lovable Cloud:</p>
        <ol className="list-inside list-decimal space-y-2">
          <li>Ga naar <strong>Lovable → Cloud → Database → Tables</strong></li>
          <li>Exporteer elke tabel als CSV</li>
          <li>Kopieer de CSV-bestanden naar je {mode === "split" ? "backend-server (A)" : "server"}</li>
          <li>Importeer ze:</li>
        </ol>
        <CodeBlock>{`# Kopieer CSV naar server
scp tabel.csv root@jouw-server:/tmp/

# Importeer in PostgreSQL
docker exec -i supabase-db psql -U supabase -d postgres \\
  -c "\\COPY public.tabel_naam FROM '/tmp/tabel.csv' WITH CSV HEADER"`}</CodeBlock>
        <Warn>Gebruikerswachtwoorden kunnen niet gemigreerd worden. Gebruikers moeten een wachtwoord-reset doen na migratie.</Warn>
      </Step>

      {/* Stap: SMTP & OAuth */}
      <Step id="smtp-oauth" number={steps.findIndex(s => s.id === "smtp-oauth") + 1} title="SMTP & OAuth instellen">
        <Warn>Zonder SMTP staat e-mail autoconfirm aan — iedereen kan zich registreren zonder verificatie. Stel SMTP in voor productie!</Warn>

        <h4 className="font-semibold text-foreground">E-mail (SMTP)</h4>
        <p>Bewerk de Supabase environment file{mode === "split" ? " op Server A" : ""}:</p>
        <CodeBlock>{`sudo nano /opt/supabase/.env

# Pas deze regels aan:
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=jouw-email@gmail.com
SMTP_PASS=jouw-app-wachtwoord
SMTP_SENDER_NAME=Mijn App

# Zet autoconfirm UIT:
# In docker-compose.yml → auth service:
# GOTRUE_MAILER_AUTOCONFIRM: "false"

# Herstart auth container
cd /opt/supabase && docker compose restart auth`}</CodeBlock>

        <h4 className="mt-6 font-semibold text-foreground">Google OAuth</h4>
        <ol className="list-inside list-decimal space-y-1">
          <li>Ga naar <a href="https://console.cloud.google.com" className="text-primary hover:underline" target="_blank" rel="noopener noreferrer">Google Cloud Console</a></li>
          <li>Maak OAuth 2.0 credentials aan</li>
          <li>Redirect URI: <code className="rounded bg-muted px-1.5 py-0.5 text-sm">https://jouw-domein.nl/auth/v1/callback</code></li>
          <li>Voeg toe aan <code className="rounded bg-muted px-1.5 py-0.5 text-sm">/opt/supabase/.env</code>{mode === "split" ? " op Server A" : ""}:</li>
        </ol>
        <CodeBlock>{`GOTRUE_EXTERNAL_GOOGLE_ENABLED=true
GOTRUE_EXTERNAL_GOOGLE_CLIENT_ID=jouw-client-id
GOTRUE_EXTERNAL_GOOGLE_SECRET=jouw-secret
GOTRUE_EXTERNAL_GOOGLE_REDIRECT_URI=https://jouw-domein.nl/auth/v1/callback`}</CodeBlock>
      </Step>

      {/* Stap: Troubleshooting */}
      <Step id="troubleshooting" number={steps.findIndex(s => s.id === "troubleshooting") + 1} title="Troubleshooting">
        <div className="space-y-4">
          <TroubleItem q="Container start niet op" a={`Check logs: docker logs supabase-db (of andere container). Vaak een verkeerd wachtwoord of poort-conflict.`} />
          <TroubleItem q="Frontend laadt niet" a="Check of poort 3000 open is: curl http://localhost:3000. Check Nginx: sudo nginx -t" />
          <TroubleItem q="SSL werkt niet" a="Controleer of poort 80 en 443 open staan in Proxmox firewall én UFW. Draai: sudo certbot --nginx -d jouw-domein.nl" />
          <TroubleItem q="Database connectie mislukt" a={`Check of PostgreSQL draait: docker exec supabase-db pg_isready -U supabase.${mode === "split" ? " Bij split: check firewall op Server A." : ""}`} />
          <TroubleItem q="Git pull mislukt" a="Check deploy key: ssh -T git@github.com. Controleer ~/.ssh/config." />
          <TroubleItem q="Supabase API geeft 401" a="Controleer of ANON_KEY in .env.production overeenkomt met de key in /opt/supabase/.env" />
          {mode === "split" && (
            <TroubleItem q="Frontend kan Server A niet bereiken" a="Check of poort 8000 open staat op Server A: curl http://SERVER_A_IP:8000/rest/v1/. Controleer UFW regels." />
          )}
        </div>
      </Step>

      {/* Stap: Backup */}
      <Step id="backup" number={steps.findIndex(s => s.id === "backup") + 1} title="Backup">
        <p>Maak regelmatig backups van je database{mode === "split" ? " (op Server A)" : ""}:</p>
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
        <Tip>Bewaar backups op een andere locatie — gebruik rsync naar een andere Proxmox VM of externe opslag.</Tip>
      </Step>

      <footer className="mt-16 border-t border-border pt-8 pb-12 text-center text-sm text-muted-foreground">
        Lovable VPS Installer — Self-hosted deployment toolkit
      </footer>
    </div>
  );
}

/* ── Helper components ── */

function Step({ id, number, title, children }: { id: string; number: number; title: string; children: React.ReactNode }) {
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
  const [copied, setCopied] = useState(false);

  const handleCopy = async () => {
    await navigator.clipboard.writeText(children);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="group relative my-3 overflow-x-auto rounded-lg border border-border bg-muted/60">
      {title && (
        <div className="border-b border-border px-4 py-1.5 text-xs font-medium text-muted-foreground">{title}</div>
      )}
      <button
        onClick={handleCopy}
        className="absolute top-2 right-2 rounded-md border border-border bg-background p-1.5 text-muted-foreground opacity-0 transition-opacity hover:text-foreground group-hover:opacity-100"
        title="Kopiëren"
      >
        {copied ? <Check className="h-3.5 w-3.5 text-green-500" /> : <Copy className="h-3.5 w-3.5" />}
      </button>
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
