extends Panel

@onready var import_button: Button = $ImportVideoButton
@onready var close_button: Button = $CloseButton
@onready var volume_slider: HSlider = $VolumeSlider
@onready var volume_label: Label = $VolumeLabel
@export var selection_manager_path: NodePath
var selection_manager: Node
@onready var brightness_spinbox: SpinBox = $BrightnessSpinBox
var target_body: StaticBody3D = null
@export var main_script_path: NodePath
var main_script: Node
@onready var delete_button: Button = $DeleteVideoButton
@export var animation_manager_path: NodePath
var animation_manager: Node



func _ready() -> void:
	if animation_manager_path != NodePath(""):
		animation_manager = get_node(animation_manager_path)
	brightness_spinbox.value_changed.connect(_on_brightness_changed)
	if main_script_path != NodePath(""):
		main_script = get_node(main_script_path)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	import_button.pressed.connect(_on_import_pressed)
	close_button.pressed.connect(_on_close_pressed)
	volume_slider.min_value = -40
	volume_slider.max_value = 6
	volume_slider.value_changed.connect(_on_volume_changed)
	delete_button.pressed.connect(_on_delete_pressed)
	if selection_manager_path != NodePath(""):
		selection_manager = get_node(selection_manager_path)
func open_for(body: StaticBody3D, screen_pos: Vector2) -> void:
	target_body = body
	position = screen_pos
	visible = true

	var has_audio: bool = body.get_meta("has_audio", false)
	volume_slider.visible = has_audio
	volume_label.visible = has_audio

	if has_audio:
		var audio_player: AudioStreamPlayer = body.get_node_or_null("VideoAudio")
		if audio_player != null:
			volume_slider.set_value_no_signal(audio_player.volume_db)
			
	brightness_spinbox.set_value_no_signal(target_body.get_meta("video_brightness", 1.0))
func _on_close_pressed() -> void:
	visible = false

func _on_import_pressed() -> void:
	var path: String = pick_video_file_native()
	if path == "":
		return

	var old_dir: String = target_body.get_meta("video_cache_dir", "") if target_body != null else ""

	# Soltamos cualquier referencia al video/audio viejo ANTES de tocar su carpeta en disco
	if target_body != null:
		var old_audio: AudioStreamPlayer = target_body.get_node_or_null("VideoAudio")
		if old_audio != null:
			old_audio.stop()
			old_audio.stream = null
		var old_mesh: MeshInstance3D = target_body.get_node_or_null("Mesh")
		if old_mesh != null and old_mesh.material_override is StandardMaterial3D:
			old_mesh.material_override.albedo_texture = null
		target_body.set_meta("video_frames", [])

	await get_tree().process_frame

	var user_dir: String = OS.get_user_data_dir() + "/video_cache_" + str(Time.get_ticks_msec())
	var ffmpeg_path: String = main_script.get_ffmpeg_path()
	DirAccess.make_dir_recursive_absolute(user_dir)

	# Extraemos los cuadros visuales
	var output: Array = []
	var args := ["-i", path, "-vf", "fps=%d" % int(animation_manager.FPS), user_dir + "/frame_%04d.png"]
	var exit_code: int = OS.execute(ffmpeg_path, args, output, true)

	if exit_code != 0:
		print("Error al convertir el video/gif")
		return

	await get_tree().process_frame

	# Intentamos extraer el audio (si no tiene audio, este comando fallará silenciosamente, y está bien)
	var audio_path: String = user_dir + "/audio.ogg"
	var audio_output: Array = []
	var audio_args := ["-i", path, "-vn", "-acodec", "libvorbis", audio_path]
	var audio_exit_code: int = OS.execute(ffmpeg_path, audio_args, audio_output, true)

	var has_audio: bool = audio_exit_code == 0 and FileAccess.file_exists(audio_path)

	if target_body != null:
		target_body.set_meta("video_cache_dir", user_dir)
		target_body.set_meta("has_audio", has_audio)
		target_body.set_meta("video_start_offset", 0)

	if has_audio:
		var stream: AudioStream = AudioStreamOggVorbis.load_from_file(audio_path)
		var audio_player: AudioStreamPlayer = target_body.get_node_or_null("VideoAudio")
		if audio_player == null:
			audio_player = AudioStreamPlayer.new()
			audio_player.name = "VideoAudio"
			target_body.add_child(audio_player)
		audio_player.stream = stream

	await get_tree().process_frame

	load_frames_from_folder(user_dir)

	# Recién ahora, con el video nuevo ya anda, borramos la carpeta vieja
	if old_dir != "" and old_dir != user_dir and DirAccess.dir_exists_absolute(old_dir):
		OS.move_to_trash(old_dir)

func load_frames_from_folder(folder: String) -> void:
	var frames: Array = []
	var dir := DirAccess.open(folder)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	var filenames: Array = []
	while file_name != "":
		if file_name.ends_with(".png"):
			filenames.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	filenames.sort()

	for fname in filenames:
		var img := Image.new()
		img.load(folder + "/" + fname)
		var tex := ImageTexture.create_from_image(img)
		frames.append(tex)

	if target_body != null:
		target_body.set_meta("video_frames", frames)
		if frames.size() > 0:
			var mesh_instance: MeshInstance3D = target_body.get_node("Mesh")
			var mat: StandardMaterial3D = mesh_instance.material_override
			mat.albedo_texture = frames[0]

	visible = false

func pick_video_file_native() -> String:
	var output: Array = []
	var script := 'Add-Type -AssemblyName System.Windows.Forms; $dialog = New-Object System.Windows.Forms.OpenFileDialog; $dialog.Filter = \'Video o GIF (*.mp4;*.gif;*.webm;*.mov)|*.mp4;*.gif;*.webm;*.mov\'; if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Write-Output $dialog.FileName }'
	OS.execute("powershell", ["-NoProfile", "-Command", script], output, true)
	if output.size() > 0:
		return output[0].strip_edges()
	return ""

func _on_volume_changed(value: float) -> void:
	if target_body != null:
		var audio_player: AudioStreamPlayer = target_body.get_node_or_null("VideoAudio")
		if audio_player != null:
			audio_player.volume_db = value

func _on_brightness_changed(value: float) -> void:
	if target_body == null:
		return
	var mesh_instance: MeshInstance3D = target_body.get_node_or_null("Mesh")
	if mesh_instance != null and mesh_instance.material_override is StandardMaterial3D:
		mesh_instance.material_override.albedo_color = Color(value, value, value)
	target_body.set_meta("video_brightness", value)

func _on_delete_pressed() -> void:
	if target_body == null:
		return

	var old_audio: AudioStreamPlayer = target_body.get_node_or_null("VideoAudio")
	if old_audio != null:
		old_audio.stop()

	var cache_dir: String = target_body.get_meta("video_cache_dir", "")
	if cache_dir != "" and DirAccess.dir_exists_absolute(cache_dir):
		OS.move_to_trash(cache_dir)

	if selection_manager != null:
		selection_manager.delete_object_completely(target_body)

	target_body = null
	visible = false
