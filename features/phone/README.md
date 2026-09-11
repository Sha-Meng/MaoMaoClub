# 手机功能目录

该目录包含屏幕空间手机壳层及各应用功能。`shell/` 只管理入口、返回栈和角标；`wechat/` 独立拥有联系人、消息、朋友圈与确定性生成状态。

`PhoneShell` 使用独立 CanvasLayer，未开放应用只显示反馈，不压入空白页面。微信 UI 只读取 `WechatService` 已生成的实例；切页、关闭和重新打开不会触发随机生成。

扩展微信内容时，在 `wechat/configs/default_wechat_catalog.tres` 增加稳定联系人/模板 ID。联系人必须配置简介、兴趣、爱好、人格、回复风格、口头禅，以及问候/提问/兴趣/普通回复语料；消息和朋友圈模板配置作者、事件标签、权重、冷却与互斥键。外围内容生成器由保存的 seed、cursor 和事件顺序决定；聊天使用独立消息序列，不改变下一条外围随机内容。头像与朋友圈图必须先登记到 CatBar 资产清单。

手机与微信共用 `presentation/phone_pixel_theme.gd` 的暖暗像素主题。新增控件优先复用该样式工厂，业务逻辑不得依赖具体颜色或 StyleBox。

外围系统通过 `consume_event(unique_event_id, event_tag, unlock_contact_id)` 写入微信。事件 ID 必须全局稳定且唯一；重复 ID 会被忽略。历史容量由 catalog 控制，存档恢复会过滤未知联系人和缺失图片。
