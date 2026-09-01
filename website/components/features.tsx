"use client";

import { motion, useReducedMotion } from "motion/react";
import Image from "next/image";
import { useState } from "react";
import { cn } from "@/lib/cn";

const ITEMS = [
  {
    id: "path",
    title: "路径",
    body: "Finder 在前台时读取当前窗口目录。也可以在栏上滑动最近项目，或手选文件夹。",
    image: "/images/desk.jpg",
    position: "object-center",
  },
  {
    id: "agents",
    title: "Agent",
    body: "Codex、Cursor、Claude Code、Grok Build。已安装的才会出现，点一下就在项目目录启动。",
    image: "/images/macro.jpg",
    position: "object-center",
  },
  {
    id: "apps",
    title: "应用",
    body: "把三个最常用的 App 钉在栏上。点图标只负责打开，管理入口在设置里。",
    image: "/images/hero.jpg",
    position: "object-[center_20%]",
  },
] as const;

export function Features() {
  const [active, setActive] = useState(1);
  const reduce = useReducedMotion();

  return (
    <section className="bg-bg px-6 py-24 md:px-12 md:py-32">
      <div className="mx-auto grid max-w-[1400px] items-stretch gap-3 md:grid-cols-12 md:gap-4">
        {ITEMS.map((item, i) => {
          const open = active === i;
          return (
            <motion.button
              key={item.id}
              type="button"
              onMouseEnter={() => setActive(i)}
              onFocus={() => setActive(i)}
              onClick={() => setActive(i)}
              aria-pressed={open}
              className={cn(
                "group relative overflow-hidden rounded-[18px] text-left ring-1 ring-line",
                "min-h-[280px] md:min-h-[420px]",
                open ? "md:col-span-6" : "md:col-span-3",
              )}
              layout
              transition={
                reduce
                  ? { duration: 0 }
                  : { type: "spring", stiffness: 260, damping: 32 }
              }
            >
              <Image
                src={item.image}
                alt=""
                fill
                sizes="(max-width: 768px) 100vw, 50vw"
                className={cn("object-cover", item.position)}
              />
              <div className="absolute inset-0 bg-gradient-to-t from-[rgba(8,9,11,0.92)] via-[rgba(8,9,11,0.25)] to-transparent" />
              <div className="absolute inset-x-0 bottom-0 p-6 md:p-7">
                <h3 className="text-2xl font-medium tracking-tight text-white md:text-3xl">
                  {item.title}
                </h3>
                <p
                  className={cn(
                    "mt-2 max-w-[36ch] text-[14px] leading-relaxed text-white/75 transition-opacity duration-300",
                    open ? "opacity-100" : "opacity-0 md:opacity-0",
                  )}
                >
                  {item.body}
                </p>
              </div>
            </motion.button>
          );
        })}
      </div>
    </section>
  );
}
