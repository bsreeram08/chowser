import { Link } from 'react-router-dom';
import { Github } from 'lucide-react';
import { Button, buttonVariants } from "@/components/ui/button";
import { cn } from "@/lib/utils";

export const Navbar = () => {
    return (
        <nav className="fixed top-0 w-full z-50 border-b border-border/50 bg-background/70 backdrop-blur-xl">
            <div className="max-w-7xl mx-auto px-4 h-16 flex items-center justify-between">
                <Link to="/" className="flex items-center gap-2 group">
                    <div className="w-8 h-8 rounded-lg bg-primary flex items-center justify-center text-primary-foreground transform group-hover:scale-105 transition-transform">
                        <svg viewBox="0 0 24 24" className="w-5 h-5 fill-current">
                            <path d="M12 2L4.5 20.29l.71.71L12 18l6.79 3 .71-.71L12 2z" />
                        </svg>
                    </div>
                    <span className="font-bold text-lg tracking-tight text-foreground">Chowser</span>
                </Link>
                <div className="flex items-center gap-1 sm:gap-6">
                    <Link to="/agentic-setup">
                        <Button variant="ghost" size="sm" className="text-muted-foreground hover:text-foreground">AI Setup</Button>
                    </Link>
                    <Link to="/security-setup">
                        <Button variant="ghost" size="sm" className="text-muted-foreground hover:text-foreground">Security</Button>
                    </Link>
                    <div className="w-px h-4 bg-border/20 hidden sm:block mx-2" />
                    <a
                        href="https://github.com/bsreeram08/chowser"
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-muted-foreground hover:text-foreground transition-colors"
                    >
                        <Github className="w-5 h-5" />
                    </a>
                    <a
                        href="https://github.com/bsreeram08/chowser/releases/latest"
                        target="_blank"
                        rel="noopener noreferrer"
                        className={cn(buttonVariants({ variant: "outline", size: "sm" }), "hidden sm:flex border-primary/20 hover:border-primary/40 bg-primary/5 hover:bg-primary/10")}
                    >
                        Download
                    </a>
                </div>
            </div>
        </nav>
    );
};
