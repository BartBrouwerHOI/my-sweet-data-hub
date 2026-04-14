import { createFileRoute } from "@tanstack/react-router";
import { useState, useEffect, useCallback } from "react";
import { Copy, Check, Terminal, Globe, Monitor, Info, Settings } from "lucide-react";

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
type Distro = "debian" | "rhel";

function HandleidingPage() {
  const [mode, setMode] = useState<SetupMode>("single");
  const [distro, setDistro] = useState<Distro>("debian");

  // User config fields with localStorage persistence
  const [userConfig, setUserConfig] = useState({
    githubUser: "",
    repoName: "",
    serverIp: "",
    domain: "",
    serverAIp: "",
  });

  useEffect(() => {
    try {
      const saved = localStorage.getItem("handleiding-config");
      if (saved) setUserConfig(JSON.parse(saved));
    } catch {}
  }, []);

  const updateField = useCallback((field: keyof typeof userConfig, value: string) => {
    setUserConfig(prev => {
      const next = { ...prev, [field]: value };
      localStorage.setItem("handleiding-config", JSON.stringify(next));
      return next;
    });
  }, []);

  const fill = useCallback((text: string): string => {
    let result = text;
    if (userConfig.githubUser) result = result.replace(/JOUW-USER/g, userConfig.githubUser);
    if (userConfig.repoName) result = result.replace(/JOUW-REPO/g, userConfig.repoName);
    if (userConfig.serverIp) result = result.replace(/JOUW-SERVER-IP/g, userConfig.serverIp);
    if (userConfig.domain) result = result.replace(/jouw-domein\.nl/g, userConfig.domain);
    if (userConfig.serverAIp) result = result.replace(/SERVER_A_IP/g, userConfig.serverAIp);
    return result;
  }, [userConfig]);

  const singleSteps = [
    { id: "vereisten", title: "Vereisten" },
    { id: "architectuur", title: "Architectuur" },
    { id: "deploy-key", title: "GitHub deploy key instellen", badge: "verplicht" as const },
    { id: "installatie", title: "Installatie", badge: "verplicht" as const },
    { id: "na-installatie", title: "Na installatie", badge: "verplicht" as const },
    { id: "updates", title: "Updates draaien", badge: "wanneer-nodig" as const },
    { id: "data-migratie", title: "Data migreren uit Lovable Cloud", badge: "optioneel" as const },
    { id: "smtp-oauth", title: "SMTP & OAuth instellen" },
    { id: "troubleshooting", title: "Troubleshooting" },
    { id: "backup", title: "Backup" },
  ];

  const splitSteps = [
    { id: "vereisten", title: "Vereisten" },
    { id: "architectuur", title: "Architectuur" },
    { id: "deploy-key", title: "GitHub deploy key instellen", badge: "verplicht" as const },
    { id: "split-backend", title: "Server A — Supabase backend", badge: "verplicht" as const },
    { id: "split-frontend", title: "Server B — React frontend", badge: "verplicht" as const },
    { id: "na-installatie", title: "Na installatie", badge: "verplicht" as const },
    { id: "updates", title: "Updates draaien", badge: "wanneer-nodig" as const },
    { id: "data-migratie", title: "Data migreren uit Lovable Cloud", badge: "optioneel" as const },
    { id: "smtp-oauth", title: "SMTP & OAuth instellen" },
    { id: "troubleshooting", title: "Troubleshooting" },
    { id: "backup", title: "Backup" },
  ];

  const steps = mode === "single" ? singleSteps : splitSteps;

  return (
    <div className="mx-auto max-w-3xl px-6 py-12">
      <h1 className="mb-2 text-3xl font-bold text-foreground">Installatiehandleiding</h1>
      <p className="mb-8 text-muted-foreground">Van lege Proxmox VM tot werkende applicatie — stap voor stap.</p>

      {/* Introductie voor beginners */}
      <div className="mb-8 rounded-lg border border-primary/20 bg-primary/5 p-5">
        <h2 className="mb-2 text-sm font-semibold text-foreground">📖 Voordat je begint</h2>
        <p className="mb-2 text-sm text-muted-foreground">
          In deze handleiding voer je commando's uit op je server via een <strong className="text-foreground">terminal</strong>. 
          Dit doe je door via <InfoTooltip text="Veilige verbinding met je server op afstand, zoals remote desktop maar dan via tekst. Je typt commando's en ziet de output." /> verbinding te maken met je VM:
        </p>
        <CodeBlock fill={fill}>{`ssh root@JOUW-SERVER-IP`}</CodeBlock>
        <p className="text-sm text-muted-foreground">
          Vervang <CopyCode fill={fill}>JOUW-SERVER-IP</CopyCode> door het IP-adres van je Proxmox VM 
          (te vinden in je Proxmox dashboard). Op Windows kun je <a href="https://www.putty.org/" className="text-primary hover:underline" target="_blank" rel="noopener noreferrer">PuTTY</a> of 
          Windows Terminal gebruiken, op Mac/Linux open je gewoon de Terminal app.
        </p>
      </div>

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
            ? "Alles op één VM: React frontend + volledige Supabase stack. Makkelijkst om te beginnen."
            : "Server A draait Supabase (backend), Server B draait de React frontend. Beter schaalbaar."}
        </p>
        <p className="mt-1 text-xs text-primary/80 font-medium">💡 Twijfel je? Kies Single server — je kunt later altijd splitsen.</p>
      </div>

      {/* Distro toggle */}
      <div className="mb-10 rounded-lg border border-border bg-muted/50 p-4">
        <p className="mb-3 text-sm font-medium text-foreground">
          Welke Linux distributie draai je? <InfoTooltip text="Het install-script detecteert dit automatisch, maar de handleiding toont de juiste commando's op basis van je keuze hier." />
        </p>
        <div className="flex gap-2">
          <button
            onClick={() => setDistro("debian")}
            className={`rounded-md px-4 py-2 text-sm font-medium transition-colors ${
              distro === "debian"
                ? "bg-primary text-primary-foreground"
                : "bg-muted text-muted-foreground hover:bg-muted/80"
            }`}
          >
            Ubuntu / Debian
          </button>
          <button
            onClick={() => setDistro("rhel")}
            className={`rounded-md px-4 py-2 text-sm font-medium transition-colors ${
              distro === "rhel"
                ? "bg-primary text-primary-foreground"
                : "bg-muted text-muted-foreground hover:bg-muted/80"
            }`}
          >
            CentOS / AlmaLinux / Rocky
          </button>
        </div>
        <p className="mt-2 text-xs text-muted-foreground">
          {distro === "debian"
            ? "Gebruikt apt, ufw, en /etc/nginx/sites-available/. Aanbevolen: Ubuntu 22.04+ of Debian 11+."
            : "Gebruikt dnf, firewalld, en /etc/nginx/conf.d/. Ondersteund: CentOS Stream 9, AlmaLinux 9, Rocky Linux 9."}
        </p>
      </div>

      {/* User config form */}
      <div className="mb-10 rounded-lg border border-primary/30 bg-primary/5 p-5">
        <div className="mb-3 flex items-center gap-2">
          <Settings className="h-4 w-4 text-primary" />
          <h2 className="text-sm font-semibold text-foreground">Jouw gegevens</h2>
        </div>
        <p className="mb-4 text-xs text-muted-foreground">
          Vul je gegevens in — alle commando's in de handleiding worden automatisch aangepast zodat je ze direct kunt kopiëren en plakken.
        </p>
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <ConfigInput label="GitHub gebruikersnaam" placeholder="JOUW-USER" value={userConfig.githubUser} onChange={v => updateField("githubUser", v)} />
          <ConfigInput label="Repository naam" placeholder="JOUW-REPO" value={userConfig.repoName} onChange={v => updateField("repoName", v)} />
          <ConfigInput label="Server IP" placeholder="JOUW-SERVER-IP" value={userConfig.serverIp} onChange={v => updateField("serverIp", v)} />
          <ConfigInput label="Domeinnaam" placeholder="jouw-domein.nl" value={userConfig.domain} onChange={v => updateField("domain", v)} />
          {mode === "split" && (
            <ConfigInput label="Server A IP (backend)" placeholder="SERVER_A_IP" value={userConfig.serverAIp} onChange={v => updateField("serverAIp", v)} />
          )}
        </div>
      </div>

      {/* Table of contents */}
      <nav className="mb-12 rounded-lg border border-border bg-muted/50 p-5">
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-muted-foreground">Inhoud</h2>
        <ol className="list-inside list-decimal space-y-1 text-sm text-primary">
          {steps.map((step) => (
            <li key={step.id}>
              <a href={`#${step.id}`} className="hover:underline">{step.title}</a>
              {"badge" in step && step.badge && <StepBadge type={step.badge} />}
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
            <li><strong>{distro === "debian" ? "Ubuntu 24.04" : "AlmaLinux 9 / Rocky Linux 9 / CentOS Stream 9"} VM</strong> — minimaal 4GB RAM, 2 vCPU, 20GB disk</li>
          ) : (
            <>
              <li><strong>{distro === "debian" ? "Ubuntu 24.04" : "AlmaLinux 9 / Rocky Linux 9"} VM (Server A)</strong> — minimaal 2GB RAM, 2 vCPU, 20GB disk — voor Supabase</li>
              <li><strong>{distro === "debian" ? "Ubuntu 24.04" : "AlmaLinux 9 / Rocky Linux 9"} VM (Server B)</strong> — minimaal 2GB RAM, 2 vCPU, 10GB disk — voor de frontend</li>
            </>
          )}
          <li><strong><InfoTooltip text="Veilige verbinding met je server op afstand, zoals remote desktop maar dan via tekst." />-toegang</strong> tot de VM{mode === "split" ? "'s" : ""}</li>
          <li><strong>Privé GitHub repo</strong> met je Lovable project (te vinden op <a href="https://github.com" className="text-primary hover:underline" target="_blank" rel="noopener noreferrer">github.com</a>)</li>
          <li><strong>Domeinnaam</strong> (optioneel, kan ook op IP)</li>
        </ul>
        {mode === "split" && (
          <Tip>Zorg dat beide VM's elkaar kunnen bereiken via het interne Proxmox netwerk (vmbr0). Noteer de IP-adressen van beide servers.</Tip>
        )}
      </Step>

      {/* Stap: Architectuur */}
      <Step id="architectuur" number={steps.findIndex(s => s.id === "architectuur") + 1} title="Architectuur">
        <Tip>
          <strong>Wat is Supabase?</strong> Supabase is een complete backend-stack: <InfoTooltip text="De database waar al je data in wordt opgeslagen — tabellen, gebruikers, alles." /> (database), <InfoTooltip text="Supabase service die login, registratie en wachtwoord-reset regelt." /> (authenticatie), <InfoTooltip text="Zet je database automatisch om naar een REST API — je hoeft geen backend-code te schrijven." /> (API), Storage (bestanden) en Realtime (websockets). Al deze services draaien als <InfoTooltip text="Software die in een afgesloten 'doos' draait, zodat het overal hetzelfde werkt — ongeacht het besturingssysteem." /> op je server.
        </Tip>

        {mode === "single" ? (
          <>
            <p>Alles draait op één VM:</p>
            <CodeBlock fill={fill}>{`[VM - 4GB RAM]
├── Nginx (SSL termination + reverse proxy)
│   ├── /           → Node.js frontend (poort 3000)
│   └── /auth, /rest, /storage, /realtime → Kong API Gateway (poort 8000)
│
├── React Frontend (Node.js, Docker container)
│
└── Supabase stack (Docker Compose)
    ├── Kong (API Gateway, poort 8000) ← valideert API keys
    ├── PostgreSQL (database)
    ├── GoTrue (authenticatie/login)
    ├── PostgREST (REST API)
    ├── Storage (bestanden)
    ├── Realtime (websockets)
    └── Studio (admin dashboard, poort 8080)`}</CodeBlock>
            <div className="my-2 flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted-foreground">
              <span><InfoTooltip text="Webserver die bezoekers doorstuurt naar de juiste service op basis van de URL (reverse proxy)." /> = reverse proxy</span>
              <span><InfoTooltip text="API Gateway — controleert of API-verzoeken een geldige sleutel (API key) hebben voordat ze worden doorgestuurd." /> = API Gateway</span>
              <span><InfoTooltip text="Versleutelde verbinding (https) zodat data veilig verstuurd wordt. Gratis via Let's Encrypt." /> = versleuteling</span>
              <span><InfoTooltip text="Tool om meerdere Docker containers tegelijk te starten en beheren met één configuratiebestand." /> = container orchestratie</span>
            </div>
          </>
        ) : (
          <>
            <p>Twee servers, gescheiden verantwoordelijkheden:</p>
            <CodeBlock fill={fill}>{`[Server A - Supabase backend - 2GB RAM]
├── Kong API Gateway (poort 8000) ← Frontend praat hiermee
├── PostgreSQL (database)
├── GoTrue (authenticatie/login)
├── PostgREST (REST API)
├── Storage (bestanden)
├── Realtime (websockets)
├── Studio (admin dashboard, poort 8080)
└── Firewall: poort 8000 alleen open voor Server B

[Server B - React frontend - 2GB RAM]
├── Node.js frontend (Docker container, poort 3000)
├── Nginx (SSL + reverse proxy)
│   ├── /           → localhost:3000 (frontend)
│   └── /auth, /rest, /storage, /realtime → Server A:8000
└── .env → VITE_SUPABASE_URL wijst naar Server A`}</CodeBlock>
            <div className="my-2 flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted-foreground">
              <span><InfoTooltip text="Webserver die bezoekers doorstuurt naar de juiste service (reverse proxy)." /> = reverse proxy</span>
              <span><InfoTooltip text="API Gateway — controleert of API-verzoeken een geldige sleutel hebben." /> = API Gateway</span>
              <span><InfoTooltip text="Bepaalt welke poorten open of dicht staan op je server — beschermt tegen ongewenste toegang." /> = firewall</span>
            </div>
          </>
        )}
      </Step>

      {/* Stap: Deploy key */}
      <Step id="deploy-key" number={steps.findIndex(s => s.id === "deploy-key") + 1} title={<>GitHub <InfoTooltip text="Een SSH-sleutel die alleen leesrechten heeft op één specifieke GitHub repo. Hiermee kan je server de code downloaden zonder wachtwoord." /> instellen <StepBadge type="verplicht" /></>}>
        <p>
          Een <strong>deploy key</strong> is een <InfoTooltip text="Veilige verbinding met je server op afstand, zoals remote desktop maar dan via tekst." />-sleutel waarmee je server je privé GitHub repo kan downloaden zonder wachtwoord. 
          Je maakt een sleutel aan op je server en voegt het publieke deel toe aan GitHub.
        </p>
        {mode === "split" && (
          <Warn>Herhaal deze stap op <strong>beide servers</strong> (A en B). Elke server krijgt een eigen sleutel.</Warn>
        )}

        <Location icon="terminal" text={`Terminal op je ${mode === "split" ? "server (herhaal voor beide)" : "VM"}`} />
        <CodeBlock fill={fill} title="1. SSH key genereren">{`# Genereer een nieuwe SSH key (druk Enter bij alle vragen)
ssh-keygen -t ed25519 -C "deploy@vps" -f ~/.ssh/deploy_key -N ""

# Stel de juiste permissions in (sommige SSH-versies weigeren te brede rechten)
chmod 600 ~/.ssh/deploy_key

# Toon de publieke key — kopieer de hele output
cat ~/.ssh/deploy_key.pub`}</CodeBlock>

        <Location icon="browser" text="GitHub.com — je repository" />
        <ol className="list-inside list-decimal space-y-1">
          <li>Ga naar je repo op GitHub → <strong>Settings</strong> (tandwiel-icoon)</li>
          <li>Klik links op <strong>Deploy keys</strong> → <strong>Add deploy key</strong></li>
          <li>Geef een naam (bijv. "VPS{mode === "split" ? " - Server A" : ""}") en plak de key die je net hebt gekopieerd</li>
          <li>Laat <strong>"Allow write access"</strong> uitgevinkt</li>
          <li>Klik <strong>Add key</strong></li>
        </ol>

        <Location icon="terminal" text={`Terminal op je ${mode === "split" ? "server" : "VM"}`} />
        <CodeBlock fill={fill} title="2. SSH config aanmaken">{`# Maak een SSH config zodat git de juiste key gebruikt
cat > ~/.ssh/config << 'EOF'
Host github.com
  IdentityFile ~/.ssh/deploy_key
  IdentitiesOnly yes
EOF
chmod 600 ~/.ssh/config`}</CodeBlock>

        <Warn>
          Als je al andere SSH keys hebt (bijv. <CopyCode fill={fill}>id_ed25519</CopyCode> of <CopyCode fill={fill}>id_rsa</CopyCode>), kan SSH die per ongeluk gebruiken in plaats van je deploy key. 
          De regel <CopyCode fill={fill}>IdentitiesOnly yes</CopyCode> in de config hierboven voorkomt dit. Controleer met: <CopyCode fill={fill}>ls ~/.ssh/*.pub</CopyCode>
        </Warn>

        <CodeBlock fill={fill} title="3. Verbinding testen">{`# Test de verbinding — bekijk welke key SSH aanbiedt
ssh -vT git@github.com 2>&1 | grep "Offering\\|authenticated"

# Als bovenstaande niet werkt, forceer de deploy key:
ssh -T -i ~/.ssh/deploy_key git@github.com`}</CodeBlock>

        <div className="rounded-lg border border-border overflow-hidden text-sm">
          <table className="w-full">
            <thead>
              <tr className="bg-muted/50">
                <th className="px-3 py-2 text-left font-medium">Foutmelding</th>
                <th className="px-3 py-2 text-left font-medium">Betekenis</th>
                <th className="px-3 py-2 text-left font-medium">Oplossing</th>
              </tr>
            </thead>
            <tbody>
              <tr className="border-t border-border">
                <td className="px-3 py-2 font-mono text-xs">"Hi USERNAME! You've successfully authenticated"</td>
                <td className="px-3 py-2 text-green-600 dark:text-green-400">✅ Alles werkt</td>
                <td className="px-3 py-2">Ga door naar de clone stap</td>
              </tr>
              <tr className="border-t border-border">
                <td className="px-3 py-2 font-mono text-xs">"Repository not found"</td>
                <td className="px-3 py-2">SSH werkt, maar de key heeft geen toegang tot deze repo</td>
                <td className="px-3 py-2">Controleer of de deploy key aan de <strong>juiste repo</strong> is toegevoegd op GitHub</td>
              </tr>
              <tr className="border-t border-border">
                <td className="px-3 py-2 font-mono text-xs">"Permission denied (publickey)"</td>
                <td className="px-3 py-2">SSH kan helemaal niet authenticeren</td>
                <td className="px-3 py-2">De key wordt niet gevonden — controleer <CopyCode fill={fill}>~/.ssh/config</CopyCode> en <CopyCode fill={fill}>chmod 600</CopyCode></td>
              </tr>
            </tbody>
          </table>
        </div>
      </Step>

      {/* === SINGLE MODE: Installatie === */}
      {mode === "single" && (
        <Step id="installatie" number={steps.findIndex(s => s.id === "installatie") + 1} title={<>Installatie <StepBadge type="verplicht" /></>}>
          <Location icon="terminal" text="Terminal op je VM" />
          <p>Clone je repo en draai het install-script:</p>
          <Warn>Gebruik <strong>niet</strong> <CopyCode fill={fill}>sudo git clone</CopyCode> — sudo draait als root en heeft geen toegang tot jouw SSH key. Maak eerst de map aan, dan clone je als gewone gebruiker.</Warn>
          <CodeBlock fill={fill}>{`# Maak de map aan en geef jezelf rechten
sudo mkdir -p /opt/lovable-app
sudo chown $USER:$USER /opt/lovable-app

# Clone als huidige gebruiker (die de SSH key heeft)
git clone git@github.com:JOUW-USER/JOUW-REPO.git /opt/lovable-app

# Start de installer
cd /opt/lovable-app
sudo bash install.sh`}</CodeBlock>
          <Tip>
            <strong>JOUW-USER</strong> = je GitHub gebruikersnaam (bijv. <CopyCode fill={fill}>jandevries</CopyCode>)<br />
            <strong>JOUW-REPO</strong> = de naam van je repository (bijv. <CopyCode fill={fill}>mijn-app</CopyCode>)<br />
            Je vindt dit in de URL van je repo: github.com/<strong>JOUW-USER</strong>/<strong>JOUW-REPO</strong>
          </Tip>
          <p>Het script vraagt om:</p>
          <ul className="list-inside list-disc space-y-1">
            <li><strong>Installatiemodus</strong> — kies <CopyCode fill={fill}>1) Volledige installatie</CopyCode></li>
            <li><strong>Domeinnaam</strong> — bijv. <CopyCode fill={fill}>mijnapp.nl</CopyCode> of laat leeg voor IP</li>
            <li><strong>Admin e-mail</strong> — voor het <InfoTooltip text="Versleutelde verbinding (https) zodat data veilig verstuurd wordt. Let's Encrypt geeft gratis SSL-certificaten uit." /> certificaat</li>
            <li><strong>Database wachtwoord</strong> — kies iets sterks, je hebt dit later nodig</li>
            <li><strong>Dashboard wachtwoord</strong> — voor Supabase Studio (admin paneel)</li>
          </ul>
          <p className="mt-2">Het script doet de rest: het detecteert automatisch of je {distro === "debian" ? "Ubuntu/Debian" : "CentOS/AlmaLinux/Rocky"} draait en installeert de juiste packages ({distro === "debian" ? "apt" : "dnf"}), <InfoTooltip text="Software die in een afgesloten 'doos' draait, zodat het overal hetzelfde werkt — ongeacht het besturingssysteem." />, secrets genereren, containers starten, <InfoTooltip text="Webserver die bezoekers doorstuurt naar de juiste service (reverse proxy)." /> + SSL en firewall ({distro === "debian" ? "UFW" : "firewalld"}).</p>
          <Warn>Het script zet <CopyCode fill={fill}>GOTRUE_MAILER_AUTOCONFIRM: true</CopyCode>. Dit bevestigt e-mailadressen automatisch zonder verificatie-email. Voor productie: stel <InfoTooltip text="Protocol voor het versturen van e-mails — nodig voor verificatie-mails en wachtwoord-reset." /> in (stap {steps.findIndex(s => s.id === "smtp-oauth") + 1}) en zet dit op <CopyCode fill={fill}>false</CopyCode>.</Warn>
        </Step>
      )}

      {/* === SPLIT MODE: Server A (Backend) === */}
      {mode === "split" && (
        <Step id="split-backend" number={steps.findIndex(s => s.id === "split-backend") + 1} title="Server A — Supabase backend">
          <Location icon="terminal" text="Terminal op Server A" />
          <p>Op Server A draai je de volledige Supabase stack (database, login, API, opslag):</p>
          <Warn>Gebruik <strong>niet</strong> <CopyCode fill={fill}>sudo git clone</CopyCode> — sudo draait als root en heeft geen toegang tot jouw SSH key.</Warn>
          <CodeBlock fill={fill}>{`# Maak de map aan en geef jezelf rechten
sudo mkdir -p /opt/lovable-app
sudo chown $USER:$USER /opt/lovable-app

# Clone als huidige gebruiker
git clone git@github.com:JOUW-USER/JOUW-REPO.git /opt/lovable-app

# Start de installer
cd /opt/lovable-app
sudo bash install.sh

# Kies: 2) Alleen database (Supabase stack)`}</CodeBlock>
          <p>Het script start alle Supabase containers en <InfoTooltip text="API Gateway — controleert of API-verzoeken een geldige sleutel hebben voordat ze worden doorgestuurd naar de juiste service." /> (API Gateway op poort 8000).</p>

          <h4 className="mt-4 font-semibold text-foreground"><InfoTooltip text="Bepaalt welke poorten open of dicht staan op je server — beschermt tegen ongewenste toegang van buitenaf." /> instellen</h4>
          <p>Beperk toegang tot de API Gateway zodat alleen Server B erbij kan:</p>
          {distro === "debian" ? (
            <CodeBlock fill={fill}>{`# Vervang SERVER_B_IP met het IP-adres van je frontend-server
# Voorbeeld: sudo ufw allow from 192.168.1.20 to any port 8000
sudo ufw allow from SERVER_B_IP to any port 8000`}</CodeBlock>
          ) : (
            <CodeBlock fill={fill}>{`# Vervang SERVER_B_IP met het IP-adres van je frontend-server
# Voorbeeld: sudo firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=192.168.1.20 port port=8000 protocol=tcp accept'
sudo firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=SERVER_B_IP port port=8000 protocol=tcp accept'
sudo firewall-cmd --reload`}</CodeBlock>
          )}
          <Warn>
            <strong>Belangrijk!</strong> Noteer de <strong><InfoTooltip text="Publieke sleutel waarmee de frontend met de Supabase API praat. Dit is geen geheim — hij wordt in de browser gebruikt." /></strong> die het script aan het einde toont — 
            die heb je nodig bij het installeren van Server B. Je vindt deze ook terug in <CopyCode fill={fill}>/opt/supabase/credentials.txt</CopyCode>.
          </Warn>
          <Warn>Zet poort 8000 <strong>niet</strong> open voor iedereen. Beperk het tot het IP van Server B.</Warn>
        </Step>
      )}

      {/* === SPLIT MODE: Server B (Frontend) === */}
      {mode === "split" && (
        <Step id="split-frontend" number={steps.findIndex(s => s.id === "split-frontend") + 1} title="Server B — React frontend">
          <Location icon="terminal" text="Terminal op Server B" />
          <p>Op Server B draait alleen de React app — geen database, geen Supabase services:</p>
          <CodeBlock fill={fill}>{`# Maak de map aan en geef jezelf rechten
sudo mkdir -p /opt/lovable-app
sudo chown $USER:$USER /opt/lovable-app

# Clone als huidige gebruiker
git clone git@github.com:JOUW-USER/JOUW-REPO.git /opt/lovable-app

# Start de installer
cd /opt/lovable-app
sudo bash install.sh

# Kies: 3) Alleen frontend
# Voer het IP-adres van Server A in wanneer gevraagd
# Voer de Anon Key in die je bij Server A hebt genoteerd`}</CodeBlock>
          <p>Het script bouwt de React app als <InfoTooltip text="Software die in een afgesloten 'doos' draait, zodat het overal hetzelfde werkt." />, configureert <InfoTooltip text="Webserver die bezoekers doorstuurt naar de juiste service (reverse proxy)." /> als reverse proxy en regelt SSL.</p>
        </Step>
      )}

      {/* Stap: Na installatie */}
      <Step id="na-installatie" number={steps.findIndex(s => s.id === "na-installatie") + 1} title={<>Na installatie <StepBadge type="verplicht" /></>}>
        <p>Controleer of alles werkt:</p>
        {mode === "single" ? (
          <>
            <Location icon="terminal" text="Terminal op je VM" />
            <CodeBlock fill={fill}>{`# Bekijk alle draaiende containers (je zou 8+ containers moeten zien)
docker ps

# Test of de frontend reageert
curl -I http://localhost:3000

# Test de Supabase API (vervang JOUW_ANON_KEY)
curl http://localhost:8000/rest/v1/ -H "apikey: JOUW_ANON_KEY"`}</CodeBlock>
            <Location icon="browser" text="Browser op je eigen computer" />
            <CodeBlock fill={fill}>{`# Open deze adressen in je browser:
https://jouw-domein.nl        → je app
https://jouw-domein.nl:8080   → Supabase Studio (admin paneel)`}</CodeBlock>
          </>
        ) : (
          <>
            <Location icon="terminal" text="Terminal op Server A (backend)" />
            <CodeBlock fill={fill}>{`# Controleer of alle Supabase containers draaien
docker ps

# Test de API
curl http://localhost:8000/rest/v1/ -H "apikey: JOUW_ANON_KEY"

# Studio openen in browser: http://SERVER_A_IP:8080`}</CodeBlock>
            <Location icon="terminal" text="Terminal op Server B (frontend)" />
            <CodeBlock fill={fill}>{`# Controleer of de frontend draait
docker ps
curl -I http://localhost:3000

# Test of de API via Nginx bereikbaar is
curl http://localhost/rest/v1/ -H "apikey: JOUW_ANON_KEY"`}</CodeBlock>
            <Location icon="browser" text="Browser op je eigen computer" />
            <p>Open <CopyCode fill={fill}>https://jouw-domein.nl</CopyCode> — je zou je app moeten zien.</p>
          </>
        )}
      </Step>

      {/* Stap: Updates */}
      <Step id="updates" number={steps.findIndex(s => s.id === "updates") + 1} title={<>Updates draaien <StepBadge type="wanneer-nodig" /></>}>
        <p className="italic text-muted-foreground">Je hoeft dit alleen te doen nadat je wijzigingen hebt gemaakt in Lovable. Geen wijzigingen? Dan kun je deze stap overslaan.</p>
        <p>Na wijzigingen in Lovable (die automatisch naar GitHub pusht):</p>
        {mode === "single" ? (
          <>
            <Location icon="terminal" text="Terminal op je VM" />
            <CodeBlock fill={fill}>{`# Eén commando om alles te updaten:
lovable-update

# Of handmatig:
cd /opt/lovable-app
git pull
docker build -t lovable-frontend -f Dockerfile .
docker stop lovable-frontend && docker rm lovable-frontend
docker run -d --name lovable-frontend --restart unless-stopped -p 3000:3000 lovable-frontend`}</CodeBlock>
          </>
        ) : (
          <>
            <Location icon="terminal" text="Terminal op Server B (frontend)" />
            <CodeBlock fill={fill}>{`# Update de frontend:
lovable-update

# Dit doet: git pull → docker build → restart container`}</CodeBlock>
            <Location icon="terminal" text="Terminal op Server A (alleen bij database-wijzigingen)" />
            <CodeBlock fill={fill}>{`# Nieuwe migraties toepassen:
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
      <Step id="data-migratie" number={steps.findIndex(s => s.id === "data-migratie") + 1} title={<>Data migreren uit Lovable Cloud <StepBadge type="optioneel" /></>}>
        <p className="italic text-muted-foreground">Alleen nodig als je bestaande data hebt in Lovable Cloud. Start je een nieuwe app zonder bestaande data? Sla deze stap over en ga door naar de volgende.</p>
        <p>Als je bestaande data hebt in Lovable Cloud kun je die overzetten:</p>

        <Location icon="browser" text="Lovable.dev in je browser" />
        <ol className="list-inside list-decimal space-y-2">
          <li>Ga naar <strong>Lovable → Cloud → Database → Tables</strong></li>
          <li>Exporteer elke tabel als CSV</li>
        </ol>

        <Location icon="terminal" text={`Terminal op je ${mode === "split" ? "backend-server (A)" : "server"}`} />
        <ol className="list-inside list-decimal space-y-2" start={3}>
          <li>Kopieer de CSV-bestanden naar je server en importeer ze:</li>
        </ol>
        <CodeBlock fill={fill}>{`# Kopieer CSV van je computer naar de server
# (draai dit op je EIGEN computer, niet op de server)
scp tabel.csv root@jouw-server:/tmp/

# Importeer in PostgreSQL (draai dit op de SERVER)
# Vervang "tabel_naam" met de naam van je tabel
cat /tmp/tabel.csv | docker exec -i supabase-db psql -U supabase -d postgres \\
  -c "\\COPY public.tabel_naam FROM STDIN WITH CSV HEADER"`}</CodeBlock>
        <Tip>Het <InfoTooltip text="Bestanden kopiëren tussen je computer en een server via SSH — zoals slepen naar een USB-stick, maar dan over het netwerk." />-commando draai je op je eigen computer (niet op de server). Het kopieert een bestand via SSH naar de server.</Tip>
        <Warn>Gebruikerswachtwoorden kunnen niet gemigreerd worden. Gebruikers moeten een wachtwoord-reset doen na migratie.</Warn>
      </Step>

      {/* Stap: SMTP & OAuth */}
      <Step id="smtp-oauth" number={steps.findIndex(s => s.id === "smtp-oauth") + 1} title={<><InfoTooltip text="Protocol voor het versturen van e-mails — nodig voor verificatie-mails en wachtwoord-reset." /> & <InfoTooltip text="Inloggen via een derde partij zoals Google — gebruikers hoeven geen apart wachtwoord aan te maken." /> instellen</>}>

        {/* SMTP — Aanbevolen */}
        <div className="rounded-lg border border-destructive/30 bg-destructive/5 p-4">
          <div className="mb-2 flex items-center gap-2">
            <span className="rounded bg-destructive px-2 py-0.5 text-xs font-semibold text-destructive-foreground">Aanbevolen voor productie</span>
            <h4 className="font-semibold text-foreground">E-mail (<InfoTooltip text="Protocol voor het versturen van e-mails. Je hebt een SMTP-server nodig om verificatie-mails en wachtwoord-resets te versturen." />)</h4>
          </div>
          <Warn>Zonder SMTP staat e-mail autoconfirm aan — iedereen kan zich registreren zonder verificatie. Stel SMTP in zodra je app live gaat!</Warn>

          <Location icon="terminal" text={`Terminal op je ${mode === "split" ? "backend-server (A)" : "VM"}`} />
          <p>Bewerk de Supabase environment file:</p>
          <CodeBlock fill={fill}>{`sudo nano /opt/supabase/.env

# Pas deze regels aan met je eigen SMTP gegevens:
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
          <Tip>Voor Gmail: gebruik een <a href="https://myaccount.google.com/apppasswords" className="text-primary hover:underline" target="_blank" rel="noopener noreferrer">App-wachtwoord</a>, niet je gewone wachtwoord. Je hebt 2FA nodig om een App-wachtwoord aan te maken.</Tip>
        </div>

        {/* Google OAuth — Optioneel */}
        <div className="mt-6 rounded-lg border border-border bg-muted/30 p-4">
          <div className="mb-2 flex items-center gap-2">
            <span className="rounded bg-muted px-2 py-0.5 text-xs font-semibold text-muted-foreground">Optioneel</span>
            <h4 className="font-semibold text-foreground">Google <InfoTooltip text="Inloggen via een derde partij zoals Google — gebruikers hoeven geen apart wachtwoord aan te maken." /> (inloggen met Google)</h4>
          </div>
          <p className="mb-3 text-sm text-muted-foreground">
            Dit is optioneel. Als je app geen "Inloggen met Google"-knop nodig heeft, kun je deze stap overslaan en doorgaan naar de volgende stap. Je app werkt prima met alleen e-mail/wachtwoord login.
          </p>

          <Location icon="browser" text="Google Cloud Console" />
          <ol className="list-inside list-decimal space-y-1">
            <li>Ga naar <a href="https://console.cloud.google.com" className="text-primary hover:underline" target="_blank" rel="noopener noreferrer">Google Cloud Console</a></li>
            <li>Maak OAuth 2.0 credentials aan (APIs & Services → Credentials)</li>
            <li>Redirect URI: <CopyCode fill={fill}>https://jouw-domein.nl/auth/v1/callback</CopyCode></li>
          </ol>

          <Location icon="terminal" text={`Terminal op je ${mode === "split" ? "backend-server (A)" : "VM"}`} />
          <ol className="list-inside list-decimal space-y-1" start={4}>
            <li>Voeg de credentials toe aan de Supabase config:</li>
          </ol>
          <CodeBlock fill={fill}>{`sudo nano /opt/supabase/.env

# Voeg deze regels toe:
GOTRUE_EXTERNAL_GOOGLE_ENABLED=true
GOTRUE_EXTERNAL_GOOGLE_CLIENT_ID=jouw-client-id
GOTRUE_EXTERNAL_GOOGLE_SECRET=jouw-secret
GOTRUE_EXTERNAL_GOOGLE_REDIRECT_URI=https://jouw-domein.nl/auth/v1/callback

# Herstart auth
cd /opt/supabase && docker compose restart auth`}</CodeBlock>
        </div>
      </Step>

      {/* Stap: Troubleshooting */}
      <Step id="troubleshooting" number={steps.findIndex(s => s.id === "troubleshooting") + 1} title="Troubleshooting">
        <div className="space-y-4">
          <TroubleItem q="Container start niet op" a={`Check logs: docker logs supabase-db (of andere containernaam). Vaak een verkeerd wachtwoord of poort-conflict.`} />
          <TroubleItem q="Frontend laadt niet" a="Check of de container draait: docker ps. Test lokaal: curl http://localhost:3000. Check Nginx config: sudo nginx -t" />
          <TroubleItem q="SSL werkt niet" a={distro === "debian" ? "Controleer of poort 80 en 443 open staan in Proxmox firewall én UFW. Draai opnieuw: sudo certbot --nginx -d jouw-domein.nl" : "Controleer of poort 80 en 443 open staan in Proxmox firewall én firewalld (sudo firewall-cmd --list-all). Draai opnieuw: sudo certbot --nginx -d jouw-domein.nl"} />
          <TroubleItem q="Database connectie mislukt" a={`Check of PostgreSQL draait: docker exec supabase-db pg_isready -U supabase.${mode === "split" ? " Bij split: check of poort 8000 open staat op Server A met: curl http://SERVER_A_IP:8000/rest/v1/" : ""}`} />
          <TroubleItem q="Git pull mislukt" a="Check deploy key: ssh -T git@github.com. Controleer ~/.ssh/config. Zorg dat de deploy key op GitHub staat." />
          <TroubleItem q="Supabase API geeft 401" a="Controleer of ANON_KEY in .env.production (frontend) overeenkomt met de key in /opt/supabase/.env (backend). Deze moeten exact gelijk zijn." />
          {mode === "split" && (
            <TroubleItem q="Frontend kan Server A niet bereiken" a="Check firewall op Server A: sudo ufw status. Test verbinding: curl http://SERVER_A_IP:8000/rest/v1/. Poort 8000 moet open staan voor het IP van Server B." />
          )}
          <TroubleItem q="'Permission denied' bij commando's" a="Gebruik sudo voor commando's die root-rechten nodig hebben, bijv: sudo bash install.sh" />
        </div>
      </Step>

      {/* Stap: Backup */}
      <Step id="backup" number={steps.findIndex(s => s.id === "backup") + 1} title="Backup">
        <Location icon="terminal" text={`Terminal op je ${mode === "split" ? "backend-server (A)" : "VM"}`} />

        {/* Database dump — Aanbevolen */}
        <div className="rounded-lg border border-destructive/30 bg-destructive/5 p-4">
          <div className="mb-2 flex items-center gap-2">
            <span className="rounded bg-destructive px-2 py-0.5 text-xs font-semibold text-destructive-foreground">Aanbevolen</span>
            <h4 className="font-semibold text-foreground">Database backup</h4>
          </div>
          <p>Maak regelmatig backups van je database:</p>
        <CodeBlock fill={fill} title="Database dump">{`# Maak eerst de backup-map aan
sudo mkdir -p /opt/backups

# Volledige backup
docker exec supabase-db pg_dump -U supabase postgres > /opt/backups/backup_$(date +%Y%m%d).sql

# Backup met compressie (kleiner bestand)
docker exec supabase-db pg_dump -U supabase -Fc postgres > /opt/backups/backup_$(date +%Y%m%d).dump

# Restore (terugzetten)
docker exec -i supabase-db psql -U supabase -d postgres < /opt/backups/backup_20240101.sql`}</CodeBlock>

        </div>

        {/* Automatische backup + Storage — Optioneel */}
        <div className="mt-4 rounded-lg border border-border bg-muted/30 p-4">
          <div className="mb-2 flex items-center gap-2">
            <span className="rounded bg-muted px-2 py-0.5 text-xs font-semibold text-muted-foreground">Optioneel</span>
            <h4 className="font-semibold text-foreground">Automatische & storage backup</h4>
          </div>
          <p className="mb-3 text-sm text-muted-foreground">Handig maar niet strikt noodzakelijk. Je kunt deze stap overslaan als je handmatige backups maakt.</p>

        <CodeBlock fill={fill} title={<>Automatische backup (<InfoTooltip text="Geplande taken die automatisch draaien op vaste tijden — zoals een wekker voor je server." />)</>}>{`# Open de cron-editor
sudo crontab -e

# Voeg deze regel toe (dagelijkse backup om 3:00 's nachts):
0 3 * * * mkdir -p /opt/backups && docker exec supabase-db pg_dump -U supabase -Fc postgres > /opt/backups/db_$(date +\\%Y\\%m\\%d).dump 2>&1`}</CodeBlock>

        <CodeBlock fill={fill} title="Storage backup (geüploade bestanden)">{`# Supabase Storage bestanden backuppen
tar -czf /opt/backups/storage_backup_$(date +%Y%m%d).tar.gz /opt/supabase/volumes/storage/`}</CodeBlock>
        </div>

        <Tip>Bewaar backups op een andere locatie — gebruik <CopyCode fill={fill}>rsync</CopyCode> of <InfoTooltip text="Bestanden kopiëren tussen je computer en een server via SSH." /> naar een andere Proxmox VM of externe opslag.</Tip>
      </Step>

      <footer className="mt-16 border-t border-border pt-8 pb-12 text-center text-sm text-muted-foreground">
        Lovable VPS Installer — Self-hosted deployment toolkit
      </footer>
    </div>
  );
}

/* ── Helper components ── */

function InfoTooltip({ text }: { text: string }) {
  return (
    <span className="relative inline-flex items-center group cursor-help align-baseline">
      <Info className="h-3.5 w-3.5 text-muted-foreground/60 group-hover:text-primary transition-colors" />
      <span className="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 hidden group-hover:block w-60 rounded-md border border-border bg-popover p-2.5 text-xs leading-relaxed text-popover-foreground shadow-md z-50 pointer-events-none">
        {text}
      </span>
    </span>
  );
}

function Step({ id, number, title, children }: { id: string; number: number; title: React.ReactNode; children: React.ReactNode }) {
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

function Location({ icon, text }: { icon: "terminal" | "browser" | "computer"; text: string }) {
  const IconComponent = icon === "terminal" ? Terminal : icon === "browser" ? Globe : Monitor;
  return (
    <div className="my-3 flex items-center gap-2 rounded-md border border-border bg-muted/40 px-3 py-2 text-xs font-medium text-foreground">
      <IconComponent className="h-3.5 w-3.5 text-primary" />
      <span>📍 {text}</span>
    </div>
  );
}

function CodeBlock({ children, title, fill }: { children: string; title?: React.ReactNode; fill?: (t: string) => string }) {
  const [copied, setCopied] = useState(false);
  const displayed = fill ? fill(children) : children;

  const handleCopy = async () => {
    await navigator.clipboard.writeText(displayed);
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
        className="absolute top-2 right-2 rounded-md border border-border bg-background p-1.5 text-muted-foreground transition-colors hover:text-foreground"
        title="Kopiëren"
      >
        {copied ? <Check className="h-3.5 w-3.5 text-green-500" /> : <Copy className="h-3.5 w-3.5" />}
      </button>
      <pre className="p-4 text-xs leading-relaxed text-foreground"><code>{displayed}</code></pre>
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

function StepBadge({ type }: { type: "verplicht" | "aanbevolen" | "optioneel" | "wanneer-nodig" }) {
  const config = {
    verplicht: { label: "Verplicht", className: "bg-primary text-primary-foreground" },
    aanbevolen: { label: "Aanbevolen", className: "bg-destructive text-destructive-foreground" },
    optioneel: { label: "Optioneel", className: "bg-muted text-muted-foreground" },
    "wanneer-nodig": { label: "Wanneer nodig", className: "bg-accent text-accent-foreground border border-border" },
  };
  const { label, className } = config[type];
  return <span className={`ml-2 rounded px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide ${className}`}>{label}</span>;
}

function CopyCode({ children, fill }: { children: string; fill?: (t: string) => string }) {
  const [copied, setCopied] = useState(false);
  const displayed = fill ? fill(children) : children;

  const handleCopy = async () => {
    await navigator.clipboard.writeText(displayed);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  };

  return (
    <code
      onClick={handleCopy}
      className={`cursor-pointer rounded px-1.5 py-0.5 text-xs transition-colors ${
        copied
          ? "bg-primary/20 text-primary"
          : "bg-muted text-foreground hover:bg-primary/10"
      }`}
      title="Klik om te kopiëren"
    >
      {copied ? "✓ Gekopieerd!" : displayed}
    </code>
  );
}

function ConfigInput({ label, placeholder, value, onChange }: { label: string; placeholder: string; value: string; onChange: (v: string) => void }) {
  return (
    <div>
      <label className="mb-1 block text-xs font-medium text-muted-foreground">{label}</label>
      <input
        type="text"
        value={value}
        onChange={e => onChange(e.target.value)}
        placeholder={placeholder}
        className="w-full rounded-md border border-border bg-background px-3 py-1.5 text-sm text-foreground placeholder:text-muted-foreground/50 focus:outline-none focus:ring-1 focus:ring-ring"
      />
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
