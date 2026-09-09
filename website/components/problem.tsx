import { FadeIn } from "@/components/fade-in";
import { TouchBarFrame } from "@/components/touch-bar";

export function Problem() {
  return (
    <section className="bg-bg px-6 py-24 md:px-12 md:py-32">
      <FadeIn className="mx-auto max-w-[920px] text-center">
        <h2 className="text-4xl font-medium tracking-[-0.03em] text-ink md:text-5xl">
          Dock 太远了。
        </h2>
        <p className="mx-auto mt-5 max-w-[36ch] text-[16px] leading-relaxed text-muted">
          用量和常用 App 就在键盘上方。点一下打开订阅对应的应用，不用去 Dock
          里找图标。
        </p>
      </FadeIn>
      <FadeIn delay={0.08} className="mx-auto mt-12 max-w-4xl md:mt-16">
        <TouchBarFrame />
      </FadeIn>
    </section>
  );
}
