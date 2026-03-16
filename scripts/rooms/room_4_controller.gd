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
	Vector2(140, 860),
	Vector2(210, 860),
	Vector2(280, 860),
	Vector2(350, 860),
	Vector2(420, 860),
	Vector2(490, 860)
]
const HEART_CENTER: Vector2 = Vector2(270, 430)
const BOARD_SCALE: float = 2.8
const DRAGGABLE_SCRIPT: Script = preload("res://scripts/components/draggable.gd")

@onready var _protagonist: Node2D = $Protagonist
@onready var _assembly_area: Node2D = $AssemblyArea
@onready var _assembly_hotspot: Area2D = $AssemblyArea/AssemblyHotspot
@onready var _crying_boy: Node2D = $CryingBoy
@onready var _henri: AnimatedSprite2D = $CryingBoy/Henri

var _pieces_collected: int = 0
var _collected_piece_ids: Dictionary = {}
var _awaiting_assembly_arrival: bool = false
var _assembly_unlocked: bool = false
var _minigame_opened: bool = false
var _minigame_layer: CanvasLayer

func _ready() -> void:
	_connect_signal(_protagonist, &"destination_reached", &"_on_protagonist_destination_reached")
	_connect_signal(_assembly_hotspot, &"pressed", &"_on_assembly_hotspot_pressed")
	if _assembly_hotspot != null:
		_assembly_hotspot.set("active", false)
	_build_minigame_layer()
	_update_boy_feedback()

func notify_piece_collected(piece_id: String, piece_node: Node2D) -> void:
	if piece_id == "" or _collected_piece_ids.has(piece_id):
		return

	_collected_piece_ids[piece_id] = true
	_pieces_collected = _collected_piece_ids.size()

	if piece_node != null:
		piece_node.visible = false
		piece_node.process_mode = Node.PROCESS_MODE_DISABLED

	_update_boy_feedback()

	if _pieces_collected >= TOTAL_HEART_PIECES:
		_unlock_assembly_area()

func are_all_pieces_collected() -> bool:
	return _pieces_collected >= TOTAL_HEART_PIECES

func get_pieces_collected() -> int:
	return _pieces_collected

func _on_assembly_hotspot_pressed(_hotspot_id: String) -> void:
	if not are_all_pieces_collected():
		return
	if _awaiting_assembly_arrival or _minigame_opened:
		return
	if _protagonist == null or _assembly_area == null:
		return

	_awaiting_assembly_arrival = true
	_protagonist.set_manual_input_enabled(false)
	_protagonist.consume_next_press()
	_protagonist.move_to_global_position(_assembly_area.global_position)

func _on_protagonist_destination_reached(destination: Vector2) -> void:
	if not _awaiting_assembly_arrival:
		return
	if _assembly_area == null:
		return
	if destination.distance_to(_assembly_area.global_position) > 24.0:
		return

	_awaiting_assembly_arrival = false
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

func _open_minigame() -> void:
	if _minigame_opened or _minigame_layer == null:
		return

	_minigame_opened = true
	_minigame_layer.visible = true

	if _protagonist != null:
		_protagonist.set_manual_input_enabled(false)

func _build_minigame_layer() -> void:
	_minigame_layer = CanvasLayer.new()
	_minigame_layer.name = "MinigameLayer"
	_minigame_layer.visible = false
	add_child(_minigame_layer)

	var dim: ColorRect = ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_minigame_layer.add_child(dim)

	var board_root: Node2D = Node2D.new()
	board_root.name = "BoardRoot"
	_minigame_layer.add_child(board_root)

	var heart_shadow: Polygon2D = Polygon2D.new()
	heart_shadow.name = "HeartShadow"
	heart_shadow.polygon = _build_heart_silhouette()
	heart_shadow.global_position = HEART_CENTER
	heart_shadow.scale = Vector2(BOARD_SCALE, BOARD_SCALE)
	heart_shadow.color = Color(0.07, 0.03, 0.04, 0.92)
	board_root.add_child(heart_shadow)

	var piece_polygons: Array[PackedVector2Array] = _build_piece_polygons()
	for index: int in range(piece_polygons.size()):
		board_root.add_child(_create_minigame_piece(index, piece_polygons[index]))

func _create_minigame_piece(index: int, piece_polygon: PackedVector2Array) -> Area2D:
	var piece: Area2D = Area2D.new()
	piece.name = "MinigamePiece%02d" % [index + 1]
	piece.global_position = MINIGAME_POSITIONS[index]
	piece.set_script(DRAGGABLE_SCRIPT)
	piece.set("drag_id", "heart_piece_%02d" % [index + 1])

	var polygon: Polygon2D = Polygon2D.new()
	polygon.polygon = piece_polygon
	polygon.color = PIECE_COLORS[index]
	piece.add_child(polygon)

	var collision: CollisionPolygon2D = CollisionPolygon2D.new()
	collision.polygon = piece_polygon
	piece.add_child(collision)

	return piece

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

	var progress: float = clampf(float(_pieces_collected) / float(TOTAL_HEART_PIECES), 0.0, 1.0)
	_crying_boy.scale = Vector2.ONE.lerp(Vector2(1.08, 1.08), progress)
	_henri.modulate = Color(1.0, 0.72 + (0.28 * progress), 0.72 + (0.18 * progress), 1.0)
	_henri.speed_scale = 1.0 - (0.35 * progress)

func _connect_signal(node: Object, signal_name: StringName, method_name: StringName) -> void:
	if node == null or not node.has_signal(signal_name):
		return

	var callback: Callable = Callable(self, method_name)
	if not node.is_connected(signal_name, callback):
		node.connect(signal_name, callback)
