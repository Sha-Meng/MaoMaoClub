extends SceneTree


func _init() -> void:
	var validator := CatBarAssetValidator.new()
	var errors := validator.validate()
	var content_errors := CatBarContentValidator.new().validate(
		preload("res://features/cat_bar/bartending/configs/default_content_catalog.tres"),
		InteractionExecutorRegistry.new().strategy_ids()
	)
	errors.append_array(content_errors)
	var counts := validator.summary()
	print("CatBar asset validation: placeholders=%d release_ready=%d reference_only=%d errors=%d" % [counts.placeholder, counts.release_ready, counts.reference_only, errors.size()])
	for error: String in errors:
		push_error(error)
	quit(0 if errors.is_empty() else 1)
