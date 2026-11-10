extends HBoxContainer

signal play_pressed
signal stop_pressed

@onready var play_button: Control = $PlayButton
@onready var stop_button: Control = $StopButton

func _ready() -> void:
	play_button.gui_input.connect(_on_play_input)
	stop_button.gui_input.connect(_on_stop_input)

func _on_play_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		play_pressed.emit()

func _on_stop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		stop_pressed.emit()
