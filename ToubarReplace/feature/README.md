# ToubarReplace 功能地图与特性文档 (Feature Catalog)

本目录归档 ToubarReplace 所有页面、界面窗口、触控栏模式及子功能的结构化说明。面向后续自动化测试编写、UI 回归及功能迭代。

---

## 文档目录索引

| 序号 | 文档名称 | 对应模块/页面 | 核心交互对象 |
| :--- | :--- | :--- | :--- |
| 01 | [`01-status-bar-menu.md`](01-status-bar-menu.md) | 状态栏菜单 (Status Bar Menu) | 状态栏图标、显隐控制、设置与退出入口 |
| 02 | [`02-settings-window.md`](02-settings-window.md) | 设置面板 (Settings Window) | 展示位置、自定义坐标、像素分辨率、比例滑块、订阅勾选、App 管理 |
| 03 | [`03-mirror-window.md`](03-mirror-window.md) | 桌面镜像浮窗 (Touch Bar Mirror Window) | 流式镜像窗口、鼠标穿透策略、悬停 0.3 透明度、转场盖板 |
| 04 | [`04-workspace-floating-switcher.md`](04-workspace-floating-switcher.md) | 独立切换浮窗 (Workspace Floating Switcher) | 48×36 桌面小方块、短按切场景、长按自由拖拽移动 |
| 05 | [`05-physical-touchbar-switcher.md`](05-physical-touchbar-switcher.md) | 物理 Touch Bar 切换键 (Physical Switcher Item) | 物理栏 Placement 0 网格按钮、保留 Control Strip、关闭盒抑制 |
| 06 | [`06-workspace-touchbar.md`](06-workspace-touchbar.md) | Workspace 触控工作台 (Workspace Touch Bar) | 全宽 Placement 1 托盘、Escape 槽独立返回、桌面软工作台模式 |
| 07 | [`07-quota-plate.md`](07-quota-plate.md) | 额度用量展示看板 (Quota Plate View) | 5h/周/重置三竖柱、按量付费卡片、智能浪费压力推荐、无条横滑 |
| 08 | [`08-custom-apps.md`](08-custom-apps.md) | 自定义应用启动区 (Custom Apps Zone) | 常用应用 5 槽位自适应排布、空态引导、齿轮设置入口、一键拉起 |
| 09 | [`09-help-and-diagnostics.md`](09-help-and-diagnostics.md) | 故障诊断与帮助指引 (Help and Diagnostics) | Control Strip 系统重置终端命令展示、保活恢复 |

---

## 功能文档编写标准模板

每次新增页面或重构界面时，必须在 `feature/` 下创建或同步更新对应文档，统一遵循以下规范格式：

```markdown
## <页面或功能名称>
- 用户称呼：<用户习惯称呼、别名、标签>
- 入口：<到达该功能或页面的精确路径与触发手势>
- 关键选择器：<代码中的类名、Item Identifier、Autosave Name 或 Accessibility Identifier>
- 子功能：<该功能包含的具体子能力列表与逻辑说明>
- 前置条件：<运行该功能所需的环境、权限或状态依赖>
- 常见故障现象：<常见异常表现、排查指引与已知恢复策略>
```

---

## 维护规范

1. **控件标识真实性**：选择器字段必须与 AppKit / SwiftUI 源代码中的 identifier、autosave name、accessibilityLabel 等完全一致，不得臆造。
2. **变更同步**：当 UI 布局、快捷键、交互层级或数据映射逻辑发生变更时，修改代码的同时必须同步更新对应的 feature 文档。
3. **冒烟测试覆盖**：新增或修改功能文档后，运行 `Scripts/run-regression.sh` 确保系统回归与断言完全一致。
4. **仅描述已有能力**：文档仅记录当前已实现且生效的功能与行为，严禁编写否定性免责声明（无需写“不可做某某”、“不支持某某”、“由其他区域负责”等冗余内容）。
