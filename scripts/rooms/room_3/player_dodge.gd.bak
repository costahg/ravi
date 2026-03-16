extends "res://scripts/components/protagonist_actor.gd"

signal hit

const PROJECTILE_GROUP: StringName = &"projectile"

@onready var _hitbox: Area2D = $Hitbox

var _active_touch_index: int = -1
var _last_global_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	super._ready()
	_last_global_position = global_position
	_connect_hitbox()


func _input(event: InputEvent) -> void:
	if not _manual_input_enabled:
		return

	if event is InputEventMouseMotion:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		_follow_screen_position(mouse_motion.position)
		return

	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			_follow_screen_position(mouse_button.position)
		return

	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed and (_active_touch_index == -1 or _active_touch_index == touch_event.index):
			_active_touch_index = touch_event.index
			_follow_screen_position(touch_event.position)
			return

		if not touch_event.pressed and touch_event.index == _active_touch_index:
			_active_touch_index = -1
		return

	if event is InputEventScreenDrag:
		var drag_event: InputEventScreenDrag = event as InputEventScreenDrag
		if _active_touch_index == -1:
			_active_touch_index = drag_event.index

		if drag_event.index == _active_touch_index:
			_follow_screen_position(drag_event.position)


func _physics_process(_delta: float) -> void:
	var movement_delta: Vector2 = global_position - _last_global_position
	if movement_delta.length_squared() > 0.01:
		_update_facing_direction(movement_delta)
		_play_animation(ANIMATION_WALKING)
	else:
		_play_animation(ANIMATION_IDLE)

	_last_global_position = global_position


func _connect_hitbox() -> void:
	if _hitbox == null:
		push_warning("PlayerDodge nao encontrou o node Hitbox na protagonista da Sala 3.")
		return

	var on_area_entered: Callable = Callable(self, "_on_hitbox_area_entered")
	if not _hitbox.is_connected("area_entered", on_area_entered):
		_hitbox.connect("area_entered", on_area_entered)


func _follow_screen_position(screen_position: Vector2) -> void:
	global_position = _clamp_to_margins(_screen_to_global_position(screen_position))
	_destination = global_position
	_is_moving = false


func _on_hitbox_area_entered(area: Area2D) -> void:
	if area == null:
		return

	if not area.is_in_group(PROJECTILE_GROUP):
		return

	hit.emit()
