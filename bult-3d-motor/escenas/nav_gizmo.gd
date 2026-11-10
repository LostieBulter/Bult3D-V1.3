extends Control

@export var camera_rig_path: NodePath
var camera_rig: Node3D
var camera_pitch: Node3D
var cam: Camera3D
# Recuerda, para cada letra, si la última vista usada fue positiva o negativa
var axis_toggle_state := {"X": true, "Y": true, "Z": true}

const RADIUS := 32.0          # distancia del centro a cada bolita
const BALL_POS_SIZE := 10.0   # tamaño de las bolitas positivas (X, Y, Z)
const BALL_NEG_SIZE := 7.0    # tamaño de las bolitas negativas (-X, -Y, -Z)
const CLICK_MARGIN := 4.0     # tolerancia extra para hacer clic

# Cada eje: nombre visible, dirección en el mundo, color, y si es el lado "positivo"
var axes := [
	{"name": "X",  "dir": Vector3(1, 0, 0),  "color": Color(0.86, 0.24, 0.30), "positive": true},
	{"name": "",   "dir": Vector3(-1, 0, 0), "color": Color(0.86, 0.24, 0.30), "positive": false},
	{"name": "Y",  "dir": Vector3(0, 1, 0),  "color": Color(0.45, 0.77, 0.20), "positive": true},
	{"name": "",   "dir": Vector3(0, -1, 0), "color": Color(0.45, 0.77, 0.20), "positive": false},
	{"name": "Z",  "dir": Vector3(0, 0, 1),  "color": Color(0.25, 0.53, 0.86), "positive": true},
	{"name": "",   "dir": Vector3(0, 0, -1), "color": Color(0.25, 0.53, 0.86), "positive": false},
]

var screen_data := []       # se recalcula cada frame: posición en pantalla + info de cada eje
var hovered_index := -1     # cuál bolita tiene el mouse encima ahora mismo
var active_tween: Tween
var font: Font

func _ready() -> void:
	camera_rig = get_node(camera_rig_path)
	camera_pitch = camera_rig.get_node("CameraPitch")
	cam = camera_pitch.get_node("Camera3D")
	mouse_filter = Control.MOUSE_FILTER_STOP
	font = ThemeDB.fallback_font

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var center := size / 2.0
	var basis: Basis = cam.global_transform.basis
	screen_data.clear()

	# Fondo circular sutil, para separar el gizmo del resto de la escena
	draw_circle(center, RADIUS + BALL_POS_SIZE + 6.0, Color(0, 0, 0, 0.25))

	var entries := []
	for i in axes.size():
		var axis: Dictionary = axes[i]
		var world_dir: Vector3 = axis["dir"]
		var local_dir: Vector3 = basis.inverse() * world_dir
		var screen_pos: Vector2 = center + Vector2(local_dir.x, -local_dir.y) * RADIUS

		entries.append({
			"index": i,
			"name": axis["name"],
			"color": axis["color"],
			"positive": axis["positive"],
			"screen_pos": screen_pos,
			"depth": local_dir.z,   # negativo = más cerca de la cámara (al frente)
		})

	screen_data = entries.duplicate(true)

	# Dibujamos primero lo que está más atrás, para que lo de adelante quede encima
	entries.sort_custom(func(a, b): return a["depth"] > b["depth"])

	for e in entries:
		var pos: Vector2 = e["screen_pos"]
		var is_hovered: bool = (e["index"] == hovered_index)

		if e["positive"]:
			# Bolita sólida grande, con su letra adentro
			var r: float = BALL_POS_SIZE + (2.0 if is_hovered else 0.0)
			var col: Color = e["color"]
			if is_hovered:
				col = col.lightened(0.3)
			draw_circle(pos, r, col)

			# Dibujamos la letra (X, Y o Z) centrada en la bolita
			var label: String = e["name"]
			var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
			draw_string(font, pos - text_size / 2.0 + Vector2(0, text_size.y * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color.WHITE)
		else:
			# Bolita hueca (solo contorno), más chica, sin letra
			var r: float = BALL_NEG_SIZE + (2.0 if is_hovered else 0.0)
			var col: Color = e["color"]
			if is_hovered:
				draw_circle(pos, r, col * Color(1, 1, 1, 0.5))
			draw_arc(pos, r, 0, TAU, 20, col, 2.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hovered_index = get_closest_axis(event.position)

	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var idx: int = get_closest_axis(event.position)
		if idx != -1:
			snap_to_axis(axes[idx]["dir"])

func get_closest_axis(mouse_pos: Vector2) -> int:
	var closest_index := -1
	var closest_dist := INF
	for e in screen_data:
		var r: float = BALL_POS_SIZE if e["positive"] else BALL_NEG_SIZE
		var d: float = mouse_pos.distance_to(e["screen_pos"])
		if d <= r + CLICK_MARGIN and d < closest_dist:
			closest_dist = d
			closest_index = e["index"]
	return closest_index

func snap_to_axis(world_dir: Vector3) -> void:
	var yaw := 0.0
	var pitch := 0.0

	if world_dir.x == 1:
		yaw = -PI / 2.0
	elif world_dir.x == -1:
		yaw = PI / 2.0
	elif world_dir.z == 1:
		yaw = 0.0
	elif world_dir.z == -1:
		yaw = PI
	elif world_dir.y == 1:
		pitch = -PI / 2.0 + 0.001
	elif world_dir.y == -1:
		pitch = PI / 2.0 - 0.001

	if active_tween and active_tween.is_valid():
		active_tween.kill()

	active_tween = create_tween()
	active_tween.set_parallel(true)
	active_tween.tween_property(camera_rig, "rotation:y", yaw, 0.25)
	active_tween.tween_property(camera_pitch, "rotation:x", pitch, 0.25)

# Llamada desde afuera (por teclado) para ir a la vista de un eje por letra
func snap_to_axis_by_letter(letter: String) -> void:
	var is_positive: bool = axis_toggle_state[letter]

	var dir := Vector3.ZERO
	match letter:
		"X":
			dir = Vector3(1, 0, 0) if is_positive else Vector3(-1, 0, 0)
		"Y":
			dir = Vector3(0, 1, 0) if is_positive else Vector3(0, -1, 0)
		"Z":
			dir = Vector3(0, 0, 1) if is_positive else Vector3(0, 0, -1)

	# La próxima vez que se toque esta tecla, va al lado contrario
	axis_toggle_state[letter] = not is_positive

	snap_to_axis(dir)
