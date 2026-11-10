extends Panel
signal material_apply_requested(data: Dictionary)
@export var context_menu_path: NodePath
var context_menu: Panel

@onready var materials_list: HBoxContainer = $ScrollContainer/MaterialsList

var materials: Array = []  # cada entrada: {"color": Color, "texture": Texture2D o null}
var texture_library: Array = []  # cada entrada: {"path": String, "texture": Texture2D}

@export var texture_library_panel_path: NodePath
var texture_library_panel: Node
var current_model_groups: Dictionary = {}
var model_swatch_nodes: Array = []

func _ready() -> void:
	if context_menu != null:
		context_menu.delete_requested.connect(remove_material)
	if context_menu_path != NodePath(""):
		context_menu = get_node(context_menu_path)
	add_new_material_button()
	if texture_library_panel_path != NodePath(""):
		texture_library_panel = get_node(texture_library_panel_path)
func add_new_material_button() -> void:
	var btn := Button.new()
	btn.text = "+"
	btn.custom_minimum_size = Vector2(48, 48)
	btn.pressed.connect(_on_add_material_pressed)
	materials_list.add_child(btn)

func _on_add_material_pressed() -> void:
	_add_material_swatch({"color": Color.WHITE, "texture": null})

func _add_material_swatch(data: Dictionary) -> void:
	materials.append(data)

	var sphere_button := TextureButton.new()
	sphere_button.custom_minimum_size = Vector2(48, 48)
	sphere_button.ignore_texture_size = true
	sphere_button.stretch_mode = TextureButton.STRETCH_SCALE
	sphere_button.set_meta("material_data", data)
	update_sphere_visual(sphere_button, data)
	sphere_button.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				if context_menu != null:
					context_menu.open_for(sphere_button, data)
			elif event.button_index == MOUSE_BUTTON_LEFT:
				material_apply_requested.emit(data)
	)
	# Insertamos antes del botón "+" (que siempre queda al final)
	var plus_button: Node = materials_list.get_child(materials_list.get_child_count() - 1)
	materials_list.add_child(sphere_button)
	materials_list.move_child(sphere_button, plus_button.get_index())

func update_sphere_visual(button: TextureButton, data: Dictionary) -> void:
	if data["texture"] != null:
		button.texture_normal = data["texture"]
	else:
		# Generamos una textura sólida simple del color elegido
		var img := Image.create(48, 48, false, Image.FORMAT_RGB8)
		img.fill(data["color"])
		button.texture_normal = ImageTexture.create_from_image(img)
		
func remove_material(button: TextureButton) -> void:
	var data = button.get_meta("material_data")
	materials.erase(data)
	button.queue_free()

func clear_model_swatches() -> void:
	for node in model_swatch_nodes:
		if is_instance_valid(node):
			node.queue_free()
	model_swatch_nodes.clear()
	current_model_groups = {}

func show_model_swatches(model_root: Node) -> void:
	clear_model_swatches()

	var groups: Dictionary = {}
	_collect_model_materials(model_root, groups)
	current_model_groups = groups

	for material in groups.keys():
		var locations: Array = groups[material]
		var swatch := TextureButton.new()
		swatch.custom_minimum_size = Vector2(48, 48)
		swatch.ignore_texture_size = true
		swatch.stretch_mode = TextureButton.STRETCH_SCALE
		swatch.texture_normal = _preview_for_material(material)
		swatch.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_LEFT:
					_on_model_swatch_pressed(material, locations, swatch)
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					var combined: Array = []
					var seen: Array = []
					for entry in _get_model_own_textures() + texture_library:
						if entry["texture"] in seen:
							continue
						seen.append(entry["texture"])
						combined.append(entry)
					if not combined.is_empty() and texture_library_panel != null:
						texture_library_panel.open_for(locations, combined, swatch)
		)
		var plus_button: Node = materials_list.get_child(materials_list.get_child_count() - 1)
		materials_list.add_child(swatch)
		materials_list.move_child(swatch, plus_button.get_index())
		model_swatch_nodes.append(swatch)

func _collect_model_materials(node: Node, groups: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for i in node.mesh.get_surface_count():
			var mat: Material = node.get_surface_override_material(i)
			if mat == null:
				mat = node.mesh.surface_get_material(i)
			if mat != null:
				if not groups.has(mat):
					groups[mat] = []
				groups[mat].append({"mesh": node, "surface": i})
	for child in node.get_children():
		_collect_model_materials(child, groups)

func _preview_for_material(material: Material) -> Texture2D:
	if material is BaseMaterial3D and material.albedo_texture != null:
		return material.albedo_texture
	var img := Image.create(48, 48, false, Image.FORMAT_RGB8)
	var color: Color = material.albedo_color if material is BaseMaterial3D else Color.WHITE
	img.fill(color)
	return ImageTexture.create_from_image(img)

func _on_model_swatch_pressed(material: Material, locations: Array, swatch: TextureButton) -> void:
	var path: String = pick_texture_file_native()
	if path == "":
		return
	var img := Image.new()
	if img.load(path) != OK:
		return
	var tex := ImageTexture.create_from_image(img)
	register_texture_in_library(path, tex)

	var new_mat: StandardMaterial3D
	if material is StandardMaterial3D:
		new_mat = material.duplicate()
	else:
		new_mat = StandardMaterial3D.new()
	new_mat.albedo_texture = tex
	AlphaHelper.fix(new_mat)   # <-- nueva

	for loc in locations:
		loc["mesh"].set_surface_override_material(loc["surface"], new_mat)

	swatch.texture_normal = tex

func pick_texture_file_native() -> String:
	var output: Array = []
	var script := 'Add-Type -AssemblyName System.Windows.Forms; $dialog = New-Object System.Windows.Forms.OpenFileDialog; $dialog.Filter = \'Imagenes (*.png;*.jpg;*.jpeg)|*.png;*.jpg;*.jpeg\'; if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Write-Output $dialog.FileName }'
	OS.execute("powershell", ["-NoProfile", "-Command", script], output, true)
	if output.size() > 0:
		return output[0].strip_edges()
	return ""

func register_texture_in_library(path: String, tex: Texture2D) -> void:
	for entry in texture_library:
		if entry["path"] == path:
			return
	texture_library.append({"path": path, "texture": tex})

func _get_model_own_textures() -> Array:
	var result: Array = []
	for material in current_model_groups.keys():
		if material is BaseMaterial3D and material.albedo_texture != null:
			result.append({"texture": material.albedo_texture})
	return result

func _tex_to_b64(tex: Texture2D) -> Variant:
	if tex == null:
		return null
	var img: Image = tex.get_image()
	if img == null:
		return null
	return Marshalls.raw_to_base64(img.save_png_to_buffer())

func _b64_to_tex(b64) -> Texture2D:
	if b64 == null or b64 == "":
		return null
	var img := Image.new()
	if img.load_png_from_buffer(Marshalls.base64_to_raw(b64)) != OK:
		return null
	return ImageTexture.create_from_image(img)

func serialize_palette() -> Dictionary:
	var mats: Array = []
	for m in materials:
		var c: Color = m["color"]
		mats.append({
			"color": [c.r, c.g, c.b, c.a],
			"roughness": m.get("roughness", 1.0),
			"metallic": m.get("metallic", 0.0),
			"texture_base64": _tex_to_b64(m["texture"]),
		})
	var lib: Array = []
	for entry in texture_library:
		lib.append({"path": entry["path"], "texture_base64": _tex_to_b64(entry["texture"])})
	return {"materials": mats, "library": lib}

func deserialize_palette(data: Dictionary) -> void:
	for child in materials_list.get_children():
		if child.has_meta("material_data"):
			materials_list.remove_child(child)
			child.queue_free()
	materials.clear()
	texture_library.clear()
	for m in data.get("materials", []):
		var c: Array = m["color"]
		_add_material_swatch({
			"color": Color(c[0], c[1], c[2], c[3]),
			"texture": _b64_to_tex(m.get("texture_base64")),
			"roughness": m.get("roughness", 1.0),
			"metallic": m.get("metallic", 0.0),
		})
	for entry in data.get("library", []):
		var t: Texture2D = _b64_to_tex(entry.get("texture_base64"))
		if t != null:
			texture_library.append({"path": entry.get("path", ""), "texture": t})
