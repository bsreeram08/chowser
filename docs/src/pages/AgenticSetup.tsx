import React from 'react';
import { Navbar } from '@/components/Navbar';
import { Footer } from '@/components/Footer';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Card } from '@/components/ui/card';
import { Copy, Terminal, Bot, Sparkles, Wand2 } from 'lucide-react';
import { toast } from 'sonner';

export const AgenticSetup: React.FC = () => {
    const copyToClipboard = (text: string) => {
        navigator.clipboard.writeText(text);
        toast.success("Copied to clipboard");
    };

    const curlCmd = "curl -s https://chowser.sreerams.in/agentic-setup.md | pbcopy";

    return (
        <div className="bg-background min-h-screen text-foreground font-sans antialiased">
            <Navbar />

            <main className="pt-32 pb-24 container mx-auto px-4 max-w-4xl">
                <header className="text-center space-y-6 mb-16">
                    <Badge variant="outline" className="bg-primary/10 border-primary/20 text-primary gap-1.5 py-1 px-3">
                        <Sparkles className="w-3 h-3" />
                        AI-Enhanced Setup
                    </Badge>
                    <h1 className="text-4xl md:text-6xl font-extrabold tracking-tight text-foreground">Let AI Configure Chowser</h1>
                    <p className="text-muted-foreground text-lg max-w-2xl mx-auto">
                        Automate your browser profile discovery and rule generation. Paste the prompt into Claude, ChatGPT, or Cursor to get started.
                    </p>
                </header>

                <div className="grid gap-8">
                    {/* Step 1 */}
                    <section className="relative group">
                        <div className="absolute -left-4 top-0 w-8 h-8 rounded-full bg-primary flex items-center justify-center font-bold text-primary-foreground z-10 hidden md:flex">1</div>
                        <Card className="bg-card/50 border-border/50 p-8 overflow-hidden relative">
                            <div className="absolute top-0 right-0 p-8 opacity-5">
                                <Terminal className="w-32 h-32" />
                            </div>
                            <div className="space-y-6 relative">
                                <h2 className="text-2xl font-bold flex items-center gap-2">
                                    <Terminal className="w-5 h-5 text-primary" />
                                    Run Terminal Command
                                </h2>
                                <p className="text-muted-foreground">
                                    This command fetches the full setup prompt and pipes it straight to your clipboard.
                                </p>

                                <div className="group/code relative">
                                    <pre className="bg-muted/40 p-6 rounded-xl font-mono text-sm border border-border/50 text-primary overflow-x-auto">
                                        <code>{curlCmd}</code>
                                    </pre>
                                    <Button
                                        size="sm"
                                        variant="secondary"
                                        onClick={() => copyToClipboard(curlCmd)}
                                        className="absolute right-3 top-3 opacity-0 group-hover/code:opacity-100 transition-opacity"
                                    >
                                        <Copy className="w-3.5 h-3.5 mr-2" />
                                        Copy
                                    </Button>
                                </div>
                            </div>
                        </Card>
                    </section>

                    {/* Step 2 */}
                    <section className="relative group">
                        <div className="absolute -left-4 top-0 w-8 h-8 rounded-full bg-primary flex items-center justify-center font-bold text-primary-foreground z-10 hidden md:flex">2</div>
                        <Card className="bg-card/50 border-border/50 p-8 overflow-hidden relative">
                            <div className="absolute top-0 right-0 p-8 opacity-5">
                                <Bot className="w-32 h-32" />
                            </div>
                            <div className="space-y-6 relative">
                                <h2 className="text-2xl font-bold flex items-center gap-2">
                                    <Wand2 className="w-5 h-5 text-purple-400" />
                                    Paste to AI Assistant
                                </h2>
                                <p className="text-muted-foreground leading-relaxed">
                                    Open your AI assistant (e.g., Cursor Composer, Claude, or ChatGPT) and paste the content.
                                    The AI will then:
                                </p>
                                <ul className="space-y-3 text-sm text-muted-foreground list-disc list-inside ml-2">
                                    <li>Scan your <span className="text-foreground">Application Support</span> folders for browsers.</li>
                                    <li>Discover all available profiles and spaces.</li>
                                    <li>Generate your <span className="text-foreground">ChowserBrowsers.json</span> configuration.</li>
                                    <li>Draft routing rules based on your specific requirements.</li>
                                </ul>
                            </div>
                        </Card>
                    </section>

                    {/* Step 3 */}
                    <section className="relative group">
                        <div className="absolute -left-4 top-0 w-8 h-8 rounded-full bg-primary flex items-center justify-center font-bold text-primary-foreground z-10 hidden md:flex">3</div>
                        <Card className="bg-card/50 border-border/50 p-8 relative">
                            <div className="space-y-6">
                                <h2 className="text-2xl font-bold text-foreground">Import Configuration</h2>
                                <p className="text-muted-foreground">
                                    Once the AI generates the JSON files, import them into Chowser Settings:
                                </p>
                                <div className="grid sm:grid-cols-2 gap-4">
                                    <div className="bg-muted/20 p-4 rounded-lg border border-border/50">
                                        <span className="block text-xs font-bold text-primary mb-1 uppercase tracking-tighter">Step 3.1</span>
                                        <p className="text-sm">Browsers Tab &rarr; Import JSON</p>
                                    </div>
                                    <div className="bg-muted/20 p-4 rounded-lg border border-border/50">
                                        <span className="block text-xs font-bold text-primary mb-1 uppercase tracking-tighter">Step 3.2</span>
                                        <p className="text-sm">Rules Tab &rarr; Import JSON</p>
                                    </div>
                                </div>
                            </div>
                        </Card>
                    </section>
                </div>
            </main>

            <Footer />
        </div>
    );
};
