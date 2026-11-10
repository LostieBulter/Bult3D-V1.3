extends Node3D

@export var rotation_speed := 0.005
@export var zoom_speed := 0.5

@export var min_pitch_deg := -80.0
@export var max_pitch_deg := 10.0

@onready var pitch_pivot: Node3D = $CameraPitch
@onready var camera: Camera3D = $CameraPitch/Camera3D
@export var nav_gizmo_path: NodePath
@export var tool_selector_path: NodePath
@export var pan_speed := 0.01
@export var selection_manager_path: NodePath
@export var object_toolbar_path: NodePath
@export var history_manager_path: NodePath
@export var timeline_ruler_path: NodePath
@export var render_manager_path: NodePath

@export var min_distance := 0.05
@export var max_distance := 500.0




var render_manager: Node
var following_camera: Camera3D = null
var timeline_ruler: Control
var history_manager: Node
var selection_manager: Node3D
var object_toolbar: Control
var scene_camera: Camera3D = null
var mouse_down := false
var click_start_pos := Vector2.ZERO
var axis_key_locked: String = ""  # evita que una tecla mantenida dispare varias veces
var nav_gizmo: Control
var dragging := false
var tool_selector: Control

const DRAG_THRESHOLD := 6.0
var default_real_camera_fov: float = 75.0
var viewing_camera_env_active: bool = false
var saved_zoom_z: float = 8.0

var home_rig_transform: Transform3D
var home_pitch_transform: Transform3D
var home_camera_position: Vector3



func _ready() -> void:
	home_rig_transform = transform
	home_pitch_transform = pitch_pivot.transform
	home_camera_position = camera.position
	if render_manager_path != NodePath(""):
		render_manager = get_node(render_manager_path)
	
	
	
	if tool_selector != null:
		tool_selector.camera_view_requested.connect(_on_camera_view_requested)
	
	if timeline_ruler_path != NodePath(""):
		timeline_ruler = get_node(timeline_ruler_path)
	
	if history_manager_path != NodePath(""):
		history_manager = get_node(history_manager_path)
	if selection_manager_path != NodePath(""):
		selection_manager = get_node(selection_manager_path)
	if nav_gizmo_path != NodePath(""):
		nav_gizmo = get_node(nav_gizmo_path)
	else:
		push_warning("CameraRig: no asignaste Nav Gizmo Path en el Inspector")

	if tool_selector_path != NodePath(""):
		tool_selector = get_node(tool_selector_path)
	else:
		push_warning("CameraRig: no asignaste Tool Selector Path en el Inspector")
	if selection_manager_path != NodePath(""):
		selection_manager = get_node(selection_manager_path)
	if object_toolbar_path != NodePath(""):
		object_toolbar = get_node(object_toolbar_path)
		
		default_real_camera_fov = camera.fov
	
func _process(_delta: float) -> void:
	if following_camera != null:
		var pitch_pivot: Node3D = get_node("CameraPitch")
		var real_camera: Camera3D = pitch_pivot.get_node("Camera3D")

		pitch_pivot.rotation = Vector3.ZERO
		global_transform = following_camera.global_transform

		var offset: Vector3 = real_camera.position
		global_position = following_camera.global_transform.origin - following_camera.global_transform.basis * offset


func _unhandled_input(event: InputEvent) -> void:
	if render_manager != null and render_manager.is_rendering:
		return
	
	if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed:
		if event.keycode == KEY_Z and history_manager != null:
			history_manager.undo()
			return
		if event.keycode == KEY_Y and history_manager != null:
			history_manager.redo()
			return
			
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_8:
		reset_camera_view()
		return
		
	if event is InputEventKey and not event.echo:
		if event.pressed:
			if event.keycode == KEY_1 and tool_selector != null:
				tool_selector.set_tool(tool_selector.Tool.ORBIT)
				return
			if event.keycode == KEY_2 and tool_selector != null:
				tool_selector.set_tool(tool_selector.Tool.PAN)
				return
		
	
	
		if event.keycode in [KEY_ALT, KEY_X, KEY_Y, KEY_Z]:
			if not event.pressed:
				if event.keycode == KEY_ALT or String(OS.get_keycode_string(event.keycode)) == axis_key_locked:
					axis_key_locked = ""
				return

			if event.alt_pressed and nav_gizmo != null:
				var letter := ""
				match event.keycode:
					KEY_X: letter = "X"
					KEY_Y: letter = "Y"
					KEY_Z: letter = "Z"

				if letter != "" and axis_key_locked != letter:
					axis_key_locked = letter
					nav_gizmo.snap_to_axis_by_letter(letter)
				return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				mouse_down = true
				dragging = false
				click_start_pos = event.position
			else:
				if mouse_down and not dragging:
					try_select(event.position)
				mouse_down = false
				dragging = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if timeline_ruler != null and timeline_ruler.mouse_is_over:
				return
			zoom(-zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if timeline_ruler != null and timeline_ruler.mouse_is_over:
				return
			zoom(zoom_speed)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if following_camera != null or viewing_camera_env_active:
					stop_following_camera()
				mouse_down = true
				dragging = false
				click_start_pos = event.position
		
		
		
	elif event is InputEventMouseMotion and mouse_down:
		if selection_manager != null and selection_manager.is_dragging_gizmo:
			return

		if not dragging and event.position.distance_to(click_start_pos) > DRAG_THRESHOLD:
			dragging = true

		if dragging:
			var use_pan: bool = tool_selector != null and tool_selector.current_tool == tool_selector.Tool.PAN
			if use_pan:
				var right: Vector3 = pitch_pivot.global_transform.basis.x
				var up: Vector3 = pitch_pivot.global_transform.basis.y
				position -= right * event.relative.x * pan_speed
				position += up * event.relative.y * pan_speed
			else:
				rotate_y(-event.relative.x * rotation_speed)
				pitch_pivot.rotate_x(-event.relative.y * rotation_speed)

func try_select(screen_pos: Vector2) -> void:
	if selection_manager == null:
		return
	if Time.get_ticks_msec() - selection_manager.last_gizmo_drag_end_time < 150:
		return  # acabamos de soltar un gizmo, todavía no tocamos la selección
	selection_manager.try_select(screen_pos)
	
func zoom(amount: float) -> void:
	if viewing_camera_env_active:
		return  # en vista de cámara el scroll no toca el zoom, así no se acumula
	var pos := camera.position
	var step: float = max(pos.z * 0.12, 0.02)
	if amount < 0.0:
		pos.z = max(pos.z - step, min_distance)
	else:
		pos.z = min(pos.z + max(step, 0.05), max_distance)
	camera.position = pos

func _on_camera_view_requested() -> void:
	if scene_camera != null:
		global_transform = scene_camera.global_transform

func start_following_camera(cam: Camera3D) -> void:
	if not viewing_camera_env_active:
		saved_zoom_z = camera.position.z
	following_camera = cam
	viewing_camera_env_active = true
	camera.fov = cam.fov
	camera.environment = cam.environment

func stop_following_camera() -> void:
	var was_active: bool = viewing_camera_env_active
	following_camera = null
	viewing_camera_env_active = false
	camera.fov = default_real_camera_fov
	camera.environment = null
	if was_active:
		# Volvemos al zoom que tenías, dejando la cámara en el mismo lugar del mundo
		var z_now: float = camera.position.z
		var z_back: float = saved_zoom_z if saved_zoom_z > 0.5 else 8.0
		global_position += global_transform.basis.z * (z_now - z_back)
		camera.position.z = z_back

func mark_camera_view_active() -> void:
	if not viewing_camera_env_active:
		saved_zoom_z = camera.position.z
	viewing_camera_env_active = true

func reset_camera_view() -> void:
	if following_camera != null or viewing_camera_env_active:
		stop_following_camera()
	transform = home_rig_transform
	pitch_pivot.transform = home_pitch_transform
	camera.position = home_camera_position
