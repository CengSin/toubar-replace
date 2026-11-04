# 故障诊断与帮助指引 (Help and Diagnostics)

## Control Strip 故障重置弹窗
- 用户称呼：帮助窗口、Control Strip 恢复帮助、Troubleshooting 弹窗、修复指引
- 入口：顶部系统状态栏菜单 → 点击「帮助…」
- 关键选择器：
  - 弹窗类型：`NSAlert`（`alertStyle = .informational`）
  - 弹窗标题：`messageText = "ToubarReplace 帮助"`
  - 确认按钮：`alert.addButton(withTitle: "完成")`
  - 提示内容包含指令：
    ```sh
    defaults delete com.apple.controlstrip FullCustomized
    defaults delete com.apple.controlstrip MiniCustomized
    killall ControlStrip
    ```
- 子功能：
  - 系统设置引导：帮助开头说明「系统设置 → 键盘 → 触控栏设置」，调整触控栏显示内容和 Fn 行为
  - 展示 Control Strip 修复指南：给出重置 macOS 系统级触控栏配置并杀死 ControlStrip 守护进程的标准命令
  - 激活策略安全隔离：打开时临时切换到 `.regular` 模式以展示模态窗口，关闭后安全恢复为 `.accessory` 模式
  - 自动呈现保活：弹窗关闭后自动调用 `ensurePhysicalSwitcherPresented()`，确保物理栏网格按钮未被系统意外注销
- 前置条件：状态栏菜单点击唤起
- 常见故障现象：
  - 关闭弹窗后物理栏图标丢失：系统重构 Function Row 导致丢失焦点，应用在弹窗关闭后已安排自动补挂保证不丢

## 显示流生命周期验收
- 用户称呼：显示流诊断、捕获资源验收、启停压力测试
- 入口：项目根目录运行 `./Scripts/verify-capture-lifecycle.sh`；添加 `--stress` 执行 100 次启停
- 关键选择器：`CaptureLifecycleVerifier`、`CaptureLifecycleProbe`、`MeasuredDisplayStream`、`TouchBarStopSignalTracker`、`RetainedTouchBarSurface`
- 子功能：
  - 默认执行 4 次捕获暂停与恢复，压力模式执行 100 次；使用真实 DFR 流统计逻辑启停、底层启动、关闭确认及画面数量
  - 校验底层 DFR 流只创建和启动一次，最终关闭时释放全部流对象；输出 `native_starts`、`native_shutdowns`、`retained_streams` 等 JSON 验收指标
  - 压力模式预热后输出 `phase: ready`，随后等待 3 秒开始循环，供外部采样建立启动后的内存基准
  - 恢复时复用按 IOSurface 引用和使用计数保留的最近画面；关闭时识别私有 DFR 的零时间戳空帧通知并完成释放
  - 运行超时自动退出；捕获启停沿用系统原有 Touch Bar 状态
- 前置条件：具有物理 Touch Bar 的 Mac、项目构建工具及 macOS 26 或更新版本 SDK
- 常见故障现象：
  - `passed` 为 `false`：检查输出中的 `errors`、`raw_frames`、`delivered_frames` 和启停计数，结合系统显示流日志排查
  - 退出码为 `124`：系统显示流操作超时，检查 TouchBarServer 与 WindowServer 的运行状态
