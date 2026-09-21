# 自定义应用启动区 (Workspace Custom Apps Zone)

## 常用应用触控启动栏
- 用户称呼：常用应用区、自定义 App、App 槽位、快捷启动区、桌面 App 快捷栏
- 入口：位于 Workspace 触控托盘右侧（宽度由设置「区域比例」决定，默认占据托盘 30% 宽度）
- 关键选择器：
  - 应用区容器：`WorkspaceCustomAppsView`
  - 空态添加按钮：`WorkspaceChromeButton`
    - 标题：`"自定义app"`
    - Tooltip：`"点击在设置中添加常用应用"`
    - 无障碍标签：`accessibilityLabel: "添加自定义 App"`
  - 已固定应用按钮：`WorkspaceChromeButton`
    - 图标：应用原生高清图标（如 `Xcode`、`VSCode`、`Cursor` 等，回退到 `app.dashed`）
    - 无障碍标签：应用显示名称（如 `"Visual Studio Code"`）
    - Tooltip：`"打开 \(app.displayName)"`
  - 管理设置齿轮按钮：`WorkspaceChromeButton`
    - 图标：`gearshape`（系统 SF Symbol）
    - 无障碍标签：`accessibilityLabel: "管理常用应用"`
    - Tooltip：`"管理常用应用"`
- 子功能：
  - 一键快速拉起应用：轻触应用图标瞬间通过 `NSWorkspace.shared.open` 启动或聚焦对应应用程序
  - 引导配置常用应用：空态下显示「自定义app」大按钮，点击直接呼出设置面板的常用应用添加流程
  - 常驻设置入口：右侧常驻齿轮按钮，随时可唤起设置面板进行新增、替换或移除
  - 等分自适应网格排布：槽位宽度根据当前已固定应用数量自适应均分铺满，图标保持标准尺寸居中显示
  - 启动失败错误反馈：当被选应用移动、丢失或无执行权限时，弹窗提示明确错误原因，禁止静默忽略
- 前置条件：在设置中已固定至少 1 个本机 `.app` 应用（最多 5 个）
- 常见故障现象：
  - 点击图标无任何反应：应用被删除或路径发生变化，需在设置中点击「替换…」重新指定
  - macOS 弹出安全性或自动化拦截弹窗：部分沙盒应用或系统组件首次通过外部启动时需用户点击允许
