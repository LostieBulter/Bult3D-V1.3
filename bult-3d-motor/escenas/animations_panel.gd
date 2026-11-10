extends Panel

signal create_requested(anim_name: String)
signal select_requested(anim_name: String)
signal delete_requested(anim_name: String)

var item_list: ItemList
var name_input: LineEdit
var names_cache: Array = []
var title_label: Label

func _ready() -> void:
	size = Vector2(250, 250)
	position = Vector2(110, 60)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	title_label = Label.new()
	title_label.position = Vector2(10, 6)
	title_label.size = Vector2(195, 24)
	title_label.clip_text = true
	add_child(title_label)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(212, 4)
	close_btn.size = Vector2(28, 24)
	close_btn.pressed.connect(func(): visible = false)
	add_child(close_btn)

	item_list = ItemList.new()
	item_list.position = Vector2(10, 34)
	item_list.size = Vector2(230, 120)
	item_list.item_selected.connect(_on_item_selected)
	add_child(item_list)

	name_input = LineEdit.new()
	name_input.placeholder_text = "Nombre (ej: saltando)"
	name_input.position = Vector2(10, 164)
	name_input.size = Vector2(230, 30)
	name_input.text_submitted.connect(func(_t): _on_create_pressed())
	add_child(name_input)

	var create_btn := Button.new()
	create_btn.text = "Nueva animación"
	create_btn.position = Vector2(10, 204)
	create_btn.size = Vector2(140, 30)
	create_btn.pressed.connect(_on_create_pressed)
	add_child(create_btn)

	var delete_btn := Button.new()
	delete_btn.text = "Borrar"
	delete_btn.position = Vector2(158, 204)
	delete_btn.size = Vector2(82, 30)
	delete_btn.pressed.connect(_on_delete_pressed)
	add_child(delete_btn)

func refresh(names: Array, current: String, obj_name: String = "") -> void:
	title_label.text = ("Animaciones: " + obj_name) if obj_name != "" else "Selecciona un objeto"
	names_cache = names.duplicate()
	item_list.clear()
	for i in names_cache.size():
		item_list.add_item(names_cache[i])
		if names_cache[i] == current:
			item_list.select(i)

func _on_item_selected(index: int) -> void:
	if index >= 0 and index < names_cache.size():
		select_requested.emit(names_cache[index])

func _on_create_pressed() -> void:
	var n: String = name_input.text.strip_edges()
	if n == "":
		return
	create_requested.emit(n)
	name_input.clear()

func _on_delete_pressed() -> void:
	var sel: PackedInt32Array = item_list.get_selected_items()
	if sel.is_empty():
		return
	delete_requested.emit(names_cache[sel[0]])
