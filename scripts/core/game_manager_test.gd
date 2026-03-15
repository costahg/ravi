extends Node

class HubLoopTestRunner extends Node:
	const ROOM_COMPLETE_DELAY: float = 0.15
	const STAGE_TIMEOUT_SECONDS: float = 4.0
	const OVERLAY_LAYER: int = 200

	var target_room_id: int = 1
	var _stage: String = "idle"
	var _timeout_timer: Timer
	var _status_label: Label
	var _details_label: Label

	func _ready() -> void:
		name = "HubLoopTestRunner"
		_build_overlay()
		_build_timeout_timer()
		GameManager.transition_started.connect(_on_transition_started)
		GameManager.transition_finished.connect(_on_transition_finished)
		GameManager.rooms_completed.clear()
		_stage = "go_to_hub"
		_set_status("Teste: carregando hub...")
		_set_details("Loop esperado: hub -> sala %d -> hub." % target_room_id)
		_arm_timeout()
		GameManager.return_to_hub()

	func _build_overlay() -> void:
		var overlay_layer: CanvasLayer = CanvasLayer.new()
		overlay_layer.layer = OVERLAY_LAYER
		add_child(overlay_layer)

		var background: ColorRect = ColorRect.new()
		background.color = Color(0.0, 0.0, 0.0, 0.72)
		background.offset_left = 16.0
		background.offset_top = 16.0
		background.offset_right = 524.0
		background.offset_bottom = 156.0
		overlay_layer.add_child(background)

		_status_label = Label.new()
		_status_label.offset_left = 32.0
		_status_label.offset_top = 32.0
		_status_label.offset_right = 508.0
		_status_label.offset_bottom = 78.0
		_status_label.add_theme_font_size_override("font_size", 24)
		overlay_layer.add_child(_status_label)

		_details_label = Label.new()
		_details_label.offset_left = 32.0
		_details_label.offset_top = 84.0
		_details_label.offset_right = 508.0
		_details_label.offset_bottom = 140.0
		_details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_details_label.add_theme_font_size_override("font_size", 16)
		overlay_layer.add_child(_details_label)

	func _build_timeout_timer() -> void:
		_timeout_timer = Timer.new()
		_timeout_timer.one_shot = true
		_timeout_timer.wait_time = STAGE_TIMEOUT_SECONDS
		_timeout_timer.timeout.connect(_on_stage_timeout)
		add_child(_timeout_timer)

	func _arm_timeout() -> void:
		if _timeout_timer == null:
			return
		_timeout_timer.start()

	func _on_transition_started() -> void:
		_set_details("Transicao iniciada na etapa '%s'." % _stage)

	func _on_transition_finished() -> void:
		if _timeout_timer != null:
			_timeout_timer.stop()

		match _stage:
			"go_to_hub":
				if GameManager.current_room != 0 or GameManager.state != GameManager.State.PLAYING:
					_fail("Hub invalido: current_room=%s, state=%s." % [GameManager.current_room, _state_to_string(GameManager.state)])
					return
				_stage = "go_to_room"
				_set_status("Teste: hub OK. Abrindo sala %d..." % target_room_id)
				_set_details("Hub carregado com current_room=0. Iniciando transicao para a sala.")
				_arm_timeout()
				GameManager.transition_to_room(target_room_id)
			"go_to_room":
				if GameManager.current_room != target_room_id or GameManager.state != GameManager.State.PLAYING:
					_fail("Sala invalida: current_room=%s, state=%s." % [GameManager.current_room, _state_to_string(GameManager.state)])
					return
				_stage = "return_to_hub"
				_set_status("Teste: sala %d OK. Concluindo sala..." % target_room_id)
				_set_details("Chamando GameManager.complete_room(%d)." % target_room_id)
				_arm_timeout()
				get_tree().create_timer(ROOM_COMPLETE_DELAY).timeout.connect(_complete_current_room, CONNECT_ONE_SHOT)
			"return_to_hub":
				_validate_return_to_hub()

	func _complete_current_room() -> void:
		if _stage != "return_to_hub":
			return
		GameManager.complete_room(target_room_id)

	func _validate_return_to_hub() -> void:
		var current_room_matches: bool = GameManager.current_room == 0
		var state_matches: bool = GameManager.state == GameManager.State.PLAYING
		var room_completed: bool = GameManager.rooms_completed.get(target_room_id, false)
		var room_locked_after_completion: bool = not GameManager.can_enter_room(target_room_id)
		var expected_next_room: int = 0
		if target_room_id < GameManager.ROOM_SCENES.size():
			expected_next_room = target_room_id + 1
		var next_room_matches: bool = GameManager.get_next_room_to_unlock() == expected_next_room
		var next_room_unlocked: bool = expected_next_room == 0 or GameManager.can_enter_room(expected_next_room)

		if current_room_matches and state_matches and room_completed and room_locked_after_completion and next_room_matches and next_room_unlocked:
			_stage = "done"
			_set_status("Teste OK: loop hub -> sala -> hub validado.")
			_set_details(
				"current_room=0, rooms_completed[%d]=true, proxima_sala=%d."
				% [target_room_id, expected_next_room]
			)
			return

		_fail(
			"Retorno ao hub invalido: current_room=%s, state=%s, completed=%s, next=%s."
			% [
				GameManager.current_room,
				_state_to_string(GameManager.state),
				room_completed,
				GameManager.get_next_room_to_unlock(),
			]
		)

	func _on_stage_timeout() -> void:
		_fail("Timeout na etapa '%s'." % _stage)

	func _fail(message: String) -> void:
		_stage = "failed"
		_set_status("Teste FALHOU: loop hub -> sala -> hub.")
		_set_details(message)
		push_error(message)

	func _set_status(text: String) -> void:
		if _status_label != null:
			_status_label.text = text

	func _set_details(text: String) -> void:
		if _details_label != null:
			_details_label.text = text

	func _state_to_string(value: int) -> String:
		match value:
			GameManager.State.PLAYING:
				return "PLAYING"
			GameManager.State.TRANSITIONING:
				return "TRANSITIONING"
			_:
				return "UNKNOWN(%s)" % value


class Room1FlowTestRunner extends Node:
	const STAGE_TIMEOUT_SECONDS: float = 4.0
	const OVERLAY_LAYER: int = 200
	const FLOWERS: Array[Dictionary] = [
		{
			"id": "hibisco",
			"flower_path": NodePath("CanvasLayer/FlowerOrigin/Hibisco"),
			"hotspot_path": NodePath("CanvasLayer/FlowerTargets/TargetHibisco/Hotspot"),
			"approach_path": NodePath("CanvasLayer/FlowerTargets/TargetHibisco/ApproachMarker"),
			"hint_path": NodePath("CanvasLayer/TargetHints/HintHibisco"),
			"layer_path": NodePath("CanvasLayer/Highlighter1Hibisco"),
		},
		{
			"id": "rosa",
			"flower_path": NodePath("CanvasLayer/FlowerOrigin/RosasVermelhas"),
			"hotspot_path": NodePath("CanvasLayer/FlowerTargets/TargetRosa/Hotspot"),
			"approach_path": NodePath("CanvasLayer/FlowerTargets/TargetRosa/ApproachMarker"),
			"hint_path": NodePath("CanvasLayer/TargetHints/HintRosasVermelhas"),
			"layer_path": NodePath("CanvasLayer/Highlighter2RosasVermelhas"),
		},
		{
			"id": "lirio",
			"flower_path": NodePath("CanvasLayer/FlowerOrigin/Lirios"),
			"hotspot_path": NodePath("CanvasLayer/FlowerTargets/TargetLirio/Hotspot"),
			"approach_path": NodePath("CanvasLayer/FlowerTargets/TargetLirio/ApproachMarker"),
			"hint_path": NodePath("CanvasLayer/TargetHints/HintLirios"),
			"layer_path": NodePath("CanvasLayer/Highlighter3Lirios"),
		},
		{
			"id": "girassol",
			"flower_path": NodePath("CanvasLayer/FlowerOrigin/Girassois"),
			"hotspot_path": NodePath("CanvasLayer/FlowerTargets/TargetGirassol/Hotspot"),
			"approach_path": NodePath("CanvasLayer/FlowerTargets/TargetGirassol/ApproachMarker"),
			"hint_path": NodePath("CanvasLayer/TargetHints/HintGirassois"),
			"layer_path": NodePath("CanvasLayer/Highlighter4Girassois"),
		},
	]

	var _status_label: Label
	var _details_label: Label
	var _room_scene: Node
	var _active_flower_index: int = -1
	var _expected_restore_count: int = 0

	func _ready() -> void:
		name = "Room1FlowTestRunner"
		_build_overlay()
		call_deferred("_run_test")

	func _run_test() -> void:
		GameManager.rooms_completed.clear()
		GameManager.current_room = 0
		_set_status("Teste Sala 1: abrindo cena...")
		_set_details("Validando fluxo completo da Sala 1 em headless.")
		GameManager.transition_to_room(1)

		if not await _wait_until(Callable(self, "_is_room_1_ready"), STAGE_TIMEOUT_SECONDS, "Sala 1 nao carregou corretamente."):
			return

		_room_scene = get_tree().current_scene
		if not _validate_initial_state():
			return

		for flower_index: int in FLOWERS.size():
			_active_flower_index = flower_index
			_expected_restore_count = flower_index + 1
			_set_status("Teste Sala 1: flor %d/4" % _expected_restore_count)
			_set_details("Acionando hotspot '%s' e aguardando centro -> alvo." % FLOWERS[flower_index]["id"])

			if not _validate_turn_state(flower_index):
				return

			var hotspot: Area2D = _room_scene.get_node(FLOWERS[flower_index]["hotspot_path"]) as Area2D
			hotspot.pressed.emit(FLOWERS[flower_index]["id"])

			if not await _wait_until(Callable(self, "_is_active_hint_visible"), STAGE_TIMEOUT_SECONDS, "Hint da flor '%s' nao apareceu." % FLOWERS[flower_index]["id"]):
				return
			if not await _wait_until(Callable(self, "_is_protagonist_at_center"), STAGE_TIMEOUT_SECONDS, "Protagonista nao alcancou o centro para '%s'." % FLOWERS[flower_index]["id"]):
				return
			if not await _wait_until(Callable(self, "_is_protagonist_at_target"), STAGE_TIMEOUT_SECONDS, "Protagonista nao alcancou o alvo para '%s'." % FLOWERS[flower_index]["id"]):
				return
			if not await _wait_until(Callable(self, "_is_restore_count_reached"), STAGE_TIMEOUT_SECONDS, "Entrega da flor '%s' nao concluiu." % FLOWERS[flower_index]["id"]):
				return
			if not await _wait_until(Callable(self, "_is_active_layer_revealed"), STAGE_TIMEOUT_SECONDS, "Layer da flor '%s' nao terminou de revelar." % FLOWERS[flower_index]["id"]):
				return
			if not _validate_post_restore_state(flower_index):
				return

		_set_status("Teste Sala 1: validando finale...")
		_set_details("Aguardando GardenSurprise, Presente, Furao e retorno ao hub.")

		if not await _wait_until(Callable(self, "_is_background_surprise"), STAGE_TIMEOUT_SECONDS, "Background nao entrou na animacao surprise."):
			return
		if not await _wait_until(Callable(self, "_is_center_hidden"), STAGE_TIMEOUT_SECONDS, "Center nao foi ocultado no finale."):
			return
		if not await _wait_until(Callable(self, "_is_present_visible"), STAGE_TIMEOUT_SECONDS, "Presente nao apareceu com fade."):
			return
		if not await _wait_until(Callable(self, "_is_furao_visible"), STAGE_TIMEOUT_SECONDS, "Furao nao apareceu no finale."):
			return
		if not await _wait_until(Callable(self, "_is_hub_ready_after_room_1"), STAGE_TIMEOUT_SECONDS * 2.0, "Nao retornou ao hub com a Sala 2 desbloqueada."):
			return

		_finish_success("Teste OK: Sala 1 completa do primeiro hotspot ao retorno ao hub.")

	func _build_overlay() -> void:
		var overlay_layer: CanvasLayer = CanvasLayer.new()
		overlay_layer.layer = OVERLAY_LAYER
		add_child(overlay_layer)

		var background: ColorRect = ColorRect.new()
		background.color = Color(0.0, 0.0, 0.0, 0.72)
		background.offset_left = 16.0
		background.offset_top = 16.0
		background.offset_right = 524.0
		background.offset_bottom = 156.0
		overlay_layer.add_child(background)

		_status_label = Label.new()
		_status_label.offset_left = 32.0
		_status_label.offset_top = 32.0
		_status_label.offset_right = 508.0
		_status_label.offset_bottom = 78.0
		_status_label.add_theme_font_size_override("font_size", 24)
		overlay_layer.add_child(_status_label)

		_details_label = Label.new()
		_details_label.offset_left = 32.0
		_details_label.offset_top = 84.0
		_details_label.offset_right = 508.0
		_details_label.offset_bottom = 140.0
		_details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_details_label.add_theme_font_size_override("font_size", 16)
		overlay_layer.add_child(_details_label)

	func _wait_until(condition: Callable, timeout_seconds: float, failure_message: String) -> bool:
		var deadline_ms: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
		while Time.get_ticks_msec() <= deadline_ms:
			if condition.call():
				return true
			await get_tree().process_frame
		_finish_failure(failure_message)
		return false

	func _validate_initial_state() -> bool:
		if int(_room_scene.get("_flowers_restored")) != 0:
			_finish_failure("Estado inicial invalido: _flowers_restored != 0.")
			return false
		if int(_room_scene.get("_current_flower_index")) != 0:
			_finish_failure("Estado inicial invalido: _current_flower_index != 0.")
			return false
		return _validate_turn_state(0)

	func _validate_turn_state(expected_active_index: int) -> bool:
		for flower_index: int in FLOWERS.size():
			var flower: CanvasItem = _room_scene.get_node(FLOWERS[flower_index]["flower_path"]) as CanvasItem
			var hotspot: Area2D = _room_scene.get_node(FLOWERS[flower_index]["hotspot_path"]) as Area2D
			var should_be_visible: bool = flower_index == expected_active_index
			var should_be_active: bool = flower_index == expected_active_index
			if flower.visible != should_be_visible:
				_finish_failure("Flor visivel incorreta no turno %d." % expected_active_index)
				return false
			if bool(hotspot.get("active")) != should_be_active:
				_finish_failure("Hotspot ativo incorreto no turno %d." % expected_active_index)
				return false
		return true

	func _validate_post_restore_state(restored_index: int) -> bool:
		var active_hint: CanvasItem = _room_scene.get_node(FLOWERS[restored_index]["hint_path"]) as CanvasItem
		var restored_layer: CanvasItem = _room_scene.get_node(FLOWERS[restored_index]["layer_path"]) as CanvasItem
		if active_hint.visible:
			_finish_failure("Hint da flor '%s' permaneceu visivel apos a entrega." % FLOWERS[restored_index]["id"])
			return false
		if restored_layer.modulate.a < 0.95:
			_finish_failure("Layer da flor '%s' nao foi revelada." % FLOWERS[restored_index]["id"])
			return false
		if restored_index + 1 < FLOWERS.size():
			return _validate_turn_state(restored_index + 1)
		for flower_data: Dictionary in FLOWERS:
			var hotspot: Area2D = _room_scene.get_node(flower_data["hotspot_path"]) as Area2D
			if bool(hotspot.get("active")):
				_finish_failure("Nenhum hotspot deveria permanecer ativo apos a quarta entrega.")
				return false
		return true

	func _is_room_1_ready() -> bool:
		var current_scene: Node = get_tree().current_scene
		return current_scene != null and current_scene.scene_file_path == GameManager.ROOM_SCENES[1] and GameManager.current_room == 1 and GameManager.state == GameManager.State.PLAYING

	func _is_active_hint_visible() -> bool:
		var hint: CanvasItem = _room_scene.get_node(FLOWERS[_active_flower_index]["hint_path"]) as CanvasItem
		return hint.visible

	func _is_protagonist_at_center() -> bool:
		var protagonist: Node2D = _room_scene.get_node("CanvasLayer/Protagonist") as Node2D
		var center: Node2D = _room_scene.get_node("CanvasLayer/FlowerOrigin") as Node2D
		return protagonist.global_position.distance_to(center.global_position) <= 1.0

	func _is_protagonist_at_target() -> bool:
		var protagonist: Node2D = _room_scene.get_node("CanvasLayer/Protagonist") as Node2D
		var target: Node2D = _room_scene.get_node(FLOWERS[_active_flower_index]["approach_path"]) as Node2D
		return protagonist.global_position.distance_to(target.global_position) <= 1.0

	func _is_restore_count_reached() -> bool:
		return int(_room_scene.get("_flowers_restored")) == _expected_restore_count

	func _is_active_layer_revealed() -> bool:
		var layer: CanvasItem = _room_scene.get_node(FLOWERS[_active_flower_index]["layer_path"]) as CanvasItem
		return layer.modulate.a >= 0.95

	func _is_background_surprise() -> bool:
		var background: AnimatedSprite2D = _room_scene.get_node("CanvasLayer/Background") as AnimatedSprite2D
		return background.animation == &"surprise"

	func _is_center_hidden() -> bool:
		var center: CanvasItem = _room_scene.get_node("CanvasLayer/Center") as CanvasItem
		return not center.visible

	func _is_present_visible() -> bool:
		var present: Sprite2D = _room_scene.get_node("CanvasLayer/Presente") as Sprite2D
		return present.modulate.a >= 0.95

	func _is_furao_visible() -> bool:
		var furao: Node2D = _room_scene.get_node("CanvasLayer/Furao") as Node2D
		return furao.visible and absf(furao.scale.x - 0.6) <= 0.05 and absf(furao.scale.y - 0.6) <= 0.05

	func _is_hub_ready_after_room_1() -> bool:
		var current_scene: Node = get_tree().current_scene
		return current_scene != null and current_scene.scene_file_path == GameManager.MAIN_MENU_SCENE_PATH and GameManager.current_room == 0 and GameManager.state == GameManager.State.PLAYING and GameManager.rooms_completed.get(1, false) and GameManager.get_next_room_to_unlock() == 2 and not GameManager.can_enter_room(1) and GameManager.can_enter_room(2)

	func _finish_success(message: String) -> void:
		_set_status("Teste OK: fluxo da Sala 1 validado.")
		_set_details(message)
		print("ROOM1_FLOW_TEST: PASS | %s" % message)
		if DisplayServer.get_name() == "headless":
			get_tree().quit(0)

	func _finish_failure(message: String) -> void:
		_set_status("Teste FALHOU: fluxo da Sala 1.")
		_set_details(message)
		print("ROOM1_FLOW_TEST: FAIL | %s" % message)
		push_error(message)
		if DisplayServer.get_name() == "headless":
			get_tree().quit(1)

	func _set_status(text: String) -> void:
		if _status_label != null:
			_status_label.text = text

	func _set_details(text: String) -> void:
		if _details_label != null:
			_details_label.text = text

@export var auto_start_transition: bool = false
@export var auto_run_hub_loop_test: bool = false
@export var auto_run_room_1_flow_test: bool = false
@export var target_room_id: int = 1
@export var expected_room_id: int = 0

@onready var _status_label: Label = get_node_or_null("CanvasLayer/StatusLabel") as Label


func _ready() -> void:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if user_args.has("--room1-flow-test"):
		auto_run_room_1_flow_test = true

	if auto_run_room_1_flow_test:
		_start_room_1_flow_test()
		return

	if auto_run_hub_loop_test:
		_start_hub_loop_test()
		return

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


func _start_hub_loop_test() -> void:
	var existing_runner: Node = GameManager.get_node_or_null("HubLoopTestRunner")
	if existing_runner != null:
		existing_runner.queue_free()

	var runner: HubLoopTestRunner = HubLoopTestRunner.new()
	runner.target_room_id = target_room_id
	GameManager.add_child(runner)
	_set_status("Teste do loop iniciado. O status persistira sobre as cenas.")


func _start_room_1_flow_test() -> void:
	var existing_hub_runner: Node = GameManager.get_node_or_null("HubLoopTestRunner")
	if existing_hub_runner != null:
		existing_hub_runner.queue_free()

	var existing_room_runner: Node = GameManager.get_node_or_null("Room1FlowTestRunner")
	if existing_room_runner != null:
		existing_room_runner.queue_free()

	var runner: Room1FlowTestRunner = Room1FlowTestRunner.new()
	GameManager.add_child(runner)
	_set_status("Teste automatizado da Sala 1 iniciado.")


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
