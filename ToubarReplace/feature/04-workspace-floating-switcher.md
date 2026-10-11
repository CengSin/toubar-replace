# 桌面展示与 Touch Bar 唤醒

## 桌面展示与手动显隐
- 用户称呼：桌面 Touch Bar、Touch Bar 唤醒、界面显隐
- 入口：
  - 应用启动后直接展示当前镜像或 Workspace 场景
  - 手动隐藏后轻触物理 Touch Bar 任意位置激活界面
  - 顶部状态栏菜单 →「显示 / 隐藏 ToubarReplace」控制显隐；「切换 Touch Bar / Workspace」控制场景
- 关键选择器：
  - 桌面窗口：`NSPanel`，Frame Autosave：`ToubarReplaceMirrorWindow`
  - 桌面容器：`DesktopCapsuleView`、`DesktopCapsuleController`、`DesktopCapsuleSpring`、`DesktopCapsuleLayout`
  - 桌面容器 Accessibility Identifier：`ToubarReplace.DesktopCapsule`
  - 物理唤醒层：`DesktopWakeTouchBarController`，Placement `1`，PresentationModeGlobal：`app`
  - 唤醒主区 Item Identifier：`com.toubarreplace.desktop.wake`，为唯一 `defaultItemIdentifiers`
  - 唤醒 Escape 槽 Item Identifier：`com.toubarreplace.desktop.wake.escape`，注册于 `escapeKeyReplacementItemIdentifier`
  - 唤醒视图：`DesktopWakeRegionView`、`DesktopWakeButton`，Accessibility Identifier：`ToubarReplace.TouchBar.Wake`
  - 物理隐藏键 Accessibility Identifier：`ToubarReplace.TouchBar.Collapse`，图标：`chevron.down`
- 子功能：
  - 完整隐藏：状态栏菜单或物理隐藏键控制窗口通过 `orderOut` 退出显示；保留原场景、配置尺寸与位置
  - 整条盲点唤醒：隐藏时主区、Escape 槽统一为唤醒入口，系统控制区让位于全宽唤醒层；激活后恢复原来的镜像或 Workspace 场景
  - 唤醒操作隔离：唤醒键在抬手时激活界面；动画完成且唤醒触摸结束后恢复正常物理控件，期间由唤醒层承接触摸
  - 显隐状态保持：进入与退出全屏、切换应用或 Space 时保持当前显示或隐藏状态
  - 固定位置：位置由设置控制；唤醒展开时左端坐标固定；硬件镜像采用鼠标穿透
  - 配置尺寸：内容占用完整配置宽高；Retina 2× 下默认 2300 × 70px 换算为 1150 × 35pt；隐藏期间修改尺寸后，下次激活使用新尺寸
  - 弹性与淡入：唤醒时宽度从 48pt 展开至配置宽度，spring response 为 0.36s、damping ratio 为 0.82，内容随展开进度淡入；「减少动态效果」直接显示目标尺寸
  - 统一主题：全黑与毛玻璃共享显隐、定位与唤醒逻辑；隐藏和展开动画期间保留原场景内容，正常触控恢复后重新接入捕获
- 前置条件：应用已启动；物理唤醒需要可用的 Touch Bar 与 System Modal API；毛玻璃主题在 macOS 26 及以上手动开启
- 常见故障现象：
  - 位置需要调整：在设置中选择底部、顶部、居中或自定义坐标
  - 唤醒区域暂时脱离：应用监听窗口挂载，自动重建唤醒层；睡眠时释放，唤醒后按当前显隐状态恢复
