## MODIFIED Requirements

### Requirement: 场景内实体调酒

调酒台 MUST 保证业务容器状态与可视容器状态一致；只有能够成功提交的操作才可播放完整倾倒动画，Shake 杯和成品杯的液位、颜色与空间边界 MUST 匹配各自杯体。

#### Scenario: 空量酒器重复倾倒

- **WHEN** 量酒器内容已全部转入 Shake 杯
- **THEN** 玩家不能再次拿起量酒器执行倾倒
- **AND** Shake 杯内容与步骤日志保持不变

#### Scenario: Shake 杯显示酒液

- **WHEN** 一种或多种基酒进入 Shake 杯
- **THEN** 液位按杯中总毫升数和杯体容量计算
- **AND** 液体颜色使用各基酒按剂量加权后的颜色
- **AND** 液体与运动粒子保持在 Shake 杯内轮廓中

#### Scenario: 杯盖完成封盖

- **WHEN** 杯盖被拖到 Shake 杯并成功封盖
- **THEN** 杯盖底沿与 Shake 杯杯口重合
- **AND** 独立桌面杯盖隐藏

#### Scenario: 成品酒液呈现

- **WHEN** 完成 Shake 的酒液被倒入成品杯
- **THEN** 成品杯按实际倒入毫升数显示与配方一致的液体颜色
- **AND** 液体形状限制在成品杯碗形内
- **AND** 系统在可观察的短暂展示后进入送餐流程
