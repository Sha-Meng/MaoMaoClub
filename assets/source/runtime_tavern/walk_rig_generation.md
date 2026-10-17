# 步行分件素材生成记录

日期：2026-10-17；使用内置 image_gen（非 CLI）。最终运行素材：assets/tavern/walk_parts_first.png、walk_parts_extra.png、walk_parts_team.png。每张三行、五个分件，保留原生透明 alpha。

## puppet_first

参考：D:/MaomaoClub/MaoMaoClub/assets/tavern/customers_first.png

```text
Use case: identity-preserve. Reference for identity, outfit and warm painted line art. Make a production CUT-OUT PUPPET PARTS atlas, not a walkcycle, no complete standing figures. STRICT THREE ROWS by FIVE COLUMNS of isolated parts on true transparent alpha, equal cells, HUGE clear gutters so no part crosses cell borders. ONE CHARACTER PER ROW. All parts same slightly three-quarter RIGHT facing view. COLUMN 1: head+neck+torso+hips+tail only, NO ARMS AND NO LEGS; torso ends at hips, include waist/shorts upper edge and tail. COLUMN 2: complete detached far arm from rounded shoulder cut through elbow to hand, relaxed almost straight hanging down. COLUMN 3: complete detached near arm with rounded shoulder cut, elbow to hand, relaxed hanging down. COLUMN 4: complete detached far leg from rounded upper thigh to knee to ankle and right-facing foot, relaxed straight. COLUMN 5: detached near leg thigh/knee/ankle/right-facing foot relaxed straight. Upper arms include the character's sleeve garment; legs include relevant trouser/short portions. Limbs end with overlapping rounded cuts at shoulder/thigh for articulated animation, NO severed flesh or gore (paper puppet clothing/fur only). Hands open relaxed, no props. EACH PART IS SEPARATE AND HAS TRANSPARENT SPACE ALL AROUND, do not draw a background, shadow, floor, grid, text or watermark. Preserve anatomy and identifying clothing/face from reference, natural adult animal proportions. Neutral parts are to be rotated as actual limbs in engine so both arms and legs must be complete. 5 equal-width columns x3 equal-height rows, canvas1536x1024. Row1 lively slender orange squirrel, cream sleeveless ribbed shirt/navy shorts, fluffy tail attached to torso. Row2 tall golden retriever, blue rolled-sleeve shirt/red loose tie/charcoal trousers, tired gentle face. Row3 broad stocky capybara, sage plaid shirt/brown trousers, calm face.
```

## puppet_extra

参考：D:/MaomaoClub/MaoMaoClub/assets/tavern/customers_extra.png

```text
Use case: identity-preserve. Reference for identity, outfit and warm painted line art. Make a production CUT-OUT PUPPET PARTS atlas, not a walkcycle, no complete standing figures. STRICT THREE ROWS by FIVE COLUMNS of isolated parts on true transparent alpha, equal cells, HUGE clear gutters so no part crosses cell borders. ONE CHARACTER PER ROW. All parts same slightly three-quarter RIGHT facing view. COLUMN 1: head+neck+torso+hips+tail only, NO ARMS AND NO LEGS; torso ends at hips, include waist/shorts upper edge and tail. COLUMN 2: complete detached far arm from rounded shoulder cut through elbow to hand, relaxed almost straight hanging down. COLUMN 3: complete detached near arm with rounded shoulder cut, elbow to hand, relaxed hanging down. COLUMN 4: complete detached far leg from rounded upper thigh to knee to ankle and right-facing foot, relaxed straight. COLUMN 5: detached near leg thigh/knee/ankle/right-facing foot relaxed straight. Upper arms include the character's sleeve garment; legs include relevant trouser/short portions. Limbs end with overlapping rounded cuts at shoulder/thigh for articulated animation, NO severed flesh or gore (paper puppet clothing/fur only). Hands open relaxed, no props. EACH PART IS SEPARATE AND HAS TRANSPARENT SPACE ALL AROUND, do not draw a background, shadow, floor, grid, text or watermark. Preserve anatomy and identifying clothing/face from reference, natural adult animal proportions. Neutral parts are to be rotated as actual limbs in engine so both arms and legs must be complete. 5 equal-width columns x3 equal-height rows, canvas1536x1024. Row1 slim sly orange fox, purple sweater/teal scarf/dark trousers, white tipped tail attached to torso. Row2 slim cream rabbit long ears, ochre jacket/cream shirt/olive shorts, curious face, no book in hands. Row3 stocky raccoon, lavender hoodie/navy trousers, sleepy face, striped tail attached to torso, no phone in hands.
```

## puppet_team

参考：D:/MaomaoClub/MaoMaoClub/assets/tavern/cat_team.png

```text
Use case: identity-preserve. Reference for identity, outfit and warm painted line art. Make a production CUT-OUT PUPPET PARTS atlas, not a walkcycle, no complete standing figures. STRICT THREE ROWS by FIVE COLUMNS of isolated parts on true transparent alpha, equal cells, HUGE clear gutters so no part crosses cell borders. ONE CHARACTER PER ROW. All parts same slightly three-quarter RIGHT facing view. COLUMN 1: head+neck+torso+hips+tail only, NO ARMS AND NO LEGS; torso ends at hips, include waist/shorts upper edge and tail. COLUMN 2: complete detached far arm from rounded shoulder cut through elbow to hand, relaxed almost straight hanging down. COLUMN 3: complete detached near arm with rounded shoulder cut, elbow to hand, relaxed hanging down. COLUMN 4: complete detached far leg from rounded upper thigh to knee to ankle and right-facing foot, relaxed straight. COLUMN 5: detached near leg thigh/knee/ankle/right-facing foot relaxed straight. Upper arms include the character's sleeve garment; legs include relevant trouser/short portions. Limbs end with overlapping rounded cuts at shoulder/thigh for articulated animation, NO severed flesh or gore (paper puppet clothing/fur only). Hands open relaxed, no props. EACH PART IS SEPARATE AND HAS TRANSPARENT SPACE ALL AROUND, do not draw a background, shadow, floor, grid, text or watermark. Preserve anatomy and identifying clothing/face from reference, natural adult animal proportions. Neutral parts are to be rotated as actual limbs in engine so both arms and legs must be complete. 5 equal-width columns x3 equal-height rows, canvas1536x1024. Row1 round cream cat manager, open charcoal vest/gold chain/round belly/curled cream tail/relaxed smile; NO pants or glass. Row2 lean charcoal cat bartender, cream rolled sleeves/long olive apron/golden eyes. Row3 compact orange-white cat server, cream shirt/rust short apron/olive trousers/cheerful face.
```

## 分件清理提示词

对三张分件原图分别执行同一编辑提示词，最终图片完整保留在运行素材目录：

```text
Use case: background-extraction and precise-object-edit. Edit target is supplied puppet atlas. MUST output genuine transparent PNG with zero-alpha background: completely REMOVE every brown/tan/gray backdrop gradient between and around all parts; background is empty transparent, no checkerboard illustration. Preserve the exact row and part placements, sizes, identities, clothing, fur, tails, ink and painted colors. In the LEFTMOST torso column ONLY, remove ALL remaining arms, sleeves sticking out and hands from the torso, reconstruct the torso side outline cleanly from shoulder socket to waist; keep head, torso, hips and tail. The other four columns are detached complete arms/legs and must remain intact and isolated. Keep three rows and five columns exactly as source; do not add complete people, props, shadows or text. All exterior space and gaps between the 15 separate parts must be alpha 0. This is an animation-ready transparent cutout atlas.
```

## 未采用的候选

曾尝试三张八帧步行图集，因同侧脚重复、帧间锚点及比例漂移，未接入运行时；保留在本目录 rejected_walk_atlas_*.png，仅作过程记录。最终采用分件和连续关节驱动。整身网格变形也因躯干扭曲未采用。
