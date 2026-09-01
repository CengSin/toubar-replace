import Image from "next/image";
import { Browser, FolderSimple, ListBullets, Plus } from "@phosphor-icons/react/dist/ssr";
import { AGENTS } from "@/lib/site";
import { cn } from "@/lib/cn";

export function TouchBar({ className }: { className?: string }) {
  return (
    <div
      role="img"
      aria-label="ToubarReplace 工作区：路径、Agent 与自定义应用"
      className={cn(
        "flex h-14 items-center gap-1 rounded-[18px] bg-[#1a1b1e] px-1.5",
        "ring-1 ring-white/10",
        "shadow-[0_16px_50px_rgba(0,0,0,0.42),inset_0_1px_0_rgba(255,255,255,0.08)]",
        className,
      )}
    >
      <div className="flex size-10 shrink-0 items-center justify-center rounded-[12px] bg-white/6">
        <Browser size={16} weight="regular" className="text-white/80" />
      </div>

      <div className="flex h-10 min-w-0 flex-[4] items-center gap-2 rounded-[12px] bg-white/6 px-3">
        <FolderSimple size={16} weight="regular" className="shrink-0 text-white/70" />
        <ListBullets size={16} weight="regular" className="shrink-0 text-white/35" />
        <span className="truncate text-[13px] font-medium tracking-tight text-white/92">
          ToubarReplace
        </span>
      </div>

      <div className="mx-0.5 h-6 w-px shrink-0 bg-white/10" />

      <div className="flex h-10 flex-[3] items-center justify-around px-1">
        {AGENTS.map((agent) => (
          <span
            key={agent.name}
            className="relative flex size-9 items-center justify-center rounded-[10px] bg-white/4"
            title={agent.name}
          >
            <Image
              src={agent.src}
              alt=""
              width={22}
              height={22}
              className="size-[22px] rounded-[5px] object-contain"
            />
            <i
              className="absolute bottom-0.5 left-1/2 size-1 -translate-x-1/2 rounded-full"
              style={{ background: agent.dot }}
              aria-hidden
            />
          </span>
        ))}
      </div>

      <div className="mx-0.5 h-6 w-px shrink-0 bg-white/10" />

      <div className="flex h-10 flex-[3] items-center gap-1 px-1">
        <span className="flex size-9 items-center justify-center rounded-full bg-[#0a84ff] text-[12px] font-semibold text-white">
          S
        </span>
        <span className="flex size-9 items-center justify-center rounded-full bg-[#30d158] text-[12px] font-semibold text-white">
          A
        </span>
        <span className="ml-auto flex size-9 items-center justify-center rounded-[10px] bg-white/6 text-white/80">
          <Plus size={16} weight="regular" />
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
