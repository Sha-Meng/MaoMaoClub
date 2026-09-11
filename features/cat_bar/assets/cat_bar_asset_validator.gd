extends RefCounted
class_name CatBarAssetValidator

const MANIFEST_PATH := "res://assets/cat_bar/asset_manifest.json"
const CONTENT_CATALOG: CatBarContentCatalog = preload("res://features/cat_bar/bartending/configs/default_content_catalog.tres")
const WECHAT_CATALOG: WechatContentCatalog = preload("res://features/phone/wechat/configs/default_wechat_catalog.tres")
const VALID_CATEGORIES := [&"environment", &"characters", &"tools", &"ingredients", &"glassware", &"ui", &"wechat", &"reference"]
const VALID_STATUSES := [&"placeholder", &"reference_only", &"release_ready"]

var placeholder_count: int = 0
var release_ready_count: int = 0
var reference_count: int = 0


func validate() -> PackedStringArray:
	placeholder_count = 0
	release_ready_count = 0
	reference_count = 0
	var errors := PackedStringArray()
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return PackedStringArray(["资产清单不存在：%s" % MANIFEST_PATH])
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return PackedStringArray(["资产清单不是合法 JSON 对象"])
	var manifest: Dictionary = parsed
	_validate_import_policy(manifest.get("pixel_import", {}), errors)
	var entries: Variant = manifest.get("entries", [])
	if not entries is Array:
		return PackedStringArray(["资产清单 entries 必须为数组"])
	var by_id: Dictionary[StringName, Dictionary] = {}
	for index: int in range(entries.size()):
		if not entries[index] is Dictionary:
			errors.append("entries[%d] 不是对象" % index)
			continue
		_validate_entry(entries[index], by_id, errors)
	_validate_content_references(by_id, errors)
	_validate_wechat_references(by_id, errors)
	return errors


func summary() -> Dictionary:
	return {"placeholder": placeholder_count, "release_ready": release_ready_count, "reference_only": reference_count}


func _validate_import_policy(policy: Variant, errors: PackedStringArray) -> void:
	if not policy is Dictionary or bool(policy.get("filter", true)) or bool(policy.get("mipmaps", true)) or not bool(policy.get("integer_grid", false)):
		errors.append("像素导入策略必须关闭过滤/mipmap 并启用整数网格")


func _validate_entry(entry: Dictionary, by_id: Dictionary[StringName, Dictionary], errors: PackedStringArray) -> void:
	var asset_id := StringName(entry.get("id", ""))
	if asset_id.is_empty() or by_id.has(asset_id):
		errors.append("资产 ID 为空或重复：%s" % asset_id)
		return
	by_id[asset_id] = entry
	var category := StringName(entry.get("category", ""))
	var status := StringName(entry.get("status", ""))
	if not VALID_CATEGORIES.has(category):
		errors.append("%s: 未知分类 %s" % [asset_id, category])
	if not VALID_STATUSES.has(status):
		errors.append("%s: 未知状态 %s" % [asset_id, status])
	if String(entry.get("source", "")).is_empty() or String(entry.get("author", "")).is_empty() or String(entry.get("license", "")).is_empty():
		errors.append("%s: 来源、作者和许可必须完整" % asset_id)
	var runtime_path := String(entry.get("runtime_path", ""))
	if status == &"reference_only":
		reference_count += 1
		if not runtime_path.is_empty() or bool(entry.get("publish_allowed", true)):
			errors.append("%s: reference_only 不得有运行时路径或发布许可" % asset_id)
	else:
		if not runtime_path.begins_with("res://assets/cat_bar/%s/" % category) or not FileAccess.file_exists(runtime_path):
			errors.append("%s: 运行时文件缺失或分类路径不符：%s" % [asset_id, runtime_path])
		if status == &"placeholder":
			placeholder_count += 1
		else:
			release_ready_count += 1
	_validate_geometry(asset_id, entry, errors)
	if category == &"characters" and status != &"reference_only":
		_validate_character_atlas(asset_id, entry, runtime_path, errors)


func _validate_geometry(asset_id: StringName, entry: Dictionary, errors: PackedStringArray) -> void:
	var size: Array = entry.get("size", [])
	var frame: Array = entry.get("frame_size", [])
	var anchor: Array = entry.get("anchor", [])
	if size.size() != 2 or frame.size() != 2 or anchor.size() != 2:
		errors.append("%s: 尺寸、帧尺寸或锚点格式错误" % asset_id)
		return
	if int(frame[0]) <= 0 or int(frame[1]) <= 0 or int(size[0]) % int(frame[0]) != 0 or int(size[1]) % int(frame[1]) != 0:
		errors.append("%s: 图集尺寸不是帧尺寸整数倍" % asset_id)
	if int(anchor[0]) < 0 or int(anchor[1]) < 0 or int(anchor[0]) > int(frame[0]) or int(anchor[1]) > int(frame[1]):
		errors.append("%s: 锚点超出单帧范围" % asset_id)


func _validate_character_atlas(asset_id: StringName, entry: Dictionary, runtime_path: String, errors: PackedStringArray) -> void:
	var roles: Array = entry.get("roles", [])
	var frames := int(entry.get("frames", 0))
	if roles.size() != frames or roles.size() < 1:
		errors.append("%s: 角色槽位数量必须与帧数一致" % asset_id)
	var unique_roles: Dictionary[StringName, bool] = {}
	for role_value: Variant in roles:
		var role := StringName(role_value)
		if role.is_empty() or unique_roles.has(role):
			errors.append("%s: 角色槽位为空或重复：%s" % [asset_id, role])
		continue
		unique_roles[role] = true
	if not bool(entry.get("alpha_required", false)) or not FileAccess.file_exists(runtime_path):
		errors.append("%s: 角色图集必须声明并提供透明背景" % asset_id)
		return
	var image := Image.new()
	var load_error := image.load(ProjectSettings.globalize_path(runtime_path))
	if load_error != OK or image.detect_alpha() == Image.ALPHA_NONE:
		errors.append("%s: 角色图集没有可用 alpha 通道" % asset_id)


func _validate_content_references(by_id: Dictionary[StringName, Dictionary], errors: PackedStringArray) -> void:
	for collection: Array in [CONTENT_CATALOG.tools, CONTENT_CATALOG.ingredients, CONTENT_CATALOG.glasses, CONTENT_CATALOG.recipes]:
		for definition: CatBarContentDefinition in collection:
			if not by_id.has(definition.asset_id):
				errors.append("内容 %s 引用未知资产 %s" % [definition.content_id, definition.asset_id])


func _validate_wechat_references(by_id: Dictionary[StringName, Dictionary], errors: PackedStringArray) -> void:
	for contact: WechatContactDefinition in WECHAT_CATALOG.contacts:
		for definition_error: String in contact.validate_definition():
			errors.append("联系人 %s: %s" % [contact.contact_id, definition_error])
		if not by_id.has(contact.avatar_id):
			errors.append("联系人 %s 引用未知头像 %s" % [contact.contact_id, contact.avatar_id])
	for template: WechatMomentTemplate in WECHAT_CATALOG.moment_templates:
		for image_id: StringName in template.image_ids:
			if not by_id.has(image_id):
				errors.append("朋友圈模板 %s 引用未知图片 %s" % [template.template_id, image_id])
