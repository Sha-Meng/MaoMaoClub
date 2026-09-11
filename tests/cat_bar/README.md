# CatBar 测试

- `unit/`：配置、注册表、状态机、交互事务与评价。
- `integration/`：工作台、送酒、订单和存档组合流程。
- `visual/`：场景冒烟、镜头、像素稳定性和性能观察。

常用入口（Godot 4.7.1）：

- `res://tests/cat_bar/run_cat_bar_tests.gd`：CatBar、经营、存档和微信自动测试。
- `res://tests/cat_bar/run_asset_validation.gd`：内容与资产聚合校验。
- `res://tests/cat_bar/run_cat_bar_performance.gd`：60 FPS 帧预算采样。
- `res://tests/cat_bar/run_cat_bar_stability.gd`：30 分钟等价时长模拟。
- `res://tests/cat_bar/capture_cat_bar_views.gd`：GPU 渲染大厅、调酒台、手机主页、朋友圈、联系人和聊天视觉验收截图。
