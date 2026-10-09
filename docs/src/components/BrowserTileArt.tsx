import { Briefcase, Music2, UserRound } from "lucide-react";

/* CSS-drawn app tiles so demos read as real browsers and apps, not placeholder glyphs. */
export type DemoBrowserKind = "chrome" | "safari" | "work" | "personal" | "arc" | "spotify";

export const BrowserTileArt: React.FC<{ kind: DemoBrowserKind; size?: number }> = ({
  kind,
  size = 54,
}) => {
  const base =
    "rounded-[27%] grid place-items-center shadow-[0_6px_16px_rgba(0,0,0,0.18)] relative overflow-hidden shrink-0";
  const px = { width: size, height: size };

  if (kind === "chrome")
    return (
      <div
        className={base}
        style={{
          ...px,
          background:
            "conic-gradient(from -45deg, #ea4335 0 25%, #fbbc05 25% 50%, #34a853 50% 75%, #4285f4 75% 100%)",
        }}
      >
        <div className="w-[42%] h-[42%] bg-white rounded-full grid place-items-center shadow-inner">
          <div className="w-[62%] h-[62%] rounded-full bg-[#4285f4]" />
        </div>
      </div>
    );
  if (kind === "safari")
    return (
      <div className={base} style={{ ...px, background: "linear-gradient(160deg,#3edcff,#1275f8)" }}>
        <div className="w-[68%] h-[68%] rounded-full border-[2.5px] border-white/85 grid place-items-center">
          <div
            className="w-[52%] h-[52%] rotate-45"
            style={{
              background: "linear-gradient(to bottom, #ff3b30 50%, #ffffff 50%)",
              clipPath: "polygon(50% 0%, 78% 50%, 50% 100%, 22% 50%)",
            }}
          />
        </div>
      </div>
    );
  if (kind === "arc")
    return (
      <div className={base} style={{ ...px, background: "linear-gradient(140deg,#ff5f6d,#7b61ff 55%,#2ec5ff)" }}>
        <div className="w-[52%] h-[52%] rounded-full border-[3px] border-white border-b-transparent rotate-45" />
      </div>
    );
  if (kind === "spotify")
    return (
      <div className={base} style={{ ...px, background: "#1ed760" }}>
        <Music2 className="w-[48%] h-[48%] text-black/85" />
      </div>
    );
  if (kind === "work")
    return (
      <div className={base} style={{ ...px, background: "linear-gradient(135deg,#ff9500,#ff2d55)" }}>
        <Briefcase className="w-[46%] h-[46%] text-white drop-shadow-sm" />
      </div>
    );
  return (
    <div className={base} style={{ ...px, background: "linear-gradient(135deg,#7b5cff,#47c7ff)" }}>
      <UserRound className="w-[48%] h-[48%] text-white drop-shadow-sm" />
    </div>
  );
};
