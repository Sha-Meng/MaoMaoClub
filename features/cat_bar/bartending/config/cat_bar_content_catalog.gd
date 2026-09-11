extends Resource
class_name CatBarContentCatalog

@export var tools: Array[ToolDefinition] = []
@export var ingredients: Array[IngredientDefinition] = []
@export var glasses: Array[GlassDefinition] = []
@export var interactions: Array[InteractionDefinition] = []
@export var recipes: Array[RecipeDefinition] = []
@export var station_layout: StationLayoutDefinition
@export var deprecated_ids: Dictionary[StringName, StringName] = {}

