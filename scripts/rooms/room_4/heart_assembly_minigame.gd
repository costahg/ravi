class_name HeartAssemblyMinigame
extends CanvasLayer

signal piece_placed(piece_id: String, zone_id: String)
signal assembly_completed()

const DRAGGABLE_SCRIPT: Script = preload("res://scripts/components/draggable.gd")
const DROP_ZONE_SCRIPT: Script = preload("res://scripts/components/drop_zone.gd")

const TARGET_OFFSETS: Array[Vector2] = [
	Vector2(-78, -78),
	Vector2(78, -78),
	Vector2(-126, -4),
	Vector2(126, -4),
	Vector2(-62, 96),
	Vector2(62, 96)
]

var _heart_center: Vector2 = Vector2.ZERO
var _board_scale: float = 1.0
var _piece_polygons: Array[PackedVector2Array] = []
var _start_positions: Array[Vector2] = []
var _piece_colors: Array[Color] = []

var _built: bool = false
var _placed_piece_ids: Dictionary = {}
var _filled_zone_ids: Dictionary = {}
var _required_piece_count: int = 0


func setup(
	heart_center: Vector2,
	board_scale: float,
	piece_polygons: Array[PackedVector2Array],
	start_positions: Array[Vector2],
	piece_colors: Array[Color]
) -> void:
	_heart_center = heart_center
	_board_scale = board_scale
	_piece_polygons = piece_polygons
	_start_positions = start_positions
	_piece_colors = piece_colors

	if is_inside_tree():
		_rebuild()


func open() -> void:
	visible = true


func close() -> void:
	visible = false


func _ready() -> void:
	visible = false
	if not _built and not _piece_polygons.is_empty():
		_rebuild()


func _rebuild() -> void:
	_clear_children()
	_built = true
	_placed_piece_ids.clear()
	_filled_zone_ids.clear()

	_required_piece_count = min(
		min(_piece_polygons.size(), _start_positions.size()),
		min(_piece_colors.size(), TARGET_OFFSETS.size())
	)

	var dim: ColorRect = ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var board_root: Node2D = Node2D.new()
	board_root.name = "BoardRoot"
	add_child(board_root)

	var heart_shadow: Polygon2D = Polygon2D.new()
	heart_shadow.name = "HeartShadow"
	heart_shadow.polygon = _build_heart_silhouette()
	heart_shadow.position = _heart_center
	heart_shadow.scale = Vector2(_board_scale, _board_scale)
	heart_shadow.color = Color(0.07, 0.03, 0.04, 0.92)
	board_root.add_child(heart_shadow)

	for index: int in range(_required_piece_count):
		var zone_id: String = "heart_slot_%02d" % [index + 1]
		var drag_id: String = "heart_piece_%02d" % [index + 1]
		var slot_position: Vector2 = _heart_center + TARGET_OFFSETS[index]

		board_root.add_child(_create_slot(zone_id, slot_position))
		board_root.add_child(
			_create_piece(
				drag_id,
				_piece_polygons[index],
				_piece_colors[index],
				_start_positions[index]
			)
		)


func _create_slot(zone_id: String, target_position: Vector2) -> Area2D:
	var slot: Area2D = Area2D.new()
	slot.name = zone_id
	slot.position = target_position
	slot.set_script(DROP_ZONE_SCRIPT)
	slot.set("zone_id", zone_id)
	slot.monitoring = true
	slot.monitorable = true

	var glow: Polygon2D = Polygon2D.new()
	glow.name = "Glow"
	glow.polygon = _build_slot_polygon()
	glow.color = Color(1.0, 0.78, 0.9, 0.22)
	slot.add_child(glow)

	var collision: CollisionPolygon2D = CollisionPolygon2D.new()
	collision.polygon = _scale_polygon(_build_slot_polygon(), 1.18)
	slot.add_child(collision)

	return slot


func _create_piece(
	drag_id: String,
	piece_polygon: PackedVector2Array,
	piece_color: Color,
	start_position: Vector2
) -> Area2D:
	var piece: Area2D = Area2D.new()
	piece.name = drag_id
	piece.position = start_position
	piece.set_script(DRAGGABLE_SCRIPT)
	piece.set("drag_id", drag_id)
	piece.set("snap_back", true)
	piece.set("active", true)
	piece.z_index = 10

	var polygon: Polygon2D = Polygon2D.new()
	polygon.name = "Visual"
	polygon.polygon = piece_polygon
	polygon.color = piece_color
	piece.add_child(polygon)

	var collision: CollisionPolygon2D = CollisionPolygon2D.new()
	collision.polygon = _scale_polygon(piece_polygon, 1.35)
	piece.add_child(collision)

	piece.dropped_on_target.connect(_on_piece_dropped.bind(piece))

	return piece


func _on_piece_dropped(piece_id: String, target_area: Area2D, piece: Area2D) -> void:
	if piece_id == "" or target_area == null or piece == null:
		return
	if _placed_piece_ids.has(piece_id):
		return

	var zone_id: String = str(target_area.get("zone_id"))
	if zone_id == "":
		return
	if _filled_zone_ids.has(zone_id):
		_snap_piece_back(piece)
		return

	_filled_zone_ids[zone_id] = true
	_placed_piece_ids[piece_id] = true

	piece.set("active", false)
	piece.monitoring = false
	piece.monitorable = false
	piece.global_position = target_area.global_position
	piece.z_index = 1

	var visual: Polygon2D = piece.get_node_or_null("Visual") as Polygon2D
	if visual != null:
		visual.color = visual.color.lightened(0.12)

	var glow: Polygon2D = target_area.get_node_or_null("Glow") as Polygon2D
	if glow != null:
		glow.visible = false

	target_area.monitoring = false
	target_area.monitorable = false

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(piece, "scale", Vector2(1.08, 1.08), 0.1)
	tween.tween_property(piece, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)
	tween.chain().tween_property(piece, "scale", Vector2.ONE, 0.12)

	piece_placed.emit(piece_id, zone_id)

	if _placed_piece_ids.size() >= _required_piece_count:
		assembly_completed.emit()


func _snap_piece_back(piece: Area2D) -> void:
	if piece == null:
		return

	var origin: Vector2 = piece.global_position
	if "snap_back" in piece and bool(piece.get("snap_back")):
		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(piece, "global_position", origin, 0.01)


func _clear_children() -> void:
	for child: Node in get_children():
		child.queue_free()


func _build_heart_silhouette() -> PackedVector2Array:
	var silhouette: PackedVector2Array = PackedVector2Array()

	for angle_step: int in range(0, 360, 12):
		var radians: float = deg_to_rad(float(angle_step))
		var x: float = 16.0 * pow(sin(radians), 3.0)
		var y: float = -(13.0 * cos(radians) - 5.0 * cos(2.0 * radians) - 2.0 * cos(3.0 * radians) - cos(4.0 * radians))
		silhouette.append(Vector2(x, y) * 10.0)

	return silhouette


func _build_slot_polygon() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-28, 0),
		Vector2(-14, -18),
		Vector2(0, -24),
		Vector2(14, -18),
		Vector2(28, 0),
		Vector2(0, 28)
	])


func _scale_polygon(source: PackedVector2Array, factor: float) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()

	for point: Vector2 in source:
		result.append(point * factor)

	return result