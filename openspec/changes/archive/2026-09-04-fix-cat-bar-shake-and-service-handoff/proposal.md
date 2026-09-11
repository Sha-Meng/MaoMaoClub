## Why

当前 CatBar 调酒近景缺少玩家可见的退出入口，Shake 虽复用了实验场的业务适配器，却没有把真实粒子位置呈现到产品杯体中，造成“无法返回大厅”和“液体看起来不动”的直接体验问题。成品送达目前也由调酒师 Neko 一人完成，不符合调酒师放杯、打工猫接力送往卡座的新服务演出要求，现有程序化猫形象还缺少统一的像素画风。

## What Changes

- 为调酒台增加明确的“返回大厅”按钮与 `Esc` 返回路径；退出时安全取消未提交会话、释放拖拽捕获并清空临时流体表现，再次进入可开始干净的新会话。
- 让 CatBar Shake 杯消费与粒子流体实验一致的只读粒子/冰块局部快照，实时绘制液体粒子运动、杯体位移和回稳过程，同时保持业务剂量与视觉粒子解耦。
- 把送酒演出拆成“调酒师把成品放到吧台交接点”和“打工猫从交接点取杯并送到目标卡座”两个可观察、顺序确定的阶段；只有打工猫完成放杯后才结算订单。
- 生成并接入一套原创、统一暖暗像素风的猫角色图集，覆盖调酒师、打工猫和代表性卡座顾客，并在资产清单中登记生成方式与审阅状态。
- 为退出、流体位置变化、两段式交接顺序和统一角色纹理绑定补充自动化回归测试及场景截图验证。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `cat-bar-bartending`: 增加产品调酒台对真实流体粒子运动快照的呈现要求，以及安全退出/重入调酒会话的行为。
- `cat-bar-scene`: 把单一 Neko 送酒改为调酒师与打工猫两段式交接，并规定 CatBar 猫角色采用统一像素视觉体系。
- `cat-bar-content-architecture`: 增加统一猫角色图集的导入、配置、资产清单和可替换契约。

## Impact

- 代码与场景：`features/cat_bar/bartending/`、`features/cat_bar/service/`、`features/cat_bar/patrons/`、`features/cat_bar/cat_bar_controller.gd`、`features/cat_bar/cat_bar.tscn`。
- 共享实验接口：`features/cocktail_shaker_lab/cocktail_shaker_lab.gd` 只新增只读局部快照查询，不把 CatBar 业务反向写入流体模块。
- 素材与配置：`assets/cat_bar/characters/`、CatBar 资产清单、顾客原型配置和场景角色纹理绑定。
- 测试：CatBar 集成测试、流体适配测试、资产校验、性能/稳定性门禁和截图验收。
