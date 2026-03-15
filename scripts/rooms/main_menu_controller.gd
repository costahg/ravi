extends Node2D

const DOOR_UNLOCKED_MODULATE: Color = Color(1.0, 1.0, 1.0, 1.0)
const DOOR_BLOCKED_MODULATE: Color = Color(0.72, 0.78, 0.88, 0.95)
const DOOR_COMPLETED_MODULATE: Color = Color(0.48, 0.5, 0.56, 0.8)
const HIGHLIGHT_HOVER_MODULATE: Color = Color(1.2, 1.2, 1.2, 1.0)
const HIGHLIGHTS_SPRITESHEET: Texture2D = preload("res://assets/sprites/MainRoomHighlights.png")
const HIGHLIGHTS_FRAME_SIZE: Vector2 = Vector2(1024.0, 1536.0)
const HIGHLIGHTS_FRAME_BY_ROOM_ID: Dictionary = {
	1: 2,
	2: 3,
	3: 0,
	4: 1,
}
const BLOCKED_FOG_BASE_MODULATE: Color = Color(1.0, 1.0, 1.0, 0.8)
const BLOCKED_FOG_FLASH_MODULATE: Color = Color(1.0, 1.0, 1.0, 1.0)
const BLOCKED_FEEDBACK_DURATION: float = 0.12
const HOTSPOT_TO_ROOM_ID: Dictionary = {
	"door_1": 1,
	"door_2": 2,
	"door_3": 3,
	"door_4": 4,
}

@export var protagonist_move_speed: float = 340.0
@export var protagonist_arrival_threshold: float = 10.0
@export var protagonist_margin_top: float = 108.0
@export var protagonist_margin_bottom: float = 72.0
@export var protagonist_margin_left: float = 32.0
@export var protagonist_margin_right: float = 32.0

@onready var _door_1: Control = $CanvasLayer/Doors/Door1
@onready var _door_2: Control = $CanvasLayer/Doors/Door2
@onready var _door_3: Control = $CanvasLayer/Doors/Door3
@onready var _door_4: Control = $CanvasLayer/Doors/Door4
@onready var _highlights: TextureRect = get_node_or_null("CanvasLayer/Highlights") as TextureRect
@onready var _protagonist: Node2D = $CanvasLayer/Protagonist

@onready var _door_1_fog: ColorRect = get_node_or_null("CanvasLayer/Doors/Door1/Fog") as ColorRect
@onready var _door_2_fog: ColorRect = get_node_or_null("CanvasLayer/Doors/Door2/Fog") as ColorRect
@onready var _door_3_fog: ColorRect = get_node_or_null("CanvasLayer/Doors/Door3/Fog") as ColorRect
@onready var _door_4_fog: ColorRect = get_node_or_null("CanvasLayer/Doors/Door4/Fog") as ColorRect

var _door_state_by_room: Dictionary = {}
var _highlight_textures_by_room: Dictionary = {}
var _blocked_feedback_tweens: Dictionary = {}
var _hovered_room_id: int = 0
var _pending_room_id: int = 0
var _skip_next_global_press: bool = false


func _ready() -> void:
	_build_highlight_textures()
	_connect_door_hotspots()
	_configure_protagonist()
	_connect_protagonist()
	_refresh_doors_state()


func _refresh_doors_state() -> void:
	var next_room_to_unlock: int = GameManager.get_next_room_to_unlock()

	_door_state_by_room = {
		1: _build_room_state(1, next_room_to_unlock),
		2: _build_room_state(2, next_room_to_unlock),
		3: _build_room_state(3, next_room_to_unlock),
		4: _build_room_state(4, next_room_to_unlock),
	}

	_apply_door_state(_door_1, _door_1_fog, _door_state_by_room[1])
	_apply_door_state(_door_2, _door_2_fog, _door_state_by_room[2])
	_apply_door_state(_door_3, _door_3_fog, _door_state_by_room[3])
	_apply_door_state(_door_4, _door_4_fog, _door_state_by_room[4])
	_set_default_highlight(next_room_to_unlock)


func _build_room_state(room_id: int, next_room_to_unlock: int) -> Dictionary:
	var is_completed: bool = GameManager.rooms_completed.get(room_id, false)
	var is_unlocked_now: bool = room_id == next_room_to_unlock and not is_completed

	return {
		"is_completed": is_completed,
		"is_unlocked_now": is_unlocked_now,
		"is_blocked": not is_completed and not is_unlocked_now,
	}


func _build_highlight_textures() -> void:
	_highlight_textures_by_room.clear()

	for room_id_variant in HIGHLIGHTS_FRAME_BY_ROOM_ID.keys():
		var room_id: int = room_id_variant
		var frame_index: int = HIGHLIGHTS_FRAME_BY_ROOM_ID[room_id]
		var atlas_texture: AtlasTexture = AtlasTexture.new()
		atlas_texture.atlas = HIGHLIGHTS_SPRITESHEET
		atlas_texture.region = Rect2(
			float(frame_index) * HIGHLIGHTS_FRAME_SIZE.x,
			0.0,
			HIGHLIGHTS_FRAME_SIZE.x,
			HIGHLIGHTS_FRAME_SIZE.y
		)
		_highlight_textures_by_room[room_id] = atlas_texture


func _set_default_highlight(next_room_to_unlock: int) -> void:
	if _highlights == null:
		return

	if next_room_to_unlock <= 0:
		_highlights.visible = false
		return

	_highlights.visible = false
	_set_highlight_room(next_room_to_unlock)
	_highlights.modulate = DOOR_UNLOCKED_MODULATE


func _set_highlight_room(room_id: int) -> void:
	if _highlights == null:
		return

	var highlight_texture: AtlasTexture = _highlight_textures_by_room.get(room_id) as AtlasTexture
	if highlight_texture == null:
		return

	_highlights.texture = highlight_texture


func _apply_door_state(door: Control, fog: ColorRect, state: Dictionary) -> void:
	var is_completed: bool = state.get("is_completed", false)
	var is_unlocked_now: bool = state.get("is_unlocked_now", false)
	var is_blocked: bool = state.get("is_blocked", false)
	var hotspot: Area2D = door.get_node_or_null("Hotspot") as Area2D

	if hotspot != null:
		hotspot.set("active", is_unlocked_now or is_blocked)

	if is_completed:
		if hotspot != null:
			hotspot.set("active", false)
		_set_fog_visibility(fog, false)
		door.modulate = DOOR_COMPLETED_MODULATE
		return

	if is_unlocked_now:
		_set_fog_visibility(fog, false)
		door.modulate = DOOR_UNLOCKED_MODULATE
		return

	_set_fog_visibility(fog, true)
	if fog != null:
		fog.modulate = BLOCKED_FOG_BASE_MODULATE
	door.modulate = DOOR_BLOCKED_MODULATE


func _connect_door_hotspots() -> void:
	_connect_hotspot(_door_1)
	_connect_hotspot(_door_2)
	_connect_hotspot(_door_3)
	_connect_hotspot(_door_4)


func _connect_hotspot(door: Control) -> void:
	var hotspot: Area2D = door.get_node_or_null("Hotspot") as Area2D
	if hotspot == null:
		return

	var room_id: int = HOTSPOT_TO_ROOM_ID.get(hotspot.get("hotspot_id"), 0)
	var on_hotspot_input_event_callable: Callable = Callable(self, "_on_hotspot_input_event").bind(room_id)
	var on_mouse_entered_callable: Callable = Callable(self, "_on_hotspot_mouse_entered").bind(room_id)
	var on_mouse_exited_callable: Callable = Callable(self, "_on_hotspot_mouse_exited").bind(room_id)

	if not hotspot.is_connected("input_event", on_hotspot_input_event_callable):
		hotspot.connect("input_event", on_hotspot_input_event_callable)

	if room_id <= 0:
		return

	if not hotspot.is_connected("mouse_entered", on_mouse_entered_callable):
		hotspot.connect("mouse_entered", on_mouse_entered_callable)

	if not hotspot.is_connected("mouse_exited", on_mouse_exited_callable):
		hotspot.connect("mouse_exited", on_mouse_exited_callable)


func _on_hotspot_input_event(_viewport: Node, event: InputEvent, _shape_idx: int, room_id: int) -> void:
	var press_position: Variant = _extract_press_position(event)
	if press_position == null:
		return

	_skip_next_global_press = true
	if GameManager.state == GameManager.State.TRANSITIONING or _pending_room_id > 0:
		return

	if not HOTSPOT_TO_ROOM_ID.values().has(room_id):
		push_warning("MainMenuController ignorou room_id desconhecido: %s" % room_id)
		_move_protagonist_to_screen_position(press_position as Vector2, 0)
		return

	_refresh_doors_state()
	var room_state: Dictionary = _door_state_by_room.get(room_id, {})
	if GameManager.can_enter_room(room_id):
		_move_protagonist_to_screen_position(press_position as Vector2, room_id)
		return

	_move_protagonist_to_screen_position(press_position as Vector2, 0)
	if room_state.get("is_blocked", false):
		_play_blocked_feedback(room_id)


func _input(event: InputEvent) -> void:
	if GameManager.state == GameManager.State.TRANSITIONING:
		return

	var press_position: Variant = _extract_press_position(event)
	if press_position == null:
		return

	if _skip_next_global_press:
		_skip_next_global_press = false
		return

	if _pending_room_id > 0:
		return

	_move_protagonist_to_screen_position(press_position as Vector2, 0)


func _play_blocked_feedback(room_id: int) -> void:
	var fog: ColorRect = _get_fog(room_id)
	if fog == null:
		return

	var existing_tween: Tween = _blocked_feedback_tweens.get(room_id)
	if existing_tween != null:
		existing_tween.kill()

	_set_fog_visibility(fog, true)
	fog.modulate = BLOCKED_FOG_BASE_MODULATE

	var tween: Tween = create_tween()
	_blocked_feedback_tweens[room_id] = tween
	tween.tween_property(fog, "modulate", BLOCKED_FOG_FLASH_MODULATE, BLOCKED_FEEDBACK_DURATION)
	tween.tween_property(fog, "modulate", BLOCKED_FOG_BASE_MODULATE, BLOCKED_FEEDBACK_DURATION)
	tween.finished.connect(_on_blocked_feedback_finished.bind(room_id, tween), CONNECT_ONE_SHOT)


func _on_blocked_feedback_finished(room_id: int, tween: Tween) -> void:
	if _blocked_feedback_tweens.get(room_id) == tween:
		_blocked_feedback_tweens.erase(room_id)

	_refresh_doors_state()


func _on_hotspot_mouse_entered(room_id: int) -> void:
	if room_id <= 0 or _hovered_room_id == room_id:
		return

	_hovered_room_id = room_id
	_set_highlight_room(room_id)

	if _highlights == null:
		return

	_highlights.visible = true
	_highlights.modulate = HIGHLIGHT_HOVER_MODULATE


func _on_hotspot_mouse_exited(room_id: int) -> void:
	if _hovered_room_id != room_id:
		return

	_hovered_room_id = 0
	_refresh_doors_state()


func _configure_protagonist() -> void:
	_protagonist.set_process_input(false)
	_protagonist.set("move_speed", protagonist_move_speed)
	_protagonist.set("arrival_threshold", protagonist_arrival_threshold)


func _connect_protagonist() -> void:
	if not _protagonist.has_signal("destination_reached"):
		push_warning("MainMenuController nao encontrou o sinal destination_reached na protagonista.")
		return

	var on_destination_reached: Callable = Callable(self, "_on_protagonist_destination_reached")
	if not _protagonist.is_connected("destination_reached", on_destination_reached):
		_protagonist.connect("destination_reached", on_destination_reached)


func _move_protagonist_to_screen_position(screen_position: Vector2, room_id: int) -> void:
	if not _protagonist.has_method("move_to_screen_position"):
		push_warning("MainMenuController nao encontrou a API move_to_screen_position na protagonista.")
		return

	_pending_room_id = room_id
	_protagonist.call("move_to_screen_position", screen_position)


func _on_protagonist_destination_reached(_destination: Vector2) -> void:
	var room_id: int = _pending_room_id
	_pending_room_id = 0
	if room_id <= 0:
		return

	if GameManager.state == GameManager.State.TRANSITIONING:
		return

	if not GameManager.can_enter_room(room_id):
		_refresh_doors_state()
		return

	GameManager.transition_to_room(room_id)


func _set_fog_visibility(fog: ColorRect, is_visible: bool) -> void:
	if fog == null:
		return

	fog.visible = is_visible


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


func _get_fog(room_id: int) -> ColorRect:
	match room_id:
		1:
			return _door_1_fog
		2:
			return _door_2_fog
		3:
			return _door_3_fog
		4:
			return _door_4_fog
		_:
			return null
