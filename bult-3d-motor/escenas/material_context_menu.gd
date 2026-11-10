extends Panel

@onready var color_picker: ColorPickerButton = $ColorPickerButton
@onready var import_button: Button = $ImportTextureButton
@onready var close_button: Button = $CloseButton
@onready var reset_button: Button = $ResetButton
signal delete_requested(button: TextureButton)
@onready var roughness_slider: HSlider = $RoughnessSlider
@onready var metallic_slider: HSlider = $MetallicSlider
@onready var delete_material_button: Button = $DeleteMaterialButton
var current_button: TextureButton = null
var current_data: Dictionary = {}

func _ready() -> void:
	metallic_slider.value_changed.connect(_on_metallic_changed)
	roughness_slider.value_changed.connect(_on_roughness_changed)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	color_picker.color_changed.connect(_on_color_changed)
	import_button.pressed.connect(_on_import_pressed)
	close_button.pressed.connect(_on_close_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	delete_material_button.pressed.connect(_on_delete_material_pressed)
	
func open_for(button: TextureButton, data: Dictionary) -> void:
	if not data.has("metallic"):
		data["metallic"] = 0.0
	metallic_slider.set_value_no_signal(data["metallic"])
	current_button = button
	current_data = data
	color_picker.color = data["color"]
	if not data.has("roughness"):
		data["roughness"] = 1.0
	roughness_slider.set_value_no_signal(data["roughness"])
	visible = true

func _on_color_changed(color: Color) -> void:
	current_data["color"] = color
	current_data["texture"] = null
	if current_button != null:
		var img := Image.create(48, 48, false, Image.FORMAT_RGB8)
		img.fill(color)
		current_button.texture_normal = ImageTexture.create_from_image(img)

func _on_import_pressed() -> void:
	var path: String = pick_file_native()
	if path == "":
		return
	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		print("No se pudo cargar la imagen: ", path)
		return
	var tex := ImageTexture.create_from_image(img)
	current_data["texture"] = tex
	if current_button != null:
		current_button.texture_normal = tex
	visible = false

func pick_file_native() -> String:
	var output: Array = []
	var script := 'Add-Type -AssemblyName System.Windows.Forms; $dialog = New-Object System.Windows.Forms.OpenFileDialog; $dialog.Filter = \'Imagenes (*.png;*.jpg;*.jpeg)|*.png;*.jpg;*.jpeg\'; if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Write-Output $dialog.FileName }'
	OS.execute("powershell", ["-NoProfile", "-Command", script], output, true)
	if output.size() > 0:
		return output[0].strip_edges()
	return ""

func _on_close_pressed() -> void:
	visible = false

func _on_reset_pressed() -> void:
	current_data["metallic"] = 0.0
	metallic_slider.set_value_no_signal(0.0)
	current_data["color"] = Color.WHITE
	current_data["texture"] = null
	current_data["roughness"] = 1.0
	color_picker.color = Color.WHITE
	roughness_slider.set_value_no_signal(1.0)

	if current_button != null:
		var img := Image.create(48, 48, false, Image.FORMAT_RGB8)
		img.fill(Color.WHITE)
		current_button.texture_normal = ImageTexture.create_from_image(img)

func _on_delete_material_pressed() -> void:
	if current_button != null:
		delete_requested.emit(current_button)
	visible = false

func _on_roughness_changed(value: float) -> void:
	current_data["roughness"] = value

func _on_metallic_changed(value: float) -> void:
	current_data["metallic"] = value
