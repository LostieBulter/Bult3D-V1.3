extends Control

func _ready() -> void:
	
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(32, 32)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _draw() -> void:
	var s: float = min(size.x, size.y)
	var points := PackedVector2Array([
		Vector2(size.x * 0.25, size.y * 0.15),
		Vector2(size.x * 0.25, size.y * 0.85),
		Vector2(size.x * 0.85, size.y * 0.5),
	])
	draw_colored_polygon(points, Color(0.9, 0.9, 0.9))
