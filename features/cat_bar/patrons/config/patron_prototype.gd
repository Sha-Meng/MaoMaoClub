extends Resource
class_name PatronPrototype

@export var patron_id: StringName = &""
@export var display_name: String = "顾客"
@export var body_color: Color = Color("a98ac2")
@export var character_texture: Texture2D
@export var animation_variants: PackedStringArray = ["sit", "sip", "chat"]
