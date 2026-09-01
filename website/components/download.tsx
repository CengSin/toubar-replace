import { DownloadButton } from "@/components/download-button";
import { FadeIn } from "@/components/fade-in";
import { SITE } from "@/lib/site";

export function Download() {
  return (
    <section
      id="download"
      className="flex min-h-[80dvh] scroll-mt-24 items-center bg-bg px-6 py-24 md:px-12 md:py-32"
    >
      <FadeIn className="mx-auto max-w-[760px] text-center">
        <div className="mx-auto mb-12 h-px w-full max-w-md bg-accent/80" />
        <h2 className="text-4xl font-medium tracking-[-0.03em] text-ink md:text-6xl">
          下载 {SITE.name}
        </h2>
        <p className="mt-4 text-[15px] text-muted">{SITE.mac}</p>
        <div className="mt-8 flex flex-col items-center gap-3">
          <DownloadButton href={SITE.dmg} download>
            下载应用
          </DownloadButton>
          <a
            href={SITE.pkg}
            download
            className="text-[14px] text-muted underline decoration-line underline-offset-4 hover:text-ink"
          >
            或获取 PKG
          </a>
        </div>
      </FadeIn>
    </section>
  );
}
