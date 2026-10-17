# 店长 Blender 单角色验证记录

日期：2026-10-18。范围：分层源稿 → Blender 骨骼与关键帧 → 透明图集 → Godot 4.6.3 独立预览。

用户要求正常前后交叉步态，并提供 `manager_crossing_stride_reference.png` 指定原型。已撤销上版把“不偏女性化”解释为“不允许双腿交叠”的错误约束。前两版原稿、工程与预览保存在 `assets/source/manager_blender/rejected_v1/`、`rejected_v2/`，旧验收说明也已保留。

## 当前交付

- 用户参考：`assets/source/references/2026_10_17_desktop_tavern/manager_crossing_stride_reference.png`。
- 最终分层底稿：`assets/source/manager_blender/crossing_parts_final.png`；内置 imagegen 的完整提示词和来源：同目录 `crossing_generation_prompt.md`。
- 可编辑骨骼工程：`assets/source/manager_blender/manager_rig.blend`，包含打包贴图、权重和 8 个动作。
- 运行资源：`assets/tavern/manager_authored/`，共 216 帧，包含空手/持杯各自的站立、起步、行走、停步。
- 独立启动：`tools/run_manager_lab.ps1`；支持约 88 px 常驻大小、2.5 倍观察、方向、持杯、暂停、半速和深浅底。
- 本目录 `manager_crossing_demo.gif`：Godot 实际渲染的 330 帧、11 秒预览，使用 30/30/40 ms 时长组保持总播放时长。
- 本目录 `key_poses.png`、`lower_body_all_frames.png`、`lower_body_cup_all_frames.png`、`start_anatomy.png`、`stop_anatomy.png`、`preview.png` 和 `dark_preview.png`：姿势与实际渲染证据。

## 技术检查

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| Godot 控制器和界面 | 765 断言，0 失败；覆盖不同帧率、起步取消、转向、停步、换杯及控件 | `unit_report.json` |
| 原有营业与存档回归 | 54 用例、7314 断言，0 失败 | `regression_report.json` |
| 保存后 Blender 骨骼 | 216 帧重新求值；足端最大误差约 0.00000816，支撑脚最大漂移约 0.00000216 逻辑单位 | `rig_report.json` |
| 前后交替 | 空手/持杯均每周期两次交叉；远脚减近脚横向差约 -7 至 +15 px；近远层固定 | `rig_report.json` |
| 网格与道具 | 可见面片反折为 0；骨盆旋转为 0；杯子相对持杯骨矩阵误差小于 0.000008 | `rig_report.json` |
| PNG 连接和接缝 | 216 帧没有独立 alpha 岛；站立→起步、起步→行走、停步→站立的连接帧平均像素差为 0 | `pixel_report.json` |
| 图集 | 216 帧非空、无边缘裁切；1408×5184，PNG 5,105,798 字节 | `asset_report.json` |
| Godot 渲染 | Godot 4.6.3 / Compatibility / RTX 3060；330 帧；平均等待渲染约 1.75 ms、最大约 16.28 ms | `render_report.json` |

渲染计时包含等待渲染信号，不是隔离 GPU 基准。图集按 RGBA8 无 mipmap 计算约 27.84 MiB；预览总纹理约 46.27 MiB，包含字体与界面。

## 视觉自查与实现修正

- 以新参考重新制作圆脸、短颈、厚腹与粗短腿分层稿。宽腹与两条腿独立绑定，近腿根藏入腹部并渐隐，固定近腿在前、远腿在后。
- 撤销“双腿与腹部必须共用同一平面”的约束，避免交叉时拉扯腹部或强行交换图层。
- 绑定骨骼对齐原画已弯曲的膝盖，求解时扣除绑定角度，修正重复屈膝导致的蹲行。
- 检查了空手/持杯各 30 帧下身及起停关键帧。近腿经过腹前，远腿从后方经过；脚掌保持体积，未见前版的悬挂腿帽和独立小腿。近侧大腿在腹前仍有可见轮廓线，其美术接受程度交由用户评价。
- 在实际 Godot 窗口查看常驻大小和放大视图，并实际操作左右行走、半速及深浅底；持杯状态和转向均有渲染证据。
- 不用逐帧重新生成或帧间溶解。行走一周期位移 22 px、抬脚最高 3.5 px、身体起伏 0.4 px；起步位移 7.4 px、停步位移 9.6 px。杯子随持杯臂子骨骼运动。

技术检查通过不等于用户已经接受视觉表现。本次是店长独立样片，正式营业仍使用原人物表现；全员迁移、坐下、饮酒、表情及握放动作由 `openspec/changes/adopt-authored-character-animation/` 继续跟踪。

当前停步会等待完整行走周期后收步，步行状态最坏响应约 1.87 秒。正式接入前需增加半步停步，并验证原有行为与坐姿衔接。

用户随后要求先上传 Git 远端。本记录随当前进度快照保存，不据此宣布全员动画迁移完成。
