import Image from "next/image";
import { FadeIn } from "@/components/fade-in";

const ITEMS = [
  {
    id: "quota",
    title: "用量",
    body: "读本机 OpenUsage，每个订阅三根竖柱：短时、周剩余、下次重置。多了左右滑，设置里勾选要展示的项。",
    image: "/images/workspace-quota.png",
    width: 1104,
    height: 80,
    alt: "用量区真实截图：Grok Build、Cursor 与推荐的 Grok Bots 三柱",
  },
  {
    id: "recommend",
    title: "推荐",
    body: "浪费风险最高的订阅会描边，对应额度柱为琥珀色。点那一列打开对应应用，不用先去找图标。",
    image: "/images/workspace-recommend.png",
    width: 256,
    height: 80,
    alt: "推荐订阅真实截图：Grok Bots 描边，5 小时额度柱为琥珀色",
  },
  {
    id: "apps",
    title: "应用",
    body: "把最多五个常用 App 钉在栏上。点图标只负责打开，右侧齿轮进入设置管理。",
    image: "/images/workspace-apps.png",
    width: 1250,
    height: 80,
    alt: "自定义 App 区真实截图：固定应用图标与设置齿轮",
  },
] as const;

export function Features() {
  return (
    <section className="bg-bg px-6 py-24 md:px-12 md:py-32">
      <div className="mx-auto grid max-w-[1400px] gap-4 md:grid-cols-3">
        {ITEMS.map((item, i) => (
          <FadeIn key={item.id} delay={i * 0.06}>
            <article className="flex h-full flex-col overflow-hidden rounded-[18px] bg-elev ring-1 ring-line">
              <div className="flex min-h-[148px] items-center overflow-hidden bg-[#111214] px-4 py-8 md:min-h-[180px] md:px-5">
                <Image
                  src={item.image}
                  alt={item.alt}
                  width={item.width}
                  height={item.height}
                  className="h-14 w-auto max-w-none md:h-16"
                />
              </div>
              <div className="flex flex-1 flex-col p-6 md:p-7">
                <h3 className="text-2xl font-medium tracking-tight text-ink">
                  {item.title}
                </h3>
                <p className="mt-2 max-w-[36ch] text-[14px] leading-relaxed text-muted">
                  {item.body}
                </p>
              </div>
            </article>
          </FadeIn>
        ))}
      </div>
    </section>
  );
}
