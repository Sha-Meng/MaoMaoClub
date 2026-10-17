# V2 尺度校正与店长细节提示词

工具：内置 `image_gen`。以下为本轮实际使用的完整后续提示词，按调用顺序保存。最终小尺寸稿的主体高度经只读像素边界核对约为 7.76%。

## 第一次尺度校正

```text
Precise layout edit of this desktop mockup. The current game cluster is STILL TOO LARGE: the shop is about 230 pixels tall in a 1672x941 image, about 24%, even though the label says 8%. FIX THE ACTUAL SCALE, not just the text.

Keep the output canvas 1672x941 (or exactly equivalent 16:9 proportions). Keep the pale desktop wallpaper, top-left two text lines, and full-width OS taskbar UNCHANGED at their current sizes. The taskbar TOP EDGE stays at y=861. Scale the ENTIRE GAME CLUSTER (shop, manager, employee cats, customers, chairs, tables, tiny speech bubble) DOWN TO ONE THIRD of its current linear dimensions, anchoring the group to the BOTTOM RIGHT at the taskbar upper edge.
Pixel target bounding boxes: all game artwork must fit approximately x=1410..1652, y=783..861. Shop/cart height must be about 75 pixels, manager height about 48 pixels. The shop roof and all vines MUST BE BELOW y=780. Nothing belonging to the game may appear above y=780. Upper approximately 83% of the whole screen must show only wallpaper (except existing tiny top-left heading). This means the game is a genuinely TINY idle desktop companion near the rightmost corner. Keep the manager next to a customer to imply chatting. Keep their natural V2 proportions and the warm 2D illustration. Preserve feet, wheels and chair legs touching y=861. No enlargement, closeup, magnifier, inset, new labels, arrows or explanatory panels. The desired game is visually small and unobtrusive even if individual tiny character details are harder to see at this scale.
```

## 第二次尺度校正

```text
Make one precise size correction to this image. Keep the 1672x941 desktop, taskbar, wallpaper, text and all other existing pixels/composition unchanged. The bottom-right game cluster is still 125 pixels tall; it MUST be only 70–80 pixels tall. Scale every GAME object (the entire shop with vines, all cats, customers, chairs and tables) to 60 percent of its CURRENT size, anchored to the bottom-right at the upper edge of the taskbar y=863. After editing, the HIGHEST GAME PIXEL must be at or below y=785 and every foot and wheel bottom must land at y=863. All game objects together fit x=1400..1650 and y=785..863. The output should have a truly tiny scene in the lower right; retain the same natural stocky manager with smaller head. Do not zoom or crop the canvas, do not enlarge anything for legibility, do not add a closeup, do not change the taskbar, and do not merely change the text.
```

## 最终小尺寸校正

```text
Edit only the miniature game cluster at the lower right of this desktop. Make that ENTIRE cluster HALF of its current width and HALF of its current height. The entire current cart including vines is about 100 pixels tall; the new cart including vines should be only 50–60 pixels tall in the same 1672x941 canvas. This must be a very small desktop toy, not an illustration focal point. Anchor all feet/wheels to the existing taskbar upper edge y=863 and keep the group near the right edge. Keep the entire desktop wallpaper, title, taskbar and icons unchanged at their current scale. Preserve all character identities, natural stocky manager proportions and warm art style. Do not zoom the desktop, do not crop the canvas or introduce a magnified inset. Tiny details may become simple at this size.
```

## 店长比例细节

```text
Create a separate full-body character proportion refinement image for MaoMaoClub's manager. This is an enlarged CHARACTER DETAIL for discussion, not the actual desktop size. Input 1 is the previous colored V1 design to preserve style, colors and identity; input 2 is the user's original authoritative manager sketch to preserve distinctive features.

Show one coherent full-body manager in a relaxed three-quarter standing pose on a plain warm ivory background, with a second smaller side/three-quarter walking pose beside it. Same character in both poses. Warm hand-drawn 2D game illustration, clean warm brown outlines and restrained soft shading. Keep cream-white fur, pointed cat ears, closed crescent eyes, small triangular nose, friendly curved mouth, whiskers, chunky gold chain, open charcoal sleeveless vest, rounded belly with small navel, upward-curled long tail, and a modest short glass with amber drink in one paw. The expression is relaxed and sociable, suited to wandering and chatting with seated guests.

Correct the V1 proportions noticeably: reduce head width and height relative to the body; approximately 2.8–3 heads total body height including ears. Torso longer than head, gently rounded single belly volume rather than enormous stacked spherical folds. Stocky but believable shoulders and pelvis, clearly visible upper and lower short legs, paws planted naturally with space between them. Arms have readable elbows, reach mid-thigh and bend naturally while holding the glass; glass must not be glued to the face. Slightly longer limbs and smaller belly than V1. Do not make him skinny, muscular, human, four-legged or a giant-headed baby. In the smaller walking pose the limbs and tail follow a relaxed walking gesture, not dancing.

Keep generous whitespace, no tavern, no desktop or taskbar, no other characters, no props besides the held glass. Small clean heading exactly "店长 · 比例调整 V2". Small footer exactly "局部放大展示 · 非实际常驻大小". No measurements or extra captions.
```
