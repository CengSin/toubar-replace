import Image from "next/image";
import { CaretLeft, GearSix } from "@phosphor-icons/react/dist/ssr";
import { AGENTS } from "@/lib/site";
import { cn } from "@/lib/cn";

const QUOTA = [
  { name: "Grok Build", src: "/agents/grokBuild.png", bars: [0.7, 0.45, 0.3] },
  { name: "Cursor", src: "/agents/cursor.png", bars: [0.35, 0.8, 0.55] },
  { name: "Codex", src: "/agents/codex.png", bars: [0.55, 0.9, 0.2] },
] as const;

export function TouchBar({ className }: { className?: string }) {
  return (
    <div
      role="img"
      aria-label="ToubarReplace 工作区：订阅用量与自定义应用"
      className={cn(
        "flex h-14 items-center gap-1 rounded-[18px] bg-[#1a1b1e] px-1.5",
        "ring-1 ring-white/10",
        "shadow-[0_16px_50px_rgba(0,0,0,0.42),inset_0_1px_0_rgba(255,255,255,0.08)]",
        className,
      )}
    >
      <div className="flex size-10 shrink-0 items-center justify-center rounded-[12px] bg-white/6">
        <CaretLeft size={16} weight="regular" className="text-white/80" />
      </div>

      <div className="flex h-10 min-w-0 flex-[4] items-center gap-1 overflow-hidden rounded-[12px] bg-white/6 px-1">
        {QUOTA.map((item, index) => (
          <span
            key={item.name}
            className={cn(
              "flex h-8 min-w-0 flex-1 items-center gap-1 rounded-[9px] bg-white/6 px-1.5",
              index === 0 && "ring-1 ring-[#e8a04a]/70",
            )}
            title={item.name}
          >
            <Image
              src={item.src}
              alt=""
              width={16}
              height={16}
              className="size-4 shrink-0 rounded-[4px] object-contain"
            />
            <span className="flex h-5 items-end gap-0.5">
              {item.bars.map((ratio, barIndex) => (
                <i
                  key={`${item.name}-${barIndex}`}
                  className={cn(
                    "w-[3px] rounded-sm",
                    barIndex === 2
                      ? "bg-[#78c4bc]"
                      : index === 0 && barIndex === 0
                        ? "bg-[#e8a04a]"
                        : "bg-white/85",
                  )}
                  style={{ height: `${Math.max(ratio * 100, 18)}%` }}
                  aria-hidden
                />
              ))}
            </span>
          </span>
        ))}
      </div>

      <div className="mx-0.5 h-6 w-px shrink-0 bg-white/10" />

      <div className="flex h-10 flex-[6] items-center gap-1 px-1">
        {AGENTS.slice(0, 3).map((agent) => (
          <span
            key={agent.name}
            className="flex size-9 items-center justify-center rounded-[10px] bg-white/4"
            title={agent.name}
          >
            <Image
              src={agent.src}
              alt=""
              width={22}
              height={22}
              className="size-[22px] rounded-[5px] object-contain"
            />
          </span>
        ))}
        <span className="ml-auto flex size-9 items-center justify-center rounded-[10px] bg-white/6 text-white/80">
          <GearSix size={16} weight="regular" />
        </span>
      </div>
    </div>
  );
}

export function TouchBarFrame({ className }: { className?: string }) {
  return (
    <div className={cn("bar-scroll overflow-x-auto", className)}>
      <div className="min-w-[720px]">
        <TouchBar />
      </div>
    </div>
  );
}
