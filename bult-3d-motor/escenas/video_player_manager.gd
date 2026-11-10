extends Node

@export var spawn_root_path: NodePath
@export var animation_manager_path: NodePath
var spawn_root: Node3D
var animation_manager: Node

func _ready() -> void:
	spawn_root = get_node(spawn_root_path)
	animation_manager = get_node(animation_manager_path)

func _process(_delta: float) -> void:
	var current_frame: int = animation_manager.current_frame
	var is_playing: bool = animation_manager.is_playing

	for obj in get_all_scene_objects():
		if not obj.has_meta("is_video"):
			continue
		var frames: Array = obj.get_meta("video_frames")
		if frames.is_empty():
			continue

		var start_offset: int = obj.get_meta("video_start_offset", 0)
		var local_frame: int = current_frame - start_offset

		var mesh_instance: MeshInstance3D = obj.get_node("Mesh")
		var mat: StandardMaterial3D = mesh_instance.material_override

		if local_frame < 0:
			# Todavía no llegó su turno: mostramos el plano vacío/oculto
			mesh_instance.visible = false
			continue
		else:
			mesh_instance.visible = true

		var is_loop: bool = obj.get_meta("video_loop", true)
		var last_frame_index: int = frames.size() - 1
		var frame_index: int

		if is_loop:
			frame_index = local_frame % frames.size()
		else:
			frame_index = min(local_frame, last_frame_index)

		mat.albedo_texture = frames[frame_index]

		var audio_player: AudioStreamPlayer = obj.get_node_or_null("VideoAudio")
		if audio_player != null:
			var reached_end: bool = (not is_loop) and (local_frame >= last_frame_index)
			var should_be_playing: bool = is_playing and local_frame >= 0 and not reached_end

			if should_be_playing and not audio_player.playing:
				audio_player.play(float(local_frame) / animation_manager.FPS)
			elif not should_be_playing and audio_player.playing:
				audio_player.stop()

			if is_loop and local_frame == 0 and is_playing:
				audio_player.play(0.0)

func get_all_scene_objects() -> Array:
	var result: Array = []
	_collect_scene_objects(spawn_root, result)
	return result

func _collect_scene_objects(node: Node, result: Array) -> void:
	for child in node.get_children():
		if child is StaticBody3D:
			result.append(child)
		_collect_scene_objects(child, result)
