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
  - 展示 Control Strip 修复指南：给出重置 macOS 系统级触控栏配置并杀死 ControlStrip 守护进程的标准命令
  - 激活策略安全隔离：打开时临时切换到 `.regular` 模式以展示模态窗口，关闭后安全恢复为 `.accessory` 模式
  - 自动呈现保活：弹窗关闭后自动调用 `ensurePhysicalSwitcherPresented()`，确保物理栏网格按钮未被系统意外注销
- 前置条件：状态栏菜单点击唤起
- 常见故障现象：
  - 关闭弹窗后物理栏图标丢失：系统重构 Function Row 导致丢失焦点，应用在弹窗关闭后已安排自动补挂保证不丢
