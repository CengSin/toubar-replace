import Image from "next/image";
import { FadeIn } from "@/components/fade-in";
import { TouchBarFrame } from "@/components/touch-bar";

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
            带 Touch Bar 的 Intel Mac 上，完整镜像真实硬件。Workspace
            直接出现在物理栏上。
          </p>
          <div className="relative mt-8 aspect-[16/10] overflow-hidden rounded-[16px]">
            <Image
              src="/images/macro.jpg"
              alt="Touch Bar OLED 上青色与品红的胶囊按钮特写"
              fill
              sizes="(max-width: 1024px) 100vw, 50vw"
              className="object-cover"
            />
          </div>
        </FadeIn>
        <FadeIn delay={0.08} className="bg-elev p-8 md:p-12">
          <h2 className="text-2xl font-medium tracking-tight text-ink md:text-3xl">
            每一台 Mac
          </h2>
          <p className="mt-3 max-w-[36ch] text-[15px] leading-relaxed text-muted">
            没有物理栏时，桌面条同样可点。Apple Silicon 原生支持软件 Workspace。
          </p>
          <div className="mt-10 overflow-hidden">
            <div className="origin-top-left scale-[0.52] sm:scale-[0.58] lg:scale-[0.62] xl:scale-[0.68]">
              <div className="w-[720px]">
                <TouchBarFrame />
              </div>
            </div>
          </div>
        </FadeIn>
      </div>
    </section>
  );
}
