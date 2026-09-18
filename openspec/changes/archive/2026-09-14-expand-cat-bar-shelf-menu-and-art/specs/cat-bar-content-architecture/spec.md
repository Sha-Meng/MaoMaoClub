## ADDED Requirements

### Requirement: 调酒菜单素材完整性

所有进入一级或二级吧台菜单的内容 MUST 在资产清单中登记唯一资产 ID、运行时路径、尺寸、锚点、来源、许可和审阅状态，并 MUST 绑定可加载图片。

#### Scenario: 校验默认菜单素材

- **WHEN** 资产校验扫描默认吧台菜单
- **THEN** 五种基酒、三种工具和三种辅料均引用存在的运行时图片
- **AND** 图片采用 nearest、无 mipmap 的像素导入约束

