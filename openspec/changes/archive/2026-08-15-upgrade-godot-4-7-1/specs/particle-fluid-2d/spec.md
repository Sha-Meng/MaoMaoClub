## MODIFIED Requirements

### Requirement: 可验证性与性能基线

2D 粒子流体能力 MUST 提供可在 Godot 4.7.1 headless 模式运行的自动化测试入口，
并 MUST 以进程退出码表示成功或失败。性能基线 SHALL 记录精确引擎构建、硬件、
实际交互粒子档和压力观察档。

#### Scenario: 引擎升级后的流体回归

- **WHEN** 项目固定版本升级到 Godot 4.7.1
- **THEN** 项目解析、默认测试、长稳测试和独立场景冒烟全部通过
- **AND** 交互演示使用重新测量的 4.7.1 性能预算
