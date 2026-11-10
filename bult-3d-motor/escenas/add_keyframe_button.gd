extends Control

signal keyframe_pressed

const SIZE := 10.0
var is_hovered := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _draw() -> void:
	var center: Vector2 = size / 2.0
	var color := Color(0.3, 0.8, 1.0) if is_hovered else Color(0.9, 0.9, 0.9)

	# Dibujamos un diamante (rombo) con 4 puntos
	var points := PackedVector2Array([
		center + Vector2(0, -SIZE),
		center + Vector2(SIZE, 0),
		center + Vector2(0, SIZE),
		center + Vector2(-SIZE, 0),
	])
	draw_colored_polygon(points, color)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var was_hovered := is_hovered
		is_hovered = Rect2(Vector2.ZERO, size).has_point(event.position)
		if was_hovered != is_hovered:
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		keyframe_pressed.emit()
