extends HBoxContainer

@onready var play_once_button: Button = $PlayOnceButton
@onready var loop_button: Button = $LoopButton

var target_body: StaticBody3D = null

func _ready() -> void:
	visible = false
	play_once_button.toggle_mode = true
	loop_button.toggle_mode = true
	play_once_button.pressed.connect(_on_play_once_pressed)
	loop_button.pressed.connect(_on_loop_pressed)

func show_for(body: StaticBody3D) -> void:
	target_body = body
	visible = true
	var is_loop: bool = body.get_meta("video_loop", true)
	loop_button.button_pressed = is_loop
	play_once_button.button_pressed = not is_loop

func hide_controls() -> void:
	visible = false
	target_body = null

func _on_play_once_pressed() -> void:
	play_once_button.button_pressed = true
	loop_button.button_pressed = false
	if target_body != null:
		target_body.set_meta("video_loop", false)

func _on_loop_pressed() -> void:
	loop_button.button_pressed = true
	play_once_button.button_pressed = false
	if target_body != null:
		target_body.set_meta("video_loop", true)
