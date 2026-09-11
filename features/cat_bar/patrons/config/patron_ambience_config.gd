extends Resource
class_name PatronAmbienceConfig

@export var prototypes: Array[PatronPrototype] = []
@export var seats: Array[PatronSeatDefinition] = []
@export_range(0.1, 120.0, 0.1) var spawn_interval_seconds: float = 3.0
@export_range(0.1, 600.0, 0.1) var stay_seconds: float = 9.0
@export_range(1, 32, 1) var max_active: int = 4
@export var random_seed: int = 20260903

