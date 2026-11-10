extends Panel

@onready var thumbs_container: HBoxContainer = $ScrollContainer/ThumbsContainer
@onready var close_button: Button = $CloseButton

var pending_locations: Array = []
var pending_swatch: TextureButton = null

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.pressed.connect(func(): visible = false)

func open_for(locations: Array, library: Array, swatch: TextureButton) -> void:
	pending_locations = locations
	pending_swatch = swatch

	for child in thumbs_container.get_children():
		child.queue_free()

	for entry in library:
		var thumb := TextureButton.new()
		thumb.custom_minimum_size = Vector2(48, 48)
		thumb.ignore_texture_size = true
		thumb.stretch_mode = TextureButton.STRETCH_SCALE
		thumb.texture_normal = entry["texture"]
		thumb.pressed.connect(func(): _on_thumb_pressed(entry["texture"]))
		thumbs_container.add_child(thumb)

	visible = true

func _on_thumb_pressed(tex: Texture2D) -> void:
	var new_mat := StandardMaterial3D.new()
	new_mat.albedo_texture = tex
	AlphaHelper.fix(new_mat)   # <-- nueva
	for loc in pending_locations:
		loc["mesh"].set_surface_override_material(loc["surface"], new_mat)

	if pending_swatch != null and is_instance_valid(pending_swatch):
		pending_swatch.texture_normal = tex

	visible = false
