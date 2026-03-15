extends Node2D

const ANIMATION_IDLE: StringName = &"idle"
const ANIMATION_WALKING: StringName = &"walking"

signal destination_reached(destination: Vector2)

@export var move_speed: float = 340.0
@export var arrival_threshold: float = 10.0
@export var margin_top: float = 108.0
@export var margin_bottom: float = 72.0
@export var margin_left: float = 32.0
@export var margin_right: float = 32.0

@onready var _sprite: AnimatedSprite2D = $KaySprite
@onready var _carried_flower: Sprite2D = $Position2D/Flower

var _destination: Vector2 = Vector2.ZERO
var _is_moving: bool = false
var _manual_input_enabled: bool = true
var _ignore_next_press: bool = false


func _ready() -> void:
	set_process_input(true)
	set_physics_process(true)
	_destination = global_position
	hide_carried_flower()
	_play_animation(ANIMATION_IDLE)


func _input(event: InputEvent) -> void:
	if not _manual_input_enabled:
		return

	var press_position: Variant = _extract_press_position(event)
	if press_position == null:
		return

	if _ignore_next_press:
		_ignore_next_press = false
		return

	move_to_screen_position(press_position as Vector2)


func _physics_process(delta: float) -> void:
	if not _is_moving:
		return

	_update_facing_direction(_destination - global_position)
	global_position = global_position.move_toward(_destination, move_speed * delta)

	if global_position.distance_to(_destination) > arrival_threshold:
		return

	global_position = _destination
	_complete_movement(true)


func move_to_screen_position(screen_position: Vector2) -> void:
	move_to_global_position(_screen_to_global_position(screen_position))


func move_to_global_position(target_position: Vector2) -> void:
	_destination = _clamp_to_margins(target_position)
	if global_position.distance_to(_destination) <= arrival_threshold:
		global_position = _destination
		_complete_movement(true)
		return

	_is_moving = true
	_update_facing_direction(_destination - global_position)
	_play_animation(ANIMATION_WALKING)


func stop() -> void:
	_complete_movement(false)


func set_manual_input_enabled(is_enabled: bool) -> void:
	_manual_input_enabled = is_enabled


func consume_next_press() -> void:
	_ignore_next_press = true


func show_carried_flower(flower_texture: Texture2D, carried_scale: Vector2 = Vector2.ONE) -> void:
	if _carried_flower == null:
		return

	_carried_flower.texture = flower_texture
	_carried_flower.hframes = 1
	_carried_flower.vframes = 1
	_carried_flower.scale = carried_scale
	_carried_flower.visible = flower_texture != null


func hide_carried_flower() -> void:
	if _carried_flower == null:
		return

	_carried_flower.visible = false


func _complete_movement(emit_arrival: bool) -> void:
	var reached_destination: Vector2 = _destination
	_destination = global_position
	_is_moving = false
	_play_animation(ANIMATION_IDLE)
	if emit_arrival:
		destination_reached.emit(reached_destination)


func is_moving() -> bool:
	return _is_moving


func _clamp_to_margins(target_position: Vector2) -> Vector2:
	var viewport_rect: Rect2 = get_viewport_rect()
	var top_left: Vector2 = _screen_to_global_position(viewport_rect.position)
	var bottom_right: Vector2 = _screen_to_global_position(viewport_rect.position + viewport_rect.size)
	var min_bounds: Vector2 = Vector2(
		minf(top_left.x, bottom_right.x) + margin_left,
		minf(top_left.y, bottom_right.y) + margin_top
	)
	var max_bounds: Vector2 = Vector2(
		maxf(top_left.x, bottom_right.x) - margin_right,
		maxf(top_left.y, bottom_right.y) - margin_bottom
	)
	return Vector2(
		clampf(target_position.x, min_bounds.x, max_bounds.x),
		clampf(target_position.y, min_bounds.y, max_bounds.y)
	)


func _screen_to_global_position(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position


func _extract_press_position(event: InputEvent) -> Variant:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			return mouse_event.position

	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			return touch_event.position

	return null


func _update_facing_direction(direction: Vector2) -> void:
	if absf(direction.x) <= 0.01:
		return

	scale.x = absf(scale.x) * signf(direction.x)


func _play_animation(animation_name: StringName) -> void:
	if _sprite == null:
		return

	if not _sprite.sprite_frames.has_animation(animation_name):
		push_warning("ProtagonistActor nao encontrou animacao '%s'." % String(animation_name))
		return

	if _sprite.animation == animation_name and _sprite.is_playing():
		return

	_sprite.play(animation_name)
