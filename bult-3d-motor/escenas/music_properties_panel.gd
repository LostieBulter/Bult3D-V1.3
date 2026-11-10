extends Panel

@onready var volume_slider: HSlider = $VolumeSlider
@onready var import_button: Button = $ImportAudioButton
@onready var close_button: Button = $CloseButton
@export var animation_manager_path: NodePath
var animation_manager: Node
var target_player: AudioStreamPlayer = null

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	volume_slider.min_value = -40
	volume_slider.max_value = 6
	volume_slider.value_changed.connect(_on_volume_changed)
	import_button.pressed.connect(_on_import_pressed)
	close_button.pressed.connect(_on_close_pressed)
	if animation_manager_path != NodePath(""):
		animation_manager = get_node(animation_manager_path)
func open_for(player: AudioStreamPlayer, screen_pos: Vector2) -> void:
	target_player = player
	volume_slider.set_value_no_signal(player.volume_db)
	position = screen_pos
	visible = true

func _on_volume_changed(value: float) -> void:
	if target_player != null:
		target_player.volume_db = value

func _on_close_pressed() -> void:
	visible = false

func _on_import_pressed() -> void:
	var path: String = pick_audio_file_native()
	if path == "":
		return

	var stream: AudioStream = null
	var format: String = ""
	if path.to_lower().ends_with(".wav"):
		stream = AudioStreamWAV.load_from_file(path)
		format = "wav"
	elif path.to_lower().ends_with(".ogg"):
		stream = AudioStreamOggVorbis.load_from_file(path)
		format = "ogg"
	elif path.to_lower().ends_with(".mp3"):
		stream = AudioStreamMP3.load_from_file(path)
		format = "mp3"

	if stream == null:
		print("No se pudo cargar el audio: ", path)
		return

	var file := FileAccess.open(path, FileAccess.READ)
	var raw_bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()

	if target_player != null:
		if target_player.playing:
			target_player.stop()
		target_player.stream = stream
		target_player.get_parent().set_meta("audio_bytes", raw_bytes)
		target_player.get_parent().set_meta("audio_format", format)
		if animation_manager != null:
			animation_manager.refresh_media_range_for_selection()

func pick_audio_file_native() -> String:
	var output: Array = []
	var script := 'Add-Type -AssemblyName System.Windows.Forms; $dialog = New-Object System.Windows.Forms.OpenFileDialog; $dialog.Filter = \'Audio (*.wav;*.ogg;*.mp3)|*.wav;*.ogg;*.mp3\'; if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Write-Output $dialog.FileName }'
	OS.execute("powershell", ["-NoProfile", "-Command", script], output, true)
	if output.size() > 0:
		return output[0].strip_edges()
	return ""
