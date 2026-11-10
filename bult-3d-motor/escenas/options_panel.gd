extends Panel

@export var directional_light_path: NodePath
var sun_light: DirectionalLight3D

@onready var lighting_tab: Button = $CategoryTabs/LightingTabButton
@onready var import_tab: Button = $CategoryTabs/ImportTabButton
@onready var export_tab: Button = $CategoryTabs/ExportTabButton
@onready var render_tab: Button = $CategoryTabs/RenderTabButton

@onready var lighting_section: VBoxContainer = $LightingSection
@onready var import_section: Control = $ImportSection
@onready var export_section: Control = $ExportSection
@onready var render_section: Control = $RenderSection

@onready var ambient_slider: HSlider = $LightingSection/AmbientSlider
@onready var sun_energy_slider: HSlider = $LightingSection/SunEnergySlider
@export var render_manager_path: NodePath
@export var main_script_path: NodePath  # referencia a main.gd, para encontrar la cámara y animation_manager
@onready var progress_bar: ProgressBar = $RenderSection/ExportProgressBar

var render_manager: Node
var main_script: Node

@onready var video_start_input: LineEdit = $RenderSection/VideoStartFrameInput
@onready var video_end_input: LineEdit = $RenderSection/VideoEndFrameInput
@onready var export_video_button: Button = $RenderSection/ExportVideoButton
@onready var export_photo_button: Button = $RenderSection/ExportPhotoButton
@export var timeline_ruler_path: NodePath
var timeline_ruler: Control
@onready var export_mp4_button: Button = $RenderSection/ExportMp4Button
@onready var resolution_option: OptionButton = $RenderSection/ResolutionOption
@onready var master_brightness_spinbox: SpinBox = $LightingSection/MasterBrightnessSpinBox
var studio_lights: Array[DirectionalLight3D] = []
var studio_lights_base_energy: Array[float] = []
var base_ambient_energy: float = 1.0
@onready var fps_spinbox: SpinBox = $FpsSpinBox
@export var animation_manager_path: NodePath
var animation_manager_ref: Node
@onready var interpolation_option: OptionButton = $InterpolationOption

const RESOLUTIONS := [
	Vector2i(320, 180),
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(3840, 2160),
]


func _ready() -> void:
	
	
	
	export_mp4_button.pressed.connect(_on_export_mp4_pressed)
	visibility_changed.connect(_on_visibility_changed)
	if render_manager_path != NodePath(""):
		render_manager = get_node(render_manager_path)
	if main_script_path != NodePath(""):
		main_script = get_node(main_script_path)
		
	
	
	if animation_manager_path != NodePath(""):
		animation_manager_ref = get_node(animation_manager_path)

	if timeline_ruler_path != NodePath(""):
		timeline_ruler = get_node(timeline_ruler_path)

	video_start_input.text = "0"
	video_end_input.text = str(timeline_ruler.end_frame) if timeline_ruler != null else "48"
	
	resolution_option.clear()
	resolution_option.add_item("240p (320x180) - Baja calidad")
	resolution_option.add_item("720p (1280x720)")
	resolution_option.add_item("1080p (1920x1080)")
	resolution_option.add_item("4K (3840x2160)")
	resolution_option.selected = 1  # 1080p por defecto
	
	
	export_video_button.pressed.connect(_on_export_video_pressed)
	export_photo_button.pressed.connect(_on_export_photo_pressed)
	
	
	
	
	if directional_light_path != NodePath(""):
		sun_light = get_node(directional_light_path)
		
	

	lighting_tab.pressed.connect(func(): show_section(lighting_section))
	import_tab.pressed.connect(func(): show_section(import_section))
	export_tab.pressed.connect(func(): show_section(export_section))
	render_tab.pressed.connect(func(): show_section(render_section))
	fps_spinbox.set_value_no_signal(animation_manager_ref.FPS)
	fps_spinbox.value_changed.connect(_on_fps_changed)
	ambient_slider.value_changed.connect(_on_ambient_changed)
	sun_energy_slider.value_changed.connect(_on_sun_energy_changed)

	# Cargamos los valores actuales del ambiente, si existe
	var env: Environment = get_viewport().get_world_3d().environment
	if env != null:
		ambient_slider.set_value_no_signal(env.ambient_light_energy)
	if sun_light != null:
		sun_energy_slider.set_value_no_signal(sun_light.light_energy)
	
	for light in get_tree().get_nodes_in_group("luces_estudio"):
		if light is DirectionalLight3D:
			studio_lights.append(light)
			studio_lights_base_energy.append(light.light_energy)

	base_ambient_energy = env.ambient_light_energy if env != null else 0.3

	master_brightness_spinbox.set_value_no_signal(1.0)
	master_brightness_spinbox.value_changed.connect(_on_master_brightness_changed)
	
	show_section(lighting_section)

	interpolation_option.clear()
	interpolation_option.add_item("Curva (sin paradas)")
	interpolation_option.add_item("Suave")
	interpolation_option.add_item("Lineal")
	match animation_manager_ref.interpolation_mode:
		"spline": interpolation_option.selected = 0
		"smooth": interpolation_option.selected = 1
		_: interpolation_option.selected = 2
	interpolation_option.item_selected.connect(_on_interpolation_selected)
	_build_export_section()

func show_section(section: Control) -> void:
	lighting_section.visible = section == lighting_section
	import_section.visible = section == import_section
	export_section.visible = section == export_section
	render_section.visible = section == render_section

func _on_ambient_changed(value: float) -> void:
	var env: Environment = get_viewport().get_world_3d().environment
	if env != null:
		env.ambient_light_energy = value



func _on_sun_energy_changed(value: float) -> void:
	if sun_light != null:
		sun_light.light_energy = value

func _on_master_brightness_changed(value: float) -> void:
	for i in range(studio_lights.size()):
		studio_lights[i].light_energy = studio_lights_base_energy[i] * value
	var env: Environment = get_viewport().get_world_3d().environment
	if env != null:
		env.ambient_light_energy = base_ambient_energy * value


func _on_export_video_pressed() -> void:
	var cam: Camera3D = main_script.find_first_camera()
	if cam == null:
		print("No hay ninguna cámara en la escena")
		return

	var start_frame: int = video_start_input.text.to_int()
	var end_frame: int = video_end_input.text.to_int()

	var desktop_path: String = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	var output_dir: String = _get_unique_dir_path(desktop_path, "AnimacionExportada")
	var res: Vector2i = _get_selected_resolution()
	render_manager.set_render_resolution(res.x, res.y)
	render_manager.export_sequence(cam, start_frame, end_frame, output_dir)

func _on_export_photo_pressed() -> void:
	var cam: Camera3D = main_script.find_first_camera()
	if cam == null:
		print("No hay ninguna cámara en la escena")
		return

	var folder: String = pick_export_folder_native()
	if folder == "":
		return

	var current_frame: int = main_script.animation_manager.current_frame
	var output_path: String = _get_unique_file_path(folder, "Foto_%d" % current_frame, ".png")
	var res: Vector2i = _get_selected_resolution()
	render_manager.set_render_resolution(res.x, res.y)
	render_manager.export_single_frame(cam, current_frame, output_path)

func _on_visibility_changed() -> void:
	if visible and timeline_ruler != null:
		video_end_input.text = str(timeline_ruler.end_frame)

func _on_export_mp4_pressed() -> void:
	var cam: Camera3D = main_script.find_first_camera()
	if cam == null:
		print("No hay ninguna cámara en la escena")
		return

	var folder: String = pick_export_folder_native()
	if folder == "":
		return

	var start_frame: int = video_start_input.text.to_int()
	var end_frame: int = video_end_input.text.to_int()
	var temp_frames_dir: String = OS.get_user_data_dir() + "/mp4_temp_frames_" + str(Time.get_ticks_msec())

	progress_bar.visible = true
	progress_bar.value = 0
	var res: Vector2i = _get_selected_resolution()
	render_manager.set_render_resolution(res.x, res.y)

	render_manager.export_sequence(cam, start_frame, end_frame, temp_frames_dir)
	await render_manager.export_finished

	var output_mp4: String = _get_unique_file_path(folder, "AnimacionExportada", ".mp4")
	render_manager.convert_frames_to_mp4(temp_frames_dir, output_mp4)

	OS.move_to_trash(temp_frames_dir)
	progress_bar.visible = false

func _get_selected_resolution() -> Vector2i:
	return RESOLUTIONS[resolution_option.selected]

func _get_unique_file_path(directory: String, base_name: String, extension: String) -> String:
	var candidate: String = directory + "/" + base_name + extension
	if not FileAccess.file_exists(candidate):
		return candidate
	var i: int = 2
	while true:
		candidate = directory + "/" + base_name + str(i) + extension
		if not FileAccess.file_exists(candidate):
			return candidate
		i += 1
	return candidate

func _get_unique_dir_path(directory: String, base_name: String) -> String:
	var candidate: String = directory + "/" + base_name
	if not DirAccess.dir_exists_absolute(candidate):
		return candidate
	var i: int = 2
	while true:
		candidate = directory + "/" + base_name + str(i)
		if not DirAccess.dir_exists_absolute(candidate):
			return candidate
		i += 1
	return candidate

func pick_export_folder_native() -> String:
	var output: Array = []
	var script := 'Add-Type -AssemblyName System.Windows.Forms; $dialog = New-Object System.Windows.Forms.FolderBrowserDialog; if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Write-Output $dialog.SelectedPath }'
	OS.execute("powershell", ["-NoProfile", "-Command", script], output, true)
	if output.size() > 0:
		return output[0].strip_edges()
	return ""

func _on_fps_changed(value: float) -> void:
	if animation_manager_ref != null:
		animation_manager_ref.FPS = value

func _on_interpolation_selected(index: int) -> void:
	if animation_manager_ref == null:
		return
	match index:
		0: animation_manager_ref.interpolation_mode = "spline"
		1: animation_manager_ref.interpolation_mode = "smooth"
		_: animation_manager_ref.interpolation_mode = "linear"

func _build_export_section() -> void:
	if export_section is Label:
		export_section.text = ""
	export_section.position = Vector2(10, 50)

	var box := VBoxContainer.new()
	export_section.add_child(box)

	var info := Label.new()
	info.text = "Exporta todo el proyecto con TODAS las animaciones\n(cada objeto con su lista). En Godot, los nombres\naparecen en el nodo AnimationPlayer."
	box.add_child(info)

	var glb_btn := Button.new()
	glb_btn.text = "  Exportar proyecto (.glb)  "
	glb_btn.pressed.connect(func(): _on_export_gltf_pressed(".glb"))
	box.add_child(glb_btn)

	var gltf_btn := Button.new()
	gltf_btn.text = "  Exportar proyecto (.gltf)  "
	gltf_btn.pressed.connect(func(): _on_export_gltf_pressed(".gltf"))
	box.add_child(gltf_btn)

func _on_export_gltf_pressed(ext: String) -> void:
	var folder: String = pick_export_folder_native()
	if folder == "":
		return
	var exporter = preload("res://escenas/gltf_exporter.gd").new()
	exporter.selection_manager = main_script.selection_manager
	exporter.animation_manager = animation_manager_ref
	var path: String = _get_unique_file_path(folder, "ProyectoExportado", ext)
	var err: int = exporter.export_project(path)
	if err == OK:
		get_tree().call_group("toast_system", "show_toast", "Proyecto exportado: " + path)
	else:
		get_tree().call_group("toast_system", "show_toast", "Error al exportar (código %d)" % err)
