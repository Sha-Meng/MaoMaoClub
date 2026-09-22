# 技术设计：场景直取、猫爪抓取与动物原料

## 所有权

- `BartendingSessionDraft` 继续拥有容器内容和动作日志。
- `BartendingStation` 只拥有当前拖拽、猫爪表现和场景来源节点的短生命周期引用。
- `CatBarController` 在大厅启动时收集调酒师、打工猫和活动顾客，并在顾客进出时刷新来源表。
- 动物掉落物通过稳定 ID `animal_droppings` 进入既有 `sprinkle` 策略，不把动物 Node 或访问者实例 ID 写入存档。

## 输入与表现流程

1. 大厅全景取得世界焦点时隐藏系统鼠标并显示旋转 180° 的开放猫爪；手机或服务阶段恢复系统鼠标。
2. 点击物件后，猫爪切换为抓握帧；场景实体随指针移动，原锚点留空。
3. 既有 `_target_for` 和目标描边决定合法投放位置。
4. 普通物件沿用原有倾倒、量取、搅拌、封盖与 Shake 命令。
5. 动物来源开始拖拽时隐藏真实 Node，显示同纹理拖拽代理；释放到 Shake 杯后提交一次 `animal_droppings`，依次播放蹲下、排泄物落杯与命中粒子、三轮左右刨猫砂与尘粒、代理返回锚点，最后才恢复真实 Node 的原始位置与可见性。序列期间锁定其他拖拽和手机入口。
6. 非法释放、Esc、取消会话、关闭调酒焦点都无条件恢复来源节点与系统鼠标。

## 坐标契约

场景动物使用 `get_global_transform_with_canvas().origin` 映射为 CanvasLayer 屏幕坐标；大厅启动和顾客名单变化后刷新代理，不依赖任何调酒镜头转场。

## 美术契约

- 猫爪为 `assets/cat_bar/ui/` 下的 2×1 透明 PNG 图集，左右分别为开放与抓握状态。
- 掉落物为 `assets/cat_bar/ingredients/` 下的透明 PNG 单帧图标。
- 两者使用 nearest、无 mipmap、整数缩放兼容导入，并登记为 `PROJECT_GENERATED_REVIEW_REQUIRED`。
