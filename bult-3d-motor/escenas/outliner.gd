extends Panel

@export var spawn_root_path: NodePath
@export var selection_manager_path: NodePath

var spawn_root: Node3D
var selection_manager: Node3D
@onready var new_folder_button: Button = $NewFolderButton
@onready var items_list: VBoxContainer = $ScrollContainer/ItemsList
var folders: Dictionary = {}  # nombre_carpeta -> Array de objetos dentro
@onready var folder_menu: PopupMenu = $FolderMenu
var pending_move_object: Node = null
@onready var folder_action_menu: PopupMenu = $FolderActionMenu  # NUEVO nodo PopupMenu
var pending_folder_action: String = ""
var pending_part_to_delete: MeshInstance3D = null
var highlighted_part_label: Label = null
var highlighted_part: MeshInstance3D = null
var pending_bone_target_skeleton: Skeleton3D = null

func _ready() -> void:
	
	mouse_filter = Control.MOUSE_FILTER_STOP
	spawn_root = get_node(spawn_root_path)
	selection_manager = get_node(selection_manager_path)
	new_folder_button.pressed.connect(_on_new_folder_pressed)
	folder_menu.id_pressed.connect(_on_folder_menu_id_pressed)
	folder_action_menu.id_pressed.connect(_on_folder_action_menu_id_pressed)
	items_list.set_script(preload("res://scripts/outliner_drag_target.gd"))
	items_list.set_meta("outliner_ref", self)
	refresh()

func _process(_delta: float) -> void:
	highlight_selected_recursive(items_list)
		
func refresh() -> void:
	highlighted_part_label = null
	for child in items_list.get_children():
		child.queue_free()

	var objects_in_folders: Array = []
	for folder_name in folders.keys():
		objects_in_folders.append_array(folders[folder_name])

	for folder_name in folders.keys():
		add_folder_row(folder_name)

	for obj in get_all_scene_objects():
		if obj.name == "OriginGizmo":
			continue
		if obj in objects_in_folders:
			continue
		if obj.get_parent() != spawn_root:
			continue
		add_object_row_recursive(items_list, obj, 0)

func add_row(obj: Node) -> void:
	items_list.add_child(create_row_for(obj))

func create_row_for(obj: Node, depth: int = 0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.set_meta("target_obj", obj)

	var visibility_button := Button.new()
	visibility_button.text = "👁"
	visibility_button.custom_minimum_size = Vector2(24, 24)
	visibility_button.flat = true
	visibility_button.pressed.connect(func():
		if not is_instance_valid(obj):
			return
		obj.visible = not obj.visible
		visibility_button.modulate = Color(1, 1, 1) if obj.visible else Color(0.4, 0.4, 0.4)
	)
	row.add_child(visibility_button)

	var label := Label.new()
	label.name = "NameLabel"
	label.text = ("↳ ".repeat(depth)) + ("🚫 " if obj.get_meta("collision_disabled", false) else "") + obj.name
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.gui_input.connect(_on_label_gui_input.bind(label, obj))

	if obj is StaticBody3D:
		label.set_script(preload("res://scripts/outliner_drag_target.gd"))
		label.set_meta("target_obj", obj)
		label.set_meta("outliner_ref", self)

	row.add_child(label)

	
	return row

func _on_label_gui_input(event: InputEvent, label: Label, obj: Node) -> void:
	if not is_instance_valid(obj):
		return
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.double_click:
				start_rename(label, obj)
			elif obj is StaticBody3D:
				selection_manager.select_object(obj)
			elif obj is MeshInstance3D:
				highlight_part_label(label, obj)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if obj is StaticBody3D:
				selection_manager.select_object(obj)
			open_object_context_menu(event.global_position, obj)

func start_rename(label: Label, obj: Node) -> void:
	var line_edit := LineEdit.new()
	line_edit.text = obj.name
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var parent := label.get_parent()
	var idx := label.get_index()
	parent.remove_child(label)
	parent.add_child(line_edit)
	parent.move_child(line_edit, idx)
	line_edit.grab_focus()
	line_edit.select_all()

	line_edit.text_submitted.connect(func(new_text): finish_rename(line_edit, label, obj, new_text))
	line_edit.focus_exited.connect(func(): finish_rename(line_edit, label, obj, line_edit.text))

func finish_rename(line_edit: LineEdit, label: Label, obj: Node, new_text: String) -> void:
	if not is_instance_valid(line_edit):
		return
	if line_edit.has_meta("finishing"):
		return
	line_edit.set_meta("finishing", true)

	var old_name: String = obj.name
	var prefix: String = label.text
	if prefix.ends_with(old_name):
		prefix = prefix.substr(0, prefix.length() - old_name.length())
	else:
		prefix = ""

	if new_text.strip_edges() != "":
		obj.name = new_text.strip_edges()
	label.text = prefix + obj.name

	call_deferred("_finish_rename_deferred", line_edit, label)

func _finish_rename_deferred(line_edit: Node, label: Label) -> void:
	if not is_instance_valid(line_edit):
		return
	var parent := line_edit.get_parent()
	if parent == null:
		return
	var idx := line_edit.get_index()
	parent.remove_child(line_edit)
	parent.add_child(label)
	parent.move_child(label, idx)
	line_edit.queue_free()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		accept_event()

func _on_new_folder_pressed() -> void:
	var folder_name := "Carpeta_%d" % folders.size()
	folders[folder_name] = []
	refresh()

func add_folder_row(folder_name: String) -> void:
	var folder_container := VBoxContainer.new()
	var header := HBoxContainer.new()

	var visibility_button := Button.new()
	visibility_button.text = "👁"
	visibility_button.custom_minimum_size = Vector2(24, 24)
	visibility_button.flat = true

	var any_visible: bool = false
	for obj in folders[folder_name]:
		if is_instance_valid(obj) and obj.visible:
			any_visible = true
			break
	visibility_button.modulate = Color(1, 1, 1) if any_visible else Color(0.4, 0.4, 0.4)

	visibility_button.pressed.connect(func():
		var all_visible: bool = true
		for obj in folders[folder_name]:
			if is_instance_valid(obj):
				all_visible = all_visible and obj.visible
		for obj in folders[folder_name]:
			if is_instance_valid(obj):
				obj.visible = not all_visible
		refresh()
	)
	header.add_child(visibility_button)

	var expand_button := Button.new()
	expand_button.text = "▼"
	expand_button.custom_minimum_size = Vector2(24, 24)
	expand_button.flat = true
	header.add_child(expand_button)

	var folder_label := Label.new()
	folder_label.text = "📁 " + folder_name
	folder_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	folder_label.mouse_filter = Control.MOUSE_FILTER_STOP
	folder_label.set_script(preload("res://scripts/outliner_drag_target.gd"))
	folder_label.set_meta("folder_target", folder_name)
	folder_label.set_meta("outliner_ref", self)
	header.add_child(folder_label)

	folder_label.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.double_click:
			start_folder_rename(folder_label, folder_name)
	)

	folder_container.add_child(header)

	var contents := VBoxContainer.new()
	contents.name = "Contents"
	for obj in folders[folder_name]:
		if is_instance_valid(obj):
			add_object_row_recursive(contents, obj, 0)
	folder_container.add_child(contents)

	expand_button.pressed.connect(func():
		contents.visible = not contents.visible
		expand_button.text = "▼" if contents.visible else "▶"
	)

	folder_label.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				select_all_in_folder(folder_name)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				open_folder_context_menu(event.global_position, folder_name)
	)

	items_list.add_child(folder_container)

func select_all_in_folder(folder_name: String) -> void:
	for obj in folders[folder_name]:
		if is_instance_valid(obj) and obj is StaticBody3D:
			selection_manager.select_object(obj)
			break

func open_object_context_menu(pos: Vector2, obj: Node) -> void:
	if obj is MeshInstance3D:
		open_part_context_menu(pos, obj)
		return

	pending_move_object = obj

	folder_menu.clear()
	folder_menu.add_item("Eliminar", 1000)

	if obj is StaticBody3D:
		if obj.get_meta("collision_disabled", false):
			folder_menu.add_item("Activar colisión (se puede clicar)", 7000)
		else:
			folder_menu.add_item("Desactivar colisión (para mapas)", 7001)

	if obj is StaticBody3D and obj.get_node_or_null("Mesh") is MeshInstance3D and not obj.has_meta("is_imported_model") and not obj.has_meta("is_video") and obj.get_node_or_null("LightSource") == null and obj.get_node_or_null("CameraSource") == null and obj.get_node_or_null("AudioSource") == null:
		if obj.get_meta("double_sided", false):
			folder_menu.add_item("Quitar vista por dentro", 7003)
		else:
			folder_menu.add_item("Ver por dentro (doble cara)", 7002)
		if obj.get_meta("unshaded", false):
			folder_menu.add_item("Volver a iluminar", 7005)
		else:
			folder_menu.add_item("Sin iluminación (cielo/fondo)", 7004)

	if obj.has_meta("is_model_part_object"):
		folder_menu.add_item("Volver a ser parte del modelo", 1500)

	var current_folder: String = find_folder_of(obj)
	var is_child: bool = obj.get_parent() != spawn_root

	if current_folder != "" and not is_child:
		folder_menu.add_item("Sacar de \"%s\"" % current_folder, 1001)

	if is_child:
		folder_menu.add_item("Sacar de su padre", 2000)

	if not is_child:
		var other_folders: Array = []
		for folder_name in folders.keys():
			if folder_name != current_folder:
				other_folders.append(folder_name)

		if not other_folders.is_empty():
			folder_menu.add_separator("Mover a carpeta")
			var idx: int = 0
			for folder_name in other_folders:
				folder_menu.add_item(folder_name, idx)
				idx += 1

	var possible_parents: Array = []
	for other in get_all_scene_objects():
		if other == obj:
			continue
		if is_descendant_of(other, obj):
			continue
		possible_parents.append(other)

	if not possible_parents.is_empty():
		folder_menu.add_separator("Convertir en hijo de")
		var pidx: int = 0
		for other in possible_parents:
			folder_menu.add_item(other.name, 3000 + pidx)
			pidx += 1
	pending_bone_target_skeleton = null
	if selection_manager != null:
		var skeleton: Skeleton3D = selection_manager.find_skeleton_in(spawn_root)
		if skeleton != null:
			folder_menu.add_separator("Adjuntar a hueso")
			for i in skeleton.get_bone_count():
				folder_menu.add_item(skeleton.get_bone_name(i), 4000 + i)
			pending_bone_target_skeleton = skeleton

	var has_anim: bool = (obj.has_meta("keyframes") and not obj.get_meta("keyframes").is_empty()) or (obj.has_meta("bone_keyframes") and not obj.get_meta("bone_keyframes").is_empty())
	if has_anim:
		folder_menu.add_item("Duplicar con animación", 6000)
		folder_menu.add_item("Duplicar sin animación", 6001)
	else:
		folder_menu.add_item("Duplicar", 6002)
	folder_menu.position = Vector2i(pos)
	folder_menu.popup()

func open_part_context_menu(pos: Vector2, part: MeshInstance3D) -> void:
	pending_part_to_delete = part
	folder_menu.clear()
	folder_menu.add_item("Eliminar esta parte", 5000)
	folder_menu.add_item("Convertir en objeto independiente", 5001)
	folder_menu.position = Vector2i(pos)
	folder_menu.popup()

func _on_folder_menu_id_pressed(id: int) -> void:
	if id == 5000:
		if pending_part_to_delete != null and selection_manager != null:
			selection_manager.delete_model_part(pending_part_to_delete)
		return
	if id == 5001:
		if pending_part_to_delete != null and selection_manager != null:
			selection_manager.promote_model_part(pending_part_to_delete)
		return
	
		
	if id == 1000:
		if pending_move_object != null:
			selection_manager.delete_object_completely(pending_move_object)
		return
		
	if id == 7000 or id == 7001:
		if selection_manager != null and pending_move_object != null:
			selection_manager.set_object_collision_enabled(pending_move_object, id == 7000)
		return
		
	if id >= 7002 and id <= 7005:
		if selection_manager != null and pending_move_object != null:
			var flag: String = "double_sided" if id <= 7003 else "unshaded"
			selection_manager.set_object_surface_flag(pending_move_object, flag, id == 7002 or id == 7004)
		return
	
	if id == 1500:
		if selection_manager != null:
			selection_manager.revert_promoted_part(pending_move_object)
		return
	if id == 1001:
		var current_folder: String = find_folder_of(pending_move_object)
		if current_folder != "":
			folders[current_folder].erase(pending_move_object)
			if is_instance_valid(pending_move_object):
				pending_move_object.visible = true
			refresh()
		return

	if id == 2000:
		if pending_move_object != null:
			reparent_object(pending_move_object, spawn_root)
		return

	if id >= 3000 and id < 4000:
		var possible_parents: Array = []
		for other in get_all_scene_objects():
			if other == pending_move_object:
				continue
			if is_descendant_of(other, pending_move_object):
				continue
			possible_parents.append(other)
		var pidx: int = id - 3000
		if pidx >= 0 and pidx < possible_parents.size():
			reparent_object(pending_move_object, possible_parents[pidx])
		return
	if id >= 4000 and id < 5000:
		if pending_bone_target_skeleton != null and pending_move_object != null and selection_manager != null:
			var bone_idx: int = id - 4000
			selection_manager.attach_object_to_bone(pending_move_object, pending_bone_target_skeleton, bone_idx)
		return
	if id == 6000 or id == 6001 or id == 6002:
		if selection_manager != null and pending_move_object != null:
			var with_anim: bool = id == 6000
			selection_manager.duplicate_object(pending_move_object, with_anim)
		return
		
	var current_folder_check: String = find_folder_of(pending_move_object)
	var other_folders: Array = []
	for folder_name in folders.keys():
		if folder_name != current_folder_check:
			other_folders.append(folder_name)

	if id >= 0 and id < other_folders.size():
		var folder_name: String = other_folders[id]
		move_object_to_folder(pending_move_object, folder_name)

func find_folder_of(obj: Node) -> String:
	for folder_name in folders.keys():
		if obj in folders[folder_name]:
			return folder_name
	return ""

func highlight_selected_recursive(container: Node) -> void:
	for child in container.get_children():
		if child is HBoxContainer and child.has_meta("target_obj"):
			var obj = child.get_meta("target_obj")
			var label: Label = child.get_node_or_null("NameLabel")
			if label != null and obj != null:
				if selection_manager.selected_object == obj:
					label.add_theme_color_override("font_color", Color.YELLOW)
				else:
					label.remove_theme_color_override("font_color")
		else:
			highlight_selected_recursive(child)

func _on_folder_action_menu_id_pressed(id: int) -> void:
	if pending_folder_action == "":
		return
	if id == 2000:
		folders.erase(pending_folder_action)
		refresh()
	elif id == 2001:
		for obj in folders[pending_folder_action]:
			if is_instance_valid(obj):
				selection_manager.delete_object_completely(obj)
		folders.erase(pending_folder_action)
		refresh()

func open_folder_context_menu(pos: Vector2, folder_name: String) -> void:
	pending_folder_action = folder_name
	folder_action_menu.clear()
	folder_action_menu.add_item("Eliminar carpeta (mantiene objetos)", 2000)
	folder_action_menu.add_item("Eliminar carpeta y objetos dentro", 2001)
	folder_action_menu.position = Vector2i(pos)
	folder_action_menu.popup()

func get_all_scene_objects() -> Array:
	var result: Array = []
	_collect_scene_objects(spawn_root, result)
	return result

func _collect_scene_objects(node: Node, result: Array) -> void:
	for child in node.get_children():
		if child is StaticBody3D:
			result.append(child)
		_collect_scene_objects(child, result)

func is_descendant_of(node: Node, potential_ancestor: Node) -> bool:
	var p: Node = node.get_parent()
	while p != null:
		if p == potential_ancestor:
			return true
		p = p.get_parent()
	return false

func reparent_object(obj: Node3D, new_parent: Node3D) -> void:
	if obj == null or new_parent == null or obj == new_parent:
		return
	if is_descendant_of(new_parent, obj):
		get_tree().call_group("toast_system", "show_toast", "No se puede: crearía un ciclo")
		return
	obj.reparent(new_parent, true)
	refresh()

func start_folder_rename(label: Label, folder_name: String) -> void:
	var line_edit := LineEdit.new()
	line_edit.text = folder_name
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.get_parent().add_child(line_edit)
	label.get_parent().move_child(line_edit, label.get_index())
	label.visible = false
	line_edit.grab_focus()
	line_edit.select_all()

	line_edit.text_submitted.connect(func(new_text: String):
		finish_folder_rename(line_edit, label, folder_name, new_text)
	)
	line_edit.focus_exited.connect(func():
		finish_folder_rename(line_edit, label, folder_name, line_edit.text)
	)

func finish_folder_rename(line_edit: LineEdit, label: Label, old_name: String, new_text: String) -> void:
	if new_text.strip_edges() != "" and new_text != old_name and not folders.has(new_text):
		folders[new_text] = folders[old_name]
		folders.erase(old_name)
		refresh()
	else:
		label.visible = true
		line_edit.queue_free()

func add_object_row_recursive(container: Node, obj: Node, depth: int) -> void:
	var has_parts: bool = obj is StaticBody3D and obj.has_meta("is_imported_model")

	if has_parts:
		var wrapper := VBoxContainer.new()
		var row := create_row_for(obj, depth)

		var expand_button := Button.new()
		expand_button.text = "▼"
		expand_button.custom_minimum_size = Vector2(24, 24)
		expand_button.flat = true
		row.add_child(expand_button)
		row.move_child(expand_button, 1)

		wrapper.add_child(row)

		var parts_container := VBoxContainer.new()
		parts_container.name = "Parts"
		parts_container.visible = false
		var model_root: Node = obj.get_node_or_null("ImportedModel")
		if model_root != null:
			_add_model_part_rows(parts_container, model_root, depth + 1)
		wrapper.add_child(parts_container)
		expand_button.text = "▶"

		expand_button.pressed.connect(func():
			parts_container.visible = not parts_container.visible
			expand_button.text = "▼" if parts_container.visible else "▶"
		)

		container.add_child(wrapper)
	else:
		container.add_child(create_row_for(obj, depth))

	for child in obj.get_children():
		if child is StaticBody3D:
			add_object_row_recursive(container, child, depth + 1)

func _add_model_part_rows(container: Node, node: Node, depth: int) -> void:
	for child in node.get_children():
		if child is StaticBody3D:
			container.add_child(create_row_for(child, depth))
			_add_model_part_rows(container, child, depth + 1)
		elif child is BoneAttachment3D:
			var bone_row := HBoxContainer.new()
			var bone_label := Label.new()
			bone_label.text = ("↳ ".repeat(depth)) + "🦴 " + child.bone_name
			bone_row.add_child(bone_label)

			if child.get_child_count() == 0:
				var delete_btn := Button.new()
				delete_btn.text = "🗑"
				delete_btn.flat = true
				delete_btn.custom_minimum_size = Vector2(24, 24)
				var bone_ref: BoneAttachment3D = child
				delete_btn.pressed.connect(func():
					if is_instance_valid(bone_ref):
						bone_ref.queue_free()
						refresh()
				)
				bone_row.add_child(delete_btn)

			container.add_child(bone_row)
			_add_model_part_rows(container, child, depth + 1)
		elif child is MeshInstance3D and not child.has_meta("is_promoted_owner_mesh"):
			container.add_child(create_row_for(child, depth))
		else:
			_add_model_part_rows(container, child, depth)

func move_object_to_folder(obj: Node, folder_name: String) -> void:
	var current: String = find_folder_of(obj)
	if current != "":
		folders[current].erase(obj)
	if folder_name != "":
		folders[folder_name].append(obj)
	refresh()

func highlight_part_label(label: Label, part: MeshInstance3D) -> void:
	if highlighted_part_label != null and is_instance_valid(highlighted_part_label):
		highlighted_part_label.modulate = Color.WHITE
	label.modulate = Color.YELLOW
	highlighted_part_label = label
	highlighted_part = part
