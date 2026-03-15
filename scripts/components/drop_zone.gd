extends Area2D

const DROP_TARGET_GROUP: StringName = &"drop_target"

@export var zone_id: String = ""


func _ready() -> void:
	add_to_group(DROP_TARGET_GROUP)
