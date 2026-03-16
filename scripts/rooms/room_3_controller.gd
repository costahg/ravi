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
const PROTAGONIST_SCENE: PackedScene = preload("res://scenes/components/protagonist.tscn")

@export var survival_duration: float = 15.0
@export_group("Nursery Protagonist Margins")
@export var nursery_margin_top: float = 320.0
@export var nursery_margin_bottom: float = 200.0
@export var nursery_margin_left: float = 70.0
@export var nursery_margin_right: float = 70.0

@onready var _canvas_layer: CanvasLayer = $CanvasLayer
@onready var _hospital_background: AnimatedSprite2D = $CanvasLayer/HospitalBackground
@onready var _protagonist: Node2D = $CanvasLayer/Protagonist
@onready var _survival_timer: Timer = $CanvasLayer/SurvivalTimer
@onready var _bullet_spawner: Node = get_node_or_null("CanvasLayer/BulletSpawner") as Node
@onready var _doctor: AnimatedSprite2D = get_node_or_null("CanvasLayer/Doctor") as AnimatedSprite2D
@onready var _doctor_timer_label: Label = _resolve_doctor_timer_label()
@onready var _baby_interaction: Area2D = _resolve_baby_interaction()
@onready var _ravi_sprite: Node2D = _resolve_baby_visual()

var _default_protagonist_modulate: Color = Color.WHITE
var _hit_flash_tween: Tween
var _hit_invulnerable: bool = false
var _survival_phase_finished: bool = false
var _nursery_transition_started: bool = false
var _nursery_background: AnimatedSprite2D
var _ravi_base_scale: Vector2 = Vector2.ONE
var _hub_return_requested: bool = false


func _ready() -> void:
	_default_protagonist_modulate = _protagonist.modulate
	_configure_hospital_background()
	_configure_survival_timer()
	_connect_survival_phase()
	_connect_baby_interaction_signals()
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


func _connect_baby_interaction_signals() -> void:
	if _baby_interaction == null or not _baby_interaction.has_signal("exit_requested"):
		return

	var on_exit_requested: Callable = Callable(self, "_on_baby_exit_requested")
	if not _baby_interaction.is_connected("exit_requested", on_exit_requested):
		_baby_interaction.connect("exit_requested", on_exit_requested)


func _on_baby_exit_requested() -> void:
	_request_return_to_hub()


func _request_return_to_hub() -> void:
	if _hub_return_requested:
		return

	_hub_return_requested = true

	if Engine.has_singleton("GameManager"):
		if GameManager.current_room == 3 and not GameManager.rooms_completed.get(3, false):
			GameManager.complete_room(3)
			return

		push_warning(
			"Room3Controller nao conseguiu concluir a sala 3 via GameManager.complete_room(3). "
			+ "Aplicando fallback para GameManager.return_to_hub()."
		)
		GameManager.return_to_hub()
		return

	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager == null:
		push_warning("Room3Controller nao encontrou GameManager para retornar ao hub.")
		return

	if game_manager.get("current_room") == 3 and not game_manager.get("rooms_completed").get(3, false):
		game_manager.call("complete_room", 3)
		return

	push_warning(
		"Room3Controller nao conseguiu concluir a sala 3 via GameManager.complete_room(3). "
		+ "Aplicando fallback para GameManager.return_to_hub()."
	)
	if game_manager.has_method("return_to_hub"):
		game_manager.call("return_to_hub")


func _start_bullet_spawner() -> void:
	if _bullet_spawner == null:
		push_warning("Room3Controller nao encontrou CanvasLayer/BulletSpawner.")
		return

	if _bullet_spawner.has_method("start_spawning"):
		_bullet_spawner.call("start_spawning")


func _resolve_doctor_timer_label() -> Label:
	var canvas_label: Label = get_node_or_null("CanvasLayer/TimerLabel") as Label
	if canvas_label != null:
		return canvas_label

	return get_node_or_null("CanvasLayer/Doctor/TimerLabel") as Label


func _resolve_baby_interaction() -> Area2D:
	var direct_baby_interaction: Area2D = get_node_or_null("CanvasLayer/BabyInteraction") as Area2D
	if direct_baby_interaction != null:
		return direct_baby_interaction

	var canvas_layer_node: Node = get_node_or_null("CanvasLayer")
	if canvas_layer_node == null:
		return null

	for node_variant in canvas_layer_node.find_children("*", "Area2D", true, false):
		var area: Area2D = node_variant as Area2D
		if area == null:
			continue
		if area.has_method("setup") and area.has_method("set_interaction_enabled"):
			return area

	return null


func _resolve_baby_visual() -> Node2D:
	if _baby_interaction == null:
		return null

	for node_variant in _baby_interaction.find_children("*", "AnimatedSprite2D", true, false):
		var animated_sprite: AnimatedSprite2D = node_variant as AnimatedSprite2D
		if animated_sprite != null:
			return animated_sprite

	for node_variant in _baby_interaction.find_children("*", "Sprite2D", true, false):
		var sprite: Sprite2D = node_variant as Sprite2D
		if sprite != null:
			return sprite

	for child in _baby_interaction.get_children():
		var visual_node: Node2D = child as Node2D
		if visual_node == null:
			continue
		if visual_node is CollisionShape2D:
			continue
		return visual_node

	return null


func _stop_bullet_spawner() -> void:
	if _bullet_spawner == null:
		return

	if _bullet_spawner.has_method("stop_spawning"):
		_bullet_spawner.call("stop_spawning")


func _configure_doctor_timer_label() -> void:
	if _doctor_timer_label == null:
		push_warning("Room3Controller nao encontrou o contador visivel do Doctor.")
		return

	_doctor_timer_label.visible = true
	_doctor_timer_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
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
		_doctor_timer_label.visible = false
		_doctor_timer_label.text = ""
		return

	var seconds_left: float = maxf(_survival_timer.time_left, 0.0)
	_doctor_timer_label.visible = true
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
	_stop_bullet_spawner()

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
	transition_chain.add_step(Callable(self, "_replace_dodge_protagonist_with_standard"), 0.05)
	transition_chain.add_step(Callable(self, "_configure_baby_interaction_for_nursery"), 0.05)
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

	if _baby_interaction == null:
		push_warning("Room3Controller nao encontrou nenhum Area2D de interacao do bebe na cena.")
		return

	if _ravi_sprite == null:
		push_warning("Room3Controller nao encontrou nenhum visual do bebe dentro do Area2D configurado na cena.")
		return

	_ravi_base_scale = _resolve_ravi_base_scale()

	if _baby_interaction.has_method("set_interaction_enabled"):
		_baby_interaction.call("set_interaction_enabled", false)

	if _baby_interaction.has_method("set_roaming_enabled"):
		_baby_interaction.call("set_roaming_enabled", false)

	_ravi_sprite.visible = false
	_ravi_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_ravi_sprite.scale = _ravi_base_scale


func _configure_baby_interaction_for_nursery() -> void:
	if _baby_interaction == null:
		return

	if _baby_interaction.has_method("setup"):
		_baby_interaction.call("setup", _protagonist, _baby_interaction.global_position)

	if _baby_interaction.has_method("configure_roaming_area"):
		_baby_interaction.call(
			"configure_roaming_area",
			get_viewport_rect().size,
			nursery_margin_top,
			nursery_margin_bottom,
			nursery_margin_left,
			nursery_margin_right
		)

	if _baby_interaction.has_method("set_interaction_enabled"):
		_baby_interaction.call("set_interaction_enabled", true)

	if _baby_interaction.has_method("set_roaming_enabled"):
		_baby_interaction.call("set_roaming_enabled", true)


func _replace_dodge_protagonist_with_standard() -> void:
	if _protagonist == null:
		push_warning("Room3Controller nao encontrou a protagonista para substituir apos o bullet hell.")
		return

	if PROTAGONIST_SCENE == null:
		push_warning("Room3Controller nao conseguiu carregar o PackedScene da protagonista padrao.")
		return

	var old_protagonist: Node2D = _protagonist
	var parent_node: Node = old_protagonist.get_parent()
	if parent_node == null:
		push_warning("Room3Controller nao encontrou parent da protagonista para substituir apos o bullet hell.")
		return

	var standard_protagonist: Node2D = PROTAGONIST_SCENE.instantiate() as Node2D
	if standard_protagonist == null:
		push_warning("Room3Controller nao conseguiu instanciar a protagonista padrao.")
		return

	var previous_index: int = old_protagonist.get_index()
	var previous_name: StringName = old_protagonist.name
	var previous_global_position: Vector2 = old_protagonist.global_position
	var previous_scale: Vector2 = old_protagonist.scale
	var previous_rotation: float = old_protagonist.rotation
	var previous_modulate: Color = old_protagonist.modulate
	var previous_visible: bool = old_protagonist.visible
	var previous_z_index: int = old_protagonist.z_index

	old_protagonist.name = &"ProtagonistBulletHell"

	parent_node.add_child(standard_protagonist)
	parent_node.move_child(standard_protagonist, previous_index)

	standard_protagonist.name = previous_name
	standard_protagonist.global_position = previous_global_position
	standard_protagonist.scale = previous_scale
	standard_protagonist.rotation = previous_rotation
	standard_protagonist.modulate = previous_modulate
	standard_protagonist.visible = previous_visible
	standard_protagonist.z_index = previous_z_index

	_apply_nursery_protagonist_margins(standard_protagonist)

	old_protagonist.queue_free()

	_protagonist = standard_protagonist
	_default_protagonist_modulate = _protagonist.modulate


func _apply_nursery_protagonist_margins(target: Node2D) -> void:
	if target == null:
		return

	target.set("margin_top", nursery_margin_top)
	target.set("margin_bottom", nursery_margin_bottom)
	target.set("margin_left", nursery_margin_left)
	target.set("margin_right", nursery_margin_right)


func _fade_out_hospital_elements() -> void:
	if _hospital_background != null:
		var hospital_fade: Tween = create_tween()
		hospital_fade.tween_property(_hospital_background, "modulate:a", 0.0, HOSPITAL_FADE_DURATION)

	if _doctor != null:
		var doctor_fade: Tween = create_tween()
		doctor_fade.tween_property(_doctor, "modulate:a", 0.0, HOSPITAL_FADE_DURATION)

	if _doctor_timer_label != null:
		var label_fade: Tween = create_tween()
		label_fade.tween_property(_doctor_timer_label, "modulate:a", 0.0, HOSPITAL_FADE_DURATION)


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
		push_warning("Room3Controller nao conseguiu preparar o visual do bebe configurado na cena.")
		return

	_ravi_sprite.visible = true
	_ravi_sprite.modulate.a = 0.0
	_ravi_sprite.scale = _ravi_base_scale * 0.9

	var animated_sprite: AnimatedSprite2D = _ravi_sprite as AnimatedSprite2D
	if animated_sprite != null and animated_sprite.sprite_frames != null:
		if animated_sprite.animation != StringName() and animated_sprite.sprite_frames.has_animation(animated_sprite.animation):
			animated_sprite.play(animated_sprite.animation)
		else:
			var animation_names: PackedStringArray = animated_sprite.sprite_frames.get_animation_names()
			if not animation_names.is_empty():
				animated_sprite.play(StringName(animation_names[0]))

	var reveal_tween: Tween = create_tween()
	reveal_tween.parallel().tween_property(_ravi_sprite, "modulate:a", 1.0, RAVI_REVEAL_DURATION)
	reveal_tween.parallel().tween_property(_ravi_sprite, "scale", _ravi_base_scale, RAVI_REVEAL_DURATION)

	if _baby_interaction != null and _baby_interaction.has_method("set_roaming_enabled"):
		_baby_interaction.call("set_roaming_enabled", true)


func _resolve_ravi_base_scale() -> Vector2:
	if _ravi_sprite == null:
		return Vector2.ONE

	var current_scale: Vector2 = _ravi_sprite.scale
	if is_zero_approx(current_scale.x) or is_zero_approx(current_scale.y):
		return Vector2.ONE

	return current_scale


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
