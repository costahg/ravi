extends Area2D

signal touch_count_changed(touch_count: int)
signal minimum_touches_reached(touch_count: int)

const HEART_PATTERN: PackedStringArray = ["01100110", "11111111", "11111111", "11111111", "01111110", "00111100", "00011000", "00000000"]
const HEART_COLOR: Color = Color(1.0, 0.45, 0.7, 1.0)
const DEFAULT_HITBOX_SIZE: Vector2 = Vector2(220.0, 220.0)
const NEXT_INDICATOR_OFFSET: Vector2 = Vector2(-48.0, -188.0)
const NEXT_INDICATOR_TEXTURE_PATH: String = "res://assets/sprites/key.png"

@export var hitbox_size: Vector2 = DEFAULT_HITBOX_SIZE
@export var required_touches: int = 5
@export var arrival_tolerance: float = 18.0
@export var heart_float_distance: float = 64.0
@export var heart_lifetime: float = 1.0
@export var touch_sfx_variants: Array[AudioStream] = []

@export_group("Roaming")
@export var roam_enabled: bool = true
@export var roam_speed: float = 110.0
@export var roam_pause_min: float = 1.0
@export var roam_pause_max: float = 3.0
@export var roam_step_min: float = 48.0
@export var roam_step_max: float = 180.0
@export var roam_max_travel_duration: float = 1.8

var _protagonist: Node2D
var _touch_count: int = 0
var _interaction_unlocked: bool = false
var _moving_to_target: bool = false
var _warned_missing_sfx: bool = false
var _heart_texture: Texture2D
var _roaming_active: bool = false
var _roaming_loop_running: bool = false
var _roaming_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(540.0, 960.0))
var _roam_tween: Tween
var _baby_visual_base_scale: Vector2 = Vector2.ONE

@onready var _collision_shape: CollisionShape2D = _ensure_collision_shape()
@onready var _next_indicator: TextureRect = _ensure_next_indicator()
@onready var _baby_visual: AnimatedSprite2D = _resolve_baby_visual()


func _enter_tree() -> void:
	_ensure_collision_shape()


func _ready() -> void:
	_ensure_collision_shape()
	input_pickable = false
	monitoring = false
	monitorable = false
	_heart_texture = _build_heart_texture()

	if _baby_visual != null:
		_baby_visual_base_scale = _baby_visual.scale
		if is_zero_approx(_baby_visual_base_scale.x):
			_baby_visual_base_scale.x = 1.0
		if is_zero_approx(_baby_visual_base_scale.y):
			_baby_visual_base_scale.y = 1.0

	_play_baby_animation(&"idle")


func setup(protagonist: Node2D, _target_position: Vector2) -> void:
	_ensure_collision_shape()
	if _protagonist != protagonist:
		_disconnect_protagonist_signal()
		_protagonist = protagonist
		_connect_protagonist_signal()


func configure_roaming_area(viewport_size: Vector2, margin_top: float, margin_bottom: float, margin_left: float, margin_right: float) -> void:
	var safe_width: float = maxf(viewport_size.x - margin_left - margin_right, 1.0)
	var safe_height: float = maxf(viewport_size.y - margin_top - margin_bottom, 1.0)
	_roaming_bounds = Rect2(Vector2(margin_left, margin_top), Vector2(safe_width, safe_height))
	global_position = _clamp_position_to_roaming_bounds(global_position)


func set_interaction_enabled(is_enabled: bool) -> void:
	_ensure_collision_shape()
	input_pickable = is_enabled
	monitoring = is_enabled
	monitorable = is_enabled
	if _collision_shape != null:
		_collision_shape.set_deferred("disabled", not is_enabled)


func set_roaming_enabled(is_enabled: bool) -> void:
	roam_enabled = is_enabled
	_roaming_active = is_enabled

	if not _roaming_active:
		if _roam_tween != null:
			_roam_tween.kill()
			_roam_tween = null
		_play_baby_animation(&"idle")
		return

	if not _roaming_loop_running:
		_run_roaming_loop()


func get_touch_count() -> int:
	return _touch_count


func get_next_indicator() -> TextureRect:
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
	if _protagonist == null or not _protagonist.has_method("move_to_global_position"):
		return

	_moving_to_target = true
	_sync_protagonist_follow_target()


func _sync_protagonist_follow_target() -> void:
	if not _moving_to_target:
		return
	if _protagonist == null or not _protagonist.has_method("move_to_global_position"):
		return

	_protagonist.call("move_to_global_position", global_position)


func _register_touch(screen_position: Vector2) -> void:
	_touch_count += 1
	_spawn_heart(_screen_to_global_position(screen_position))
	_play_touch_sfx()
	touch_count_changed.emit(_touch_count)

	if _touch_count >= required_touches and not _next_indicator.visible:
		_next_indicator.visible = true
		minimum_touches_reached.emit(_touch_count)


func _on_destination_reached(_destination: Vector2) -> void:
	if not _moving_to_target:
		return

	if _protagonist != null and _protagonist.global_position.distance_to(global_position) <= arrival_tolerance:
		_moving_to_target = false
		_interaction_unlocked = true
		return

	_sync_protagonist_follow_target()


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


func _run_roaming_loop() -> void:
	_roaming_loop_running = true

	while _roaming_active and roam_enabled:
		var destination: Vector2 = _pick_next_roaming_position()
		var delta: Vector2 = destination - global_position
		var travel_distance: float = delta.length()

		if travel_distance >= 2.0:
			_update_visual_direction(delta.x)
			_play_baby_animation(&"walk")

			var travel_duration: float = _calculate_travel_duration(travel_distance)
			if _roam_tween != null:
				_roam_tween.kill()

			_roam_tween = create_tween()
			_roam_tween.tween_property(self, "global_position", destination, travel_duration)
			await _roam_tween.finished
			_roam_tween = null

			if _moving_to_target:
				_sync_protagonist_follow_target()

			_play_baby_animation(&"idle")

			var play_time: float = _pick_idle_play_time(travel_duration)
			await get_tree().create_timer(play_time).timeout
			continue

		_play_baby_animation(&"idle")
		await get_tree().create_timer(0.35).timeout

	_roaming_loop_running = false
	_play_baby_animation(&"idle")


func _calculate_travel_duration(travel_distance: float) -> float:
	var speed_duration: float = travel_distance / maxf(roam_speed, 1.0)
	return clampf(speed_duration, 0.12, roam_max_travel_duration)


func _pick_idle_play_time(travel_duration: float) -> float:
	var min_pause: float = maxf(roam_pause_min, travel_duration + 0.1)
	var max_pause: float = maxf(roam_pause_max, min_pause)
	return randf_range(min_pause, max_pause)


func _pick_next_roaming_position() -> Vector2:
	var angle: float = randf_range(0.0, TAU)
	var distance: float = randf_range(roam_step_min, roam_step_max)
	var offset: Vector2 = Vector2.RIGHT.rotated(angle) * distance
	var candidate: Vector2 = global_position + offset
	return _clamp_position_to_roaming_bounds(candidate)


func _clamp_position_to_roaming_bounds(target_position: Vector2) -> Vector2:
	return Vector2(
		clampf(target_position.x, _roaming_bounds.position.x, _roaming_bounds.end.x),
		clampf(target_position.y, _roaming_bounds.position.y, _roaming_bounds.end.y)
	)


func _update_visual_direction(horizontal_delta: float) -> void:
	if _baby_visual == null:
		return

	var scale_x: float = absf(_baby_visual_base_scale.x)
	if scale_x <= 0.0:
		scale_x = 1.0

	if horizontal_delta < -0.5:
		_baby_visual.scale = Vector2(-scale_x, _baby_visual_base_scale.y)
	elif horizontal_delta > 0.5:
		_baby_visual.scale = Vector2(scale_x, _baby_visual_base_scale.y)


func _play_baby_animation(animation_name: StringName) -> void:
	if _baby_visual == null or _baby_visual.sprite_frames == null:
		return
	if not _baby_visual.sprite_frames.has_animation(animation_name):
		return
	if _baby_visual.animation == animation_name and _baby_visual.is_playing():
		return

	_baby_visual.play(animation_name)


func _resolve_baby_visual() -> AnimatedSprite2D:
	for node_variant in find_children("*", "AnimatedSprite2D", true, false):
		var animated_sprite: AnimatedSprite2D = node_variant as AnimatedSprite2D
		if animated_sprite != null:
			return animated_sprite
	return null


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

	rectangle_shape.size = hitbox_size.max(Vector2.ONE)
	collision_shape.shape = rectangle_shape
	collision_shape.disabled = not input_pickable
	return collision_shape


func _ensure_next_indicator() -> TextureRect:
	var next_indicator: TextureRect = get_node_or_null("NextIndicator") as TextureRect
	if next_indicator == null:
		next_indicator = TextureRect.new()
		next_indicator.name = "NextIndicator"
		add_child(next_indicator)

	next_indicator.visible = false
	next_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_indicator.position = NEXT_INDICATOR_OFFSET
	next_indicator.size = Vector2(96.0, 96.0)
	next_indicator.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	next_indicator.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	next_indicator.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	next_indicator.modulate = Color(1.0, 1.0, 1.0, 0.95)

	if ResourceLoader.exists(NEXT_INDICATOR_TEXTURE_PATH):
		next_indicator.texture = load(NEXT_INDICATOR_TEXTURE_PATH) as Texture2D
	else:
		push_warning("BabyInteraction nao encontrou o indicador em %s." % NEXT_INDICATOR_TEXTURE_PATH)

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