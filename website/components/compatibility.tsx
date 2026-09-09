import { FadeIn } from "@/components/fade-in";
import { WorkspaceShot } from "@/components/workspace-shot";

export function Compatibility() {
  return (
    <section
      id="compat"
      className="scroll-mt-24 bg-bg px-6 py-24 md:px-12 md:py-32"
    >
      <div className="mx-auto grid max-w-[1400px] overflow-hidden rounded-[22px] ring-1 ring-line lg:grid-cols-2">
        <FadeIn className="border-b border-line p-8 md:p-12 lg:border-b-0 lg:border-r">
          <h2 className="text-2xl font-medium tracking-tight text-ink md:text-3xl">
            物理 Touch Bar
          </h2>
          <p className="mt-3 max-w-[36ch] text-[15px] leading-relaxed text-muted">
            带 Touch Bar 的 Intel Mac 上，Workspace 直接出现在物理栏上，桌面窗口镜像当前画面。
          </p>
          <WorkspaceShot className="mt-8" />
        </FadeIn>
        <FadeIn delay={0.08} className="bg-elev p-8 md:p-12">
          <h2 className="text-2xl font-medium tracking-tight text-ink md:text-3xl">
            每一台 Mac
          </h2>
          <p className="mt-3 max-w-[36ch] text-[15px] leading-relaxed text-muted">
            没有物理栏时，同一条 Workspace 画在桌面上，可直接点。Apple Silicon 原生支持软件
            Workspace。
          </p>
          <WorkspaceShot className="mt-8" />
        </FadeIn>
      </div>
    </section>
  );
}
