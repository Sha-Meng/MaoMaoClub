extends Node2D
## 不使用正式营业场景或持久化服务。

var player: ManagerAnimationPlayer = ManagerAnimationPlayer.new()
var atlas: Texture2D = preload("res://assets/tavern/manager_authored/manager_atlas.png")
var font: SystemFont = SystemFont.new()
var clock_time: float = 0.0
var automatic: bool = true
var paused: bool = false
var dark: bool = false
var held_choice: bool = false
var playback_speed: float = 1.0
var manual_direction: int = 0
var capture_mode: bool = false


func _ready() -> void:
	font.font_names = PackedStringArray(["Microsoft YaHei UI"])
	if not capture_mode:
		var window: Window = get_window()
		window.title = "MaoMaoClub · 店长交替步态验证"
		window.always_on_top = false
		window.borderless = false
		window.transparent = false
		window.transparent_bg = false
		window.content_scale_size = Vector2i(1120, 720)
		window.size = Vector2i(1120, 720)
		window.position = Vector2i(120, 80)
	Engine.max_fps = 30
	_add_controls()
	queue_redraw()


func _add_controls() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.position = Vector2(32, 660)
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	_button(row, "自动演示", func() -> void: automatic = true)
	_button(row, "向左", func() -> void: _manual(-1))
	_button(row, "停步", func() -> void: _manual(0))
	_button(row, "向右", func() -> void: _manual(1))
	_button(row, "空手 / 持杯", func() -> void:
		held_choice = not held_choice
		automatic = false
		player.request_motion(manual_direction, held_choice))
	_button(row, "暂停 / 继续", func() -> void: paused = not paused)
	_button(row, "0.5× / 1×", func() -> void: playback_speed = 0.5 if playback_speed == 1.0 else 1.0)
	_button(row, "浅底 / 深底", func() -> void: dark = not dark)


func _button(row: HBoxContainer, title: String, callback: Callable) -> void:
	var button: Button = Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(96, 34)
	button.pressed.connect(callback)
	row.add_child(button)


func _manual(direction: int) -> void:
	automatic = false
	manual_direction = direction
	player.request_motion(direction, held_choice)


func _process(delta: float) -> void:
	if not capture_mode:
		advance_demo(delta)


func advance_demo(delta: float) -> void:
	if not paused:
		var step: float = delta * playback_speed
		if automatic:
			clock_time += step
			var phase: float = fposmod(clock_time, 11.0)
			var direction: int = 1 if phase >= 1.0 and phase < 3.8 else (-1 if phase >= 6.0 and phase < 8.8 else 0)
			player.request_motion(direction, phase >= 5.3 and phase < 10.5)
		player.advance(step)
	queue_redraw()


func _draw() -> void:
	var bg: Color = Color("202a30") if dark else Color("f3efe5")
	var card: Color = Color("2c3840") if dark else Color("fffdf6")
	var ink: Color = Color("e8e0cd") if dark else Color("3f4941")
	var muted: Color = Color("a4b7b4") if dark else Color("768077")
	draw_rect(Rect2(0, 0, 1120, 720), bg)
	draw_string(font, Vector2(32, 44), "CAT CLUB  /  店长动作验证", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, ink)
	draw_string(font, Vector2(32, 76), "Blender 分层骨骼与关键帧  →  透明动画图集  →  Godot 4.6.3", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, muted)
	draw_rect(Rect2(28, 98, 1064, 174), card)
	draw_rect(Rect2(28, 286, 1064, 350), card)
	draw_string(font, Vector2(48, 126), "常驻大小 · 约 88 px", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
	draw_string(font, Vector2(48, 316), "2.5 倍观察 · 关节连接 / 脚步交替 / 酒杯跟手", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
	var x: float = fposmod(player.position_x + 80.0, 200.0) - 80.0
	_draw_actor(Vector2(430 + x, 246), 1.0)
	_draw_actor(Vector2(430 + x * 2.5, 609), 2.5)
	draw_line(Vector2(48, 246), Vector2(1072, 246), muted, 1.0)
	draw_line(Vector2(48, 609), Vector2(1072, 609), muted, 1.0)
	var labels: Dictionary = {"idle": "站立", "start": "起步", "walk": "行走", "stop": "停步"}
	draw_string(font, Vector2(780, 165), str(labels[player.clip]) + (" · 持杯" if player.held else " · 空手"), HORIZONTAL_ALIGNMENT_LEFT, -1, 21, ink)
	draw_string(font, Vector2(780, 195), ("向右" if player.facing > 0 else "向左") + "  /  %s×" % playback_speed, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, muted)
	draw_string(font, Vector2(780, 224), "前后交替 · 近腿在前", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, muted)


func _draw_actor(ground: Vector2, zoom: float) -> void:
	var size: Vector2 = Vector2(float(player.data["cell"][0]), float(player.data["cell"][1])) / float(player.data["scale"])
	var origin: Vector2 = Vector2(float(player.data["origin"][0]), float(player.data["origin"][1])) / float(player.data["scale"])
	draw_set_transform(ground, 0.0, Vector2(player.facing * zoom, zoom))
	draw_texture_rect_region(atlas, Rect2(-origin, size), player.source_rect())
	draw_set_transform(Vector2.ZERO)
