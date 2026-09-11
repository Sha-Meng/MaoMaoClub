## ADDED Requirements

### Requirement: 按功能组织 CatBar 文件

CatBar 运行时代码、场景、配置和测试 MUST 按功能边界组织，MUST 使用 `snake_case` 文件与目录、`PascalCase` 节点和 typed GDScript 显式返回类型；共享底层模块 MUST 不反向依赖 CatBar 业务。

#### Scenario: 检查目录边界

- **WHEN** 开发者检查 CatBar、调酒、卡座、手机微信、资产和测试文件
- **THEN** 文件位于各自约定的 feature/asset/test 目录
- **AND** `particle_fluid_2d` 不包含配方、微信、顾客或酒吧场景规则

#### Scenario: 检查生产脚本类型

- **WHEN** 静态检查扫描本变更新增的生产 GDScript
- **THEN** 成员、参数、返回值与集合按项目规则声明类型
- **AND** 文件与类职责不依赖全局绝对 NodePath

### Requirement: 静态配置与运行时状态分离

内容定义 MUST 使用只读 Resource 配表，运行时可变状态 MUST 存在于会话、领域状态或版本化快照中；生产逻辑 MUST 不在运行时修改共享 `.tres` 资源，也 MUST 不在 Resource 中保存场景 Node 引用。

#### Scenario: 两个调酒会话读取同一配方

- **WHEN** 两个隔离测试会话读取相同 RecipeDefinition
- **THEN** 一个会话的步骤与评价不会改变另一个会话或磁盘配方
- **AND** 配方 Resource 不持有任一会话的容器 Node

#### Scenario: 微信模板生成实例

- **WHEN** 微信模板生成消息或朋友圈
- **THEN** 可变的已读状态和生成时间只写入运行时实例
- **AND** 原始模板权重与内容字段保持不变

### Requirement: 稳定 ID 与引用完整性

所有可跨场景、跨配置或跨存档引用的内容 MUST 使用稳定 ID，MUST 在加载时检查唯一性、引用存在性、类别兼容和废弃映射；运行时实例 ID MUST 与内容定义 ID 分离。

#### Scenario: 检测重复 ID

- **WHEN** 两个原料、槽位或微信联系人声明相同稳定 ID
- **THEN** 内容校验以非零结果报告所有冲突路径
- **AND** 发布门禁不接受该内容目录

#### Scenario: 加载废弃内容 ID

- **WHEN** 存档引用已在迁移表中替换的旧内容 ID
- **THEN** 加载器映射到明确的新 ID 并记录迁移
- **AND** 未知且无迁移路径的 ID 被安全忽略或替换为配置占位内容

### Requirement: 像素素材导入规范

CatBar 像素纹理 MUST 采用统一基准网格、无过滤、无 mipmap 和整数缩放兼容的导入设置；动画图集 MUST 声明帧尺寸、帧数、锚点和方向命名，素材替换 MUST 不改变稳定内容 ID。

#### Scenario: 导入新器具图集

- **WHEN** 美术把符合清单的器具图集放入运行时资产目录
- **THEN** 导入配置保持像素边缘清晰且帧矩形不越界
- **AND** 工作台通过原有器具 ID 引用新纹理而不修改业务代码

#### Scenario: 检测非整数帧图集

- **WHEN** 图集尺寸无法被声明的帧尺寸整除
- **THEN** 资产校验报告具体文件与期望尺寸
- **AND** 该动画不进入发布内容清单

### Requirement: 资产清单与授权状态

每个 CatBar 发布资产 MUST 在清单中记录稳定资产 ID、用途、来源/作者、许可或原创状态、原始尺寸、锚点、动画信息和替换状态；仅有参考用途或授权不明的图片 MUST 不得被标记为可发布资源。

#### Scenario: 登记参考图

- **WHEN** 团队把本需求附图登记为视觉参考
- **THEN** 清单将其标记为 `reference_only` 或等效非发布状态
- **AND** 运行时场景不直接引用该参考图作为最终纹理

#### Scenario: 发布检查发现授权缺失

- **WHEN** 发布资产缺少作者或许可状态
- **THEN** 内容/发布校验失败并列出缺失项
- **AND** 可使用明确标记的原创占位资源继续开发构建

### Requirement: 美术源文件与运行时成品隔离

可编辑源文件 MUST 位于带 `.gdignore` 的 `art_source/cat_bar/` 或等效源目录，运行时资产 MUST 位于 `assets/cat_bar/` 的功能分类下；生产场景和 Resource MUST 只引用运行时可导入成品。

#### Scenario: Godot 扫描项目资源

- **WHEN** 项目包含 PSD、分层源文件或授权说明
- **THEN** Godot 不会把被隔离的美术源文件导入运行时资源库
- **AND** 授权说明仍可被版本控制和人工审阅

### Requirement: 代表性内容与占位契约

首轮实现 MUST 提供足以验证完整流程的代表性内容集，并 MUST 为尚未完成的美术或内容提供显式占位标识；占位内容 MUST 保持与最终内容相同的 ID、锚点和碰撞/点击范围契约。

#### Scenario: 运行首轮纵向切片

- **WHEN** 最终全量资产尚未完成
- **THEN** 玩家仍可使用至少一个 Shake 杯、一个量酒杯、一个长柄勺、两种酒液、冰块、一种香料和一个目标酒杯完成代表性配方
- **AND** 所有占位内容可从诊断或资产清单识别

### Requirement: 自动内容校验入口

系统 MUST 提供可由 Godot 4.7.1 headless 或仓库工具运行的内容校验入口，并 MUST 以进程退出码表示成功或失败；校验 MUST 覆盖稳定 ID、交叉引用、数值范围、策略注册、槽位兼容、资产存在、像素图集元数据和发布许可状态。

#### Scenario: 合法内容通过校验

- **WHEN** 默认 CatBar 内容集完整且所有约束满足
- **THEN** 校验输出各类别数量与占位数量摘要
- **AND** 进程以退出码 0 结束

#### Scenario: 内容存在多个错误

- **WHEN** 内容集同时包含重复 ID、缺失纹理和未知策略
- **THEN** 校验在一次运行中报告全部可发现错误
- **AND** 进程以非零退出码结束

