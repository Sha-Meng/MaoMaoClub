# CatBar 运行时资产

仅存放 Godot 可导入的运行时成品，按 `environment`、`characters`、`tools`、`ingredients`、`glassware`、`ui`、`wechat` 分类。像素纹理关闭过滤与 mipmap，并通过资产清单记录稳定 ID、来源、授权和替换状态。

可编辑美术源文件必须存放在 `art_source/cat_bar/`，不得由运行时场景直接引用。

## 命名与导入约定

- 目录固定为 `environment/`、`characters/`、`tools/`、`ingredients/`、`glassware/`、`ui/`、`wechat/`。
- 文件与稳定资产 ID 使用 `类别_主体_变体` 的 snake_case；替换美术时保持资产 ID 不变。
- 像素内容使用整数帧尺寸和锚点，世界节点落在整数坐标；项目默认关闭纹理过滤与 nearest mipmap filter。
- `asset_manifest.json` 是运行时资产、许可和占位状态的唯一清单。`reference_only` 条目没有运行时路径且禁止发布。
- AI 生成的开发素材必须使用 `PROJECT_GENERATED_REVIEW_REQUIRED`，记录生成来源与 `generated_pending_art_review`，发布前由项目负责人完成原创性、授权与画面质量复核。
- 执行 `Godot --headless --script res://tests/cat_bar/run_asset_validation.gd` 可聚合校验内容/资产交叉引用、尺寸、许可和占位数量。
