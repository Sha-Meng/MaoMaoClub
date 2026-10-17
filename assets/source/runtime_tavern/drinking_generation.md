# 持杯与饮用补充素材记录

日期：2026-10-17。使用内置 image_gen，原生透明 PNG；在 Godot 4.6.3 中注册脚底及肩部，不用后期缩放肢体改变体型。

运行素材：`assets/tavern/drinks_first_v2.png`、`drinks_extra_v2.png`（各六列三行）、`manager_held_arm.png`（屈肘手与杯同一部件）。前两张分别参考原运行顾客图，店长手臂参考团队分件。扩展饮用初稿因兔脚触及浣熊耳朵未采用，保留为 `drinks_extra_before_spacing.png`；最终间隔修订图已用于运行。

## drinks_first

参考：D:/MaomaoClub/MaoMaoClub/assets/tavern/customers_first.png

```text
Use case: identity-preserve. Asset type: actual transparent game drinking-animation sprite atlas. Use supplied image ONLY as character identity, proportions, clothes, painterly style and SEATED posture reference. Produce exactly THREE equal-height ROWS and SIX equal-width COLUMNS, one character per row. Every frame is the SAME fully seated character, same head size, hips/feet positions, side-three-quarter RIGHT facing. NO CHAIR OR TABLE (engine supplies furniture), no background, ground, text, borders or shadows, true transparent alpha. Six columns show a coherent DRINKING gesture: 1 grips a small clear tumbler of amber drink at lower chest; 2 elbow bends lifting that SAME cup halfway; 3 cup rim touches lips, hand firmly around glass; 4 small sip, wrist and cup tilt together at lips; 5 lowers cup halfway while STILL GRIPPING; 6 cup returns to lower chest, fingers still wrapped. Only the drinking arm, wrist, cup and small facial expression change; torso, other arm, legs and feet stay consistent. Glass is physically gripped in EVERY frame: fingers wrap around its near side, thumb on far side, palm touches glass, no floating drink and no ghost hands or duplicate glasses. Shoulders remain connected. Cup and hand are drawn together, not separate assets. Preserve original natural anatomy, distinct body builds, expressions and clothes. Keep seated hips at 72% row height and foot soles at 93%, same X in every cell, full bodies and tails with clear padding so no sprite crosses cells. Landscape 2048x1024. Row1 lively slender orange squirrel, cream sleeveless ribbed top and navy shorts, big fluffy tail. Row2 tall tired golden retriever, blue rolled-sleeve shirt, red loose tie, charcoal trousers. Row3 broad heavy calm capybara, sage plaid shirt, brown trousers. Each holds ONE identical small tumbler; no accessories in the free hand.
```

## drinks_extra

参考：D:/MaomaoClub/MaoMaoClub/assets/tavern/customers_extra.png

```text
Use case: identity-preserve. Asset type: actual transparent game drinking-animation sprite atlas. Use supplied image ONLY as character identity, proportions, clothes, painterly style and SEATED posture reference. Produce exactly THREE equal-height ROWS and SIX equal-width COLUMNS, one character per row. Every frame is the SAME fully seated character, same head size, hips/feet positions, side-three-quarter RIGHT facing. NO CHAIR OR TABLE (engine supplies furniture), no background, ground, text, borders or shadows, true transparent alpha. Six columns show a coherent DRINKING gesture: 1 grips a small clear tumbler of amber drink at lower chest; 2 elbow bends lifting that SAME cup halfway; 3 cup rim touches lips, hand firmly around glass; 4 small sip, wrist and cup tilt together at lips; 5 lowers cup halfway while STILL GRIPPING; 6 cup returns to lower chest, fingers still wrapped. Only the drinking arm, wrist, cup and small facial expression change; torso, other arm, legs and feet stay consistent. Glass is physically gripped in EVERY frame: fingers wrap around its near side, thumb on far side, palm touches glass, no floating drink and no ghost hands or duplicate glasses. Shoulders remain connected. Cup and hand are drawn together, not separate assets. Preserve original natural anatomy, distinct body builds, expressions and clothes. Keep seated hips at 72% row height and foot soles at 93%, same X in every cell, full bodies and tails with clear padding so no sprite crosses cells. Landscape 2048x1024. Row1 slim sly orange fox, purple sweater, teal scarf, dark trousers, white tipped tail. Row2 cream long-eared rabbit, ochre jacket, cream shirt, olive shorts. Row3 stocky sleepy raccoon, lavender hoodie, navy trousers, striped tail. All phones/books are put aside while drinking; free hand rests on thigh. Each has ONE small amber tumbler.
```

## manager_held_arm

参考：D:/MaomaoClub/MaoMaoClub/assets/tavern/walk_parts_team.png

```text
Use case: identity-preserve. Make ONE isolated production cutout NEAR ARM and its held small whiskey tumbler for the cream cat manager in TOP ROW of supplied reference. Match his warm cream fur, rounded paw, dark brown ink line and painterly style exactly. Output only the COMPLETE bent arm from rounded SHOULDER CAP, upper arm pointing naturally DOWN, elbow bent 90 degrees, FOREARM pointing diagonally UP AND RIGHT, PAW gripping a small upright clear amber tumbler at lower chest. Anatomically natural relaxed elbow tuck: NOT an outstretched straight arm, not a horizontal stiff salute. Paw fingers visibly wrap the near side of the glass, thumb behind, cup sits in the paw, no floating props. Arm no sleeve (manager wears sleeveless vest). The top shoulder cap is the highest point of this isolated assembly; cup rim remains a little below shoulder height. Entire arm+cup fully visible with clear padding on all sides, no character head, torso, other limbs, text or shadows. TRUE TRANSPARENT alpha background. Exactly one single arm and one small tumbler. Arm compact softly bent, not muscular long human arm. Facing right three-quarter view as reference. Image 512x512.
```

## drinks_extra_gutters

参考：D:/MaomaoClub/MaoMaoClub/assets/tavern/drinks_extra_v2.png

```text
Use case: precise-object-edit. Preserve this exact THREE ROWS SIX COLUMNS drinking sprite atlas, all 18 full-body characters, same outfits, right-facing poses and fingers holding the cup in every frame. Fix spacing ONLY: move/scale all six frames of each row consistently into their own equal-height row, with at least 18 transparent pixels above the ears and 18 below the feet in EVERY row. There MUST be no touching or overlap between rows: rabbit toes must NOT touch raccoon ears; fox paws must NOT touch rabbit ears. Keep all body parts, ears and tails complete within their own cell, clear horizontal gutters too. NO ground lines, chairs, floor, shadows, background or text. All exterior is true transparent zero-alpha PNG, preserve existing transparency and painted colors. Six columns remain lower-chest hold, halfway raise, rim touches lips, tilted sip, lower midway, lower chest. Do not add anything, do not change poses or identities, just fit each sprite with generous empty margins into a clean 6x3 sprite grid.
```
