#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$(git rev-parse --show-toplevel)"
cp scripts/rooms/room_3/player_dodge.gd scripts/rooms/room_3/player_dodge.gd.bak
cp scripts/rooms/room_3/baby_interaction.gd scripts/rooms/room_3/baby_interaction.gd.bak
cp scripts/rooms/room_3_controller.gd scripts/rooms/room_3_controller.gd.bak
cp scenes/rooms/room_3.tscn scenes/rooms/room_3.tscn.bak
cat > scripts/rooms/room_3/player_dodge.gd <<'EOF_PLAYER_DODGE'
extends "res://scripts/components/protagonist_actor.gd"

signal hit

const PROJECTILE_GROUP: StringName = &"projectile"

@onready var _hitbox: Area2D = $Hitbox

var _active_touch_index: int = -1
var _last_global_position: Vector2 = Vector2.ZERO
var _dodge_input_enabled: bool = true


func _ready() -> void:
	super._ready()
	_last_global_position = global_position
	_connect_hitbox()


func _input(event: InputEvent) -> void:
	if not _manual_input_enabled:
		return

	if not _dodge_input_enabled:
		super._input(event)
		return

	if event is InputEventMouseMotion:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		_follow_screen_position(mouse_motion.position)
		return

	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			_follow_screen_position(mouse_button.position)
		return

	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed and (_active_touch_index == -1 or _active_touch_index == touch_event.index):
			_active_touch_index = touch_event.index
			_follow_screen_position(touch_event.position)
			return

		if not touch_event.pressed and touch_event.index == _active_touch_index:
			_active_touch_index = -1
		return

	if event is InputEventScreenDrag:
		var drag_event: InputEventScreenDrag = event as InputEventScreenDrag
		if _active_touch_index == -1:
			_active_touch_index = drag_event.index

		if drag_event.index == _active_touch_index:
			_follow_screen_position(drag_event.position)


func _physics_process(_delta: float) -> void:
	if not _dodge_input_enabled:
		super._physics_process(_delta)
		_last_global_position = global_position
		return

	var movement_delta: Vector2 = global_position - _last_global_position
	if movement_delta.length_squared() > 0.01:
		_update_facing_direction(movement_delta)
		_play_animation(ANIMATION_WALKING)
	else:
		_play_animation(ANIMATION_IDLE)

	_last_global_position = global_position


func set_dodge_input_enabled(is_enabled: bool) -> void:
	_dodge_input_enabled = is_enabled
	_active_touch_index = -1
	_last_global_position = global_position


func _connect_hitbox() -> void:
	if _hitbox == null:
		push_warning("PlayerDodge nao encontrou o node Hitbox na protagonista da Sala 3.")
		return

	var on_area_entered: Callable = Callable(self, "_on_hitbox_area_entered")
	if not _hitbox.is_connected("area_entered", on_area_entered):
		_hitbox.connect("area_entered", on_area_entered)


func _follow_screen_position(screen_position: Vector2) -> void:
	global_position = _clamp_to_margins(_screen_to_global_position(screen_position))
	_destination = global_position
	_is_moving = false


func _on_hitbox_area_entered(area: Area2D) -> void:
	if area == null:
		return

	if not area.is_in_group(PROJECTILE_GROUP):
		return

	hit.emit()

EOF_PLAYER_DODGE
cat > scripts/rooms/room_3/baby_interaction.gd <<'EOF_BABY_INTERACTION'
extends Area2D

signal touch_count_changed(touch_count: int)
signal minimum_touches_reached(touch_count: int)

const HEART_PATTERN: PackedStringArray = ["01100110", "11111111", "11111111", "11111111", "01111110", "00111100", "00011000", "00000000"]
const HEART_COLOR: Color = Color(1.0, 0.45, 0.7, 1.0)
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

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _next_indicator: Button = _ensure_next_indicator()


func _ready() -> void:
	input_pickable = false
	monitoring = false
	monitorable = false
	if _collision_shape != null:
		_collision_shape.disabled = false
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
	if _collision_shape != null:
		_collision_shape.disabled = not is_enabled


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


func _ensure_next_indicator() -> Button:
	var next_indicator: Button = get_node_or_null("NextIndicator") as Button
	if next_indicator == null:
		next_indicator = Button.new()
		next_indicator.name = "NextIndicator"
		add_child(next_indicator)

	next_indicator.text = "→"
	next_indicator.flat = true
	next_indicator.visible = false
	next_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_indicator.focus_mode = Control.FOCUS_NONE
	next_indicator.position = NEXT_INDICATOR_OFFSET
	next_indicator.custom_minimum_size = Vector2(72.0, 72.0)
	next_indicator.add_theme_font_size_override("font_size", 46)
	next_indicator.add_theme_color_override("font_color", Color(1.0, 0.9, 0.65, 1.0))
	next_indicator.add_theme_color_override("font_focus_color", Color(1.0, 0.9, 0.65, 1.0))
	next_indicator.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.65, 1.0))
	return next_indicator


func _build_heart_texture() -> Texture2D:
	var image: Image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))

	for y: int in HEART_PATTERN.size():
		var row: String = HEART_PATTERN[y]
		for x: int in row.length():
			if row.substr(x, 1) == "1":
				image.set_pixel(x, y, HEART_COLOR)

	return ImageTexture.create_from_image(image)

EOF_BABY_INTERACTION
cat > scripts/rooms/room_3_controller.gd <<'EOF_ROOM3_CONTROLLER'
extends Node2D

const HOSPITAL_BACKGROUND_TEXTURE_PATH: String = "res://assets/sprites/Hospital-11024x1536_6C4L.png"
const HOSPITAL_BACKGROUND_COLUMNS: int = 6
const HOSPITAL_BACKGROUND_ROWS: int = 4
const HOSPITAL_BACKGROUND_FRAME_SIZE: Vector2 = Vector2(1024.0, 1536.0)
const HOSPITAL_BACKGROUND_FPS: float = 12.0
const NURSERY_BACKGROUND_TEXTURE_PATH: String = "res://assets/sprites/RaviRoom-11024x1536_6C4L.png"
const NURSERY_BACKGROUND_COLUMNS: int = 6
const NURSERY_BACKGROUND_ROWS: int = 4
const NURSERY_BACKGROUND_FRAME_SIZE: Vector2 = Vector2(1024.0, 1536.0)
const NURSERY_BACKGROUND_FPS: float = 12.0
const RAVI_IDLE_TEXTURE_PATH: String = "res://assets/sprites/RaviFunny-1256x256_7C7L.png"
const RAVI_IDLE_COLUMNS: int = 7
const RAVI_IDLE_ROWS: int = 7
const RAVI_IDLE_FRAME_SIZE: Vector2 = Vector2(256.0, 256.0)
const RAVI_IDLE_FPS: float = 10.0
const PROJECTILE_GROUP: StringName = &"projectile"
const HIT_FLASH_COLOR: Color = Color(1.0, 0.35, 0.35, 1.0)
const HIT_FLASH_DURATION: float = 0.08
const HIT_RECOVER_DURATION: float = 0.18
const HIT_INVULNERABILITY_DURATION: float = 0.5
const PROJECTILE_FADE_DURATION: float = 0.25
const HOSPITAL_FADE_DURATION: float = 0.6
const NURSERY_FADE_DURATION: float = 0.8
const RAVI_REVEAL_DURATION: float = 0.6
const NURSERY_BGM_TARGET_VOLUME_DB: float = -8.0

@export var survival_duration: float = 15.0

@onready var _canvas_layer: CanvasLayer = $CanvasLayer
@onready var _hospital_background: AnimatedSprite2D = $CanvasLayer/HospitalBackground
@onready var _protagonist: Node2D = $CanvasLayer/Protagonist
@onready var _survival_timer: Timer = $CanvasLayer/SurvivalTimer
@onready var _bullet_spawner: Node = get_node_or_null("CanvasLayer/BulletSpawner") as Node
@onready var _doctor: AnimatedSprite2D = get_node_or_null("CanvasLayer/Doctor") as AnimatedSprite2D
@onready var _doctor_timer_label: Label = get_node_or_null("CanvasLayer/Doctor/TimerLabel") as Label
@onready var _ravi_sprite: AnimatedSprite2D = get_node_or_null("CanvasLayer/Ravi") as AnimatedSprite2D
@onready var _baby_interaction: Area2D = get_node_or_null("CanvasLayer/Ravi/BabyInteraction") as Area2D

var _default_protagonist_modulate: Color = Color.WHITE
var _hit_flash_tween: Tween
var _hit_invulnerable: bool = false
var _survival_phase_finished: bool = false
var _nursery_transition_started: bool = false
var _nursery_background: AnimatedSprite2D
var _ravi_base_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	_default_protagonist_modulate = _protagonist.modulate
	if _ravi_sprite != null:
		_ravi_base_scale = _ravi_sprite.scale
	_configure_hospital_background()
	_configure_survival_timer()
	_connect_survival_phase()
	_configure_doctor_timer_label()
	_prepare_nursery_nodes()
	_start_bullet_spawner()


func _process(_delta: float) -> void:
	_update_doctor_timer_label()


func _configure_hospital_background() -> void:
	if _hospital_background == null:
		push_warning("Room3Controller nao encontrou CanvasLayer/HospitalBackground.")
		return

	var hospital_frames: SpriteFrames = _build_sprite_frames(
		HOSPITAL_BACKGROUND_TEXTURE_PATH,
		&"hospital_loop",
		HOSPITAL_BACKGROUND_COLUMNS,
		HOSPITAL_BACKGROUND_ROWS,
		HOSPITAL_BACKGROUND_FRAME_SIZE,
		HOSPITAL_BACKGROUND_FPS,
		true
	)
	if hospital_frames == null:
		return

	_hospital_background.sprite_frames = hospital_frames
	_hospital_background.animation = &"hospital_loop"
	_hospital_background.frame = 0
	_hospital_background.frame_progress = 0.0
	_hospital_background.play(&"hospital_loop")


func _configure_survival_timer() -> void:
	if _survival_timer == null:
		push_warning("Room3Controller nao encontrou CanvasLayer/SurvivalTimer.")
		return

	_survival_timer.one_shot = true
	_survival_timer.autostart = false
	_survival_timer.wait_time = maxf(survival_duration, 0.1)
	_survival_timer.start()


func _connect_survival_phase() -> void:
	if _protagonist != null and _protagonist.has_signal("hit"):
		var on_hit: Callable = Callable(self, "_on_protagonist_hit")
		if not _protagonist.is_connected("hit", on_hit):
			_protagonist.connect("hit", on_hit)

	if _survival_timer == null:
		return

	var on_timeout: Callable = Callable(self, "_on_survival_timer_timeout")
	if not _survival_timer.is_connected("timeout", on_timeout):
		_survival_timer.connect("timeout", on_timeout)


func _start_bullet_spawner() -> void:
	if _bullet_spawner == null:
		push_warning("Room3Controller nao encontrou CanvasLayer/BulletSpawner.")
		return

	if _bullet_spawner.has_method("start_spawning"):
		_bullet_spawner.call("start_spawning")


func _stop_bullet_spawner() -> void:
	if _bullet_spawner == null:
		return

	if _bullet_spawner.has_method("stop_spawning"):
		_bullet_spawner.call("stop_spawning")


func _configure_doctor_timer_label() -> void:
	if _doctor_timer_label == null:
		push_warning("Room3Controller nao encontrou CanvasLayer/Doctor/TimerLabel.")
		return

	_doctor_timer_label.add_theme_font_size_override("font_size", 64)
	_doctor_timer_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.9, 1.0))
	_doctor_timer_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_doctor_timer_label.add_theme_constant_override("outline_size", 14)
	_doctor_timer_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	_doctor_timer_label.add_theme_constant_override("shadow_outline_size", 8)
	_doctor_timer_label.add_theme_constant_override("shadow_offset_x", 0)
	_doctor_timer_label.add_theme_constant_override("shadow_offset_y", 4)
	_update_doctor_timer_label()


func _update_doctor_timer_label() -> void:
	if _doctor_timer_label == null or _survival_timer == null:
		return

	if _survival_phase_finished:
		_doctor_timer_label.text = "0.0"
		return

	var seconds_left: float = maxf(_survival_timer.time_left, 0.0)
	_doctor_timer_label.text = "%.1f" % seconds_left


func _on_protagonist_hit() -> void:
	if _hit_invulnerable or _survival_phase_finished:
		return

	_hit_invulnerable = true
	_play_hit_flash()
	await get_tree().create_timer(HIT_INVULNERABILITY_DURATION).timeout
	_hit_invulnerable = false


func _play_hit_flash() -> void:
	if _protagonist == null:
		return

	if _hit_flash_tween != null:
		_hit_flash_tween.kill()

	_protagonist.modulate = _default_protagonist_modulate
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(_protagonist, "modulate", HIT_FLASH_COLOR, HIT_FLASH_DURATION)
	_hit_flash_tween.tween_property(_protagonist, "modulate", _default_protagonist_modulate, HIT_RECOVER_DURATION)


func _on_survival_timer_timeout() -> void:
	if _survival_phase_finished:
		return

	_survival_phase_finished = true
	set_process(false)
	_stop_bullet_spawner()
	if _protagonist != null and _protagonist.has_method("set_dodge_input_enabled"):
		_protagonist.call("set_dodge_input_enabled", false)
	if _protagonist != null and _protagonist.has_method("stop"):
		_protagonist.call("stop")

	if not get_tree().get_nodes_in_group(PROJECTILE_GROUP).is_empty():
		await _fade_out_projectiles()

	_transition_to_nursery()


func _fade_out_projectiles() -> void:
	for projectile_variant in get_tree().get_nodes_in_group(PROJECTILE_GROUP):
		var projectile: Area2D = projectile_variant as Area2D
		if projectile == null or projectile.is_queued_for_deletion():
			continue

		projectile.set_process(false)
		projectile.monitoring = false
		projectile.monitorable = false
		_disable_projectile_collisions(projectile)

		var fade_tween: Tween = create_tween()
		fade_tween.tween_property(projectile, "modulate:a", 0.0, PROJECTILE_FADE_DURATION)
		fade_tween.tween_callback(Callable(projectile, "queue_free"))

	await get_tree().create_timer(PROJECTILE_FADE_DURATION).timeout

	for projectile_variant in get_tree().get_nodes_in_group(PROJECTILE_GROUP):
		var projectile: Node = projectile_variant as Node
		if projectile != null and is_instance_valid(projectile):
			projectile.queue_free()


func _disable_projectile_collisions(projectile: Area2D) -> void:
	for child in projectile.get_children():
		var collision_shape: CollisionShape2D = child as CollisionShape2D
		if collision_shape != null:
			collision_shape.set_deferred("disabled", true)


func _transition_to_nursery() -> void:
	if _nursery_transition_started:
		return

	_nursery_transition_started = true
	_prepare_nursery_nodes()

	var transition_chain: EventChain = EventChain.new()
	transition_chain.name = "NurseryTransitionChain"
	add_child(transition_chain)
	transition_chain.add_step(Callable(self, "_fade_out_hospital_elements"), HOSPITAL_FADE_DURATION)
	transition_chain.add_step(Callable(self, "_fade_in_nursery_background"), NURSERY_FADE_DURATION)
	transition_chain.add_step(Callable(self, "_soften_room_3_music"), 0.15)
	transition_chain.add_step(Callable(self, "_reveal_ravi_center"), RAVI_REVEAL_DURATION)
	transition_chain.chain_completed.connect(
		func() -> void:
			transition_chain.queue_free()
	)
	transition_chain.play()


func _prepare_nursery_nodes() -> void:
	if _canvas_layer == null:
		push_warning("Room3Controller nao encontrou CanvasLayer para preparar o quarto do Ravi.")
		return

	if _nursery_background == null:
		_nursery_background = AnimatedSprite2D.new()
		_nursery_background.name = "NurseryBackground"
		_nursery_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_nursery_background.centered = false
		_nursery_background.scale = Vector2(0.52734375, 0.62500006)
		_nursery_background.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_nursery_background.visible = false
		_nursery_background.z_index = -1
		_canvas_layer.add_child(_nursery_background)
		_canvas_layer.move_child(_nursery_background, 0)

	var nursery_frames: SpriteFrames = _build_sprite_frames(
		NURSERY_BACKGROUND_TEXTURE_PATH,
		&"nursery_loop",
		NURSERY_BACKGROUND_COLUMNS,
		NURSERY_BACKGROUND_ROWS,
		NURSERY_BACKGROUND_FRAME_SIZE,
		NURSERY_BACKGROUND_FPS,
		true
	)
	if nursery_frames != null:
		_nursery_background.sprite_frames = nursery_frames
		_nursery_background.animation = &"nursery_loop"
		_nursery_background.frame = 0
		_nursery_background.frame_progress = 0.0

	if _ravi_sprite == null:
		push_warning("Room3Controller nao encontrou CanvasLayer/Ravi na cena.")
		return

	var ravi_frames: SpriteFrames = _build_sprite_frames(
		RAVI_IDLE_TEXTURE_PATH,
		&"funny_idle",
		RAVI_IDLE_COLUMNS,
		RAVI_IDLE_ROWS,
		RAVI_IDLE_FRAME_SIZE,
		RAVI_IDLE_FPS,
		true
	)
	if ravi_frames != null and _ravi_sprite.sprite_frames == null:
		_ravi_sprite.sprite_frames = ravi_frames
	if _ravi_sprite.sprite_frames != null:
		_ravi_sprite.animation = &"funny_idle"
		_ravi_sprite.frame = 0
		_ravi_sprite.frame_progress = 0.0
	_setup_baby_interaction()


func _fade_out_hospital_elements() -> void:
	if _hospital_background != null:
		var hospital_fade: Tween = create_tween()
		hospital_fade.tween_property(_hospital_background, "modulate:a", 0.0, HOSPITAL_FADE_DURATION)

	if _doctor != null:
		var doctor_fade: Tween = create_tween()
		doctor_fade.tween_property(_doctor, "modulate:a", 0.0, HOSPITAL_FADE_DURATION)
		doctor_fade.tween_callback(func() -> void:
			_doctor.visible = false
		)

	if _doctor_timer_label != null:
		var label_fade: Tween = create_tween()
		label_fade.tween_property(_doctor_timer_label, "modulate:a", 0.0, HOSPITAL_FADE_DURATION)
		label_fade.tween_callback(func() -> void:
			_doctor_timer_label.visible = false
		)


func _fade_in_nursery_background() -> void:
	if _nursery_background == null:
		push_warning("Room3Controller nao conseguiu preparar o fundo do quarto do Ravi.")
		return

	_nursery_background.visible = true
	_nursery_background.modulate.a = 0.0
	_nursery_background.play(&"nursery_loop")

	var nursery_fade: Tween = create_tween()
	nursery_fade.tween_property(_nursery_background, "modulate:a", 1.0, NURSERY_FADE_DURATION)


func _soften_room_3_music() -> void:
	if Engine.has_singleton("AudioManager"):
		AudioManager.set_bgm_volume(NURSERY_BGM_TARGET_VOLUME_DB, NURSERY_FADE_DURATION)


func _reveal_ravi_center() -> void:
	if _ravi_sprite == null:
		push_warning("Room3Controller nao conseguiu preparar o sprite do Ravi.")
		return

	_ravi_sprite.visible = true
	_ravi_sprite.modulate.a = 0.0
	_ravi_sprite.scale = _ravi_base_scale * 0.9
	_ravi_sprite.play(&"funny_idle")
	_setup_baby_interaction()
	if _baby_interaction != null and _baby_interaction.has_method("set_interaction_enabled"):
		_baby_interaction.call("set_interaction_enabled", false)

	var reveal_tween: Tween = create_tween()
	reveal_tween.parallel().tween_property(_ravi_sprite, "modulate:a", 1.0, RAVI_REVEAL_DURATION)
	reveal_tween.parallel().tween_property(_ravi_sprite, "scale", _ravi_base_scale, RAVI_REVEAL_DURATION)
	reveal_tween.finished.connect(Callable(self, "_activate_baby_interaction"), CONNECT_ONE_SHOT)


func _setup_baby_interaction() -> void:
	if _baby_interaction == null:
		push_warning("Room3Controller nao encontrou CanvasLayer/Ravi/BabyInteraction na cena.")
		return
	if _baby_interaction.has_method("setup"):
		_baby_interaction.call("setup", _protagonist, _ravi_sprite.global_position)
	if _baby_interaction.has_method("set_interaction_enabled"):
		_baby_interaction.call("set_interaction_enabled", false)


func _activate_baby_interaction() -> void:
	if _baby_interaction == null:
		return
	if _baby_interaction.has_method("setup"):
		_baby_interaction.call("setup", _protagonist, _ravi_sprite.global_position)
	if _baby_interaction.has_method("set_interaction_enabled"):
		_baby_interaction.call("set_interaction_enabled", true)


func _build_sprite_frames(
	texture_path: String,
	animation_name: StringName,
	columns: int,
	rows: int,
	frame_size: Vector2,
	fps: float,
	loop_enabled: bool
) -> SpriteFrames:
	if not ResourceLoader.exists(texture_path):
		push_warning("Room3Controller nao encontrou o spritesheet em %s." % texture_path)
		return null

	var sprite_texture: Texture2D = load(texture_path) as Texture2D
	if sprite_texture == null:
		push_warning("Room3Controller nao conseguiu carregar o spritesheet em %s." % texture_path)
		return null

	var sprite_frames: SpriteFrames = SpriteFrames.new()
	sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_loop(animation_name, loop_enabled)
	sprite_frames.set_animation_speed(animation_name, fps)

	for row_index in rows:
		for column_index in columns:
			var atlas_texture: AtlasTexture = AtlasTexture.new()
			atlas_texture.atlas = sprite_texture
			atlas_texture.region = Rect2(
				float(column_index) * frame_size.x,
				float(row_index) * frame_size.y,
				frame_size.x,
				frame_size.y
			)
			sprite_frames.add_frame(animation_name, atlas_texture)

	return sprite_frames

EOF_ROOM3_CONTROLLER
cat > scenes/rooms/room_3.tscn <<'EOF_ROOM3_TSCN'
PLACEHOLDER
EOF_ROOM3_TSCN
echo "OK: arquivos regravados e backups .bak criados"
