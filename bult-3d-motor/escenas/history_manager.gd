extends Node

@export var outliner_path: NodePath
var outliner_ref: Node
# Cada acción es un Dictionary con "type" y los datos necesarios para deshacer/rehacer
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []

@export var animation_manager_path: NodePath
var animation_manager_ref: Node
@export var selection_manager_path: NodePath
var selection_manager_ref: Node

func _ready() -> void:
	if outliner_path != NodePath(""):
		outliner_ref = get_node(outliner_path)
	if animation_manager_path != NodePath(""):
		animation_manager_ref = get_node(animation_manager_path)
	if selection_manager_path != NodePath(""):
		selection_manager_ref = get_node(selection_manager_path)


func undo() -> void:
	if undo_stack.is_empty():
		return
	var action: Dictionary = undo_stack.pop_back()
	apply_reverse(action)
	redo_stack.append(action)

func redo() -> void:
	if redo_stack.is_empty():
		return
	var action: Dictionary = redo_stack.pop_back()
	apply_forward(action)
	undo_stack.append(action)

func apply_reverse(action: Dictionary) -> void:
	match action["type"]:
		"transform":
			var obj = action["object"]
			if is_instance_valid(obj):
				obj.position = action["old_position"]
				obj.rotation_degrees = action["old_rotation"]
				obj.scale = action["old_scale"]
		"bone_transform":
			var skeleton = action["skeleton"]
			var bone_idx: int = action["bone_idx"]
			if is_instance_valid(skeleton):
				skeleton.set_bone_pose_position(bone_idx, action["old_position"])
				skeleton.set_bone_pose_rotation(bone_idx, action["old_rotation"])
				skeleton.set_bone_pose_scale(bone_idx, action["old_scale"])
				skeleton.force_update_all_bone_transforms()
		"create":
			var obj = action["object"]
			if is_instance_valid(obj) and obj.get_parent() != null:
				obj.get_parent().remove_child(obj)
		"delete":
			var obj = action["object"]
			var parent = action["parent"]
			if is_instance_valid(obj) and is_instance_valid(parent):
				parent.add_child(obj)
		"part_removal":
			var part = action["part"]
			var parent = action["parent"]
			if is_instance_valid(part) and is_instance_valid(parent) and part.get_parent() == null:
				parent.add_child(part)
				parent.move_child(part, action["index"])
			if outliner_ref != null:
				outliner_ref.refresh()
		"keyframe_delete":
			var obj = action["object"]
			if not is_instance_valid(obj):
				return
			match action["kind"]:
				"object":
					var keyframes: Array = obj.get_meta("keyframes", [])
					keyframes.append(action["key_data"])
					keyframes.sort_custom(func(a, b): return a["frame"] < b["frame"])
					obj.set_meta("keyframes", keyframes)
				"bone":
					var bone_keyframes: Dictionary = obj.get_meta("bone_keyframes", {})
					var track: Array = bone_keyframes.get(action["bone_idx"], [])
					track.append(action["key_data"])
					track.sort_custom(func(a, b): return a["frame"] < b["frame"])
					bone_keyframes[action["bone_idx"]] = track
					obj.set_meta("bone_keyframes", bone_keyframes)
				"ik":
					var ik_keyframes: Dictionary = obj.get_meta("ik_keyframes", {})
					var ik_track: Array = ik_keyframes.get(action["bone_idx"], [])
					ik_track.append(action["key_data"])
					ik_track.sort_custom(func(a, b): return a["frame"] < b["frame"])
					ik_keyframes[action["bone_idx"]] = ik_track
					obj.set_meta("ik_keyframes", ik_keyframes)
			if animation_manager_ref != null:
				animation_manager_ref.apply_frame_to_object(obj)
				animation_manager_ref.refresh_timeline_for_selection()
		"keyframe_set":
			var obj = action["object"]
			if not is_instance_valid(obj):
				return
			var frame: int = action["frame"]
			match action["kind"]:
				"object":
					var keyframes: Array = obj.get_meta("keyframes", [])
					var idx := -1
					for i in keyframes.size():
						if keyframes[i]["frame"] == frame:
							idx = i
							break
					if action["old_key_data"] == null:
						if idx != -1:
							keyframes.remove_at(idx)
					elif idx != -1:
						keyframes[idx] = action["old_key_data"]
					obj.set_meta("keyframes", keyframes)
				"bone":
					var bone_keyframes: Dictionary = obj.get_meta("bone_keyframes", {})
					var track: Array = bone_keyframes.get(action["bone_idx"], [])
					var idx := -1
					for i in track.size():
						if track[i]["frame"] == frame:
							idx = i
							break
					if action["old_key_data"] == null:
						if idx != -1:
							track.remove_at(idx)
					elif idx != -1:
						track[idx] = action["old_key_data"]
					bone_keyframes[action["bone_idx"]] = track
					obj.set_meta("bone_keyframes", bone_keyframes)
			if animation_manager_ref != null:
				animation_manager_ref.apply_frame_to_object(obj)
				animation_manager_ref.refresh_timeline_for_selection()
		
		"track_snapshot":
			var obj = action["object"]
			if not is_instance_valid(obj):
				return
			match action["kind"]:
				"object":
					obj.set_meta("keyframes", action["old_track"].duplicate(true))
				"bone":
					var bone_keyframes: Dictionary = obj.get_meta("bone_keyframes", {})
					bone_keyframes[action["bone_idx"]] = action["old_track"].duplicate(true)
					obj.set_meta("bone_keyframes", bone_keyframes)
			if animation_manager_ref != null:
				animation_manager_ref.apply_frame_to_object(obj)
				animation_manager_ref.refresh_timeline_for_selection()
				
func apply_forward(action: Dictionary) -> void:
	match action["type"]:
		"transform":
			var obj = action["object"]
			if is_instance_valid(obj):
				obj.position = action["new_position"]
				obj.rotation_degrees = action["new_rotation"]
				obj.scale = action["new_scale"]
		"bone_transform":
			var skeleton = action["skeleton"]
			var bone_idx: int = action["bone_idx"]
			if is_instance_valid(skeleton):
				skeleton.set_bone_pose_position(bone_idx, action["new_position"])
				skeleton.set_bone_pose_rotation(bone_idx, action["new_rotation"])
				skeleton.set_bone_pose_scale(bone_idx, action["new_scale"])
				skeleton.force_update_all_bone_transforms()
		"create":
			var obj = action["object"]
			var parent = action["parent"]
			if is_instance_valid(obj) and is_instance_valid(parent):
				parent.add_child(obj)
		"delete":
			var obj = action["object"]
			if is_instance_valid(obj) and obj.get_parent() != null:
				obj.get_parent().remove_child(obj)
		"part_removal":
			var part = action["part"]
			if is_instance_valid(part) and part.get_parent() != null:
				part.get_parent().remove_child(part)
			if outliner_ref != null:
				outliner_ref.refresh()
				
		"keyframe_delete":
			var obj = action["object"]
			if not is_instance_valid(obj):
				return
			var frame: int = action["frame"]
			match action["kind"]:
				"object":
					var keyframes: Array = obj.get_meta("keyframes", [])
					for i in keyframes.size():
						if keyframes[i]["frame"] == frame:
							keyframes.remove_at(i)
							break
					obj.set_meta("keyframes", keyframes)
				"bone":
					var bone_keyframes: Dictionary = obj.get_meta("bone_keyframes", {})
					var track: Array = bone_keyframes.get(action["bone_idx"], [])
					for i in track.size():
						if track[i]["frame"] == frame:
							track.remove_at(i)
							break
					bone_keyframes[action["bone_idx"]] = track
					obj.set_meta("bone_keyframes", bone_keyframes)
				"ik":
					var ik_keyframes: Dictionary = obj.get_meta("ik_keyframes", {})
					var ik_track: Array = ik_keyframes.get(action["bone_idx"], [])
					for i in ik_track.size():
						if ik_track[i]["frame"] == frame:
							ik_track.remove_at(i)
							break
					ik_keyframes[action["bone_idx"]] = ik_track
					obj.set_meta("ik_keyframes", ik_keyframes)
			if animation_manager_ref != null:
				animation_manager_ref.apply_frame_to_object(obj)
				animation_manager_ref.refresh_timeline_for_selection()
		"keyframe_set":
			var obj = action["object"]
			if not is_instance_valid(obj):
				return
			var frame: int = action["frame"]
			match action["kind"]:
				"object":
					var keyframes: Array = obj.get_meta("keyframes", [])
					var idx := -1
					for i in keyframes.size():
						if keyframes[i]["frame"] == frame:
							idx = i
							break
					if idx != -1:
						keyframes[idx] = action["new_key_data"]
					else:
						keyframes.append(action["new_key_data"])
						keyframes.sort_custom(func(a, b): return a["frame"] < b["frame"])
					obj.set_meta("keyframes", keyframes)
				"bone":
					var bone_keyframes: Dictionary = obj.get_meta("bone_keyframes", {})
					var track: Array = bone_keyframes.get(action["bone_idx"], [])
					var idx := -1
					for i in track.size():
						if track[i]["frame"] == frame:
							idx = i
							break
					if idx != -1:
						track[idx] = action["new_key_data"]
					else:
						track.append(action["new_key_data"])
						track.sort_custom(func(a, b): return a["frame"] < b["frame"])
					bone_keyframes[action["bone_idx"]] = track
					obj.set_meta("bone_keyframes", bone_keyframes)
			if animation_manager_ref != null:
				animation_manager_ref.apply_frame_to_object(obj)
				animation_manager_ref.refresh_timeline_for_selection()
		
		"track_snapshot":
			var obj = action["object"]
			if not is_instance_valid(obj):
				return
			match action["kind"]:
				"object":
					obj.set_meta("keyframes", action["new_track"].duplicate(true))
				"bone":
					var bone_keyframes: Dictionary = obj.get_meta("bone_keyframes", {})
					bone_keyframes[action["bone_idx"]] = action["new_track"].duplicate(true)
					obj.set_meta("bone_keyframes", bone_keyframes)
			if animation_manager_ref != null:
				animation_manager_ref.apply_frame_to_object(obj)
				animation_manager_ref.refresh_timeline_for_selection()

func push_action(action: Dictionary) -> void:
	undo_stack.append(action)
	redo_stack.clear()  # cualquier acción nueva invalida el "rehacer" pendiente

func clear() -> void:
	undo_stack.clear()
	redo_stack.clear()
