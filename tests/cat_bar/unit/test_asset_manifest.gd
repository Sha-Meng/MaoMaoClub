extends RefCounted


func run(suite: CatBarTestSuite) -> void:
	suite.run_case("CatBar 资产清单、交叉引用与参考图隔离", _test_manifest.bind(suite))


func _test_manifest(suite: CatBarTestSuite) -> void:
	var validator := CatBarAssetValidator.new()
	var errors := validator.validate()
	suite.expect_equal(errors.size(), 0, "默认资产清单应通过聚合校验：%s" % errors)
	var counts := validator.summary()
	suite.expect_true(int(counts["placeholder"]) > 0, "开发清单应显式统计占位素材")
	suite.expect_equal(counts["reference_only"], 1, "需求附图应且仅应登记为一条 reference_only")
	var atlas := load("res://assets/cat_bar/characters/cat_roles_atlas_generated.png") as Texture2D
	suite.expect_true(atlas != null, "统一猫角色图集应可由 Godot 加载")
	suite.expect_equal(atlas.get_size(), Vector2(1254.0, 1254.0), "角色图集尺寸应满足 2x2 槽位契约")
