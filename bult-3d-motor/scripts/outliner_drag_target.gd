extends Control

func _get_drag_data(_at_position: Vector2) -> Variant:
	var obj: Node = get_meta("target_obj", null)
	if obj == null or not is_instance_valid(obj):
		return null

	var preview := Label.new()
	preview.text = "📦 " + obj.name
	set_drag_preview(preview)

	return {"outliner_drag_object": obj}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not data.has("outliner_drag_object"):
		return false
	var dragged: Node = data["outliner_drag_object"]
	var outliner: Node = get_meta("outliner_ref", null)
	if dragged == null or outliner == null:
		return false

	var folder_target: String = get_meta("folder_target", "")
	if folder_target != "":
		return dragged.get_parent() == outliner.spawn_root

	var target: Node = get_meta("target_obj", outliner.spawn_root)
	if dragged == target:
		return false
	if outliner.is_descendant_of(target, dragged):
		return false
	return true

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var dragged: Node = data["outliner_drag_object"]
	var outliner: Node = get_meta("outliner_ref", null)
	if outliner == null:
		return

	var folder_target: String = get_meta("folder_target", "")
	if folder_target != "":
		outliner.move_object_to_folder(dragged, folder_target)
		return

	var target: Node = get_meta("target_obj", outliner.spawn_root)
	outliner.reparent_object(dragged, target)
