extends LineEdit

signal end_frame_changed(new_end: int)

func _ready() -> void:
	text = "140"
	text_submitted.connect(_on_submitted)
	focus_exited.connect(_on_focus_exited)

func _on_submitted(new_text: String) -> void:
	_apply_value(new_text)
	release_focus()

func _on_focus_exited() -> void:
	_apply_value(text)

func _apply_value(new_text: String) -> void:
	var value: int = new_text.to_int()
	if value < 1:
		value = 1
	text = str(value)
	end_frame_changed.emit(value)
