extends Control

const PROJECTS_FILE := "user://projects.json"
const MAIN_SCENE_PATH := "res://escenas/main.tscn"  # ajustá esto al path real de tu escena principal

@onready var info_tab_button: Button = $TabBar/InfoTabButton
@onready var projects_tab_button: Button = $TabBar/ProjectsTabButton
@onready var info_panel: Panel = $InfoPanel
@onready var projects_panel: Panel = $ProjectsPanel
@onready var shortcuts_label: Label = $InfoPanel/ScrollContainer/ShortcutsLabel
@onready var projects_list: VBoxContainer = $ProjectsPanel/ScrollContainer/ProjectsList

var projects: Array = []

func _ready() -> void:
	var exit_button: Button = get_node_or_null("ExitButton")
	if exit_button != null:
		exit_button.pressed.connect(func(): get_tree().quit())
	
	info_tab_button.pressed.connect(_show_info)
	projects_tab_button.pressed.connect(_show_projects)

	shortcuts_label.text = get_shortcuts_text()

	load_projects()
	refresh_projects_list()

	_show_projects()

func _show_info() -> void:
	
	info_panel.visible = true
	projects_panel.visible = false

func _show_projects() -> void:
	info_panel.visible = false
	projects_panel.visible = true

func get_shortcuts_text() -> String:
	return """[b]Cámara[/b]
Clic izquierdo + arrastrar: Orbitar la vista
Rueda del mouse: Acercar / Alejar (casi sin límite: de muy cerca a muy lejos)
Tecla 1: Herramienta Orbitar
Tecla 2: Herramienta Mano (Pan). Úsala también para meterte dentro de un modelo.
Tecla 3: Vista de cámara (mirar a través de la cámara de la escena, si hay una)
Alt + X / Y / Z: Vista alineada a ese eje (repetir alterna al lado opuesto)
 
[b]Edición[/b]
Shift + A: Menú de añadir: figuras (cubo, esfera, triángulo, plano), luces (sol, foco, punto), cámaras, música, video/GIF y modelos 3D
Clic izquierdo: Seleccionar (funciona con cualquier herramienta activa)
Clic derecho (con algo seleccionado): abre el menú de ese objeto en cualquier parte de la vista, no hace falta apuntarle justo encima.
  Luz: propiedades / Cámara: ver, seguir o fondo / Música y video: sus propiedades / Otros: Eliminar
G: Mover objeto seleccionado (después presionar X/Y/Z para restringir eje)
S: Escalar objeto seleccionado, en las tres direcciones a la vez (después presionar X/Y/Z para restringir a un solo eje)
Enter o clic izquierdo: Confirmar movimiento o escala
Escape o clic derecho: Cancelar movimiento o escala
Ctrl + Z / Ctrl + Y: Deshacer / Rehacer. Cambiar o crear una animación, o editar el origen, vacía el historial.
Shift + B: Abrir el cuadro de tamaños visuales (huesos y gizmo del objeto)
 
[b]Herramientas (barra lateral)[/b]
Seleccionar, Mover, Rotar, Escalar, IK y Colisión.
Colisión: ajusta la caja de colisión de un objeto, útil cuando un modelo importado la trae mal.
  C: escalar la colisión con teclado / V: moverla (X/Y/Z restringe el eje, Enter confirma, Escape cancela)
  Shift + C: panel con el tamaño y la posición exacta de la colisión.
 
[b]Origen (punto de giro) del objeto[/b]
Shift + O con un objeto seleccionado: aparece una esfera cian (el origen) con flechas para arrastrarlo, y un panel con los valores X/Y/Z para ajustar a mano. Los cambios se ven en vivo.
"Al centro" y "A la base" lo ubican rápido.
Mover el origen NO mueve el objeto ni rompe sus animaciones: solo cambia el punto alrededor del cual gira y escala. Útil para hélices, puertas, ruedas, etc.
Cambiar de herramienta cierra el panel y lo ya aplicado se conserva.
 
[b]Luces[/b]
Clic derecho con una luz seleccionada: panel con intensidad, sombra, color y, solo en el Foco, el Rango (qué tan lejos y grande alumbra).
Para animar un parpadeo, cambiá la intensidad y poné un keyframe con el diamante en cada cuadro.
Al renderizar, las esferitas guía de las luces se ocultan solas.
 
[b]Cámaras de la escena[/b]
Clic derecho con una cámara seleccionada: Ver desde esta cámara, Seguir en vivo, o Fondo y campo de visión.
Fondo y campo de visión: color de fondo propio y ángulo de la lente. Solo afecta lo que ve esa cámara y lo que renderiza, no tu vista de trabajo.
Para salir de la vista de una cámara, mové la vista con el mouse como siempre y tu vista vuelve a la normalidad, con el mismo zoom que tenías.
 
[b]Jerarquía (padres e hijos)[/b]
En la lista de objetos (Outliner), arrastrar un objeto sobre otro lo convierte en su hijo.
Mover/rotar/escalar un objeto padre también afecta a sus hijos.
Clic derecho sobre un objeto → "Convertir en hijo de" / "Sacar de su padre".
Borrar un objeto padre borra también a sus hijos.
Arrastrar un objeto a una carpeta lo organiza ahí (doble clic en el nombre de una carpeta para renombrarla).
Clic derecho → "Duplicar" (con o sin animación).
 
[b]Mapas, cielos y fondos (clic derecho en el Outliner)[/b]
Desactivar colisión (para mapas): el clic del mouse atraviesa el objeto y podés seleccionar lo que hay dentro o encima. Un objeto sin colisión se selecciona desde el Outliner (marcado con 🚫). Se vuelve a activar desde el mismo menú.
Ver por dentro (doble cara): en figuras, dibuja también la cara interior, como en Blender.
Sin iluminación (cielo/fondo): la textura se ve con sus colores reales, sin luces ni sombras.
Para un cielo: esfera grande + textura + Ver por dentro + Sin iluminación (y, si querés, sin colisión). Ponele la textura primero.
Estas dos opciones también hacen que la figura no proyecte sombras.
 
[b]Modelos importados (.glb / .gltf)[/b]
Shift + A → Importar Modelo, para traer un modelo 3D con huesos o sin ellos.
En el Outliner, un modelo con piezas internas muestra una flechita ▼/▶ para desplegarlas.
Clic en una pieza: la resalta en amarillo. Clic derecho sobre una pieza: Eliminar esa parte (recuperable con Ctrl+Z).
El ojo de cada fila muestra/oculta esa pieza puntual.
Convertir en objeto independiente (clic derecho sobre una pieza): la pieza pasa a ser un objeto propio con su propia animación, útil para piezas rígidas como hélices o ruedas. Para devolverla: clic derecho → "Volver a ser parte del modelo".
Las piezas eliminadas y las piezas independientes se guardan con el proyecto.
Adjuntar a hueso: clic derecho sobre un objeto (por ejemplo una luz) en el Outliner. Al final del menú aparece la lista de huesos del modelo. El objeto sigue a ese hueso, también cuando lo animás. Para soltarlo: "Sacar de su padre". Los huesos que quedan vacíos muestran un 🗑 en el Outliner para limpiarlos.
 
[b]Huesos (modo Animación)[/b]
Con un modelo con esqueleto seleccionado, clic sobre una bolita blanca: selecciona ese hueso (queda magenta).
Con la herramienta Mover/Rotar/Escalar activa, aparece el gizmo correspondiente sobre el hueso.
G, sobre un hueso: moverlo con teclado (X/Y/Z para restringir eje), igual que un objeto.
Herramienta IK: aparece una esfera cian sobre el hueso. Arrastrala para que esa parte del cuerpo (mano, pie) la siga, doblando el resto de la cadena automáticamente. La esfera acompaña a la mano cuando movés la línea de tiempo.
El diamante de keyframe graba la pose del brazo (hombro y codo), llegues a ella con IK o rotando a mano. Podés mezclar las dos técnicas cuadro por cuadro.
Consejo: antes de usar IK en una extremidad, poné un diamante en el cuadro 0 en cada hueso de la cadena con FK. Así el IK no cambia lo que ya animaste.
La pose que dejes en los huesos sin diamante se conserva al cambiar de animación.
Shift + B: si las bolitas o los gizmos se ven demasiado grandes en un modelo, achicalos desde ese cuadro. El ajuste se guarda con el proyecto.
 
[b]Animación[/b]
Shift + T (con un objeto seleccionado): panel de animaciones de ese objeto. Cada objeto tiene su propia lista: escribí un nombre ("correr", "saltar"...) y creá cuantas quieras. Al elegir una, la barra de tiempo muestra solo esa.
Un objeto sin animación tiene la barra de tiempo bloqueada hasta que crees una. Los videos y la música usan la barra libremente.
Al reproducir, cada objeto mueve su animación activa. Una animación nueva empieza desde la pose de reposo.
Duplicar con animación copia todas las animaciones; duplicar sin animación nace limpio.
Clic en la barra de tiempo (o arrastrar el cabezal): Mover el cabezal de reproducción
Rueda del mouse sobre la barra: Desplazar la línea de tiempo
Ctrl + Rueda sobre la barra: Zoom de la línea de tiempo
Diamante: Agregar keyframe en el cuadro actual (si ya había uno, lo reemplaza)
Clic derecho sobre un keyframe: Eliminarlo
Arrastrar un keyframe: Moverlo a otro cuadro
Agregar, borrar y mover keyframes se pueden deshacer con Ctrl + Z.
 
[b]Materiales y texturas (panel de Materiales, modo Editar)[/b]
Botón +: crea una muestra nueva. Clic derecho sobre ella: cambiar color, textura, rugosidad y metálico. Clic izquierdo: aplicarla a lo que tengas resaltado en el Outliner.
Al seleccionar un modelo importado aparece, junto al +, un cuadrito por cada textura que el modelo trae:
  Clic izquierdo: elegir una imagen nueva para esa textura (se aplica a todas las piezas que la comparten).
  Clic derecho: abrir la librería con todas las texturas del modelo y las que ya usaste en la sesión.
Estos cuadritos aparecen solo con el modelo seleccionado, para no mezclarse con la paleta manual.
Los cambios de textura en modelos se guardan con el proyecto.
 
[b]Opciones: iluminación, render y exportación[/b]
Brillo general: un solo número para todas las luces del estudio y el ambiente. 1 es lo normal, 0 deja todo a oscuras, los negativos oscurecen aún más y valores mayores a 1 iluminan de más. Sirve para que se noten mejor las luces que ponés vos.
FPS del proyecto e interpolación (Curva / Suave / Lineal).
Video-Foto: foto PNG, video como secuencia de imágenes o MP4, eligiendo el rango de cuadros y la resolución.
El render usa la cámara de la escena, con su fondo y campo de visión, y solo la animación que cada objeto tenga activa en ese momento.
Exportar: guarda todo el proyecto como .glb o .gltf con TODAS las animaciones de cada objeto. Al importarlo en Godot, los nombres aparecen en el nodo AnimationPlayer. Si una animación se llama igual en varios objetos, queda una sola con todos sus tracks.
F10: si un render se queda colgado y el motor no responde, destraba la vista (no cancela el render, solo libera los controles).



[b]Proyectos[/b]
Ctrl + S: Guardar el proyecto actual
Ctrl + Q: Guardar y volver al menú principal
Si cerrás el programa de otra forma, se pierde lo hecho desde el último guardado.
Desde este menú: Exportar un proyecto a un archivo (.b3dproj) para pasarlo a otra compu, o Importar uno que hayas exportado antes.
Se guarda: objetos y su jerarquía, luces (color, intensidad, sombra, rango), cámaras (fondo y campo de visión), todas las animaciones de cada objeto (objetos y huesos), modelos con sus cambios de textura, piezas independientes y piezas eliminadas, objetos adjuntos a huesos, colisiones editadas, opciones de superficie, brillo general, y los tamaños de huesos y gizmos.
 
[b]LIMITACIONES CONOCIDAS[/b]
 
Objetos superpuestos (uno dentro de otro):
El clic selecciona el objeto más cercano a la cámara en ese punto.
Si un objeto queda tapado por otro, seleccionalo desde el Outliner
(la lista de objetos) y usá G + X / Y / Z para moverlo, o
desactivá la colisión del objeto que estorba.
 
Objetos muy pequeños:
Las manijas de mover/rotar/escalar tienen un tamaño mínimo fijo
para que siempre se puedan tomar con el mouse. Si en un modelo se
ven demasiado grandes, usá Shift + B para achicarlas.
 
Huesos e IK:
El IK resuelve cadenas de tres huesos (por ejemplo hombro, codo y
mano), sin control de hacia dónde apunta el codo. Al poner un
keyframe se graba la pose del brazo, no el punto en el espacio al
que apuntaba la mano. Si después movés el cuerpo entero, la mano
no se queda pegada a ese punto.
Deshacer un keyframe puesto con IK necesita dos Ctrl + Z (uno por
hombro y otro por codo).
 
Animaciones:
Cambiar o crear una animación vacía el historial de Ctrl + Z.
Borrar una animación no se puede deshacer.
La intensidad animada de las luces no se guarda en la animación activa
al guardar el proyecto.
 
Origen del objeto:
Cambiar el origen no se puede deshacer con Ctrl + Z. Se edita sobre
el objeto, no sobre los huesos.
 
Exportar a .glb / .gltf:
No incluye videos, música, la intensidad animada de las luces ni las
colisiones. Los objetos adjuntos a un hueso salen sueltos. La
animación se exporta cuadro por cuadro (se ve igual que en el motor,
pero no queda editable como curva). Con .gltf, Godot escribe además
un .bin y las texturas: usá una carpeta propia.
 
Adjuntar a hueso:
Si la escena tiene varios modelos con esqueleto, la lista de huesos
muestra los del primero que se encuentre.
Adjuntar un objeto a un hueso no se puede deshacer con Ctrl + Z;
usá "Sacar de su padre".
 
Texturas de modelos:
Solo se guardan los cambios de imagen (textura). Los cambios de
solo color, rugosidad o metálico sobre piezas de un modelo no se
guardan. Cambiar una textura tampoco se puede deshacer con Ctrl + Z.
Las texturas cambiadas en una pieza convertida en objeto
independiente no se guardan.
 
Tamaño de los proyectos:
El proyecto guarda todo adentro (modelos, audio, video), por eso
puede pesar bastante si usás archivos grandes.
 
Música en formato MP3:
Se puede importar, pero al reproducirse en loop puede notarse
un pequeño salto en el punto donde vuelve a empezar (una
limitación del formato MP3 en sí, no del motor). Para música
de fondo larga, WAV u OGG dan un loop perfecto.
 
Modelos .gltf (a diferencia de .glb):
Si el .gltf depende de archivos sueltos (texturas, .bin) que no
están en la misma carpeta al importar, el modelo puede entrar
sin texturas. El panel de Materiales permite pintar una pieza
puntual a mano como solución rápida.
 
Sistema:
Los selectores de archivos y la exportación a MP4 están pensados
para Windows. Para exportar MP4 y para importar video/GIF, el
archivo ffmpeg.exe tiene que estar en la carpeta "ffmpeg", al lado
del ejecutable del motor. No hace falta instalar nada más.
 
[b]Créditos[/b]
Programación: Claude (Anthropic)
Dirección y visión: Lostie
Hecho con Godot Engine
Video y MP4: FFmpeg (ffmpeg.org), distribuido bajo su propia licencia."""

func load_projects() -> void:
	projects.clear()
	if FileAccess.file_exists(PROJECTS_FILE):
		var file := FileAccess.open(PROJECTS_FILE, FileAccess.READ)
		var content: String = file.get_as_text()
		file.close()
		var parsed = JSON.parse_string(content)
		if parsed is Array:
			projects = parsed
	projects.sort_custom(func(a, b): return a.to_lower() < b.to_lower())

func save_projects() -> void:
	var file := FileAccess.open(PROJECTS_FILE, FileAccess.WRITE)
	file.store_string(JSON.stringify(projects))
	file.close()

func refresh_projects_list() -> void:
	for child in projects_list.get_children():
		child.queue_free()

	for project_name in projects:
		add_project_row(project_name)

	add_new_project_button()
	add_import_button()

func add_project_row(project_name: String) -> void:
	var row := HBoxContainer.new()

	var label := Label.new()
	label.text = project_name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var open_button := Button.new()
	open_button.text = "Abrir"
	open_button.pressed.connect(func(): open_project(project_name))
	row.add_child(open_button)
	
	var export_button := Button.new()
	export_button.text = "Exportar"
	export_button.pressed.connect(func(): export_project(project_name))
	row.add_child(export_button)

	var delete_button := Button.new()
	delete_button.text = "Borrar"
	delete_button.pressed.connect(func(): delete_project(project_name))
	row.add_child(delete_button)

	projects_list.add_child(row)

func add_new_project_button() -> void:
	var new_button := Button.new()
	new_button.text = "+ Nuevo Proyecto"
	new_button.pressed.connect(_on_new_project_pressed)
	projects_list.add_child(new_button)

func _on_new_project_pressed() -> void:
	var index: int = 1
	var base_name := "Proyecto"
	var final_name := "%s %d" % [base_name, index]
	while projects.has(final_name) or FileAccess.file_exists("user://projects/" + final_name + "/project.json"):
		index += 1
		final_name = "%s %d" % [base_name, index]

	projects.append(final_name)
	projects.sort_custom(func(a, b): return a.to_lower() < b.to_lower())
	save_projects()
	refresh_projects_list()

	var stale_path: String = "user://projects/" + final_name + "/project.json"
	if FileAccess.file_exists(stale_path):
		DirAccess.remove_absolute(stale_path)

	open_project(final_name)

func delete_project(project_name: String) -> void:
	projects.erase(project_name)
	save_projects()
	refresh_projects_list()

func open_project(project_name: String) -> void:
	ProjectSession.current_project_name = project_name
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)

func add_import_button() -> void:
	var import_button := Button.new()
	import_button.text = "Importar Proyecto"
	import_button.pressed.connect(import_project)
	projects_list.add_child(import_button)

func export_project(project_name: String) -> void:
	var source_path: String = "user://projects/" + project_name + "/project.json"
	if not FileAccess.file_exists(source_path):
		return

	var dest_path: String = pick_save_path_native(project_name)
	if dest_path == "":
		return

	var file := FileAccess.open(source_path, FileAccess.READ)
	var content: String = file.get_as_text()
	file.close()

	var out := FileAccess.open(dest_path, FileAccess.WRITE)
	out.store_string(content)
	out.close()

func pick_save_path_native(default_name: String) -> String:
	var output: Array = []
	var script := 'Add-Type -AssemblyName System.Windows.Forms; $dialog = New-Object System.Windows.Forms.SaveFileDialog; $dialog.Filter = \'Proyecto Bult3D (*.b3dproj)|*.b3dproj\'; $dialog.FileName = \'' + default_name + '.b3dproj\'; if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Write-Output $dialog.FileName }'
	OS.execute("powershell", ["-NoProfile", "-Command", script], output, true)
	if output.size() > 0:
		return output[0].strip_edges()
	return ""

func import_project() -> void:
	var path: String = pick_open_project_native()
	if path == "":
		return

	var file := FileAccess.open(path, FileAccess.READ)
	var content: String = file.get_as_text()
	file.close()

	var base_name: String = path.get_file().get_basename()
	var final_name: String = base_name
	var index: int = 1
	while projects.has(final_name):
		final_name = "%s (%d)" % [base_name, index]
		index += 1

	var dest_dir: String = "user://projects/" + final_name
	DirAccess.make_dir_recursive_absolute(dest_dir)
	var out := FileAccess.open(dest_dir + "/project.json", FileAccess.WRITE)
	out.store_string(content)
	out.close()

	projects.append(final_name)
	projects.sort_custom(func(a, b): return a.to_lower() < b.to_lower())
	save_projects()
	refresh_projects_list()

func pick_open_project_native() -> String:
	var output: Array = []
	var script := 'Add-Type -AssemblyName System.Windows.Forms; $dialog = New-Object System.Windows.Forms.OpenFileDialog; $dialog.Filter = \'Proyecto Bult3D (*.b3dproj)|*.b3dproj\'; if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Write-Output $dialog.FileName }'
	OS.execute("powershell", ["-NoProfile", "-Command", script], output, true)
	if output.size() > 0:
		return output[0].strip_edges()
	return ""
