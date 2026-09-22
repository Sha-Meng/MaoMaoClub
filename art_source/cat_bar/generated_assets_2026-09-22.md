# CatBar 场景直取 3C 生成素材记录（2026-09-22）

## 生成方式

本次使用 Codex 内置 `image_gen`，以用户附图作为暖暗像素酒吧的风格参考。附图仅用于色温、像素密度和氛围参考，未复制其文字、品牌、角色或具体构图。运行时成品均已复制到 `assets/cat_bar/` 并登记在 `asset_manifest.json`。

## 双帧猫爪光标

- 运行时路径：`res://assets/cat_bar/ui/cat_paws_cursor_generated.png`
- 尺寸：1774×887；2×1 图集；单帧 887×887。
- 左帧：两只张开的奶油色猫爪；右帧：同一双猫爪向内抓握。
- 最终提示词：

  > Create a two-frame horizontal sprite sheet of an adorable pair of small cat paws used as a mouse cursor. Left frame: two open fluffy paws reaching downward, relaxed and ready to grab. Right frame: the same two paws gently clasped inward as if holding an object. Use the attached image only as a warm dark cozy pixel-art style reference. Fully transparent background, hard pixel edges, consistent scale and anchor, no text, no watermark, no extra objects.

## 动物掉落物图标

- 运行时路径：`res://assets/cat_bar/ingredients/animal_droppings_generated.png`
- 尺寸：1254×1254；透明单帧。
- 最终提示词：

  > Create one tiny cute stylized animal droppings ingredient icon for a whimsical cat cocktail game. It should read immediately as a small chocolate-brown poop swirl but remain playful and non-gross, with two tiny golden sparkle pixels. Use the attached image only as a warm dark cozy pixel-art style reference. Fully transparent background, hard pixel edges, no face, no text, no watermark, no container.

## 发布状态

两项素材当前均为 `PROJECT_GENERATED_REVIEW_REQUIRED` / `generated_pending_art_review`，可用于开发和玩法验证，发布前需要人工美术与许可审阅。
