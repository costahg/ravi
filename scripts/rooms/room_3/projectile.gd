extends Area2D

const PROJECTILE_LIFETIME_MAX: float = 5.0

@export var speed: float = 420.0
@export var direction: Vector2 = Vector2.RIGHT

@onready var _screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var _lifetime_timer: Timer = $LifetimeTimer


func _ready() -> void:
	_connect_screen_notifier()
	_configure_lifetime_timer()


func _process(delta: float) -> void:
	global_position += direction.normalized() * speed * delta


func _connect_screen_notifier() -> void:
	if _screen_notifier == null:
		push_warning("Projectile nao encontrou VisibleOnScreenNotifier2D.")
		return

	var on_screen_exited: Callable = Callable(self, "_on_screen_exited")
	if not _screen_notifier.is_connected("screen_exited", on_screen_exited):
		_screen_notifier.connect("screen_exited", on_screen_exited)


func _configure_lifetime_timer() -> void:
	if _lifetime_timer == null:
		push_warning("Projectile nao encontrou LifetimeTimer.")
		return

	_lifetime_timer.one_shot = true
	_lifetime_timer.autostart = false
	_lifetime_timer.wait_time = PROJECTILE_LIFETIME_MAX

	var on_timeout: Callable = Callable(self, "_on_lifetime_timeout")
	if not _lifetime_timer.is_connected("timeout", on_timeout):
		_lifetime_timer.connect("timeout", on_timeout)

	_lifetime_timer.start()


func _on_screen_exited() -> void:
	queue_free()


func _on_lifetime_timeout() -> void:
	queue_free()
