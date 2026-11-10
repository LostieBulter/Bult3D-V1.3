extends Node

@export var camera_rig_path: NodePath
@export var pick_viewport_path: NodePath
@export var pick_camera_path: NodePath

var main_camera: Camera3D
var pick_viewport: SubViewport
var pick_camera: Camera3D

var next_id: int = 1
var id_to_object: Dictionary = {}   # int -> StaticBody3D
var object_to_proxy: Dictionary = {} # StaticBody3D -> MeshInstance3D (dentro del pick viewport)

func _ready() -> void:
	var camera_rig: Node3D = get_node(camera_rig_path)
	
	main_camera = camera_rig.get_node("CameraPitch/Camera3D")
	pick_viewport = get_node(pick_viewport_path)
	pick_camera = get_node(pick_camera_path)

	get_viewport().size_changed.connect(_on_main_viewport_resized)
	_on_main_viewport_resized()

	# DEBUG TEMPORAL: guardamos la imagen del pick viewport cada 2 segundos
	var timer := Timer.new()
	timer.wait_time = 2.0
	timer.timeout.connect(_debug_save_image)
	add_child(timer)
	timer.start()

func _debug_save_image() -> void:
	var img: Image = pick_viewport.get_texture().get_image()
	img.save_png("user://pick_debug.png")

	# Contamos cuántos píxeles NO son negros en toda la imagen
	var non_black_count := 0
	for y in range(0, img.get_height(), 10):  # muestreamos cada 10 píxeles para que sea rápido
		for x in range(0, img.get_width(), 10):
			var c: Color = img.get_pixel(x, y)
			if c != Color(0, 0, 0, 1):
				non_black_count += 1

	print("Píxeles no-negros encontrados (muestreo): ", non_black_count)
	print("Objetos registrados: ", id_to_object.keys())
	print("Proxies en el viewport: ", pick_viewport.get_child_count())

func _on_main_viewport_resized() -> void:
	pick_viewport.size = get_viewport().size

func _process(_delta: float) -> void:
	# La cámara de picking siempre copia exactamente a la cámara real
	pick_camera.global_transform = main_camera.global_transform
	pick_camera.fov = main_camera.fov
	pick_camera.near = main_camera.near
	pick_camera.far = main_camera.far

	# Mantenemos cada proxy sincronizado con la posición real de su objeto
	for obj in object_to_proxy.keys():
		if is_instance_valid(obj):
			object_to_proxy[obj].global_transform = obj.global_transform

func register_object(obj: StaticBody3D, mesh: Mesh) -> void:
	var id: int = next_id
	next_id += 1
	print("Registrando '", obj.name, "' con id=", id)

	var proxy := MeshInstance3D.new()
	
	proxy.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = id_to_color(id)
	proxy.material_override = mat

	pick_viewport.add_child(proxy)
	proxy.global_transform = obj.global_transform
	
	
	id_to_object[id] = obj
	object_to_proxy[obj] = proxy

func unregister_object(obj: StaticBody3D) -> void:
	if object_to_proxy.has(obj):
		object_to_proxy[obj].queue_free()
		object_to_proxy.erase(obj)
	for id in id_to_object.keys():
		if id_to_object[id] == obj:
			id_to_object.erase(id)
			break

func id_to_color(id: int) -> Color:
	var r: float = float(id & 0xFF) / 255.0
	var g: float = float((id >> 8) & 0xFF) / 255.0
	var b: float = float((id >> 16) & 0xFF) / 255.0
	return Color(r, g, b)

func color_to_id(color: Color) -> int:
	var r: int = int(round(color.r * 255.0))
	var g: int = int(round(color.g * 255.0))
	var b: int = int(round(color.b * 255.0))
	return r | (g << 8) | (b << 16)

func pick_at(screen_pos: Vector2) -> StaticBody3D:
	var img: Image = pick_viewport.get_texture().get_image()
	var x: int = int(screen_pos.x)
	var y: int = int(screen_pos.y)
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return null

	var color: Color = img.get_pixel(x, y)
	var id: int = color_to_id(color)
	print("clic en (", x, ",", y, ") color=", color, " id calculado=", id, " ids registrados=", id_to_object.keys())
	if id == 0 or not id_to_object.has(id):
		return null
	return id_to_object[id]
