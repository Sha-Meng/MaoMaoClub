# 桌面酒馆：确认设定与实现索引

确认与实现日期：2026-10-17。用户指令为“将以上设定都归档；并按照现在这版设定完整实现”。此前的暂用名、岗位与三位扩展顾客在本轮一并采纳。概念来源保留历史版本，不能混用旧同体型稿替代当前角色。

## 当前视觉来源

| 设定 | 当前来源 | 运行资源 / 实现 |
| --- | --- | --- |
| 常驻整体比例 | `design/art/desktop_tavern_v2/desktop_idle_selected_v2.png` | 960×280 逻辑画布、约 146 高店铺；随屏幕缩放；80%/100%/120% 设置 |
| 店长身份与自然比例 | `manager_proportions_v2.png` 与 `tavern_cast_v2/tavern_team_personalities_v1.png` | 奶油猫、金链、背心、圆腹、卷尾、酒杯；游走、聊天和点击回应 |
| 六位差异化顾客 | `design/art/tavern_cast_v2/customer_personalities_v2.png` | `assets/tavern/customers_first.png`、`customers_extra.png`，六位轮换来店 |
| 团队分工 | `design/art/tavern_cast_v2/tavern_team_personalities_v1.png` | `assets/tavern/cat_team.png`，店长、调酒员、服务员分工 |
| 人物性格与边界 | `tavern_personality_v1.md` | `features/tavern/cast_catalog.gd` 与 `tavern_simulation.gd` |
| 横向单基线摆放 | `design/art/desktop_tavern_v2/horizontal_interaction_rules.md` | X 轴阈值拖动、Y 固定、无纵深；调酒员不可单独拖动；家具增删、已入座椅子带人、动态挂点与存档 |

## 九位人物

| 人物 | 性格表现 |
| --- | --- |
| 阿栗 · 汗衫松鼠 | 矮瘦轻快、亮眼笑，讲故事和招手，等待对方回应 |
| 阿领 · 领带狗 | 瘦高内收、认真拘谨，先听后说、松领带、下班后逐渐放松；包随移动/坐姿显示 |
| 慢慢 · 格衫水豚 | 宽胖稳重、半垂眼，慢转头、点头、安静回应 |
| 绯绯 · 围巾狐狸 | 高挑、挑眉偏笑，小幅摊手逗趣，观察对方反应 |
| 小绘 · 画手兔子 | 窄肩长耳、圆眼好奇，先观察画画，再展示画本 |
| 夜豆 · 连帽浣熊 | 矮壮困倦，抬眼、放低手机、接一句冷幽默 |
| 店长 | 圆润松弛，招呼、倾听、举杯、整理金链；尊重不参与社交 |
| 调酒员 | 瘦高专注，调制、倒酒、对齐出杯、拿瓶、擦杯、擦吧台；工作优先于闲聊 |
| 服务员 | 紧凑活泼，确认目标、持盘行走、慢下来轻放酒杯、收杯、擦桌和整理围裙 |

## 动画与业务的对应

- 顾客：站立、走路、入座、坐姿、点单、接杯、饮用、说话/倾听、付款道谢、起身、离场、拖动/落地，以及各人的个性动作。
- 调酒员：工作待机、摇杯、倒酒、出杯和空闲整理/简短社交；固定在吧台，不再开放独立拖动或离岗行走。完整步态保留为角色表现资源。
- 服务员：待机、空手行走、取托盘、持盘行走、递杯、收杯、清洁、拖动/落地和简短回应。
- 店长：待机、自由游走、说话、倾听、招呼、举杯/点击、轻笑、整理配件与拖动/落地。
- 每人 6 个透明基础姿势，共 54 个；通过姿势切换、注册到脚底的轮廓网格、程序位移/倾斜/回弹和独立杯、壶、托盘等道具表现动作。这些状态不是 54 套独立逐帧动画。
- 走路来源：`assets/tavern/walk_complete/` 十张完整人物图集保留归档。当前只使用其第 8 号完整站姿，注册输出 `assets/tavern/grounded/`，由 `TavernGroundedGait` 连续驱动。旧 45 分件及独立腿段缩放停止用于运行，历史源码文本保留。
- 单张完整纹理保持肩、肘、手和持物接触；髋膝踝关节保持骨长，脚掌刚性旋转，摆动时屈膝和回收，躯干承重起伏，空手反向摆动。坐下/起身仍固定座面与脚部，保持现有小幅上半身收稳。
- 腿脚层级依原稿标定：先画远腿，再画近腿；当前十种图稿源图左腿为近腿，朝向镜像和步态推进均不交换层级。交错遮挡验证见 `production/qa/leg_occlusion/acceptance.md`。
- 店长与持盘服务员的手持物随完整人物同帧绘制；顾客 36 个手杯一体饮用阶段继续由 `TavernDrinkArt` 播放。来源分别见 `complete_walk_generation.md` 和 `drinking_generation.md`，均位于 `assets/source/runtime_tavern/`。
- 当前播放修订：停用八原画硬切、32 帧光流混合和脚底平移牵动整腿。支撑占 60%、摆动占 40%，双脚首次摆动时对齐行走轴，停止不重置；站走同稿，近远关系固定。步幅按腿长限制，实际移动速度同步减小，常规约 0.86–0.95 双步周期/秒。具体标定见 `design/animation/articulated_walk_pipeline.md`。
- 最新回归和视觉证据见 `production/qa/articulated_walk/acceptance.md`；四种关键姿态与关节图、十种人物 30 FPS 原色行走/停步/反向帧均可复看。新增骨长、屈膝、承重、摆臂和对称行走轴检查；旧锁地与遮挡检查通过不能单独证明动作自然。
- 大头近景表情板、八方向全套、熟客长期关系、醉酒规则、员工代班等原稿中依赖未来玩法的 P2 不在本次承诺内；已有研发/材料规格继续独立跟踪，不被本轮人物设定暗中扩张。

## 归档与检查

- 经营规则、稳定订单编号、座位、社交占用、输入和存档由数据模拟维护；表现不直接记账。
- 概念图与运行图集的生成提示词分别保存在 `design/art/tavern_cast_v2/generation_prompts.md` 和 `assets/source/runtime_tavern/generation_prompts.md`，均使用内置 image_gen。
- 正式行为规格位于 `openspec/specs/personality-tavern/`、`tavern-character-presentation/`、`taskbar-tavern-presentation/` 与 `desktop-window/`。
- 复现与验收记录见 `production/qa/personality_tavern/acceptance.md`。测试命令为 `./tools/run_tests.ps1`，启动命令为 `./tools/run_desktop.ps1`。
- 本轮实玩反馈修复及最新规则、证据见 `design/art/desktop_tavern_v2/horizontal_interaction_rules.md`、`production/qa/horizontal_walk_fixes/acceptance.md`，优先于历史二维摆放文字。
