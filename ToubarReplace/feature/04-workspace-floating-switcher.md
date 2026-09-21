# 独立切换浮窗 (Workspace Floating Switcher)

## 桌面悬浮切换按钮
- 用户称呼：浮窗切换钮、小方块、切换按钮、桌面切换钮、悬浮窗
- 入口：
  - 设置中「切换按钮」选为「独立浮窗」
  - 或在 Apple Silicon / 无物理 Touch Bar 的 Mac 上自动强制启用
- 关键选择器：
  - 窗口类型：`NSPanel`（`styleMask: [.borderless, .nonactivatingPanel]`, `level: .floating`）
  - 窗口 Frame Autosave：`ToubarReplaceWorkspaceSwitcherWindow`
  - 浮窗视图：`WorkspaceFloatingSwitcherView`（固定尺寸: `48 × 36` pt）
  - 无障碍角色：`setAccessibilityRole(.button)`
  - 镜像模式下控件：
    - 图标：`square.grid.2x2`
    - 无障碍标签：`accessibilityLabel: "打开 Workspace"`
    - Tooltip：`"点击打开 Workspace；长按拖动可调整位置"`
  - Workspace 模式下控件：
    - 图标：`rectangle.on.rectangle.slash`
    - 无障碍标签：`accessibilityLabel: "返回 Touch Bar 镜像"`
    - Tooltip：`"点击返回 Touch Bar 镜像；长按拖动可调整位置"`
- 子功能：
  - 短按快速切换场景：按压时长 < 350ms 且鼠标位移 < 4pt 时触发切换，快速在 Touch Bar 镜像与 Workspace 触控台间转换
  - 长按与拖动调整位置：按压时长 ≥ 350ms 或位移 ≥ 4pt 时判定为拖动，用户可自由将浮窗拖到屏幕任意位置，释放后自动保存窗口坐标
  - 自动贴边初始化：首次打开且无保存坐标时，默认贴靠在桌面镜像窗口左侧（若屏幕空间不足则排在右侧）
  - 支持辅助功能按下：实现 `accessibilityPerformPress()` 响应辅助按键
- 前置条件：切换按钮模式配置为独立浮窗，或运行于无物理栏设备
- 常见故障现象：
  - 点击浮窗变成拖拽：点击时鼠标有抖动位移超过 4pt，触发了防误触拖动阈值
  - 拖拽后浮窗超出屏幕：拖出屏幕可见区域时，系统下一次对齐会自动归入可视屏幕安全边界
