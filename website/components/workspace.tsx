import { FadeIn } from "@/components/fade-in";
import { TouchBarFrame } from "@/components/touch-bar";

export function Workspace() {
  return (
    <section
      id="workspace"
      className="scroll-mt-24 bg-bg px-6 py-24 md:px-12 md:py-32"
    >
      <FadeIn className="mx-auto max-w-[720px]">
        <h2 className="text-4xl font-medium tracking-[-0.03em] text-ink md:text-5xl">
          一条栏，两个区。
        </h2>
        <p className="mt-5 max-w-[42ch] text-[16px] leading-relaxed text-muted">
          左侧看订阅用量，右侧打开常用 App。订阅多了可以左右滑，点一下就启动。
        </p>
      </FadeIn>
      <FadeIn delay={0.1} className="mx-auto mt-12 max-w-5xl md:mt-16">
        <TouchBarFrame />
      </FadeIn>
    </section>
  );
}
