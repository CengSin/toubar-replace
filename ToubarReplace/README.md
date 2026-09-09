<p align="center">
  <img src="Resources/AppIcon.iconset/icon_256x256@2x.png" width="128" alt="ToubarReplace">
</p>

# ToubarReplace

在桌面上镜像真实硬件 Touch Bar，并可选在物理 Touch Bar 上打开 Workspace，查看订阅额度推荐并一触打开常用 App。

> **完整镜像（物理 Touch Bar）**：带 Touch Bar 的 Intel Mac（macOS 14 及以上）。  
> **Apple Silicon / 无物理 Touch Bar**：可原生运行（universal 包）；启动后默认进入 **软件 Workspace**（额度推荐 / 自定义 App 在桌面条上操作），无系统 Control Strip 真镜像。

---

## 安装

### 从安装包安装（推荐）

1. 打开发布包中的 **DMG**，或运行 **PKG** 安装程序。
2. 将 `ToubarReplace.app` 拖入「应用程序」文件夹（PKG 会自动安装到该位置）。
3. 首次打开：若系统提示来自未识别的开发者，可在「系统设置 → 隐私与安全性」中允许打开，或右键图标选择「打开」。
4. 启动后，菜单栏会出现 ToubarReplace 图标（本应用为菜单栏应用，Dock 中默认不常驻）。

菜单栏 → **帮助…** 可查看镜像异常时的恢复与排错说明。

### 从源码构建（可选）

```sh
swift build
./.build/debug/ToubarReplace
```

打包为 `.app` / DMG / PKG（尽量打 **arm64 + x86_64** universal；单侧交叉编译失败时回退本机架构）：

```sh
TOUBAR_VERSION=1.2.3 Packaging/build-app.sh
```

产物在 `dist/` 目录。可用 `lipo -info dist/ToubarReplace.app/Contents/MacOS/ToubarReplace` 查看架构切片。

---

## 功能概览

### 桌面镜像窗口

- 实时显示物理 Touch Bar 的画面（默认约 30 帧/秒，可在设置中调整）。
- 默认定在屏幕底部，可在设置中改为顶部、中央、上次关闭位置或自定义坐标。
- **点击穿透**：镜像窗为纯展示，鼠标点击会落到背后的应用；位置请用设置中的展示位置 / 自定义坐标调整，不能拖动窗口。
- 窗口出现在所有桌面空间。
- 有新画面时 100% 不透明；**仅当镜像浮窗遮挡住其他 app 内容时**，无更新达到设置的延迟后自动降至 30%（默认 5 秒，可设置 1–300 秒）；浮在空桌面/无内容区域上时保持 100%（镜像与 Workspace 模式共用同一套逻辑）。
- **注意**：镜像窗口只负责显示，不把鼠标点击映射到物理 Touch Bar；触控操作请在物理栏上完成。

### Workspace（工作区）

默认启动后进入 Workspace；设置里可将「启动后进入」改回镜像。通过切换按钮或 Workspace 左侧返回可进入镜像，再次点击回到 Workspace（有物理栏时呈现在 Touch Bar 上；无物理栏时呈现在桌面镜像窗内并可直接点击）：

- **切换方式**：有物理 Touch Bar 时，可在设置中选择物理栏网格按钮或可拖动的独立浮窗；二者只显示一个。无物理 Touch Bar 时，镜像场景使用独立浮窗，Workspace 用条子左侧返回。短按浮窗切换，长按或拖动只调整浮窗位置。物理 Workspace 最左侧是独立的返回 item（不画在额度板里）。
- **额度区**：OpenUsage 里每一个带用量的订阅都会出现在用量区（不限前三个）。每种订阅用三根竖柱展示短时剩余、周/长周期剩余、距下次重置；柱高表示剩余比例；没有该窗口则显示淡空柱。浪费风险最高的订阅描边，对应那根额度柱为琥珀色。订阅较多时用量区可左右滑动查看。点某一订阅打开对应应用（已固定的自定义 App，或能解析到的 `.app` / 网页）。完整数字在 tooltip。用量读本机 [OpenUsage](https://github.com/robinebers/openusage)（菜单栏 App 的 `127.0.0.1:6736` 或自带 `openusage` 命令）。未安装或暂无快照时显示「暂无额度」。
- **应用区**：最多固定 5 个常用 `.app`。空态点「自定义app」、有应用时点右侧齿轮，均打开**设置**进行新增 / 替换 / 移除；点图标仅打开该应用（满员拒绝静默挤出）。

### 设置与菜单

菜单栏图标可打开：

- **设置…**：窗口四边和四角均可用鼠标调整大小，调整后的尺寸会保存；可配置启动后进入 Workspace 或镜像、展示位置、镜像宽高、帧率、透明延迟、切换按钮位置、用量区要展示的订阅、Workspace 自定义 App 管理等。
- **帮助…**：使用说明与镜像异常时的恢复建议
- **退出 ToubarReplace**

打开设置时应用会暂时变为普通前台应用，关闭设置后回到菜单栏模式。

---

## 使用提示

1. **镜像异常 / 画面全黑或空白**  
   打开菜单栏 **帮助…** 查看说明。也可在终端依次执行：

   ```sh
   defaults delete com.apple.controlstrip FullCustomized
   defaults delete com.apple.controlstrip MiniCustomized
   killall ControlStrip
   ```

2. **锁屏或睡眠**  
   应用会暂停捕获；解锁或唤醒后自动恢复。

3. **「App 控制」或「快速操作」下暂时没有可显示内容**  
   镜像会保留最后一帧并给出提示；切换到支持触控栏的 App 或启用快速操作后会自动恢复。
