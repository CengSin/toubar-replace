# ToubarReplace 官网

Mac 菜单栏应用 ToubarReplace 的产品官网：把 Touch Bar 做成订阅用量与常用 App 的触控启动台。

线上地址：https://toubarreplace.z-agent.ccwu.cc

当前展示版本 **2.0.0**。页面里的工作区、用量、应用和设置图来自正在运行的应用截图。

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

静态导出到 `out/`。下载文件来自仓库 `ToubarReplace/dist` 中的 2.0.0 安装包，复制到 `public/downloads/`。
