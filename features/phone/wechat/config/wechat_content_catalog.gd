extends Resource
class_name WechatContentCatalog

@export var contacts: Array[WechatContactDefinition] = []
@export var message_templates: Array[WechatMessageTemplate] = []
@export var moment_templates: Array[WechatMomentTemplate] = []
@export_range(1, 500, 1) var message_history_limit: int = 64
@export_range(1, 200, 1) var moment_history_limit: int = 32
@export_range(1, 1000, 1) var processed_event_limit: int = 128
@export_range(0, 20, 1) var initial_moment_count: int = 5
