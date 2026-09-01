import Image from "next/image";
import { FadeIn } from "@/components/fade-in";

export function How() {
  return (
    <section className="bg-bg px-6 py-24 md:px-12 md:py-32">
      <div className="mx-auto grid max-w-[1400px] items-center gap-10 lg:grid-cols-12 lg:gap-16">
        <FadeIn className="relative aspect-[4/3] overflow-hidden rounded-[18px] lg:col-span-7">
          <Image
            src="/images/desk.jpg"
            alt="打开的 MacBook 放在深色桌面上，Touch Bar 亮着"
            fill
            sizes="(max-width: 1024px) 100vw, 60vw"
            className="object-cover"
          />
        </FadeIn>
        <FadeIn delay={0.08} className="lg:col-span-5">
          <h2 className="text-4xl font-medium leading-[1.12] tracking-[-0.03em] text-ink md:text-5xl">
            安装。
            <br />
            对准。
            <br />
            <span className="underline decoration-accent decoration-2 underline-offset-8">
              点一下。
            </span>
          </h2>
          <p className="mt-6 max-w-[34ch] text-[16px] leading-relaxed text-muted">
            装上应用，打开项目，在栏上点 Agent。手指不用离开主键盘。
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
