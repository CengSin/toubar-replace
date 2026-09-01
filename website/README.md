# ToubarReplace 官网

Mac 菜单栏应用 ToubarReplace 的产品官网：把 Touch Bar 做成 Agent 启动台。

线上地址：https://toubarreplace.z-agent.ccwu.cc

## 本地运行

```sh
npm install
npm run dev
```

打开 `http://localhost:3000`。

## 构建与发布

```sh
NEXT_PUBLIC_SITE_URL=https://toubarreplace.z-agent.ccwu.cc npm run build
npx wrangler deploy
```

静态导出到 `out/`。下载文件来自仓库 `ToubarReplace/dist` 中的 1.1.9 安装包，已复制到 `public/downloads/`。
