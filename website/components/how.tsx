import Image from "next/image";
import { FadeIn } from "@/components/fade-in";
import { SITE } from "@/lib/site";

export function How() {
  return (
    <section className="bg-bg px-6 py-24 md:px-12 md:py-32">
      <div className="mx-auto grid max-w-[1400px] items-center gap-10 lg:grid-cols-12 lg:gap-16">
        <FadeIn className="overflow-hidden rounded-[18px] bg-elev p-4 ring-1 ring-line sm:p-6 lg:col-span-7">
          <Image
            src="/images/settings.png"
            alt="ToubarReplace 设置窗口真实截图：用量订阅勾选与自定义 App 管理"
            width={1120}
            height={1504}
            className="mx-auto h-auto w-full max-w-[520px]"
          />
        </FadeIn>
        <FadeIn delay={0.08} className="lg:col-span-5">
          <h2 className="text-4xl font-medium leading-[1.12] tracking-[-0.03em] text-ink md:text-5xl">
            安装。
            <br />
            勾选。
            <br />
            <span className="underline decoration-accent decoration-2 underline-offset-8">
              点一下。
            </span>
          </h2>
          <p className="mt-6 max-w-[34ch] text-[16px] leading-relaxed text-muted">
            装上应用，在设置里勾选要展示的订阅、钉上常用 App。用量数据来自本机{" "}
            <a
              href={SITE.openUsage}
              className="underline decoration-line underline-offset-4 hover:text-ink"
            >
              OpenUsage
            </a>
            。手指不用离开主键盘。
          </p>
          <a
            href="#workspace"
            className="mt-8 inline-flex h-11 items-center rounded-full border border-line px-5 text-[15px] font-medium text-ink transition-colors hover:border-ink/40"
          >
            查看工作区
          </a>
        </FadeIn>
      </div>
    </section>
  );
}
