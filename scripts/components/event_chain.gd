extends Node
class_name EventChain

signal chain_completed

@export var configured_targets: Array[NodePath] = []
@export var configured_methods: Array[StringName] = []
@export var configured_delays: Array[float] = []

var _steps: Array[Dictionary] = []
var _playing: bool = false


func add_step(what: Callable, delay_after: float = 0.5) -> EventChain:
	_steps.append(
		{
			"callable": what,
			"delay_after": delay_after,
		}
	)
	return self


func clear() -> void:
	_steps.clear()


func play() -> void:
	if _playing:
		return

	_playing = true

	var steps_to_play: Array[Dictionary] = _steps.duplicate(true)
	if steps_to_play.is_empty():
		steps_to_play = _build_configured_steps()

	for step: Dictionary in steps_to_play:
		var step_callable: Callable = step.get("callable", Callable())
		if not step_callable.is_valid():
			push_warning("EventChain step callable invalido; step ignorado.")
			continue

		var delay_after: float = float(step.get("delay_after", 0.0))
		step_callable.call()
		await get_tree().create_timer(delay_after).timeout

	_playing = false
	chain_completed.emit()


func _build_configured_steps() -> Array[Dictionary]:
	var built_steps: Array[Dictionary] = []

	for index: int in configured_targets.size():
		if index >= configured_methods.size():
			push_warning("EventChain configurado sem method para o step %d." % index)
			continue

		var target_path: NodePath = configured_targets[index]
		if target_path.is_empty():
			push_warning("EventChain configurado com target vazio no step %d." % index)
			continue

		var target_node: Node = get_node_or_null(target_path)
		if target_node == null:
			push_warning("EventChain nao encontrou target configurado no step %d." % index)
			continue

		var method_name: StringName = configured_methods[index]
		if method_name == StringName():
			push_warning("EventChain configurado com method vazio no step %d." % index)
			continue

		var delay_after: float = 0.5
		if index < configured_delays.size():
			delay_after = configured_delays[index]

		built_steps.append(
			{
				"callable": Callable(target_node, method_name),
				"delay_after": delay_after,
			}
		)

	return built_steps
