extends RefCounted

const DEFAULT_CATALOG := preload("res://features/cat_bar/bartending/configs/default_content_catalog.tres")
const STRATEGY_IDS: Array[StringName] = [
	&"pour_fixed_dose",
	&"drop_ice",
	&"sprinkle",
	&"measure",
	&"stir_drag",
	&"seal_toggle",
	&"shake_drag",
	&"strain_pour",
]


func run(suite: CatBarTestSuite) -> void:
	suite.run_case("默认 CatBar 内容配表完整", _test_default_catalog.bind(suite))


func _test_default_catalog(suite: CatBarTestSuite) -> void:
	var catalog := DEFAULT_CATALOG as CatBarContentCatalog
	suite.expect_true(catalog != null, "默认内容目录必须可加载")
	if catalog == null:
		return
	var errors := CatBarContentValidator.new().validate(catalog, STRATEGY_IDS)
	suite.expect_equal(errors.size(), 0, "默认内容目录必须通过完整校验")
	var registry := CatBarContentRegistry.new()
	registry.build(catalog)
	var counts := registry.counts()
	suite.expect_equal(counts[&"tools"], 3, "首批应有三个器具")
	suite.expect_equal(counts[&"ingredients"], 9, "默认内容应有五种基酒、三种吧台辅料和一种动物掉落物")
	suite.expect_equal(counts[&"glasses"], 1, "首批应有一个目标酒杯")
	suite.expect_equal(counts[&"interactions"], 8, "首批应覆盖八种交互")
	suite.expect_equal(counts[&"recipes"], 1, "首批应有一个代表性配方")
	suite.expect_equal(catalog.station_layout.zones.size(), 5, "工作台应有五个陈列分区")
	suite.expect_true(registry.get_ingredient(&"moon_gin").icon_texture != null, "月光金酒必须绑定瓶身纹理")
	suite.expect_true(registry.get_ingredient(&"dusk_liqueur").icon_texture != null, "暮色甜酒必须绑定不同瓶身纹理")
	suite.expect_true(registry.get_tool(&"bar_spoon").icon_texture != null, "长柄勺必须绑定拖拽纹理")
	suite.expect_true(registry.get_ingredient(&"moon_gin").icon_texture != registry.get_ingredient(&"dusk_liqueur").icon_texture, "两种酒液不得共用同一瓶身纹理")
	for content_id: StringName in [&"sunset_whiskey", &"dawn_vodka", &"daybreak_white_rum", &"clear_ice", &"catnip_spice", &"premium_fish_oil"]:
		var ingredient := registry.get_ingredient(content_id)
		suite.expect_true(ingredient != null, "扩展内容缺少 %s" % content_id)
		if ingredient != null:
			suite.expect_true(ingredient.icon_texture != null, "%s 必须绑定菜单图片" % content_id)
	for tool_id: StringName in [&"shaker", &"jigger", &"bar_spoon"]:
		suite.expect_true(registry.get_tool(tool_id).icon_texture != null, "%s 必须绑定菜单图片" % tool_id)
