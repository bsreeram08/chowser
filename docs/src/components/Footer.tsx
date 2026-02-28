import { Link } from 'react-router-dom';

export const Footer = () => {
    return (
        <footer className="border-t border-border/50 bg-background/50 py-12 px-4">
            <div className="max-w-7xl mx-auto flex flex-col md:flex-row justify-between items-center gap-8 text-sm">
                <div className="flex items-center gap-2 opacity-50">
                    <div className="w-5 h-5 rounded bg-muted flex items-center justify-center border border-border/50 text-foreground">
                        <svg viewBox="0 0 24 24" className="w-3 h-3 fill-current">
                            <path d="M12 2L4.5 20.29l.71.71L12 18l6.79 3 .71-.71L12 2z" />
                        </svg>
                    </div>
                    <span className="font-medium text-muted-foreground">Chowser</span>
                    <span className="text-muted-foreground/60">© {new Date().getFullYear()}</span>
                </div>
                <div className="flex flex-wrap items-center justify-center gap-6 text-muted-foreground">
                    <Link to="/" className="hover:text-foreground transition-colors">Home</Link>
                    <Link to="/agentic-setup" className="hover:text-foreground transition-colors">AI Setup</Link>
                    <Link to="/security-setup" className="hover:text-foreground transition-colors">Security</Link>
                </div>
            </div>
        </footer>
    );
};
