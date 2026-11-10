extends Panel

@onready var use_custom_bg_checkbox: CheckBox = $UseCustomBgCheckbox
@onready var bg_color_picker: ColorPickerButton = $BgColorPickerButton
@onready var fov_spinbox: SpinBox = $FovSpinBox
@onready var close_button: Button = $CloseButton

var target_camera: Camera3D = null

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	use_custom_bg_checkbox.toggled.connect(_on_use_custom_bg_toggled)
	bg_color_picker.color_changed.connect(_on_bg_color_changed)
	fov_spinbox.value_changed.connect(_on_fov_changed)
	close_button.pressed.connect(_on_close_pressed)

func open_for_camera(cam: Camera3D, screen_pos: Vector2) -> void:
	target_camera = cam
	fov_spinbox.set_value_no_signal(cam.fov)

	var has_custom_bg: bool = cam.environment != null
	use_custom_bg_checkbox.set_pressed_no_signal(has_custom_bg)
	bg_color_picker.disabled = not has_custom_bg
	bg_color_picker.color = cam.environment.background_color if has_custom_bg else Color(0.3, 0.3, 0.3)

	position = screen_pos
	visible = true

func _on_use_custom_bg_toggled(pressed: bool) -> void:
	if target_camera == null:
		return
	bg_color_picker.disabled = not pressed
	if pressed:
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = bg_color_picker.color
		target_camera.environment = env
	else:
		target_camera.environment = null

func _on_bg_color_changed(color: Color) -> void:
	if target_camera != null and target_camera.environment != null:
		target_camera.environment.background_color = color

func _on_fov_changed(value: float) -> void:
	if target_camera != null:
		target_camera.fov = value

func _on_close_pressed() -> void:
	visible = false
