extends Panel

signal delete_requested(light: Light3D)

@onready var intensity_slider: HSlider = $IntensitySlider
@onready var shadow_checkbox: CheckBox = $ShadowCheckbox
@onready var color_picker_button: ColorPickerButton = $ColorPickerButton
@onready var delete_button: Button = $DeleteLightButton
@onready var close_button: Button = $CloseButton
@onready var range_label: Label = $RangeLabel
@onready var range_spinbox: SpinBox = $RangeSpinBox


var target_light: Light3D = null

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	intensity_slider.value_changed.connect(_on_intensity_changed)
	shadow_checkbox.toggled.connect(_on_shadow_toggled)
	color_picker_button.color_changed.connect(_on_color_changed)
	delete_button.pressed.connect(_on_delete_pressed)
	close_button.pressed.connect(_on_close_pressed)
	range_spinbox.value_changed.connect(_on_range_changed)
	
func open_for_light(light: Light3D, screen_pos: Vector2) -> void:
	target_light = light
	intensity_slider.set_value_no_signal(light.light_energy)
	shadow_checkbox.set_pressed_no_signal(light.shadow_enabled)
	color_picker_button.color = light.light_color

	var is_spot: bool = light is SpotLight3D
	range_label.visible = is_spot
	range_spinbox.visible = is_spot
	if is_spot:
		range_spinbox.set_value_no_signal(light.spot_range)

	position = screen_pos
	visible = true

func _on_intensity_changed(value: float) -> void:
	if target_light != null:
		target_light.light_energy = value

func _on_shadow_toggled(pressed: bool) -> void:
	if target_light != null:
		target_light.shadow_enabled = pressed

func _on_delete_pressed() -> void:
	if target_light != null:
		delete_requested.emit(target_light)
	visible = false

func _on_close_pressed() -> void:
	visible = false

func _on_color_changed(color: Color) -> void:
	if target_light != null:
		target_light.light_color = color

func _on_range_changed(value: float) -> void:
	if target_light != null and target_light is SpotLight3D:
		target_light.spot_range = value
