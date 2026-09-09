<p align="center">
  <img src="Resources/AppIcon.iconset/icon_256x256@2x.png" width="128" alt="ToubarReplace">
</p>

# ToubarReplace

把 MacBook Touch Bar 做成订阅用量与常用 App 的触控启动台：看还剩多少额度，点一下打开对应应用。带物理 Touch Bar 的机器上，还可以把真实硬件栏镜像到桌面。

官网：<https://toubarreplace.z-agent.ccwu.cc>

> **有物理 Touch Bar**（带栏的 Intel Mac，macOS 14 及以上）：Workspace 出现在物理栏上，桌面窗口镜像当前栏画面。  
> **无物理 Touch Bar**（含 Apple Silicon）：启动后默认进入桌面 **软件 Workspace**，条子可直接点；没有系统 Control Strip 的真镜像。

---

## 安装

### 从安装包安装（推荐）

1. 从[官网](https://toubarreplace.z-agent.ccwu.cc)下载，或打开发布包中的 **DMG** / 运行 **PKG**。
2. 将 `ToubarReplace.app` 拖入「应用程序」文件夹（PKG 会自动安装到该位置）。
3. 首次打开：若系统提示来自未识别的开发者，可在「系统设置 → 隐私与安全性」中允许打开，或右键图标选择「打开」。
4. 启动后，菜单栏会出现 ToubarReplace 图标（本应用为菜单栏应用，Dock 中默认不常驻）。

用量区依赖本机 [OpenUsage](https://github.com/robinebers/openusage)。未安装或暂无快照时，用量区显示「暂无额度」。

### 从源码构建（可选）

```sh
swift build
./.build/debug/ToubarReplace
```

打包为 `.app` / DMG / PKG（尽量打 **arm64 + x86_64** universal；单侧交叉编译失败时回退本机架构）：

```sh
TOUBAR_VERSION=2.0.0 Packaging/build-app.sh
```

产物在 `dist/` 目录。可用 `lipo -info dist/ToubarReplace.app/Contents/MacOS/ToubarReplace` 查看架构切片。

构建、回归测试与实现边界见 [`docs/README-developer.md`](docs/README-developer.md)。

---

## 功能概览

默认启动后进入 **Workspace**。设置里可将「启动后进入」改为镜像。

### Workspace（工作区）

一条栏，两个区：左侧看订阅用量，右侧打开常用 App。有物理栏时呈现在 Touch Bar 上；没有物理栏时画在桌面条上，可直接点击。

- **切换**：有物理 Touch Bar 时，设置「切换按钮」可选物理栏网格，或可拖动的独立浮窗，二者只显示一个。无物理栏时，镜像场景用独立浮窗，Workspace 用条子左侧返回。短按浮窗切换场景，长按或拖动只调整浮窗位置。Workspace 左侧返回可回到镜像。
- **用量区**：读本机 OpenUsage 里每一个带用量的订阅（例如 Grok Build、Codex、Cursor、Claude、Antigravity、OpenRouter 等；Cursor 的 Grok Bots 会单独成列）。每列三根竖柱：短时剩余、周/长周期剩余、距下次重置；柱高表示剩余比例，没有该窗口则显示淡空柱。浪费风险最高的订阅描边，对应额度柱为琥珀色。订阅较多时可左右滑动。设置「用量订阅」可勾选要展示的项（新发现的默认显示）。点某一列打开对应应用（已固定的自定义 App，或能解析到的 `.app` / 网页）。桌面条上把鼠标停在列上可看完整数字。数据先读 OpenUsage 的 `127.0.0.1:6736`，失败再跑 `OpenUsage.app` 自带的 `openusage` 命令。
- **应用区**：最多固定 5 个常用 `.app`。空态点「自定义app」、有应用时点右侧齿轮，都打开**设置**做新增 / 替换 / 移除；点图标只打开该应用。满员后不会悄悄挤掉已有项。

### 桌面镜像窗口

- 有物理栏时，实时显示当前 Touch Bar 画面（默认 2300×70 像素、30 帧/秒，均可在设置中调整）。
- 无物理栏且启动进入镜像时，窗口提示「当前 Mac 无物理 Touch Bar」，通过切换按钮进入软件 Workspace。
- 默认定在屏幕底部；可改为顶部、中央、上次关闭位置，或自定义窗口左上角坐标（AppKit 坐标，Y 轴向上）。
- **镜像场景点击穿透**：鼠标点到窗口会落到背后的应用，窗口本身不能拖动。位置用设置里的展示位置 / 自定义坐标调整。软件 Workspace 画在同一窗口里时**可以点击**条子。
- 窗口出现在所有桌面空间。菜单栏「显示或隐藏 Touch Bar」可把这个窗口藏起来或再显示。
- **空闲透明只作用于镜像**：有新画面时 100% 不透明；仅当浮窗挡住其他 app 内容、且无更新达到设置的延迟后，才降到 30%（默认 5 秒，可设 1–300 秒）。浮在空桌面上保持 100%。Workspace 场景不会因空闲变淡。
- 镜像窗口不把鼠标坐标映射到物理 Touch Bar；有物理栏时，触控请在栏上完成。

### 设置与菜单

菜单栏图标可打开：

- **显示或隐藏 Touch Bar**：显示或收起桌面窗口
- **设置…**：窗口四边和四角均可调整大小，尺寸会保存。可配置启动后进入 Workspace 或镜像、展示位置、镜像宽高、帧率、透明延迟、切换按钮（物理栏网格 / 独立浮窗）、用量区要展示的订阅、自定义 App
- **版本**：当前安装版本（不可点）
- **帮助…**：镜像全黑或空白时的 Control Strip 恢复命令
- **退出 ToubarReplace**

打开设置时应用会暂时变为普通前台应用，关闭设置后回到菜单栏模式。

---

## 使用提示

1. **用量区是空的**  
   请先安装并运行 [OpenUsage](https://github.com/robinebers/openusage)，确认设置「用量订阅」里能读到项目。未安装或暂无快照时显示「暂无额度」。

2. **镜像异常 / 画面全黑或空白**  
   打开菜单栏 **帮助…**，或在终端依次执行：

   ```sh
   defaults delete com.apple.controlstrip FullCustomized
   defaults delete com.apple.controlstrip MiniCustomized
   killall ControlStrip
   ```

   等几秒，显示流会自动重连。

3. **锁屏或睡眠**  
   应用会暂停捕获，并收起物理栏上的 Workspace / 切换按钮。解锁或唤醒后自动恢复；睡眠前若在 Workspace，醒来仍回到 Workspace。

4. **「App 控制」或「快速操作」下暂时没有可显示内容**  
   镜像会保留最后一帧并给出提示；切换到支持触控栏的 App，或启用一个快速操作后会自动恢复。
