import { SITE } from "@/lib/site";

export function Footer() {
  return (
    <footer className="bg-bg px-6 pb-10 pt-6 md:px-12">
      <div className="mx-auto max-w-[1400px] border-t border-line pt-8">
        <div className="flex flex-col gap-6 md:flex-row md:items-center md:justify-between">
          <a href="#top" className="text-[15px] font-medium tracking-tight">
            Toubar<span className="text-accent">Replace</span>
          </a>
          <nav className="flex flex-wrap items-center gap-6 text-[14px] text-muted">
            <a href="#workspace" className="hover:text-ink">
              工作区
            </a>
            <a href="#compat" className="hover:text-ink">
              兼容
            </a>
            <a href={SITE.dmg} download className="hover:text-ink">
              下载应用
            </a>
          </nav>
        </div>
        <p className="mt-8 text-[12px] text-muted">
          {new Date().getFullYear()} {SITE.name}. 菜单栏应用，macOS 14 及以上。
        </p>
      </div>
    </footer>
  );
}
