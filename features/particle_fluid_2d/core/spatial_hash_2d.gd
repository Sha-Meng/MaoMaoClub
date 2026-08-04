extends RefCounted
class_name SpatialHash2D

var cell_size: float = 1.0
var _buckets: Dictionary = {}
var _bucket_pool: Array[PackedInt32Array] = []

func configure(new_cell_size: float) -> void:
	assert(new_cell_size > 0.0)
	cell_size = new_cell_size
	_recycle_buckets()

func clear() -> void:
	_recycle_buckets()

func build(positions: PackedVector2Array) -> void:
	_recycle_buckets()
	for index: int in range(positions.size()):
		var cell := _cell_for(positions[index])
		var bucket: PackedInt32Array
		if _buckets.has(cell):
			bucket = _buckets[cell]
		else:
			bucket = _bucket_pool.pop_back() if not _bucket_pool.is_empty() else PackedInt32Array()
		bucket.append(index)
		_buckets[cell] = bucket

func query_indices(position: Vector2, radius: float, positions: PackedVector2Array) -> PackedInt32Array:
	var result := PackedInt32Array()
	var center := _cell_for(position)
	var cell_radius := ceili(radius / cell_size)
	var radius_squared := radius * radius
	for y_offset: int in range(-cell_radius, cell_radius + 1):
		for x_offset: int in range(-cell_radius, cell_radius + 1):
			var cell := center + Vector2i(x_offset, y_offset)
			if not _buckets.has(cell):
				continue
			var bucket: PackedInt32Array = _buckets[cell]
			for particle_index: int in bucket:
				if position.distance_squared_to(positions[particle_index]) <= radius_squared:
					result.append(particle_index)
	return result

func bucket_count() -> int:
	return _buckets.size()

func pooled_bucket_count() -> int:
	return _bucket_pool.size()

func _recycle_buckets() -> void:
	for key: Vector2i in _buckets:
		var bucket: PackedInt32Array = _buckets[key]
		bucket.clear()
		_bucket_pool.append(bucket)
	_buckets.clear()

func _cell_for(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / cell_size), floori(position.y / cell_size))
