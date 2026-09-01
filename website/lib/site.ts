export const SITE = {
  name: "ToubarReplace",
  tagline: "手指一点，打开 Agent",
  description:
    "把 MacBook Touch Bar 做成路径、Agent 与常用 App 的触控启动台。",
  version: "1.1.9",
  dmg: "/downloads/ToubarReplace.dmg",
  pkg: "/downloads/ToubarReplace.pkg",
  mac: "macOS 14 及以上，Universal",
} as const;

export const AGENTS = [
  { name: "Codex", src: "/agents/codex.png", dot: "#34C759" },
  { name: "Cursor", src: "/agents/cursor.png", dot: "#FF9F0A" },
  { name: "Claude Code", src: "/agents/claudeCode.png", dot: "#8E8E93" },
  { name: "Grok Build", src: "/agents/grokBuild.png", dot: "#BF5AF2" },
] as const;
