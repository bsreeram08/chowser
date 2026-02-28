import React from 'react';
import { Navbar } from '@/components/Navbar';
import { Footer } from '@/components/Footer';
import { Card } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { ShieldAlert, MousePointer2, Settings, CheckCircle2 } from 'lucide-react';

export const SecuritySetup: React.FC = () => {
    return (
        <div className="bg-background min-h-screen text-foreground font-sans antialiased">
            <Navbar />

            <main className="pt-32 pb-24 container mx-auto px-4 max-w-4xl">
                <header className="text-center space-y-6 mb-12">
                    <Badge variant="destructive" className="bg-destructive/10 border-destructive/20 text-destructive gap-1.5 py-1 px-3">
                        <ShieldAlert className="w-3 h-3" />
                        Bypass macOS Gatekeeper
                    </Badge>
                    <h1 className="text-4xl md:text-5xl font-extrabold tracking-tight text-foreground leading-tight">Install & Allow Chowser</h1>
                    <p className="text-muted-foreground text-lg max-w-2xl mx-auto leading-relaxed">
                        Chowser is a professional tool currently in a pre-release state and is unsigned. Follow these steps to allow it on your Mac.
                        This is a one-time configuration.
                    </p>
                </header>

                <div className="space-y-6">
                    <div className="grid gap-6">
                        <div className="flex gap-6 group">
                            <div className="flex flex-col items-center">
                                <div className="w-10 h-10 rounded-full bg-muted border border-border/50 flex items-center justify-center text-sm font-bold shrink-0 group-hover:border-primary/50 transition-colors">1</div>
                                <div className="w-px flex-1 bg-border/20 my-4" />
                            </div>
                            <Card className="flex-1 bg-card/40 border-border/50 p-8 transition-colors hover:bg-card/60">
                                <div className="flex items-start gap-4">
                                    <div className="p-3 rounded-xl bg-blue-500/10 text-blue-500 border border-blue-500/20">
                                        <MousePointer2 className="w-6 h-6" />
                                    </div>
                                    <div className="space-y-2">
                                        <h3 className="text-xl font-bold text-foreground">Right-click to Open</h3>
                                        <p className="text-muted-foreground text-sm leading-relaxed">
                                            Drag Chowser to your <span className="text-foreground">Applications</span> folder.
                                            Hold the <kbd className="bg-muted px-1.5 py-0.5 rounded border border-border/50 font-mono text-xs">Control</kbd> key and click the app icon, then select <strong>Open</strong> from the menu.
                                        </p>
                                    </div>
                                </div>
                            </Card>
                        </div>

                        <div className="flex gap-6 group">
                            <div className="flex flex-col items-center">
                                <div className="w-10 h-10 rounded-full bg-muted border border-border/50 flex items-center justify-center text-sm font-bold shrink-0 group-hover:border-primary/50 transition-colors">2</div>
                                <div className="w-px flex-1 bg-border/20 my-4" />
                            </div>
                            <Card className="flex-1 bg-card/40 border-border/50 p-8 transition-colors hover:bg-card/60 border-l-amber-500/30">
                                <div className="flex items-start gap-4">
                                    <div className="p-3 rounded-xl bg-amber-500/10 text-amber-500 border border-amber-500/20">
                                        <Settings className="w-6 h-6" />
                                    </div>
                                    <div className="space-y-2">
                                        <h3 className="text-xl font-bold text-foreground">System Settings</h3>
                                        <p className="text-muted-foreground text-sm leading-relaxed">
                                            If macOS blocks it, open <strong>System Settings &rarr; Privacy & Security</strong>.
                                            Scroll down to the Security section and click <strong>Open Anyway</strong> for Chowser.
                                        </p>
                                    </div>
                                </div>
                            </Card>
                        </div>

                        <div className="flex gap-6 group">
                            <div className="flex flex-col items-center">
                                <div className="w-10 h-10 rounded-full bg-muted border border-border/50 flex items-center justify-center text-sm font-bold shrink-0 group-hover:border-green-500/50 transition-colors text-green-500">
                                    <CheckCircle2 className="w-5 h-5" />
                                </div>
                            </div>
                            <Card className="flex-1 bg-card/40 border-border/50 p-8 transition-colors hover:bg-card/60">
                                <div className="flex items-start gap-4">
                                    <div className="p-3 rounded-xl bg-green-500/10 text-green-500 border border-green-500/20">
                                        <CheckCircle2 className="w-6 h-6" />
                                    </div>
                                    <div className="space-y-2">
                                        <h3 className="text-xl font-bold text-foreground">Set as Default</h3>
                                        <p className="text-muted-foreground text-sm leading-relaxed">
                                            Finally, set Chowser as your system's default browser in <strong>System Settings &rarr; Desktop & Dock</strong> or directly within Chowser settings.
                                        </p>
                                    </div>
                                </div>
                            </Card>
                        </div>
                    </div>
                </div>

                <section className="mt-24 p-8 rounded-3xl bg-primary/5 border border-primary/10 text-center space-y-4">
                    <h4 className="text-lg font-bold text-foreground italic">"Wait, is it safe?"</h4>
                    <p className="text-muted-foreground text-sm max-w-xl mx-auto leading-relaxed">
                        Chowser is built with privacy and performance as top priorities.
                        The only reason for these prompts is that this professional build hasn't been notarized with an Apple Developer certificate yet.
                    </p>
                </section>
            </main>

            <Footer />
        </div>
    );
};
