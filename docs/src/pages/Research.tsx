import React from 'react';
import { Link } from 'react-router-dom';

export const Research: React.FC = () => {
    return (
        <div className="bg-background min-h-screen font-sans selection:bg-primary/30 selection:text-white p-8 sm:p-20">
            <div className="max-w-4xl mx-auto">
                <Link to="/" className="text-primary hover:underline mb-8 inline-block">&larr; Back to Home</Link>

                <article className="prose prose-invert max-w-none">
                    <h1 className="text-4xl font-bold mb-8 text-foreground">Arc and Dia Browser Profile Research</h1>

                    <div className="bg-muted/50 border border-border/50 rounded-xl p-6 mb-12">
                        <h2 className="text-xl font-bold mb-4 text-foreground">Status</h2>
                        <p className="text-muted-foreground">Research in progress — findings based on file system inspection and community documentation. Neither browser is currently supported for profile detection in <code>BrowserProfileDetector.swift</code>.</p>
                    </div>

                    <section className="mb-12">
                        <h2 className="text-2xl font-bold mb-4 text-foreground">Arc Browser</h2>
                        <p className="text-muted-foreground mb-4"><strong>Bundle ID:</strong> <code>company.thebrowser.Browser</code></p>
                        <h3 className="text-xl font-bold mb-2 text-foreground">Profile / Space Storage</h3>
                        <p className="text-muted-foreground mb-4">Arc stores its UI state in a proprietary format: <code>~/Library/Application Support/Arc/StorableSidebar.json</code>.</p>
                        <pre className="bg-muted/30 p-4 rounded-lg overflow-x-auto text-sm text-foreground/80">
                            <code>open -n -a "Arc" --args --profile-directory="&lt;SpaceProfileDir&gt;" "https://example.com"</code>
                        </pre>
                    </section>

                    <section className="mb-12">
                        <h2 className="text-2xl font-bold mb-4 text-foreground">Dia Browser</h2>
                        <p className="text-muted-foreground mb-4">Dia is built on the same engine as Arc. Its profile/space structure is expected to be similar or identical to Arc's <code>StorableSidebar.json</code> pattern.</p>
                    </section>
                </article>
            </div>
        </div>
    );
};
