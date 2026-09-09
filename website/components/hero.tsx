import { DownloadButton } from "@/components/download-button";
import { WorkspaceShot } from "@/components/workspace-shot";
import { SITE } from "@/lib/site";

export function Hero() {
  return (
    <section
      id="top"
      className="relative flex min-h-[100dvh] flex-col overflow-hidden bg-bg"
    >
      <div className="relative z-10 mx-auto flex w-full max-w-[1400px] flex-1 flex-col justify-end px-6 pb-10 pt-28 md:px-12 md:pb-12">
        <div className="hero-copy max-w-xl">
          <p className="mb-4 text-[13px] font-medium tracking-[0.18em] text-muted uppercase">
            {SITE.version}
          </p>
          <h1 className="text-[42px] font-medium leading-[1.08] tracking-[-0.035em] text-ink md:text-6xl">
            手指一点。
            <br />
            看用量，开应用。
          </h1>
          <p className="mt-5 max-w-[36ch] text-[16px] leading-relaxed text-muted md:text-[17px]">
            {SITE.description}
          </p>
          <div className="mt-8 flex flex-wrap items-center gap-3">
            <DownloadButton href={SITE.dmg}>
              下载应用
            </DownloadButton>
            <a
              href="#workspace"
              className="inline-flex h-11 items-center rounded-full px-4 text-[15px] text-muted underline decoration-line underline-offset-4 transition-colors hover:text-ink"
            >
              查看工作区
            </a>
          </div>
        </div>
      </div>
      <div className="relative mx-auto w-full max-w-[1400px] px-6 pb-16 md:px-12 md:pb-20">
        <WorkspaceShot priority />
      </div>
    </section>
  );
}
