extends Node2D

const HINT_BASE_MODULATE: Color = Color(1.0, 1.0, 1.0, 0.14)
const HINT_PEAK_MODULATE: Color = Color(1.0, 1.0, 1.0, 0.34)
const HIDDEN_HIGHLIGHT_COLOR: Color = Color(1.0, 1.0, 1.0, 0.0)
const CARRIED_FLOWER_SCALE: Vector2 = Vector2(1.4, 1.4)
const KEY_BOB_OFFSET: Vector2 = Vector2(0.0, -12.0)
const KEY_BOB_DURATION: float = 0.7
const FURAO_IDLE_ANIMATION: StringName = &"idle"
const FURAO_PET_ANIMATION: StringName = &"pet"
const FURAO_LOVE_DURATION: float = 2.0

enum RoomState {
	WAITING_PICKUP,
	MOVING_TO_PICKUP,
	CARRYING_FLOWER,
	MOVING_TO_PLACE,
	FINALE_PLAYING,
	WAITING_PRESENT_OPEN,
	MOVING_TO_PRESENT,
	WAITING_KEY,
	MOVING_TO_KEY,
}

@onready var _pickup_hotspot: Area2D = $CanvasLayer/FlowerOrigin/PickupHotspot
@onready var _hibisco_hotspot: Area2D = $CanvasLayer/FlowerTargets/TargetHibisco/Hotspot
@onready var _rosa_hotspot: Area2D = $CanvasLayer/FlowerTargets/TargetRosa/Hotspot
@onready var _lirio_hotspot: Area2D = $CanvasLayer/FlowerTargets/TargetLirio/Hotspot
@onready var _girassol_hotspot: Area2D = $CanvasLayer/FlowerTargets/TargetGirassol/Hotspot
@onready var _hibisco_layer: TextureRect = $CanvasLayer/Highlighter1Hibisco
@onready var _hibisco_revealer: Node = $CanvasLayer/Highlighter1Hibisco/Revealer
@onready var _rosas_vermelhas_layer: TextureRect = $CanvasLayer/Highlighter2RosasVermelhas
@onready var _rosas_vermelhas_revealer: Node = $CanvasLayer/Highlighter2RosasVermelhas/Revealer
@onready var _lirios_layer: TextureRect = $CanvasLayer/Highlighter3Lirios
@onready var _lirios_revealer: Node = $CanvasLayer/Highlighter3Lirios/Revealer
@onready var _girassois_layer: TextureRect = $CanvasLayer/Highlighter4Girassois
@onready var _girassois_revealer: Node = $CanvasLayer/Highlighter4Girassois/Revealer
@onready var _flower_origin: Node2D = $CanvasLayer/FlowerOrigin
@onready var _hibisco_flower: Sprite2D = $CanvasLayer/FlowerOrigin/Hibisco
@onready var _rosas_vermelhas_flower: Sprite2D = $CanvasLayer/FlowerOrigin/RosasVermelhas
@onready var _lirios_flower: Sprite2D = $CanvasLayer/FlowerOrigin/Lirios
@onready var _girassois_flower: Sprite2D = $CanvasLayer/FlowerOrigin/Girassois
@onready var _hibisco_approach_marker: Marker2D = $CanvasLayer/FlowerTargets/TargetHibisco/ApproachMarker
@onready var _rosa_approach_marker: Marker2D = $CanvasLayer/FlowerTargets/TargetRosa/ApproachMarker
@onready var _lirio_approach_marker: Marker2D = $CanvasLayer/FlowerTargets/TargetLirio/ApproachMarker
@onready var _girassol_approach_marker: Marker2D = $CanvasLayer/FlowerTargets/TargetGirassol/ApproachMarker
@onready var _hibisco_hint: TextureRect = $CanvasLayer/TargetHints/HintHibisco
@onready var _rosas_vermelhas_hint: TextureRect = $CanvasLayer/TargetHints/HintRosasVermelhas
@onready var _lirios_hint: TextureRect = $CanvasLayer/TargetHints/HintLirios
@onready var _girassois_hint: TextureRect = $CanvasLayer/TargetHints/HintGirassois
@onready var _background: AnimatedSprite2D = $CanvasLayer/Background
@onready var _protagonist: Node2D = $CanvasLayer/Protagonist
@onready var _center: TextureRect = $CanvasLayer/Center
@onready var _presente: Sprite2D = $CanvasLayer/Presente
@onready var _present_hotspot: Area2D = $CanvasLayer/Presente/Hotspot
@onready var _furao: AnimatedSprite2D = $CanvasLayer/Furao
@onready var _furao_hotspot: Area2D = $CanvasLayer/Furao/Hotspot
@onready var _furao_love: Sprite2D = $CanvasLayer/Furao/Love
@onready var _key_pickup: Node2D = $CanvasLayer/KeyPickup
@onready var _key_hotspot: Area2D = $CanvasLayer/KeyPickup/Hotspot

var _flowers_restored: int = 0
var _current_flower_index: int = 0
var _room_state: int = RoomState.WAITING_PICKUP
var _flower_sequence: Array[Dictionary] = []
var _pending_flower_data: Dictionary = {}
var _active_hint: TextureRect
var _hint_tween: Tween
var _key_bob_tween: Tween
var _furao_reset_tween: Tween
var _key_base_position: Vector2 = Vector2.ZERO
var _furao_interaction_active: bool = false


func _ready() -> void:
	_flower_sequence = [
		_create_flower_data("hibisco", _hibisco_hotspot, _hibisco_flower, _hibisco_approach_marker, _hibisco_hint, _hibisco_layer, _hibisco_revealer),
		_create_flower_data("rosa", _rosa_hotspot, _rosas_vermelhas_flower, _rosa_approach_marker, _rosas_vermelhas_hint, _rosas_vermelhas_layer, _rosas_vermelhas_revealer),
		_create_flower_data("lirio", _lirio_hotspot, _lirios_flower, _lirio_approach_marker, _lirios_hint, _lirios_layer, _lirios_revealer),
		_create_flower_data("girassol", _girassol_hotspot, _girassois_flower, _girassol_approach_marker, _girassois_hint, _girassois_layer, _girassois_revealer),
	]

	_key_base_position = _key_pickup.position
	_prepare_flower_layers()
	_connect_hotspots()
	_connect_protagonist()
	_hide_all_hints()
	_hide_carried_flower()
	_set_key_visible(false)
	_set_furao_visible(false)
	_show_current_flower()
	_refresh_hotspots()
	_set_manual_input_enabled(true)


func _on_hotspot_pressed(hotspot_id: String) -> void:
	if GameManager.state == GameManager.State.TRANSITIONING:
		return

	match hotspot_id:
		"pickup_flower":
			_request_pickup()
		"open_present":
			_request_present_open()
		"pet_furao":
			_trigger_furao_interaction()
		"pickup_key":
			_request_key_pickup()
		_:
			_request_delivery(hotspot_id)


func _on_protagonist_destination_reached(_destination: Vector2) -> void:
	match _room_state:
		RoomState.MOVING_TO_PICKUP:
			_complete_pickup()
		RoomState.MOVING_TO_PLACE:
			_complete_flower_delivery()
		RoomState.MOVING_TO_PRESENT:
			_complete_present_open()
		RoomState.MOVING_TO_KEY:
			_complete_key_pickup()


func _request_pickup() -> void:
	if _room_state != RoomState.WAITING_PICKUP:
		return

	var flower_data: Dictionary = _get_current_flower_data()
	if flower_data.is_empty():
		return

	_pending_flower_data = flower_data
	_room_state = RoomState.MOVING_TO_PICKUP
	_refresh_hotspots()
	_move_protagonist_to_action(_flower_origin.global_position)


func _request_delivery(hotspot_id: String) -> void:
	if _room_state != RoomState.CARRYING_FLOWER:
		return

	var flower_data: Dictionary = _get_current_flower_data()
	if flower_data.is_empty() or hotspot_id != flower_data.get("id", ""):
		return

	var approach_marker: Marker2D = flower_data.get("approach_marker") as Marker2D
	if approach_marker == null:
		return

	_pending_flower_data = flower_data
	_room_state = RoomState.MOVING_TO_PLACE
	_refresh_hotspots()
	_move_protagonist_to_action(approach_marker.global_position)


func _request_key_pickup() -> void:
	if _room_state != RoomState.WAITING_KEY:
		return

	_room_state = RoomState.MOVING_TO_KEY
	_refresh_hotspots()
	_move_protagonist_to_action(_key_pickup.global_position)


func _request_present_open() -> void:
	if _room_state != RoomState.WAITING_PRESENT_OPEN or not _presente.visible:
		return

	_room_state = RoomState.MOVING_TO_PRESENT
	_refresh_hotspots()
	_move_protagonist_to_action(_presente.global_position)


func _complete_pickup() -> void:
	var flower_data: Dictionary = _pending_flower_data
	if flower_data.is_empty():
		flower_data = _get_current_flower_data()
	if flower_data.is_empty():
		return

	var flower_sprite: Sprite2D = flower_data.get("flower") as Sprite2D
	if flower_sprite != null:
		flower_sprite.visible = false
		_show_carried_flower(flower_sprite.texture)

	_room_state = RoomState.CARRYING_FLOWER
	_set_hint_visible(flower_data, true)
	_refresh_hotspots()
	_set_manual_input_enabled(true)


func _complete_flower_delivery() -> void:
	var flower_data: Dictionary = _pending_flower_data
	_pending_flower_data = {}
	if flower_data.is_empty():
		return

	_hide_carried_flower()
	_set_hint_visible(flower_data, false)

	var revealer: Node = flower_data.get("revealer") as Node
	if revealer != null and revealer.has_method("hide_visual"):
		revealer.call("hide_visual")

	_flowers_restored += 1
	_current_flower_index = _flowers_restored
	_show_current_flower()

	if _flowers_restored >= _flower_sequence.size():
		_start_finale()
		return

	_room_state = RoomState.WAITING_PICKUP
	_refresh_hotspots()
	_set_manual_input_enabled(true)


func _complete_key_pickup() -> void:
	_set_key_visible(false)
	GameManager.complete_room(1)


func _complete_present_open() -> void:
	_presente.visible = false
	_presente.modulate = Color.WHITE
	_present_hotspot.set("active", false)
	_set_furao_visible(true)
	_furao.scale = Vector2.ZERO
	create_tween().tween_property(_furao, "scale", Vector2(0.6, 0.6), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_show_key_reward()


func _create_flower_data(flower_id: String, hotspot: Area2D, flower: Sprite2D, approach_marker: Marker2D, hint: TextureRect, layer: TextureRect, revealer: Node) -> Dictionary:
	return {
		"id": flower_id,
		"hotspot": hotspot,
		"flower": flower,
		"approach_marker": approach_marker,
		"hint": hint,
		"layer": layer,
		"revealer": revealer,
	}


func _prepare_flower_layers() -> void:
	for flower_data: Dictionary in _flower_sequence:
		var layer: TextureRect = flower_data.get("layer") as TextureRect
		var revealer: Node = flower_data.get("revealer") as Node
		if layer != null:
			layer.modulate = Color.WHITE
		if revealer != null:
			revealer.set("hidden_color", HIDDEN_HIGHLIGHT_COLOR)
			if revealer.has_method("reveal_instant"):
				revealer.call("reveal_instant")


func _connect_hotspots() -> void:
	var on_hotspot_pressed: Callable = Callable(self, "_on_hotspot_pressed")
	var hotspots: Array[Area2D] = [_pickup_hotspot, _hibisco_hotspot, _rosa_hotspot, _lirio_hotspot, _girassol_hotspot, _present_hotspot, _furao_hotspot, _key_hotspot]
	for hotspot: Area2D in hotspots:
		if hotspot != null and not hotspot.is_connected("pressed", on_hotspot_pressed):
			hotspot.connect("pressed", on_hotspot_pressed)


func _connect_protagonist() -> void:
	var on_destination_reached: Callable = Callable(self, "_on_protagonist_destination_reached")
	if _protagonist.has_signal("destination_reached") and not _protagonist.is_connected("destination_reached", on_destination_reached):
		_protagonist.connect("destination_reached", on_destination_reached)


func _hide_all_hints() -> void:
	_stop_hint_tween()
	for flower_data: Dictionary in _flower_sequence:
		var hint: TextureRect = flower_data.get("hint") as TextureRect
		if hint != null:
			hint.visible = false
			hint.modulate = HINT_BASE_MODULATE
	_active_hint = null


func _show_current_flower() -> void:
	for flower_data: Dictionary in _flower_sequence:
		var flower_sprite: Sprite2D = flower_data.get("flower") as Sprite2D
		if flower_sprite != null:
			flower_sprite.visible = false

	var current_flower: Dictionary = _get_current_flower_data()
	var current_sprite: Sprite2D = current_flower.get("flower") as Sprite2D
	if current_sprite != null and _room_state < RoomState.FINALE_PLAYING:
		current_sprite.visible = true


func _refresh_hotspots() -> void:
	var current_index: int = _current_flower_index
	_pickup_hotspot.set("active", _room_state == RoomState.WAITING_PICKUP and current_index < _flower_sequence.size())
	_present_hotspot.set("active", _room_state == RoomState.WAITING_PRESENT_OPEN and _presente.visible)
	_furao_hotspot.set("active", _room_state == RoomState.WAITING_KEY and _furao.visible and not _furao_interaction_active)
	_key_hotspot.set("active", _room_state == RoomState.WAITING_KEY and _key_pickup.visible)

	for index: int in _flower_sequence.size():
		var hotspot: Area2D = _flower_sequence[index].get("hotspot") as Area2D
		if hotspot == null:
			continue

		hotspot.set("active", _room_state == RoomState.CARRYING_FLOWER and index == current_index)


func _get_current_flower_data() -> Dictionary:
	if _current_flower_index < 0 or _current_flower_index >= _flower_sequence.size():
		return {}

	return _flower_sequence[_current_flower_index]


func _set_hint_visible(flower_data: Dictionary, is_visible: bool) -> void:
	var hint: TextureRect = flower_data.get("hint") as TextureRect
	if hint == null:
		return

	if is_visible:
		_hide_all_hints()
		_active_hint = hint
		hint.visible = true
		hint.modulate = HINT_BASE_MODULATE
		_hint_tween = create_tween().set_loops()
		_hint_tween.tween_property(hint, "modulate", HINT_PEAK_MODULATE, 0.45)
		_hint_tween.tween_property(hint, "modulate", HINT_BASE_MODULATE, 0.45)
		return

	if _active_hint == hint:
		_stop_hint_tween()
		_active_hint = null

	hint.visible = false
	hint.modulate = HINT_BASE_MODULATE


func _move_protagonist_to_action(target_position: Vector2) -> void:
	if _protagonist.has_method("consume_next_press"):
		_protagonist.call("consume_next_press")
	_set_manual_input_enabled(false)
	if _protagonist.has_method("move_to_global_position"):
		_protagonist.call("move_to_global_position", target_position)


func _set_manual_input_enabled(is_enabled: bool) -> void:
	if _protagonist.has_method("set_manual_input_enabled"):
		_protagonist.call("set_manual_input_enabled", is_enabled)


func _show_carried_flower(flower_texture: Texture2D) -> void:
	if _protagonist.has_method("show_carried_flower"):
		_protagonist.call("show_carried_flower", flower_texture, CARRIED_FLOWER_SCALE)


func _hide_carried_flower() -> void:
	if _protagonist.has_method("hide_carried_flower"):
		_protagonist.call("hide_carried_flower")


func _start_finale() -> void:
	if _flowers_restored < _flower_sequence.size() or GameManager.state == GameManager.State.TRANSITIONING:
		return

	_room_state = RoomState.FINALE_PLAYING
	_refresh_hotspots()
	_set_manual_input_enabled(false)

	var finale_chain: EventChain = get_node_or_null("FinaleChain") as EventChain
	if finale_chain == null:
		finale_chain = EventChain.new()
		finale_chain.name = "FinaleChain"
		add_child(finale_chain)

	finale_chain.clear()
	finale_chain.add_step(Callable(self, "_run_finale_step").bind(1), 0.2)
	finale_chain.add_step(Callable(self, "_run_finale_step").bind(2), 1.25)
	finale_chain.add_step(Callable(self, "_run_finale_step").bind(3), 0.1)
	finale_chain.add_step(Callable(self, "_run_finale_step").bind(4), 0.7)
	finale_chain.add_step(Callable(self, "_run_finale_step").bind(5), 0.0)
	finale_chain.play()


func _run_finale_step(step: int) -> void:
	match step:
		1:
			pass
		2:
			_background.play(&"surprise")
		3:
			_center.visible = false
		4:
			_presente.modulate = Color(1.0, 1.0, 1.0, 0.0)
			_presente.visible = true
			create_tween().tween_property(_presente, "modulate", Color.WHITE, 0.6)
		5:
			_await_present_open()


func _await_present_open() -> void:
	_room_state = RoomState.WAITING_PRESENT_OPEN
	_refresh_hotspots()
	_set_manual_input_enabled(true)


func _show_key_reward() -> void:
	_room_state = RoomState.WAITING_KEY
	_set_key_visible(true)
	_refresh_hotspots()
	_set_manual_input_enabled(true)
	_start_key_bob()


func _trigger_furao_interaction() -> void:
	if _room_state != RoomState.WAITING_KEY or not _furao.visible or _furao_interaction_active:
		return

	_furao_interaction_active = true
	_refresh_hotspots()
	_play_furao_interaction_sfx()
	_furao_love.visible = true
	_furao.play(FURAO_PET_ANIMATION)
	if _furao_reset_tween != null:
		_furao_reset_tween.kill()
	_furao_reset_tween = create_tween()
	_furao_reset_tween.tween_interval(FURAO_LOVE_DURATION)
	_furao_reset_tween.finished.connect(_finish_furao_interaction, CONNECT_ONE_SHOT)


func _finish_furao_interaction() -> void:
	_furao_love.visible = false
	_furao.play(FURAO_IDLE_ANIMATION)
	_furao_interaction_active = false
	_furao_reset_tween = null
	_refresh_hotspots()


func _set_furao_visible(is_visible: bool) -> void:
	_furao.visible = is_visible
	_furao_love.visible = false
	if not is_visible:
		_furao_interaction_active = false
		if _furao_reset_tween != null:
			_furao_reset_tween.kill()
			_furao_reset_tween = null
		return

	_furao.play(FURAO_IDLE_ANIMATION)


func _play_furao_interaction_sfx() -> void:
	pass


func _set_key_visible(is_visible: bool) -> void:
	_key_pickup.visible = is_visible
	if not is_visible:
		_stop_key_bob()


func _start_key_bob() -> void:
	_stop_key_bob()
	_key_pickup.position = _key_base_position
	_key_bob_tween = create_tween().set_loops()
	_key_bob_tween.tween_property(_key_pickup, "position", _key_base_position + KEY_BOB_OFFSET, KEY_BOB_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_key_bob_tween.tween_property(_key_pickup, "position", _key_base_position - KEY_BOB_OFFSET, KEY_BOB_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_key_bob() -> void:
	if _key_bob_tween != null:
		_key_bob_tween.kill()
		_key_bob_tween = null
	_key_pickup.position = _key_base_position


func _stop_hint_tween() -> void:
	if _hint_tween != null:
		_hint_tween.kill()
		_hint_tween = null