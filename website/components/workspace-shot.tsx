import Image from "next/image";
import { cn } from "@/lib/cn";

export function WorkspaceShot({
  src = "/images/workspace-bar.png",
  alt = "ToubarReplace Workspace 真实截图：左侧订阅用量，右侧常用 App",
  width = 2350,
  height = 80,
  className,
  priority = false,
}: {
  src?: string;
  alt?: string;
  width?: number;
  height?: number;
  className?: string;
  priority?: boolean;
}) {
  return (
    <figure
      className={cn(
        "overflow-hidden rounded-[18px] bg-[#111214] p-3 ring-1 ring-white/10 md:p-5",
        className,
      )}
    >
      <Image
        src={src}
        alt={alt}
        width={width}
        height={height}
        priority={priority}
        className="h-auto w-full"
      />
    </figure>
  );
}
