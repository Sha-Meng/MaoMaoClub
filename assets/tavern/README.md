# 桌面酒馆运行素材

这些资源用于实际游戏；概念板另存于 `design/art/`。全部由内置 image_gen 根据本项目确认的角色与店铺参考生成，完整提示词在 `assets/source/runtime_tavern/generation_prompts.md`。

| 文件 | 布局 / 角色 | SHA-256 |
| --- | --- | --- |
| `customers_first.png` | 1774×887，6 列 3 行；松鼠、狗、水豚 | `206961A03A4D638A32BB4DB596CFCB88138C87B7C7398FAAE1D1AC67FEA3DB95` |
| `customers_extra.png` | 1774×887，6 列 3 行；狐狸、兔子、浣熊 | `EB2E46E3102365D41A5645E8730B21D5247B80BF6376D2CE07177F259D1D6A8E` |
| `cat_team.png` | 1774×887，6 列 3 行；店长、调酒员、服务员 | `21E4B6D049E5C68812CCB5CA04D33498D1D7847329495D4B07FEE352D7A69179` |
| `shop.png` | 透明独立店铺，暖灯、木吧台、绿白篷布 | `31A3EF138F852CFF5085F0D42BEBAD6FC9C3E455A32AE645E307A7C836ABF2FA` |
| `walk_parts_first.png` | 1536×1024，3 行；松鼠、狗、水豚各含躯干、双臂、双腿 | `314E3FB80ACA8B6FD02B0516C30AC523D5EBF92D16A850398F34C9482C55C70E` |
| `walk_parts_extra.png` | 1536×1024，3 行；狐狸、兔子、浣熊各含五个分件 | `08A9399053FC7D96F20DAFC48DC81349A81183C396B7388DE45038301ACE7C91` |
| `walk_parts_team.png` | 1536×1024，3 行；店长、调酒员、服务员各含五个分件 | `A6A73E8196D8FB5A9F38D136BC1FCCD3141A7C9713C1C5BED0731C8B93380AC5` |

顾客六列为站立、走路两姿势、坐姿、饮用姿势、交谈。团队按岗位映射待机、走路、说话/倾听或制饮/服务姿势。

旧两张走姿保留为原始素材，不再用于运行时步行循环。当前步行由 `TavernWalkRig` 的分件和连续关节运动驱动，列边界为 0/29%/46%/64%/82%/100%；独立注册腰部、肩部与髋部，支撑脚按实际行进位移保持落地，摆动脚抬起、膝部前屈，双臂反向摆动。尾巴不参与腰部锚点计算；端盘手保持稳定。新图存在透明像素下的棕色 RGB，实际 alpha 为 0；必须保留 alpha，不能扁平化后导入。

本轮分件原图、最终图和提示词记录见 `assets/source/runtime_tavern/walk_rig_generation.md`；80 个步态相位及 32 张连续帧 GPU 验证见 `production/qa/horizontal_walk_fixes/`。

肩部绑定修正：`TavernWalkRig.SHOULDER_SOCKETS` 按各图集角色实际肩膀位置注册；上臂以裁切高度 12% 处的内部关节旋转，不能绕裁切框顶部旋转。肩盖使用原躯干纹理覆盖切口；远臂与胸部/尾巴分别遮挡。手部挂点由手掌轮廓提取。连接专项的全周期几何重叠及实际 alpha 连通渲染见 `production/qa/actor_binding_fixes/`，不以“分件非空”代替连接验收。

生成图的格子边界不是像素严格齐整的图集规范，因此 `TavernArt` 按实际行分界与透明主轮廓取样，排除邻格残片，并以脚底注册。道具与反应由表现层单独绘制，不能使用不带适配的平均裁切替代当前映射。54 个基础姿势的实际 GPU 渲染对照见 `production/qa/personality_tavern/rendered_poses.png`。
