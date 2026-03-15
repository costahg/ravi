extends Node

signal revealed

@export var reveal_duration: float = 0.6
@export var hidden_color: Color = Color(0.15, 0.15, 0.15, 1.0)
@export var revealed_color: Color = Color.WHITE
@export var start_hidden: bool = true

var _visual_parent: CanvasItem
var _active_tween: Tween
var _is_revealed: bool = false


func _ready() -> void:
	var parent_node: Node = get_parent()
	if parent_node is CanvasItem:
		_visual_parent = parent_node as CanvasItem
	else:
		push_warning("Revealer precisa ser filho de um CanvasItem.")
		return

	if start_hidden:
		_visual_parent.modulate = hidden_color
		_is_revealed = false
		return

	_is_revealed = true


func reveal() -> void:
	if _visual_parent == null or _is_revealed:
		return

	if _active_tween != null:
		return

	var tween: Tween = create_tween()
	_active_tween = tween
	tween.tween_property(_visual_parent, "modulate", revealed_color, reveal_duration)
	tween.finished.connect(_on_reveal_finished)


func _on_reveal_finished() -> void:
	if _visual_parent != null:
		_visual_parent.modulate = revealed_color

	_active_tween = null
	_is_revealed = true
	revealed.emit()


func hide_visual() -> void:
	if _visual_parent == null:
		return

	_stop_active_tween()
	_is_revealed = false

	var tween: Tween = create_tween()
	_active_tween = tween
	tween.tween_property(_visual_parent, "modulate", hidden_color, reveal_duration)
	tween.finished.connect(_on_hide_finished)


func reveal_instant() -> void:
	if _visual_parent == null:
		return

	_stop_active_tween()
	_visual_parent.modulate = revealed_color
	_is_revealed = true


func _on_hide_finished() -> void:
	if _visual_parent != null:
		_visual_parent.modulate = hidden_color

	_active_tween = null


func _stop_active_tween() -> void:
	if _active_tween == null:
		return

	_active_tween.kill()
	_active_tween = null
