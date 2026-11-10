extends Node3D



@onready var welcome_tip: Panel = $CanvasLayer/WelcomeTip
@onready var welcome_close_button: Button = $CanvasLayer/WelcomeTip/VBoxContainer/WelcomeCloseButton
@onready var spawn_root: Node3D = $SpawnRoot
@onready var add_menu: PopupMenu = $CanvasLayer/AddMenu
@onready var lights_menu: PopupMenu = $CanvasLayer/AddMenu/LightsMenu
@onready var outliner: Panel = $CanvasLayer/Outliner
@onready var cameras_menu: PopupMenu = $CanvasLayer/AddMenu/CamerasMenu
@onready var camera_rig_ref: Node3D = $CameraRig
@onready var render_manager: Node = $RenderManager

@onready var animation_manager: Node = $AnimationManager
@onready var music_menu: PopupMenu = $CanvasLayer/AddMenu/MusicMenu
@onready var video_menu: PopupMenu = $CanvasLayer/AddMenu/VideoMenu
@export var selection_manager_path: NodePath
@export var history_manager_path: NodePath
@onready var selection_manager: Node = get_node(selection_manager_path)
@onready var history_manager: Node = get_node(history_manager_path)
var spawn_offset := 0
@export var options_panel_path: NodePath
var options_panel: Node
enum Shape { CUBO, ESFERA, TRIANGULO, PLANO }

enum Light { SOL, FOCO, PUNTO }

func _ready() -> void:
	add_menu.hide()
	video_menu.add_item("Video/GIF", 0)
	video_menu.id_pressed.connect(_on_video_menu_id_pressed)
	add_menu.add_submenu_node_item("Video", video_menu)
	music_menu.add_item("Importar Música", 0)
	music_menu.id_pressed.connect(_on_music_menu_id_pressed)
	add_menu.add_submenu_node_item("Música", music_menu)
	print("spawn_root en _ready: ", spawn_root)
	add_menu.add_item("Cubo", Shape.CUBO)
	add_menu.add_item("Esfera", Shape.ESFERA)
	add_menu.add_item("Triángulo (prisma)", Shape.TRIANGULO)
	add_menu.add_item("Plano", Shape.PLANO)
	add_menu.add_item("Importar Modelo (.glb/.gltf)", 100)

	# Armamos el submenú de luces
	lights_menu.add_item("Sol", Light.SOL)
	lights_menu.add_item("Foco", Light.FOCO)
	lights_menu.add_item("Punto", Light.PUNTO)
	lights_menu.id_pressed.connect(_on_light_menu_id_pressed)

	# Lo agregamos como submenú dentro del menú principal
	add_menu.add_submenu_node_item("Luces", lights_menu)

	add_menu.id_pressed.connect(_on_menu_id_pressed)
	#Categoria de camaras
	cameras_menu.add_item("Cámara", 0)
	cameras_menu.id_pressed.connect(_on_camera_menu_id_pressed)
	add_menu.add_submenu_node_item("Cámara", cameras_menu)
	
	if options_panel_path != NodePath(""):
		options_panel = get_node(options_panel_path)
		
	if ProjectSession.current_project_name != "":
		load_project(ProjectSession.current_project_name)
	welcome_close_button.pressed.connect(_on_welcome_close_pressed)
	if not FileAccess.file_exists("user://welcome_seen.flag"):
		welcome_tip.visible = true
	
		
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_A and event.shift_pressed:
			var mouse_pos := get_viewport().get_mouse_position()
			add_menu.position = Vector2i(mouse_pos)
			add_menu.popup()
	
	
			
		if event is InputEventKey and event.pressed and event.keycode == KEY_F10:
			render_manager.is_rendering = false
			print("Forzado: is_rendering = false")
			
		
		
		if event.keycode == KEY_S and event.ctrl_pressed:
			save_project(ProjectSession.current_project_name)
			get_tree().call_group("toast_system", "show_toast", "Proyecto guardado")
			return

		if event.keycode == KEY_Q and event.ctrl_pressed:
			save_project(ProjectSession.current_project_name)
			get_tree().change_scene_to_file("res://escenas/main_menu.tscn")
			return
		
		
func _on_menu_id_pressed(id: int) -> void:
	match id:
		Shape.CUBO:
			spawn_shape("cubo")
		Shape.ESFERA:
			spawn_shape("esfera")
		Shape.TRIANGULO:
			spawn_shape("triangulo")
		Shape.PLANO:
			spawn_shape("plano")
		100:
			var path: String = pick_model_file_native()
			if path != "":
				import_model(path)

func spawn_shape(tipo: String) -> StaticBody3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"

	match tipo:
		"cubo":
			mesh_instance.mesh = BoxMesh.new()
		"esfera":
			mesh_instance.mesh = SphereMesh.new()
		"triangulo":
			var prism := PrismMesh.new()
			prism.left_to_right = 0.0
			mesh_instance.mesh = prism
		"plano":
			mesh_instance.mesh = PlaneMesh.new()

	# Envolvemos la malla en un cuerpo físico para poder detectarla con un clic
	var body := StaticBody3D.new()
	body.name = "Figure_%s_%d" % [tipo, spawn_offset]
	body.add_child(mesh_instance)

	var collision_shape := CollisionShape3D.new()
	# create_convex_shape() genera automáticamente una forma de colisión
	# que se ajusta a cualquier tipo de malla, sin tener que armarla a mano
	collision_shape.shape = mesh_instance.mesh.create_convex_shape()
	body.add_child(collision_shape)

	body.position = Vector3(spawn_offset * 0, 0.5, 0)
	spawn_offset += 1
	body.input_ray_pickable = false
	spawn_root.add_child(body)
	
	outliner.refresh()
	return body
	

	
func _on_light_menu_id_pressed(id: int) -> void:
	match id:
		Light.SOL:
			spawn_light("sol")
		Light.FOCO:
			spawn_light("foco")
		Light.PUNTO:
			spawn_light("punto")

func spawn_light(tipo: String) -> StaticBody3D:
	var light: Light3D
	var icon_color: Color

	match tipo:
		"sol":
			light = DirectionalLight3D.new()
			icon_color = Color(1.0, 0.9, 0.3)
		"foco":
			var spot := SpotLight3D.new()
			spot.spot_range = 10.0
			spot.spot_angle = 35.0
			light = spot
			icon_color = Color(0.3, 0.8, 1.0)
		"punto":
			var omni := OmniLight3D.new()
			omni.omni_range = 8.0
			light = omni
			icon_color = Color(1.0, 0.6, 0.2)

	light.name = "LightSource"
	light.light_energy = 1.2
	light.shadow_enabled = false

	var body := StaticBody3D.new()
	body.name = "Light_%s_%d" % [tipo, spawn_offset]

	# Ícono: una esferita de color que representa la luz en el espacio
	var icon := MeshInstance3D.new()
	icon.name = "Mesh"
	var icon_mesh := SphereMesh.new()
	icon_mesh.radius = 0.15
	icon_mesh.height = 0.3
	icon.mesh = icon_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = icon_color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	icon.material_override = mat
	body.add_child(icon)

	# Línea que muestra hacia dónde apunta (eje -Z, la dirección por defecto de las luces en Godot)
	if tipo != "punto":
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_LINES)
		st.set_color(icon_color)
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(0, 0, -1.0))
		var line_instance := MeshInstance3D.new()
		line_instance.mesh = st.commit()
		var line_mat := StandardMaterial3D.new()
		line_mat.vertex_color_use_as_albedo = true
		line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		line_mat.no_depth_test = true
		line_instance.material_override = line_mat
		body.add_child(line_instance)

	# Colisión para poder seleccionarla con clic, igual que las figuras
	var collision_shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.2
	collision_shape.shape = sphere_shape
	body.add_child(collision_shape)

	body.add_child(light)
	body.position = Vector3(spawn_offset * 0, 0, 0)
	spawn_offset += 1
	body.input_ray_pickable = false
	spawn_root.add_child(body)
	
	outliner.refresh()
	return body
	
func _on_camera_menu_id_pressed(_id: int) -> void:
	spawn_camera()

func spawn_camera() -> StaticBody3D:
	var cam := Camera3D.new()
	cam.name = "CameraSource"

	var body := StaticBody3D.new()
	body.name = "Camera_%d" % spawn_offset

	# Cuerpo simple (una cajita) que representa el "cuerpo" de la cámara
	var box := MeshInstance3D.new()
	box.name = "Mesh"
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.3, 0.25, 0.4)
	box.mesh = box_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.2, 0.2)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box.material_override = mat
	body.add_child(box)

	# Cono de visión (frustum) dibujado con líneas, tipo Blender
	var frustum := build_camera_frustum()
	var frustum_mat := StandardMaterial3D.new()
	frustum_mat.vertex_color_use_as_albedo = true
	frustum_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	frustum_mat.no_depth_test = true
	frustum.material_override = frustum_mat
	body.add_child(frustum)

	# Colisión para poder seleccionarla con clic
	var collision_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.3, 0.25, 0.4)
	collision_shape.shape = shape
	body.add_child(collision_shape)

	body.add_child(cam)
	body.position = Vector3(spawn_offset * 0, 0.5, 0)
	spawn_offset += 1
	body.input_ray_pickable = false
	spawn_root.add_child(body)
	outliner.refresh()
	return body
	
	camera_rig_ref.scene_camera = cam
	print("camera_rig_ref es: ", camera_rig_ref, " id: ", camera_rig_ref.get_instance_id())
	
func build_camera_frustum() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	st.set_color(Color(1.0, 0.85, 0.1))  # amarillo, como el gizmo de Blender

	var depth := 1.0
	var half_w := 0.5
	var half_h := 0.35

	var apex := Vector3.ZERO
	var corners := [
		Vector3(-half_w, half_h, -depth),
		Vector3(half_w, half_h, -depth),
		Vector3(half_w, -half_h, -depth),
		Vector3(-half_w, -half_h, -depth),
	]

	# Líneas desde el vértice (la cámara) hacia cada esquina del marco
	for c in corners:
		st.add_vertex(apex)
		st.add_vertex(c)

	# El marco rectangular que representa el encuadre
	for i in corners.size():
		st.add_vertex(corners[i])
		st.add_vertex(corners[(i + 1) % corners.size()])

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "FrustumGizmo"
	mesh_instance.mesh = st.commit()
	return mesh_instance

func find_first_camera() -> Camera3D:
	for obj in get_all_scene_objects():
		var cam_node: Node = obj.get_node_or_null("CameraSource")
		if cam_node != null and cam_node is Camera3D:
			return cam_node
	return null

func _on_music_menu_id_pressed(_id: int) -> void:
	spawn_music()

func pick_audio_file_native() -> String:
	var output: Array = []
	var script := 'Add-Type -AssemblyName System.Windows.Forms; $dialog = New-Object System.Windows.Forms.OpenFileDialog; $dialog.Filter = \'Audio (*.wav;*.ogg)|*.wav;*.ogg\'; if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Write-Output $dialog.FileName }'
	OS.execute("powershell", ["-NoProfile", "-Command", script], output, true)
	if output.size() > 0:
		return output[0].strip_edges()
	return ""

func spawn_music() -> StaticBody3D:
	var player := AudioStreamPlayer.new()
	player.name = "AudioSource"

	var body := StaticBody3D.new()
	body.name = "Music_%d" % spawn_offset

	var icon := MeshInstance3D.new()
	icon.name = "Mesh"
	var icon_mesh := BoxMesh.new()
	icon_mesh.size = Vector3(0.3, 0.3, 0.15)
	icon.mesh = icon_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.7, 0.1)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	icon.material_override = mat
	body.add_child(icon)

	var collision_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.3, 0.3, 0.15)
	collision_shape.shape = shape
	body.add_child(collision_shape)

	body.add_child(player)

	var grid_size := 5
	var col: int = spawn_offset % grid_size
	var row: int = int(spawn_offset / float(grid_size)) % grid_size
	body.position = Vector3(col * 2.0, 1.0, row * 2.0)
	spawn_offset += 1

	spawn_root.add_child(body)
	outliner.refresh()
	return body
	
func test_ffmpeg() -> void:
	var ffmpeg_path: String = get_ffmpeg_path()
	var output: Array = []
	var exit_code: int = OS.execute(ffmpeg_path, ["-version"], output, true)
	print("Código de salida: ", exit_code)
	print("Resultado: ", output)
	
func convert_video_to_frames(video_path: String, output_dir: String) -> bool:
	var ffmpeg_path: String = get_ffmpeg_path()
	DirAccess.make_dir_recursive_absolute(output_dir)

	var output: Array = []
	var args := [
		"-i", video_path,
		"-vf", "fps=%d" % int(animation_manager.FPS),
		output_dir + "/frame_%04d.png"
	]
	var exit_code: int = OS.execute(ffmpeg_path, args, output, true)

	print("FFmpeg salida: ", exit_code)
	return exit_code == 0

func _on_video_menu_id_pressed(_id: int) -> void:
	spawn_video_plane()

func spawn_video_plane() -> StaticBody3D:
	
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(2, 2)
	plane_mesh.orientation = PlaneMesh.FACE_Z
	mesh_instance.mesh = plane_mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.15, 0.15)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = mat

	var body := StaticBody3D.new()
	body.name = "Video_%d" % spawn_offset
	body.input_ray_pickable = false
	body.add_child(mesh_instance)

	var collision_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2, 2, 0.05)
	collision_shape.shape = shape
	body.add_child(collision_shape)

	var grid_size := 5
	var col: int = spawn_offset % grid_size
	var row: int = int(spawn_offset / float(grid_size)) % grid_size
	body.position = Vector3(col * 2.5, 1.0, row * 2.5)
	spawn_offset += 1
	
	body.set_meta("video_cache_dir", "")
	body.set_meta("is_video", true)
	body.set_meta("video_frames", [])
	body.set_meta("video_fps", 24.0)
	body.set_meta("video_start_offset", 0)
	
	spawn_root.add_child(body)
	outliner.refresh()
	return body
func get_all_scene_objects() -> Array:
	var result: Array = []
	_collect_scene_objects(spawn_root, result)
	return result

func _collect_scene_objects(node: Node, result: Array) -> void:
	for child in node.get_children():
		if child is StaticBody3D:
			result.append(child)
		_collect_scene_objects(child, result)

func serialize_keyframes(obj: Node3D) -> Array:
	var result: Array = []
	for key in obj.get_meta("keyframes", []):
		result.append({
			"frame": key["frame"],
			"position": [key["position"].x, key["position"].y, key["position"].z],
			"rotation": [key["rotation"].x, key["rotation"].y, key["rotation"].z],
			"scale": [key["scale"].x, key["scale"].y, key["scale"].z],
		})
	return result

func deserialize_keyframes(obj: Node3D, data: Array) -> void:
	var keyframes: Array = []
	for key in data:
		keyframes.append({
			"frame": int(key["frame"]),
			"position": Vector3(key["position"][0], key["position"][1], key["position"][2]),
			"rotation": Vector3(key["rotation"][0], key["rotation"][1], key["rotation"][2]),
			"scale": Vector3(key["scale"][0], key["scale"][1], key["scale"][2]),
		})
	obj.set_meta("keyframes", keyframes)

func serialize_project() -> Dictionary:
	var data := {
		"format_version": 1,
		"animation_end_frame": animation_manager.timeline_ruler.end_frame,
		"master_brightness": options_panel.master_brightness_spinbox.value if options_panel != null else 1.0,
		"project_fps": animation_manager.FPS,
		"interpolation_mode": animation_manager.interpolation_mode,


		"folders": {},
		"objects": []
	}

	if outliner != null:
		for folder_name in outliner.folders.keys():
			var names: Array = []
			for obj in outliner.folders[folder_name]:
				if is_instance_valid(obj):
					names.append(obj.name)
			data["folders"][folder_name] = names

	var all_objects: Array = get_all_scene_objects()
	var index_by_object: Dictionary = {}
	for i in all_objects.size():
		index_by_object[all_objects[i]] = i

	for obj in all_objects:
		var record := {
			"name": obj.name,
			"parent_index": index_by_object.get(obj.get_parent(), -1),
			"position": [obj.position.x, obj.position.y, obj.position.z],
			"rotation_degrees": [obj.rotation_degrees.x, obj.rotation_degrees.y, obj.rotation_degrees.z],
			"scale": [obj.scale.x, obj.scale.y, obj.scale.z],
			"visible": obj.visible,
			"keyframes": serialize_keyframes(obj),
			
			"bone_keyframes": serialize_bone_keyframes(obj),
			"ik_keyframes": serialize_ik_keyframes(obj),
			"animation_names": obj.get_meta("animation_names", []),
			"current_animation": obj.get_meta("current_animation", ""),
			"animations": _serialize_animation_store(obj),
			
		}
		if obj.get_parent() is BoneAttachment3D:
			var bone_attachment: Node = obj.get_parent()
			var ancestor: Node = bone_attachment.get_parent()
			while ancestor != null and not (ancestor is StaticBody3D and ancestor.has_meta("is_imported_model")):
				ancestor = ancestor.get_parent()
			if ancestor != null:
				record["attached_to_model_index"] = index_by_object.get(ancestor, -1)
				record["attached_to_bone_name"] = bone_attachment.bone_name
		record["gizmo_size_multiplier"] = obj.get_meta("gizmo_size_multiplier", 1.0)
		record["collision_disabled"] = obj.get_meta("collision_disabled", false)
		record["double_sided"] = obj.get_meta("double_sided", false)
		record["unshaded"] = obj.get_meta("unshaded", false)
		
		var mesh_instance: MeshInstance3D = obj.get_node_or_null("Mesh")
		var light_node: Node = obj.get_node_or_null("LightSource")
		var camera_node: Node = obj.get_node_or_null("CameraSource")
		var audio_node: Node = obj.get_node_or_null("AudioSource")
		var is_video: bool = obj.has_meta("is_video")

		if obj.has_meta("is_imported_model"):
			record["category"] = "model"
			record["model_format"] = obj.get_meta("model_format", "glb")
			record["model_base64"] = Marshalls.raw_to_base64(obj.get_meta("model_bytes", PackedByteArray()))
			
			record["bone_size_multiplier"] = obj.get_meta("bone_size_multiplier", 1.0)
			var deleted_paths: Array = []
			for entry in obj.get_meta("deleted_parts", []):
				if is_instance_valid(entry["node"]) and entry["node"].get_parent() == null:
					deleted_paths.append(entry["path"])
			record["deleted_parts"] = deleted_paths
			
			var import_root_ser: Node = obj.get_node_or_null("ImportedModel")
			if import_root_ser != null:
				var overrides: Array = []
				_collect_texture_overrides(import_root_ser, import_root_ser, overrides)
				if not overrides.is_empty():
					record["texture_overrides"] = overrides
			var col_shape: CollisionShape3D = selection_manager.find_collision_shape(obj)
			if col_shape != null and col_shape.shape is BoxShape3D:
				var cbox: BoxShape3D = col_shape.shape
				record["collision_size"] = [
						cbox.size.x * col_shape.scale.x,
						cbox.size.y * col_shape.scale.y,
						cbox.size.z * col_shape.scale.z
					]
				record["collision_position"] = [col_shape.position.x, col_shape.position.y, col_shape.position.z]
			var skeleton_ser: Skeleton3D = selection_manager.find_skeleton_in(import_root_ser) if import_root_ser != null else null
			if skeleton_ser != null:
				var poses: Array = []
				for bi in skeleton_ser.get_bone_count():
					var p: Vector3 = skeleton_ser.get_bone_pose_position(bi)
					var r: Quaternion = skeleton_ser.get_bone_pose_rotation(bi)
					var s: Vector3 = skeleton_ser.get_bone_pose_scale(bi)
					poses.append({
						"position": [p.x, p.y, p.z],
						"rotation": [r.x, r.y, r.z, r.w],
						"scale": [s.x, s.y, s.z],
					})
				record["bone_poses"] = poses
		
		elif is_video:
			record["category"] = "video"
			record["video_fps"] = obj.get_meta("video_fps", 24.0)
			record["video_start_offset"] = obj.get_meta("video_start_offset", 0)
			record["video_loop"] = obj.get_meta("video_loop", true)
			record["has_audio"] = obj.get_meta("has_audio", false)
			record["video_brightness"] = obj.get_meta("video_brightness", 1.0)
			
			var frames_b64: Array = []
			var cache_dir: String = obj.get_meta("video_cache_dir", "")
			if cache_dir != "" and DirAccess.dir_exists_absolute(cache_dir):
				var dir := DirAccess.open(cache_dir)
				var filenames: Array = []
				dir.list_dir_begin()
				var fname := dir.get_next()
				while fname != "":
					if fname.ends_with(".png"):
						filenames.append(fname)
					fname = dir.get_next()
				dir.list_dir_end()
				filenames.sort()
				for fname2 in filenames:
					var f := FileAccess.open(cache_dir + "/" + fname2, FileAccess.READ)
					frames_b64.append(Marshalls.raw_to_base64(f.get_buffer(f.get_length())))
					f.close()

				if record["has_audio"] and FileAccess.file_exists(cache_dir + "/audio.ogg"):
					var af := FileAccess.open(cache_dir + "/audio.ogg", FileAccess.READ)
					record["audio_base64"] = Marshalls.raw_to_base64(af.get_buffer(af.get_length()))
					af.close()

			record["frames_base64"] = frames_b64

			var video_audio: Node = obj.get_node_or_null("VideoAudio")
			if video_audio != null:
				record["volume_db"] = video_audio.volume_db

		elif light_node != null:
			record["category"] = "light"
			if light_node is DirectionalLight3D:
				record["light_type"] = "sol"
			elif light_node is SpotLight3D:
				record["light_type"] = "foco"
				record["spot_range"] = light_node.spot_range
				record["spot_angle"] = light_node.spot_angle
			elif light_node is OmniLight3D:
				record["light_type"] = "punto"
				record["omni_range"] = light_node.omni_range
			record["light_energy"] = light_node.light_energy
			record["shadow_enabled"] = light_node.shadow_enabled
			record["light_color"] = [light_node.light_color.r, light_node.light_color.g, light_node.light_color.b]

		elif camera_node != null:
			record["category"] = "camera"
			record["fov"] = camera_node.fov
			record["has_custom_bg"] = camera_node.environment != null
			if camera_node.environment != null:
				var bg: Color = camera_node.environment.background_color
				record["bg_color"] = [bg.r, bg.g, bg.b]

		elif audio_node != null:
			record["category"] = "music"
			record["volume_db"] = audio_node.volume_db
			record["audio_format"] = obj.get_meta("audio_format", "")
			record["audio_base64"] = Marshalls.raw_to_base64(obj.get_meta("audio_bytes", PackedByteArray()))

		elif obj.has_meta("is_model_part_object"):
			record["category"] = "model_part"
			record["part_path"] = obj.get_meta("model_part_path", "")
			var part_owner: Node = obj.get_parent()
			while part_owner != null and not (part_owner is StaticBody3D and part_owner.has_meta("is_imported_model")):
				part_owner = part_owner.get_parent()
			record["model_index"] = index_by_object.get(part_owner, -1)



		else:
			record["category"] = "figure"
			if mesh_instance != null:
				if mesh_instance.mesh is BoxMesh:
					record["shape_type"] = "cubo"
				elif mesh_instance.mesh is SphereMesh:
					record["shape_type"] = "esfera"
				elif mesh_instance.mesh is PrismMesh:
					record["shape_type"] = "triangulo"
				elif mesh_instance.mesh is PlaneMesh:
					record["shape_type"] = "plano"

		if mesh_instance != null and record["category"] == "figure" and mesh_instance.material_override is StandardMaterial3D:
			var mat: StandardMaterial3D = mesh_instance.material_override
			var tex_b64 = null
			if mat.albedo_texture != null:
				var img: Image = mat.albedo_texture.get_image()
				tex_b64 = Marshalls.raw_to_base64(img.save_png_to_buffer())
			record["material"] = {
				"color": [mat.albedo_color.r, mat.albedo_color.g, mat.albedo_color.b, mat.albedo_color.a],
				"roughness": mat.roughness,
				"metallic": mat.metallic,
				"texture_base64": tex_b64,
			}

		data["objects"].append(record)

	if selection_manager.materials_panel != null:
		data["materials_palette"] = selection_manager.materials_panel.serialize_palette()

	

	return data
	
func serialize_bone_keyframes(obj: Node3D) -> Dictionary:
	var result: Dictionary = {}
	var bone_keyframes: Dictionary = obj.get_meta("bone_keyframes", {})
	for bone_idx in bone_keyframes.keys():
		var track_out: Array = []
		for key in bone_keyframes[bone_idx]:
			var q: Quaternion = key["rotation"]
			var pos: Vector3 = key.get("position", Vector3.ZERO)
			var scl: Vector3 = key.get("scale", Vector3.ONE)
			track_out.append({
				"frame": key["frame"],
				"position": [pos.x, pos.y, pos.z],
				"rotation": [q.x, q.y, q.z, q.w],
				"scale": [scl.x, scl.y, scl.z],
			})
		result[str(bone_idx)] = track_out
	return result

func deserialize_bone_keyframes(obj: Node3D, data: Dictionary) -> void:
	if data.is_empty():
		return
	var bone_keyframes: Dictionary = {}
	for bone_key in data.keys():
		var track: Array = []
		for key in data[bone_key]:
			var r: Array = key["rotation"]
			var p: Array = key.get("position", [0.0, 0.0, 0.0])
			var s: Array = key.get("scale", [1.0, 1.0, 1.0])
			track.append({
				"frame": int(key["frame"]),
				"position": Vector3(p[0], p[1], p[2]),
				"rotation": Quaternion(r[0], r[1], r[2], r[3]),
				"scale": Vector3(s[0], s[1], s[2]),
			})
		bone_keyframes[int(bone_key)] = track
	obj.set_meta("bone_keyframes", bone_keyframes)

func serialize_ik_keyframes(obj: Node3D) -> Dictionary:
	var result: Dictionary = {}
	var ik_keyframes: Dictionary = obj.get_meta("ik_keyframes", {})
	for bone_idx in ik_keyframes.keys():
		var track_out: Array = []
		for key in ik_keyframes[bone_idx]:
			track_out.append({
				"frame": key["frame"],
				"target": [key["target"][0], key["target"][1], key["target"][2]],
			})
		result[str(bone_idx)] = track_out
	return result

func deserialize_ik_keyframes(obj: Node3D, data: Dictionary) -> void:
	if data.is_empty():
		return
	var ik_keyframes: Dictionary = {}
	for bone_key in data.keys():
		var track: Array = []
		for key in data[bone_key]:
			track.append({
				"frame": int(key["frame"]),
				"target": [float(key["target"][0]), float(key["target"][1]), float(key["target"][2])],
			})
		ik_keyframes[int(bone_key)] = track
	obj.set_meta("ik_keyframes", ik_keyframes)


func save_project(project_name: String) -> void:
	if project_name == "":
		return
	var dir_path: String = "user://projects/" + project_name
	DirAccess.make_dir_recursive_absolute(dir_path)
	var data: Dictionary = serialize_project()
	var file := FileAccess.open(dir_path + "/project.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func load_project(project_name: String) -> void:
	var path: String = "user://projects/" + project_name + "/project.json"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var content: String = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	if parsed is Dictionary:
		deserialize_project(parsed)

func _create_figure_silent(shape_type: String) -> StaticBody3D:
	return spawn_shape(shape_type)

func _create_light_silent(record: Dictionary) -> StaticBody3D:
	var body: StaticBody3D = spawn_light(record.get("light_type", "sol"))
	var light_node: Light3D = body.get_node("LightSource")
	light_node.light_energy = record.get("light_energy", 1.2)
	light_node.shadow_enabled = record.get("shadow_enabled", false)
	if record.has("light_color"):
		var lc: Array = record["light_color"]
		light_node.light_color = Color(lc[0], lc[1], lc[2])
	if light_node is SpotLight3D:
		light_node.spot_range = record.get("spot_range", 10.0)
		light_node.spot_angle = record.get("spot_angle", 35.0)
	elif light_node is OmniLight3D:
		light_node.omni_range = record.get("omni_range", 8.0)
	return body

func _create_camera_silent() -> StaticBody3D:
	return spawn_camera()

func _create_music_silent(record: Dictionary) -> StaticBody3D:
	var body: StaticBody3D = spawn_music()
	var format: String = record.get("audio_format", "ogg")
	var raw_bytes: PackedByteArray = Marshalls.base64_to_raw(record.get("audio_base64", ""))

	var tmp_path: String = OS.get_user_data_dir() + "/tmp_import_" + str(Time.get_ticks_msec()) + "." + format
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	f.store_buffer(raw_bytes)
	f.close()

	var stream: AudioStream = null
	match format:
		"wav": stream = AudioStreamWAV.load_from_file(tmp_path)
		"ogg": stream = AudioStreamOggVorbis.load_from_file(tmp_path)
		"mp3": stream = AudioStreamMP3.load_from_file(tmp_path)

	var player: AudioStreamPlayer = body.get_node("AudioSource")
	player.stream = stream
	player.volume_db = record.get("volume_db", 0.0)
	body.set_meta("audio_bytes", raw_bytes)
	body.set_meta("audio_format", format)
	return body

func _create_video_silent(record: Dictionary) -> StaticBody3D:
	var body: StaticBody3D = spawn_video_plane()
	var cache_dir: String = OS.get_user_data_dir() + "/video_cache_" + str(Time.get_ticks_msec()) + "_" + str(randi())
	DirAccess.make_dir_recursive_absolute(cache_dir)

	var frames_b64: Array = record.get("frames_base64", [])
	var frames: Array = []
	
	for i in frames_b64.size():
		var bytes: PackedByteArray = Marshalls.base64_to_raw(frames_b64[i])
		var fpath: String = cache_dir + "/frame_%04d.png" % i
		var fw := FileAccess.open(fpath, FileAccess.WRITE)
		fw.store_buffer(bytes)
		fw.close()
		var img := Image.new()
		img.load_png_from_buffer(bytes)
		frames.append(ImageTexture.create_from_image(img))

	body.set_meta("video_cache_dir", cache_dir)
	body.set_meta("video_frames", frames)
	body.set_meta("video_fps", record.get("video_fps", 24.0))
	body.set_meta("video_start_offset", record.get("video_start_offset", 0))
	body.set_meta("video_loop", record.get("video_loop", true))
	body.set_meta("has_audio", record.get("has_audio", false))

	var brightness: float = record.get("video_brightness", 1.0)
	body.set_meta("video_brightness", brightness)

	if frames.size() > 0:
		var mesh_instance: MeshInstance3D = body.get_node("Mesh")
		var mat: StandardMaterial3D = mesh_instance.material_override
		mat.albedo_texture = frames[0]
		mat.albedo_color = Color(brightness, brightness, brightness)

	if record.get("has_audio", false) and record.has("audio_base64"):
		var audio_bytes: PackedByteArray = Marshalls.base64_to_raw(record["audio_base64"])
		var audio_path: String = cache_dir + "/audio.ogg"
		var af := FileAccess.open(audio_path, FileAccess.WRITE)
		af.store_buffer(audio_bytes)
		af.close()
		var stream: AudioStream = AudioStreamOggVorbis.load_from_file(audio_path)
		var audio_player := AudioStreamPlayer.new()
		audio_player.name = "VideoAudio"
		audio_player.stream = stream
		audio_player.volume_db = record.get("volume_db", 0.0)
		body.add_child(audio_player)

	return body

func deserialize_project(data: Dictionary) -> void:
	if selection_manager != null:
		selection_manager.deselect()
	if history_manager != null and history_manager.has_method("clear"):
		history_manager.clear()
	for child in spawn_root.get_children():
		child.free()

	spawn_offset = 0
	if selection_manager.materials_panel != null:
		selection_manager.materials_panel.deserialize_palette(data.get("materials_palette", {}))

	if animation_manager != null and animation_manager.timeline_ruler != null:
		animation_manager.timeline_ruler.set_end_frame(data.get("animation_end_frame", 140))

	if options_panel != null:
		var brightness: float = data.get("master_brightness", 1.0)
		options_panel.master_brightness_spinbox.value = brightness

	if animation_manager != null:
		animation_manager.FPS = data.get("project_fps", 24.0)
		animation_manager.interpolation_mode = data.get("interpolation_mode", "smooth")

	if options_panel != null:
		options_panel.fps_spinbox.set_value_no_signal(animation_manager.FPS)
		match animation_manager.interpolation_mode:
			"spline": options_panel.interpolation_option.selected = 0
			"smooth": options_panel.interpolation_option.selected = 1
			_: options_panel.interpolation_option.selected = 2

	var records: Array = data.get("objects", [])
	var created: Array = []

	for record in records:
		var body: StaticBody3D = null
		match record.get("category", "figure"):
			"figure": body = _create_figure_silent(record.get("shape_type", "cubo"))
			"light": body = _create_light_silent(record)
			"camera": body = _create_camera_silent()
			"music": body = _create_music_silent(record)
			"video": body = _create_video_silent(record)
			"model": body = _create_model_silent(record)
			"model_part": body = _create_model_part_silent(record, created)
		created.append(body)


	for i in records.size():
		var model_index: int = records[i].get("attached_to_model_index", -1)
		if model_index >= 0 and created[i] != null and created[model_index] != null:
			var model_body: Node = created[model_index]
			var import_root: Node = model_body.get_node_or_null("ImportedModel")
			var skeleton: Skeleton3D = selection_manager.find_skeleton_in(import_root) if import_root != null else null
			if skeleton != null:
				var bone_idx: int = skeleton.find_bone(records[i].get("attached_to_bone_name", ""))
				if bone_idx != -1:
					selection_manager.attach_object_to_bone(created[i], skeleton, bone_idx)


	for i in records.size():
		var record: Dictionary = records[i]
		var body: StaticBody3D = created[i]
		if body == null:
			continue
		body.name = record.get("name", body.name)
		body.position = Vector3(record["position"][0], record["position"][1], record["position"][2])
		body.rotation_degrees = Vector3(record["rotation_degrees"][0], record["rotation_degrees"][1], record["rotation_degrees"][2])
		body.scale = Vector3(record["scale"][0], record["scale"][1], record["scale"][2])
		body.visible = record.get("visible", true)
		deserialize_keyframes(body, record.get("keyframes", []))
		body.set_meta("gizmo_size_multiplier", record.get("gizmo_size_multiplier", 1.0))
		if record.get("collision_disabled", false):
			selection_manager.set_object_collision_enabled(body, false, true)
		if record.get("category", "") == "camera":
			var camera_node: Camera3D = body.get_node_or_null("CameraSource")
			if camera_node != null:
				camera_node.fov = record.get("fov", 75.0)
				if record.get("has_custom_bg", false):
					var env := Environment.new()
					env.background_mode = Environment.BG_COLOR
					var c: Array = record.get("bg_color", [0.3, 0.3, 0.3])
					env.background_color = Color(c[0], c[1], c[2])
					camera_node.environment = env
				
		deserialize_bone_keyframes(body, record.get("bone_keyframes", {}))
		deserialize_ik_keyframes(body, record.get("ik_keyframes", {}))
		var anim_store: Dictionary = {}
		var saved_anims: Dictionary = record.get("animations", {})
		for anim_name in saved_anims.keys():
			anim_store[anim_name] = {
				"keyframes": _keys_from_json(saved_anims[anim_name].get("keyframes", [])),
				"bone_keyframes": _bones_from_json(saved_anims[anim_name].get("bone_keyframes", {})),
				"pose": _pose_from_json(saved_anims[anim_name].get("pose", [])),
			}
		body.set_meta("animations", anim_store)

		var anim_names: Array = record.get("animation_names", [])
		var anim_current: String = record.get("current_animation", "")
		# Proyectos viejos: tenía keyframes pero no lista de animaciones
		if anim_names.is_empty() and (not body.get_meta("keyframes", []).is_empty() or not body.get_meta("bone_keyframes", {}).is_empty()):
			anim_names = ["Animación 1"]
			anim_current = "Animación 1"
		body.set_meta("animation_names", anim_names)
		body.set_meta("current_animation", anim_current)


		if record.has("material"):
			var mesh_instance: MeshInstance3D = body.get_node_or_null("Mesh")
			if mesh_instance != null:
				var mat := StandardMaterial3D.new()
				var c: Array = record["material"]["color"]
				mat.albedo_color = Color(c[0], c[1], c[2], c[3])
				mat.roughness = record["material"].get("roughness", 1.0)
				mat.metallic = record["material"].get("metallic", 0.0)
				if record["material"].get("texture_base64") != null:
					var img := Image.new()
					img.load_png_from_buffer(Marshalls.base64_to_raw(record["material"]["texture_base64"]))
					mat.albedo_texture = ImageTexture.create_from_image(img)
					AlphaHelper.fix(mat)   # <-- nueva
				mesh_instance.material_override = mat

		if record.get("double_sided", false) or record.get("unshaded", false):
			body.set_meta("double_sided", record.get("double_sided", false))
			body.set_meta("unshaded", record.get("unshaded", false))
			selection_manager._apply_surface_flags(body)

	for i in records.size():
		var parent_index: int = records[i].get("parent_index", -1)
		if parent_index >= 0 and created[i] != null and created[parent_index] != null:
			created[i].reparent(created[parent_index], true)

	
					
	if outliner != null:
		outliner.folders.clear()
		var folders_data: Dictionary = data.get("folders", {})
		for folder_name in folders_data.keys():
			var objs: Array = []
			for i in records.size():
				if records[i]["name"] in folders_data[folder_name] and created[i] != null:
					objs.append(created[i])
			outliner.folders[folder_name] = objs
		outliner.refresh()
	if animation_manager != null:
		animation_manager._after_animation_change()

func pick_model_file_native() -> String:
	var output: Array = []
	var script := 'Add-Type -AssemblyName System.Windows.Forms; $dialog = New-Object System.Windows.Forms.OpenFileDialog; $dialog.Filter = \'Modelos 3D (*.glb;*.gltf)|*.glb;*.gltf\'; if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Write-Output $dialog.FileName }'
	OS.execute("powershell", ["-NoProfile", "-Command", script], output, true)
	if output.size() > 0:
		return output[0].strip_edges()
	return ""

func import_model(path: String) -> StaticBody3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err: int = doc.append_from_file(path, state)
	if err != OK:
		get_tree().call_group("toast_system", "show_toast", "No se pudo leer el modelo")
		return null

	var model_root: Node = doc.generate_scene(state)
	if model_root == null:
		get_tree().call_group("toast_system", "show_toast", "No se pudo leer el modelo")
		return null

	model_root.name = "ImportedModel"
	_force_lit_shading(model_root)

	spawn_offset += 1
	var body := StaticBody3D.new()
	body.name = "Model_%d" % spawn_offset
	body.input_ray_pickable = false
	body.add_child(model_root)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	col.shape = shape
	body.add_child(col)

	spawn_root.add_child(body)

	

	var combined: AABB = selection_manager.get_combined_aabb(body)
	shape.size = combined.size
	col.position = combined.position + combined.size / 2.0

	var model_bytes := PackedByteArray()
	var mf := FileAccess.open(path, FileAccess.READ)
	if mf != null:
		model_bytes = mf.get_buffer(mf.get_length())
		mf.close()

	body.set_meta("is_imported_model", true)
	body.set_meta("model_path", path)
	body.set_meta("model_bytes", model_bytes)
	body.set_meta("model_format", path.get_extension().to_lower())

	outliner.refresh()

	if selection_manager != null:
		selection_manager.select_object(body)

	return body

func _create_model_silent(record: Dictionary) -> StaticBody3D:
	var format: String = record.get("model_format", "glb")
	var raw_bytes: PackedByteArray = Marshalls.base64_to_raw(record.get("model_base64", ""))

	var tmp_path: String = OS.get_user_data_dir() + "/tmp_model_" + str(Time.get_ticks_msec()) + "." + format
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	f.store_buffer(raw_bytes)
	f.close()

	var body: StaticBody3D = import_model(tmp_path)
	body.set_meta("bone_size_multiplier", record.get("bone_size_multiplier", 1.0))
	var overrides: Array = record.get("texture_overrides", [])
	if not overrides.is_empty():
		var import_root: Node = body.get_node_or_null("ImportedModel")
		if import_root != null:
			for entry in overrides:
				var target: Node = import_root.get_node_or_null(NodePath(entry["path"]))
				if target is MeshInstance3D:
					var img := Image.new()
					img.load_png_from_buffer(Marshalls.base64_to_raw(entry["texture_base64"]))
					var mat := StandardMaterial3D.new()
					mat.albedo_texture = ImageTexture.create_from_image(img)
					AlphaHelper.fix(mat)   # <-- nueva
					if entry["surface"] == -1:
						target.material_override = mat
					else:
						target.set_surface_override_material(entry["surface"], mat)

	var bone_poses: Array = record.get("bone_poses", [])
	if not bone_poses.is_empty():
		var import_root2: Node = body.get_node_or_null("ImportedModel")
		var skeleton2: Skeleton3D = selection_manager.find_skeleton_in(import_root2) if import_root2 != null else null
		if skeleton2 != null:
			for bi in range(min(bone_poses.size(), skeleton2.get_bone_count())):
				var pd: Dictionary = bone_poses[bi]
				var p: Array = pd["position"]
				var r: Array = pd["rotation"]
				var s: Array = pd["scale"]
				skeleton2.set_bone_pose_position(bi, Vector3(p[0], p[1], p[2]))
				skeleton2.set_bone_pose_rotation(bi, Quaternion(r[0], r[1], r[2], r[3]))
				skeleton2.set_bone_pose_scale(bi, Vector3(s[0], s[1], s[2]))
			skeleton2.force_update_all_bone_transforms()
	if record.has("collision_size"):
		var col_shape2: CollisionShape3D = selection_manager.find_collision_shape(body)
		if col_shape2 != null and col_shape2.shape is BoxShape3D:
			var cbox2: BoxShape3D = col_shape2.shape
			var cs: Array = record["collision_size"]
			cbox2.size = Vector3(cs[0], cs[1], cs[2])
			var cp: Array = record.get("collision_position", [0.0, 0.0, 0.0])
			col_shape2.position = Vector3(cp[0], cp[1], cp[2])
			col_shape2.scale = Vector3.ONE

	var import_root3: Node = body.get_node_or_null("ImportedModel")
	if import_root3 != null:
		for del_path in record.get("deleted_parts", []):
			var dead: Node = import_root3.get_node_or_null(NodePath(del_path))
			if dead != null and dead.get_parent() != null:
				dead.get_parent().remove_child(dead)
				dead.free()

	if selection_manager != null:
		selection_manager.deselect()

	return body

	

func _debug_print_model_tree(node: Node, depth: int) -> void:
	var indent: String = "  ".repeat(depth)
	if node is MeshInstance3D:
		print(indent, "MeshInstance3D '", node.name, "' visible=", node.visible, " mesh=", node.mesh, " scale=", node.scale, " position=", node.position)
	else:
		print(indent, node.get_class(), " '", node.name, "'")
	for child in node.get_children():
		_debug_print_model_tree(child, depth + 1)

func _disable_backface_culling(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for i in node.mesh.get_surface_count():
			var mat: Material = node.mesh.surface_get_material(i)
			if mat is BaseMaterial3D:
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for child in node.get_children():
		_disable_backface_culling(child)

func _debug_print_materials(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for i in node.mesh.get_surface_count():
			var mat: Material = node.mesh.surface_get_material(i)
			if mat is BaseMaterial3D:
				if mat.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL or mat.emission_enabled:
					print("SOSPECHOSO -> MALLA '", node.name, "' shading_mode=", mat.shading_mode, " emission_enabled=", mat.emission_enabled, " emission_energy=", mat.emission_energy_multiplier)
			elif mat != null:
				print("MATERIAL NO ESTANDAR -> MALLA '", node.name, "' tipo=", mat.get_class())
			else:
				print("SIN MATERIAL -> MALLA '", node.name, "'")
	for child in node.get_children():
		_debug_print_materials(child)

func _debug_count_meshes(node: Node, count: Array) -> void:
	if node is MeshInstance3D:
		count[0] += 1
	for child in node.get_children():
		_debug_count_meshes(child, count)

func _force_lit_shading(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for i in node.mesh.get_surface_count():
			var mat: Material = node.mesh.surface_get_material(i)
			if mat is BaseMaterial3D and mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	for child in node.get_children():
		_force_lit_shading(child)

func _on_welcome_close_pressed() -> void:
	welcome_tip.visible = false
	var file := FileAccess.open("user://welcome_seen.flag", FileAccess.WRITE)
	if file != null:
		file.store_string("1")
		file.close()

func _collect_texture_overrides(root: Node, node: Node, result: Array) -> void:
	if node is MeshInstance3D and node.mesh != null:
		if node.material_override is BaseMaterial3D and node.material_override.albedo_texture != null:
			var img: Image = node.material_override.albedo_texture.get_image()
			result.append({
				"path": str(root.get_path_to(node)),
				"surface": -1,
				"texture_base64": Marshalls.raw_to_base64(img.save_png_to_buffer()),
			})
		for i in node.mesh.get_surface_count():
			var mat: Material = node.get_surface_override_material(i)
			if mat is BaseMaterial3D and mat.albedo_texture != null:
				var img2: Image = mat.albedo_texture.get_image()
				result.append({
					"path": str(root.get_path_to(node)),
					"surface": i,
					"texture_base64": Marshalls.raw_to_base64(img2.save_png_to_buffer()),
				})
	for child in node.get_children():
		_collect_texture_overrides(root, child, result)

func get_ffmpeg_path() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://ffmpeg/ffmpeg.exe")
	else:
		return OS.get_executable_path().get_base_dir() + "/ffmpeg/ffmpeg.exe"

# ---------- Animaciones múltiples: ayudantes de guardado ----------

func _keys_to_json(keys: Array) -> Array:
	var result: Array = []
	for key in keys:
		var rec := {
			"frame": key["frame"],
			"position": [key["position"].x, key["position"].y, key["position"].z],
			"rotation": [key["rotation"].x, key["rotation"].y, key["rotation"].z],
			"scale": [key["scale"].x, key["scale"].y, key["scale"].z],
		}
		if key.has("energy"):
			rec["energy"] = key["energy"]
		result.append(rec)
	return result

func _keys_from_json(data: Array) -> Array:
	var result: Array = []
	for key in data:
		var k := {
			"frame": int(key["frame"]),
			"position": Vector3(key["position"][0], key["position"][1], key["position"][2]),
			"rotation": Vector3(key["rotation"][0], key["rotation"][1], key["rotation"][2]),
			"scale": Vector3(key["scale"][0], key["scale"][1], key["scale"][2]),
		}
		if key.has("energy"):
			k["energy"] = float(key["energy"])
		result.append(k)
	return result

func _bones_to_json(bone_keyframes: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for bone_idx in bone_keyframes.keys():
		var track_out: Array = []
		for key in bone_keyframes[bone_idx]:
			var q: Quaternion = key["rotation"]
			var pos: Vector3 = key.get("position", Vector3.ZERO)
			var scl: Vector3 = key.get("scale", Vector3.ONE)
			track_out.append({
				"frame": key["frame"],
				"position": [pos.x, pos.y, pos.z],
				"rotation": [q.x, q.y, q.z, q.w],
				"scale": [scl.x, scl.y, scl.z],
			})
		result[str(bone_idx)] = track_out
	return result

func _bones_from_json(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for bone_key in data.keys():
		var track: Array = []
		for key in data[bone_key]:
			var r: Array = key["rotation"]
			var p: Array = key.get("position", [0.0, 0.0, 0.0])
			var s: Array = key.get("scale", [1.0, 1.0, 1.0])
			track.append({
				"frame": int(key["frame"]),
				"position": Vector3(p[0], p[1], p[2]),
				"rotation": Quaternion(r[0], r[1], r[2], r[3]),
				"scale": Vector3(s[0], s[1], s[2]),
			})
		result[int(bone_key)] = track
	return result

func _serialize_animation_store(obj: Node3D) -> Dictionary:
	var out: Dictionary = {}
	var store: Dictionary = obj.get_meta("animations", {})
	var names: Array = obj.get_meta("animation_names", [])
	var cur: String = obj.get_meta("current_animation", "")
	for anim in store.keys():
		if anim == cur or not names.has(anim):
			continue
		out[anim] = {
			"keyframes": _keys_to_json(store[anim].get("keyframes", [])),
			"bone_keyframes": _bones_to_json(store[anim].get("bone_keyframes", {})),
			"pose": _pose_to_json(store[anim].get("pose", [])),
		}
	return out

func _pose_to_json(pose: Array) -> Array:
	var result: Array = []
	for b in pose:
		var p: Vector3 = b["p"]
		var r: Quaternion = b["r"]
		var s: Vector3 = b["s"]
		result.append({"p": [p.x, p.y, p.z], "r": [r.x, r.y, r.z, r.w], "s": [s.x, s.y, s.z]})
	return result

func _pose_from_json(data: Array) -> Array:
	var result: Array = []
	for b in data:
		result.append({
			"p": Vector3(b["p"][0], b["p"][1], b["p"][2]),
			"r": Quaternion(b["r"][0], b["r"][1], b["r"][2], b["r"][3]),
			"s": Vector3(b["s"][0], b["s"][1], b["s"][2]),
		})
	return result

func _create_model_part_silent(record: Dictionary, created: Array) -> StaticBody3D:
	var model_index: int = record.get("model_index", -1)
	if model_index < 0 or model_index >= created.size() or created[model_index] == null:
		return null
	var import_root: Node = created[model_index].get_node_or_null("ImportedModel")
	if import_root == null:
		return null
	var part: Node = import_root.get_node_or_null(NodePath(record.get("part_path", "")))
	if part == null or not (part is MeshInstance3D):
		return null
	return selection_manager.promote_model_part(part)
