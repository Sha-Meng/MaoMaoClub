extends Node2D
class_name PatronAmbienceActor

enum State { INACTIVE, ENTERING, SEATED, DRINKING, LEAVING }

var visitor_id: int = 0
var prototype_id: StringName = &""
var seat_id: StringName = &""
var state: State = State.INACTIVE
var elapsed_seconds: float = 0.0
var stay_seconds: float = 0.0
var body_color: Color = Color.WHITE
var character_texture: Texture2D


func activate(id: int, prototype: PatronPrototype, leased_seat_id: StringName, seat_position: Vector2, duration: float) -> void:
	visitor_id = id
	prototype_id = prototype.patron_id
	seat_id = leased_seat_id
	position = seat_position.round()
	stay_seconds = duration
	elapsed_seconds = 0.0
	body_color = prototype.body_color
	character_texture = prototype.character_texture
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	state = State.ENTERING
	visible = true
	queue_redraw()


func advance(delta_seconds: float) -> bool:
	elapsed_seconds += maxf(delta_seconds, 0.0)
	if elapsed_seconds >= stay_seconds + 0.2:
		return true
	if elapsed_seconds >= stay_seconds:
		state = State.LEAVING
	elif elapsed_seconds >= 0.5:
		state = State.DRINKING
	elif elapsed_seconds >= 0.2:
		state = State.SEATED
	queue_redraw()
	return false


func deactivate() -> void:
	visitor_id = 0
	prototype_id = &""
	seat_id = &""
	state = State.INACTIVE
	elapsed_seconds = 0.0
	stay_seconds = 0.0
	character_texture = null
	visible = false
	queue_redraw()


func _draw() -> void:
	if state == State.INACTIVE:
		return
	if character_texture != null:
		draw_texture_rect(character_texture, Rect2(Vector2(-31.0, -49.0), Vector2(62.0, 62.0)), false)
		return
	draw_circle(Vector2.ZERO, 11.0, body_color)
	draw_circle(Vector2(-4, -2), 1.5, Color("1e1820"))
	draw_circle(Vector2(4, -2), 1.5, Color("1e1820"))
	draw_line(Vector2(-7, 10), Vector2(7, 10), Color("46303a"), 4.0)
