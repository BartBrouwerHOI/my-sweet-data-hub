import { createFileRoute, Link } from "@tanstack/react-router";
import { Server, Database, Globe, ArrowRight, Shield, RefreshCw } from "lucide-react";
import { Button } from "@/components/ui/button";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Lovable VPS — Self-Hosted Deployment" },
      { name: "description", content: "Deploy je Lovable app met Supabase op je eigen Proxmox server. Eén script, volledig automatisch." },
      { property: "og:title", content: "Lovable VPS — Self-Hosted Deployment" },
      { property: "og:description", content: "Deploy je Lovable app met Supabase op je eigen Proxmox server." },
    ],
  }),
  component: Index,
});

function Index() {
  return (
    <div className="min-h-[calc(100vh-3.5rem)]">
      {/* Hero */}
      <section className="flex flex-col items-center justify-center gap-6 px-6 py-24 text-center">
        <div className="inline-flex items-center gap-2 rounded-full border border-border bg-muted/50 px-4 py-1.5 text-xs font-medium text-muted-foreground">
          <span className="h-1.5 w-1.5 rounded-full bg-green-500" />
          Open source · Self-hosted
        </div>
        <h1 className="max-w-2xl text-4xl font-bold tracking-tight text-foreground sm:text-5xl">
          Je Lovable app op je <span className="text-primary">eigen server</span>
        </h1>
        <p className="max-w-lg text-lg text-muted-foreground">
          Eén install-script zet alles op: frontend, Supabase, database, SSL.
          Draait op Proxmox, updates via GitHub.
        </p>
        <div className="flex gap-3">
          <Button asChild size="lg">
            <Link to="/handleiding">
              Bekijk de handleiding
              <ArrowRight className="ml-1 h-4 w-4" />
            </Link>
          </Button>
        </div>
      </section>

      {/* Architecture */}
      <section className="border-t border-border bg-muted/30 px-6 py-20">
        <div className="mx-auto max-w-4xl">
          <h2 className="mb-12 text-center text-2xl font-semibold text-foreground">Hoe het werkt</h2>
          <div className="grid gap-6 sm:grid-cols-3">
            <FeatureCard
              icon={<Server className="h-6 w-6" />}
              title="Single of Split"
              description="Alles op één VM, of database en frontend apart. Jij kiest."
            />
            <FeatureCard
              icon={<Database className="h-6 w-6" />}
              title="Volledige Supabase"
              description="PostgreSQL, Auth, Storage, Realtime — allemaal self-hosted via Docker."
            />
            <FeatureCard
              icon={<RefreshCw className="h-6 w-6" />}
              title="Git Pull = Update"
              description="Push in Lovable, pull op je server. Eén commando, klaar."
            />
          </div>
        </div>
      </section>

      {/* Diagram */}
      <section className="px-6 py-20">
        <div className="mx-auto max-w-3xl">
          <h2 className="mb-8 text-center text-2xl font-semibold text-foreground">Architectuur</h2>
          <div className="overflow-x-auto rounded-lg border border-border bg-muted/50 p-6">
            <pre className="text-sm leading-relaxed text-muted-foreground">
{`/opt/lovable-infra/   ← Publieke infra-repo (HTTPS, geen key nodig)
│  install.sh, Dockerfiles, docker-compose.yml, kong.yml
│
/opt/lovable-app/     ← Jouw app-repo (privé, deploy key)
│  package.json, src/, supabase/migrations/
│
Browser → Nginx (SSL/443)
          ├── /          → Frontend container (SPA of SSR)
          └── /auth      → Supabase Auth (GoTrue)
              /rest      → PostgREST (API)
              /storage   → Supabase Storage
              /realtime  → Supabase Realtime
                           └── PostgreSQL 15`}
            </pre>
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="border-t border-border bg-muted/30 px-6 py-20">
        <div className="mx-auto grid max-w-4xl gap-6 sm:grid-cols-2">
          <FeatureCard
            icon={<Shield className="h-6 w-6" />}
            title="SSL automatisch"
            description="Let's Encrypt wordt automatisch geconfigureerd bij installatie."
          />
          <FeatureCard
            icon={<Globe className="h-6 w-6" />}
            title="SPA + SSR"
            description="Automatische detectie: Vite SPA of TanStack Start SSR. Kiest het juiste Dockerfile."
          />
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-border px-6 py-8 text-center text-sm text-muted-foreground">
        Lovable VPS Installer · Self-hosted deployment toolkit
      </footer>
    </div>
  );
}

function FeatureCard({ icon, title, description }: { icon: React.ReactNode; title: string; description: string }) {
  return (
    <div className="rounded-lg border border-border bg-background p-6">
      <div className="mb-3 text-primary">{icon}</div>
      <h3 className="mb-1 font-semibold text-foreground">{title}</h3>
      <p className="text-sm text-muted-foreground">{description}</p>
    </div>
  );
}
