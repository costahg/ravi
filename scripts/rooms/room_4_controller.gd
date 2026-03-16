extends Node2D

const TOTAL_HEART_PIECES := 6
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
const HEART_CENTER := Vector2(270, 430)
const BOARD_SCALE := 1.55
const ARRIVAL_TOLERANCE := 24.0

const HEART_ASSEMBLY_MINIGAME_SCRIPT: Script = preload("res://scripts/rooms/room_4/heart_assembly_minigame.gd")

@onready var _protagonist: Node2D = $Protagonist
@onready var _assembly_area: Node2D = $AssemblyArea
@onready var _assembly_hotspot: Area2D = $AssemblyArea/AssemblyHotspot
@onready var _crying_boy: Node2D = $CryingBoy
@onready var _henri: AnimatedSprite2D = $CryingBoy/Henri
@onready var _heart_pieces_root: Node = $HeartPieces

var _pieces_collected := 0
var _assembled_pieces := 0
var _collected_piece_ids: Dictionary = {}
var _assembled_piece_ids: Dictionary = {}
var _awaiting_assembly_arrival := false
var _assembly_unlocked := false
var _minigame_opened := false
var _assembly_completed := false
var _assembly_minigame: CanvasLayer
var _pending_piece_id := ""
var _pending_piece_node: Node2D
var _pending_piece_target := Vector2.ZERO
var _carried_heart: Node2D


func _ready() -> void:
	if _protagonist != null and not _protagonist.destination_reached.is_connected(_on_protagonist_destination_reached):
		_protagonist.destination_reached.connect(_on_protagonist_destination_reached)

	if _assembly_hotspot != null:
		if not _assembly_hotspot.pressed.is_connected(_on_assembly_hotspot_pressed):
			_assembly_hotspot.pressed.connect(_on_assembly_hotspot_pressed)
		_assembly_hotspot.set("active", false)

	_connect_piece_hotspots()
	_build_carried_heart()
	_build_minigame()
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

	var total_progress_steps: float = float(TOTAL_HEART_PIECES * 2)
	var current_progress: float = float(_pieces_collected + _assembled_pieces)
	var progress: float = clampf(current_progress / total_progress_steps, 0.0, 1.0)

	_crying_boy.scale = Vector2.ONE.lerp(Vector2(1.1, 1.1), progress)
	_henri.modulate = Color(1.0, 0.72 + (0.28 * progress), 0.72 + (0.18 * progress), 1.0)
	_henri.speed_scale = 1.0 - (0.45 * progress)