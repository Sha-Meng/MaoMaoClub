# 半透明桌面窗口验收

日期：2026-10-17（Asia/Shanghai）

变更：`enable-transparent-desktop-window`

> 后续更新：同日 `enforce-desktop-always-on-top` 已将可切换置顶改为固定常驻；本记录中的置顶开关是当时版本的验收快照。当前行为以 `openspec/specs/desktop-window/spec.md` 和 `production/qa/desktop-always-on-top-2026-10-17.md` 为准。

结论：本机 Windows 桌面形态验收通过。使用 Godot `4.6.3.stable.official.7d41c59c4`，NVIDIA GeForce RTX 3060，Compatibility / OpenGL 3.3。此结论不代表旧挂机 MVP 的其他交互问题已全部验收。

## 自动检查

- 在临时副本与隔离 APPDATA / XDG 目录中执行，避免验证数据覆盖真实经营存档。
- 全部 16 个脚本完成全局类注册，编辑器导入和运行退出码均为 0。
- 最终代码运行 `--headless --fixed-fps 60 --quit-after 36000`，模拟 600 秒，服务计数由 92 增至 185，金币由 792 增至 1588；无脚本错误。
- 在真实 Windows DisplayServer 中执行临时检查脚本，确认根窗口无边框、透明、默认置顶；置顶开关改变原生标志，最小化改变原生窗口模式。
- 渲染纹理取样：空白点 `(900, 100)` alpha 为 `0.0`，地台点 `(30, 320)` alpha 为 `0.380392163991928`。
- 旧版零坐标存档迁移至 `(1576, 1008)`；窗口尺寸 `960×360`。超远坐标和部分越界坐标均恢复至完整可见区域。
- 最小化时保存仍保留最小化前的位置。
- 保存后重读金币、经营值、窗口位置及布局版本全部相符；窗口布局版本为 1，旧存档经济字段不重置。

## 真实界面操作

- 确认旧运行模式实际为编辑器嵌入，日志出现“Embedded window can't be resized / moved”。
- 在该项目 Godot 编辑器中关闭“下次运行时嵌入游戏”，F5 可以打开独立透明窗口。
- 独立窗口没有系统标题栏、编辑器游戏工具栏或整页底色；可以看到下方编辑器与其他应用。三只猫猫、吧台、顾客、收益计数仍可见。
- 置顶按钮可切换视觉选中状态；原生标志由自动检查交叉验证。
- 最终拖动检查：窗口由 `(1475, 999)` 移至 `(1275, 999)`，保存文件同步更新。
- 最小化后恢复仍位于 `(1275, 999)`，挂机收益继续积累。
- 点击“×”后窗口退出；重新使用 `tools/run_desktop.ps1` 启动，经营值及原位置保留。
- 独立启动脚本已实际执行，能完成导入并打开桌面版。
- `git diff --check` 通过。

## 实现说明与边界

- 拖动按鼠标按下位置与全局鼠标位置计算位移，同时处理鼠标移动事件，覆盖按下、移动、释放在同一帧入队的情况。
- 最小化之前即时记录正常窗口位置，避免把 Windows 的最小化坐标写回存档。
- 不提供全窗口点击穿透；不隐藏任务栏入口，最小化后可恢复。
- 原挂机 MVP 中“拖拽正在服务的猫猫”的状态一致性问题不属于本次窗口变更，原验收待办继续保留。
- 多屏位置逻辑已处理可用区域，但没有实测显示器拔插、混合 DPI、其他显卡驱动或独占全屏覆盖。

## 参考

- [Godot 4.6 桌面覆盖层配置](https://docs.godotengine.org/en/4.6/tutorials/ui/creating_applications.html#displaying-the-application-as-an-overlay)
- [Godot 4.6 Window 类](https://docs.godotengine.org/en/4.6/classes/class_window.html)
