extends Node3D

@export var camera_rig_path: NodePath
@export var object_toolbar_path: NodePath
@export var delete_menu_path: NodePath
@export var outliner_path: NodePath
@export var history_manager_path: NodePath
@export var light_panel_path: NodePath

@export var view_camera_menu_path: NodePath
@export var render_manager_path: NodePath
@export var materials_panel_path: NodePath
const GIZMO_SCREEN_SIZE := 0.12
@export var music_panel_path: NodePath
@export var video_panel_path: NodePath
var video_panel: Panel
var music_panel: Panel
var materials_panel: Node
var pending_material_to_apply = null
var render_manager: Node
var view_camera_menu: PopupMenu
var pending_camera_view: Camera3D = null
@export var camera_panel_path: NodePath
var camera_panel: Node
@export var camera_rig_ref_path: NodePath
var camera_rig_ref: Node3D
var keyboard_axis_line: MeshInstance3D = null
var keyboard_move_active := false
var keyboard_move_axis: String = ""
var keyboard_move_start_pos: Vector3
var keyboard_move_start_mouse: Vector2


var keyboard_scale_active := false
var keyboard_scale_axis: String = ""   # "" = escala uniforme (los 3 ejes)
var keyboard_scale_start_scale: Vector3
var keyboard_scale_start_pos: Vector3
var keyboard_scale_start_mouse: Vector2


var light_panel: Panel
var history_manager: Node
var camera: Camera3D
var selected_object: StaticBody3D = null
var outline_instance: MeshInstance3D = null

var object_toolbar: Control
var delete_menu: PopupMenu
var outliner: Panel

var is_dragging_gizmo := false
var last_click_time: float = 0.0
const CLICK_RADIUS_TOLERANCE := 15.0
const CLICK_TIME_TOLERANCE := 1.0  # segundos

# --- Mover ---
var move_gizmo: Node3D = null
var last_gizmo_drag_end_time: int = -99999
var dragging_axis: String = ""
var drag_start_mouse: Vector2
var drag_start_object_pos: Vector3

# --- Rotar ---
var rotate_gizmo: Node3D = null
var dragging_rotate_axis: String = ""
var rotate_start_rotation: Vector3
var rotate_start_angle: float = 0.0

# --- Escalar ---
var scale_gizmo: Node3D = null
var dragging_scale_axis: String = ""
var scale_drag_start_mouse: Vector2
var scale_start_value: Vector3
var scale_start_object_pos: Vector3

var collision_scale_gizmo: Node3D = null
var dragging_collision_scale_axis: String = ""
var collision_scale_drag_start_mouse: Vector2
var collision_scale_start_value: Vector3
#-----------------------------------------------

@export var mode_bar_path: NodePath
var mode_bar: Node

var selected_skeleton: Skeleton3D = null
var selected_bone_idx: int = -1
var all_bone_markers: Dictionary = {}
var current_skeleton_for_markers: Skeleton3D = null
var bone_rotate_gizmo: Node3D = null
var dragging_bone_axis: String = ""
var bone_rotate_start_pose: Quaternion
var bone_rotate_start_angle: float = 0.0
var bone_rotate_start_world_axis: Vector3
@export var animation_manager_path: NodePath
var animation_manager: Node
@export var bone_axis_panel_path: NodePath
var bone_axis_panel: Control
var bone_move_gizmo: Node3D = null
var dragging_bone_move_axis: String = ""
var bone_move_start_mouse: Vector2
var bone_move_start_pos: Vector3

var bone_scale_gizmo: Node3D = null
var dragging_bone_scale_axis: String = ""
var bone_scale_start_mouse: Vector2
var bone_scale_start_value: Vector3

var ik_gizmo: Area3D = null
var ik_target_pos: Vector3 = Vector3.ZERO
var ik_active_skeleton: Skeleton3D = null
var ik_active_bone_idx: int = -1
var dragging_ik_target: bool = false
var ik_drag_start_target: Vector3

var keyboard_bone_move_active := false
var keyboard_bone_move_axis: String = ""
var keyboard_bone_move_start_pos: Vector3
var keyboard_bone_move_start_mouse: Vector2

var keyboard_collision_scale_active := false
var keyboard_collision_scale_axis: String = ""
var keyboard_collision_scale_start: Vector3
var keyboard_collision_scale_start_mouse: Vector2
var collision_debug_box: Node3D = null

var ik_drag_start_root_rotation: Quaternion
var ik_drag_start_mid_rotation: Quaternion
var ik_drag_root_idx: int = -1
var ik_drag_mid_idx: int = -1

var keyboard_collision_move_active := false
var keyboard_collision_move_axis: String = ""
var keyboard_collision_move_start_mouse: Vector2
var keyboard_collision_move_start_pos: Vector3
var skeleton_extent: float = 0.0

var bone_size_multiplier: float = 1.0
var bone_size_panel: Panel = null
var bone_size_spinbox: SpinBox = null
var gizmo_size_spinbox: SpinBox = null
var collision_size_panel: Panel = null
var collision_size_spinboxes: Array = []
var collision_pos_spinboxes: Array = []

var origin_panel: Panel = null
var origin_spinboxes: Array = []
var origin_marker: MeshInstance3D = null
var origin_gizmo: Node3D = null
var dragging_origin_axis: String = ""
var origin_drag_start_mouse: Vector2
var origin_drag_start_pos: Vector3
var origin_drag_applied: float = 0.0

var rotate_start_basis: Basis

func _ready() -> void:
	if view_camera_menu_path != NodePath(""):
		get_node(view_camera_menu_path).hide()

	if mode_bar_path != NodePath(""):
		mode_bar = get_node(mode_bar_path)

	if bone_axis_panel_path != NodePath(""):
		bone_axis_panel = get_node(bone_axis_panel_path)
		bone_axis_panel.visible = false

	if animation_manager_path != NodePath(""):
		animation_manager = get_node(animation_manager_path)
		
	if video_panel_path != NodePath(""):
		video_panel = get_node(video_panel_path)
	
	if music_panel_path != NodePath(""):
		music_panel = get_node(music_panel_path)
	
	if materials_panel_path != NodePath(""):
		materials_panel = get_node(materials_panel_path)
		materials_panel.material_apply_requested.connect(_on_material_apply_requested)
	
	if render_manager_path != NodePath(""):
		render_manager = get_node(render_manager_path)
	
	if view_camera_menu_path != NodePath(""):
		view_camera_menu = get_node(view_camera_menu_path)
		view_camera_menu.clear()
		view_camera_menu.add_item("Ver desde esta cámara", 0)
		view_camera_menu.add_item("Seguir esta cámara (en vivo)", 1)
		view_camera_menu.id_pressed.connect(_on_view_camera_menu_pressed)
		view_camera_menu.add_item("Fondo y campo de visión...", 2)
	if camera_panel_path != NodePath(""):
		camera_panel = get_node(camera_panel_path)
	if camera_rig_ref_path != NodePath(""):
		camera_rig_ref = get_node(camera_rig_ref_path)
	
	
	if light_panel_path != NodePath(""):
		light_panel = get_node(light_panel_path)
		light_panel.delete_requested.connect(_on_light_delete_requested)
	
	
	if history_manager_path != NodePath(""):
		history_manager = get_node(history_manager_path)
	var camera_rig: Node3D = get_node(camera_rig_path)
	camera = camera_rig.get_node("CameraPitch/Camera3D")

	if object_toolbar_path != NodePath(""):
		object_toolbar = get_node(object_toolbar_path)

	if delete_menu_path != NodePath(""):
		delete_menu = get_node(delete_menu_path)
		delete_menu.clear()
		delete_menu.add_item("Eliminar", 0)
		delete_menu.id_pressed.connect(_on_delete_menu_id_pressed)

	if outliner_path != NodePath(""):
		outliner = get_node(outliner_path)


func _process(_delta: float) -> void:
	update_move_gizmo()
	update_rotate_gizmo()
	update_scale_gizmo()
	update_bone_gizmo()
	update_collision_scale_gizmo()
	_update_origin_panel()



# ============================================================
# SELECCIÓN
# ============================================================

var last_click_pos: Vector2 = Vector2(-999, -999)
var last_click_results: Array = []
var last_click_index: int = 0

func try_select(screen_pos: Vector2) -> void:
	var in_animation_mode: bool = mode_bar != null and mode_bar.anim_button.button_pressed

	if in_animation_mode and current_skeleton_for_markers != null:
		if try_select_bone(current_skeleton_for_markers, screen_pos):
			return

	var space_state := get_world_3d().direct_space_state
	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var to: Vector3 = from + camera.project_ray_normal(screen_pos) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var result := space_state.intersect_ray(query)

	if pending_material_to_apply != null:
		if result.has("collider") and result["collider"] is StaticBody3D:
			apply_material_to_object(result["collider"], pending_material_to_apply)
		pending_material_to_apply = null
		return

	if result.has("collider") and result["collider"] is StaticBody3D:
		var collider: StaticBody3D = result["collider"]

		if in_animation_mode and collider.has_meta("is_imported_model"):
			var skeleton: Skeleton3D = find_skeleton_in(collider)
			if skeleton != null:
				select_object(collider)
				try_select_bone(skeleton, screen_pos)
				return

		clear_bone_selection()
		select_object(collider)
	else:
		clear_bone_selection()
		deselect()

func select_object(body: StaticBody3D) -> void:
	if body == selected_object:
		return

	_force_confirm_pending_keyboard_ops()
	deselect()
	selected_object = body
	var cs: CollisionShape3D = find_collision_shape(body)
	if cs != null:
		print("DEBUG al seleccionar: body.scale=", body.scale, " collision_shape.scale=", cs.scale)
		
	var aabb: AABB
	var existing_shape: CollisionShape3D = find_collision_shape(body)
	if existing_shape != null and existing_shape.shape is BoxShape3D:
		var box: BoxShape3D = existing_shape.shape
		var half: Vector3 = (box.size * existing_shape.scale) / 2.0
		aabb = AABB(existing_shape.position - half, box.size * existing_shape.scale)
	else:
		aabb = get_combined_aabb(body)
	aabb = aabb.grow(0.03)

	outline_instance = MeshInstance3D.new()
	outline_instance.name = "SelectionOutline"
	outline_instance.mesh = build_wireframe_box(aabb)

	outline_instance.material_override = make_gizmo_material(Color.YELLOW)

	body.add_child(outline_instance)
	_refresh_materials_panel_for_selection()

func deselect() -> void:
	if outline_instance and is_instance_valid(outline_instance):
		outline_instance.queue_free()
	outline_instance = null
	selected_object = null

	_refresh_materials_panel_for_selection()

	if animation_manager != null:
		animation_manager.last_selected_object = null
		animation_manager.refresh_timeline_for_selection()
		animation_manager.refresh_media_range_for_selection()
	
	if move_gizmo != null:
		move_gizmo.queue_free()
		move_gizmo = null
	if rotate_gizmo != null:
		rotate_gizmo.queue_free()
		rotate_gizmo = null
	if scale_gizmo != null:
		scale_gizmo.queue_free()
		scale_gizmo = null


func build_wireframe_box(aabb: AABB) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)

	var p: Vector3 = aabb.position
	var s: Vector3 = aabb.size
	var corners := [
		p, p + Vector3(s.x, 0, 0), p + Vector3(s.x, s.y, 0), p + Vector3(0, s.y, 0),
		p + Vector3(0, 0, s.z), p + Vector3(s.x, 0, s.z), p + Vector3(s.x, s.y, s.z), p + Vector3(0, s.y, s.z)
	]
	var edges := [
		[0,1],[1,2],[2,3],[3,0],
		[4,5],[5,6],[6,7],[7,4],
		[0,4],[1,5],[2,6],[3,7]
	]
	for e in edges:
		st.add_vertex(corners[e[0]])
		st.add_vertex(corners[e[1]])

	return st.commit()


# ============================================================
# GIZMO DE MOVER
# ============================================================

func update_move_gizmo() -> void:
	var should_show: bool = selected_object != null and object_toolbar != null and object_toolbar.current_tool == object_toolbar.Tool.MOVE
	if should_show and move_gizmo == null:
		create_move_gizmo()
	elif not should_show and move_gizmo != null:
		move_gizmo.get_parent().remove_child(move_gizmo)
		move_gizmo.free()
		move_gizmo = null
	if move_gizmo != null and selected_object != null:
		move_gizmo.global_position = selected_object.global_position
		move_gizmo.scale = Vector3.ONE * get_object_gizmo_size()


func create_move_gizmo() -> void:
	move_gizmo = Node3D.new()
	move_gizmo.name = "MoveGizmo"
	get_tree().current_scene.add_child(move_gizmo)

	add_arrow(move_gizmo, Vector3(1, 0, 0), Color.RED, "X")
	add_arrow(move_gizmo, Vector3(0, 1, 0), Color.GREEN, "Y")
	add_arrow(move_gizmo, Vector3(0, 0, 1), Color.BLUE, "Z")


func add_arrow(parent: Node3D, dir: Vector3, color: Color, axis_name: String) -> void:
	var length := 1.0

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	st.set_color(color)
	st.add_vertex(Vector3.ZERO)
	st.add_vertex(dir * length)
	var line_mesh := st.commit()

	var line_instance := MeshInstance3D.new()
	line_instance.mesh = line_mesh
	var mat := make_gizmo_material(color, true)
	line_instance.material_override = mat
	parent.add_child(line_instance)

	var body := Area3D.new()
	body.name = "Arrow_" + axis_name
	body.position = dir * length
	body.collision_layer = 2
	body.collision_mask = 0

	var cone := MeshInstance3D.new()
	var cone_mesh := SphereMesh.new()
	cone_mesh.radius = 0.08
	cone_mesh.height = 0.16
	cone.mesh = cone_mesh
	var cone_mat := make_gizmo_material(color)
	cone.material_override = cone_mat
	body.add_child(cone)

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.15
	col.shape = shape
	body.add_child(col)

	body.input_ray_pickable = true
	body.input_event.connect(_on_arrow_input.bind(axis_name))

	parent.add_child(body)


func _on_arrow_input(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int, axis_name: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		dragging_axis = axis_name
		is_dragging_gizmo = true
		drag_start_mouse = get_viewport().get_mouse_position()
		drag_start_object_pos = selected_object.global_position


# ============================================================
# GIZMO DE ROTAR
# ============================================================

func update_rotate_gizmo() -> void:
	var should_show: bool = selected_object != null and object_toolbar != null and object_toolbar.current_tool == object_toolbar.Tool.ROTATE
	if should_show and rotate_gizmo == null:
		create_rotate_gizmo()
	elif not should_show and rotate_gizmo != null:
		rotate_gizmo.get_parent().remove_child(rotate_gizmo)
		rotate_gizmo.free()
		rotate_gizmo = null
	if rotate_gizmo != null and selected_object != null:
		rotate_gizmo.global_position = selected_object.global_position
		rotate_gizmo.scale = Vector3.ONE * get_object_gizmo_size()


func create_rotate_gizmo() -> void:
	rotate_gizmo = Node3D.new()
	rotate_gizmo.name = "RotateGizmo"
	get_tree().current_scene.add_child(rotate_gizmo)

	add_ring(rotate_gizmo, "X", Color.RED)
	add_ring(rotate_gizmo, "Y", Color.GREEN)
	add_ring(rotate_gizmo, "Z", Color.BLUE)


func add_ring(parent: Node3D, axis_name: String, color: Color) -> void:
	var radius := 1.0
	var thickness := 0.02
	var segments := 32

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	st.set_color(color)

	for i in segments + 1:
		var angle: float = (float(i) / segments) * TAU
		var inner := Vector3.ZERO
		var outer := Vector3.ZERO
		match axis_name:
			"X":
				inner = Vector3(0, cos(angle) * (radius - thickness), sin(angle) * (radius - thickness))
				outer = Vector3(0, cos(angle) * (radius + thickness), sin(angle) * (radius + thickness))
			"Y":
				inner = Vector3(cos(angle) * (radius - thickness), 0, sin(angle) * (radius - thickness))
				outer = Vector3(cos(angle) * (radius + thickness), 0, sin(angle) * (radius + thickness))
			"Z":
				inner = Vector3(cos(angle) * (radius - thickness), sin(angle) * (radius - thickness), 0)
				outer = Vector3(cos(angle) * (radius + thickness), sin(angle) * (radius + thickness), 0)
		st.add_vertex(inner)
		st.add_vertex(outer)

	var ring_mesh := st.commit()

	var area := Area3D.new()
	area.name = "Ring_" + axis_name

	area.collision_layer = 2
	area.collision_mask = 0

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = ring_mesh
	var mat := make_gizmo_material(color, true)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = mat
	area.add_child(mesh_instance)

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = thickness * 2.0
	col.shape = shape
	match axis_name:
		"X": col.rotation = Vector3(0, 0, deg_to_rad(90))
		"Z": col.rotation = Vector3(deg_to_rad(90), 0, 0)
	area.add_child(col)

	area.input_ray_pickable = true
	area.input_event.connect(_on_ring_input.bind(axis_name))

	parent.add_child(area)


func _on_ring_input(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int, axis_name: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		dragging_rotate_axis = axis_name
		is_dragging_gizmo = true
		rotate_start_rotation = selected_object.rotation_degrees
		rotate_start_basis = selected_object.global_transform.basis   # <-- nueva

		var screen_center: Vector2 = camera.unproject_position(selected_object.global_position)
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		rotate_start_angle = (mouse_pos - screen_center).angle()


# ============================================================
# GIZMO DE ESCALAR
# ============================================================

func update_scale_gizmo() -> void:
	var should_show: bool = selected_object != null and object_toolbar != null and object_toolbar.current_tool == object_toolbar.Tool.SCALE
	if should_show and scale_gizmo == null:
		create_scale_gizmo()
	elif not should_show and scale_gizmo != null:
		scale_gizmo.get_parent().remove_child(scale_gizmo)
		scale_gizmo.free()
		scale_gizmo = null
	if scale_gizmo != null and selected_object != null:
		scale_gizmo.global_position = selected_object.global_position
		# Ajustamos el tamaño del gizmo según qué tan grande esté el objeto
		scale_gizmo.scale = Vector3.ONE * get_object_gizmo_size()


func create_scale_gizmo() -> void:
	scale_gizmo = Node3D.new()
	scale_gizmo.name = "ScaleGizmo"
	get_tree().current_scene.add_child(scale_gizmo)

	add_scale_handle(scale_gizmo, Vector3(1, 0, 0), Color.RED, "X")
	add_scale_handle(scale_gizmo, Vector3(0, 1, 0), Color.GREEN, "Y")
	add_scale_handle(scale_gizmo, Vector3(0, 0, 1), Color.BLUE, "Z")
	add_scale_handle(scale_gizmo, Vector3.ZERO, Color.WHITE, "ALL")


func add_scale_handle(parent: Node3D, dir: Vector3, color: Color, axis_name: String) -> void:
	var length := 1.0

	if axis_name != "ALL":
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_LINES)
		st.set_color(color)
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(dir * length)
		var line_instance := MeshInstance3D.new()
		line_instance.mesh = st.commit()
		var line_mat := make_gizmo_material(color, true)
		line_instance.material_override = line_mat
		parent.add_child(line_instance)

	var area := Area3D.new()
	area.name = "ScaleHandle_" + axis_name
	area.position = dir * length if axis_name != "ALL" else Vector3.ZERO
	area.collision_layer = 2
	area.collision_mask = 0

	var box := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3.ONE * 0.15
	box.mesh = box_mesh
	var mat := make_gizmo_material(color)
	box.material_override = mat
	area.add_child(box)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * 0.2
	col.shape = shape
	area.add_child(col)

	area.input_ray_pickable = true
	area.input_event.connect(_on_scale_handle_input.bind(axis_name))

	parent.add_child(area)


func _on_scale_handle_input(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int, axis_name: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		dragging_scale_axis = axis_name
		is_dragging_gizmo = true
		scale_drag_start_mouse = get_viewport().get_mouse_position()
		scale_start_value = selected_object.scale
		scale_start_object_pos = selected_object.global_position


# ============================================================
# INPUT GLOBAL (clic derecho para borrar + arrastre de gizmos)
# ============================================================

func _unhandled_input(event: InputEvent) -> void:
	if render_manager != null and render_manager.is_rendering:
		return

	if event is InputEventMouseMotion and dragging_origin_axis != "" and selected_object != null:
		var oa := Vector3.ZERO
		match dragging_origin_axis:
			"X": oa = Vector3(1, 0, 0)
			"Y": oa = Vector3(0, 1, 0)
			"Z": oa = Vector3(0, 0, 1)
		var o_screen: Vector2 = camera.unproject_position(origin_drag_start_pos)
		var a_screen: Vector2 = camera.unproject_position(origin_drag_start_pos + oa)
		var px_per_unit: float = max(o_screen.distance_to(a_screen), 1.0)
		var screen_dir: Vector2 = (a_screen - o_screen).normalized()
		var mouse_delta: Vector2 = get_viewport().get_mouse_position() - origin_drag_start_mouse
		var amount: float = mouse_delta.dot(screen_dir) / px_per_unit
		var step: float = amount - origin_drag_applied
		origin_drag_applied = amount
		var d_local: Vector3 = selected_object.global_transform.basis.inverse() * (oa * step)
		set_object_origin(selected_object, d_local)
		return


	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_G and not keyboard_move_active and not keyboard_scale_active and not keyboard_bone_move_active and selected_skeleton != null and selected_bone_idx != -1:
			start_keyboard_bone_move()
			return

		if event.keycode == KEY_B and event.shift_pressed and not event.ctrl_pressed:
			toggle_bone_size_panel()
			return

		if event.keycode == KEY_C and event.shift_pressed and not event.ctrl_pressed:
			toggle_collision_size_panel()
			return

		if event.keycode == KEY_O and event.shift_pressed and not event.ctrl_pressed:
			toggle_origin_panel()
			return

		if event.keycode == KEY_G and not keyboard_move_active and not keyboard_scale_active and selected_object != null:
			start_keyboard_move()
			return

		if event.keycode == KEY_S and not event.ctrl_pressed and not keyboard_move_active and not keyboard_scale_active and selected_object != null:
			start_keyboard_scale()
			return

		if event.keycode == KEY_C and object_toolbar != null and object_toolbar.current_tool == object_toolbar.Tool.COLLISION and not keyboard_collision_scale_active and selected_object != null:
			start_keyboard_collision_scale()
			return

		if event.keycode == KEY_V and object_toolbar != null and object_toolbar.current_tool == object_toolbar.Tool.COLLISION and not keyboard_collision_move_active and selected_object != null:
			start_keyboard_collision_move()
			return

		if keyboard_move_active:
			if event.keycode == KEY_X:
				keyboard_move_axis = "X"
				update_keyboard_axis_line()
				return
			if event.keycode == KEY_Y:
				keyboard_move_axis = "Y"
				update_keyboard_axis_line()
				return
			if event.keycode == KEY_Z:
				keyboard_move_axis = "Z"
				update_keyboard_axis_line()
				return
			if event.keycode == KEY_ESCAPE:
				cancel_keyboard_move()
				return
			if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				confirm_keyboard_move()
				return

		if keyboard_bone_move_active:
			if event.keycode == KEY_X:
				keyboard_bone_move_axis = "X"
				return
			if event.keycode == KEY_Y:
				keyboard_bone_move_axis = "Y"
				return
			if event.keycode == KEY_Z:
				keyboard_bone_move_axis = "Z"
				return
			if event.keycode == KEY_ESCAPE:
				cancel_keyboard_bone_move()
				return
			if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				confirm_keyboard_bone_move()
				return

		if keyboard_scale_active:
			if event.keycode == KEY_X:
				keyboard_scale_axis = "X"
				return
			if event.keycode == KEY_Y:
				keyboard_scale_axis = "Y"
				return
			if event.keycode == KEY_Z:
				keyboard_scale_axis = "Z"
				return
			if event.keycode == KEY_ESCAPE:
				cancel_keyboard_scale()
				return
			if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				confirm_keyboard_scale()
				return

		if keyboard_collision_scale_active:
			if event.keycode == KEY_X:
				keyboard_collision_scale_axis = "X"
				return
			if event.keycode == KEY_Y:
				keyboard_collision_scale_axis = "Y"
				return
			if event.keycode == KEY_Z:
				keyboard_collision_scale_axis = "Z"
				return
			if event.keycode == KEY_ESCAPE:
				cancel_keyboard_collision_scale()
				return
			if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				confirm_keyboard_collision_scale()
				return

		if keyboard_collision_move_active:
			if event.keycode == KEY_X:
				keyboard_collision_move_axis = "X"
				return
			if event.keycode == KEY_Y:
				keyboard_collision_move_axis = "Y"
				return
			if event.keycode == KEY_Z:
				keyboard_collision_move_axis = "Z"
				return
			if event.keycode == KEY_ESCAPE:
				cancel_keyboard_collision_move()
				return
			if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				confirm_keyboard_collision_move()
				return

	if event is InputEventMouseMotion and keyboard_bone_move_active and keyboard_bone_move_axis != "" and selected_skeleton != null:
		var local_axis := Vector3.ZERO
		match keyboard_bone_move_axis:
			"X": local_axis = Vector3(1, 0, 0)
			"Y": local_axis = Vector3(0, 1, 0)
			"Z": local_axis = Vector3(0, 0, 1)

		var bone_origin: Vector3 = selected_skeleton.global_transform * selected_skeleton.get_bone_global_pose(selected_bone_idx).origin
		var bone_basis: Basis = (selected_skeleton.global_transform * selected_skeleton.get_bone_global_pose(selected_bone_idx)).basis
		var world_axis: Vector3 = bone_basis * local_axis

		var mouse_delta: Vector2 = get_viewport().get_mouse_position() - keyboard_bone_move_start_mouse
		var origin_screen: Vector2 = camera.unproject_position(bone_origin)
		var axis_screen: Vector2 = camera.unproject_position(bone_origin + world_axis)
		var screen_dir: Vector2 = (axis_screen - origin_screen).normalized()

		var move_amount: float = mouse_delta.dot(screen_dir) * 0.01
		selected_skeleton.set_bone_pose_position(selected_bone_idx, keyboard_bone_move_start_pos + local_axis * move_amount)
		selected_skeleton.force_update_all_bone_transforms()
		return

	
	if event is InputEventMouseButton and keyboard_move_active:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			confirm_keyboard_move()
			return
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			cancel_keyboard_move()
			return
		
	if event is InputEventMouseButton and keyboard_bone_move_active:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			confirm_keyboard_bone_move()
			return
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			cancel_keyboard_bone_move()
			return
	

	if event is InputEventMouseButton and keyboard_collision_scale_active:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			confirm_keyboard_collision_scale()
			return
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			cancel_keyboard_collision_scale()
			return
			
	if event is InputEventMouseButton and keyboard_collision_move_active:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			confirm_keyboard_collision_move()
			return
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			cancel_keyboard_collision_move()
			return

	if event is InputEventMouseMotion and keyboard_move_active and keyboard_move_axis != "" and selected_object != null:
		var world_axis := Vector3.ZERO
		match keyboard_move_axis:
			"X": world_axis = Vector3(1, 0, 0)
			"Y": world_axis = Vector3(0, 1, 0)
			"Z": world_axis = Vector3(0, 0, 1)

		var mouse_delta: Vector2 = get_viewport().get_mouse_position() - keyboard_move_start_mouse
		var origin_screen: Vector2 = camera.unproject_position(keyboard_move_start_pos)
		var axis_screen: Vector2 = camera.unproject_position(keyboard_move_start_pos + world_axis)
		var screen_dir: Vector2 = (axis_screen - origin_screen).normalized()

		var move_amount: float = mouse_delta.dot(screen_dir) * 0.01
		selected_object.position = keyboard_move_start_pos + world_axis * move_amount
		return

	if event is InputEventMouseMotion and keyboard_scale_active and selected_object != null:
		var mouse_delta_ks: Vector2 = get_viewport().get_mouse_position() - keyboard_scale_start_mouse

		var reference_axis_ks := Vector3(1, 0, 0)
		match keyboard_scale_axis:
			"X": reference_axis_ks = Vector3(1, 0, 0)
			"Y": reference_axis_ks = Vector3(0, 1, 0)
			"Z": reference_axis_ks = Vector3(0, 0, 1)

		var origin_screen_ks: Vector2 = camera.unproject_position(keyboard_scale_start_pos)
		var reference_screen_ks: Vector2 = camera.unproject_position(keyboard_scale_start_pos + reference_axis_ks)
		var pixels_per_unit_ks: float = max(origin_screen_ks.distance_to(reference_screen_ks), 30.0)

		var drag_amount_ks: float = (mouse_delta_ks.x - mouse_delta_ks.y) / pixels_per_unit_ks

		var new_scale_ks := keyboard_scale_start_scale
		match keyboard_scale_axis:
			"X": new_scale_ks.x = max(0.05, keyboard_scale_start_scale.x + drag_amount_ks)
			"Y": new_scale_ks.y = max(0.05, keyboard_scale_start_scale.y + drag_amount_ks)
			"Z": new_scale_ks.z = max(0.05, keyboard_scale_start_scale.z + drag_amount_ks)
			"":
				var factor_ks: float = max(0.05, 1.0 + drag_amount_ks)
				new_scale_ks = keyboard_scale_start_scale * factor_ks

		selected_object.scale = new_scale_ks
		return
		
	if event is InputEventMouseMotion and keyboard_collision_scale_active and selected_object != null:
		var collision_shape: CollisionShape3D = find_collision_shape(selected_object)
		if collision_shape != null:
			var mouse_delta_kc: Vector2 = get_viewport().get_mouse_position() - keyboard_collision_scale_start_mouse
			var drag_amount_kc: float = (mouse_delta_kc.x - mouse_delta_kc.y) / 30.0

			var new_scale_kc := keyboard_collision_scale_start
			match keyboard_collision_scale_axis:
				"X": new_scale_kc.x = max(0.05, keyboard_collision_scale_start.x + drag_amount_kc)
				"Y": new_scale_kc.y = max(0.05, keyboard_collision_scale_start.y + drag_amount_kc)
				"Z": new_scale_kc.z = max(0.05, keyboard_collision_scale_start.z + drag_amount_kc)
				"":
					var factor_kc: float = max(0.05, 1.0 + drag_amount_kc)
					new_scale_kc = keyboard_collision_scale_start * factor_kc

			collision_shape.scale = new_scale_kc
		return

	if event is InputEventMouseMotion and keyboard_collision_move_active and keyboard_collision_move_axis != "" and selected_object != null:
		var collision_shape: CollisionShape3D = find_collision_shape(selected_object)
		if collision_shape != null:
			var world_axis := Vector3.ZERO
			match keyboard_collision_move_axis:
				"X": world_axis = Vector3(1, 0, 0)
				"Y": world_axis = Vector3(0, 1, 0)
				"Z": world_axis = Vector3(0, 0, 1)

			var mouse_delta_cm: Vector2 = get_viewport().get_mouse_position() - keyboard_collision_move_start_mouse
			var origin_screen_cm: Vector2 = camera.unproject_position(collision_shape.global_position)
			var axis_screen_cm: Vector2 = camera.unproject_position(collision_shape.global_position + world_axis)
			var screen_dir_cm: Vector2 = (axis_screen_cm - origin_screen_cm).normalized()

			var move_amount_cm: float = mouse_delta_cm.dot(screen_dir_cm) * 0.01
			collision_shape.position = keyboard_collision_move_start_pos + world_axis * move_amount_cm
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _mouse_over_animation_strip(event.position):
			return
		if selected_object != null:
			var light_node: Node = selected_object.get_node_or_null("LightSource")
			var camera_node: Node = selected_object.get_node_or_null("CameraSource")
			var music_node: Node = selected_object.get_node_or_null("AudioSource")
			var is_video: bool = selected_object.has_meta("is_video")

			if light_node != null and light_node is Light3D and light_panel != null:
				light_panel.open_for_light(light_node, event.position)
			elif camera_node != null and camera_node is Camera3D:
				view_camera_menu.position = Vector2i(event.position)
				view_camera_menu.popup()
				pending_camera_view = camera_node
			elif music_node != null and music_node is AudioStreamPlayer and music_panel != null:
				music_panel.open_for(music_node, event.position)
			elif is_video and video_panel != null:
				video_panel.open_for(selected_object, event.position)
			else:
				delete_menu.position = Vector2i(event.position)
				delete_menu.popup()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if dragging_origin_axis != "":
			dragging_origin_axis = ""
			last_gizmo_drag_end_time = Time.get_ticks_msec()
		var was_dragging_gizmo: bool = dragging_axis != "" or dragging_rotate_axis != "" or dragging_scale_axis != ""

		if dragging_axis != "" and selected_object != null and history_manager != null:
			history_manager.push_action({
				"type": "transform",
				"object": selected_object,
				"old_position": drag_start_object_pos,
				"old_rotation": selected_object.rotation_degrees,
				"old_scale": selected_object.scale,
				"new_position": selected_object.position,
				"new_rotation": selected_object.rotation_degrees,
				"new_scale": selected_object.scale,
			})

		if dragging_rotate_axis != "" and selected_object != null and history_manager != null:
			history_manager.push_action({
				"type": "transform",
				"object": selected_object,
				"old_position": selected_object.position,
				"old_rotation": rotate_start_rotation,
				"old_scale": selected_object.scale,
				"new_position": selected_object.position,
				"new_rotation": selected_object.rotation_degrees,
				"new_scale": selected_object.scale,
			})

		if dragging_scale_axis != "" and selected_object != null and history_manager != null:
			history_manager.push_action({
				"type": "transform",
				"object": selected_object,
				"old_position": selected_object.position,
				"old_rotation": selected_object.rotation_degrees,
				"old_scale": scale_start_value,
				"new_position": selected_object.position,
				"new_rotation": selected_object.rotation_degrees,
				"new_scale": selected_object.scale,
			})

		dragging_axis = ""
		dragging_rotate_axis = ""
		dragging_scale_axis = ""
		is_dragging_gizmo = false

		if dragging_bone_axis != "" and selected_skeleton != null and history_manager != null:
			history_manager.push_action({
				"type": "bone_transform",
				"skeleton": selected_skeleton,
				"bone_idx": selected_bone_idx,
				"old_position": selected_skeleton.get_bone_pose_position(selected_bone_idx),
				"old_rotation": bone_rotate_start_pose,
				"old_scale": selected_skeleton.get_bone_pose_scale(selected_bone_idx),
				"new_position": selected_skeleton.get_bone_pose_position(selected_bone_idx),
				"new_rotation": selected_skeleton.get_bone_pose_rotation(selected_bone_idx),
				"new_scale": selected_skeleton.get_bone_pose_scale(selected_bone_idx),
			})
			dragging_bone_axis = ""
			last_gizmo_drag_end_time = Time.get_ticks_msec()

		if dragging_bone_move_axis != "" and selected_skeleton != null and history_manager != null:
			history_manager.push_action({
				"type": "bone_transform",
				"skeleton": selected_skeleton,
				"bone_idx": selected_bone_idx,
				"old_position": bone_move_start_pos,
				"old_rotation": selected_skeleton.get_bone_pose_rotation(selected_bone_idx),
				"old_scale": selected_skeleton.get_bone_pose_scale(selected_bone_idx),
				"new_position": selected_skeleton.get_bone_pose_position(selected_bone_idx),
				"new_rotation": selected_skeleton.get_bone_pose_rotation(selected_bone_idx),
				"new_scale": selected_skeleton.get_bone_pose_scale(selected_bone_idx),
			})
			dragging_bone_move_axis = ""
			last_gizmo_drag_end_time = Time.get_ticks_msec()

		if dragging_bone_scale_axis != "" and selected_skeleton != null and history_manager != null:
			history_manager.push_action({
				"type": "bone_transform",
				"skeleton": selected_skeleton,
				"bone_idx": selected_bone_idx,
				"old_position": selected_skeleton.get_bone_pose_position(selected_bone_idx),
				"old_rotation": selected_skeleton.get_bone_pose_rotation(selected_bone_idx),
				"old_scale": bone_scale_start_value,
				"new_position": selected_skeleton.get_bone_pose_position(selected_bone_idx),
				"new_rotation": selected_skeleton.get_bone_pose_rotation(selected_bone_idx),
				"new_scale": selected_skeleton.get_bone_pose_scale(selected_bone_idx),
			})
			dragging_bone_scale_axis = ""
			last_gizmo_drag_end_time = Time.get_ticks_msec()

		if dragging_ik_target:
			if ik_active_skeleton != null and ik_drag_root_idx != -1 and ik_drag_mid_idx != -1 and history_manager != null:
				history_manager.push_action({
					"type": "bone_transform",
					"skeleton": ik_active_skeleton,
					"bone_idx": ik_drag_root_idx,
					"old_position": ik_active_skeleton.get_bone_pose_position(ik_drag_root_idx),
					"old_rotation": ik_drag_start_root_rotation,
					"old_scale": ik_active_skeleton.get_bone_pose_scale(ik_drag_root_idx),
					"new_position": ik_active_skeleton.get_bone_pose_position(ik_drag_root_idx),
					"new_rotation": ik_active_skeleton.get_bone_pose_rotation(ik_drag_root_idx),
					"new_scale": ik_active_skeleton.get_bone_pose_scale(ik_drag_root_idx),
				})
				history_manager.push_action({
					"type": "bone_transform",
					"skeleton": ik_active_skeleton,
					"bone_idx": ik_drag_mid_idx,
					"old_position": ik_active_skeleton.get_bone_pose_position(ik_drag_mid_idx),
					"old_rotation": ik_drag_start_mid_rotation,
					"old_scale": ik_active_skeleton.get_bone_pose_scale(ik_drag_mid_idx),
					"new_position": ik_active_skeleton.get_bone_pose_position(ik_drag_mid_idx),
					"new_rotation": ik_active_skeleton.get_bone_pose_rotation(ik_drag_mid_idx),
					"new_scale": ik_active_skeleton.get_bone_pose_scale(ik_drag_mid_idx),
				})
			dragging_ik_target = false
			last_gizmo_drag_end_time = Time.get_ticks_msec()

		if dragging_collision_scale_axis != "":
			dragging_collision_scale_axis = ""
			last_gizmo_drag_end_time = Time.get_ticks_msec()

		if was_dragging_gizmo:
			last_gizmo_drag_end_time = Time.get_ticks_msec()
			
	if event is InputEventMouseMotion and dragging_axis != "" and selected_object != null:
		var mouse_delta: Vector2 = get_viewport().get_mouse_position() - drag_start_mouse
		var world_axis := Vector3.ZERO
		match dragging_axis:
			"X": world_axis = Vector3(1, 0, 0)
			"Y": world_axis = Vector3(0, 1, 0)
			"Z": world_axis = Vector3(0, 0, 1)
		var origin_screen: Vector2 = camera.unproject_position(drag_start_object_pos)
		var axis_screen: Vector2 = camera.unproject_position(drag_start_object_pos + world_axis)
		var screen_dir: Vector2 = (axis_screen - origin_screen).normalized()
		var move_amount: float = mouse_delta.dot(screen_dir) * 0.01
		selected_object.global_position = drag_start_object_pos + world_axis * move_amount

	if event is InputEventMouseMotion and dragging_rotate_axis != "" and selected_object != null:
		var screen_center: Vector2 = camera.unproject_position(selected_object.global_position)
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		var current_angle: float = (mouse_pos - screen_center).angle()
		var angle_diff: float = rad_to_deg(current_angle - rotate_start_angle)

		var world_axis_r := Vector3.ZERO
		match dragging_rotate_axis:
			"X": world_axis_r = Vector3(1, 0, 0)
			"Y": world_axis_r = Vector3(0, 1, 0)
			"Z": world_axis_r = Vector3(0, 0, 1)

		var cam_to_obj: Vector3 = (selected_object.global_position - camera.global_position).normalized()
		var facing: float = world_axis_r.dot(cam_to_obj)
		var direction_sign: float = 1.0 if facing < 0.0 else -1.0
		var rotation_amount: float = angle_diff * direction_sign

		var rot_basis := Basis(world_axis_r, deg_to_rad(rotation_amount))
		var prev_euler: Vector3 = selected_object.rotation_degrees
		var gt: Transform3D = selected_object.global_transform
		gt.basis = rot_basis * rotate_start_basis
		selected_object.global_transform = gt
		# Mantener los ángulos continuos (sin reducirlos a -180..180)
		var new_euler: Vector3 = selected_object.rotation_degrees
		for i in 3:
			new_euler[i] = prev_euler[i] + fposmod(new_euler[i] - prev_euler[i] + 180.0, 360.0) - 180.0
		selected_object.rotation_degrees = new_euler

	if event is InputEventMouseMotion and dragging_scale_axis != "" and selected_object != null:
		var mouse_delta_s: Vector2 = get_viewport().get_mouse_position() - scale_drag_start_mouse

		var reference_axis := Vector3(1, 0, 0)
		match dragging_scale_axis:
			"X": reference_axis = Vector3(1, 0, 0)
			"Y": reference_axis = Vector3(0, 1, 0)
			"Z": reference_axis = Vector3(0, 0, 1)
			"ALL": reference_axis = Vector3(1, 0, 0)

		var origin_screen_s: Vector2 = camera.unproject_position(scale_start_object_pos)
		var reference_screen: Vector2 = camera.unproject_position(scale_start_object_pos + reference_axis)
		var pixels_per_unit: float = max(origin_screen_s.distance_to(reference_screen), 30.0)

		var drag_amount: float = (mouse_delta_s.x - mouse_delta_s.y) / pixels_per_unit

		var new_scale := scale_start_value
		match dragging_scale_axis:
			"X": new_scale.x = max(0.05, scale_start_value.x + drag_amount)
			"Y": new_scale.y = max(0.05, scale_start_value.y + drag_amount)
			"Z": new_scale.z = max(0.05, scale_start_value.z + drag_amount)
			"ALL":
				var factor: float = max(0.05, 1.0 + drag_amount)
				new_scale = scale_start_value * factor

		selected_object.scale = new_scale
		
	if event is InputEventMouseMotion and dragging_collision_scale_axis != "" and selected_object != null:
		print("DEBUG arrastrando, axis=", dragging_collision_scale_axis)
		var collision_shape: CollisionShape3D = find_collision_shape(selected_object)
		if collision_shape != null:
			var mouse_delta_cs: Vector2 = get_viewport().get_mouse_position() - collision_scale_drag_start_mouse

			var reference_axis_cs := Vector3(1, 0, 0)
			match dragging_collision_scale_axis:
				"X": reference_axis_cs = Vector3(1, 0, 0)
				"Y": reference_axis_cs = Vector3(0, 1, 0)
				"Z": reference_axis_cs = Vector3(0, 0, 1)
				"ALL": reference_axis_cs = Vector3(1, 0, 0)

			var origin_screen_cs: Vector2 = camera.unproject_position(collision_shape.global_position)
			var reference_screen_cs: Vector2 = camera.unproject_position(collision_shape.global_position + reference_axis_cs)
			var pixels_per_unit_cs: float = max(origin_screen_cs.distance_to(reference_screen_cs), 30.0)

			var drag_amount_cs: float = ((mouse_delta_cs.x - mouse_delta_cs.y) / pixels_per_unit_cs) * 3.0

			var new_scale_cs := collision_scale_start_value
			match dragging_collision_scale_axis:
				"X": new_scale_cs.x = max(0.05, collision_scale_start_value.x + drag_amount_cs)
				"Y": new_scale_cs.y = max(0.05, collision_scale_start_value.y + drag_amount_cs)
				"Z": new_scale_cs.z = max(0.05, collision_scale_start_value.z + drag_amount_cs)
				"ALL":
					var factor_cs: float = max(0.05, 1.0 + drag_amount_cs)
					new_scale_cs = collision_scale_start_value * factor_cs

			collision_shape.scale = new_scale_cs
	
	
	if event is InputEventMouseMotion and dragging_bone_axis != "" and selected_skeleton != null:
		var screen_center: Vector2 = camera.unproject_position(bone_rotate_gizmo.global_position)
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		var current_angle: float = (mouse_pos - screen_center).angle()
		var angle_diff: float = current_angle - bone_rotate_start_angle

		var cam_to_bone: Vector3 = (bone_rotate_gizmo.global_position - camera.global_position).normalized()
		var facing: float = bone_rotate_start_world_axis.dot(cam_to_bone)
		var direction_sign: float = 1.0 if facing < 0.0 else -1.0

		var local_axis := Vector3.ZERO
		match dragging_bone_axis:
			"X": local_axis = Vector3(1, 0, 0)
			"Y": local_axis = Vector3(0, 1, 0)
			"Z": local_axis = Vector3(0, 0, 1)

		var delta_quat := Quaternion(local_axis, angle_diff * direction_sign)
		selected_skeleton.set_bone_pose_rotation(selected_bone_idx, bone_rotate_start_pose * delta_quat)
		selected_skeleton.force_update_all_bone_transforms()

	if event is InputEventMouseMotion and dragging_bone_move_axis != "" and selected_skeleton != null:
		var mouse_delta: Vector2 = get_viewport().get_mouse_position() - bone_move_start_mouse
		var local_axis := Vector3.ZERO
		match dragging_bone_move_axis:
			"X": local_axis = Vector3(1, 0, 0)
			"Y": local_axis = Vector3(0, 1, 0)
			"Z": local_axis = Vector3(0, 0, 1)

		var bone_origin: Vector3 = selected_skeleton.global_transform * selected_skeleton.get_bone_global_pose(selected_bone_idx).origin
		var bone_basis: Basis = (selected_skeleton.global_transform * selected_skeleton.get_bone_global_pose(selected_bone_idx)).basis
		var world_axis: Vector3 = bone_basis * local_axis

		var origin_screen: Vector2 = camera.unproject_position(bone_origin)
		var axis_screen: Vector2 = camera.unproject_position(bone_origin + world_axis)
		var screen_dir: Vector2 = (axis_screen - origin_screen).normalized()

		var move_amount: float = mouse_delta.dot(screen_dir) * 0.01
		var new_pos: Vector3 = bone_move_start_pos + local_axis * move_amount
		selected_skeleton.set_bone_pose_position(selected_bone_idx, new_pos)
		selected_skeleton.force_update_all_bone_transforms()

	if event is InputEventMouseMotion and dragging_bone_scale_axis != "" and selected_skeleton != null:
		var mouse_delta_bs: Vector2 = get_viewport().get_mouse_position() - bone_scale_start_mouse

		var reference_axis := Vector3(1, 0, 0)
		match dragging_bone_scale_axis:
			"X": reference_axis = Vector3(1, 0, 0)
			"Y": reference_axis = Vector3(0, 1, 0)
			"Z": reference_axis = Vector3(0, 0, 1)

		var bone_origin_s: Vector3 = selected_skeleton.global_transform * selected_skeleton.get_bone_global_pose(selected_bone_idx).origin
		var bone_basis_s: Basis = (selected_skeleton.global_transform * selected_skeleton.get_bone_global_pose(selected_bone_idx)).basis
		var world_reference: Vector3 = bone_basis_s * reference_axis

		var origin_screen_bs: Vector2 = camera.unproject_position(bone_origin_s)
		var reference_screen_bs: Vector2 = camera.unproject_position(bone_origin_s + world_reference)
		var pixels_per_unit_bs: float = max(origin_screen_bs.distance_to(reference_screen_bs), 30.0)

		var drag_amount_bs: float = (mouse_delta_bs.x - mouse_delta_bs.y) / pixels_per_unit_bs

		var new_scale_bs := bone_scale_start_value
		match dragging_bone_scale_axis:
			"X": new_scale_bs.x = max(0.05, bone_scale_start_value.x + drag_amount_bs)
			"Y": new_scale_bs.y = max(0.05, bone_scale_start_value.y + drag_amount_bs)
			"Z": new_scale_bs.z = max(0.05, bone_scale_start_value.z + drag_amount_bs)

		selected_skeleton.set_bone_pose_scale(selected_bone_idx, new_scale_bs)
		selected_skeleton.force_update_all_bone_transforms()
		
	if event is InputEventMouseMotion and dragging_ik_target and camera != null:
		print("DEBUG moviendo IK target")
		var cam_forward: Vector3 = -camera.global_transform.basis.z
		var plane := Plane(cam_forward, ik_drag_start_target)
		var from: Vector3 = camera.project_ray_origin(get_viewport().get_mouse_position())
		var dir: Vector3 = camera.project_ray_normal(get_viewport().get_mouse_position())
		var hit = plane.intersects_ray(from, dir)
		if hit != null:
			ik_target_pos = hit
	
# ============================================================
# BORRAR
# ============================================================

func _on_delete_menu_id_pressed(id: int) -> void:
	if id == 0 and selected_object != null:
		delete_object_completely(selected_object)

func start_keyboard_move() -> void:
	if selected_object == null:
		return
	keyboard_move_active = true
	keyboard_move_axis = ""
	keyboard_move_start_pos = selected_object.position
	keyboard_move_start_mouse = get_viewport().get_mouse_position()
	is_dragging_gizmo = true  # reusamos la bandera para bloquear la cámara mientras tanto
	
	
	
	
	
func cancel_keyboard_move() -> void:
	if selected_object != null:
		selected_object.position = keyboard_move_start_pos
	keyboard_move_active = false
	keyboard_move_axis = ""
	is_dragging_gizmo = false
	if keyboard_axis_line != null:
		keyboard_axis_line.queue_free()
		keyboard_axis_line = null

func confirm_keyboard_move() -> void:
	keyboard_move_active = false
	keyboard_move_axis = ""
	is_dragging_gizmo = false
	if keyboard_axis_line != null:
		keyboard_axis_line.queue_free()
		keyboard_axis_line = null

func start_keyboard_scale() -> void:
	if selected_object == null:
		return
	keyboard_scale_active = true
	keyboard_scale_axis = ""
	keyboard_scale_start_scale = selected_object.scale
	keyboard_scale_start_pos = selected_object.global_position
	keyboard_scale_start_mouse = get_viewport().get_mouse_position()
	is_dragging_gizmo = true

func cancel_keyboard_scale() -> void:
	if selected_object != null:
		selected_object.scale = keyboard_scale_start_scale
	keyboard_scale_active = false
	keyboard_scale_axis = ""
	is_dragging_gizmo = false

func confirm_keyboard_scale() -> void:
	keyboard_scale_active = false
	keyboard_scale_axis = ""
	is_dragging_gizmo = false


func update_keyboard_axis_line() -> void:
	
	if keyboard_axis_line != null:
		keyboard_axis_line.queue_free()
		keyboard_axis_line = null

	if not keyboard_move_active or keyboard_move_axis == "" or selected_object == null:
		return

	var world_axis := Vector3.ZERO
	var color := Color.WHITE
	match keyboard_move_axis:
		"X":
			world_axis = Vector3(1, 0, 0)
			color = Color.RED
		"Y":
			world_axis = Vector3(0, 1, 0)
			color = Color.GREEN
		"Z":
			world_axis = Vector3(0, 0, 1)
			color = Color.BLUE

	var length := 100.0  # línea bien larga, para que se sienta "infinita"

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	st.set_color(color)
	st.add_vertex(keyboard_move_start_pos - world_axis * length)
	st.add_vertex(keyboard_move_start_pos + world_axis * length)

	keyboard_axis_line = MeshInstance3D.new()
	keyboard_axis_line.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	keyboard_axis_line.material_override = mat

	get_tree().current_scene.add_child(keyboard_axis_line)
	
func _on_light_delete_requested(light: Light3D) -> void:
	var body: Node3D = light.get_parent()
	delete_object_completely(body)
	
func _on_view_camera_menu_pressed(id: int) -> void:
	if pending_camera_view == null or camera_rig_ref == null:
		return

	if id == 0:
		# Teletransporte único (lo que ya teníamos)
		var target_transform: Transform3D = pending_camera_view.global_transform
		var pitch_pivot: Node3D = camera_rig_ref.get_node("CameraPitch")
		var real_camera: Camera3D = pitch_pivot.get_node("Camera3D")
		pitch_pivot.rotation = Vector3.ZERO
		camera_rig_ref.global_transform = target_transform
		var offset: Vector3 = real_camera.position
		camera_rig_ref.global_position = target_transform.origin - target_transform.basis * offset
		real_camera.fov = pending_camera_view.fov
		real_camera.environment = pending_camera_view.environment
		camera_rig_ref.mark_camera_view_active()
	elif id == 1:
		# Seguimiento en vivo
		camera_rig_ref.start_following_camera(pending_camera_view)
	elif id == 2:
		if camera_panel != null:
			camera_panel.open_for_camera(pending_camera_view, view_camera_menu.position)
			
func _on_material_apply_requested(data: Dictionary) -> void:
	if outliner != null and outliner.highlighted_part != null and is_instance_valid(outliner.highlighted_part):
		apply_material_to_mesh_part(outliner.highlighted_part, data)
		return
	pending_material_to_apply = data

func apply_material_to_mesh_part(part: MeshInstance3D, data: Dictionary) -> void:
	var mat := StandardMaterial3D.new()
	if data["texture"] != null:
		mat.albedo_texture = data["texture"]
	AlphaHelper.fix(mat)   # <-- nueva
	mat.albedo_color = data["color"]

	mat.albedo_color = data["color"]
	mat.roughness = data.get("roughness", 1.0)
	mat.metallic = data.get("metallic", 0.0)
	part.material_override = mat

func apply_material_to_object(body: StaticBody3D, data: Dictionary) -> void:
	var mesh_instance: MeshInstance3D = body.get_node_or_null("Mesh")
	if mesh_instance == null:
		return

	var mat := StandardMaterial3D.new()
	if data["texture"] != null:
		mat.albedo_texture = data["texture"]
	AlphaHelper.fix(mat)   # <-- nueva
	mat.albedo_color = data["color"]
	mat.albedo_color = data["color"]
	mat.roughness = data.get("roughness", 1.0)
	mat.metallic = data.get("metallic", 0.0)
	
	mesh_instance.material_override = mat
	_apply_surface_flags(body)
	
func make_gizmo_material(color: Color, use_vertex_color: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	if use_vertex_color:
		mat.vertex_color_use_as_albedo = true
	else:
		mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.render_priority = 100
	return mat

func get_combined_aabb(body: Node3D) -> AABB:
	var mesh_list: Array = []
	_gather_meshes(body, mesh_list)

	if mesh_list.is_empty():
		return AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1, 1, 1))

	var combined: AABB = _mesh_aabb_in_body_space(mesh_list[0], body)
	for i in range(1, mesh_list.size()):
		combined = combined.merge(_mesh_aabb_in_body_space(mesh_list[i], body))
	return combined

func _gather_meshes(node: Node, result: Array) -> void:
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_gather_meshes(child, result)

func _mesh_aabb_in_body_space(mesh_instance: MeshInstance3D, body: Node3D) -> AABB:
	var local_aabb: AABB = mesh_instance.get_aabb()
	var to_body: Transform3D = body.global_transform.affine_inverse() * mesh_instance.global_transform
	return to_body * local_aabb

func find_skeleton_in(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found: Skeleton3D = find_skeleton_in(child)
		if found != null:
			return found
	return null

func try_select_bone(skeleton: Skeleton3D, screen_pos: Vector2) -> bool:
	if current_skeleton_for_markers != skeleton:
		show_all_bone_markers(skeleton)

	var best_idx: int = -1
	var best_dist: float = 40.0

	for i in skeleton.get_bone_count():
		var bone_world_pos: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(i).origin
		var screen_bone_pos: Vector2 = camera.unproject_position(bone_world_pos)
		var dist: float = screen_bone_pos.distance_to(screen_pos)
		if dist < best_dist:
			best_dist = dist
			best_idx = i

	if best_idx == -1:
		return false

	if selected_bone_idx != -1 and all_bone_markers.has(selected_bone_idx):
		all_bone_markers[selected_bone_idx].material_override = make_gizmo_material(Color.WHITE)

	selected_skeleton = skeleton
	selected_bone_idx = best_idx

	if all_bone_markers.has(best_idx):
		all_bone_markers[best_idx].material_override = make_gizmo_material(Color.MAGENTA)
		
	

	if animation_manager != null:
		animation_manager.refresh_timeline_for_selection()

	return true

func show_all_bone_markers(skeleton: Skeleton3D) -> void:
	clear_all_bone_markers()
	current_skeleton_for_markers = skeleton

	for i in skeleton.get_bone_count():
		var marker := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.04
		sphere.height = 0.08
		marker.mesh = sphere
		marker.material_override = make_gizmo_material(Color.WHITE)
		marker.custom_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))

		get_tree().current_scene.add_child(marker)
		all_bone_markers[i] = marker

func clear_all_bone_markers() -> void:
	for bone_idx in all_bone_markers.keys():
		var marker: MeshInstance3D = all_bone_markers[bone_idx]
		if is_instance_valid(marker):
			marker.queue_free()
	all_bone_markers.clear()
	current_skeleton_for_markers = null

func clear_bone_selection() -> void:
	selected_skeleton = null
	selected_bone_idx = -1
	clear_all_bone_markers()
	if bone_rotate_gizmo != null:
		bone_rotate_gizmo.queue_free()
		bone_rotate_gizmo = null
	if bone_move_gizmo != null:
		bone_move_gizmo.queue_free()
		bone_move_gizmo = null
	if bone_scale_gizmo != null:
		bone_scale_gizmo.queue_free()
		bone_scale_gizmo = null
	if bone_axis_panel != null:
		bone_axis_panel.visible = false
	if animation_manager != null:
		animation_manager.refresh_timeline_for_selection()

func update_bone_gizmo() -> void:
	if bone_size_panel != null and bone_size_panel.visible:
		_sync_size_panel()

	
	if current_skeleton_for_markers != null:
		var model_body: Node = _get_skeleton_model_body(current_skeleton_for_markers)
		bone_size_multiplier = model_body.get_meta("bone_size_multiplier", 1.0) if model_body != null else 1.0

		var marker_scale: float = get_bone_gizmo_scale()
		var min_pos := Vector3(INF, INF, INF)
		var max_pos := Vector3(-INF, -INF, -INF)
		for bone_idx in all_bone_markers.keys():
			var marker: MeshInstance3D = all_bone_markers[bone_idx]
			if is_instance_valid(marker):
				var bone_world_pos: Vector3 = current_skeleton_for_markers.global_transform * current_skeleton_for_markers.get_bone_global_pose(bone_idx).origin
				marker.global_position = bone_world_pos
				marker.scale = Vector3.ONE * marker_scale * 0.8
				min_pos = min_pos.min(bone_world_pos)
				max_pos = max_pos.max(bone_world_pos)
		if min_pos.x != INF:
			skeleton_extent = (max_pos - min_pos).length()
	else:
		skeleton_extent = 0.0
		bone_size_multiplier = 1.0

	update_bone_rotate_gizmo()
	update_bone_move_gizmo()
	update_bone_scale_gizmo()
	update_bone_ik_gizmo()

func update_bone_rotate_gizmo() -> void:
	var should_show: bool = selected_skeleton != null and selected_bone_idx != -1 and object_toolbar != null and object_toolbar.current_tool == object_toolbar.Tool.ROTATE

	if bone_axis_panel != null:
		bone_axis_panel.visible = should_show

	if not should_show:
		if bone_rotate_gizmo != null:
			bone_rotate_gizmo.queue_free()
			bone_rotate_gizmo = null
		return

	if bone_rotate_gizmo == null:
		bone_rotate_gizmo = Node3D.new()
		get_tree().current_scene.add_child(bone_rotate_gizmo)
		add_bone_ring(bone_rotate_gizmo, "X", Color.RED)
		add_bone_ring(bone_rotate_gizmo, "Y", Color.GREEN)
		add_bone_ring(bone_rotate_gizmo, "Z", Color.BLUE)

	bone_rotate_gizmo.global_position = selected_skeleton.global_transform * selected_skeleton.get_bone_global_pose(selected_bone_idx).origin
	bone_rotate_gizmo.scale = Vector3.ONE * get_bone_gizmo_scale() * 0.7

func update_bone_move_gizmo() -> void:
	var should_show: bool = selected_skeleton != null and selected_bone_idx != -1 and object_toolbar != null and object_toolbar.current_tool == object_toolbar.Tool.MOVE

	if not should_show:
		if bone_move_gizmo != null:
			bone_move_gizmo.queue_free()
			bone_move_gizmo = null
		return

	if bone_move_gizmo == null:
		bone_move_gizmo = Node3D.new()
		get_tree().current_scene.add_child(bone_move_gizmo)
		add_bone_arrow(bone_move_gizmo, Vector3(1, 0, 0), Color.RED, "X")
		add_bone_arrow(bone_move_gizmo, Vector3(0, 1, 0), Color.GREEN, "Y")
		add_bone_arrow(bone_move_gizmo, Vector3(0, 0, 1), Color.BLUE, "Z")

	bone_move_gizmo.global_position = selected_skeleton.global_transform * selected_skeleton.get_bone_global_pose(selected_bone_idx).origin
	bone_move_gizmo.scale = Vector3.ONE * get_bone_gizmo_scale() * 0.7

func update_bone_scale_gizmo() -> void:
	var should_show: bool = selected_skeleton != null and selected_bone_idx != -1 and object_toolbar != null and object_toolbar.current_tool == object_toolbar.Tool.SCALE

	if not should_show:
		if bone_scale_gizmo != null:
			bone_scale_gizmo.queue_free()
			bone_scale_gizmo = null
		return

	if bone_scale_gizmo == null:
		bone_scale_gizmo = Node3D.new()
		get_tree().current_scene.add_child(bone_scale_gizmo)
		add_bone_scale_handle(bone_scale_gizmo, Vector3(1, 0, 0), Color.RED, "X")
		add_bone_scale_handle(bone_scale_gizmo, Vector3(0, 1, 0), Color.GREEN, "Y")
		add_bone_scale_handle(bone_scale_gizmo, Vector3(0, 0, 1), Color.BLUE, "Z")

	bone_scale_gizmo.global_position = selected_skeleton.global_transform * selected_skeleton.get_bone_global_pose(selected_bone_idx).origin
	bone_scale_gizmo.scale = Vector3.ONE * get_bone_gizmo_scale() * 0.7

func add_bone_ring(parent: Node3D, axis_name: String, color: Color) -> void:
	var radius := 1.0
	var thickness := 0.02
	var segments := 32

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	st.set_color(color)

	for i in segments + 1:
		var angle: float = (float(i) / segments) * TAU
		var inner := Vector3.ZERO
		var outer := Vector3.ZERO
		match axis_name:
			"X":
				inner = Vector3(0, cos(angle) * (radius - thickness), sin(angle) * (radius - thickness))
				outer = Vector3(0, cos(angle) * (radius + thickness), sin(angle) * (radius + thickness))
			"Y":
				inner = Vector3(cos(angle) * (radius - thickness), 0, sin(angle) * (radius - thickness))
				outer = Vector3(cos(angle) * (radius + thickness), 0, sin(angle) * (radius + thickness))
			"Z":
				inner = Vector3(cos(angle) * (radius - thickness), sin(angle) * (radius - thickness), 0)
				outer = Vector3(cos(angle) * (radius + thickness), sin(angle) * (radius + thickness), 0)
		st.add_vertex(inner)
		st.add_vertex(outer)

	var area := Area3D.new()
	area.name = "BoneRing_" + axis_name
	area.collision_layer = 2
	area.collision_mask = 0

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = st.commit()
	var mat := make_gizmo_material(color, true)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = mat
	area.add_child(mesh_instance)

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = thickness * 2.0
	col.shape = shape
	match axis_name:
		"X": col.rotation = Vector3(0, 0, deg_to_rad(90))
		"Z": col.rotation = Vector3(deg_to_rad(90), 0, 0)
	area.add_child(col)

	area.input_ray_pickable = true
	area.input_event.connect(_on_bone_ring_input.bind(axis_name))

	parent.add_child(area)

func _on_bone_ring_input(_camera: Node, event: InputEvent, pos: Vector3, _normal: Vector3, _shape_idx: int, axis_name: String) -> void:
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var dist_from_center: float = pos.distance_to(bone_rotate_gizmo.global_position)
		var ring_radius: float = bone_rotate_gizmo.scale.x

		if abs(dist_from_center - ring_radius) > ring_radius * 0.35:
			return

		dragging_bone_axis = axis_name
		bone_rotate_start_pose = selected_skeleton.get_bone_pose_rotation(selected_bone_idx)

		var local_axis := Vector3.ZERO
		match axis_name:
			"X": local_axis = Vector3(1, 0, 0)
			"Y": local_axis = Vector3(0, 1, 0)
			"Z": local_axis = Vector3(0, 0, 1)
		var bone_global_basis: Basis = (selected_skeleton.global_transform * selected_skeleton.get_bone_global_pose(selected_bone_idx)).basis
		bone_rotate_start_world_axis = bone_global_basis * local_axis

		var screen_center: Vector2 = camera.unproject_position(bone_rotate_gizmo.global_position)
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		bone_rotate_start_angle = (mouse_pos - screen_center).angle()
		is_dragging_gizmo = true
		
func get_gizmo_scale() -> float:
	if camera == null or selected_object == null:
		return 1.0
	var dist: float = camera.global_position.distance_to(selected_object.global_position)
	var avg_object_scale: float = (selected_object.scale.x + selected_object.scale.y + selected_object.scale.z) / 3.0
	return max(dist * GIZMO_SCREEN_SIZE, avg_object_scale * 0.6, 0.3)


func add_bone_arrow(parent: Node3D, dir: Vector3, color: Color, axis_name: String) -> void:
	var length := 1.0

	var line_instance := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.02
	shaft_mesh.bottom_radius = 0.02
	shaft_mesh.height = length
	line_instance.mesh = shaft_mesh
	line_instance.position = dir * (length / 2.0)
	match axis_name:
		"X": line_instance.rotation = Vector3(0, 0, deg_to_rad(-90))
		"Y": line_instance.rotation = Vector3.ZERO
		"Z": line_instance.rotation = Vector3(deg_to_rad(90), 0, 0)
	line_instance.custom_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	line_instance.material_override = make_gizmo_material(color)
	parent.add_child(line_instance)

	var body := Area3D.new()
	body.name = "BoneArrow_" + axis_name
	body.position = dir * length
	body.collision_layer = 2
	body.collision_mask = 0

	var cone := MeshInstance3D.new()
	var cone_mesh := SphereMesh.new()
	cone_mesh.radius = 0.08
	cone_mesh.height = 0.16
	cone.mesh = cone_mesh
	cone.material_override = make_gizmo_material(color)
	cone.custom_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	body.add_child(cone)

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.15
	col.shape = shape
	body.add_child(col)

	body.input_ray_pickable = true
	body.input_event.connect(_on_bone_arrow_input.bind(axis_name))

	parent.add_child(body)

func _on_bone_arrow_input(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int, axis_name: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		dragging_bone_move_axis = axis_name
		bone_move_start_mouse = get_viewport().get_mouse_position()
		bone_move_start_pos = selected_skeleton.get_bone_pose_position(selected_bone_idx)
		is_dragging_gizmo = true

func add_bone_scale_handle(parent: Node3D, dir: Vector3, color: Color, axis_name: String) -> void:
	var length := 1.0

	var line_instance := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.02
	shaft_mesh.bottom_radius = 0.02
	shaft_mesh.height = length
	line_instance.mesh = shaft_mesh
	line_instance.position = dir * (length / 2.0)
	match axis_name:
		"X": line_instance.rotation = Vector3(0, 0, deg_to_rad(-90))
		"Y": line_instance.rotation = Vector3.ZERO
		"Z": line_instance.rotation = Vector3(deg_to_rad(90), 0, 0)
	line_instance.custom_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	line_instance.material_override = make_gizmo_material(color)
	parent.add_child(line_instance)

	var area := Area3D.new()
	area.name = "BoneScaleHandle_" + axis_name
	area.position = dir * length
	area.collision_layer = 2
	area.collision_mask = 0

	var box := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3.ONE * 0.15
	box.mesh = box_mesh
	box.material_override = make_gizmo_material(color)
	box.custom_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	area.add_child(box)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * 0.2
	col.shape = shape
	area.add_child(col)

	area.input_ray_pickable = true
	area.input_event.connect(_on_bone_scale_handle_input.bind(axis_name))

	parent.add_child(area)

func _on_bone_scale_handle_input(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int, axis_name: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		dragging_bone_scale_axis = axis_name
		bone_scale_start_mouse = get_viewport().get_mouse_position()
		bone_scale_start_value = selected_skeleton.get_bone_pose_scale(selected_bone_idx)
		is_dragging_gizmo = true
		
		
		if dragging_ik_target:
			dragging_ik_target = false
			last_gizmo_drag_end_time = Time.get_ticks_msec()

		if dragging_collision_scale_axis != "":
			dragging_collision_scale_axis = ""
			last_gizmo_drag_end_time = Time.get_ticks_msec()

		
		
func delete_object_completely(obj: Node3D) -> void:
	if obj == null or not is_instance_valid(obj):
		return
	if obj == selected_object:
		deselect()
	
	if obj.get_parent() != null:
		obj.get_parent().remove_child(obj)
	obj.free()
	if outliner != null:
		outliner.refresh()

func delete_model_part(part: MeshInstance3D) -> void:
	if part == null or not is_instance_valid(part):
		return
	var parent: Node = part.get_parent()
	if parent == null:
		return

	if history_manager != null:
		history_manager.push_action({
			"type": "part_removal",
			"part": part,
			"parent": parent,
			"index": part.get_index(),
		})

	var del_root: Node = find_imported_model_ancestor(part)
	if del_root != null:
		var del_body: Node = del_root.get_parent()
		var del_list: Array = del_body.get_meta("deleted_parts", [])
		del_list.append({"node": part, "path": str(del_root.get_path_to(part))})
		del_body.set_meta("deleted_parts", del_list)

	parent.remove_child(part)
	if outliner != null:
		outliner.refresh()

func promote_model_part(part: MeshInstance3D) -> StaticBody3D:
	
	if part == null or not is_instance_valid(part):
		return null
	var old_parent: Node = part.get_parent()
	if old_parent == null:
		return null
		
	var old_index: int = part.get_index()
	var model_root_for_path: Node = find_imported_model_ancestor(part)
	var part_path: String = str(model_root_for_path.get_path_to(part)) if model_root_for_path != null else ""
	var old_transform: Transform3D = part.transform
	var old_skeleton_path: NodePath = part.skeleton

	var linked_skeleton: Node = null
	if part.skeleton != NodePath(""):
		linked_skeleton = part.get_node_or_null(part.skeleton)

	var body := StaticBody3D.new()
	body.name = part.name + "_Objeto"
	body.set_meta("model_part_path", part_path)
	
	old_parent.add_child(body)
	old_parent.move_child(body, old_index)

	part.reparent(body, true)
	body.transform = part.transform
	part.transform = Transform3D.IDENTITY

	if linked_skeleton != null and is_instance_valid(linked_skeleton):
		part.skeleton = part.get_path_to(linked_skeleton)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	col.shape = shape
	body.add_child(col)

	var combined: AABB = get_combined_aabb(body)
	shape.size = combined.size if combined.size != Vector3.ZERO else Vector3.ONE * 0.2
	col.position = combined.position + combined.size / 2.0

	body.input_ray_pickable = false
	body.set_meta("is_model_part_object", true)
	part.set_meta("is_promoted_owner_mesh", true)

	if outliner != null:
		outliner.refresh()

	

	get_tree().call_group("toast_system", "show_toast", "Pieza convertida en objeto independiente")
	
	return body
func revert_promoted_part(body: StaticBody3D) -> void:
	if body == null or not is_instance_valid(body) or not body.has_meta("is_model_part_object"):
		return
	var part: MeshInstance3D = null
	for child in body.get_children():
		if child is MeshInstance3D:
			part = child
			break
	if part == null:
		return
	var old_parent: Node = body.get_parent()
	if old_parent == null:
		return
	var old_index: int = body.get_index()

	if selected_object == body:
		deselect()

	var linked_skeleton: Node = null
	if part.skeleton != NodePath(""):
		linked_skeleton = part.get_node_or_null(part.skeleton)

	var world_transform: Transform3D = part.global_transform

	body.remove_child(part)
	old_parent.remove_child(body)
	old_parent.add_child(part)
	old_parent.move_child(part, min(old_index, old_parent.get_child_count() - 1))

	part.transform = old_parent.global_transform.affine_inverse() * world_transform

	if linked_skeleton != null and is_instance_valid(linked_skeleton):
		part.skeleton = part.get_path_to(linked_skeleton)
	part.remove_meta("is_promoted_owner_mesh")

	if outliner != null:
		outliner.refresh()

	body.free()

	get_tree().call_group("toast_system", "show_toast", "Pieza devuelta al modelo")
	
	
	
	
	
func attach_object_to_bone(obj: Node3D, skeleton: Skeleton3D, bone_idx: int) -> void:
	if obj == null or not is_instance_valid(obj) or skeleton == null or not is_instance_valid(skeleton):
		return
	if bone_idx < 0 or bone_idx >= skeleton.get_bone_count():
		return

	var bone_name: String = skeleton.get_bone_name(bone_idx)

	# Si ya existe un BoneAttachment3D para este hueso, lo reusamos,
	# para no llenar el esqueleto de nodos repetidos.
	var attachment: BoneAttachment3D = null
	for child in skeleton.get_children():
		if child is BoneAttachment3D and child.bone_name == bone_name:
			attachment = child
			break

	if attachment == null:
		attachment = BoneAttachment3D.new()
		attachment.name = "Hueso_%s" % bone_name
		skeleton.add_child(attachment)
		attachment.bone_name = bone_name

	obj.reparent(attachment, true)

	if outliner != null:
		outliner.refresh()

	get_tree().call_group("toast_system", "show_toast", "Adjuntado al hueso \"%s\"" % bone_name)
	
	
func update_bone_ik_gizmo() -> void:
	var is_playing_animation: bool = animation_manager != null and animation_manager.is_playing
	var should_show: bool = not is_playing_animation and selected_skeleton != null and selected_bone_idx != -1 and object_toolbar != null and object_toolbar.current_tool == object_toolbar.Tool.IK

	if not should_show:
		if ik_gizmo != null:
			ik_gizmo.queue_free()
			ik_gizmo = null
			if not is_playing_animation and animation_manager != null:
				animation_manager.refresh_timeline_for_selection()
		ik_active_skeleton = null
		ik_active_bone_idx = -1
		return

	if ik_gizmo == null or ik_active_skeleton != selected_skeleton or ik_active_bone_idx != selected_bone_idx:
		if ik_gizmo != null:
			ik_gizmo.queue_free()
		ik_active_skeleton = selected_skeleton
		ik_active_bone_idx = selected_bone_idx
		ik_target_pos = selected_skeleton.global_transform * selected_skeleton.get_bone_global_pose(selected_bone_idx).origin
		ik_gizmo = _create_ik_handle()
		if animation_manager != null:
			animation_manager.refresh_timeline_for_selection()

	if not dragging_ik_target:
		ik_target_pos = selected_skeleton.global_transform * selected_skeleton.get_bone_global_pose(selected_bone_idx).origin

	ik_gizmo.global_position = ik_target_pos
	ik_gizmo.scale = Vector3.ONE * get_bone_gizmo_scale() * 0.6

	if dragging_ik_target:
		solve_two_bone_ik(selected_skeleton, selected_bone_idx, ik_target_pos)

func _create_ik_handle() -> Area3D:
	var handle := Area3D.new()
	handle.name = "IKHandle"
	handle.collision_layer = 2
	handle.collision_mask = 0

	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	mesh_instance.mesh = sphere
	mesh_instance.material_override = make_gizmo_material(Color.CYAN)
	mesh_instance.custom_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	handle.add_child(mesh_instance)

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.2
	col.shape = shape
	handle.add_child(col)

	handle.input_ray_pickable = true
	handle.input_event.connect(_on_ik_handle_input)

	get_tree().current_scene.add_child(handle)
	return handle









func _on_ik_handle_input(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	print("DEBUG toqué la esfera de IK")
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		dragging_ik_target = true
		ik_drag_start_target = ik_target_pos

		ik_drag_root_idx = -1
		ik_drag_mid_idx = -1
		if selected_skeleton != null and selected_bone_idx != -1:
			ik_drag_mid_idx = selected_skeleton.get_bone_parent(selected_bone_idx)
			if ik_drag_mid_idx != -1:
				ik_drag_start_mid_rotation = selected_skeleton.get_bone_pose_rotation(ik_drag_mid_idx)
				ik_drag_root_idx = selected_skeleton.get_bone_parent(ik_drag_mid_idx)
			if ik_drag_root_idx != -1:
				ik_drag_start_root_rotation = selected_skeleton.get_bone_pose_rotation(ik_drag_root_idx)

		is_dragging_gizmo = true



func solve_two_bone_ik(skeleton: Skeleton3D, tip_idx: int, target_world_pos: Vector3) -> void:
	var mid_idx: int = skeleton.get_bone_parent(tip_idx)
	if mid_idx == -1:
		return
	var root_idx: int = skeleton.get_bone_parent(mid_idx)
	if root_idx == -1:
		return

	var target_local: Vector3 = skeleton.global_transform.affine_inverse() * target_world_pos

	var root_pos: Vector3 = skeleton.get_bone_global_pose(root_idx).origin
	var mid_pos: Vector3 = skeleton.get_bone_global_pose(mid_idx).origin
	var tip_pos: Vector3 = skeleton.get_bone_global_pose(tip_idx).origin

	var len1: float = root_pos.distance_to(mid_pos)
	var len2: float = mid_pos.distance_to(tip_pos)
	if len1 < 0.0001 or len2 < 0.0001:
		return

	var target_dist: float = root_pos.distance_to(target_local)
	target_dist = clamp(target_dist, abs(len1 - len2) + 0.001, len1 + len2 - 0.001)

	var cos_a: float = (len1 * len1 + target_dist * target_dist - len2 * len2) / (2.0 * len1 * target_dist)
	var angle_a: float = acos(clamp(cos_a, -1.0, 1.0))

	var root_to_target: Vector3 = (target_local - root_pos).normalized()
	var root_to_mid: Vector3 = (mid_pos - root_pos).normalized()
	var mid_to_tip: Vector3 = (tip_pos - mid_pos).normalized()

	var bend_axis: Vector3 = root_to_mid.cross(mid_to_tip)
	if bend_axis.length() < 0.001:
		bend_axis = root_to_mid.cross(Vector3.UP)
		if bend_axis.length() < 0.001:
			bend_axis = root_to_mid.cross(Vector3.RIGHT)
	bend_axis = bend_axis.normalized()

	var new_dir_pos: Vector3 = root_to_target.rotated(bend_axis, angle_a)
	var new_dir_neg: Vector3 = root_to_target.rotated(bend_axis, -angle_a)
	var new_root_to_mid: Vector3 = new_dir_pos if new_dir_pos.dot(root_to_mid) > new_dir_neg.dot(root_to_mid) else new_dir_neg

	var root_world_delta: Quaternion = Quaternion(root_to_mid, new_root_to_mid)
	if root_world_delta.get_angle() > 0.0005:
		var root_global_basis: Basis = skeleton.get_bone_global_pose(root_idx).basis
		var root_local_axis: Vector3 = (root_global_basis.inverse() * root_world_delta.get_axis()).normalized()
		skeleton.set_bone_pose_rotation(root_idx, skeleton.get_bone_pose_rotation(root_idx) * Quaternion(root_local_axis, root_world_delta.get_angle()))

	skeleton.force_update_all_bone_transforms()

	var new_mid_pos: Vector3 = skeleton.get_bone_global_pose(mid_idx).origin
	var new_mid_to_tip: Vector3 = (skeleton.get_bone_global_pose(tip_idx).origin - new_mid_pos).normalized()
	var new_mid_to_target: Vector3 = (target_local - new_mid_pos).normalized()

	var mid_world_delta: Quaternion = Quaternion(new_mid_to_tip, new_mid_to_target)
	if mid_world_delta.get_angle() > 0.0005:
		var mid_global_basis: Basis = skeleton.get_bone_global_pose(mid_idx).basis
		var mid_local_axis: Vector3 = (mid_global_basis.inverse() * mid_world_delta.get_axis()).normalized()
		skeleton.set_bone_pose_rotation(mid_idx, skeleton.get_bone_pose_rotation(mid_idx) * Quaternion(mid_local_axis, mid_world_delta.get_angle()))

	skeleton.force_update_all_bone_transforms()

func start_keyboard_bone_move() -> void:
	if selected_skeleton == null or selected_bone_idx == -1:
		return
	keyboard_bone_move_active = true
	keyboard_bone_move_axis = ""
	keyboard_bone_move_start_pos = selected_skeleton.get_bone_pose_position(selected_bone_idx)
	keyboard_bone_move_start_mouse = get_viewport().get_mouse_position()
	is_dragging_gizmo = true

func cancel_keyboard_bone_move() -> void:
	if selected_skeleton != null and selected_bone_idx != -1:
		selected_skeleton.set_bone_pose_position(selected_bone_idx, keyboard_bone_move_start_pos)
		selected_skeleton.force_update_all_bone_transforms()
	keyboard_bone_move_active = false
	keyboard_bone_move_axis = ""
	is_dragging_gizmo = false

func confirm_keyboard_bone_move() -> void:
	keyboard_bone_move_active = false
	keyboard_bone_move_axis = ""
	is_dragging_gizmo = false

func update_collision_scale_gizmo() -> void:
	var should_show: bool = selected_object != null and object_toolbar != null and object_toolbar.current_tool == object_toolbar.Tool.COLLISION

	if outline_instance != null and is_instance_valid(outline_instance):
		outline_instance.visible = not should_show

	if not should_show:
		if collision_scale_gizmo != null:
			collision_scale_gizmo.queue_free()
			collision_scale_gizmo = null
		if collision_debug_box != null:
			collision_debug_box.queue_free()
			collision_debug_box = null
		return

	var collision_shape: CollisionShape3D = find_collision_shape(selected_object)
	if collision_shape == null:
		if collision_scale_gizmo != null:
			collision_scale_gizmo.queue_free()
			collision_scale_gizmo = null
		if collision_debug_box != null:
			collision_debug_box.queue_free()
			collision_debug_box = null
		return

	if collision_scale_gizmo == null:
		collision_scale_gizmo = Node3D.new()
		get_tree().current_scene.add_child(collision_scale_gizmo)
		add_collision_scale_handle(collision_scale_gizmo, Vector3(1, 0, 0), Color.RED, "X")
		add_collision_scale_handle(collision_scale_gizmo, Vector3(0, 1, 0), Color.GREEN, "Y")
		add_collision_scale_handle(collision_scale_gizmo, Vector3(0, 0, 1), Color.BLUE, "Z")
		add_collision_scale_handle(collision_scale_gizmo, Vector3.ZERO, Color.CYAN, "ALL")

	collision_scale_gizmo.global_position = collision_shape.global_position
	collision_scale_gizmo.scale = Vector3.ONE * get_gizmo_scale()

	update_collision_debug_box(collision_shape)

func add_collision_scale_handle(parent: Node3D, dir: Vector3, color: Color, axis_name: String) -> void:
	var length := 1.0

	if axis_name != "ALL":
		var line_instance := MeshInstance3D.new()
		var shaft_mesh := CylinderMesh.new()
		shaft_mesh.top_radius = 0.02
		shaft_mesh.bottom_radius = 0.02
		shaft_mesh.height = length
		line_instance.mesh = shaft_mesh
		line_instance.position = dir * (length / 2.0)
		match axis_name:
			"X": line_instance.rotation = Vector3(0, 0, deg_to_rad(-90))
			"Y": line_instance.rotation = Vector3.ZERO
			"Z": line_instance.rotation = Vector3(deg_to_rad(90), 0, 0)
		line_instance.custom_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
		line_instance.material_override = make_gizmo_material(color)
		parent.add_child(line_instance)

	var area := Area3D.new()
	area.name = "CollisionScaleHandle_" + axis_name
	area.position = dir * length if axis_name != "ALL" else Vector3.ZERO
	area.collision_layer = 2
	area.collision_mask = 0

	var box := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3.ONE * (0.2 if axis_name == "ALL" else 0.15)
	box.mesh = box_mesh
	box.material_override = make_gizmo_material(color)
	box.custom_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	area.add_child(box)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * (0.25 if axis_name == "ALL" else 0.2)
	col.shape = shape
	area.add_child(col)

	area.input_ray_pickable = true
	area.input_event.connect(_on_collision_scale_handle_input.bind(axis_name))

	parent.add_child(area)

func _on_collision_scale_handle_input(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int, axis_name: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("DEBUG clic en manija de colisión, eje=", axis_name)
		var collision_shape: CollisionShape3D = find_collision_shape(selected_object)
		print("DEBUG collision_shape encontrado=", collision_shape)
		if collision_shape == null:
			return
		dragging_collision_scale_axis = axis_name
		collision_scale_drag_start_mouse = get_viewport().get_mouse_position()
		collision_scale_start_value = collision_shape.scale
		is_dragging_gizmo = true

func find_collision_shape(body: Node3D) -> CollisionShape3D:
	for child in body.get_children():
		if child is CollisionShape3D:
			return child
	return null

func start_keyboard_collision_scale() -> void:
	var collision_shape: CollisionShape3D = find_collision_shape(selected_object)
	if collision_shape == null:
		return
	keyboard_collision_scale_active = true
	keyboard_collision_scale_axis = ""
	keyboard_collision_scale_start = collision_shape.scale
	keyboard_collision_scale_start_mouse = get_viewport().get_mouse_position()
	is_dragging_gizmo = true

func cancel_keyboard_collision_scale() -> void:
	var collision_shape: CollisionShape3D = find_collision_shape(selected_object)
	if collision_shape != null:
		collision_shape.scale = keyboard_collision_scale_start
	keyboard_collision_scale_active = false
	keyboard_collision_scale_axis = ""
	is_dragging_gizmo = false

func confirm_keyboard_collision_scale() -> void:
	keyboard_collision_scale_active = false
	keyboard_collision_scale_axis = ""
	is_dragging_gizmo = false

func update_collision_debug_box(collision_shape: CollisionShape3D) -> void:
	if collision_debug_box != null:
		collision_debug_box.queue_free()
		collision_debug_box = null

	if not (collision_shape.shape is BoxShape3D):
		return

	var box_shape: BoxShape3D = collision_shape.shape
	var half_size: Vector3 = box_shape.size / 2.0

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	var corners := [
		Vector3(-half_size.x, -half_size.y, -half_size.z), Vector3(half_size.x, -half_size.y, -half_size.z),
		Vector3(half_size.x, half_size.y, -half_size.z), Vector3(-half_size.x, half_size.y, -half_size.z),
		Vector3(-half_size.x, -half_size.y, half_size.z), Vector3(half_size.x, -half_size.y, half_size.z),
		Vector3(half_size.x, half_size.y, half_size.z), Vector3(-half_size.x, half_size.y, half_size.z),
	]
	var edges := [
		[0,1],[1,2],[2,3],[3,0],
		[4,5],[5,6],[6,7],[7,4],
		[0,4],[1,5],[2,6],[3,7]
	]
	for e in edges:
		st.add_vertex(corners[e[0]])
		st.add_vertex(corners[e[1]])

	collision_debug_box = MeshInstance3D.new()
	collision_debug_box.mesh = st.commit()
	collision_debug_box.material_override = make_gizmo_material(Color.ORANGE)

	get_tree().current_scene.add_child(collision_debug_box)
	collision_debug_box.global_transform = collision_shape.global_transform

func start_keyboard_collision_move() -> void:
	var collision_shape: CollisionShape3D = find_collision_shape(selected_object)
	if collision_shape == null:
		return
	keyboard_collision_move_active = true
	keyboard_collision_move_axis = ""
	keyboard_collision_move_start_pos = collision_shape.position
	keyboard_collision_move_start_mouse = get_viewport().get_mouse_position()
	is_dragging_gizmo = true

func cancel_keyboard_collision_move() -> void:
	var collision_shape: CollisionShape3D = find_collision_shape(selected_object)
	if collision_shape != null:
		collision_shape.position = keyboard_collision_move_start_pos
	keyboard_collision_move_active = false
	keyboard_collision_move_axis = ""
	is_dragging_gizmo = false

func confirm_keyboard_collision_move() -> void:
	keyboard_collision_move_active = false
	keyboard_collision_move_axis = ""
	is_dragging_gizmo = false

func _force_confirm_pending_keyboard_ops() -> void:
	if keyboard_move_active:
		confirm_keyboard_move()
	if keyboard_scale_active:
		confirm_keyboard_scale()
	if keyboard_bone_move_active:
		confirm_keyboard_bone_move()
	if keyboard_collision_scale_active:
		confirm_keyboard_collision_scale()
	if keyboard_collision_move_active:
		confirm_keyboard_collision_move()

func find_imported_model_ancestor(node: Node) -> Node:
	var current: Node = node
	while current != null:
		if current is StaticBody3D and current.has_meta("is_imported_model"):
			return current.get_node_or_null("ImportedModel")
		current = current.get_parent()
	return null

func _refresh_materials_panel_for_selection() -> void:
	if materials_panel == null:
		return
	var model_root: Node = find_imported_model_ancestor(selected_object) if selected_object != null else null
	if model_root != null:
		materials_panel.show_model_swatches(model_root)
	else:
		materials_panel.clear_model_swatches()

func get_bone_gizmo_scale() -> float:
	var base: float = get_gizmo_scale()
	if skeleton_extent > 0.0:
		base = min(base, skeleton_extent * 0.4)
	return base * bone_size_multiplier
	
func _get_skeleton_model_body(skeleton: Skeleton3D) -> Node:
	var current: Node = skeleton
	while current != null:
		if current is StaticBody3D and current.has_meta("is_imported_model"):
			return current
		current = current.get_parent()
	return null

func toggle_bone_size_panel() -> void:
	if current_skeleton_for_markers == null and selected_object == null:
		get_tree().call_group("toast_system", "show_toast", "Selecciona primero un objeto o un modelo con huesos")
		return
	if bone_size_panel == null:
		_build_bone_size_panel()
	if bone_size_panel.visible:
		bone_size_panel.visible = false
		return
	_sync_size_panel()
	bone_size_panel.visible = true

func _build_bone_size_panel() -> void:
	bone_size_panel = Panel.new()
	bone_size_panel.size = Vector2(270, 150)
	bone_size_panel.position = Vector2(get_viewport().get_visible_rect().size.x - 290, 60)
	bone_size_panel.visible = false
	bone_size_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var title1 := Label.new()
	title1.text = "Tamaño de huesos (visual)"
	title1.position = Vector2(12, 8)
	bone_size_panel.add_child(title1)

	bone_size_spinbox = SpinBox.new()
	bone_size_spinbox.min_value = 0.001
	bone_size_spinbox.max_value = 100.0
	bone_size_spinbox.step = 0.001
	bone_size_spinbox.value = 1.0
	bone_size_spinbox.position = Vector2(12, 34)
	bone_size_spinbox.size = Vector2(140, 31)
	bone_size_spinbox.value_changed.connect(_on_bone_size_changed)
	bone_size_panel.add_child(bone_size_spinbox)

	var title2 := Label.new()
	title2.text = "Tamaño del gizmo del objeto"
	title2.position = Vector2(12, 76)
	bone_size_panel.add_child(title2)

	gizmo_size_spinbox = SpinBox.new()
	gizmo_size_spinbox.min_value = 0.001
	gizmo_size_spinbox.max_value = 100.0
	gizmo_size_spinbox.step = 0.001
	gizmo_size_spinbox.value = 1.0
	gizmo_size_spinbox.position = Vector2(12, 102)
	gizmo_size_spinbox.size = Vector2(140, 31)
	gizmo_size_spinbox.value_changed.connect(_on_gizmo_size_changed)
	bone_size_panel.add_child(gizmo_size_spinbox)

	var close_btn := Button.new()
	close_btn.text = "Cerrar"
	close_btn.position = Vector2(174, 102)
	close_btn.pressed.connect(func(): bone_size_panel.visible = false)
	bone_size_panel.add_child(close_btn)

	var layer: Node = get_tree().current_scene.get_node_or_null("CanvasLayer")
	if layer != null:
		layer.add_child(bone_size_panel)
	else:
		get_tree().current_scene.add_child(bone_size_panel)

func _on_bone_size_changed(value: float) -> void:
	if current_skeleton_for_markers == null:
		return
	var body: Node = _get_skeleton_model_body(current_skeleton_for_markers)
	if body != null:
		body.set_meta("bone_size_multiplier", value)

func get_object_gizmo_size() -> float:
	if selected_object == null:
		return 1.0
	var avg_scale: float = (selected_object.scale.x + selected_object.scale.y + selected_object.scale.z) / 3.0
	return max(avg_scale, 0.6) * selected_object.get_meta("gizmo_size_multiplier", 1.0)

func _on_gizmo_size_changed(value: float) -> void:
	if selected_object != null:
		selected_object.set_meta("gizmo_size_multiplier", value)

func _sync_size_panel() -> void:
	if bone_size_panel == null:
		return
	var has_skeleton: bool = current_skeleton_for_markers != null
	bone_size_spinbox.editable = has_skeleton
	gizmo_size_spinbox.editable = selected_object != null
	if not bone_size_spinbox.get_line_edit().has_focus():
		var body: Node = _get_skeleton_model_body(current_skeleton_for_markers) if has_skeleton else null
		bone_size_spinbox.set_value_no_signal(body.get_meta("bone_size_multiplier", 1.0) if body != null else 1.0)
	if not gizmo_size_spinbox.get_line_edit().has_focus():
		gizmo_size_spinbox.set_value_no_signal(selected_object.get_meta("gizmo_size_multiplier", 1.0) if selected_object != null else 1.0)

func toggle_collision_size_panel() -> void:
	if selected_object == null:
		get_tree().call_group("toast_system", "show_toast", "Selecciona primero un objeto")
		return
	var shape: CollisionShape3D = find_collision_shape(selected_object)
	if shape == null or not (shape.shape is BoxShape3D):
		get_tree().call_group("toast_system", "show_toast", "Este objeto no tiene una colisión de tipo caja editable así")
		return

	if collision_size_panel == null:
		_build_collision_size_panel()
	if collision_size_panel.visible:
		collision_size_panel.visible = false
		return

	var box: BoxShape3D = shape.shape
	var body_scale: Vector3 = selected_object.scale

	# Juntamos la escala de la colisión (no la del modelo) dentro del tamaño,
	# para que solo quede un factor de escala por compensar: el del modelo.
	box.size = Vector3(box.size.x * shape.scale.x, box.size.y * shape.scale.y, box.size.z * shape.scale.z)
	shape.scale = Vector3.ONE

	var world_size: Vector3 = box.size * body_scale

	for i in 3:
		collision_size_spinboxes[i].set_value_no_signal(world_size[i])
		collision_pos_spinboxes[i].set_value_no_signal(shape.position[i] * body_scale[i])


	if object_toolbar != null:
		object_toolbar.current_tool = object_toolbar.Tool.COLLISION

	collision_size_panel.visible = true

func _build_collision_size_panel() -> void:
	collision_size_panel = Panel.new()
	collision_size_panel.size = Vector2(260, 220)
	collision_size_panel.position = Vector2(get_viewport().get_visible_rect().size.x - 280, 220)
	collision_size_panel.visible = false
	collision_size_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var title := Label.new()
	title.text = "Tamaño y posición de la colisión"
	title.position = Vector2(12, 8)
	collision_size_panel.add_child(title)

	var labels_size := ["Ancho (X)", "Alto (Y)", "Profundo (Z)"]
	var labels_pos := ["Posición X", "Posición Y", "Posición Z"]
	collision_size_spinboxes.clear()
	collision_pos_spinboxes.clear()

	for i in 3:
		var lbl := Label.new()
		lbl.text = labels_size[i]
		lbl.position = Vector2(12, 40 + i * 34)
		collision_size_panel.add_child(lbl)

		var sb := SpinBox.new()
		sb.min_value = 0.001
		sb.max_value = 10000.0
		sb.step = 0.01
		sb.position = Vector2(140, 36 + i * 34)
		sb.size = Vector2(110, 30)
		var axis_index: int = i
		sb.value_changed.connect(func(v): _on_collision_size_changed(axis_index, v))
		collision_size_panel.add_child(sb)
		collision_size_spinboxes.append(sb)

	for i in 3:
		var lbl2 := Label.new()
		lbl2.text = labels_pos[i]
		lbl2.position = Vector2(12, 150 + i * 0)
		# Reacomodamos en una segunda columna si hace falta; para mantenerlo simple
		# las ponemos debajo, una tras otra
		lbl2.position = Vector2(12, 142 + i * 34)
		collision_size_panel.add_child(lbl2)

		var sb2 := SpinBox.new()
		sb2.min_value = -10000.0
		sb2.max_value = 10000.0
		sb2.step = 0.01
		sb2.position = Vector2(140, 138 + i * 34)
		sb2.size = Vector2(110, 30)
		var axis_index2: int = i
		sb2.value_changed.connect(func(v): _on_collision_pos_changed(axis_index2, v))
		collision_size_panel.add_child(sb2)
		collision_pos_spinboxes.append(sb2)

	var layer: Node = get_tree().current_scene.get_node_or_null("CanvasLayer")
	if layer != null:
		layer.add_child(collision_size_panel)
	else:
		get_tree().current_scene.add_child(collision_size_panel)

func _on_collision_size_changed(axis: int, value: float) -> void:
	if selected_object == null:
		return
	var shape: CollisionShape3D = find_collision_shape(selected_object)
	if shape == null or not (shape.shape is BoxShape3D):
		return
	var box: BoxShape3D = shape.shape
	var body_scale: Vector3 = selected_object.scale
	var local_value: float = value / body_scale[axis] if body_scale[axis] != 0 else value
	var s: Vector3 = box.size
	s[axis] = local_value
	box.size = s
	update_collision_debug_box(shape)

func _on_collision_pos_changed(axis: int, value: float) -> void:
	if selected_object == null:
		return
	var shape: CollisionShape3D = find_collision_shape(selected_object)
	if shape == null:
		return
	var body_scale: Vector3 = selected_object.scale
	var local_value: float = value / body_scale[axis] if body_scale[axis] != 0 else value
	var p: Vector3 = shape.position
	p[axis] = local_value
	shape.position = p
	update_collision_debug_box(shape)

func duplicate_object(obj: StaticBody3D, with_animation: bool) -> StaticBody3D:
	if obj == null or not is_instance_valid(obj):
		return null

	var new_obj: StaticBody3D = obj.duplicate()
	var parent: Node = obj.get_parent()
	if parent == null:
		parent = outliner.spawn_root if outliner != null else get_tree().current_scene
	parent.add_child(new_obj)
	new_obj.global_transform = obj.global_transform
	new_obj.name = obj.name + "_copia"

	# Si el original estaba seleccionado al duplicar, el marco amarillo se
	# copia como si fuera parte del modelo — lo sacamos, no es algo real.
	var leftover_outline: Node = new_obj.get_node_or_null("SelectionOutline")
	if leftover_outline != null:
		leftover_outline.queue_free()

	# duplicate() no copia los metadatos (keyframes, info del modelo, etc.) —
	# hay que traerlos a mano, uno por uno.
	for meta_key in obj.get_meta_list():
		if meta_key in ["keyframes", "bone_keyframes", "ik_keyframes", "animations", "animation_names", "current_animation"]:
			continue
		var value = obj.get_meta(meta_key)
		if value is Array or value is Dictionary:
			new_obj.set_meta(meta_key, value.duplicate(true))
		else:
			new_obj.set_meta(meta_key, value)

	if with_animation:
		new_obj.set_meta("keyframes", obj.get_meta("keyframes", []).duplicate(true))
		new_obj.set_meta("bone_keyframes", obj.get_meta("bone_keyframes", {}).duplicate(true))
		new_obj.set_meta("animations", obj.get_meta("animations", {}).duplicate(true))
		new_obj.set_meta("animation_names", obj.get_meta("animation_names", []).duplicate())
		new_obj.set_meta("current_animation", obj.get_meta("current_animation", ""))
	else:
		new_obj.set_meta("keyframes", [])
		new_obj.set_meta("bone_keyframes", {})
		new_obj.set_meta("animations", {})
		new_obj.set_meta("animation_names", [])
		new_obj.set_meta("current_animation", "")

	# Si tiene esqueleto, le copiamos la pose actual (si no, nace en pose de reposo)
	var orig_skeleton: Skeleton3D = find_skeleton_in(obj)
	var new_skeleton: Skeleton3D = find_skeleton_in(new_obj)
	if orig_skeleton != null and new_skeleton != null:
		for bi in orig_skeleton.get_bone_count():
			new_skeleton.set_bone_pose_position(bi, orig_skeleton.get_bone_pose_position(bi))
			new_skeleton.set_bone_pose_rotation(bi, orig_skeleton.get_bone_pose_rotation(bi))
			new_skeleton.set_bone_pose_scale(bi, orig_skeleton.get_bone_pose_scale(bi))
		new_skeleton.force_update_all_bone_transforms()

	# Separamos los materiales, para que cambiarle la textura a uno no afecte al otro
	_make_materials_unique(new_obj)

	if outliner != null:
		outliner.refresh()

	get_tree().call_group("toast_system", "show_toast", "Objeto duplicado")
	return new_obj

func _make_materials_unique(node: Node) -> void:
	if node is MeshInstance3D:
		if node.material_override != null:
			node.material_override = node.material_override.duplicate()
		if node.mesh != null:
			for i in node.mesh.get_surface_count():
				var mat: Material = node.get_surface_override_material(i)
				if mat != null:
					node.set_surface_override_material(i, mat.duplicate())
	for child in node.get_children():
		_make_materials_unique(child)


# ============================================================
# EDITAR ORIGEN (pivote) DEL OBJETO
# ============================================================

func toggle_origin_panel() -> void:
	if selected_object == null:
		get_tree().call_group("toast_system", "show_toast", "Selecciona primero un objeto")
		return
	if origin_panel == null:
		_build_origin_panel()
	origin_panel.visible = not origin_panel.visible
	if origin_panel.visible:
		if object_toolbar != null:
			object_toolbar.current_tool = object_toolbar.Tool.SELECT
			object_toolbar.queue_redraw()
		_sync_origin_panel()
	else:
		_hide_origin_marker()

func _build_origin_panel() -> void:
	origin_panel = Panel.new()
	origin_panel.size = Vector2(270, 235)
	origin_panel.position = Vector2(get_viewport().get_visible_rect().size.x - 290, 400)
	origin_panel.visible = false
	origin_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var title := Label.new()
	title.text = "Origen (relativo al centro del modelo)"
	title.position = Vector2(12, 8)
	origin_panel.add_child(title)

	var names := ["Origen X", "Origen Y", "Origen Z"]
	origin_spinboxes.clear()
	for i in 3:
		var lbl := Label.new()
		lbl.text = names[i]
		lbl.position = Vector2(12, 42 + i * 34)
		origin_panel.add_child(lbl)

		var sb := SpinBox.new()
		sb.min_value = -10000.0
		sb.max_value = 10000.0
		sb.step = 0.01
		sb.position = Vector2(140, 38 + i * 34)
		sb.size = Vector2(110, 30)
		var axis_index: int = i
		sb.value_changed.connect(func(v): _on_origin_axis_changed(axis_index, v))
		sb.get_line_edit().text_changed.connect(func(t: String):
			if t.is_valid_float():
				_on_origin_axis_changed(axis_index, t.to_float())
		)
		origin_panel.add_child(sb)
		origin_spinboxes.append(sb)

	var center_btn := Button.new()
	center_btn.text = "Al centro"
	center_btn.position = Vector2(12, 150)
	center_btn.size = Vector2(115, 30)
	center_btn.pressed.connect(func(): _set_origin_preset("center"))
	origin_panel.add_child(center_btn)

	var base_btn := Button.new()
	base_btn.text = "A la base"
	base_btn.position = Vector2(135, 150)
	base_btn.size = Vector2(115, 30)
	base_btn.pressed.connect(func(): _set_origin_preset("base"))
	origin_panel.add_child(base_btn)

	var close_btn := Button.new()
	close_btn.text = "Cerrar"
	close_btn.position = Vector2(12, 190)
	close_btn.size = Vector2(238, 30)
	close_btn.pressed.connect(func():
		origin_panel.visible = false
		_hide_origin_marker()
	)
	origin_panel.add_child(close_btn)

	var layer: Node = get_tree().current_scene.get_node_or_null("CanvasLayer")
	if layer != null:
		layer.add_child(origin_panel)
	else:
		get_tree().current_scene.add_child(origin_panel)

# AABB solo del objeto (sin el marco amarillo ni los objetos hijos)
func _own_geometry_aabb(body: Node3D) -> AABB:
	var list: Array = []
	_gather_own_meshes(body, body, list)
	if list.is_empty():
		return AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
	var combined: AABB = _mesh_aabb_in_body_space(list[0], body)
	for i in range(1, list.size()):
		combined = combined.merge(_mesh_aabb_in_body_space(list[i], body))
	return combined

func _gather_own_meshes(node: Node, body: Node, result: Array) -> void:
	for child in node.get_children():
		if child.name == "SelectionOutline":
			continue
		if node == body and child is StaticBody3D:
			continue
		if child is MeshInstance3D:
			result.append(child)
		_gather_own_meshes(child, body, result)

func _sync_origin_panel() -> void:
	if origin_panel == null or selected_object == null:
		return
	var c: Vector3 = _own_geometry_aabb(selected_object).get_center()
	for i in 3:
		if not origin_spinboxes[i].get_line_edit().has_focus():
			origin_spinboxes[i].set_value_no_signal(-c[i])

func _update_origin_panel() -> void:
	if origin_panel == null or not origin_panel.visible:
		return
		
	if selected_object == null:
		origin_panel.visible = false
		_hide_origin_marker()
		return
	_sync_origin_panel()
	
	if object_toolbar != null and object_toolbar.current_tool != object_toolbar.Tool.SELECT:
		origin_panel.visible = false
		_hide_origin_marker()
		return
	
	if origin_marker == null:
		origin_marker = MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.08
		sphere.height = 0.16
		origin_marker.mesh = sphere
		origin_marker.material_override = make_gizmo_material(Color.CYAN)
		origin_marker.custom_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
		get_tree().current_scene.add_child(origin_marker)
	origin_marker.global_position = selected_object.global_position
	origin_marker.scale = Vector3.ONE * get_object_gizmo_size() * 0.6

	if origin_gizmo == null:
		origin_gizmo = Node3D.new()
		get_tree().current_scene.add_child(origin_gizmo)
		_add_origin_arrow(origin_gizmo, Vector3(1, 0, 0), Color.RED, "X")
		_add_origin_arrow(origin_gizmo, Vector3(0, 1, 0), Color.GREEN, "Y")
		_add_origin_arrow(origin_gizmo, Vector3(0, 0, 1), Color.BLUE, "Z")
	origin_gizmo.global_position = selected_object.global_position
	origin_gizmo.scale = Vector3.ONE * get_object_gizmo_size() * 1.2


func _hide_origin_marker() -> void:
	if origin_marker != null:
		origin_marker.queue_free()
		origin_marker = null
	if origin_gizmo != null:
		origin_gizmo.queue_free()
		origin_gizmo = null
	dragging_origin_axis = ""

func _on_origin_axis_changed(axis: int, value: float) -> void:
	if selected_object == null:
		return
	var c: Vector3 = _own_geometry_aabb(selected_object).get_center()
	var d := Vector3.ZERO
	d[axis] = value + c[axis]
	set_object_origin(selected_object, d)

func _set_origin_preset(preset: String) -> void:
	if selected_object == null:
		return
	var box: AABB = _own_geometry_aabb(selected_object)
	var c: Vector3 = box.get_center()
	var target: Vector3 = c
	if preset == "base":
		target = Vector3(c.x, box.position.y, c.z)
	set_object_origin(selected_object, target)
	_sync_origin_panel()

# d_local = dónde queda el nuevo origen, en coordenadas locales actuales del objeto
func set_object_origin(obj: StaticBody3D, d: Vector3) -> void:
	if obj == null or d.length() < 0.00001:
		return

	# 1) Corregimos los keyframes de TODAS las animaciones del objeto
	_shift_keys_in(obj, d, true)

	# 2) Movemos el objeto al nuevo origen y compensamos a los hijos
	obj.position += obj.basis * d
	for child in obj.get_children():
		if child is Node3D and child.name != "SelectionOutline":
			child.position -= d
			if child is StaticBody3D:
				_shift_keys_in(child, d, false)

	if history_manager != null:
		history_manager.clear()

	# 3) El marco amarillo se corre junto con el resto, sin deseleccionar
	if outline_instance != null and is_instance_valid(outline_instance):
		outline_instance.position -= d
	if animation_manager != null:
		animation_manager.apply_frame_to_all_objects()

func _shift_keys_in(obj: Node, d: Vector3, as_pivot_owner: bool) -> void:
	var lists: Array = [obj.get_meta("keyframes", [])]
	var store: Dictionary = obj.get_meta("animations", {})
	for anim in store.keys():
		lists.append(store[anim].get("keyframes", []))
	for keys in lists:
		for key in keys:
			if as_pivot_owner:
				var b: Basis = Basis.from_euler(key["rotation"] * (PI / 180.0)) * Basis.from_scale(key["scale"])
				key["position"] += b * d
			else:
				key["position"] -= d

func _add_origin_arrow(parent: Node3D, dir: Vector3, color: Color, axis_name: String) -> void:
	var length := 1.0
	var big := AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))

	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.025
	shaft_mesh.bottom_radius = 0.025
	shaft_mesh.height = length
	shaft.mesh = shaft_mesh
	shaft.position = dir * (length / 2.0)
	match axis_name:
		"X": shaft.rotation = Vector3(0, 0, deg_to_rad(-90))
		"Z": shaft.rotation = Vector3(deg_to_rad(90), 0, 0)
	shaft.custom_aabb = big
	shaft.material_override = make_gizmo_material(color)
	parent.add_child(shaft)

	var area := Area3D.new()
	area.name = "OriginArrow_" + axis_name
	area.position = dir * length
	area.collision_layer = 2
	area.collision_mask = 0

	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3.ONE * 0.16
	head.mesh = head_mesh
	head.material_override = make_gizmo_material(color)
	head.custom_aabb = big
	area.add_child(head)

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.18
	col.shape = shape
	area.add_child(col)

	area.input_ray_pickable = true
	area.input_event.connect(_on_origin_arrow_input.bind(axis_name))
	parent.add_child(area)

func _on_origin_arrow_input(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int, axis_name: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and selected_object != null:
		dragging_origin_axis = axis_name
		origin_drag_start_mouse = get_viewport().get_mouse_position()
		origin_drag_start_pos = selected_object.global_position
		origin_drag_applied = 0.0
		is_dragging_gizmo = true

func set_object_collision_enabled(obj: StaticBody3D, enabled: bool, silent: bool = false) -> void:
	if obj == null or not is_instance_valid(obj):
		return
	for child in obj.get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", not enabled)
	obj.set_meta("collision_disabled", not enabled)
	if outliner != null:
		outliner.refresh()
	if not silent:
		get_tree().call_group("toast_system", "show_toast", "Colisión activada" if enabled else "Colisión desactivada: ahora el clic la atraviesa")

func set_object_surface_flag(obj: StaticBody3D, flag: String, value: bool) -> void:
	if obj == null or not is_instance_valid(obj):
		return
	obj.set_meta(flag, value)
	_apply_surface_flags(obj)
	var msg: String = ""
	if flag == "double_sided":
		msg = "Vista por dentro activada" if value else "Vista por dentro desactivada"
	else:
		msg = "Sin iluminación activado" if value else "Sin iluminación desactivado"
	get_tree().call_group("toast_system", "show_toast", msg)

func _apply_surface_flags(obj: Node) -> void:
	var mesh_instance: MeshInstance3D = obj.get_node_or_null("Mesh")
	if mesh_instance == null:
		return
	var double_sided: bool = obj.get_meta("double_sided", false)
	var unshaded: bool = obj.get_meta("unshaded", false)

	var mat: StandardMaterial3D = mesh_instance.material_override as StandardMaterial3D
	if mat == null:
		if not (double_sided or unshaded):
			return
		mat = StandardMaterial3D.new()
		mesh_instance.material_override = mat

	mat.cull_mode = BaseMaterial3D.CULL_DISABLED if double_sided else BaseMaterial3D.CULL_BACK
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if (double_sided or unshaded) else GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func _mouse_over_animation_strip(pos: Vector2) -> bool:
	if animation_manager == null or animation_manager.timeline_ruler == null:
		return false
	var panel: Control = animation_manager.timeline_ruler.get_parent()
	if panel == null or not panel.is_visible_in_tree():
		return false
	# Toda la franja de la barra de lado a lado (incluye la fila del diamante y el play)
	return pos.y >= panel.get_global_rect().position.y - 50.0
