extends Label

var hide_timer: Timer

func _ready() -> void:
	visible = false
	modulate.a = 0.0
	add_to_group("toast_system")
	hide_timer = Timer.new()
	hide_timer.one_shot = true
	hide_timer.wait_time = 2.5
	hide_timer.timeout.connect(_on_hide_timeout)
	add_child(hide_timer)

func show_toast(msg: String) -> void:
	text = msg
	visible = true
	modulate.a = 1.0
	hide_timer.start()

func _on_hide_timeout() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): visible = false)
