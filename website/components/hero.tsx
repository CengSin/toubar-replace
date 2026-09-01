import Image from "next/image";
import { DownloadButton } from "@/components/download-button";
import { SITE } from "@/lib/site";

export function Hero() {
  return (
    <section
      id="top"
      className="relative min-h-[100dvh] overflow-hidden bg-bg"
    >
      <Image
        src="/images/hero.jpg"
        alt="Space gray MacBook 键盘与发光的 Touch Bar"
        fill
        priority
        sizes="100vw"
        className="object-cover object-[center_35%]"
      />
      <div className="absolute inset-0 bg-gradient-to-t from-[rgba(8,9,11,0.92)] via-[rgba(8,9,11,0.38)] to-[rgba(8,9,11,0.22)]" />
      <div className="absolute inset-0 bg-gradient-to-r from-[rgba(8,9,11,0.55)] via-transparent to-transparent" />

      <div className="relative z-10 mx-auto flex min-h-[100dvh] max-w-[1400px] flex-col justify-end px-6 pb-16 pt-24 md:px-12 md:pb-20">
        <div className="hero-copy max-w-xl">
          <h1 className="text-[42px] font-medium leading-[1.08] tracking-[-0.035em] text-white md:text-6xl">
            手指一点。
            <br />
            打开 Agent。
          </h1>
          <p className="mt-5 max-w-[34ch] text-[16px] leading-relaxed text-white/72 md:text-[17px]">
            {SITE.description}
          </p>
          <div className="mt-8 flex flex-wrap items-center gap-3">
            <DownloadButton href={SITE.dmg} download>
              下载应用
            </DownloadButton>
            <a
              href="#workspace"
              className="inline-flex h-11 items-center rounded-full px-4 text-[15px] text-white/80 underline decoration-white/25 underline-offset-4 transition-colors hover:text-white"
            >
              查看工作区
            </a>
          </div>
        </div>
      </div>
    </section>
  );
}
