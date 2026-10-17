# 店长分层原稿来源

日期：2026-10-17。使用内置 imagegen，真实透明背景；未使用外部付费 API。

参考：`design/art/desktop_tavern_v2/manager_proportions_v2.png`（用户选定比例与画风）、`assets/tavern/grounded/manager.png`（现有运行角色）。

原始生成文件：`C:/Users/shame/.codex/generated_images/01a148e3-3535-71c0-8163-18f099bb573a/exec-4a60193d-64cd-483b-89c6-af0aa0f460a5.png`；复制为本目录 `parts_atlas.png`。实际输出 1254×1254 RGBA，提示词要求的 1536 尺寸与规则网格没有被严格执行，因此按实际像素位置建立 UV 部件定义，未按理想网格生切。

## 完整提示词

```text
Create ONE production-ready 2D cutout character RIG PARTS ATLAS, true transparent background, a square 1536x1536 image with exactly a 3 by 3 grid of equally sized 512 square cells, generous transparent gutters. No labels, no text, no grid lines. The references define our tavern manager: cream/light orange chubby adult anthropomorphic cat, dark charcoal open sleeveless vest, gold chain, relaxed knowing smile, soft handpainted ink outlines, mature natural proportions not a big baby. Keep exactly that character and drawing style. All body pieces at a consistent three-quarter side view looking RIGHT, suitable for horizontal walking. This is an exploded puppet parts sheet, NOT multiple whole characters. Each cell contains exactly the specified separate body part centered, all artwork fully inside its cell, on transparency. Row1 col1: whole head including both pointed ears, whiskers and short broad neck, half-closed friendly eyes and small smug smile facing right, no torso. Row1 col2: complete chubby torso with open dark vest, gold necklace and round cream belly/navel, from shoulders through round pelvis, NO head, NO arms, NO legs, NO tail. Repaint hidden belly and vest surfaces behind the arms. Row1 col3: the near complete arm hanging DOWN, plump shoulder, elbow and relaxed closed paw all joined, no sleeve, long enough to reach pelvis; shoulder root has generous painted overlap. Row2 col1: far complete arm hanging DOWN with relaxed paw, same appearance, slight darker shading; complete root overlap. Row2 col2: near complete short sturdy leg from broad rounded upper thigh, knee, ankle to broad cat paw facing RIGHT; neutral almost straight vertical stance; NO hard cut lines at knee; enough thigh length for real walking, not just feet. Row2 col3: corresponding far complete short sturdy leg, same scale, slight darker shading, paw pointing RIGHT; complete painted upper thigh overlap. Row3 col1: complete curled cream-orange cat tail, lower root at bottom right and curved tip at upper left, fully isolated. Row3 col2: bent near arm holding pose, shoulder at upper left, elbow bottom left, forearm extending horizontally right, empty grasping paw at right ready to grip a glass; complete connected arm and empty hand only, no cup. Row3 col3: isolated small transparent tumbler containing amber drink and two ice cubes, rim horizontal, seen at same three-quarter angle, NO hand, NO tray. Render rich clean opaque painted body interiors with antialiased alpha contours. Individual cell assets must be spatially separate and complete, no ground shadows. This atlas will be attached to real Blender bones, so hidden limb roots must be filled with matching fur and overlap sufficiently. No checkerboard baked into pixels. No extra character or decorative elements.
```

## 使用与检查

原稿九个部件通过 UV 区域使用，头、躯干、两臂、两腿、尾巴、持杯臂、杯子分别绑定。腿部连续网格包含大腿、小腿、脚三组权重；杯子是持杯臂子骨骼的独立部件。此次不拆分表情、衣摆或制作坐姿/饮酒。

原稿低 alpha 边缘有彩色残余，渲染材质采用 0.88 alpha 阈值后由 32 样本抗锯齿；未修改原稿。腿根重叠和杯身露出位置经实际渲染校正。最终画风与自然度仍待用户确认。
