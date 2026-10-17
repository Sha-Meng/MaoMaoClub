# 用户原型对应的交替步态分层原稿

参考原图：`assets/source/references/2026_10_17_desktop_tavern/manager_crossing_stride_reference.png`。

工具：内置 imagegen。首稿 `crossing_parts_v3.png`、第二轮 `crossing_parts_v3_refined.png` 保留用于溯源。连续身体带单腿的结构在大幅前摆时仍会牵拉腹部，最终改为宽腹内隐藏根部的独立双腿绑定。第三轮输出 exec-6be03de7-8dbc-41f2-9bed-1f09ae4e3fcc.png，归档为 **`crossing_parts_final.png`**；这是构建脚本实际使用的源图。

## 第三轮提示词

```text
Use case: precise-object-edit. Edit ONLY the top-middle torso piece of this transparent character rig atlas, preserve exact 1536x1024 canvas and all other pieces unchanged.
Remove its single leg and foot completely. Finish the lower torso as a broad rounded pelvis beneath the belly, suitable for hiding the roots of two independently animated legs behind/under it. The torso must have no legs or feet. Keep neck, vest, gold chain, chest and belly exactly in place. Lower torso should end around y340, maintain full hip width, with subtle cream fur volume and minimal low-contrast lower contour, avoid a heavy dark belt-like belly bottom line. Do not make it narrow or pointed. The existing isolated leg in the top-right will be reused for both legs, so exact fur color matching is vital. Keep all other head, arms, tail, glass unchanged. No additional pieces in the empty bottom-right. Genuine transparent alpha, no scene or ground.
```

## 第二轮提示词

```text
Use case: precise-object-edit. Edit the attached animation rig atlas, keep transparent background and exact 1536x1024 layout.
Change ONLY the top-middle connected torso-and-one-leg piece (about x590..985, y5..435). Its single attached leg is too far left, leaving the belly suspended far ahead of the feet. Redraw the lower half of this ONE piece with natural proportions: relocate the connected near hip, thick short thigh, shin and broad paw to sit directly UNDER THE CENTER OF THE BELLY, leg axis around x800 rather than x690, foot flat on baseline y420. Foot points right. Keep ONE leg only, connected organically with no seam or separate cap. The core's belly/chest/vest/neck remain at their current positions. Belly round and stout, no extreme forward belly overhang. The leg should originate in the lower central pelvis, not from the side of the torso. This is a binding pose for a normal front-back walking cycle. Keep near paw width around 110 px, not a giant club foot, short sturdy calf. All other seven pieces remain exactly unchanged in shape, color, placement and proportions. Keep original linework, no labels, no backgrounds or glow. Actual transparent alpha.
```

## 首轮提示词

```text
Use case: identity-preserve. Asset type: production layered 2D cutout animation rig atlas, transparent background.
Reference image is the user's EXACT target cat manager, especially round broad face, very short neck, fat round belly, short thick legs and big paws, dark charcoal vest, gold necklace, cream fur, one whiskey tumbler. Match the image's hand-painted clean outlined illustration and cheerful confident sturdy character. Do not make a slim long-necked cat. Need separate reusable art pieces for Blender animation, NOT a sprite animation strip and NOT multiple whole characters.
Arrange exactly 9 isolated pieces in a spacious 3x3 grid, no labels, no framing, no shadows. Each part entirely inside its cell, no neighbors touching:
TOP LEFT: head only, broad round cat face and two ears, slightly three-quarter facing right, short chin with no long neck, same expression as reference, no necklace.
TOP MIDDLE: armless headless tailless torso WITH ONLY ONE LEG already seamlessly joined to the belly. Includes open dark vest and gold chain. Big belly flows continuously into ONE thick short near thigh, shin and wide paw beneath center-left of belly. This is one connected anatomical body+near-leg piece. ONLY ONE FOOT and ONE LEG, absolutely no second leg. Near leg neutral straight-down standing pose, paw angled slightly right, not stretched. Belly-to-thigh shading smooth, no dark seam dividing body from leg. The far leg will be added as separate layer behind this body. No arms or arm stumps. Neck cut at top.
TOP RIGHT: isolated far whole short thick leg and broad paw, upper thigh extends high as hidden root for overlap behind belly. Proportions and fur exactly matching near leg, neutral standing pose, paw angled right.
MIDDLE LEFT: near hanging relaxed arm and hand, full shoulder-to-paw, thick soft cream anatomy.
MIDDLE CENTER: far hanging relaxed arm and hand, same scale, slightly shaded, three-quarter facing right.
MIDDLE RIGHT: near arm bent to hold a cup at chest height, hand empty, fingers shaped for glass grip; includes full shoulder, elbow and forearm, compact sturdy upper arm.
BOTTOM LEFT: isolated thick upward-curled cream tail from reference, tip on left and root on right.
BOTTOM CENTER: isolated transparent short whiskey tumbler with amber liquid and ice, no hand.
BOTTOM RIGHT: leave completely transparent and EMPTY, no extra figure.
Technical critical: body and near leg must share a continuous organic outline, with only one visible paw in top-middle. Far leg independent. Clean high-opacity colors and thin warm brown outlines, actual transparent alpha, no colored speckles. Preserve chunky short-limbed character proportions, not muscular human legs.
```
