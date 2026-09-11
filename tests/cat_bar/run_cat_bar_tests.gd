extends SceneTree

const CONTENT_REGISTRY_TESTS := preload("res://tests/cat_bar/unit/test_content_registry.gd")
const DEFAULT_CONTENT_TESTS := preload("res://tests/cat_bar/unit/test_default_content.gd")
const BARTENDING_SESSION_TESTS := preload("res://tests/cat_bar/unit/test_bartending_session.gd")
const MIXING_VESSEL_ADAPTER_TESTS := preload("res://tests/cat_bar/integration/test_mixing_vessel_adapter.gd")
const BARTENDING_STATION_TESTS := preload("res://tests/cat_bar/integration/test_bartending_station.gd")
const CAT_BAR_SCENE_TESTS := preload("res://tests/cat_bar/integration/test_cat_bar_scene.gd")
const CAT_BAR_SERVICE_LOOP_TESTS := preload("res://tests/cat_bar/integration/test_cat_bar_service_loop.gd")
const PATRON_AMBIENCE_TESTS := preload("res://tests/cat_bar/unit/test_patron_ambience.gd")
const WECHAT_DOMAIN_TESTS := preload("res://tests/phone_wechat/test_wechat_domain.gd")
const PHONE_WECHAT_UI_TESTS := preload("res://tests/phone_wechat/test_phone_wechat_ui.gd")
const SAVE_V2_TESTS := preload("res://tests/cat_bar/unit/test_save_v2.gd")
const ASSET_MANIFEST_TESTS := preload("res://tests/cat_bar/unit/test_asset_manifest.gd")
const MAIN_ASSEMBLY_TESTS := preload("res://tests/cat_bar/unit/test_main_assembly.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var suite := CatBarTestSuite.new()
	CONTENT_REGISTRY_TESTS.new().run(suite)
	DEFAULT_CONTENT_TESTS.new().run(suite)
	BARTENDING_SESSION_TESTS.new().run(suite)
	PATRON_AMBIENCE_TESTS.new().run(suite)
	WECHAT_DOMAIN_TESTS.new().run(suite)
	SAVE_V2_TESTS.new().run(suite)
	ASSET_MANIFEST_TESTS.new().run(suite)
	MAIN_ASSEMBLY_TESTS.new().run(suite)
	await MIXING_VESSEL_ADAPTER_TESTS.new().run(suite, self)
	await BARTENDING_STATION_TESTS.new().run(suite, self)
	await CAT_BAR_SCENE_TESTS.new().run(suite, self)
	await CAT_BAR_SERVICE_LOOP_TESTS.new().run(suite, self)
	await PHONE_WECHAT_UI_TESTS.new().run(suite, self)
	print("CatBar tests: %d passed, %d failed" % [suite.passed, suite.failed])
	for failure: String in suite.failures:
		print("  - %s" % failure)
	quit(0 if suite.failed == 0 else 1)
