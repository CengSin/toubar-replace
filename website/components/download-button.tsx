"use client";

import {
  motion,
  useMotionValue,
  useReducedMotion,
  useSpring,
} from "motion/react";
import { DownloadSimple } from "@phosphor-icons/react";
import type { MouseEvent, ReactNode } from "react";
import { cn } from "@/lib/cn";

type Props = {
  href: string;
  children: ReactNode;
  variant?: "solid" | "ghost";
  download?: boolean | string;
  className?: string;
  showIcon?: boolean;
};

export function DownloadButton({
  href,
  children,
  variant = "solid",
  download,
  className,
  showIcon = variant === "solid",
}: Props) {
  const reduce = useReducedMotion();
  const x = useMotionValue(0);
  const y = useMotionValue(0);
  const sx = useSpring(x, { stiffness: 220, damping: 18, mass: 0.35 });
  const sy = useSpring(y, { stiffness: 220, damping: 18, mass: 0.35 });

  function onMove(e: MouseEvent<HTMLAnchorElement>) {
    if (reduce || variant !== "solid") return;
    const r = e.currentTarget.getBoundingClientRect();
    x.set((e.clientX - r.left - r.width / 2) * 0.28);
    y.set((e.clientY - r.top - r.height / 2) * 0.28);
  }

  function onLeave() {
    x.set(0);
    y.set(0);
  }

  const base =
    "inline-flex h-11 items-center justify-center gap-2 whitespace-nowrap rounded-full px-5 text-[15px] font-medium tracking-tight transition-[transform,background-color,color,border-color] duration-200 ease-out focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent focus-visible:ring-offset-2 focus-visible:ring-offset-bg active:scale-[0.98]";

  const look =
    variant === "solid"
      ? "bg-cta text-cta-ink hover:opacity-90"
      : "border border-line bg-transparent text-ink hover:border-ink/40";

  return (
    <motion.a
      href={href}
      download={download === true ? true : download || undefined}
      className={cn(base, look, className)}
      style={reduce ? undefined : { x: sx, y: sy }}
      onMouseMove={onMove}
      onMouseLeave={onLeave}
    >
      {showIcon ? (
        <DownloadSimple size={18} weight="regular" aria-hidden />
      ) : null}
      {children}
    </motion.a>
  );
}
