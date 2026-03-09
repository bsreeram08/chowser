import React, { useState, useRef, useCallback } from "react";
import {
    Download,
    RefreshCcw,
    Layout,
    Palette,
    Type,
    Layers,
    Monitor,
    Moon,
    Sun,
    Grid3X3,
    Copy
} from "lucide-react";
import { toPng } from "html-to-image";
import { Button } from "@/components/ui/button";
import { Slider } from "@/components/ui/slider";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Card } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import { cn } from "@/lib/utils";
import { toast } from "sonner";
import { Navbar } from "@/components/Navbar";

export interface IconConfig {
    size: number;
    radius: number;
    bgStyle: "gradient" | "mesh" | "glossy";
    bgColor1: string;
    bgColor2: string;
    bgColor3: string;
    bgAngle: number;
    bgShine: number;
    bgNoise: number;

    text: string;
    textScale: number;
    textColor: string;
    textGlow: number;
    textBlur: number;
    letterSpacing: number;
    fontWeight: string;
    fontStyle: string;

    borderWidth: number;
    borderColor: string;
    borderOpacity: number;
    innerShadow: number;
    dropShadow: number;
}

const DEFAULT_CONFIG: IconConfig = {
    size: 512,
    radius: 120,
    bgStyle: "mesh",
    bgColor1: "#2d2d2d",
    bgColor2: "#1a1a1a",
    bgColor3: "#4a4a4a",
    bgAngle: 135,
    bgShine: 0.3,
    bgNoise: 0.1,

    text: "Ch",
    textScale: 1.0,
    textColor: "#ffffff",
    textGlow: 0.4,
    textBlur: 0,
    letterSpacing: -2,
    fontWeight: "800",
    fontStyle: "italic",

    borderWidth: 1.5,
    borderColor: "#ffffff",
    borderOpacity: 0.15,
    innerShadow: 20,
    dropShadow: 40,
};

const IconPreview = ({ config, className, id }: { config: IconConfig, className?: string, id?: string }) => {
    const {
        size,
        radius,
        bgStyle,
        bgColor1,
        bgColor2,
        bgColor3,
        bgAngle,
        bgShine,
        bgNoise,
        text,
        textScale,
        textColor,
        textGlow,
        textBlur,
        letterSpacing,
        fontWeight,
        fontStyle,
        borderWidth,
        borderColor,
        borderOpacity,
        innerShadow,
        dropShadow,
    } = config;

    const containerStyle: React.CSSProperties = {
        width: size,
        height: size,
        borderRadius: radius,
        position: "relative",
        overflow: "hidden",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        boxShadow: `0 ${dropShadow / 2}px ${dropShadow}px rgba(0,0,0,0.5)`,
        border: `${borderWidth}px solid ${borderColor}${Math.round(borderOpacity * 255).toString(16).padStart(2, '0')}`,
        background: bgStyle === "gradient"
            ? `linear-gradient(${bgAngle}deg, ${bgColor1}, ${bgColor2})`
            : bgStyle === "mesh"
                ? `radial-gradient(at 0% 0%, ${bgColor3} 0px, transparent 50%),
               radial-gradient(at 100% 0%, ${bgColor1} 0px, transparent 50%),
               radial-gradient(at 100% 100%, ${bgColor2} 0px, transparent 50%),
               radial-gradient(at 0% 100%, ${bgColor1} 0px, transparent 50%),
               ${bgColor2}`
                : bgColor1,
    };

    return (
        <div id={id} style={containerStyle} className={cn("select-none font-serif", className)}>
            {/* Glossy Overlay */}
            {bgStyle === "glossy" && (
                <div style={{
                    position: "absolute",
                    inset: 0,
                    background: `linear-gradient(135deg, rgba(255,255,255,${bgShine * 0.5}) 0%, rgba(255,255,255,0) 50%, rgba(0,0,0,0.2) 100%)`,
                }} />
            )}

            {/* Top Shine */}
            <div style={{
                position: "absolute",
                top: 0,
                left: "10%",
                right: "10%",
                height: "40%",
                background: `linear-gradient(to bottom, rgba(255,255,255,${bgShine * 0.3}), transparent)`,
                borderRadius: "50% 50% 100% 100% / 20% 20% 80% 80%",
                filter: "blur(20px)",
                opacity: 0.6,
            }} />

            {/* Inner Shadow */}
            <div style={{
                position: "absolute",
                inset: 0,
                boxShadow: `inset 0 0 ${innerShadow}px rgba(0,0,0,0.8)`,
                borderRadius: radius,
                pointerEvents: "none",
            }} />

            {/* Noise Texture */}
            <div style={{
                position: "absolute",
                inset: 0,
                opacity: bgNoise,
                backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 200 200' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noiseFilter'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.65' numOctaves='3' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noiseFilter)'/%3E%3C/svg%3E")`,
                pointerEvents: "none",
            }} />

            {/* Text */}
            <span style={{
                fontSize: `${size * 0.45 * textScale}px`,
                fontWeight: fontWeight as any,
                fontStyle: fontStyle,
                color: textColor,
                letterSpacing: `${letterSpacing}px`,
                textShadow: textGlow > 0 ? `0 0 ${textGlow * 20}px ${textColor}, 0 0 ${textGlow * 40}px ${textColor}44` : "none",
                filter: `blur(${textBlur}px)`,
                zIndex: 10,
                lineHeight: 1,
            }}>
                {text}
            </span>
        </div>
    );
};

export const AppIcon = () => {
    const [cfg, setCfg] = useState<IconConfig>(DEFAULT_CONFIG);
    const [canvasBg, setCanvasBg] = useState<"dark" | "light" | "grid">("grid");
    const [isExporting, setIsExporting] = useState(false);
    const iconRef = useRef<HTMLDivElement>(null);

    const updateCfg = useCallback((updates: Partial<IconConfig>) => {
        setCfg(prev => ({ ...prev, ...updates }));
    }, []);

    const handleDownload = async () => {
        if (!iconRef.current) return;
        setIsExporting(true);
        try {
            const dataUrl = await toPng(iconRef.current, {
                quality: 1,
                pixelRatio: 4,
            });
            const link = document.createElement('a');
            link.download = `chowser-icon-${cfg.text.toLowerCase()}.png`;
            link.href = dataUrl;
            link.click();
            toast.success("Icon exported successfully!");
        } catch (err) {
            console.error(err);
            toast.error("Failed to export icon.");
        } finally {
            setIsExporting(false);
        }
    };

    const handleCopy = async () => {
        if (!iconRef.current) return;
        setIsExporting(true);
        try {
            const dataUrl = await toPng(iconRef.current, { quality: 1, pixelRatio: 2 });
            const response = await fetch(dataUrl);
            const blob = await response.blob();
            await navigator.clipboard.write([
                new ClipboardItem({ 'image/png': blob })
            ]);
            toast.success("Copied to clipboard!");
        } catch (err) {
            console.error(err);
            toast.error("Failed to copy icon.");
        } finally {
            setIsExporting(false);
        }
    };

    return (
        <div className="flex flex-col min-h-screen bg-background text-foreground overflow-hidden">
            <Navbar />

            <div className="flex flex-1 pt-16 h-screen overflow-hidden">
                {/* ── Control Panel (Left) ── */}
                <Card className="w-80 border-r border-t-0 border-l-0 border-b-0 rounded-none bg-muted/30 backdrop-blur-xl z-20 flex flex-col shadow-2xl">
                    <div className="p-4 border-b bg-background/50 flex items-center justify-between">
                        <div className="flex items-center gap-2">
                            <Palette className="w-4 h-4 text-primary" />
                            <h2 className="text-sm font-semibold tracking-tight">Icon Designer</h2>
                        </div>
                        <Button variant="ghost" size="icon" className="h-8 w-8" onClick={() => setCfg(DEFAULT_CONFIG)}>
                            <RefreshCcw className="w-4 h-4" />
                        </Button>
                    </div>

                    <div className="flex-1 overflow-y-auto p-4 custom-scrollbar">
                        <Tabs defaultValue="shape" className="w-full">
                            <TabsList className="w-full mb-4 grid grid-cols-3 h-8 p-1">
                                <TabsTrigger value="shape" className="text-[10px]"><Layout className="w-3 h-3 mr-1" />Base</TabsTrigger>
                                <TabsTrigger value="style" className="text-[10px]"><Palette className="w-3 h-3 mr-1" />Style</TabsTrigger>
                                <TabsTrigger value="text" className="text-[10px]"><Type className="w-3 h-3 mr-1" />Text</TabsTrigger>
                            </TabsList>

                            <TabsContent value="shape" className="space-y-6 mt-0">
                                <div className="space-y-3">
                                    <Label className="text-[10px] uppercase tracking-wider text-muted-foreground font-bold">Radius & Shadow</Label>
                                    <div className="space-y-4 pt-2">
                                        <div className="space-y-2">
                                            <div className="flex justify-between text-[11px]">
                                                <span>Corner Radius</span>
                                                <span className="text-muted-foreground">{cfg.radius}px</span>
                                            </div>
                                            <Slider value={[cfg.radius]} min={0} max={256} step={1} onValueChange={(v) => updateCfg({ radius: Array.isArray(v) ? v[0] : v })} />
                                        </div>
                                        <div className="space-y-2">
                                            <div className="flex justify-between text-[11px]">
                                                <span>Drop Shadow</span>
                                                <span className="text-muted-foreground">{cfg.dropShadow}px</span>
                                            </div>
                                            <Slider value={[cfg.dropShadow]} min={0} max={100} step={1} onValueChange={(v) => updateCfg({ dropShadow: Array.isArray(v) ? v[0] : v })} />
                                        </div>
                                    </div>
                                </div>

                                <div className="space-y-3 pt-2">
                                    <Label className="text-[10px] uppercase tracking-wider text-muted-foreground font-bold">Border & Depth</Label>
                                    <div className="space-y-4 pt-2">
                                        <div className="space-y-2">
                                            <div className="flex justify-between text-[11px]">
                                                <span>Border Width</span>
                                                <span className="text-muted-foreground">{cfg.borderWidth}px</span>
                                            </div>
                                            <Slider value={[cfg.borderWidth]} min={0} max={10} step={0.5} onValueChange={(v) => updateCfg({ borderWidth: Array.isArray(v) ? v[0] : v })} />
                                        </div>
                                        <div className="space-y-2">
                                            <div className="flex justify-between text-[11px]">
                                                <span>Inner Depth</span>
                                                <span className="text-muted-foreground">{cfg.innerShadow}px</span>
                                            </div>
                                            <Slider value={[cfg.innerShadow]} min={0} max={100} step={1} onValueChange={(v) => updateCfg({ innerShadow: Array.isArray(v) ? v[0] : v })} />
                                        </div>
                                    </div>
                                </div>
                            </TabsContent>

                            <TabsContent value="style" className="space-y-6 mt-0">
                                <div className="space-y-3">
                                    <Label className="text-[10px] uppercase tracking-wider text-muted-foreground font-bold">Background Type</Label>
                                    <div className="grid grid-cols-3 gap-2">
                                        {(["gradient", "mesh", "glossy"] as const).map(style => (
                                            <Button
                                                key={style}
                                                variant={cfg.bgStyle === style ? "default" : "outline"}
                                                size="sm"
                                                className="h-8 text-[10px] capitalize"
                                                onClick={() => updateCfg({ bgStyle: style })}
                                            >
                                                {style}
                                            </Button>
                                        ))}
                                    </div>
                                </div>

                                <div className="space-y-4">
                                    <Label className="text-[10px] uppercase tracking-wider text-muted-foreground font-bold">Colors</Label>
                                    <div className="space-y-2">
                                        <div className="flex items-center justify-between">
                                            <span className="text-[11px]">Primary</span>
                                            <input type="color" value={cfg.bgColor1} onChange={e => updateCfg({ bgColor1: e.target.value })} className="w-8 h-4 rounded cursor-pointer bg-transparent border-none" />
                                        </div>
                                        <div className="flex items-center justify-between">
                                            <span className="text-[11px]">Secondary</span>
                                            <input type="color" value={cfg.bgColor2} onChange={e => updateCfg({ bgColor2: e.target.value })} className="w-8 h-4 rounded cursor-pointer bg-transparent border-none" />
                                        </div>
                                        {cfg.bgStyle === "mesh" && (
                                            <div className="flex items-center justify-between">
                                                <span className="text-[11px]">Accent</span>
                                                <input type="color" value={cfg.bgColor3} onChange={e => updateCfg({ bgColor3: e.target.value })} className="w-8 h-4 rounded cursor-pointer bg-transparent border-none" />
                                            </div>
                                        )}
                                    </div>
                                </div>

                                <div className="space-y-4 pt-2">
                                    <div className="space-y-2">
                                        <div className="flex justify-between text-[11px]">
                                            <span>Sheen Intensity</span>
                                            <span className="text-muted-foreground">{Math.round(cfg.bgShine * 100)}%</span>
                                        </div>
                                        <Slider value={[cfg.bgShine]} min={0} max={1} step={0.01} onValueChange={(v) => updateCfg({ bgShine: Array.isArray(v) ? v[0] : v })} />
                                    </div>
                                    <div className="space-y-2">
                                        <div className="flex justify-between text-[11px]">
                                            <span>Grain/Noise</span>
                                            <span className="text-muted-foreground">{Math.round(cfg.bgNoise * 100)}%</span>
                                        </div>
                                        <Slider value={[cfg.bgNoise]} min={0} max={0.5} step={0.01} onValueChange={(v) => updateCfg({ bgNoise: Array.isArray(v) ? v[0] : v })} />
                                    </div>
                                </div>
                            </TabsContent>

                            <TabsContent value="text" className="space-y-6 mt-0">
                                <div className="space-y-4">
                                    <div className="space-y-2">
                                        <Label className="text-[10px] uppercase tracking-wider text-muted-foreground font-bold">Glyph</Label>
                                        <div className="flex gap-2">
                                            <input
                                                type="text"
                                                value={cfg.text}
                                                onChange={e => updateCfg({ text: e.target.value })}
                                                className="flex h-8 w-full rounded-md border border-input bg-background px-3 py-1 text-sm shadow-sm transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-primary"
                                                maxLength={8}
                                            />
                                            <input type="color" value={cfg.textColor} onChange={e => updateCfg({ textColor: e.target.value })} className="w-8 h-8 rounded cursor-pointer bg-transparent border-none shrink-0" />
                                        </div>
                                    </div>

                                    <div className="space-y-4 pt-2">
                                        <div className="space-y-2">
                                            <div className="flex justify-between text-[11px]">
                                                <span>Scale</span>
                                                <span className="text-muted-foreground">{cfg.textScale.toFixed(2)}x</span>
                                            </div>
                                            <Slider value={[cfg.textScale]} min={0.5} max={2.0} step={0.01} onValueChange={(v) => updateCfg({ textScale: Array.isArray(v) ? v[0] : v })} />
                                        </div>
                                        <div className="space-y-2">
                                            <div className="flex justify-between text-[11px]">
                                                <span>Letter Spacing</span>
                                                <span className="text-muted-foreground">{cfg.letterSpacing}px</span>
                                            </div>
                                            <Slider value={[cfg.letterSpacing]} min={-20} max={20} step={1} onValueChange={(v) => updateCfg({ letterSpacing: Array.isArray(v) ? v[0] : v })} />
                                        </div>
                                        <div className="space-y-2">
                                            <div className="flex justify-between text-[11px]">
                                                <span>Glow</span>
                                                <span className="text-muted-foreground">{Math.round(cfg.textGlow * 100)}%</span>
                                            </div>
                                            <Slider value={[cfg.textGlow]} min={0} max={1} step={0.01} onValueChange={(v) => updateCfg({ textGlow: Array.isArray(v) ? v[0] : v })} />
                                        </div>
                                    </div>
                                </div>
                            </TabsContent>
                        </Tabs>
                    </div>

                    <div className="p-4 border-t bg-background/50 grid grid-cols-2 gap-2">
                        <Button variant="outline" size="sm" onClick={handleCopy} disabled={isExporting} className="h-9">
                            <Copy className="w-3.5 h-3.5 mr-2" /> Copy
                        </Button>
                        <Button size="sm" onClick={handleDownload} disabled={isExporting} className="h-9">
                            <Download className="w-3.5 h-3.5 mr-2" /> Export
                        </Button>
                    </div>
                </Card>

                {/* ── Preview Stage (Center) ── */}
                <div className="flex-1 relative overflow-hidden flex flex-col">
                    {/* Toolbar */}
                    <div className="absolute top-4 left-1/2 -translate-x-1/2 flex items-center bg-muted/50 backdrop-blur-md rounded-full px-4 py-1.5 border gap-4 z-10 shadow-lg">
                        <div className="flex items-center gap-2">
                            <span className="text-[10px] text-muted-foreground font-medium uppercase tracking-tight">Stage</span>
                            <div className="flex bg-background/50 rounded-full p-0.5 border">
                                <Button
                                    variant="ghost"
                                    size="icon"
                                    className={cn("h-6 w-6 rounded-full", canvasBg === "light" && "bg-background shadow-sm")}
                                    onClick={() => setCanvasBg("light")}
                                >
                                    <Sun className="w-3.5 h-3.5" />
                                </Button>
                                <Button
                                    variant="ghost"
                                    size="icon"
                                    className={cn("h-6 w-6 rounded-full", canvasBg === "dark" && "bg-background shadow-sm")}
                                    onClick={() => setCanvasBg("dark")}
                                >
                                    <Moon className="w-3.5 h-3.5" />
                                </Button>
                                <Button
                                    variant="ghost"
                                    size="icon"
                                    className={cn("h-6 w-6 rounded-full", canvasBg === "grid" && "bg-background shadow-sm")}
                                    onClick={() => setCanvasBg("grid")}
                                >
                                    <Grid3X3 className="w-3.5 h-3.5" />
                                </Button>
                            </div>
                        </div>
                    </div>

                    {/* Canvas */}
                    <div className={cn(
                        "flex-1 flex items-center justify-center transition-colors duration-500",
                        canvasBg === "dark" && "bg-[#090909]",
                        canvasBg === "light" && "bg-[#f5f5f7]",
                        canvasBg === "grid" && "bg-[radial-gradient(#222_1px,transparent_1px)] [background-size:20px_20px] bg-background"
                    )}>
                        <div ref={iconRef} className="relative group perspective-1000 p-20">
                            <IconPreview config={cfg} className="transform-gpu transition-transform hover:scale-[1.02] hover:rotate-1" />
                        </div>
                    </div>

                    {/* macOS Dock Preview */}
                    <div className="h-24 bg-background/20 backdrop-blur-3xl border-t flex flex-col items-center justify-center gap-2">
                        <span className="text-[9px] uppercase tracking-[0.2em] text-muted-foreground/50 font-medium">macOS Dock Preview</span>
                        <div className="flex items-end gap-3 px-6 py-2 bg-white/5 border border-white/10 rounded-2xl shadow-2xl backdrop-blur-md scale-90 origin-bottom">
                            <div className="w-12 h-12 bg-blue-500/20 rounded-xl" />
                            <div className="w-12 h-12 bg-green-500/20 rounded-xl" />
                            <IconPreview config={{ ...cfg, size: 48, radius: 11, dropShadow: 10, borderWidth: 0.5, innerShadow: 5 }} />
                            <div className="w-12 h-12 bg-orange-500/20 rounded-xl" />
                            <div className="w-12 h-12 bg-purple-500/20 rounded-xl" />
                        </div>
                    </div>
                </div>

                {/* ── Context Sidebar (Right) ── */}
                <div className="w-64 border-l bg-muted/20 backdrop-blur-sm p-6 space-y-8 hidden xl:block overflow-y-auto custom-scrollbar">
                    <div className="space-y-4">
                        <div className="flex items-center gap-2 text-primary">
                            <Layers className="w-4 h-4" />
                            <h3 className="text-xs font-bold uppercase tracking-wider">Variants</h3>
                        </div>
                        <div className="grid grid-cols-2 gap-4">
                            <div className="space-y-2 flex flex-col items-center">
                                <IconPreview config={{ ...cfg, size: 64, radius: 15, dropShadow: 10, innerShadow: 6 }} className="shadow-lg" />
                                <span className="text-[9px] font-medium text-muted-foreground">Standard</span>
                            </div>
                            <div className="space-y-2 flex flex-col items-center">
                                <IconPreview config={{ ...cfg, size: 64, radius: 32, dropShadow: 10, innerShadow: 6 }} className="shadow-lg" />
                                <span className="text-[9px] font-medium text-muted-foreground">Circle</span>
                            </div>
                        </div>
                    </div>

                    <div className="space-y-4 pt-4 border-t border-border/40">
                        <div className="flex items-center gap-2 text-primary">
                            <Monitor className="w-4 h-4" />
                            <h3 className="text-xs font-bold uppercase tracking-wider">Device</h3>
                        </div>
                        <div className="aspect-video bg-background/50 border rounded-lg flex flex-col items-center justify-center p-4 relative overflow-hidden group">
                            <div className="absolute top-0 inset-x-0 h-1 bg-primary/20" />
                            <IconPreview config={{ ...cfg, size: 32, radius: 7, dropShadow: 4, innerShadow: 3 }} />
                            <div className="mt-3 w-3/4 h-1.5 bg-muted rounded-full overflow-hidden">
                                <div className="w-1/3 h-full bg-primary" />
                            </div>
                            <span className="mt-2 text-[8px] text-muted-foreground">Menu Bar Item</span>
                        </div>
                    </div>

                    <Card className="p-4 bg-primary/5 border-primary/20">
                        <h4 className="text-[10px] font-bold uppercase mb-2">Pro Tip</h4>
                        <p className="text-[10px] text-muted-foreground leading-relaxed">
                            Use "Mesh" background with a high "Sheen" for a premium liquid-metal look.
                        </p>
                    </Card>
                </div>
            </div>

            <style>{`
                .perspective-1000 { perspective: 1000px; }
                .custom-scrollbar::-webkit-scrollbar { width: 4px; }
                .custom-scrollbar::-webkit-scrollbar-track { background: transparent; }
                .custom-scrollbar::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.1); border-radius: 10px; }
            `}</style>
        </div>
    );
};

export default AppIcon;