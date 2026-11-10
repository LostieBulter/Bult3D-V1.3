extends Node

@export var selection_manager_path: NodePath
@export var timeline_ruler_path: NodePath
@export var add_keyframe_button_path: NodePath
@export var playback_controls_path: NodePath
@export var spawn_root_path: NodePath
@export var end_frame_input_path: NodePath
@export var video_loop_controls_path: NodePath
@export var history_manager_path: NodePath
var history_manager: Node
var video_loop_controls: HBoxContainer
var spawn_root: Node3D
var last_selected_object: Node3D = null
var playback_controls: HBoxContainer

var is_playing := false
var play_time_accum := 0.0
var FPS: float = 24.0
var interpolation_mode: String = "smooth"  # "linear" o "smooth"
var last_frame: int = 0  # recordamos hasta dónde llega la animación
var selection_manager: Node3D
var timeline_ruler: Control
var current_frame: int = 0

var animations_ui: Panel

func _ready() -> void:
	
	if video_loop_controls_path != NodePath(""):
		video_loop_controls = get_node(video_loop_controls_path)
	
	if end_frame_input_path != NodePath(""):
		var end_frame_input: LineEdit = get_node(end_frame_input_path)
		end_frame_input.end_frame_changed.connect(func(value): timeline_ruler.set_end_frame(value))
	spawn_root = get_node(spawn_root_path)
	selection_manager = get_node(selection_manager_path)
	timeline_ruler = get_node(timeline_ruler_path)

	var keyframe_button: Control = get_node(add_keyframe_button_path)
	keyframe_button.keyframe_pressed.connect(_on_add_keyframe_pressed)

	timeline_ruler.frame_changed.connect(_on_frame_changed)
	timeline_ruler.keyframe_delete_requested.connect(_on_keyframe_delete_requested)
	timeline_ruler.keyframe_moved.connect(_on_keyframe_moved)
	timeline_ruler.video_range_dragged.connect(_on_video_range_dragged)
	
	if playback_controls_path != NodePath(""):
		playback_controls = get_node(playback_controls_path)
		playback_controls.play_pressed.connect(_on_play_pressed)
		playback_controls.stop_pressed.connect(_on_stop_pressed)
	if history_manager_path != NodePath(""):
		history_manager = get_node(history_manager_path)
	_build_animations_panel.call_deferred()
	
func _process(delta: float) -> void:
	_update_music_playback()

	if not is_playing:
		# Aunque no estemos reproduciendo, seguimos revisando si cambió la selección
		check_selection_change()
		return

	play_time_accum += delta
	var frame_duration: float = 1.0 / FPS

	while play_time_accum >= frame_duration:
		play_time_accum -= frame_duration
		current_frame += 1

		var max_frame: int = get_global_max_frame()
		if max_frame > 0 and current_frame > max_frame:
			current_frame = 0

		timeline_ruler.current_frame = current_frame
		timeline_ruler.queue_redraw()
		apply_frame_to_all_objects()

			
func get_global_max_frame() -> int:
	var max_frame := 0
	for obj in get_all_scene_objects():
		if obj is Node3D and obj.has_meta("keyframes"):
			var keyframes: Array = obj.get_meta("keyframes")
			if not keyframes.is_empty():
				var last: int = keyframes[keyframes.size() - 1]["frame"]
				max_frame = max(max_frame, last)
		return timeline_ruler.end_frame
	return max_frame
	
func _on_add_keyframe_pressed() -> void:
	var sel: Node3D = selection_manager.selected_object
	if sel == null or sel.get_meta("current_animation", "") == "":
		get_tree().call_group("toast_system", "show_toast", "Selecciona un objeto y crea una animación (Shift+T)")
		return
	var obj: Node3D = selection_manager.selected_object
	if obj == null:
		return

	if selection_manager.ik_gizmo != null and selection_manager.ik_active_bone_idx == selection_manager.selected_bone_idx and selection_manager.selected_bone_idx != -1:
		var skeleton: Skeleton3D = selection_manager.selected_skeleton
		var tip_idx: int = selection_manager.selected_bone_idx
		var mid_idx: int = skeleton.get_bone_parent(tip_idx)
		var root_idx: int = skeleton.get_bone_parent(mid_idx) if mid_idx != -1 else -1

		if mid_idx != -1:
			_add_bone_keyframe(obj, skeleton, mid_idx)
		if root_idx != -1:
			_add_bone_keyframe(obj, skeleton, root_idx)
		return

	if selection_manager.selected_bone_idx != -1 and selection_manager.selected_skeleton != null:
		_add_bone_keyframe(obj, selection_manager.selected_skeleton, selection_manager.selected_bone_idx)
		return

	var keyframes: Array = obj.get_meta("keyframes", [])

	# Si ya había un keyframe en este cuadro, lo reemplazamos en vez de duplicar
	var existing_index := -1
	for i in keyframes.size():
		if keyframes[i]["frame"] == current_frame:
			existing_index = i
			break

	var old_key_data = keyframes[existing_index].duplicate() if existing_index != -1 else null

	var new_key := {
		"frame": current_frame,
		"position": obj.position,
		"rotation": obj.rotation_degrees,
		"scale": obj.scale,
	}
	
	var light_node: Node = obj.get_node_or_null("LightSource")
	if light_node != null and light_node is Light3D:
		new_key["energy"] = light_node.light_energy
	
	
	if existing_index != -1:
		keyframes[existing_index] = new_key
	else:
		keyframes.append(new_key)
		keyframes.sort_custom(func(a, b): return a["frame"] < b["frame"])

	obj.set_meta("keyframes", keyframes)
	timeline_ruler.set_keyframes(keyframes)
	timeline_ruler.queue_redraw()

	if history_manager != null:
		history_manager.push_action({
			"type": "keyframe_set",
			"object": obj,
			"kind": "object",
			"bone_idx": -1,
			"frame": current_frame,
			"old_key_data": old_key_data,
			"new_key_data": new_key.duplicate(),
		})

func _on_frame_changed(frame: int) -> void:
	current_frame = frame
	apply_frame_to_all_objects()

func _interpolate_rotation(a: Vector3, b: Vector3, t: float) -> Quaternion:
	var d: Vector3 = (b - a).abs()
	var changed := 0
	for i in 3:
		if d[i] > 0.5:
			changed += 1

	# Un solo ángulo cambia (hélice, vueltas completas): ángulo por ángulo
	if changed <= 1:
		var e: Vector3 = a.lerp(b, t)
		return Quaternion.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z)))

	# Varios ángulos cambian: camino directo entre las dos orientaciones
	var qa := Quaternion.from_euler(Vector3(deg_to_rad(a.x), deg_to_rad(a.y), deg_to_rad(a.z)))
	var qb := Quaternion.from_euler(Vector3(deg_to_rad(b.x), deg_to_rad(b.y), deg_to_rad(b.z)))
	return qa.slerp(qb, t)


func apply_frame_to_object(obj: Node3D) -> void:
	if obj == null:
		return
	var keyframes: Array = obj.get_meta("keyframes", [])

	if not keyframes.is_empty():
		# Buscamos el keyframe anterior y el siguiente al cuadro actual, para interpolar entre ellos
		var prev_idx := -1
		var next_idx := -1
		for i in keyframes.size():
			if keyframes[i]["frame"] <= current_frame:
				prev_idx = i
			if keyframes[i]["frame"] >= current_frame and next_idx == -1:
				next_idx = i

		if prev_idx == -1:
			prev_idx = 0
		if next_idx == -1:
			next_idx = keyframes.size() - 1

		var prev_key = keyframes[prev_idx]
		var next_key = keyframes[next_idx]

		if prev_key["frame"] == next_key["frame"]:
			obj.position = prev_key["position"]
			obj.rotation_degrees = prev_key["rotation"]
			obj.scale = prev_key["scale"]
		else:
			var t: float = float(current_frame - prev_key["frame"]) / float(next_key["frame"] - prev_key["frame"])
			t = clamp(t, 0.0, 1.0)
			var te: float = _ease(t)

			if interpolation_mode == "spline" and keyframes.size() > 2:
				var p0_idx: int = max(prev_idx - 1, 0)
				var p3_idx: int = min(next_idx + 1, keyframes.size() - 1)
				var p0: Vector3 = keyframes[p0_idx]["position"]
				var p3: Vector3 = keyframes[p3_idx]["position"]
				obj.position = _catmull_rom(p0, prev_key["position"], next_key["position"], p3, t)
			else:
				obj.position = prev_key["position"].lerp(next_key["position"], te)

			obj.quaternion = _interpolate_rotation(prev_key["rotation"], next_key["rotation"], te)
			obj.scale = prev_key["scale"].lerp(next_key["scale"], te)
		
		var light_node: Node = obj.get_node_or_null("LightSource")
		if light_node != null and light_node is Light3D and prev_key.has("energy") and next_key.has("energy"):
			var t2: float = 0.0
			if prev_key["frame"] != next_key["frame"]:
				t2 = clamp(float(current_frame - prev_key["frame"]) / float(next_key["frame"] - prev_key["frame"]), 0.0, 1.0)
			light_node.light_energy = lerp(float(prev_key["energy"]), float(next_key["energy"]), _ease(t2))
		
		
	_apply_bone_keyframes(obj)
	
		
func _on_play_pressed() -> void:
	if not _any_object_has_animation():
		return
	is_playing = true
	play_time_accum = 0.0

func _on_stop_pressed() -> void:
	is_playing = false
	current_frame = 0
	timeline_ruler.current_frame = 0
	timeline_ruler.queue_redraw()
	apply_frame_to_all_objects()
	
func _on_keyframe_delete_requested(frame: int) -> void:
	var obj: Node3D = selection_manager.selected_object
	if obj == null:
		return

	if selection_manager.ik_gizmo != null and selection_manager.ik_active_bone_idx == selection_manager.selected_bone_idx and selection_manager.selected_bone_idx != -1:
		var skeleton: Skeleton3D = selection_manager.selected_skeleton
		var tip_idx: int = selection_manager.selected_bone_idx
		var mid_idx: int = skeleton.get_bone_parent(tip_idx)
		var root_idx: int = skeleton.get_bone_parent(mid_idx) if mid_idx != -1 else -1
		var bone_keyframes: Dictionary = obj.get_meta("bone_keyframes", {})

		for b_idx in [mid_idx, root_idx]:
			if b_idx == -1:
				continue
			var track: Array = bone_keyframes.get(b_idx, [])
			for i in track.size():
				if track[i]["frame"] == frame:
					if history_manager != null:
						history_manager.push_action({
							"type": "keyframe_delete",
							"object": obj,
							"kind": "bone",
							"bone_idx": b_idx,
							"frame": frame,
							"key_data": track[i].duplicate(),
						})
					track.remove_at(i)
					break
			bone_keyframes[b_idx] = track

		obj.set_meta("bone_keyframes", bone_keyframes)
		timeline_ruler.set_keyframes(bone_keyframes.get(mid_idx, []))
		timeline_ruler.queue_redraw()
		_apply_bone_keyframes(obj)
		return

	if selection_manager.selected_bone_idx != -1 and selection_manager.selected_skeleton != null:
		var bone_idx: int = selection_manager.selected_bone_idx
		var bone_keyframes: Dictionary = obj.get_meta("bone_keyframes", {})
		var track: Array = bone_keyframes.get(bone_idx, [])
		for i in track.size():
			if track[i]["frame"] == frame:
				if history_manager != null:
					history_manager.push_action({
						"type": "keyframe_delete",
						"object": obj,
						"kind": "bone",
						"bone_idx": bone_idx,
						"frame": frame,
						"key_data": track[i].duplicate(),
					})
				track.remove_at(i)
				break
		bone_keyframes[bone_idx] = track
		obj.set_meta("bone_keyframes", bone_keyframes)
		timeline_ruler.set_keyframes(track)
		timeline_ruler.queue_redraw()
		_apply_bone_keyframes(obj)
		return

	var keyframes: Array = obj.get_meta("keyframes", [])
	for i in keyframes.size():
		if keyframes[i]["frame"] == frame:
			if history_manager != null:
				history_manager.push_action({
					"type": "keyframe_delete",
					"object": obj,
					"kind": "object",
					"bone_idx": -1,
					"frame": frame,
					"key_data": keyframes[i].duplicate(),
				})
			keyframes.remove_at(i)
			break

	obj.set_meta("keyframes", keyframes)
	timeline_ruler.set_keyframes(keyframes)
	timeline_ruler.queue_redraw()
	apply_frame_to_object(obj)

func _on_keyframe_moved(old_frame: int, new_frame: int) -> void:
	var obj: Node3D = selection_manager.selected_object
	if obj == null:
		return

	if selection_manager.ik_gizmo != null and selection_manager.ik_active_bone_idx == selection_manager.selected_bone_idx and selection_manager.selected_bone_idx != -1:
		var skeleton: Skeleton3D = selection_manager.selected_skeleton
		var tip_idx: int = selection_manager.selected_bone_idx
		var mid_idx: int = skeleton.get_bone_parent(tip_idx)
		var root_idx: int = skeleton.get_bone_parent(mid_idx) if mid_idx != -1 else -1
		var bone_keyframes: Dictionary = obj.get_meta("bone_keyframes", {})

		for b_idx in [mid_idx, root_idx]:
			if b_idx == -1:
				continue
			var track: Array = bone_keyframes.get(b_idx, [])
			var old_track: Array = track.duplicate(true)

			for i in range(track.size() - 1, -1, -1):
				if track[i]["frame"] == new_frame and track[i]["frame"] != old_frame:
					track.remove_at(i)
			for key in track:
				if key["frame"] == old_frame:
					key["frame"] = new_frame
			track.sort_custom(func(a, b): return a["frame"] < b["frame"])
			bone_keyframes[b_idx] = track

			if history_manager != null:
				history_manager.push_action({
					"type": "track_snapshot",
					"object": obj,
					"kind": "bone",
					"bone_idx": b_idx,
					"old_track": old_track,
					"new_track": track.duplicate(true),
				})

		obj.set_meta("bone_keyframes", bone_keyframes)
		timeline_ruler.set_keyframes(bone_keyframes.get(mid_idx, []))
		timeline_ruler.queue_redraw()
		_apply_bone_keyframes(obj)
		return

	if selection_manager.selected_bone_idx != -1 and selection_manager.selected_skeleton != null:
		var bone_idx: int = selection_manager.selected_bone_idx
		var bone_keyframes: Dictionary = obj.get_meta("bone_keyframes", {})
		var track: Array = bone_keyframes.get(bone_idx, [])
		var old_track: Array = track.duplicate(true)

		for i in range(track.size() - 1, -1, -1):
			if track[i]["frame"] == new_frame and track[i]["frame"] != old_frame:
				track.remove_at(i)
		for key in track:
			if key["frame"] == old_frame:
				key["frame"] = new_frame
		track.sort_custom(func(a, b): return a["frame"] < b["frame"])
		bone_keyframes[bone_idx] = track
		obj.set_meta("bone_keyframes", bone_keyframes)
		timeline_ruler.set_keyframes(track)
		timeline_ruler.queue_redraw()

		if history_manager != null:
			history_manager.push_action({
				"type": "track_snapshot",
				"object": obj,
				"kind": "bone",
				"bone_idx": bone_idx,
				"old_track": old_track,
				"new_track": track.duplicate(true),
			})
		return

	var keyframes: Array = obj.get_meta("keyframes", [])
	var old_keyframes: Array = keyframes.duplicate(true)

	for i in range(keyframes.size() - 1, -1, -1):
		if keyframes[i]["frame"] == new_frame and keyframes[i]["frame"] != old_frame:
			keyframes.remove_at(i)
	for key in keyframes:
		if key["frame"] == old_frame:
			key["frame"] = new_frame
	keyframes.sort_custom(func(a, b): return a["frame"] < b["frame"])
	obj.set_meta("keyframes", keyframes)
	timeline_ruler.set_keyframes(keyframes)
	timeline_ruler.queue_redraw()

	if history_manager != null:
		history_manager.push_action({
			"type": "track_snapshot",
			"object": obj,
			"kind": "object",
			"bone_idx": -1,
			"old_track": old_keyframes,
			"new_track": keyframes.duplicate(true),
		})
	
func apply_frame_to_all_objects() -> void:
	for obj in get_all_scene_objects():
		if obj is Node3D and (obj.has_meta("keyframes") or obj.has_meta("bone_keyframes") or obj.has_meta("ik_keyframes")):
			apply_frame_to_object(obj)

func check_selection_change() -> void:
	var current: Node3D = selection_manager.selected_object
	if current != last_selected_object:
		last_selected_object = current

		refresh_timeline_for_selection()
		refresh_media_range_for_selection()

		timeline_ruler.queue_redraw()
		
func set_frame_externally(frame: int) -> void:
	current_frame = frame
	apply_frame_to_all_objects()

func _on_video_range_dragged(new_start: int) -> void:
	if last_selected_object != null and last_selected_object.has_meta("is_video"):
		last_selected_object.set_meta("video_start_offset", new_start)
		print("Guardando offset: ", new_start, " en objeto: ", last_selected_object.name)

func get_all_scene_objects() -> Array:
	var result: Array = []
	_collect_scene_objects(spawn_root, result)
	return result

func _collect_scene_objects(node: Node, result: Array) -> void:
	for child in node.get_children():
		if child is StaticBody3D:
			result.append(child)
		_collect_scene_objects(child, result)

func _add_bone_keyframe(obj: Node3D, skeleton: Skeleton3D, bone_idx: int) -> void:
	var bone_keyframes: Dictionary = obj.get_meta("bone_keyframes", {})
	var track: Array = bone_keyframes.get(bone_idx, [])

	var existing_index := -1
	for i in track.size():
		if track[i]["frame"] == current_frame:
			existing_index = i
			break

	var old_key_data = track[existing_index].duplicate() if existing_index != -1 else null

	var new_key := {
		"frame": current_frame,
		"position": skeleton.get_bone_pose_position(bone_idx),
		"rotation": skeleton.get_bone_pose_rotation(bone_idx),
		"scale": skeleton.get_bone_pose_scale(bone_idx),
	}

	if existing_index != -1:
		track[existing_index] = new_key
	else:
		track.append(new_key)
		track.sort_custom(func(a, b): return a["frame"] < b["frame"])

	bone_keyframes[bone_idx] = track
	obj.set_meta("bone_keyframes", bone_keyframes)
	timeline_ruler.set_keyframes(track)
	timeline_ruler.queue_redraw()

	if history_manager != null:
		history_manager.push_action({
			"type": "keyframe_set",
			"object": obj,
			"kind": "bone",
			"bone_idx": bone_idx,
			"frame": current_frame,
			"old_key_data": old_key_data,
			"new_key_data": new_key.duplicate(),
		})
	
func _apply_bone_keyframes(obj: Node3D) -> void:
	if not obj.has_meta("bone_keyframes"):
		return
	var bone_keyframes: Dictionary = obj.get_meta("bone_keyframes")
	if bone_keyframes.is_empty():
		return

	var skeleton: Skeleton3D = selection_manager.find_skeleton_in(obj)
	if skeleton == null:
		return

	for bone_idx in bone_keyframes.keys():
		var track: Array = bone_keyframes[bone_idx]
		if track.is_empty():
			continue

		var prev_key = null
		var next_key = null
		for key in track:
			if key["frame"] <= current_frame:
				prev_key = key
			if key["frame"] >= current_frame and next_key == null:
				next_key = key
		if prev_key == null:
			prev_key = track[0]
		if next_key == null:
			next_key = track[track.size() - 1]

		if prev_key["frame"] == next_key["frame"]:
			skeleton.set_bone_pose_position(bone_idx, prev_key.get("position", Vector3.ZERO))
			skeleton.set_bone_pose_rotation(bone_idx, prev_key["rotation"])
			skeleton.set_bone_pose_scale(bone_idx, prev_key.get("scale", Vector3.ONE))
		else:
			var t: float = float(current_frame - prev_key["frame"]) / float(next_key["frame"] - prev_key["frame"])
			t = clamp(t, 0.0, 1.0)
			var te: float = _ease(t)
			var pos_a: Vector3 = prev_key.get("position", Vector3.ZERO)
			var pos_b: Vector3 = next_key.get("position", Vector3.ZERO)
			var scale_a: Vector3 = prev_key.get("scale", Vector3.ONE)
			var scale_b: Vector3 = next_key.get("scale", Vector3.ONE)
			skeleton.set_bone_pose_position(bone_idx, pos_a.lerp(pos_b, te))
			skeleton.set_bone_pose_rotation(bone_idx, prev_key["rotation"].slerp(next_key["rotation"], te))
			skeleton.set_bone_pose_scale(bone_idx, scale_a.lerp(scale_b, te))

	skeleton.force_update_all_bone_transforms()

func refresh_timeline_for_selection() -> void:
	_refresh_animation_ui()
	var toolbar = selection_manager.object_toolbar
	var ik_mode: bool = toolbar != null and toolbar.current_tool == toolbar.Tool.IK
	if ik_mode and selection_manager.selected_skeleton != null and selection_manager.selected_bone_idx != -1 and selection_manager.selected_object != null:
		var skeleton: Skeleton3D = selection_manager.selected_skeleton
		var mid_idx: int = skeleton.get_bone_parent(selection_manager.selected_bone_idx) if skeleton != null else -1
		var bone_keyframes: Dictionary = selection_manager.selected_object.get_meta("bone_keyframes", {})
		var track: Array = bone_keyframes.get(mid_idx, [])
		timeline_ruler.set_keyframes(track)
		timeline_ruler.queue_redraw()
		return

	if selection_manager.selected_bone_idx != -1 and selection_manager.selected_object != null:
		var bone_keyframes: Dictionary = selection_manager.selected_object.get_meta("bone_keyframes", {})
		var track: Array = bone_keyframes.get(selection_manager.selected_bone_idx, [])
		timeline_ruler.set_keyframes(track)
	elif selection_manager.selected_object != null:
		timeline_ruler.set_keyframes(selection_manager.selected_object.get_meta("keyframes", []))
	else:
		timeline_ruler.set_keyframes([])
	timeline_ruler.queue_redraw()

func refresh_media_range_for_selection() -> void:
	var current: Node3D = selection_manager.selected_object

	if current != null and current.has_meta("is_video"):
		var frames: Array = current.get_meta("video_frames")
		var start_offset: int = current.get_meta("video_start_offset", 0)
		timeline_ruler.set_video_range(start_offset, start_offset + frames.size() - 1)
		if video_loop_controls != null:
			video_loop_controls.show_for(current)
		return

	var audio_node: Node = current.get_node_or_null("AudioSource") if current != null else null
	if audio_node != null and audio_node.stream != null:
		var duration_frames: int = int(ceil(audio_node.stream.get_length() * FPS))
		timeline_ruler.set_video_range(0, max(duration_frames - 1, 0))
		if video_loop_controls != null:
			video_loop_controls.hide_controls()
		return

	timeline_ruler.clear_video_range()
	if video_loop_controls != null:
		video_loop_controls.hide_controls()

func _update_music_playback() -> void:
	for music_obj in get_all_scene_objects():
		if music_obj.has_meta("is_video"):
			continue
		var music_player: AudioStreamPlayer = music_obj.get_node_or_null("AudioSource")
		if music_player == null or music_player.stream == null:
			continue

		if is_playing and not music_player.playing:
			var seek_time: float = max(float(current_frame) / FPS, 0.0)
			if seek_time < music_player.stream.get_length():
				music_player.play(seek_time)
		elif not is_playing and music_player.playing:
			music_player.stop()

		if is_playing and current_frame == 0 and music_player.playing:
			music_player.play(0.0)


func _ease(t: float) -> float:
	if interpolation_mode == "smooth":
		return t * t * (3.0 - 2.0 * t)
	return t

func _catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * (
		(2.0 * p1) +
		(-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)

# ============================================================
# MÚLTIPLES ANIMACIONES (una lista por objeto)
# ============================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.shift_pressed and not event.ctrl_pressed and event.keycode == KEY_T:
		if animations_ui == null:
			return
		if animations_ui.visible:
			animations_ui.visible = false
		elif selection_manager.selected_object == null:
			get_tree().call_group("toast_system", "show_toast", "Selecciona primero un objeto")
		else:
			animations_ui.visible = true
			_refresh_animation_ui()

func _build_animations_panel() -> void:
	animations_ui = preload("res://escenas/animations_panel.gd").new()
	var layer: Node = get_tree().current_scene.get_node_or_null("CanvasLayer")
	if layer != null:
		layer.add_child(animations_ui)
	else:
		get_tree().current_scene.add_child(animations_ui)
	animations_ui.create_requested.connect(_on_create_animation)
	animations_ui.select_requested.connect(switch_animation)
	animations_ui.delete_requested.connect(delete_animation)
	_refresh_animation_ui()

func _any_object_has_animation() -> bool:
	for obj in get_all_scene_objects():
		if obj.get_meta("current_animation", "") != "" or _is_media_object(obj):
			return true
	return false

func _stash_animation(obj: Node, anim: String) -> void:
	var store: Dictionary = obj.get_meta("animations", {})
	store[anim] = {
		"keyframes": obj.get_meta("keyframes", []).duplicate(true),
		"bone_keyframes": obj.get_meta("bone_keyframes", {}).duplicate(true),
		"pose": _capture_pose(obj),
	}
	obj.set_meta("animations", store)

func _load_animation(obj: Node, anim: String) -> void:
	var store: Dictionary = obj.get_meta("animations", {})
	var data: Dictionary = store.get(anim, {})
	obj.set_meta("keyframes", data.get("keyframes", []).duplicate(true))
	obj.set_meta("bone_keyframes", data.get("bone_keyframes", {}).duplicate(true))
	var pose: Array = data.get("pose", [])
	if pose.is_empty():
		_reset_to_rest_pose(obj)
	else:
		_apply_pose(obj, pose)

func _switch_object_animation(obj: Node, anim: String) -> void:
	var cur: String = obj.get_meta("current_animation", "")
	if cur != "":
		_stash_animation(obj, cur)
	_load_animation(obj, anim)
	obj.set_meta("current_animation", anim)

func _on_create_animation(anim_name: String) -> void:
	var obj: Node3D = selection_manager.selected_object
	if obj == null:
		get_tree().call_group("toast_system", "show_toast", "Selecciona primero un objeto")
		return
	var names: Array = obj.get_meta("animation_names", []).duplicate()
	if names.has(anim_name):
		get_tree().call_group("toast_system", "show_toast", "Ese objeto ya tiene una animación con ese nombre")
		return

	var cur: String = obj.get_meta("current_animation", "")
	if cur != "":
		_stash_animation(obj, cur)
		obj.set_meta("keyframes", [])
		obj.set_meta("bone_keyframes", {})
	_reset_to_rest_pose(obj)

	names.append(anim_name)
	obj.set_meta("animation_names", names)
	obj.set_meta("current_animation", anim_name)
	_after_animation_change()

func switch_animation(anim_name: String) -> void:
	var obj: Node3D = selection_manager.selected_object
	if obj == null:
		return
	if anim_name == obj.get_meta("current_animation", ""):
		return
	if not obj.get_meta("animation_names", []).has(anim_name):
		return
	_switch_object_animation(obj, anim_name)
	_after_animation_change()


func delete_animation(anim_name: String) -> void:
	var obj: Node3D = selection_manager.selected_object
	if obj == null:
		return
	var names: Array = obj.get_meta("animation_names", []).duplicate()
	if not names.has(anim_name):
		return
	names.erase(anim_name)
	obj.set_meta("animation_names", names)

	var store: Dictionary = obj.get_meta("animations", {})
	store.erase(anim_name)
	obj.set_meta("animations", store)

	if obj.get_meta("current_animation", "") == anim_name:
		obj.set_meta("current_animation", "")  # así no se vuelve a guardar la borrada
		obj.set_meta("keyframes", [])
		obj.set_meta("bone_keyframes", {})
		if not names.is_empty():
			_switch_object_animation(obj, names[0])
	_after_animation_change()

func _after_animation_change() -> void:
	is_playing = false
	current_frame = 0
	timeline_ruler.current_frame = 0
	if history_manager != null:
		history_manager.clear()
	apply_frame_to_all_objects()
	refresh_timeline_for_selection()

func _refresh_animation_ui() -> void:
	if timeline_ruler == null or selection_manager == null:
		return
	var obj: Node3D = selection_manager.selected_object
	var cur: String = obj.get_meta("current_animation", "") if obj != null else ""
	timeline_ruler.locked = (cur == "") and not _is_media_object(obj)
	timeline_ruler.lock_message = "Selecciona un objeto" if obj == null else "Este objeto no tiene animación. Crea una (Shift+T)"
	timeline_ruler.queue_redraw()
	if animations_ui != null:
		animations_ui.refresh(obj.get_meta("animation_names", []) if obj != null else [], cur, obj.name if obj != null else "")

func _reset_to_rest_pose(obj: Node) -> void:
	var skeleton: Skeleton3D = selection_manager.find_skeleton_in(obj)
	if skeleton != null:
		skeleton.reset_bone_poses()
		skeleton.force_update_all_bone_transforms()

func _is_media_object(obj: Node) -> bool:
	return obj != null and (obj.has_meta("is_video") or obj.get_node_or_null("AudioSource") != null)

func _capture_pose(obj: Node) -> Array:
	var result: Array = []
	var skeleton: Skeleton3D = selection_manager.find_skeleton_in(obj)
	if skeleton == null:
		return result
	for i in skeleton.get_bone_count():
		result.append({
			"p": skeleton.get_bone_pose_position(i),
			"r": skeleton.get_bone_pose_rotation(i),
			"s": skeleton.get_bone_pose_scale(i),
		})
	return result

func _apply_pose(obj: Node, pose: Array) -> void:
	var skeleton: Skeleton3D = selection_manager.find_skeleton_in(obj)
	if skeleton == null:
		return
	for i in range(min(pose.size(), skeleton.get_bone_count())):
		skeleton.set_bone_pose_position(i, pose[i]["p"])
		skeleton.set_bone_pose_rotation(i, pose[i]["r"])
		skeleton.set_bone_pose_scale(i, pose[i]["s"])
	skeleton.force_update_all_bone_transforms()
