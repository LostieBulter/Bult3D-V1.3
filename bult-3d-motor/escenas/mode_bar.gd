extends HBoxContainer

@export var animation_panel_path: NodePath
var animation_panel: Panel
@export var options_panel_path: NodePath
var options_panel: Panel
@export var materials_panel_path: NodePath
var materials_panel: Panel
@onready var materials_button: Button = $MaterialsButton
@onready var options_button: Button = $OptionsButton
@onready var edit_button: Button = $EditButton
@onready var anim_button: Button = $AnimButton

func _ready() -> void:
	materials_panel = get_node(materials_panel_path)
	materials_button.toggle_mode = true
	materials_button.pressed.connect(_on_materials_pressed)
	options_panel = get_node(options_panel_path)
	options_button.toggle_mode = true
	options_button.pressed.connect(_on_options_pressed)
	animation_panel = get_node(animation_panel_path)
	edit_button.toggle_mode = true
	anim_button.toggle_mode = true
	edit_button.button_pressed = true

	edit_button.pressed.connect(_on_edit_pressed)
	anim_button.pressed.connect(_on_anim_pressed)

func _on_edit_pressed() -> void:
	edit_button.button_pressed = true
	anim_button.button_pressed = false
	options_button.button_pressed = false
	materials_button.button_pressed = false
	animation_panel.visible = false
	options_panel.visible = false
	materials_panel.visible = false

func _on_anim_pressed() -> void:
	anim_button.button_pressed = true
	edit_button.button_pressed = false
	options_button.button_pressed = false
	materials_button.button_pressed = false
	animation_panel.visible = true
	options_panel.visible = false
	materials_panel.visible = false

func _on_options_pressed() -> void:
	options_button.button_pressed = true
	edit_button.button_pressed = false
	anim_button.button_pressed = false
	materials_button.button_pressed = false
	animation_panel.visible = false
	options_panel.visible = true
	materials_panel.visible = false

func _on_materials_pressed() -> void:
	materials_button.button_pressed = true
	edit_button.button_pressed = false
	anim_button.button_pressed = false
	options_button.button_pressed = false
	animation_panel.visible = false
	options_panel.visible = false
	materials_panel.visible = true
