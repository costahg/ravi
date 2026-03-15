extends Node

@export var auto_start_transition: bool = false
@export var target_room_id: int = 1
@export var expected_room_id: int = 0

@onready var _status_label: Label = get_node_or_null("CanvasLayer/StatusLabel") as Label


func _ready() -> void:
	if auto_start_transition:
		_set_status("Chamando GameManager.transition_to_room(%d)..." % target_room_id)
		GameManager.transition_started.connect(_on_transition_started)
		GameManager.transition_to_room(target_room_id)
		return

	if expected_room_id > 0:
		if GameManager.state == GameManager.State.TRANSITIONING:
			_set_status("Aguardando fade finalizar...")
			GameManager.transition_finished.connect(_on_transition_finished)
			return

		_update_validation_status()
		return

	_set_status("Cena de teste carregada.")


func _on_transition_started() -> void:
	_set_status("Fade iniciado...")


func _on_transition_finished() -> void:
	_update_validation_status()


func _update_validation_status() -> void:
	var room_matches: bool = GameManager.current_room == expected_room_id
	var state_matches: bool = GameManager.state == GameManager.State.PLAYING

	if room_matches and state_matches:
		_set_status(
			"Teste OK: current_room=%d, state=%s."
			% [GameManager.current_room, _state_to_string(GameManager.state)]
		)
		return

	_set_status(
		"Teste FALHOU: current_room=%s, state=%s."
		% [GameManager.current_room, _state_to_string(GameManager.state)]
	)


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


func _state_to_string(value: int) -> String:
	match value:
		GameManager.State.PLAYING:
			return "PLAYING"
		GameManager.State.TRANSITIONING:
			return "TRANSITIONING"
		_:
			return "UNKNOWN(%s)" % value
