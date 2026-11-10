extends Control

signal tool_changed(tool_name: String)
signal camera_view_requested

enum Tool { ORBIT, PAN, CAMERA_VIEW }
var current_tool: int = Tool.ORBIT

const ICON_SIZE := 14.0
const BUTTON_RADIUS := 16.0
const SPACING := 40.0  # distancia vertical entre los dos íconos

var button_positions := []  # se calcula en _draw, se usa en _gui_input
var hovered_index := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _draw() -> void:
	var center_x: float = size.x / 2.0
	button_positions = [
		Vector2(center_x, BUTTON_RADIUS + 2.0),           # botón de orbitar (mouse)
		Vector2(center_x, BUTTON_RADIUS + 2.0 + SPACING), # botón de mano (pan)
		Vector2(center_x, BUTTON_RADIUS + 2.0 + SPACING * 2),
	]

	# --- Botón ORBITAR (mouse) ---
	draw_tool_background(0, Tool.ORBIT)
	draw_cursor_icon(button_positions[0])

	# --- Botón PAN (mano) ---
	draw_tool_background(1, Tool.PAN)
	draw_hand_icon(button_positions[1])
	
	# --- Camara cucuto ---
	draw_tool_background(2, Tool.CAMERA_VIEW)
	draw_camera_icon(button_positions[2])

func draw_tool_background(index: int, tool_id: int) -> void:
	var pos: Vector2 = button_positions[index]
	var is_selected: bool = (current_tool == tool_id)
	var is_hovered: bool = (hovered_index == index)

	# Fondo circular oscuro
	var bg_color := Color(0, 0, 0, 0.35 if not is_hovered else 0.5)
	draw_circle(pos, BUTTON_RADIUS, bg_color)

	# Aro amarillo si está seleccionado
	if is_selected:
		draw_arc(pos, BUTTON_RADIUS - 1.0, 0, TAU, 24, Color.YELLOW, 2.5)

func draw_cursor_icon(pos: Vector2) -> void:
	# Flecha simple de cursor, dibujada con un polígono
	var s := ICON_SIZE
	var points := PackedVector2Array([
		pos + Vector2(-s * 0.35, -s * 0.5),
		pos + Vector2(s * 0.35, 0.0),
		pos + Vector2(s * 0.05, s * 0.05),
		pos + Vector2(s * 0.2, s * 0.5),
		pos + Vector2(s * 0.05, s * 0.55),
		pos + Vector2(-s * 0.15, s * 0.15),
		pos + Vector2(-s * 0.35, s * 0.3),
	])
	draw_colored_polygon(points, Color.WHITE)

func draw_camera_icon(pos: Vector2) -> void:
	var s := ICON_SIZE
	# Cuerpo de la cámara (rectángulo) + un "lente" triangular, forma simplificada
	draw_rect(Rect2(pos + Vector2(-s * 0.4, -s * 0.25), Vector2(s * 0.6, s * 0.5)), Color.WHITE)
	var lens_points := PackedVector2Array([
		pos + Vector2(s * 0.2, -s * 0.15),
		pos + Vector2(s * 0.5, -s * 0.3),
		pos + Vector2(s * 0.5, s * 0.3),
		pos + Vector2(s * 0.2, s * 0.15),
	])
	draw_colored_polygon(lens_points, Color.WHITE)

func draw_hand_icon(pos: Vector2) -> void:
	# Manito simplificada: una palma (círculo) + rectángulo como "muñeca"
	var s := ICON_SIZE
	draw_circle(pos + Vector2(0, -s * 0.15), s * 0.4, Color.WHITE)
	var wrist := Rect2(pos + Vector2(-s * 0.25, s * 0.05), Vector2(s * 0.5, s * 0.4))
	draw_rect(wrist, Color.WHITE)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hovered_index = get_closest_button(event.position)

	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var idx: int = get_closest_button(event.position)
		if idx == 0:
			set_tool(Tool.ORBIT)
		elif idx == 1:
			set_tool(Tool.PAN)

func get_closest_button(mouse_pos: Vector2) -> int:
	for i in button_positions.size():
		if mouse_pos.distance_to(button_positions[i]) <= BUTTON_RADIUS:
			return i
	return -1

func set_tool(tool_id: int) -> void:
	current_tool = tool_id

	var tool_name := "orbit"
	if tool_id == Tool.PAN:
		tool_name = "pan"
	elif tool_id == Tool.CAMERA_VIEW:
		tool_name = "camera_view"

	tool_changed.emit(tool_name)

	if tool_id == Tool.CAMERA_VIEW:
		camera_view_requested.emit()

	queue_redraw()
	
