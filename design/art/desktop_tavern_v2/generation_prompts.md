# V2 生成记录

用户最终选定的是第一次尺度校正生成的 `exec-91fc59e7-9395-4667-b898-847b9a912fbc.png`，已归档为 `desktop_idle_selected_v2.png`。下面关于最初交付与尺度校正的描述保留为生成过程记录；当前比例以用户选择为准。

后续完整提示词见 `refinement_prompts.md`（尺度校正与店长比例细节）。

最终交付：`desktop_idle_small_v2.png`（1672×941）与 `manager_proportions_v2.png`。最初几个缩放候选未满足尺寸，保留在工具默认生成目录作过程记录，项目最终稿使用校准后的版本。

日期：2026-10-17。工具：内置 `image_gen`。保留 V1，不覆盖旧稿。本轮只制作讨论效果图，不改运行时代码。

## 用户已明确的方向

1. 店长自由游走，可以与顾客闲聊。
2. 所有位置，包括店铺、桌椅和角色均可拖动，形成轻量 UGC 摆放。
3. 常驻屏幕占比 5–10%，避免过多遮挡。
4. 店长比例更自然。
5. 先看缩小后的常驻效果。

本稿以常驻场景高度约为屏幕高度 8% 解读占比；不包含系统任务栏。若用户所指是面积占比，后续另行校准。各物件可自由摆位；是否吸附任务栏及纵向边界尚未定稿，不再沿用 V1 的仅限横向拖动建议。

## 常驻效果图提示词

输入：`../desktop_tavern_v1/desktop_visual_v1.png`，为编辑目标，保持画风与主要元素，调整占屏尺度、角色比例和站位。

```text
Edit the provided V1 MaoMaoClub desktop mockup into V2. Preserve its warm hand-drawn 2D style, cream/charcoal/gold manager identity, moss green and warm wooden tavern cart, amber lighting, animal customers and system-taskbar grounding. The input is the edit target. This is a FULL DESKTOP at real idle-widget scale, NOT a zoomed beauty illustration.

CRITICAL SCALE: Render a full 16:9 desktop canvas, ideally 1920x1080. The entire visible GAME SCENE including the shop roof must be only about 8% of the full SCREEN HEIGHT (acceptable 5–10%). Place all game objects in a SMALL group near the bottom-right on the top edge of the system taskbar. At a 1920x1080 equivalent: taskbar occupies y=1040..1080, shop roof around y=950 and cart wheel bottoms at y=1040, manager roughly 48–55px tall, all game props fit approximately x=1370..1850. These are layout coordinates, not text to print. At least the upper 87% of the desktop should be essentially empty. Keep the wallpaper a calm pale blue-grey gradient and keep the taskbar FULL SCREEN WIDTH and normal OS scale. DO NOT enlarge the game to fill the frame. DO NOT shrink an entire V1 screenshot into an inset: scale down the GAME OBJECTS while keeping the DESKTOP full-frame. No magnified inset, no callout boards, no giant title, no wall or floor panel behind the objects.

Manager proportions: noticeably more natural and less caricatured than V1. Smaller head relative to body (approximately 2.8–3 heads tall including ears), moderately long torso, visible short but believable upper/lower legs, normal-length forearms, rounded stocky belly rather than two stacked spherical belly folds. Keep closed crescent eyes, whiskers, pointed cat ears, cream fur, open charcoal vest, chunky gold necklace, upward-curled tail, small amber rocks glass. Relaxed natural standing/walking pose with anatomically coherent shoulders and elbows. Do not make the manager skinny or human.
Show the manager outside the cart beside one seated animal customer, turned slightly toward that customer, with one extremely small quiet ellipsis bubble to suggest friendly conversation. Two other tiny cats work behind the counter. Cart, small tables, folding chairs and customers are all separate movable items, no shared fixed foundation. Rearrange naturally into the compact right-hand group. Furniture legs, feet and wheels touch taskbar top edge. No permanent drag handles or large HUD: controls are hidden in normal idle mode.
The only environmental branding is the existing small "Cat Club" cart sign. If a heading is included, use only a modest top-left "猫猫 Club · 常驻效果 V2" and a second very small line "常驻高度约 8% · 自由摆放". Avoid fake date stamps and large coin counters. This is the actual-size discussion preview, NOT a runtime screenshot.
```
