extends Node2D

signal task_enabled(task_id: String)

const DISH_CLEAN_RATE: float = 1.0
const SWEEP_CLEAN_RATE: float = 1.0

@onready var _dishes_hotspot: Area2D = $CanvasLayer/TaskZones/DishesZone/Hotspot
@onready var _clothes_hotspot: Area2D = $CanvasLayer/TaskZones/ClothesZone/Hotspot
@onready var _sweep_hotspot: Area2D = $CanvasLayer/TaskZones/SweepZone/Hotspot
@onready var _dishes_marker: Marker2D = $CanvasLayer/TaskZones/DishesZone/ApproachMarker
@onready var _clothes_marker: Marker2D = $CanvasLayer/TaskZones/ClothesZone/ApproachMarker
@onready var _sweep_marker: Marker2D = $CanvasLayer/TaskZones/SweepZone/ApproachMarker
@onready var _dishes_dirty_visual: CanvasItem = $CanvasLayer/DirtyStates/DishesBefore
@onready var _clothes_dirty_visual: CanvasItem = $CanvasLayer/DirtyStates/ClothesBefore
@onready var _sweep_dirty_visual: CanvasItem = $CanvasLayer/DirtyStates/SweepBefore
@onready var _dishes_clean_visual: CanvasItem = $CanvasLayer/CleanStates/DishesAfter
@onready var _clothes_clean_visual: CanvasItem = $CanvasLayer/CleanStates/ClothesAfter
@onready var _sweep_clean_visual: CanvasItem = $CanvasLayer/CleanStates/SweepAfter
@onready var _sweep_static_broom: CanvasItem = get_node_or_null("CanvasLayer/DirtyStates/SweepBefore/Vassoura") as CanvasItem
@onready var _dirt_mask: CanvasItem = $CanvasLayer/DirtMask
@onready var _sweep_mask_top_left: CanvasItem = $CanvasLayer/DirtMask/MaskFrame0
@onready var _sweep_mask_top_right: CanvasItem = $CanvasLayer/DirtMask/MaskFrame1
@onready var _sweep_mask_bottom_left: CanvasItem = $CanvasLayer/DirtMask/MaskFrame2
@onready var _sweep_mask_bottom_right: CanvasItem = $CanvasLayer/DirtMask/MaskFrame3
@onready var _dish_interaction: Node2D = $CanvasLayer/DishInteraction
@onready var _dish_dirt_overlay: Sprite2D = $CanvasLayer/DishInteraction/DirtOverlay
@onready var _dish_dirt_area: Area2D = $CanvasLayer/DishInteraction/DirtArea
@onready var _dish_sponge: Area2D = $CanvasLayer/DishInteraction/Sponge
@onready var _clothes_interaction: Node2D = get_node_or_null("CanvasLayer/ClothesInteraction") as Node2D
@onready var _clothes_basket: Area2D = get_node_or_null("CanvasLayer/ClothesInteraction/Basket") as Area2D
@onready var _cloth_1: Area2D = get_node_or_null("CanvasLayer/ClothesInteraction/Cloth1") as Area2D
@onready var _cloth_2: Area2D = get_node_or_null("CanvasLayer/ClothesInteraction/Cloth2") as Area2D
@onready var _cloth_3: Area2D = get_node_or_null("CanvasLayer/ClothesInteraction/Cloth3") as Area2D
@onready var _sweep_interaction: Node2D = get_node_or_null("CanvasLayer/SweepInteraction") as Node2D
@onready var _sweep_broom: Area2D = get_node_or_null("CanvasLayer/SweepInteraction/Broom") as Area2D
@onready var _sweep_target_top_left: Area2D = get_node_or_null("CanvasLayer/SweepInteraction/TopLeft") as Area2D
@onready var _sweep_target_top_right: Area2D = get_node_or_null("CanvasLayer/SweepInteraction/TopRight") as Area2D
@onready var _sweep_target_bottom_left: Area2D = get_node_or_null("CanvasLayer/SweepInteraction/BottomLeft") as Area2D
@onready var _sweep_target_bottom_right: Area2D = get_node_or_null("CanvasLayer/SweepInteraction/BottomRight") as Area2D
@onready var _transition_animation: AnimatedSprite2D = get_node_or_null("CanvasLayer/TransitionAnimation") as AnimatedSprite2D
@onready var _protagonist: Node2D = $CanvasLayer/Protagonist

var _tasks_done: Dictionary = {
	"dishes": false,
	"clothes": false,
	"sweep": false,
}
var _active_task: String = ""

var _pending_task: String = ""
var _task_hotspots: Dictionary = {}
var _task_markers: Dictionary = {}
var _dirty_visuals: Dictionary = {}
var _clean_visuals: Dictionary = {}
var _transformation_started: bool = false
var _dish_clean_progress: float = 0.0
var _dish_scrub_complete: bool = false
var _dish_sponge_dragging: bool = false
var _dish_sponge_over_dirt: bool = false
var _clothes_draggables: Array[Area2D] = []
var _clothes_delivered_ids: Dictionary = {}
var _sweep_target_areas: Dictionary = {}
var _sweep_mask_nodes: Dictionary = {}
var _sweep_progress_by_target: Dictionary = {}
var _sweep_broom_dragging: bool = false


func _ready() -> void:
	_task_hotspots = {
		"dishes": _dishes_hotspot,
		"clothes": _clothes_hotspot,
		"sweep": _sweep_hotspot,
	}
	_task_markers = {
		"dishes": _dishes_marker,
		"clothes": _clothes_marker,
		"sweep": _sweep_marker,
	}
	_dirty_visuals = {
		"dishes": _dishes_dirty_visual,
		"clothes": _clothes_dirty_visual,
		"sweep": _sweep_dirty_visual,
	}
	_clean_visuals = {
		"dishes": _dishes_clean_visual,
		"clothes": _clothes_clean_visual,
		"sweep": _sweep_clean_visual,
	}
	_sweep_target_areas = {
		"top_left": _sweep_target_top_left,
		"top_right": _sweep_target_top_right,
		"bottom_left": _sweep_target_bottom_left,
		"bottom_right": _sweep_target_bottom_right,
	}
	_sweep_mask_nodes = {
		"top_left": _sweep_mask_top_left,
		"top_right": _sweep_mask_top_right,
		"bottom_left": _sweep_mask_bottom_left,
		"bottom_right": _sweep_mask_bottom_right,
	}
	_sweep_progress_by_target = {
		"top_left": 0.0,
		"top_right": 0.0,
		"bottom_left": 0.0,
		"bottom_right": 0.0,
	}

	_clothes_draggables.clear()
	for cloth_candidate: Area2D in [_cloth_1, _cloth_2, _cloth_3]:
		if cloth_candidate != null:
			_clothes_draggables.append(cloth_candidate)

	_connect_hotspots()
	_connect_protagonist()
	_connect_dishes_interaction()
	_connect_clothes_interaction()
	_connect_sweep_interaction()
	_sync_all_task_visuals()
	_sync_dishes_interaction_state()
	_sync_clothes_interaction_state()
	_sync_sweep_interaction_state()
	_refresh_task_hotspots()


func _process(delta: float) -> void:
	if _active_task == "dishes":
		_update_dishes_progress(delta)
		return

	if _active_task == "sweep":
		_update_sweep_progress(delta)


func _on_hotspot_pressed(task_id: String) -> void:
	if GameManager.state == GameManager.State.TRANSITIONING:
		return

	if not _can_request_task(task_id):
		return

	var marker: Marker2D = _task_markers.get(task_id) as Marker2D
	if marker == null:
		push_warning("Room2Controller nao encontrou marker para a tarefa '%s'." % task_id)
		return

	_pending_task = task_id
	_refresh_task_hotspots()
	_move_protagonist_to_action(marker.global_position)


func _on_protagonist_destination_reached(_destination: Vector2) -> void:
	if _pending_task.is_empty():
		return

	_active_task = _pending_task
	_pending_task = ""
	_refresh_task_hotspots()
	_activate_current_task()
	task_enabled.emit(_active_task)


func complete_task(task_id: String) -> void:
	if not _tasks_done.has(task_id):
		push_warning("Room2Controller.complete_task recebeu task_id invalido: '%s'." % task_id)
		return

	if _tasks_done.get(task_id, false):
		push_warning("Room2Controller.complete_task ignorado: tarefa '%s' ja concluida." % task_id)
		return

	if _active_task != task_id:
		push_warning("Room2Controller.complete_task ignorado: tarefa ativa atual e '%s', nao '%s'." % [_active_task, task_id])
		return

	_tasks_done[task_id] = true
	_active_task = ""
	_pending_task = ""
	_apply_task_visual_state(task_id)
	_refresh_task_hotspots()

	if _all_tasks_done():
		_start_transformation()


func _can_request_task(task_id: String) -> bool:
	if not _tasks_done.has(task_id):
		return false

	if _tasks_done.get(task_id, false):
		return false

	if not _active_task.is_empty():
		return false

	if not _pending_task.is_empty():
		return false

	if task_id == "clothes" and not _has_clothes_interaction():
		push_warning("Room2Controller ignorou a tarefa 'clothes' porque CanvasLayer/ClothesInteraction ainda nao existe na cena.")
		return false

	if task_id == "sweep" and not _has_sweep_interaction():
		push_warning("Room2Controller ignorou a tarefa 'sweep' porque CanvasLayer/SweepInteraction ainda nao existe na cena.")
		return false

	return true


func _connect_hotspots() -> void:
	var on_hotspot_pressed: Callable = Callable(self, "_on_hotspot_pressed")
	for hotspot_variant in _task_hotspots.values():
		var hotspot: Area2D = hotspot_variant as Area2D
		if hotspot != null and not hotspot.is_connected("pressed", on_hotspot_pressed):
			hotspot.connect("pressed", on_hotspot_pressed)


func _connect_protagonist() -> void:
	var on_destination_reached: Callable = Callable(self, "_on_protagonist_destination_reached")
	if _protagonist.has_signal("destination_reached") and not _protagonist.is_connected("destination_reached", on_destination_reached):
		_protagonist.connect("destination_reached", on_destination_reached)


func _connect_dishes_interaction() -> void:
	var on_drag_started: Callable = Callable(self, "_on_dish_sponge_drag_started")
	if _dish_sponge.has_signal("drag_started") and not _dish_sponge.is_connected("drag_started", on_drag_started):
		_dish_sponge.connect("drag_started", on_drag_started)

	var on_drag_ended: Callable = Callable(self, "_on_dish_sponge_drag_ended")
	if _dish_sponge.has_signal("drag_ended") and not _dish_sponge.is_connected("drag_ended", on_drag_ended):
		_dish_sponge.connect("drag_ended", on_drag_ended)

	var on_area_entered: Callable = Callable(self, "_on_dish_sponge_area_entered")
	if not _dish_sponge.is_connected("area_entered", on_area_entered):
		_dish_sponge.connect("area_entered", on_area_entered)

	var on_area_exited: Callable = Callable(self, "_on_dish_sponge_area_exited")
	if not _dish_sponge.is_connected("area_exited", on_area_exited):
		_dish_sponge.connect("area_exited", on_area_exited)


func _connect_clothes_interaction() -> void:
	var on_dropped_on_target: Callable = Callable(self, "_on_cloth_dropped_on_target")
	for cloth: Area2D in _clothes_draggables:
		if cloth == null:
			continue

		if cloth.has_signal("dropped_on_target") and not cloth.is_connected("dropped_on_target", on_dropped_on_target):
			cloth.connect("dropped_on_target", on_dropped_on_target)


func _connect_sweep_interaction() -> void:
	if _sweep_broom == null:
		return

	var on_drag_started: Callable = Callable(self, "_on_sweep_broom_drag_started")
	if _sweep_broom.has_signal("drag_started") and not _sweep_broom.is_connected("drag_started", on_drag_started):
		_sweep_broom.connect("drag_started", on_drag_started)

	var on_drag_ended: Callable = Callable(self, "_on_sweep_broom_drag_ended")
	if _sweep_broom.has_signal("drag_ended") and not _sweep_broom.is_connected("drag_ended", on_drag_ended):
		_sweep_broom.connect("drag_ended", on_drag_ended)


func _sync_all_task_visuals() -> void:
	for task_id_variant in _tasks_done.keys():
		_apply_task_visual_state(String(task_id_variant))


func _sync_dishes_interaction_state() -> void:
	var dishes_active: bool = _active_task == "dishes" and not _tasks_done.get("dishes", false)
	_dish_interaction.visible = dishes_active
	_dish_sponge.set("active", dishes_active)
	_update_dish_dirt_overlay()


func _update_dish_dirt_overlay() -> void:
	var remaining_alpha: float = 1.0 - _dish_clean_progress
	_dish_dirt_overlay.visible = remaining_alpha > 0.0
	_dish_dirt_overlay.modulate = Color(1.0, 1.0, 1.0, remaining_alpha)


func _update_dishes_progress(delta: float) -> void:
	if _dish_scrub_complete:
		return

	if not _dish_sponge_dragging or not _dish_sponge_over_dirt:
		return

	_dish_clean_progress = minf(_dish_clean_progress + delta * DISH_CLEAN_RATE, 1.0)
	_update_dish_dirt_overlay()

	if _dish_clean_progress >= 1.0:
		_dish_scrub_complete = true
		_update_dish_dirt_overlay()
		complete_task("dishes")


func _update_sweep_progress(delta: float) -> void:
	if not _sweep_broom_dragging or _sweep_broom == null:
		return

	for target_id_variant in _sweep_target_areas.keys():
		var target_id: String = String(target_id_variant)
		var target_area: Area2D = _sweep_target_areas.get(target_id) as Area2D
		if target_area == null:
			continue

		var current_progress: float = float(_sweep_progress_by_target.get(target_id, 0.0))
		if current_progress >= 1.0:
			continue

		if not _sweep_broom.overlaps_area(target_area):
			continue

		_sweep_progress_by_target[target_id] = minf(current_progress + delta * SWEEP_CLEAN_RATE, 1.0)
		_update_sweep_mask_visual(target_id)

		if _all_sweep_targets_clean():
			complete_task("sweep")
			return


func _update_sweep_mask_visual(target_id: String) -> void:
	var mask_node: CanvasItem = _sweep_mask_nodes.get(target_id) as CanvasItem
	if mask_node == null:
		return

	var remaining_alpha: float = 1.0 - float(_sweep_progress_by_target.get(target_id, 0.0))
	mask_node.visible = remaining_alpha > 0.0
	mask_node.modulate = Color(1.0, 1.0, 1.0, remaining_alpha)


func _sync_sweep_mask_state() -> void:
	var sweep_done: bool = _tasks_done.get("sweep", false)
	if _dirt_mask != null:
		_dirt_mask.visible = not sweep_done

	if sweep_done:
		for mask_node_variant in _sweep_mask_nodes.values():
			var mask_node: CanvasItem = mask_node_variant as CanvasItem
			if mask_node != null:
				mask_node.visible = false
		return

	for target_id_variant in _sweep_mask_nodes.keys():
		_update_sweep_mask_visual(String(target_id_variant))


func _apply_task_visual_state(task_id: String) -> void:
	var dirty_visual: CanvasItem = _dirty_visuals.get(task_id) as CanvasItem
	var clean_visual: CanvasItem = _clean_visuals.get(task_id) as CanvasItem
	var is_done: bool = _tasks_done.get(task_id, false)

	if dirty_visual != null:
		dirty_visual.visible = not is_done

	if clean_visual != null:
		clean_visual.visible = is_done

	if task_id == "dishes" and is_done:
		_sync_dishes_interaction_state()

	if task_id == "clothes" and is_done:
		_sync_clothes_interaction_state()

	if task_id == "sweep":
		_sync_sweep_mask_state()
		if is_done:
			_sync_sweep_interaction_state()


func _refresh_task_hotspots() -> void:
	var can_accept_selection: bool = _active_task.is_empty() and _pending_task.is_empty()
	for task_id_variant in _task_hotspots.keys():
		var task_id: String = String(task_id_variant)
		var hotspot: Area2D = _task_hotspots.get(task_id) as Area2D
		if hotspot == null:
			continue

		var is_available: bool = can_accept_selection and not _tasks_done.get(task_id, false)
		hotspot.set("active", is_available)


func _move_protagonist_to_action(target_position: Vector2) -> void:
	if _protagonist.has_method("consume_next_press"):
		_protagonist.call("consume_next_press")

	if _protagonist.has_method("set_manual_input_enabled"):
		_protagonist.call("set_manual_input_enabled", false)

	if _protagonist.has_method("move_to_global_position"):
		_protagonist.call("move_to_global_position", target_position)


func _activate_current_task() -> void:
	match _active_task:
		"dishes":
			_activate_dishes_interaction()
		"clothes":
			_activate_clothes_interaction()
		"sweep":
			_activate_sweep_interaction()


func _activate_dishes_interaction() -> void:
	_dish_clean_progress = 0.0
	_dish_scrub_complete = false
	_dish_sponge_dragging = false
	_dish_sponge_over_dirt = false
	_sync_dishes_interaction_state()


func _activate_clothes_interaction() -> void:
	if not _has_clothes_interaction():
		push_warning("Room2Controller nao pode ativar a tarefa 'clothes' sem CanvasLayer/ClothesInteraction.")
		_active_task = ""
		_pending_task = ""
		_refresh_task_hotspots()
		return

	_clothes_delivered_ids.clear()
	_sync_clothes_interaction_state()


func _activate_sweep_interaction() -> void:
	_sweep_broom_dragging = false
	_sync_sweep_interaction_state()


func _on_dish_sponge_drag_started(drag_id: String) -> void:
	if drag_id != "dish_sponge":
		return

	_dish_sponge_dragging = true


func _on_dish_sponge_drag_ended(_drag_id: String) -> void:
	_dish_sponge_dragging = false
	_dish_sponge_over_dirt = false


func _on_dish_sponge_area_entered(area: Area2D) -> void:
	if area != _dish_dirt_area:
		return

	_dish_sponge_over_dirt = true


func _on_dish_sponge_area_exited(area: Area2D) -> void:
	if area != _dish_dirt_area:
		return

	_dish_sponge_over_dirt = false


func _on_sweep_broom_drag_started(drag_id: String) -> void:
	if drag_id != "sweep_broom":
		return

	_sweep_broom_dragging = true


func _on_sweep_broom_drag_ended(_drag_id: String) -> void:
	_sweep_broom_dragging = false


func _all_tasks_done() -> bool:
	for task_done_variant in _tasks_done.values():
		if not bool(task_done_variant):
			return false

	return true


func _all_sweep_targets_clean() -> bool:
	for progress_variant in _sweep_progress_by_target.values():
		if float(progress_variant) < 1.0:
			return false

	return true


func _sync_clothes_interaction_state() -> void:
	var clothes_active: bool = _active_task == "clothes" and not _tasks_done.get("clothes", false)
	if _clothes_interaction != null:
		_clothes_interaction.visible = clothes_active

	if _clothes_basket != null:
		_clothes_basket.monitoring = clothes_active
		_clothes_basket.monitorable = clothes_active

	for cloth: Area2D in _clothes_draggables:
		if cloth != null:
			var cloth_id: String = String(cloth.get("drag_id"))
			var cloth_is_delivered: bool = _clothes_delivered_ids.get(cloth_id, false)
			_set_cloth_enabled_state(cloth, clothes_active and not cloth_is_delivered)


func _sync_sweep_interaction_state() -> void:
	var sweep_active: bool = _active_task == "sweep" and not _tasks_done.get("sweep", false)
	if _sweep_interaction != null:
		_sweep_interaction.visible = sweep_active

	if _sweep_static_broom != null:
		_sweep_static_broom.visible = not sweep_active and not _tasks_done.get("sweep", false)

	if _sweep_broom != null:
		_sweep_broom.set("active", sweep_active)

	for target_area_variant in _sweep_target_areas.values():
		var target_area: Area2D = target_area_variant as Area2D
		if target_area == null:
			continue

		target_area.monitoring = sweep_active
		target_area.monitorable = sweep_active


func _has_clothes_interaction() -> bool:
	return _clothes_interaction != null and _clothes_basket != null and _clothes_draggables.size() == 3


func _has_sweep_interaction() -> bool:
	return _sweep_interaction != null and _sweep_broom != null and _sweep_target_areas.size() == 4 and _sweep_mask_nodes.size() == 4


func _on_cloth_dropped_on_target(drag_id: String, target_area: Area2D) -> void:
	if _active_task != "clothes":
		return

	if _tasks_done.get("clothes", false):
		return

	if target_area != _clothes_basket:
		return

	if _clothes_delivered_ids.get(drag_id, false):
		return

	var cloth: Area2D = _get_cloth_by_drag_id(drag_id)
	if cloth == null:
		push_warning("Room2Controller nao encontrou a roupa '%s' para concluir o drop." % drag_id)
		return

	_clothes_delivered_ids[drag_id] = true
	_set_cloth_enabled_state(cloth, false)

	if _clothes_delivered_ids.size() >= 3:
		complete_task("clothes")


func _get_cloth_by_drag_id(drag_id: String) -> Area2D:
	for cloth: Area2D in _clothes_draggables:
		if cloth == null:
			continue

		if String(cloth.get("drag_id")) == drag_id:
			return cloth

	return null


func _set_cloth_enabled_state(cloth: Area2D, is_enabled: bool) -> void:
	cloth.visible = is_enabled
	cloth.input_pickable = is_enabled
	cloth.monitoring = is_enabled
	cloth.monitorable = is_enabled
	cloth.set("active", is_enabled)

	var collision_shape: CollisionShape2D = cloth.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		collision_shape.set_deferred("disabled", not is_enabled)


func _start_transformation() -> void:
	if _transformation_started:
		return

	_transformation_started = true

	if _transition_animation == null:
		push_warning("Room2Controller nao encontrou CanvasLayer/TransitionAnimation para tocar a transformacao final.")
		return

	if _transition_animation.sprite_frames == null or not _transition_animation.sprite_frames.has_animation(&"transition"):
		push_warning("Room2Controller nao encontrou a animacao 'transition' em CanvasLayer/TransitionAnimation.")
		return

	_transition_animation.visible = true
	_transition_animation.animation = &"transition"
	_transition_animation.frame = 0
	_transition_animation.frame_progress = 0.0
	_transition_animation.play(&"transition")
