extends Area2D

const DROP_TARGET_GROUP: StringName = &"drop_target"

@export var zone_id: String = ""
@export var accepted_id: String = ""


func _ready() -> void:
	add_to_group(DROP_TARGET_GROUP)


func accepts_drag_id(drag_id: String) -> bool:
	if accepted_id == "":
		return true
	return drag_id == accepted_id