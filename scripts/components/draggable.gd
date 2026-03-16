extends Area2D

signal drag_started(drag_id: String)
signal drag_ended(drag_id: String)
signal dropped_on_target(drag_id: String, target_area: Area2D)

const DROP_TARGET_GROUP: StringName = &"drop_target"
const SNAP_BACK_DURATION: float = 0.2

@export var drag_id: String = ""
@export var snap_back: bool = true
@export var snap_distance: float = 40.0
@export var active: bool = true

static var _drag_owner: Node = null

var _origin_position: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _active_touch_index: int = -1
var _mouse_dragging: bool = false


func _ready() -> void:
	_origin_position = global_position
	input_pickable = true
	monitoring = true
	monitorable = true
	set_process_input(true)


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if not active:
		return

	if _dragging or (_drag_owner != null and _drag_owner != self):
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_begin_mouse_drag()
			return

	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			_begin_touch_drag(touch_event.index)


func _input(event: InputEvent) -> void:
	if not _dragging:
		return

	if _mouse_dragging and event is InputEventMouseMotion:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		global_position = _screen_to_global_position(mouse_motion.position)
		return

	if _mouse_dragging and event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			_finish_drag()
			return

	if _active_touch_index != -1 and event is InputEventScreenDrag:
		var drag_event: InputEventScreenDrag = event as InputEventScreenDrag
		if drag_event.index == _active_touch_index:
			global_position = _screen_to_global_position(drag_event.position)
			return

	if _active_touch_index != -1 and event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.index == _active_touch_index and not touch_event.pressed:
			_finish_drag()


func _on_dropped() -> void:
	if not _dragging:
		return

	var target_area: Area2D = _find_drop_target()
	if target_area != null and _can_drop_on_target(target_area):
		global_position = target_area.global_position
		_origin_position = global_position
		dropped_on_target.emit(drag_id, target_area)
		return

	_snap_back_to_origin()


func _begin_mouse_drag() -> void:
	_dragging = true
	_mouse_dragging = true
	_active_touch_index = -1
	_drag_owner = self
	drag_started.emit(drag_id)


func _begin_touch_drag(touch_index: int) -> void:
	_dragging = true
	_mouse_dragging = false
	_active_touch_index = touch_index
	_drag_owner = self
	drag_started.emit(drag_id)


func _finish_drag() -> void:
	if not _dragging:
		return

	_on_dropped()
	_dragging = false
	_mouse_dragging = false
	_active_touch_index = -1
	if _drag_owner == self:
		_drag_owner = null
	drag_ended.emit(drag_id)


func _find_drop_target() -> Area2D:
	var closest_target: Area2D = null
	var closest_distance: float = INF

	for area: Area2D in get_overlapping_areas():
		if not area.is_in_group(DROP_TARGET_GROUP):
			continue

		var distance_to_target: float = global_position.distance_to(area.global_position)
		if closest_target == null or distance_to_target < closest_distance:
			closest_target = area
			closest_distance = distance_to_target

	return closest_target


func _can_drop_on_target(target_area: Area2D) -> bool:
	if target_area == null:
		return false

	if target_area.has_method("accepts_drag_id"):
		return bool(target_area.call("accepts_drag_id", drag_id))

	if "accepted_id" in target_area:
		var accepted_id: Variant = target_area.get("accepted_id")
		if accepted_id is String and String(accepted_id) != "":
			return String(accepted_id) == drag_id

	return true


func _snap_back_to_origin() -> void:
	if not snap_back:
		return

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", _origin_position, SNAP_BACK_DURATION)


func _screen_to_global_position(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position