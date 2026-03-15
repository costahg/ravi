extends Area2D

signal pressed(hotspot_id: String)

const FEEDBACK_MODULATE: Color = Color(1.1, 1.1, 1.1, 1.0)

@export var hotspot_id: String = ""
@export var one_shot: bool = true
@export var active: bool = true:
	set(value):
		active = value
		if not active:
			_clear_feedback_state()

var _visual_parent: CanvasItem
var _mouse_hovering: bool = false
var _touch_hovering: bool = false
var _active_touch_index: int = -1
var _feedback_applied: bool = false
var _base_parent_modulate: Color = Color.WHITE


func _ready() -> void:
	var parent_node: Node = get_parent()
	if parent_node is CanvasItem:
		_visual_parent = parent_node as CanvasItem

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	set_process_input(true)


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if not active:
		return

	var is_mouse_press: bool = false
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		is_mouse_press = mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed

	var is_touch_press: bool = false
	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		is_touch_press = touch_event.pressed
		if touch_event.pressed:
			_active_touch_index = touch_event.index
			_touch_hovering = true
			_refresh_feedback()

	if not is_mouse_press and not is_touch_press:
		return

	pressed.emit(hotspot_id)

	if one_shot:
		active = false


func _input(event: InputEvent) -> void:
	if _active_touch_index == -1:
		return

	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.index != _active_touch_index:
			return

		if not touch_event.pressed:
			_touch_hovering = false
			_active_touch_index = -1
			_refresh_feedback()
			return

	if event is InputEventScreenDrag:
		var drag_event: InputEventScreenDrag = event as InputEventScreenDrag
		if drag_event.index != _active_touch_index:
			return

		_touch_hovering = _contains_global_point(drag_event.position)
		_refresh_feedback()


func _on_mouse_entered() -> void:
	if not active:
		return
	_mouse_hovering = true
	_refresh_feedback()


func _on_mouse_exited() -> void:
	_mouse_hovering = false
	_refresh_feedback()


func _refresh_feedback() -> void:
	if _visual_parent == null:
		return

	var should_highlight: bool = active and (_mouse_hovering or _touch_hovering)
	if should_highlight:
		if _feedback_applied:
			return

		_base_parent_modulate = _visual_parent.modulate
		_visual_parent.modulate = Color(
			_base_parent_modulate.r * FEEDBACK_MODULATE.r,
			_base_parent_modulate.g * FEEDBACK_MODULATE.g,
			_base_parent_modulate.b * FEEDBACK_MODULATE.b,
			_base_parent_modulate.a * FEEDBACK_MODULATE.a
		)
		_feedback_applied = true
		return

	if not _feedback_applied:
		return

	_visual_parent.modulate = _base_parent_modulate
	_feedback_applied = false


func _clear_feedback_state() -> void:
	_mouse_hovering = false
	_touch_hovering = false
	_active_touch_index = -1
	_refresh_feedback()


func _contains_global_point(point: Vector2) -> bool:
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = collision_layer

	var results: Array[Dictionary] = get_world_2d().direct_space_state.intersect_point(query)
	for result: Dictionary in results:
		if result.get("collider") == self:
			return true

	return false
