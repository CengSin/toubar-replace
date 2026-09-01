"use client";

import { List, X } from "@phosphor-icons/react";
import { useEffect, useState } from "react";
import { DownloadButton } from "@/components/download-button";
import { ThemeToggle } from "@/components/theme-toggle";
import { SITE } from "@/lib/site";

const LINKS = [
  { href: "#workspace", label: "工作区" },
  { href: "#compat", label: "兼容" },
] as const;

export function Nav() {
  const [open, setOpen] = useState(false);

  useEffect(() => {
    document.body.style.overflow = open ? "hidden" : "";
    return () => {
      document.body.style.overflow = "";
    };
  }, [open]);

  return (
    <header className="pointer-events-none fixed inset-x-0 top-0 z-40 px-3 pt-3 md:px-6">
      <div className="pointer-events-auto mx-auto flex h-14 max-w-[1400px] items-center gap-4 rounded-full glass-nav px-3 md:h-16 md:px-4">
        <a
          href="#top"
          className="shrink-0 pl-2 text-[15px] font-medium tracking-tight text-ink"
        >
          Toubar<span className="text-accent">Replace</span>
        </a>

        <nav className="hidden flex-1 items-center justify-center gap-8 lg:flex">
          {LINKS.map((item) => (
            <a
              key={item.href}
              href={item.href}
              className="text-[14px] text-muted transition-colors hover:text-ink"
            >
              {item.label}
            </a>
          ))}
        </nav>

        <div className="ml-auto flex items-center gap-1">
          <ThemeToggle />
          <span className="hidden lg:inline-flex">
            <DownloadButton href={SITE.dmg} download>
              下载应用
            </DownloadButton>
          </span>
          <button
            type="button"
            className="inline-flex size-9 items-center justify-center rounded-full text-ink lg:hidden"
            aria-expanded={open}
            aria-label={open ? "关闭菜单" : "打开菜单"}
            onClick={() => setOpen((v) => !v)}
          >
            {open ? <X size={20} /> : <List size={20} />}
          </button>
        </div>
      </div>

      {open ? (
        <div className="pointer-events-auto mx-auto mt-2 max-w-[1400px] rounded-[22px] glass-nav p-5 lg:hidden">
          <nav className="flex flex-col gap-1">
            {LINKS.map((item) => (
              <a
                key={item.href}
                href={item.href}
                className="rounded-xl px-3 py-3 text-[16px] text-ink"
                onClick={() => setOpen(false)}
              >
                {item.label}
              </a>
            ))}
          </nav>
          <DownloadButton href={SITE.dmg} download className="mt-3 w-full">
            下载应用
          </DownloadButton>
        </div>
      ) : null}
    </header>
  );
}
