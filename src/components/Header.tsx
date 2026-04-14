import { Link } from "@tanstack/react-router";
import { Server, BookOpen } from "lucide-react";

export function Header() {
  return (
    <header className="sticky top-0 z-50 border-b border-border/40 bg-background/80 backdrop-blur-lg">
      <div className="mx-auto flex h-14 max-w-5xl items-center justify-between px-6">
        <Link to="/" className="flex items-center gap-2 font-semibold text-foreground">
          <Server className="h-5 w-5 text-primary" />
          <span>Lovable VPS</span>
        </Link>
        <nav className="flex items-center gap-6 text-sm">
          <Link
            to="/"
            activeOptions={{ exact: true }}
            activeProps={{ className: "text-foreground font-medium" }}
            inactiveProps={{ className: "text-muted-foreground hover:text-foreground transition-colors" }}
          >
            Home
          </Link>
          <Link
            to="/handleiding"
            activeProps={{ className: "text-foreground font-medium" }}
            inactiveProps={{ className: "text-muted-foreground hover:text-foreground transition-colors" }}
          >
            <span className="flex items-center gap-1.5">
              <BookOpen className="h-4 w-4" />
              Handleiding
            </span>
          </Link>
        </nav>
      </div>
    </header>
  );
}
