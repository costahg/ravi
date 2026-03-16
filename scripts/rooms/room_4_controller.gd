extends Node2D

const TOTAL_HEART_PIECES: int = 6
const PIECE_COLORS: Array[Color] = [
	Color(0.94902, 0.447059, 0.627451, 0.92),
	Color(0.984314, 0.545098, 0.705882, 0.92),
	Color(0.905882, 0.345098, 0.572549, 0.92),
	Color(1.0, 0.627451, 0.764706, 0.92),
	Color(0.972549, 0.501961, 0.670588, 0.92),
	Color(1.0, 0.576471, 0.72549, 0.92)
]
const MINIGAME_POSITIONS: Array[Vector2] = [
	Vector2(95, 860),
	Vector2(165, 860),
	Vector2(235, 860),
	Vector2(305, 860),
	Vector2(375, 860),
	Vector2(445, 860)
]
const TARGET_OFFSETS: Array[Vector2] = [
	Vector2(-78, -78),
	Vector2(78, -78),
	Vector2(-126, -4),
	Vector2(126, -4),
	Vector2(-62, 96),
	Vector2(62, 96)
]

const HEART_CENTER: Vector2 = Vector2(270, 430)
const BOARD_SCALE: float = 1.55
const ARRIVAL_TOLERANCE: float = 24.0

const HENRI_IDLE_COLUMNS: int = 6
const HENRI_IDLE_ROWS: int = 6
const HENRI_FRAME_SIZE: Vector2 = Vector2(256, 256)

const FINALE_HENRI_POSITION: Vector2 = Vector2(208, 508)
const FINALE_DOLL_POSITION: Vector2 = Vector2(332, 508)
const FINALE_SPAWN_OFFSET_Y: float = 52.0
const FINALE_HEART_FILL_STEP_DURATION: float = 0.12
const FINALE_HEART_COMPLETE_HOLD: float = 1.0
const FINALE_HEART_REFORM_DURATION: float = (TOTAL_HEART_PIECES * FINALE_HEART_FILL_STEP_DURATION) + FINALE_HEART_COMPLETE_HOLD + 0.18
const FINALE_FADE_OUT_DURATION: float = 0.7
const FINALE_FADE_IN_DURATION: float = 0.8
const FINALE_SPAWN_DURATION: float = 0.45
const FINALE_PHOTO_POSE_DURATION: float = 0.35
const FINALE_FLASH_DURATION: float = 0.14
const FINALE_FREEZE_DURATION: float = 1.5
const HENRI_INTERACTION_HITBOX_SIZE: Vector2 = Vector2(170, 190)

const HEART_ASSEMBLY_MINIGAME_SCRIPT: Script = preload("res://scripts/rooms/room_4/heart_assembly_minigame.gd")
const EVENT_CHAIN_SCRIPT: Script = preload("res://scripts/components/event_chain.gd")
const HOTSPOT_SCRIPT: Script = preload("res://scripts/components/hotspot.gd")
const HENRI_IDLE_TEXTURE: Texture2D = preload("res://assets/sprites/HenriIdle-1256x256_6C6L_S01.png")

@onready var _background_before: AnimatedSprite2D = $BackgroundBefore
@onready var _background_after: AnimatedSprite2D = $BackgroundAfter
@onready var _assembly_area: Node2D = $AssemblyArea
@onready var _assembly_hotspot: Area2D = $AssemblyArea/AssemblyHotspot
@onready var _crying_boy: Node2D = $CryingBoy
@onready var _henri: AnimatedSprite2D = $CryingBoy/Henri
@onready var _doll: Node2D = $Doll
@onready var _boneca: AnimatedSprite2D = $Doll/Boneca
@onready var _heart_pieces_root: Node = $HeartPieces
@onready var _protagonist: Node2D = $Protagonist

var _pieces_collected: int = 0
var _assembled_pieces: int = 0
var _collected_piece_ids: Dictionary = {}
var _assembled_piece_ids: Dictionary = {}
var _awaiting_assembly_arrival: bool = false
var _assembly_unlocked: bool = false
var _minigame_opened: bool = false
var _assembly_completed: bool = false
var _finale_triggered: bool = false
var _awaiting_henri_arrival: bool = false
var _post_minigame_heart_played: bool = false

var _assembly_minigame: CanvasLayer
var _pending_piece_id: String = ""
var _pending_piece_node: Node2D
var _pending_piece_target: Vector2 = Vector2.ZERO
var _carried_heart: Node2D
var _henri_hotspot: Area2D
var _protagonist_initial_position: Vector2 = Vector2.ZERO

var _finale_chain: EventChain
var _finale_overlay_layer: CanvasLayer
var _finale_fade_rect: ColorRect
var _finale_flash_rect: ColorRect
var _finale_heart_holder: Node2D
var _finale_heart_full: Polygon2D
var _finale_heart_fragments: Array[Polygon2D] = []


func _ready() -> void:
	if _protagonist != null:
		_protagonist_initial_position = _protagonist.global_position
		if not _protagonist.destination_reached.is_connected(_on_protagonist_destination_reached):
			_protagonist.destination_reached.connect(_on_protagonist_destination_reached)

	if _assembly_hotspot != null:
		if not _assembly_hotspot.pressed.is_connected(_on_assembly_hotspot_pressed):
			_assembly_hotspot.pressed.connect(_on_assembly_hotspot_pressed)
		_assembly_hotspot.set("active", false)

	_connect_piece_hotspots()
	_build_henri_interaction_hotspot()
	_build_carried_heart()
	_build_minigame()
	_build_finale_chain()
	_prepare_finale_scene_state()
	_update_boy_feedback()


func notify_piece_collected(piece_id: String, piece_node: Node2D) -> void:
	if piece_id == "" or _collected_piece_ids.has(piece_id):
		return

	_collected_piece_ids[piece_id] = true
	_pieces_collected = _collected_piece_ids.size()

	if piece_node != null:
		piece_node.visible = false
		piece_node.process_mode = Node.PROCESS_MODE_DISABLED

		var hotspot: Node = piece_node.get_node_or_null("Hotspot")
		if hotspot != null:
			hotspot.set("active", false)

	_update_boy_feedback()

	if _pieces_collected >= TOTAL_HEART_PIECES:
		_unlock_assembly_area()
		_show_carried_heart()


func are_all_pieces_collected() -> bool:
	return _pieces_collected >= TOTAL_HEART_PIECES


func get_pieces_collected() -> int:
	return _pieces_collected


func _connect_piece_hotspots() -> void:
	if _heart_pieces_root == null:
		return

	for piece: Node in _heart_pieces_root.get_children():
		var piece_node: Node2D = piece as Node2D
		if piece_node == null:
			continue

		var hotspot: Area2D = piece_node.get_node_or_null("Hotspot") as Area2D
		if hotspot == null:
			continue

		var callback: Callable = Callable(self, "_on_piece_hotspot_pressed").bind(piece_node)
		if not hotspot.pressed.is_connected(callback):
			hotspot.pressed.connect(callback)


func _build_henri_interaction_hotspot() -> void:
	if _crying_boy == null or _henri_hotspot != null:
		return

	_henri_hotspot = Area2D.new()
	_henri_hotspot.name = "HenriHotspot"
	_henri_hotspot.set_script(HOTSPOT_SCRIPT)
	_henri_hotspot.set("hotspot_id", "henri_finale")
	_henri_hotspot.set("one_shot", false)
	_henri_hotspot.set("active", false)

	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"

	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = HENRI_INTERACTION_HITBOX_SIZE
	collision_shape.shape = shape

	_henri_hotspot.add_child(collision_shape)
	_crying_boy.add_child(_henri_hotspot)

	if not _henri_hotspot.pressed.is_connected(_on_henri_hotspot_pressed):
		_henri_hotspot.pressed.connect(_on_henri_hotspot_pressed)


func _on_piece_hotspot_pressed(hotspot_id: String, piece_node: Node2D) -> void:
	if hotspot_id == "" or piece_node == null:
		return
	if _minigame_opened or _awaiting_assembly_arrival or _pending_piece_id != "":
		return
	if _collected_piece_ids.has(hotspot_id) or _protagonist == null:
		return

	_pending_piece_id = hotspot_id
	_pending_piece_node = piece_node
	_pending_piece_target = piece_node.global_position

	_protagonist.set_manual_input_enabled(false)
	_protagonist.consume_next_press()
	_protagonist.move_to_global_position(_pending_piece_target)


func _on_henri_hotspot_pressed(_hotspot_id: String) -> void:
	if not _assembly_completed or _finale_triggered or _awaiting_henri_arrival:
		return
	if not _post_minigame_heart_played:
		return
	if _protagonist == null or _crying_boy == null:
		return

	_awaiting_henri_arrival = true
	_protagonist.set_manual_input_enabled(false)
	_protagonist.consume_next_press()
	_protagonist.move_to_global_position(_crying_boy.global_position)


func _on_assembly_hotspot_pressed(_hotspot_id: String) -> void:
	if not are_all_pieces_collected() or _awaiting_assembly_arrival or _minigame_opened:
		return
	if _protagonist == null or _assembly_area == null:
		return

	_awaiting_assembly_arrival = true
	_protagonist.set_manual_input_enabled(false)
	_protagonist.consume_next_press()
	_protagonist.move_to_global_position(_assembly_area.global_position)


func _on_protagonist_destination_reached(destination: Vector2) -> void:
	if _pending_piece_id != "":
		if destination.distance_to(_pending_piece_target) <= ARRIVAL_TOLERANCE:
			notify_piece_collected(_pending_piece_id, _pending_piece_node)
			_pending_piece_id = ""
			_pending_piece_node = null
			_pending_piece_target = Vector2.ZERO

			if not _minigame_opened:
				_protagonist.set_manual_input_enabled(true)
		return

	if _awaiting_assembly_arrival and _assembly_area != null:
		if destination.distance_to(_assembly_area.global_position) <= ARRIVAL_TOLERANCE:
			_awaiting_assembly_arrival = false
			_hide_carried_heart()
			_open_minigame()
		return

	if _awaiting_henri_arrival and _crying_boy != null:
		if destination.distance_to(_crying_boy.global_position) <= ARRIVAL_TOLERANCE:
			_awaiting_henri_arrival = false
			if _henri_hotspot != null:
				_henri_hotspot.set("active", false)
			_trigger_finale()


func _unlock_assembly_area() -> void:
	if _assembly_unlocked:
		return

	_assembly_unlocked = true

	if _assembly_hotspot != null:
		_assembly_hotspot.set("active", true)

	if _assembly_area != null:
		var tween: Tween = create_tween()
		tween.set_loops(4)
		tween.tween_property(_assembly_area, "scale", Vector2(1.08, 1.08), 0.18)
		tween.tween_property(_assembly_area, "scale", Vector2.ONE, 0.18)


func _build_carried_heart() -> void:
	if _protagonist == null or _carried_heart != null:
		return

	_carried_heart = Node2D.new()
	_carried_heart.name = "CarriedHeart"
	_carried_heart.position = Vector2(0, -58)
	_carried_heart.visible = false

	var heart: Polygon2D = Polygon2D.new()
	heart.polygon = _build_heart_silhouette()
	heart.scale = Vector2(0.11, 0.11)
	heart.color = Color(0.98, 0.54, 0.72, 0.95)

	_carried_heart.add_child(heart)
	_protagonist.add_child(_carried_heart)


func _show_carried_heart() -> void:
	if _carried_heart != null:
		_carried_heart.visible = true


func _hide_carried_heart() -> void:
	if _carried_heart != null:
		_carried_heart.visible = false


func _build_minigame() -> void:
	if _assembly_minigame != null:
		return

	_assembly_minigame = HEART_ASSEMBLY_MINIGAME_SCRIPT.new() as CanvasLayer
	_assembly_minigame.name = "HeartAssemblyMinigame"
	add_child(_assembly_minigame)

	_assembly_minigame.call(
		"setup",
		HEART_CENTER,
		BOARD_SCALE,
		_build_piece_polygons(),
		MINIGAME_POSITIONS,
		PIECE_COLORS
	)

	if not _assembly_minigame.is_connected("piece_placed", _on_minigame_piece_placed):
		_assembly_minigame.connect("piece_placed", _on_minigame_piece_placed)

	if not _assembly_minigame.is_connected("assembly_completed", _on_minigame_completed):
		_assembly_minigame.connect("assembly_completed", _on_minigame_completed)


func _open_minigame() -> void:
	if _minigame_opened or _assembly_minigame == null:
		return

	_minigame_opened = true
	_assembly_minigame.call("open")

	if _protagonist != null:
		_protagonist.set_manual_input_enabled(false)


func _on_minigame_piece_placed(piece_id: String, _zone_id: String) -> void:
	if piece_id == "" or _assembled_piece_ids.has(piece_id):
		return

	_assembled_piece_ids[piece_id] = true
	_assembled_pieces = _assembled_piece_ids.size()
	_update_boy_feedback()


func _on_minigame_completed() -> void:
	if _assembly_completed:
		return

	_assembly_completed = true
	_update_boy_feedback()
	_prepare_post_minigame_state()
	_play_post_minigame_heart_animation()


func _prepare_post_minigame_state() -> void:
	_minigame_opened = false
	_awaiting_henri_arrival = false

	if _assembly_minigame != null:
		_assembly_minigame.call("close")

	_hide_carried_heart()

	if _background_before != null:
		_background_before.visible = false

	if _heart_pieces_root != null:
		_heart_pieces_root.visible = false

	if _assembly_area != null:
		_assembly_area.visible = false

	if _background_after != null:
		_background_after.visible = true
		_background_after.modulate = Color(1.0, 1.0, 1.0, 1.0)

	if _crying_boy != null:
		_crying_boy.visible = true
		_crying_boy.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_crying_boy.scale = Vector2.ONE

	_step_boy_stops_crying()

	if _protagonist != null:
		_protagonist.visible = true
		_protagonist.global_position = _protagonist_initial_position
		if _protagonist.has_method("stop"):
			_protagonist.call("stop")
		_protagonist.set_manual_input_enabled(false)

	if _henri_hotspot != null:
		_henri_hotspot.set("active", false)


func _play_post_minigame_heart_animation() -> void:
	if _post_minigame_heart_played:
		return

	_build_finale_overlay()
	_post_minigame_heart_played = true

	if _protagonist != null:
		_protagonist.set_manual_input_enabled(false)

	_step_show_completed_heart()

	var timer: SceneTreeTimer = get_tree().create_timer(FINALE_HEART_REFORM_DURATION)
	timer.timeout.connect(_on_post_minigame_heart_animation_finished)


func _on_post_minigame_heart_animation_finished() -> void:
	if _finale_triggered:
		return

	if _protagonist != null:
		_protagonist.set_manual_input_enabled(true)

	if _henri_hotspot != null:
		_henri_hotspot.set("active", true)


func _trigger_finale() -> void:
	if _finale_triggered:
		return
	if _finale_chain == null:
		return

	_build_finale_overlay()
	_reset_finale_heart_visuals()

	_finale_triggered = true
	_minigame_opened = false

	if _assembly_minigame != null:
		_assembly_minigame.call("close")

	if _protagonist != null:
		_protagonist.set_manual_input_enabled(false)
		_protagonist.visible = true

	if _henri_hotspot != null:
		_henri_hotspot.set("active", false)

	_finale_chain.clear()
	_finale_chain.add_step(Callable(self, "_step_switch_bgm_to_finale"), 0.2)
	_finale_chain.add_step(Callable(self, "_step_spawn_finale_characters"), FINALE_SPAWN_DURATION)
	_finale_chain.add_step(Callable(self, "_step_photo_pose"), FINALE_PHOTO_POSE_DURATION)
	_finale_chain.add_step(Callable(self, "_step_flash_white"), (FINALE_FLASH_DURATION * 2.0) + 0.05)
	_finale_chain.add_step(Callable(self, "_step_hold_final_frame"), FINALE_FREEZE_DURATION)
	_finale_chain.add_step(Callable(self, "_step_transition_to_final_screen"), 0.0)
	_finale_chain.play()


func _build_finale_overlay() -> void:
	if _finale_overlay_layer != null:
		return

	_finale_overlay_layer = CanvasLayer.new()
	_finale_overlay_layer.name = "FinaleOverlay"
	_finale_overlay_layer.layer = 20
	add_child(_finale_overlay_layer)

	_finale_fade_rect = ColorRect.new()
	_finale_fade_rect.name = "FadeRect"
	_finale_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_finale_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finale_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_finale_fade_rect.offset_left = 0.0
	_finale_fade_rect.offset_top = 0.0
	_finale_fade_rect.offset_right = 0.0
	_finale_fade_rect.offset_bottom = 0.0
	_finale_overlay_layer.add_child(_finale_fade_rect)

	_finale_heart_holder = Node2D.new()
	_finale_heart_holder.name = "FinaleHeartHolder"
	_finale_heart_holder.position = HEART_CENTER
	_finale_heart_holder.visible = false
	_finale_overlay_layer.add_child(_finale_heart_holder)

	var heart_outline: Polygon2D = Polygon2D.new()
	heart_outline.name = "HeartOutline"
	heart_outline.polygon = _build_heart_silhouette()
	heart_outline.scale = Vector2(1.18, 1.18)
	heart_outline.color = Color(1.0, 0.88, 0.95, 0.14)
	_finale_heart_holder.add_child(heart_outline)

	_finale_heart_fragments.clear()
	var piece_polygons: Array[PackedVector2Array] = _build_piece_polygons()
	for index: int in range(TOTAL_HEART_PIECES):
		var fragment: Polygon2D = Polygon2D.new()
		fragment.name = "HeartFragment%02d" % [index + 1]
		fragment.polygon = piece_polygons[index]
		fragment.position = TARGET_OFFSETS[index]
		fragment.color = PIECE_COLORS[index]
		fragment.modulate = Color(1.0, 1.0, 1.0, 0.0)
		fragment.scale = Vector2(0.55, 0.55)
		_finale_heart_holder.add_child(fragment)
		_finale_heart_fragments.append(fragment)

	_finale_heart_full = Polygon2D.new()
	_finale_heart_full.name = "HeartFull"
	_finale_heart_full.polygon = _build_heart_silhouette()
	_finale_heart_full.color = Color(0.98, 0.56, 0.74, 0.0)
	_finale_heart_full.scale = Vector2(0.82, 0.82)
	_finale_heart_holder.add_child(_finale_heart_full)

	_finale_flash_rect = ColorRect.new()
	_finale_flash_rect.name = "FlashRect"
	_finale_flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	_finale_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finale_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_finale_flash_rect.offset_left = 0.0
	_finale_flash_rect.offset_top = 0.0
	_finale_flash_rect.offset_right = 0.0
	_finale_flash_rect.offset_bottom = 0.0
	_finale_overlay_layer.add_child(_finale_flash_rect)


func _build_finale_chain() -> void:
	if _finale_chain != null:
		return

	_finale_chain = EVENT_CHAIN_SCRIPT.new() as EventChain
	_finale_chain.name = "FinaleEventChain"
	add_child(_finale_chain)


func _prepare_finale_scene_state() -> void:
	if _background_after != null:
		_background_after.visible = false
		_background_after.modulate = Color(1.0, 1.0, 1.0, 1.0)

	if _doll != null:
		_doll.visible = false
		_doll.position = FINALE_DOLL_POSITION + Vector2(0.0, FINALE_SPAWN_OFFSET_Y)
		_doll.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_doll.scale = Vector2.ONE

	if _boneca != null:
		_boneca.visible = false
		_boneca.play("default")

	_reset_finale_heart_visuals()


func _step_show_completed_heart() -> void:
	if _finale_heart_holder == null:
		return

	_reset_finale_heart_visuals()
	_finale_heart_holder.visible = true

	var tween: Tween = create_tween()

	for index: int in range(_finale_heart_fragments.size()):
		tween.tween_callback(Callable(self, "_show_heart_fragment").bind(index))
		tween.tween_interval(FINALE_HEART_FILL_STEP_DURATION)

	tween.tween_callback(Callable(self, "_show_full_heart"))
	tween.tween_interval(FINALE_HEART_COMPLETE_HOLD)
	tween.tween_callback(Callable(self, "_hide_finale_heart"))


func _show_heart_fragment(index: int) -> void:
	if index < 0 or index >= _finale_heart_fragments.size():
		return

	var fragment: Polygon2D = _finale_heart_fragments[index]
	fragment.visible = true

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(fragment, "scale", Vector2.ONE, 0.1)
	tween.tween_property(fragment, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)


func _show_full_heart() -> void:
	if _finale_heart_full == null:
		return

	for fragment: Polygon2D in _finale_heart_fragments:
		fragment.visible = false

	_finale_heart_full.visible = true

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_finale_heart_full, "scale", Vector2.ONE, 0.16)
	tween.tween_property(_finale_heart_full, "color", Color(0.98, 0.56, 0.74, 1.0), 0.16)


func _hide_finale_heart() -> void:
	if _finale_heart_holder != null:
		_finale_heart_holder.visible = false


func _reset_finale_heart_visuals() -> void:
	if _finale_heart_holder != null:
		_finale_heart_holder.visible = false

	for fragment: Polygon2D in _finale_heart_fragments:
		fragment.visible = true
		fragment.modulate = Color(1.0, 1.0, 1.0, 0.0)
		fragment.scale = Vector2(0.55, 0.55)

	if _finale_heart_full != null:
		_finale_heart_full.visible = false
		_finale_heart_full.scale = Vector2(0.82, 0.82)
		_finale_heart_full.color = Color(0.98, 0.56, 0.74, 0.0)


func _step_boy_stops_crying() -> void:
	if _henri == null:
		return

	_henri.sprite_frames = _build_sheet_sprite_frames(HENRI_IDLE_TEXTURE, HENRI_IDLE_COLUMNS, HENRI_IDLE_ROWS, &"idle", 9.0)
	_henri.play("idle")
	_henri.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_henri.speed_scale = 1.0


func _step_fade_out_corrupted_scene() -> void:
	if _finale_fade_rect == null:
		return

	var tween: Tween = create_tween()
	tween.tween_property(_finale_fade_rect, "color", Color(0.0, 0.0, 0.0, 1.0), FINALE_FADE_OUT_DURATION)


func _step_switch_bgm_to_finale() -> void:
	var audio_manager: Node = get_node_or_null("/root/AudioManager")
	if audio_manager == null:
		push_warning("Room4 finale: AudioManager nao encontrado.")
		return
	if not audio_manager.has_method("play_bgm"):
		push_warning("Room4 finale: AudioManager sem metodo play_bgm.")
		return

	audio_manager.call("play_bgm", "finale")


func _step_fade_in_peaceful_scene() -> void:
	if _background_before != null:
		_background_before.visible = false

	if _heart_pieces_root != null:
		_heart_pieces_root.visible = false

	if _assembly_area != null:
		_assembly_area.visible = false

	if _background_after != null:
		_background_after.visible = true
		_background_after.modulate = Color(1.0, 1.0, 1.0, 1.0)

	if _finale_fade_rect != null:
		var tween: Tween = create_tween()
		tween.tween_property(_finale_fade_rect, "color", Color(0.0, 0.0, 0.0, 0.0), FINALE_FADE_IN_DURATION)


func _step_spawn_finale_characters() -> void:
	if _crying_boy != null:
		_crying_boy.visible = true
		_crying_boy.position = FINALE_HENRI_POSITION + Vector2(0.0, FINALE_SPAWN_OFFSET_Y)
		_crying_boy.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_crying_boy.scale = Vector2.ONE

	if _doll != null:
		_doll.visible = true
		_doll.position = FINALE_DOLL_POSITION + Vector2(0.0, FINALE_SPAWN_OFFSET_Y)
		_doll.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_doll.scale = Vector2.ONE

	if _boneca != null:
		_boneca.visible = true
		_boneca.play("default")

	var tween: Tween = create_tween()
	tween.set_parallel(true)

	if _crying_boy != null:
		tween.tween_property(_crying_boy, "position", FINALE_HENRI_POSITION, FINALE_SPAWN_DURATION)
		tween.tween_property(_crying_boy, "modulate", Color(1.0, 1.0, 1.0, 1.0), FINALE_SPAWN_DURATION)

	if _doll != null:
		tween.tween_property(_doll, "position", FINALE_DOLL_POSITION, FINALE_SPAWN_DURATION)
		tween.tween_property(_doll, "modulate", Color(1.0, 1.0, 1.0, 1.0), FINALE_SPAWN_DURATION)


func _step_photo_pose() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)

	if _crying_boy != null:
		tween.tween_property(_crying_boy, "scale", Vector2(1.04, 1.04), FINALE_PHOTO_POSE_DURATION)
		tween.tween_property(_crying_boy, "position", FINALE_HENRI_POSITION + Vector2(-8.0, -6.0), FINALE_PHOTO_POSE_DURATION)

	if _doll != null:
		tween.tween_property(_doll, "scale", Vector2(1.04, 1.04), FINALE_PHOTO_POSE_DURATION)
		tween.tween_property(_doll, "position", FINALE_DOLL_POSITION + Vector2(8.0, -6.0), FINALE_PHOTO_POSE_DURATION)


func _step_flash_white() -> void:
	if _finale_flash_rect == null:
		return

	_finale_flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)

	var tween: Tween = create_tween()
	tween.tween_property(_finale_flash_rect, "color", Color(1.0, 1.0, 1.0, 1.0), FINALE_FLASH_DURATION)
	tween.tween_property(_finale_flash_rect, "color", Color(1.0, 1.0, 1.0, 0.0), FINALE_FLASH_DURATION)


func _step_hold_final_frame() -> void:
	return


func _step_transition_to_final_screen() -> void:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager == null:
		push_warning("Room4 finale: GameManager nao encontrado.")
		return
	if not game_manager.has_method("complete_room"):
		push_warning("Room4 finale: GameManager sem metodo complete_room.")
		return

	game_manager.call("complete_room", 4)


func _build_piece_polygons() -> Array[PackedVector2Array]:
	return [
		PackedVector2Array([Vector2(-26, 0), Vector2(-12, -20), Vector2(0, -28), Vector2(12, -20), Vector2(26, 0), Vector2(0, 28)]),
		PackedVector2Array([Vector2(-24, 0), Vector2(-10, -18), Vector2(0, -26), Vector2(10, -18), Vector2(24, 0), Vector2(0, 24)]),
		PackedVector2Array([Vector2(-22, 0), Vector2(-10, -16), Vector2(0, -24), Vector2(10, -16), Vector2(22, 0), Vector2(0, 22)]),
		PackedVector2Array([Vector2(-24, 0), Vector2(-11, -18), Vector2(0, -26), Vector2(11, -18), Vector2(24, 0), Vector2(0, 25)]),
		PackedVector2Array([Vector2(-23, 0), Vector2(-10, -17), Vector2(0, -25), Vector2(10, -17), Vector2(23, 0), Vector2(0, 23)]),
		PackedVector2Array([Vector2(-25, 0), Vector2(-12, -19), Vector2(0, -27), Vector2(12, -19), Vector2(25, 0), Vector2(0, 26)])
	]


func _build_heart_silhouette() -> PackedVector2Array:
	var silhouette: PackedVector2Array = PackedVector2Array()

	for angle_step: int in range(0, 360, 12):
		var radians: float = deg_to_rad(float(angle_step))
		var x: float = 16.0 * pow(sin(radians), 3.0)
		var y: float = -(13.0 * cos(radians) - 5.0 * cos(2.0 * radians) - 2.0 * cos(3.0 * radians) - cos(4.0 * radians))
		silhouette.append(Vector2(x, y) * 10.0)

	return silhouette


func _update_boy_feedback() -> void:
	if _henri == null or _crying_boy == null:
		return

	if _finale_triggered:
		return

	var total_progress_steps: float = float(TOTAL_HEART_PIECES * 2)
	var current_progress: float = float(_pieces_collected + _assembled_pieces)
	var progress: float = clampf(current_progress / total_progress_steps, 0.0, 1.0)

	_crying_boy.scale = Vector2.ONE.lerp(Vector2(1.1, 1.1), progress)
	_henri.modulate = Color(1.0, 0.72 + (0.28 * progress), 0.72 + (0.18 * progress), 1.0)
	_henri.speed_scale = 1.0 - (0.45 * progress)


func _build_sheet_sprite_frames(
	texture: Texture2D,
	columns: int,
	rows: int,
	animation_name: StringName,
	fps: float
) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, true)

	for row: int in range(rows):
		for column: int in range(columns):
			var frame_texture: AtlasTexture = AtlasTexture.new()
			frame_texture.atlas = texture
			frame_texture.region = Rect2(
				float(column) * HENRI_FRAME_SIZE.x,
				float(row) * HENRI_FRAME_SIZE.y,
				HENRI_FRAME_SIZE.x,
				HENRI_FRAME_SIZE.y
			)
			frames.add_frame(animation_name, frame_texture)

	return frames