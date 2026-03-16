extends Node

enum State {
	PLAYING,
	TRANSITIONING,
}

const ROOM_SCENES: Dictionary = {
	1: "res://scenes/rooms/room_1.tscn",
	2: "res://scenes/rooms/room_2.tscn",
	3: "res://scenes/rooms/room_3.tscn",
	4: "res://scenes/rooms/room_4.tscn",
}
const MAIN_MENU_SCENE_PATH: String = "res://scenes/ui/main_menu.tscn"
const FINAL_SCENE_PATH: String = "res://scenes/ui/final_screen.tscn"

signal room_completed(room_id: int)
signal transition_started
signal transition_finished

const TRANSITION_FADE_DURATION: float = 0.5

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _scene_cache: Dictionary = {}
var state: int = State.PLAYING
var current_room: int = 0
var rooms_completed: Dictionary = {}


func _ready() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.name = "FadeLayer"
	add_child(_fade_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.offset_left = 0.0
	_fade_rect.offset_top = 0.0
	_fade_rect.offset_right = 0.0
	_fade_rect.offset_bottom = 0.0
	_fade_rect.z_index = 100
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)

	_preload_available_scenes()
	call_deferred("_sync_bgm_with_active_scene")


func transition_to_room(room_id: int) -> void:
	if not ROOM_SCENES.has(room_id):
		push_warning("GameManager.transition_to_room ignorado: room_id invalido: %s" % room_id)
		return

	if state == State.TRANSITIONING:
		push_warning("GameManager.transition_to_room ignorado: transicao ja esta em andamento.")
		return

	if current_room == 0 and not can_enter_room(room_id):
		push_warning("GameManager.transition_to_room ignorado: room_id %s nao esta liberado a partir do hub." % room_id)
		return

	_transition_to_scene_path(ROOM_SCENES[room_id], room_id, true)


func return_to_hub() -> void:
	_transition_to_scene_path(MAIN_MENU_SCENE_PATH, 0, true)


func get_next_room_to_unlock() -> int:
	for room_index in 4:
		var room_id: int = room_index + 1
		if not rooms_completed.get(room_id, false):
			return room_id

	return 0


func can_enter_room(room_id: int) -> bool:
	if not ROOM_SCENES.has(room_id):
		return false

	if rooms_completed.get(room_id, false):
		return false

	return room_id == get_next_room_to_unlock()


func complete_room(room_id: int) -> void:
	if room_id != current_room:
		push_warning("GameManager.complete_room ignorado: room_id %s nao corresponde a current_room %s." % [room_id, current_room])
		return

	if rooms_completed.get(room_id, false):
		push_warning("GameManager.complete_room ignorado: sala %s ja estava concluida." % room_id)
		return

	rooms_completed[room_id] = true
	room_completed.emit(room_id)

	if room_id < 4:
		return_to_hub()
		return

	_transition_to_scene_path(FINAL_SCENE_PATH, current_room, false)


func _transition_to_scene_path(scene_path: String, next_room_id: int, update_current_room: bool) -> void:
	if state == State.TRANSITIONING:
		push_warning("GameManager.transition_to_room ignorado: transicao ja esta em andamento.")
		return

	if _fade_rect == null:
		push_error("GameManager.transition_to_room falhou: overlay de fade nao foi inicializado.")
		return

	if not ResourceLoader.exists(scene_path):
		push_error("GameManager.transition_to_room falhou: cena nao encontrada em %s" % scene_path)
		return

	var packed_scene: PackedScene = _get_or_load_scene(scene_path)
	if packed_scene == null:
		push_error("GameManager.transition_to_room falhou: PackedScene invalida para %s" % scene_path)
		return

	state = State.TRANSITIONING
	transition_started.emit()

	var fade_out_tween: Tween = create_tween()
	fade_out_tween.tween_property(_fade_rect, "color", Color(0.0, 0.0, 0.0, 1.0), TRANSITION_FADE_DURATION)
	await fade_out_tween.finished

	var change_error: Error = get_tree().change_scene_to_packed(packed_scene)
	if change_error != OK:
		push_error("GameManager.transition_to_room falhou: change_scene_to_packed retornou erro %s para %s" % [change_error, scene_path])

		var rollback_tween: Tween = create_tween()
		rollback_tween.tween_property(_fade_rect, "color", Color(0.0, 0.0, 0.0, 0.0), TRANSITION_FADE_DURATION)
		await rollback_tween.finished

		state = State.PLAYING
		return

	await get_tree().scene_changed
	if update_current_room:
		current_room = next_room_id

	_sync_bgm_for_scene_path(scene_path)

	var fade_in_tween: Tween = create_tween()
	fade_in_tween.tween_property(_fade_rect, "color", Color(0.0, 0.0, 0.0, 0.0), TRANSITION_FADE_DURATION)
	await fade_in_tween.finished

	state = State.PLAYING
	transition_finished.emit()


func _preload_available_scenes() -> void:
	for scene_path_variant in ROOM_SCENES.values():
		var scene_path: String = scene_path_variant
		_cache_scene_if_available(scene_path)

	_cache_scene_if_available(MAIN_MENU_SCENE_PATH)
	_cache_scene_if_available(FINAL_SCENE_PATH)


func _cache_scene_if_available(scene_path: String) -> void:
	if _scene_cache.has(scene_path):
		return

	if not ResourceLoader.exists(scene_path):
		return

	var packed_scene: PackedScene = load(scene_path) as PackedScene
	if packed_scene == null:
		push_warning("GameManager nao conseguiu preload da cena em %s" % scene_path)
		return

	_scene_cache[scene_path] = packed_scene


func _get_or_load_scene(scene_path: String) -> PackedScene:
	if _scene_cache.has(scene_path):
		return _scene_cache[scene_path] as PackedScene

	var packed_scene: PackedScene = load(scene_path) as PackedScene
	if packed_scene == null:
		return null

	_scene_cache[scene_path] = packed_scene
	return packed_scene


func _sync_bgm_with_active_scene() -> void:
	var active_scene: Node = get_tree().current_scene
	if active_scene == null:
		return

	_sync_bgm_for_scene_path(active_scene.scene_file_path)


func _sync_bgm_for_scene_path(scene_path: String) -> void:
	var audio_manager: Node = get_node_or_null("/root/AudioManager")
	if audio_manager == null or not audio_manager.has_method("play_bgm"):
		return

	var track_key: String = _get_bgm_track_key_for_scene_path(scene_path)
	if track_key.is_empty():
		return

	audio_manager.call("play_bgm", track_key)


func _get_bgm_track_key_for_scene_path(scene_path: String) -> String:
	if scene_path == MAIN_MENU_SCENE_PATH:
		return "hub_room_1"

	if scene_path == FINAL_SCENE_PATH:
		return "finale"

	for room_id_variant in ROOM_SCENES.keys():
		var room_id: int = int(room_id_variant)
		var room_scene_path: String = String(ROOM_SCENES[room_id])
		if scene_path != room_scene_path:
			continue

		match room_id:
			1:
				return "room_1"
			2:
				return "room_2"
			3:
				return "room_3"
			4:
				return "finale"

	return ""
