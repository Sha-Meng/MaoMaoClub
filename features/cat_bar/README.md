# CatBar 功能目录

CatBar 是 2D 轻俯视酒吧产品场景。目录按领域拆分为场景/镜头、调酒、卡座顾客与表现适配；跨功能通信只传稳定 ID、命令和快照。

- `bartending/`：调酒领域、配置、交互策略、表现与流体适配。
- `camera/`：全景和调酒近景构图及模式切换。
- `patrons/`：卡座氛围顾客与座位租约。
- `service/`：Neko 送达、订单幂等结算和材料/研发/菜单进度。
- `assets/`：资产清单校验，不承载具体贴图。

生产 GDScript 使用静态类型和显式返回类型。共享流体模块不得反向依赖本目录。

## 运行时结构

`cat_bar.tscn` 可独立 F6 运行。`CatBarController` 只编排全景、调酒、送酒和手机模式；调酒规则由 `BartendingSessionState` 与策略注册表执行，UI 不直接改配方数据。工作台处于独立 CanvasLayer，Camera2D 只缩放世界背景，因此镜头往返不重建会话。

送达链路为 `DrinkResult → NekoDeliveryActor → CatBarSettlementService`。结算服务核对订单、会话、卡座和 delivery key 后，才发放金币、经验与材料；重复动画回调不会二次结算。普通氛围顾客完全不进入该链路。

## 扩展内容

1. 在 `bartending/configs/` 新建带稳定 `StringName` ID 的工具、原料、交互或配方 `.tres`。
2. 把内容加入 `default_content_catalog.tres`，并在 `default_station_layout.tres` 配置兼容槽位；不要在场景控制器添加内容 ID 分支。
3. 在 `assets/cat_bar/asset_manifest.json` 登记对应资产 ID、许可、帧尺寸、锚点与状态。
4. 运行内容/资产校验和 CatBar 测试。校验器会一次报告重复 ID、未知策略、缺失引用、槽位冲突和资产问题。

当前为原创灰盒/占位美术；需求附图只登记为 `reference_only`，没有运行时路径。声音、最终逐帧动画和更多配方属于后续内容迭代。
