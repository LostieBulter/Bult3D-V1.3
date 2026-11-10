extends Control

func _ready() -> void:
	
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(32, 32)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _draw() -> void:
	var margin: float = size.x * 0.2
	draw_rect(Rect2(Vector2(margin, margin), size - Vector2(margin, margin) * 2), Color(0.9, 0.9, 0.9))
