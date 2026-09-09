const GITHUB_RELEASES =
  "https://github.com/CengSin/toubar-replace/releases";

export const SITE = {
  name: "ToubarReplace",
  tagline: "手指一点，看用量、开应用",
  description:
    "把 MacBook Touch Bar 做成订阅用量与常用 App 的触控启动台。有物理栏时也可以镜像真实硬件。",
  version: "2.0.1",
  github: "https://github.com/CengSin/toubar-replace",
  releases: `${GITHUB_RELEASES}/latest`,
  // Stable names uploaded alongside versioned assets by Package workflow.
  dmg: `${GITHUB_RELEASES}/latest/download/ToubarReplace.dmg`,
  pkg: `${GITHUB_RELEASES}/latest/download/ToubarReplace.pkg`,
  mac: "macOS 14 及以上，Universal · 2.0.1",
  openUsage: "https://github.com/robinebers/openusage",
} as const;

export const AGENTS = [
  { name: "Grok Build", src: "/agents/grokBuild.png", dot: "#BF5AF2" },
  { name: "Grok Bots", src: "/agents/grokBots.png", dot: "#4EC8E8" },
  { name: "Codex", src: "/agents/codex.png", dot: "#34C759" },
  { name: "Cursor", src: "/agents/cursor.png", dot: "#FF9F0A" },
] as const;
