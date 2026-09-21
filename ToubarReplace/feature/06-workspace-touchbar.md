# Workspace 触控工作台 (Workspace Touch Bar)

## Touch Bar 全宽工作台与桌面软件工作台
- 用户称呼：Workspace、工作区、启动台、额度条、TouchBar 工作台、桌面软件工作区
- 入口：
  - 物理 Touch Bar 上轻触左侧网格切换键
  - 或点击独立切换浮窗（桌面小方块）
  - 或设置中「启动后进入」配置为 Workspace，应用启动后自动呈现
- 关键选择器：
  - 物理模态配置：Placement `1`, PresentationModeGlobal `"app"`（全宽独占模式，不保留 Control Strip）
  - 物理返回键 Item Identifier：`NSTouchBarItem.Identifier.workspaceSwitcher`（`"ToubarReplace.Workspace.Switcher"`，注册为 `escapeKeyReplacementItemIdentifier`）
  - 物理托盘 Item Identifier：`NSTouchBarItem.Identifier.workspaceTray`（`"ToubarReplace.Workspace.Tray"`，作为唯一的 `defaultItemIdentifiers`）
  - 桌面软件工作台容器：`WorkspaceBarView`（嵌入在桌面窗口 `TouchBarRootView` 中）
  - 返回键控件：`WorkspaceReturnItemView`（硬件栏）/ `switcherButton`（软件栏）
    - 图标：`chevron.backward`
    - 无障碍标签：`accessibilityLabel: "返回 Touch Bar 镜像"`
    - Tooltip：`"点击返回 Touch Bar 镜像"`
  - 托盘容器：`trayView`（圆角深色底板，背景色 `WorkspaceTouchBarStyle.trayBackground`）
  - 分区隔离线：`zoneDivider`（1pt 垂直分割线，颜色 `WorkspaceTouchBarStyle.dividerColor`）
- 子功能：
  - 独立 Escape 返回机制：硬件栏使用专用的 Escape 槽位替换键，软件栏嵌入左侧回退键，轻触即可平滑退回镜像模式
  - 全宽托盘分流：托盘按照用户设定的 `quotaShare` 比例（默认 70%）分为左侧额度用量区与右侧常用应用区
  - 双硬件架构兼容：
    - 有物理栏时：托盘在真实 Touch Bar 硬件上呈现，桌面窗口镜像真实画面
    - 无物理栏时：桌面窗口直接呈现 `WorkspaceBarView` 软工作台，支持直接鼠标点击与悬停交互（解除鼠标穿透）
  - 边界安全保护：托盘右侧内置安全边距 `trayTrailingSafeInset = 12pt`，整体宽度限制在 `1010pt`，防止最右侧设置齿轮被 MacBook 硬件外框截断
- 前置条件：应用进入 Workspace 模式
- 常见故障现象：
  - 物理返回键无法点击：若将返回键错误放到主托盘中，会被系统关闭盒死区拦截； ToubarReplace 已采用 `escapeKeyReplacementItemIdentifier` 彻底隔离解决
  - 物理栏全黑只剩左侧箭头：如果 Touch Bar 注册了多个 `defaultItemIdentifiers` 会导致系统丢弃主要托盘；本项目严格保证托盘为唯一默认项
