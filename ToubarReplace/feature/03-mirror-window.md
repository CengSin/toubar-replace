# 桌面镜像浮窗 (Touch Bar Mirror Window)

## 桌面 Touch Bar 镜像展示窗口
- 用户称呼：桌面 Touch Bar、镜像浮窗、镜像窗口、桌面条
- 入口：
  - 应用启动后常驻在桌面（当启动场景为镜像，或在镜像模式下）
  - 通过菜单栏「显示或隐藏 Touch Bar」重新显示
- 关键选择器：
  - 窗口类型：`NSPanel`（`styleMask: [.borderless, .resizable, .nonactivatingPanel]`, `level: .floating`）
  - 窗口 Frame Autosave：`ToubarReplaceMirrorWindow`
  - 画面承载视图：`TouchBarSurfaceView`（`imageView.layer?.contentsGravity = .resizeAspect`）
  - 状态提示文本：`statusLabel`（`NSTextField`，居中显示白字）
    - 初始状态："正在读取 Touch Bar…"
    - 无硬件状态："当前 Mac 无物理 Touch Bar\n点击切换按钮打开 Workspace，查看额度并启动应用"
    - 错误状态："\(error.localizedDescription)\n\n恢复命令（终端）：\n\(ToubarReplaceAppInfo.recoveryCommands)"
  - 切换过渡遮罩：`MirrorSceneTransition`（`settleDuration: 221ms`, `fadeDuration: 0.12s`）
  - 鼠标悬停透明度控制器：`TouchBarHoverOpacityController`（正常状态 `alpha = 1.0`，鼠标悬停 `alpha = 0.3`）
- 子功能：
  - 物理 Touch Bar 流式镜像：通过私有 API `SLSDFRDisplayStreamCreate` 创建连续捕获流，并将画面呈现于桌面窗口
  - 鼠标穿透点击：在镜像场景下 `ignoresMouseEvents = true`，鼠标点击穿透至桌面底层应用程序，窗口不可随意拖拽
  - 鼠标悬停半透明：全局鼠标监视检测，进入窗口区域立即淡化至 30% 透明度，离开后恢复 100%，避免遮挡屏幕内容
  - 平滑无感场景切换：物理/软件模式切换时冻结最后一帧（cover），等待 221ms 系统 Function Row 重排稳定后执行 0.12s 渐隐淡出，遮盖系统重排脏帧
  - 故障提示与重置引导：画面出现黑屏或系统 Control Strip 异常时，自动展示终端恢复命令
- 前置条件：
  - 有物理 Touch Bar 机器：私有 DFR 显示流可用
  - 无物理 Touch Bar 机器：进入软件空闲说明态，引导用户打开 Workspace
- 常见故障现象：
  - 窗口全黑或白屏：macOS Control Strip 配置损坏或显示流断连，需在终端执行 `defaults delete com.apple.controlstrip ... && killall ControlStrip`
  - 鼠标点击被拦截无法操作桌面下方窗口：误切入桌面软件 Workspace 模式（软件 Workspace 允许鼠标交互，而镜像模式穿透鼠标）
