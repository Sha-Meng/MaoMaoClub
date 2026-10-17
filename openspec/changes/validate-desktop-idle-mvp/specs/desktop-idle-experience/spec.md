# desktop-idle-experience 规格变更

> 窗口范围更新（2026-10-17）：原生透明、默认置顶与窗口操作现由 `desktop-window` 能力规定，优先于本变更中旧 A/B 档的可选透明描述。本变更仍用于跟踪其余挂机体验的验收，未整体归档。

## ADDED Requirements

### Requirement: Windows 桌面 MVP 目标

桌面挂机 MVP SHALL 只面向 Windows，并且 SHALL 不要求 macOS 或 Linux 行为用于验证。

#### Scenario: 验证平台目标

- WHEN 桌面挂机 MVP 被实现
- THEN 实现目标是 Windows 上的 Godot 4.6.3 stable
- AND 本地验证使用 Windows Godot 可执行文件

### Requirement: A 档桌面小酒馆窗口

桌面挂机 MVP SHALL 先提供 A 档桌面窗口，再要求 B 档桌面宠物增强。

A 档指稳定的小尺寸无边框 Windows 窗口，窗口出现在桌面边缘附近、保持可交互，并在重启后恢复位置。允许使用占位背景美术。

#### Scenario: 启动 A 档窗口

- WHEN 玩家启动 MVP
- THEN 酒馆出现在桌面边缘附近的小型 Windows 窗口中
- AND 该窗口可以作为可玩的桌面酒馆表面
- AND 真透明和点击穿透行为不是 MVP 验收必需项

#### Scenario: 保留窗口位置

- WHEN 玩家改变或关闭窗口
- THEN 游戏保存最后的窗口位置和尺寸
- AND 下次启动时，在当前显示器配置有效的情况下恢复保存位置

### Requirement: B 档桌面宠物增强不阻塞

桌面挂机 MVP SHALL 将真透明背景、可靠置顶、任务栏/多屏位置增强和点击穿透行为作为后续增强，除非它们在实现中能被快速证明可行。

#### Scenario: 没有 B 档增强也能验收 MVP

- WHEN A 档窗口、猫猫交互、顾客服务循环和持久化都可用
- THEN MVP 可以被判定为验证通过
- AND 缺少 B 档点击穿透或真透明不阻塞 MVP 验收

### Requirement: 占位酒馆世界

桌面挂机 MVP SHALL 在正式美术完成前，使用占位资源展示可读的酒馆世界。

#### Scenario: 进入酒馆场景

- WHEN MVP 场景启动
- THEN 玩家能看到酒馆吧台或吧台区域
- AND 玩家能看到简单座椅或等待区域
- AND 玩家能看懂顾客入口和出口方向
- AND app 入口场景仍然是薄承载或路由层，不拥有具体玩法逻辑

### Requirement: 三只可交互猫猫

桌面挂机 MVP SHALL 在第一版可玩版本中包含且只包含三只猫猫。

猫猫 SHALL 支持待机存在感、轻量游走、点击反馈、拖拽、释放和服务可用性变化。

#### Scenario: 与猫猫交互

- WHEN MVP 启动
- THEN 酒馆区域中可见三只猫猫
- AND 每只猫猫都可以被点击并立即反馈
- AND 每只猫猫都可以被玩家拖拽

#### Scenario: 被拖拽猫猫的可用性

- WHEN 一只猫猫正在被拖拽
- THEN 这只猫猫不可被分配给顾客服务
- AND 释放猫猫后，它会回到有效酒馆区域或工作位置
- AND 返回后猫猫可以重新变为可服务状态

### Requirement: 顾客服务生命周期

桌面挂机 MVP SHALL 将顾客服务定义为由可用猫猫完成的一笔占位销售。

#### Scenario: 顾客接受服务

- WHEN 一名顾客生成
- THEN 顾客进入酒馆
- AND 顾客请求服务
- AND 如果暂时没有可用猫猫，顾客会等待
- AND 可用猫猫可以被分配给该顾客
- AND 服务在可配置时长后完成
- AND 顾客付款并离开

#### Scenario: 防止顾客无限堆积

- WHEN 活跃顾客数量达到配置上限
- THEN 酒馆循环暂停生成新顾客
- AND 只有当活跃顾客离开或完成服务后才恢复生成

### Requirement: 基础收益持久化

桌面挂机 MVP SHALL 在顾客服务完成时发放并持久化基础进度。

#### Scenario: 完成服务奖励

- WHEN 猫猫为顾客完成服务
- THEN 游戏增加整数金币
- AND 游戏增加整数经营值
- AND HUD 根据状态变化更新
- AND 玩家看到本次销售完成的可见反馈

#### Scenario: 重启后恢复进度

- GIVEN 玩家已经获得金币或经营值
- WHEN 玩家退出并重启游戏
- THEN 已保存金币被恢复
- AND 已保存经营值被恢复
- AND 累计服务顾客数被恢复
- AND 游戏关闭期间不发放离线收益

### Requirement: MVP 范围边界

桌面挂机 MVP SHALL 排除调酒研发、今日菜单策略、抽猫、猫猫繁育、高级家具、驻演、联网涂鸦墙、长期熟客剧情和离线收益。

#### Scenario: 验证桌面挂机 MVP 范围

- WHEN 团队评估 MVP 是否完成
- THEN 验收重点是桌面存在感、三只猫猫交互、顾客服务可读性、可持久化基础收益和循环稳定性
- AND 缺少调酒策略或离线收益不阻塞 MVP 验收
