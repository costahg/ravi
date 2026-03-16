extends Node

const PROJECTILE_SCENE_PATH: String = "res://scenes/components/projectile.tscn"
const PROJECTILE_SPAWN_OFFSET: float = 48.0

@export var spawn_rate_range: Vector2 = Vector2(0.4, 0.8)
@export var projectile_scale_range: Vector2 = Vector2(0.85, 1.25)

var _projectile_scene: PackedScene
var _spawn_timer: Timer
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _spawning_enabled: bool = false


func _ready() -> void:
	_rng.randomize()
	_projectile_scene = _load_projectile_scene()
	_spawn_timer = Timer.new()
	_spawn_timer.name = "SpawnTimer"
	_spawn_timer.one_shot = true
	_spawn_timer.autostart = false
	add_child(_spawn_timer)

	var on_timeout: Callable = Callable(self, "_on_spawn_timer_timeout")
	if not _spawn_timer.is_connected("timeout", on_timeout):
		_spawn_timer.connect("timeout", on_timeout)


func start_spawning() -> void:
	if _spawning_enabled:
		return

	_spawning_enabled = true
	_schedule_next_spawn()


func stop_spawning() -> void:
	_spawning_enabled = false
	if _spawn_timer != null:
		_spawn_timer.stop()


func _on_spawn_timer_timeout() -> void:
	if not _spawning_enabled:
		return

	_spawn_projectile()
	_schedule_next_spawn()


func _spawn_projectile() -> void:
	if _projectile_scene == null:
		push_warning("BulletSpawner nao conseguiu instanciar projectile.tscn porque a cena nao foi carregada.")
		return

	var projectile: Area2D = _projectile_scene.instantiate() as Area2D
	if projectile == null:
		push_warning("BulletSpawner recebeu uma instancia invalida de projectile.tscn.")
		return

	var spawn_data: Dictionary = _build_spawn_data()
	var spawn_parent: Node = get_parent()
	if spawn_parent == null:
		spawn_parent = get_tree().current_scene

	if spawn_parent == null:
		push_warning("BulletSpawner nao encontrou parent para adicionar o projetil.")
		projectile.queue_free()
		return

	spawn_parent.add_child(projectile)
	projectile.global_position = spawn_data.get("position", Vector2.ZERO)
	projectile.set("direction", spawn_data.get("direction", Vector2.DOWN))
	projectile.rotation = float(spawn_data.get("rotation", 0.0))
	projectile.scale = Vector2.ONE * float(spawn_data.get("scale", 1.0))


func _schedule_next_spawn() -> void:
	if not _spawning_enabled or _spawn_timer == null:
		return

	var min_rate: float = maxf(minf(spawn_rate_range.x, spawn_rate_range.y), 0.01)
	var max_rate: float = maxf(maxf(spawn_rate_range.x, spawn_rate_range.y), min_rate)
	_spawn_timer.wait_time = _rng.randf_range(min_rate, max_rate)
	_spawn_timer.start()


func _build_spawn_data() -> Dictionary:
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var top_left: Vector2 = _screen_to_global_position(viewport_rect.position)
	var bottom_right: Vector2 = _screen_to_global_position(viewport_rect.position + viewport_rect.size)
	var min_bounds: Vector2 = Vector2(
		minf(top_left.x, bottom_right.x),
		minf(top_left.y, bottom_right.y)
	)
	var max_bounds: Vector2 = Vector2(
		maxf(top_left.x, bottom_right.x),
		maxf(top_left.y, bottom_right.y)
	)
	var center_point: Vector2 = (min_bounds + max_bounds) * 0.5
	var edge_index: int = _rng.randi_range(0, 3)
	var spawn_position: Vector2 = Vector2.ZERO

	match edge_index:
		0:
			spawn_position = Vector2(min_bounds.x - PROJECTILE_SPAWN_OFFSET, _rng.randf_range(min_bounds.y, max_bounds.y))
		1:
			spawn_position = Vector2(max_bounds.x + PROJECTILE_SPAWN_OFFSET, _rng.randf_range(min_bounds.y, max_bounds.y))
		2:
			spawn_position = Vector2(_rng.randf_range(min_bounds.x, max_bounds.x), min_bounds.y - PROJECTILE_SPAWN_OFFSET)
		_:
			spawn_position = Vector2(_rng.randf_range(min_bounds.x, max_bounds.x), max_bounds.y + PROJECTILE_SPAWN_OFFSET)

	var direction_to_center: Vector2 = (center_point - spawn_position).normalized()
	var min_scale: float = maxf(minf(projectile_scale_range.x, projectile_scale_range.y), 0.1)
	var max_scale: float = maxf(maxf(projectile_scale_range.x, projectile_scale_range.y), min_scale)
	var projectile_scale: float = _rng.randf_range(min_scale, max_scale)

	return {
		"position": spawn_position,
		"direction": direction_to_center,
		"rotation": direction_to_center.angle(),
		"scale": projectile_scale,
	}


func _load_projectile_scene() -> PackedScene:
	if not ResourceLoader.exists(PROJECTILE_SCENE_PATH):
		push_warning("BulletSpawner nao encontrou a cena do projetil em %s." % PROJECTILE_SCENE_PATH)
		return null

	var projectile_scene: PackedScene = load(PROJECTILE_SCENE_PATH) as PackedScene
	if projectile_scene == null:
		push_warning("BulletSpawner nao conseguiu carregar a cena do projetil em %s." % PROJECTILE_SCENE_PATH)
		return null

	return projectile_scene


func _screen_to_global_position(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position
