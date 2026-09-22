# cat-bar-content-architecture 规格增量

## ADDED Requirements

### Requirement: 场景来源与领域原料隔离

动物场景 Node、访问者实例 ID 和屏幕坐标 MUST 只存在于调酒表现层短生命周期状态；领域命令、配方、存档和内容注册表 MUST 只记录稳定原料 ID `animal_droppings`。

#### Scenario: 保存包含动物掉落物的会话

- **WHEN** 会话草稿被序列化
- **THEN** 容器仅保存 `animal_droppings` 及其剂量
- **AND** 数据中不存在 Node、实例 ID 或场景坐标
