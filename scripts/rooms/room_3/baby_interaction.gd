extends Area2D

signal touch_count_changed(touch_count: int)
signal minimum_touches_reached(touch_count: int)

const HEART_PATTERN: PackedStringArray = ["01100110", "11111111", "11111111", "11111111", "01111110", "00111100", "00011000", "00000000"]
const HEART_COLOR: Color = Color(1.0, 0.45, 0.7, 1.0)
const HITBOX_SIZE: Vector2 = Vector2(220.0, 220.0)
const NEXT_INDICATOR_OFFSET: Vector2 = Vector2(-36.0, -180.0)

@export var required_touches: int = 5
@export var arrival_tolerance: float = 18.0
@export var heart_float_distance: float = 64.0
@export var heart_lifetime: float = 1.0
@export var touch_sfx_variants: Array[AudioStream] = []

var _protagonist: Node2D
var _target_position: Vector2 = Vector2.ZERO
var _touch_count: int = 0
var _interaction_unlocked: bool = false
var _moving_to_target: bool = false
var _warned_missing_sfx: bool = false
var _heart_texture: Texture2D

@onready var _collision_shape: CollisionShape2D = _ensure_collision_shape()
@onready var _next_indicator: Button = _ensure_next_indicator()

func _ready() -> void:
	input_pickable = false
	monitoring = false
	monitorable = false
	_heart_texture = _build_heart_texture()

func setup(protagonist: Node2D, target_position: Vector2) -> void:
	if _protagonist != protagonist:
		_disconnect_protagonist_signal()
		_protagonist = protagonist
		_connect_protagonist_signal()
	_target_position = target_position

func set_interaction_enabled(is_enabled: bool) -> void:
	input_pickable = is_enabled
	monitoring = is_enabled
	monitorable = is_enabled

func get_touch_count() -> int:
	return _touch_count

func get_next_indicator() -> Button:
	return _next_indicator

func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var press_position: Variant = _extract_press_position(event)
	if press_position == null:
		return
	if not _interaction_unlocked:
		_request_approach()
		return
	_register_touch(press_position as Vector2)

func _request_approach() -> void:
	if _moving_to_target or _protagonist == null or not _protagonist.has_method("move_to_global_position"):
		return
	_moving_to_target = true
	_protagonist.call("move_to_global_position", _target_position)

func _register_touch(screen_position: Vector2) -> void:
	_touch_count += 1
	_spawn_heart(_screen_to_global_position(screen_position))
	_play_touch_sfx()
	touch_count_changed.emit(_touch_count)
	if _touch_count >= required_touches and not _next_indicator.visible:
		_next_indicator.visible = true
		minimum_touches_reached.emit(_touch_count)

func _on_destination_reached(destination: Vector2) -> void:
	if not _moving_to_target:
		return
	_moving_to_target = false
	if destination.distance_to(_target_position) > arrival_tolerance:
		return
	_interaction_unlocked = true

func _connect_protagonist_signal() -> void:
	if _protagonist == null or not _protagonist.has_signal("destination_reached"):
		return
	var callback: Callable = Callable(self, "_on_destination_reached")
	if not _protagonist.is_connected("destination_reached", callback):
		_protagonist.connect("destination_reached", callback)

func _disconnect_protagonist_signal() -> void:
	if _protagonist == null or not _protagonist.has_signal("destination_reached"):
		return
	var callback: Callable = Callable(self, "_on_destination_reached")
	if _protagonist.is_connected("destination_reached", callback):
		_protagonist.disconnect("destination_reached", callback)

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

func _screen_to_global_position(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position

func _spawn_heart(global_position_at_touch: Vector2) -> void:
	if _heart_texture == null:
		return
	var heart: Sprite2D = Sprite2D.new()
	heart.texture = _heart_texture
	heart.scale = Vector2(4.0, 4.0)
	heart.centered = true
	heart.z_index = 20
	heart.global_position = global_position_at_touch
	get_parent().add_child(heart)
	var tween: Tween = heart.create_tween()
	tween.parallel().tween_property(heart, "global_position:y", heart.global_position.y - heart_float_distance, heart_lifetime)
	tween.parallel().tween_property(heart, "modulate:a", 0.0, heart_lifetime)
	tween.tween_callback(Callable(heart, "queue_free"))

func _play_touch_sfx() -> void:
	if touch_sfx_variants.is_empty():
		if not _warned_missing_sfx:
			_warned_missing_sfx = true
			push_warning("BabyInteraction sem touch_sfx_variants configurados.")
		return
	var audio_manager: Node = get_node_or_null("/root/AudioManager")
	if audio_manager == null or not audio_manager.has_method("play_sfx"):
		return
	var selected_sfx: AudioStream = touch_sfx_variants[randi() % touch_sfx_variants.size()]
	if selected_sfx == null:
		return
	audio_manager.call("play_sfx", selected_sfx)

func _ensure_collision_shape() -> CollisionShape2D:
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		add_child(collision_shape)
	var rectangle_shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
	if rectangle_shape == null:
		rectangle_shape = RectangleShape2D.new()
		collision_shape.shape = rectangle_shape
	rectangle_shape.size = HITBOX_SIZE
	collision_shape.shape = rectangle_shape
	return collision_shape

func _ensure_next_indicator() -> Button:
	var next_indicator: Button = get_node_or_null("NextIndicator") as Button
	if next_indicator == null:
		next_indicator = Button.new()
		next_indicator.name = "NextIndicator"
		add_child(next_indicator)
	next_indicator.visible = false
	next_indicator.disabled = true
	next_indicator.focus_mode = Control.FOCUS_NONE
	next_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_indicator.text = "→"
	next_indicator.position = NEXT_INDICATOR_OFFSET
	next_indicator.size = Vector2(72.0, 72.0)
	next_indicator.modulate = Color(1.0, 1.0, 1.0, 0.9)
	next_indicator.add_theme_font_size_override("font_size", 42)
	next_indicator.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	next_indicator.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	next_indicator.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
	next_indicator.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, 1.0))
	next_indicator.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	next_indicator.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	next_indicator.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	next_indicator.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	return next_indicator

func _build_heart_texture() -> Texture2D:
	var image: Image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y in range(HEART_PATTERN.size()):
		var row: String = HEART_PATTERN[y]
		for x in range(row.length()):
			if row[x] == "1":
				image.set_pixel(x, y, HEART_COLOR)
	return ImageTexture.create_from_image(image)
