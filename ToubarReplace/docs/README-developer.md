# ToubarReplace 开发说明

ToubarReplace 是 macOS 菜单栏应用：带 Touch Bar 的 Mac 通过私有显示流镜像真实物理栏，并可临时呈现全宽 Workspace；没有可用物理栏时直接在桌面窗口中运行可交互的软件 Workspace。

## 构建与回归

```sh
swift build
./.build/debug/ToubarReplace
Scripts/run-regression.sh
```

分发包通过下列命令构建；脚本尽量合并 arm64 与 x86_64，单侧交叉编译失败时回退为可用架构。

```sh
TOUBAR_VERSION=1.2.3 Packaging/build-app.sh
```

GitHub Actions 工作流在仓库根目录 `.github/workflows/`（必须放在根目录，GitHub 不会读取 `ToubarReplace/.github`）：

- `ci.yml`：push / PR 跑应用 smoke test（`macos-26`）和官网 lint + build
- `package.yml`：打 tag `v*` 或在 Actions 里手动运行，产出 DMG / PKG；挂到 GitHub Release 时同时上传带版本号的文件和稳定名 `ToubarReplace.dmg` / `ToubarReplace.pkg`（官网 `/releases/latest/download/` 用这两个名字）

手动打包：仓库 **Actions → Package → Run workflow**。

smoke test 不创建窗口、不连接私有 Touch Bar 显示流，主要验证尺寸、布局、placement、PresentationMode 策略、额度映射/滑动/隐藏、启动参数、硬件能力策略和异步打开错误传播。私有 system modal 行为仍需带 Touch Bar 的 Intel 真机验证。读本机 OpenUsage HTTP 需要 `NSAllowsLocalNetworking`。

## 桌面窗口与切换按钮

镜像 viewport 默认是 `2300 × 70` 像素，在 Retina 屏幕上约为 `1150 × 35` 点。窗口不可拖动且点击穿透；位置由设置中的底部、顶部、中央、上次关闭位置或自定义左上角坐标控制。

有物理 Touch Bar 时，切换按钮有两种互斥模式：

- 物理 Touch Bar 网格按钮：`SwitcherTouchBarController`，placement `0`，保留 Control Strip。
- 独立浮窗：`WorkspaceSwitcherWindowController`，短按切换，长按或拖动只调整浮窗位置。

无物理 Touch Bar 时，有效模式固定为独立浮窗。启动场景由设置「启动后进入」决定，默认 Workspace；选镜像则显示无硬件说明态。硬件模式即使启动进入 Workspace 也要先开显示流。睡眠前若在 Workspace，唤醒后恢复 Workspace。软件模式不得启动显示流或呈现 system modal。

桌面窗口（镜像与 Workspace）在鼠标进入后立刻变为 30% 不透明，离开后恢复 100%。物理 Touch Bar 不改透明度。点击穿透时用全局鼠标监视检测悬停。

## Workspace

物理 Workspace 使用独立的 `WorkspaceTouchBarController`：placement `1`，`PresentationModeGlobal = app`，不保留右侧 Control Strip。退出 Workspace 时按策略恢复进入前的 PresentationMode。镜像与 Workspace 两套 modal 不得合并。

物理栏返回键必须是 `escapeKeyReplacementItemIdentifier`（`WorkspaceReturnItemView`）。tray 是**唯一** default item；两条 default item 会让 principal 被丢掉、Function Row 只剩箭头。软件 Workspace 仍把返回画在 `WorkspaceBarView` 里。

Tray 固定两区：**额度 `4/10` | 自定义 App `6/10`**。已删除路径 / 最近项目、内置 Agent 槽位、终端 App 选择。物理 tray item 用 `preferredTrayWidth`（全宽 cap 减去 Escape 槽），全条 cap 仍是 `maximumContentWidth = 1010` 点，避免右侧齿轮被 Function Row chrome 裁切。高度固定约 30 点。

额度板为每个 OpenUsage consumption 订阅一列（Cursor 的 `grokBot` 另拆成 Grok Bots）。列内三根竖柱：短时（≤8h，标 5h）、周/长周期、距周额度重置。列宽不低于 `quotaGroupMinimumWidth`（144）；装不下时 `QuotaPlateView` 横向滑动，不要改成展开/图标芯片。浪费风险 `remainingRatio * exp(-hoursLeft / 12h)`，最高者描边，贡献该分数的额度柱为琥珀色。设置「用量订阅」可隐藏个别池（`ToubarReplace.workspace.hiddenQuotaProviders`），默认全显示。数据先读 `127.0.0.1:6736/v1/limits`，失败再跑 `OpenUsage.app/Contents/Helpers/openusage`，不要 `--force`。点某一列打开对应应用（已固定自定义 App，或已知 bundle / 名称 / 回退 URL）。图标在 `Resources/AgentIcons/`。

自定义 App 最多 5 个，在设置中新增、替换或移除；满员拒绝静默挤出。空态「自定义app」、有应用时右侧齿轮均打开设置。点击图标只打开应用。`NSWorkspace` completion error 必须显示，不能静默忽略。

`docs/design-workspace-touchbar-proposal*.png` 与早期 Path|Agents|Custom 稿是历史设计；现行额度三柱见 `docs/design-workspace-quota-bars*.png` 与 `memory/workspace-quota-zone-layout.md`。

## 捕获与生命周期

物理画面来自 `SLSDFRDisplayStreamCreate` 创建的持续显示流，帧数据由 `IOSurface` 提供；帧率跟随显示流原生回调，应用层不再限流。主线程仍通过 `TouchBarFrameDeliveryCoalescer` 合并堆积帧。

锁屏、屏幕休眠或系统休眠时停止捕获并 dismiss 物理栏；解锁或唤醒后，硬件模式重建显示流和物理切换按钮，软件模式重新进入桌面 Workspace。显示流启动后 5 秒没有任何状态会自动重连；持续至少 0.5 秒的全黑帧才判定为异常，且不覆盖最后一张有效画面。

镜像场景切换使用 `MirrorSceneTransition` 冻结最后一帧，当前 settle 为 221ms，fade 为 0.12s。该 cover 只改善桌面镜像观感，无法消除物理栏 placement/mode 重排。

## 私有 API 边界

- 私有调用只通过 `TouchBarPrivateAPI` 封装。
- 硬件能力只检查显示流和 system modal API 是否可用，不按 CPU 或 `uname` 判断。
- 不调用未验证的 DFRDisplay selector，不合并双 modal，不实现镜像鼠标坐标映射。
- 私有 API 可能随 macOS 更新改变；不可用时进入软件 Workspace 或显示明确错误。
