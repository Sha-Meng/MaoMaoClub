# MaoMaoClub · 猫猫桌面酒馆

Windows 无边框透明挂机经营游戏，固定使用 Godot **4.6.3 stable**，精确构建 `4.6.3.stable.official.7d41c59c4`。

## 启动

在项目根目录执行：

```powershell
./tools/run_desktop.ps1
```

脚本使用本机固定 Godot，导入资源后打开独立桌面窗口。默认沿任务栏可用上沿展开，以用户选定的 V2 效果比例显示。上方没有整页背景；透明空白外侧允许下方应用接收鼠标。

在 Godot 编辑器中试玩时，关闭 **Embed Game on Next Play**，再按 F5；编辑器浮动容器不能代替真正独立桌面窗口验收。

店长的新动画独立验证入口：`./tools/run_manager_lab.ps1`。提供常驻/放大对照、左右走停、空手/持杯、半速和浅深底；源工程、导出流程与限制见 `design/animation/manager_blender_pilot.md`。这是 Blender 免费制作路线的单角色样片，视觉待用户确认，正式营业尚未切换。

## 已实现内容

- 六位顾客轮换：汗衫松鼠阿栗、领带狗阿领、格衫水豚慢慢、围巾狐狸绯绯、画手兔子小绘、连帽浣熊夜豆；各有体型、表情、节奏和个性动作。
- 三猫分工：店长自由游走与闲聊，调酒员调制出杯，服务员送杯、收杯、擦桌。
- 自动营业：入店、等位/入座、点单、制饮、取杯、递送、饮用、付款、离场、清理。最多同时四位顾客，每单只结算一次。
- 有边界的社交：接受或暂不参与、交替说话/倾听、结束与冷却；工作和拖动优先。
- 店铺、桌椅、店长、服务员和顾客可沿同一地面线横向拖动，无 Y 轴或纵深；调酒员固定在吧台并随店铺整体移动。家具可增删和重置，挂点随布局更新。
- 布局、显示比例、人物和订单检查点保存，兼容旧经济进度，原子替换并保留有效备份；正式实例独占运行。
- 54 个基础姿势与 36 个手杯一体饮用阶段；十张完整人物图集保留来源。当前走路采用完整站姿的关节网格驱动，用户已反馈关节不自然，视觉未验收。正式动画制作方案见 `design/animation/authored_animation_research.md`。持杯/盘动作不额外叠画第二套道具。

## 操作

- **单击人物**：人物回应，人物页会选中该角色；超过 5 逻辑像素才开始拖动。
- **拖动人物/店铺/家具**：只改变横向 X，始终保持同一地面线；调酒员不能单独拖动，松手不误触单击。
- **⋯ 或单击店铺**：打开经营摘要、人物资料和摆放面板。
- **摆放模式**：优先命中座椅和桌面，便于移动有人坐着的椅子；支持加座椅、加小桌、移除所选家具、恢复布局。
- **拖动座位**：只有实际已入座的顾客跟随；拖动中的空座不接收新顾客，尚未走到座位的预占顾客会重新找座。
- **↔**：按住移动整个酒馆窗口。
- **80% / 100% / 120%**：调整显示大小，保持内部比例。
- **Esc**：收起面板，结束当前摆放操作。
- **最小化 / 保存退出**：主动隐藏或退出；保存失败会保留窗口并显示错误。

窗口固定常驻于普通应用之上，不提供关闭置顶的开关。鼠标穿透依据可见物件与面板的包络，包络内部物件之间的空白也可能接收输入，并非逐像素命中。

## 测试

```powershell
./tools/run_tests.ps1
./tools/run_tests.ps1 -Render
```

默认运行导入检查、单元、场景集成、正式入口、30 分钟确定性营业和持续随机编辑测试。`-Render` 增加关节关键姿态、脚底接触、头部形状稳定、近远遮挡、饮用、坐姿回归，以及十种人物按实际业务速度、30 FPS 行走/停步/反向的 1320 张渲染帧。失败返回非零，不使用玩家存档；最新证据见 `production/qa/articulated_walk/acceptance.md`。使用 `python tools/encode_grounded_walk_review.py production/qa/articulated_walk` 编码真实时间 GIF，需要 Pillow。

当前步态使用 `assets/tavern/grounded/` 的同一完整站姿，髋膝踝定长关节驱动屈膝、转踝、承重起伏和手脚对摆；支撑占 60%，周期按实际移动距离推进，常规约 0.86–0.95 双步周期/秒。行走落脚轴对称，近远腿顺序固定，站走不换稿、不混图。原坐姿、饮用与手杯接触保留。实现见 `design/animation/articulated_walk_pipeline.md`；自动测试结果不代表步态视觉验收已通过。

- 详细验收范围、结果和未覆盖实机情境：`production/qa/personality_tavern/acceptance.md`。
- 最新肩部连接、坐下无下滑修复及专项渲染：`production/qa/actor_binding_fixes/acceptance.md`。
- 当前设定及实现索引：`design/characters/implementation_manifest.md`。
- 原始概念与最新性格图：`design/art/`。
- 运行图集与来源：`assets/tavern/`、`assets/source/runtime_tavern/`。

## 工程约定

- 主入口 `app/main.tscn`，营业协调器 `features/tavern_loop/`，数据模拟、人物、布局与表现位于 `features/tavern/`。
- 项目约束见 `AGENTS.md`；Godot 技能入口为 `.agents/skills/maomao-godot/SKILL.md`。
- 非平凡改动先遵循 `docs/open-spec-workflow.md`，已实现行为在 `openspec/specs/`，历史变更在 `openspec/changes/archive/`。
- 正式存档为 `user://maomao_club_save.cfg`，有效备份为同名 `.bak`；测试使用独立文件。
- 尚未设计的研发酒单、材料经济、联网 UGC、醉酒或长期关系不在本轮人物与桌面交互范围。
