# 状态栏菜单 (Status Bar Menu)

## 状态栏图标与主菜单
- 用户称呼：状态栏菜单、顶部菜单、Tray 菜单、应用托盘
- 入口：macOS 顶部系统状态栏右侧 ToubarReplace 图标（图标为 `rectangle.inset.filled`）
- 关键选择器：
  - 状态栏项：`NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)`
  - 图标无障碍标签：`accessibilityDescription: "ToubarReplace"`
  - 界面显隐菜单项：`NSMenuItem(title: "显示 / 隐藏 ToubarReplace", action: #selector(toggleCapsule))`
  - 场景切换菜单项：`NSMenuItem(title: "切换 Touch Bar / Workspace", action: #selector(toggleWorkspace))`
  - 菜单项 2：`NSMenuItem(title: "设置…", action: #selector(showSettings))`
  - 菜单项 3：`NSMenuItem(title: "版本 \(ToubarReplaceAppInfo.version)", action: nil)`（`isEnabled = false`）
  - 菜单项 4：`NSMenuItem(title: "帮助…", action: #selector(showHelp))`
  - 菜单项 5：`NSMenuItem.separator()`
  - 菜单项 6：`NSMenuItem(title: "退出 ToubarReplace", action: #selector(quit))`
- 子功能：
  - 显示/隐藏界面：通过 `DesktopCapsuleController` 同步桌面窗口与物理 Touch Bar；隐藏时退出窗口显示，唤醒时按配置尺寸弹性展开
  - 场景切换：在 Touch Bar 镜像与 Workspace 间切换，软件设备可从菜单进入工作台
  - 打开设置窗口：将应用临时切换为前台激活模式（`NSApp.setActivationPolicy(.regular)`）并调出设置窗口
  - 显示当前版本号：展示已安装应用的语义化版本号
  - 查看帮助指引：弹出 Control Strip 终端重置与恢复命令弹窗
  - 退出应用：彻底终止应用程序进程（`NSApp.terminate`）
- 前置条件：应用已启动并常驻后台（`LSUIElement` / `.accessory` 模式）
- 常见故障现象：
  - 状态栏未找到图标：顶部状态栏图标过多被系统收起，或应用未正常启动
  - 点击“显示 / 隐藏 ToubarReplace”无响应：窗口已在不可见屏幕空间，可在设置中选择底部位置
