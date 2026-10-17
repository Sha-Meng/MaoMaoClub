# 店长 Blender 动画验证

日期：2026-10-18。用户明确要求前后交叉步态，并以 `manager_crossing_stride_reference.png` 指定原型。撤销上轮把“不偏女性化”解释为“不允许双腿交叠”的错误约束。店长保持圆脸、短颈、厚腹、粗短腿，采用前后交替、经过交叠的步态，骨盆保持稳定。

## 启动与检查

在项目根目录执行：

```powershell
./tools/run_manager_lab.ps1
./tools/run_manager_lab.ps1 -Test -Capture
```

预览页同时显示约 88 px 常驻大小与 2.5 倍观察；支持自动走停、左右方向、停步、空手/持杯、暂停、半速和浅深底。自动演示约 11 秒一轮。场景不创建营业模拟、不访问正式存档。

## 已实现素材

| 动作 | 帧数 | 时长 | 根位移 |
| --- | ---: | ---: | ---: |
| 站立 | 30 | 1 秒循环 | 0 |
| 起步 | 21（含终点） | 2/3 秒 | 7.4 px |
| 行走 | 30（不重复终点） | 1 秒循环 | 22 px |
| 停步 | 27（含终点） | 13/15 秒 | 9.6 px |

空手与持杯各一套，共 8 片段、216 帧。方向通过整帧镜像，播放顺序不倒转。帧画布 176×192，是逻辑尺寸的 2 倍，根锚点固定为 (88,184)。

- 原稿与提示词：`assets/source/manager_blender/`。
- 可编辑源工程：`assets/source/manager_blender/manager_rig.blend`。
- Blender 自动制作：`tools/manager_blender/build_manager.py`。
- 原生骨骼复验：`tools/manager_blender/audit_rig.py`。
- 图集、时序和位移：`assets/tavern/manager_authored/`。
- Godot 控制器与验证页：`features/animation_lab/`。
- 最终渲染、报告与预览：`production/qa/manager_blender/`。

## 制作实现

源工程使用九个网格部件、原生 Armature 权重与动作关键帧，正交相机保持二维画风。最终原稿是 `crossing_parts_final.png`：宽腹躯干与近远腿独立绑定。近腿根部进入腹部内部，使用 `attachment_fade` 顶点属性在根部渐隐；完整脚掌保持不透明。近腿、躯干、远腿的深度固定，不随脚的横向位置交换。这样交叉动作不会将腹部平面拉扯或反折。

此前“腹部和两条腿必须共用连续平面”的实现约束已撤销；它不能同时满足明显的腿部交叠。外观上的融合通过足够的根部重叠、同源毛色、渐隐连接及遮挡实现。身体和腿等比缩放；膝踝采用宽范围平滑权重，保持粗短肢体的体积。

脚目标关键姿势在构建脚本中明确列出，离线求解后记录为 Blender 骨骼关键帧。一周期步幅 22 px、抬脚最高 3.5 px、身体起伏 0.4 px，骨盆没有旋转轨道。每周期有两次前后经过，远脚减近脚的横向差覆盖 -7 至 +15 px；不再限制最小横向脚距。空手臂摆幅 10°、持杯臂摆幅 0.5°。杯子通过子骨骼随持杯手运动。

骨骼绑定姿态对齐原稿已经弯曲的膝盖，膝点向前 3.5 px，并从求解角度中扣除绑定角度。避免将直腿骨架再次弯曲到弯腿原画上，造成膝盖过度折叠和蹲行。静止脚距为 10 px，行走允许脚的横向顺序交替。

前两版素材、工程、构建脚本和预览保留在 `assets/source/manager_blender/rejected_v1/` 和 `rejected_v2/`。用户原型归档在 `assets/source/references/2026_10_17_desktop_tavern/manager_crossing_stride_reference.png`；新底稿完整生成提示词与来源见 `crossing_generation_prompt.md`。新图由内置 imagegen 编辑生成，Python 仅做骨骼制作、资源打包、指标检查及证据编排。

源文件默认显示 `walk_cup`，其他七段在 Actions 中；每段都包含 `held` 属性关键帧，自动切换空手臂、持杯臂和杯子的可见性。贴图已打包进 `.blend`，无需外部插件。

这套验证没有制作肘部独立弯曲、手指握放、表情切换、饮酒或坐姿。继续开发前需先确认这次的体型、步态和摆臂表现。

游戏运行时只读图集和 JSON，以导出的根位移曲线同步 X；没有 Blender 依赖。转向、停止和换杯请求在安全段落衔接：先完成当前行走周期，再停步，随后转向/换杯；起步中取消则直接衔接停步。此策略适合样片，步行状态下最坏停止等待约 1.87 秒；正式营业接入前应制作半步停步与更短响应方案。

## 制作工具与复现

离线工具：Blender **4.5.9 LTS**，构建 `8bf95cbd38d1`。便携版下载自 Blender 官方，SHA256 已与官方校验表一致：

`41da973b9bf95bb312cbeff4d1982feb13259b43c821686b9bafea4dfe5477cf`

本机二进制：`D:/MaomaoClub/tools/blender-4.5.9/blender-4.5.9-windows-x64/blender.exe`。不改变 Godot 4.6.3 固定版本。

```powershell
$blenderBin = 'D:/MaomaoClub/tools/blender-4.5.9/blender-4.5.9-windows-x64/blender.exe'
$pythonBin = 'C:/Users/shame/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
& $blenderBin --background --python-exit-code 1 --python tools/manager_blender/build_manager.py
& $blenderBin --background assets/source/manager_blender/manager_rig.blend --python-exit-code 1 --python tools/manager_blender/audit_rig.py
& $pythonBin tools/manager_blender/pack_frames.py
& $pythonBin tools/manager_blender/check_rendered_frames.py
& $pythonBin tools/manager_blender/make_anatomy_review.py
./tools/run_manager_lab.ps1 -Test -Capture
& $pythonBin tools/manager_blender/encode_review.py
```

Python 打包与验证依赖 Pillow、NumPy，本机已具备；不参与角色原画生成。原稿由内置 imagegen 生成，提示词已归档。Blender 为免软件授权费工具，素材生成使用现有服务额度。

## 占用与验收边界

图集 1408×5184，按 RGBA8 且无 mipmap 计算的像素容量约 27.84 MiB。PNG 大小以 `asset_report.json` 为准。实际预览总纹理约 46.27 MiB，包含字体与界面，不能当作角色独占显存。全员推广前需要去重静态帧、缩小帧画布并按动作加载。

技术检查包括实际 Blender 骨骼、可见网格反折、渲染像素和 Godot 控制器，不把数值通过等同于动作好看。视觉自查必须查看完整 30 帧行走下身、起停关键姿势、常驻与放大连续播放；不能再将明显的腿身分离作为“等用户确认”的交付。详细观察记录见 `production/qa/manager_blender/acceptance.md`。
