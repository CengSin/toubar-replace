# 物理 Touch Bar 切换键 (Physical Switcher Item)

## 硬件触控栏网格切换按钮
- 用户称呼：物理栏切换键、Touch Bar 网格图标、左侧九宫格、栏上网格钮
- 入口：在配备物理 Touch Bar 的 Mac 上，处于镜像场景，且设置中「切换按钮」选为「物理 Touch Bar」
- 关键选择器：
  - Touch Bar Item Identifier：`NSTouchBarItem.Identifier("com.toubarreplace.switcher")`
  - Item Customization Label：`"Workspace"`
  - Placement：`0`（放置于左侧，保留系统右侧 Control Strip）
  - 宿主视图：`SwitcherTouchBarHostView`（尺寸: `44 × 30` pt）
  - 图标：`square.grid.2x2`（白色矢量图标）
  - 无障碍标签：`accessibilityLabel: "打开 Workspace"`
- 子功能：
  - 单击唤出 Workspace：轻触触控栏左侧网格，触发将物理栏模式从镜像切换为全宽 Workspace
  - 维持 Control Strip 协同：使用 Placement 0 策略，确保系统音量、亮度等 Control Strip 正常常驻
  - 系统关闭盒抑制：在设置窗口或其它应用激活时，异步抑制并隐藏系统插入的 "X" 关闭按钮（`suppressCloseBox` / `TBRHideSystemModalCloseButton`）
  - 异常脱离自愈恢复：监听 Touch Bar Window 挂载与脱离事件，当系统意外关闭该 Item 时自动重新挂载呈现
- 前置条件：具备物理 Touch Bar 硬件（Intel Mac）；私有 System Modal API 可用
- 常见故障现象：
  - 网格旁突然出现 "X" 关闭键：应用切换到前台或打开设置激活了系统模态关闭盒，ToubarReplace 会在激活后异步重新隐藏
  - 物理栏切换键消失：系统 ControlStrip 崩溃或重载，可在设置中重新切换一次按钮模式触发重挂
