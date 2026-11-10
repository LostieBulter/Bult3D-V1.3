extends Node

signal export_progress(current: int, total: int)
signal export_finished
@export var render_viewport_path: NodePath
@export var animation_manager_path: NodePath
@export var origin_gizmo_path: NodePath
@export var floor_path: NodePath
@export var spawn_root_path: NodePath
@export var camera_rig_ref_path: NodePath
@export var selection_manager_path: NodePath
@export var editor_camera_path: NodePath
var origin_gizmo_scale: float = 1.0  # no se usa, solo para referencia si hiciera falta recrearlo con datos
var editor_camera: Camera3D
var selection_manager: Node3D
var camera_rig_ref: Node3D
var spawn_root: Node3D
var render_viewport: SubViewport
var animation_manager: Node

var floor_node: Node3D

var is_rendering := false
@export var main_script_path: NodePath
var main_script: Node



func _ready() -> void:
	
	if main_script_path != NodePath(""):
		main_script = get_node(main_script_path)
		
	if editor_camera_path != NodePath(""):
		editor_camera = get_node(editor_camera_path)
	
	if selection_manager_path != NodePath(""):
		selection_manager = get_node(selection_manager_path)
	render_viewport = get_node(render_viewport_path)
	animation_manager = get_node(animation_manager_path)
	spawn_root = get_node(spawn_root_path)
	
	if floor_path != NodePath(""):
		floor_node = get_node(floor_path)
	if camera_rig_ref_path != NodePath(""):
		camera_rig_ref = get_node(camera_rig_ref_path)
		
		
func set_render_resolution(width: int, height: int) -> void:
	render_viewport.size = Vector2i(width, height)
	
func export_sequence(camera: Camera3D, start_frame: int, end_frame: int, output_dir: String) -> void:
	if is_rendering:
		return
	RenderingServer.force_draw()
	is_rendering = true
	print("EXPORTACIÓN TERMINADA, is_rendering ahora es: ", is_rendering)

	if camera_rig_ref != null:
		camera_rig_ref.stop_following_camera()
	if selection_manager != null:
		selection_manager.deselect()
		selection_manager.clear_bone_selection()
	else:
		print("ERROR: selection_manager es null en render_manager")

	await get_tree().process_frame
	await get_tree().process_frame

	var camera_body: Node = camera.get_parent()
	var original_parent: Node = camera_body.get_parent()
	var original_index: int = camera_body.get_index()
	var original_transform: Transform3D = camera_body.global_transform

	hide_editor_helpers(true)
	original_parent.remove_child(camera_body)
	render_viewport.add_child(camera_body)
	camera_body.global_transform = original_transform
	camera.current = true

	await get_tree().process_frame

	DirAccess.make_dir_recursive_absolute(output_dir)
	for frame in range(start_frame, end_frame + 1):
		animation_manager.set_frame_externally(frame)
		animation_manager.apply_frame_to_object(camera_body)
		await RenderingServer.frame_post_draw
		var img: Image = render_viewport.get_texture().get_image()
		var filename: String = "%s/frame_%04d.png" % [output_dir, frame]
		img.save_png(filename)

	render_viewport.remove_child(camera_body)
	original_parent.add_child(camera_body)
	original_parent.move_child(camera_body, original_index)
	camera_body.global_transform = original_transform
	camera.current = false
	if editor_camera != null:
		editor_camera.current = true
	hide_editor_helpers(false)
	is_rendering = false
	print("Exportación completa: ", output_dir)
	export_finished.emit()
	
func hide_editor_helpers(hide: bool) -> void:
	
	if floor_node != null:
		floor_node.visible = not hide
	for obj in get_all_scene_objects():
		if not (obj is Node3D):
			continue
		var is_camera: bool = obj.get_node_or_null("CameraSource") != null
		var is_light: bool = obj.get_node_or_null("LightSource") != null
		if is_camera:
			obj.visible = not hide
		elif is_light:
			var mesh_icon: Node = obj.get_node_or_null("Mesh")
			if mesh_icon != null:
				mesh_icon.visible = not hide
			for child in obj.get_children():
				if child is MeshInstance3D and child.name != "Mesh":
					child.visible = not hide


func export_single_frame(camera: Camera3D, frame: int, output_path: String) -> void:
	if is_rendering:
		return
	is_rendering = true
	print("EXPORTACIÓN TERMINADA, is_rendering ahora es: ", is_rendering)
	if camera_rig_ref != null:
		camera_rig_ref.stop_following_camera()
	if selection_manager != null:
		selection_manager.deselect()
		selection_manager.clear_bone_selection()
	await get_tree().process_frame
	await get_tree().process_frame

	var camera_body: Node = camera.get_parent()
	var original_parent: Node = camera_body.get_parent()
	var original_index: int = camera_body.get_index()
	var original_transform: Transform3D = camera_body.global_transform

	hide_editor_helpers(true)
	original_parent.remove_child(camera_body)
	render_viewport.add_child(camera_body)
	camera_body.global_transform = original_transform
	camera.current = true
	await get_tree().process_frame

	animation_manager.set_frame_externally(frame)
	animation_manager.apply_frame_to_object(camera_body)
	await RenderingServer.frame_post_draw
	var img: Image = render_viewport.get_texture().get_image()
	img.save_png(output_path)

	render_viewport.remove_child(camera_body)
	original_parent.add_child(camera_body)
	original_parent.move_child(camera_body, original_index)
	camera_body.global_transform = original_transform
	camera.current = false
	if editor_camera != null:
		editor_camera.current = true
	hide_editor_helpers(false)
	is_rendering = false

func convert_frames_to_mp4(frames_dir: String, output_path: String) -> void:
	var ffmpeg_path: String = main_script.get_ffmpeg_path()

	if not FileAccess.file_exists(ffmpeg_path):
		get_tree().call_group("toast_system", "show_toast", "No se encontró ffmpeg.exe en: " + ffmpeg_path)
		return

	var output: Array = []
	var args := [
		"-y",
		"-framerate", str(int(animation_manager.FPS)),
		"-i", frames_dir + "/frame_%04d.png",
		"-c:v", "libx264",
		"-pix_fmt", "yuv420p",
		output_path
	]
	var exit_code: int = OS.execute(ffmpeg_path, args, output, true)
	print("Conversión a MP4 - código: ", exit_code)
	if exit_code == 0:
		print("Video MP4 exportado: ", output_path)
		get_tree().call_group("toast_system", "show_toast", "Video exportado: " + output_path)
	else:
		var error_text: String = ""
		for line in output:
			error_text += str(line) + "\n"
		print("Error al generar el MP4: ", error_text)
		get_tree().call_group("toast_system", "show_toast", "Error al exportar (código %d) — revisá la carpeta ffmpeg" % exit_code)

func get_all_scene_objects() -> Array:
	var result: Array = []
	_collect_scene_objects(spawn_root, result)
	return result

func _collect_scene_objects(node: Node, result: Array) -> void:
	for child in node.get_children():
		if child is StaticBody3D:
			result.append(child)
		_collect_scene_objects(child, result)
