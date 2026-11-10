extends Control

@export var axis_name: String = "X"
@export var ring_color: Color = Color.RED
@export var selection_manager_path: NodePath

var selection_manager: Node
var dragging: bool = false
var start_angle: float = 0.0
var start_pose: Quaternion

func _ready() -> void:
	if selection_manager_path != NodePath(""):
		selection_manager = get_node(selection_manager_path)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _draw() -> void:
	var center: Vector2 = size / 2.0
	var radius: float = min(size.x, size.y) / 2.0 - 4.0
	draw_arc(center, radius, 0, TAU, 48, ring_color, 4.0, true)

func _gui_input(event: InputEvent) -> void:
	if selection_manager == null or selection_manager.selected_skeleton == null or selection_manager.selected_bone_idx == -1:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			start_angle = (event.position - size / 2.0).angle()
			start_pose = selection_manager.selected_skeleton.get_bone_pose_rotation(selection_manager.selected_bone_idx)
		else:
			if dragging and selection_manager.history_manager != null:
				var skeleton: Skeleton3D = selection_manager.selected_skeleton
				var bone_idx: int = selection_manager.selected_bone_idx
				selection_manager.history_manager.push_action({
					"type": "bone_transform",
					"skeleton": skeleton,
					"bone_idx": bone_idx,
					"old_position": skeleton.get_bone_pose_position(bone_idx),
					"old_rotation": start_pose,
					"old_scale": skeleton.get_bone_pose_scale(bone_idx),
					"new_position": skeleton.get_bone_pose_position(bone_idx),
					"new_rotation": skeleton.get_bone_pose_rotation(bone_idx),
					"new_scale": skeleton.get_bone_pose_scale(bone_idx),
				})
			dragging = false

	elif event is InputEventMouseMotion and dragging:
		var current_angle: float = (event.position - size / 2.0).angle()
		var angle_diff: float = current_angle - start_angle

		var local_axis := Vector3.ZERO
		match axis_name:
			"X": local_axis = Vector3(1, 0, 0)
			"Y": local_axis = Vector3(0, 1, 0)
			"Z": local_axis = Vector3(0, 0, 1)

		var delta_quat := Quaternion(local_axis, angle_diff)
		selection_manager.selected_skeleton.set_bone_pose_rotation(selection_manager.selected_bone_idx, start_pose * delta_quat)
		selection_manager.selected_skeleton.force_update_all_bone_transforms()
