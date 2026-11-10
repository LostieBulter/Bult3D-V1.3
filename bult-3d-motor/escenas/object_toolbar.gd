extends Control

signal tool_changed(tool_name: String)

enum Tool { SELECT, MOVE, ROTATE, SCALE, IK, COLLISION }
var current_tool: int = Tool.SELECT

const BUTTON_RADIUS := 16.0
const SPACING := 40.0
const ICON_SIZE := 14.0


var tool_names := ["select", "move", "rotate", "scale", "ik", "collision"]
var button_positions := []
var hovered_index := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _draw() -> void:
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08, 0.7)
	style.corner_radius_top_left = 100
	style.corner_radius_top_right = 100
	style.corner_radius_bottom_left = 100
	style.corner_radius_bottom_right = 100
	# Fondo del panel completo, para ver exactamente el área clickeable
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.08, 0.08, 0.7))

	
	# ... el resto sigue igual
	var center_x: float = size.x / 2.0
	button_positions.clear()
	for i in tool_names.size():
		button_positions.append(Vector2(center_x, BUTTON_RADIUS + 2.0 + i * SPACING))

	draw_tool_bg(0, Tool.SELECT)
	draw_cursor_icon(button_positions[0])

	draw_tool_bg(1, Tool.MOVE)
	draw_move_icon(button_positions[1])

	draw_tool_bg(2, Tool.ROTATE)
	draw_rotate_icon(button_positions[2])

	draw_tool_bg(3, Tool.SCALE)
	draw_scale_icon(button_positions[3])
	
	draw_tool_bg(4, Tool.IK)
	draw_ik_icon(button_positions[4])

	draw_tool_bg(5, Tool.COLLISION)
	draw_collision_icon(button_positions[5])

func draw_tool_bg(index: int, tool_id: int) -> void:
	var pos: Vector2 = button_positions[index]
	var is_selected: bool = current_tool == tool_id
	var is_hovered: bool = hovered_index == index
	draw_circle(pos, BUTTON_RADIUS, Color(0, 0, 0, 0.5 if is_hovered else 0.35))
	if is_selected:
		draw_arc(pos, BUTTON_RADIUS - 1.0, 0, TAU, 24, Color.YELLOW, 2.5)

func draw_cursor_icon(pos: Vector2) -> void:
	var s := ICON_SIZE
	var points := PackedVector2Array([
		pos + Vector2(-s * 0.35, -s * 0.5), pos + Vector2(s * 0.35, 0.0),
		pos + Vector2(s * 0.05, s * 0.05), pos + Vector2(s * 0.2, s * 0.5),
		pos + Vector2(s * 0.05, s * 0.55), pos + Vector2(-s * 0.15, s * 0.15),
		pos + Vector2(-s * 0.35, s * 0.3)
	])
	draw_colored_polygon(points, Color.WHITE)

func draw_move_icon(pos: Vector2) -> void:
	var s := ICON_SIZE
	draw_line(pos, pos + Vector2(0, -s * 0.6), Color.WHITE, 2.0)
	draw_line(pos, pos + Vector2(0, s * 0.6), Color.WHITE, 2.0)
	draw_line(pos, pos + Vector2(-s * 0.6, 0), Color.WHITE, 2.0)
	draw_line(pos, pos + Vector2(s * 0.6, 0), Color.WHITE, 2.0)

func draw_rotate_icon(pos: Vector2) -> void:
	var s := ICON_SIZE
	draw_arc(pos, s * 0.45, 0, TAU * 0.75, 16, Color.WHITE, 2.0)

func draw_scale_icon(pos: Vector2) -> void:
	var s := ICON_SIZE
	draw_rect(Rect2(pos - Vector2(s * 0.3, s * 0.3), Vector2(s * 0.6, s * 0.6)), Color.WHITE, false, 2.0)

func draw_ik_icon(pos: Vector2) -> void:
	var s := ICON_SIZE
	draw_line(pos + Vector2(-s * 0.4, -s * 0.4), pos + Vector2(0, 0), Color.WHITE, 2.0)
	draw_line(pos + Vector2(0, 0), pos + Vector2(s * 0.1, s * 0.45), Color.WHITE, 2.0)
	draw_circle(pos + Vector2(-s * 0.4, -s * 0.4), 2.0, Color.CYAN)
	draw_circle(pos + Vector2(s * 0.1, s * 0.45), 2.5, Color.CYAN)
	
func draw_collision_icon(pos: Vector2) -> void:
	var s := ICON_SIZE
	draw_rect(Rect2(pos - Vector2(s * 0.3, s * 0.3), Vector2(s * 0.6, s * 0.6)), Color.CYAN, false, 2.0)
	draw_rect(Rect2(pos - Vector2(s * 0.45, s * 0.45), Vector2(s * 0.9, s * 0.9)), Color(1, 1, 1, 0.5), false, 1.0)



func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hovered_index = get_closest(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()  # NUEVO: absorbe el clic pase lo que pase, así no llega a la cámara
		if event.pressed:
			var idx: int = get_closest(event.position)
			if idx != -1:
				current_tool = idx
				tool_changed.emit(tool_names[idx])
				queue_redraw()

func get_closest(mouse_pos: Vector2) -> int:
	for i in button_positions.size():
		if mouse_pos.distance_to(button_positions[i]) <= BUTTON_RADIUS:
			return i
	return -1
