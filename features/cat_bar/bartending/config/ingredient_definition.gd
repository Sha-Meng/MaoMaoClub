extends CatBarContentDefinition
class_name IngredientDefinition

enum Category {
	LIQUID,
	ICE,
	SPICE,
}

@export var category: Category = Category.LIQUID
@export var interaction_id: StringName = &"pour_fixed_dose"
@export var default_dose: float = 30.0
@export var maximum_stock: int = -1
@export var fluid_id: int = -1
@export var color: Color = Color.WHITE
@export var flavor_tags: Array[StringName] = []


func validate_definition() -> PackedStringArray:
	var errors := super.validate_definition()
	if interaction_id.is_empty():
		errors.append("%s: interaction_id 不能为空" % content_id)
	if default_dose <= 0.0:
		errors.append("%s: default_dose 必须大于 0" % content_id)
	if maximum_stock < -1:
		errors.append("%s: maximum_stock 必须为 -1 或非负数" % content_id)
	if category == Category.LIQUID and fluid_id < 0:
		errors.append("%s: 液体必须关联非负 fluid_id" % content_id)
	return errors


func category_id() -> StringName:
	match category:
		Category.LIQUID:
			return &"liquid"
		Category.ICE:
			return &"ice"
		Category.SPICE:
			return &"spice"
	return &"unknown"

