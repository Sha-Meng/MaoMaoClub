extends Resource
class_name WechatMessageTemplate

@export var template_id: StringName = &""
@export var author_ids: Array[StringName] = []
@export var trigger_tags: Array[StringName] = []
@export_range(1, 100, 1) var weight: int = 1
@export_multiline var text: String = ""
@export_range(0, 100, 1) var cooldown_events: int = 0
@export var mutex_key: StringName = &""

