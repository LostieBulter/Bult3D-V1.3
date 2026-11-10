extends Control

const PIXELS_PER_FRAME := 8.0
const FRAME_LABEL_INTERVAL := 10  # mostramos un número cada 10 cuadros
var pixels_per_frame: float = 8.0
const MIN_PIXELS_PER_FRAME := 2.0
const MAX_PIXELS_PER_FRAME := 40.0
var keyframes: Array = []
var current_frame: int = 0
var scroll_offset: float = 0.0  # por si más adelante querés desplazar la línea de tiempo
var dragging_playhead := false
signal keyframe_delete_requested(frame: int)
signal keyframe_moved(old_frame: int, new_frame: int)
var mouse_is_over := false
var dragging_keyframe_frame: int = -1
const KEYFRAME_CLICK_RADIUS := 8.0
signal frame_changed(frame: int)
var end_frame: int = 140
var video_range: Dictionary = {}  # {"start": int, "end": int} o {} si no aplica
signal video_range_dragged(new_start: int)

var dragging_video_range := false
var video_range_drag_offset: float = 0.0
var locked := false
var lock_message := ""
const NEGATIVE_MARGIN := 64.0  # píxeles de zona negativa visibles a la izquierda del cuadro 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	# Ocupa exactamente el panel de animación, sin pasarse ni quedarse corto
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true

func _draw() -> void:
	# Fondo de la regla
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.13, 0.13, 0.13, 1.0))
	# Zona negativa (antes del cuadro 0): más oscura y sin números, solo de referencia
	var zero_x: float = -scroll_offset
	if zero_x > 0.0:
		draw_rect(Rect2(Vector2.ZERO, Vector2(zero_x, size.y)), Color(0.05, 0.05, 0.05, 1.0))
		draw_line(Vector2(zero_x, 0), Vector2(zero_x, size.y), Color(0.55, 0.55, 0.55), 2.0)
	# Franja que marca el rango del video, si el objeto seleccionado es uno
	if not video_range.is_empty():
		var start_x: float = video_range["start"] * pixels_per_frame - scroll_offset
		var end_x_video: float = video_range["end"] * pixels_per_frame - scroll_offset
		draw_rect(Rect2(Vector2(start_x, 22), Vector2(end_x_video - start_x, 10)), Color(0.2, 0.6, 0.9, 0.5))

	var first_visible_frame: int = max(0, int(scroll_offset / pixels_per_frame))
	var last_visible_frame: int = min(int((scroll_offset + size.x) / pixels_per_frame) + 1, end_frame)

	var label_interval: int = FRAME_LABEL_INTERVAL
	if pixels_per_frame >= 24.0:
		label_interval = 1
	elif pixels_per_frame >= 12.0:
		label_interval = 5

	for i in range(first_visible_frame, last_visible_frame + 1):
		var frame_num: int = i
		var x: float = i * pixels_per_frame - scroll_offset

		var is_major: bool = frame_num % FRAME_LABEL_INTERVAL == 0
		var tick_height: float = 12.0 if is_major else 6.0
		var tick_color := Color(0.5, 0.5, 0.5) if is_major else Color(0.35, 0.35, 0.35)

		draw_line(Vector2(x, size.y - tick_height), Vector2(x, size.y), tick_color, 1.0)

		if frame_num % label_interval == 0:
			draw_string(ThemeDB.fallback_font, Vector2(x + 2, 12), str(frame_num), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.7, 0.7))

		

	# Línea del playhead (cabezal de reproducción), en un color que resalte
	var playhead_x: float = current_frame * pixels_per_frame - scroll_offset
	draw_line(Vector2(playhead_x, 0), Vector2(playhead_x, size.y), Color(0.3, 0.8, 1.0), 2.0)

	# Dibujamos un diamante por cada keyframe guardado, centrado exactamente en su cuadro
	for key in keyframes:
		var kx: float = key["frame"] * pixels_per_frame - scroll_offset
		var ky: float = size.y - 8.0
		var points := PackedVector2Array([
			Vector2(kx, ky - 6), Vector2(kx + 6, ky), Vector2(kx, ky + 6), Vector2(kx - 6, ky)
		])
		draw_colored_polygon(points, Color(1.0, 0.75, 0.1))

	var end_x: float = end_frame * pixels_per_frame - scroll_offset
	draw_line(Vector2(end_x, 0), Vector2(end_x, size.y), Color(0.9, 0.3, 0.3), 2.0)
	
	if locked:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.13, 0.13, 0.13, 1.0))
		draw_string(ThemeDB.fallback_font, Vector2(20, size.y / 2.0), lock_message, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.9, 0.9, 0.9))
	
	
func _gui_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			accept_event()
			if event.ctrl_pressed:
				zoom_timeline(1.15, event.position)
			else:
				scroll_offset = max(-NEGATIVE_MARGIN, scroll_offset - 40.0)
				queue_redraw()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			accept_event()
			if event.ctrl_pressed:
				zoom_timeline(1.0 / 1.15, event.position)
			else:
				scroll_offset += 40.0
				queue_redraw()
			return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not video_range.is_empty() and is_point_in_video_range(event.position):
				dragging_video_range = true
				var range_start_x: float = video_range["start"] * pixels_per_frame - scroll_offset
				video_range_drag_offset = event.position.x - range_start_x
				return

			var hit_frame: int = get_keyframe_at_position(event.position)
			if hit_frame != -1:
				dragging_keyframe_frame = hit_frame
			else:
				dragging_playhead = true
				set_frame_from_mouse(event.position.x)
		else:
			dragging_video_range = false
			if dragging_keyframe_frame != -1:
				var new_frame: int = int(round((event.position.x + scroll_offset) / pixels_per_frame))
				new_frame = max(0, new_frame)
				if new_frame != dragging_keyframe_frame:
					keyframe_moved.emit(dragging_keyframe_frame, new_frame)
				dragging_keyframe_frame = -1
			dragging_playhead = false

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var hit_frame: int = get_keyframe_at_position(event.position)
		if hit_frame != -1:
			keyframe_delete_requested.emit(hit_frame)

	elif event is InputEventMouseMotion:
		if dragging_video_range:
			var new_x: float = event.position.x - video_range_drag_offset
			var new_start: int = int(round((new_x + scroll_offset) / pixels_per_frame))
			new_start = max(0, new_start)
			var duration: int = video_range["end"] - video_range["start"]
			video_range["start"] = new_start
			video_range["end"] = new_start + duration
			video_range_dragged.emit(new_start)
			queue_redraw()
		elif dragging_keyframe_frame != -1:
			var preview_frame: int = int(round((event.position.x + scroll_offset) / pixels_per_frame))
			preview_frame = max(0, preview_frame)
			update_keyframe_preview(dragging_keyframe_frame, preview_frame)
		elif dragging_playhead:
			set_frame_from_mouse(event.position.x)

func is_point_in_video_range(pos: Vector2) -> bool:
	var start_x: float = video_range["start"] * pixels_per_frame - scroll_offset
	var end_x: float = video_range["end"] * pixels_per_frame - scroll_offset
	var y_top: float = 22
	var y_bottom: float = 32
	return pos.x >= start_x and pos.x <= end_x and pos.y >= y_top and pos.y <= y_bottom

func get_keyframe_at_position(pos: Vector2) -> int:
	for key in keyframes:
		var kx: float = key["frame"] * pixels_per_frame - scroll_offset
		var ky: float = size.y - 8.0
		if pos.distance_to(Vector2(kx, ky)) <= KEYFRAME_CLICK_RADIUS:
			return key["frame"]
	return -1

func update_keyframe_preview(old_frame: int, new_frame: int) -> void:
	for key in keyframes:
		if key["frame"] == old_frame:
			key["frame"] = new_frame
			dragging_keyframe_frame = new_frame
			break
	queue_redraw()

func set_frame_from_mouse(mouse_x: float) -> void:
	var frame: int = int(round((mouse_x + scroll_offset) / pixels_per_frame))
	current_frame = max(0, frame)
	frame_changed.emit(current_frame)
	queue_redraw()
	
func set_keyframes(new_keyframes: Array) -> void:
	keyframes = new_keyframes

func zoom_timeline(factor: float, mouse_pos: Vector2) -> void:
	# El cuadro que está bajo el mouse antes de hacer zoom
	var frame_under_mouse: float = (mouse_pos.x + scroll_offset) / pixels_per_frame

	pixels_per_frame = clamp(pixels_per_frame * factor, MIN_PIXELS_PER_FRAME, MAX_PIXELS_PER_FRAME)

	# Reajustamos el scroll para que ese mismo cuadro se quede bajo el mouse después del zoom
	scroll_offset = frame_under_mouse * pixels_per_frame - mouse_pos.x
	scroll_offset = max(-NEGATIVE_MARGIN, scroll_offset)

	queue_redraw()

func set_end_frame(value: int) -> void:
	end_frame = value
	queue_redraw()

func _on_mouse_entered() -> void:
	mouse_is_over = true

func _on_mouse_exited() -> void:
	mouse_is_over = false

func set_video_range(start: int, end: int) -> void:
	video_range = {"start": start, "end": end}

func clear_video_range() -> void:
	video_range = {}
