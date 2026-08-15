## MODIFIED Requirements

### Requirement: Godot 版本固定

项目的设计、实现、测试、场景、构建和性能建议 SHALL 统一面向 Godot 4.7.1 stable，
精确构建为 `4.7.1.stable.official.a13da4feb`。版本升级 MUST 同步根约束、版本文件、
技术偏好和项目 Godot 技能，并 MUST 重新运行兼容性测试。

#### Scenario: 使用当前编辑器开发

- **WHEN** 开发者使用项目约定的 Windows Godot 编辑器打开项目
- **THEN** 编辑器版本为 Godot 4.7.1 stable
- **AND** 自动化验证使用相同精确构建的 console 程序
