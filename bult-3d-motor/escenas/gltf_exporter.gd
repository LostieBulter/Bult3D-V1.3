extends RefCounted

var selection_manager: Node
var animation_manager: Node

func export_project(path: String) -> int:
	var objects: Array = animation_manager.get_all_scene_objects()

	# La animación activa de cada objeto vive en keyframes/bone_keyframes: la guardamos en su lista
	for obj in objects:
		var cur: String = obj.get_meta("current_animation", "")
		if cur != "":
			animation_manager._stash_animation(obj, cur)

	var root := Node3D.new()
	root.name = "Proyecto"
	var copies: Dictionary = {}

	for obj in objects:
		if obj.has_meta("is_video") or obj.get_node_or_null("AudioSource") != null:
			continue
		var copy: Node3D = _make_copy(obj)
		var parent_obj: Node = obj.get_parent()
		if copies.has(parent_obj):
			copies[parent_obj].add_child(copy)
		else:
			root.add_child(copy)
			if parent_obj is BoneAttachment3D:
				copy.transform = obj.global_transform  # adjunto a un hueso: se exporta suelto
		copies[obj] = copy

	var anims: Dictionary = {}
	var fps: float = animation_manager.FPS
	for obj in objects:
		if not copies.has(obj):
			continue
		var store: Dictionary = obj.get_meta("animations", {})
		for anim_name in obj.get_meta("animation_names", []):
			var data: Dictionary = store.get(anim_name, {})
			var safe_name: String = _safe_name(anim_name)
			var anim: Animation = anims.get(safe_name)
			if anim == null:
				anim = Animation.new()
				anims[safe_name] = anim
			_add_object_tracks(anim, root, copies[obj], data.get("keyframes", []), fps)
			_add_bone_tracks(anim, root, copies[obj], data.get("bone_keyframes", {}), fps)

	if not anims.is_empty():
		var lib := AnimationLibrary.new()
		for n in anims.keys():
			var a: Animation = anims[n]
			a.length = max(a.length, 1.0 / fps)
			lib.add_animation(n, a)
		var player := AnimationPlayer.new()
		player.name = "AnimationPlayer"
		root.add_child(player)
		player.add_animation_library("", lib)

	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err: int = doc.append_from_scene(root, state)
	if err == OK:
		err = doc.write_to_filesystem(state, path)
	root.free()
	return err

func _safe_name(n: String) -> String:
	return n.replace("/", "_").replace(":", "_").replace(",", "_").replace("[", "_").replace("]", "_")

func _make_copy(obj: StaticBody3D) -> Node3D:
	var n := Node3D.new()
	n.name = obj.name
	n.transform = obj.transform
	n.visible = obj.visible

	var model: Node = obj.get_node_or_null("ImportedModel")
	if model != null:
		var m: Node = model.duplicate()
		n.add_child(m)
		_strip_attachments(m)
		_bake_material_overrides(m)
		return n

	var light: Node = obj.get_node_or_null("LightSource")
	var cam: Node = obj.get_node_or_null("CameraSource")
	if light != null:
		n.add_child(light.duplicate())
	elif cam != null:
		n.add_child(cam.duplicate())
	else:
		var mesh: Node = obj.get_node_or_null("Mesh")
		if mesh != null:
			var mc: Node = mesh.duplicate()
			n.add_child(mc)
			_bake_material_overrides(mc)
	return n

func _strip_attachments(node: Node) -> void:
	for c in node.get_children():
		if c is BoneAttachment3D:
			node.remove_child(c)
			c.free()
		else:
			_strip_attachments(c)

# El exportador glTF lee los materiales por superficie, no el material_override
func _bake_material_overrides(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null and node.material_override != null:
		for i in node.mesh.get_surface_count():
			node.set_surface_override_material(i, node.material_override)
		node.material_override = null
	for c in node.get_children():
		_bake_material_overrides(c)

# Devuelve [key_anterior, key_siguiente, t_con_suavizado]
func _pair(keys: Array, frame: int) -> Array:
	var prev = null
	var next = null
	for key in keys:
		if key["frame"] <= frame:
			prev = key
		if key["frame"] >= frame and next == null:
			next = key
	if prev == null:
		prev = keys[0]
	if next == null:
		next = keys[keys.size() - 1]
	var t := 0.0
	if prev["frame"] != next["frame"]:
		t = clamp(float(frame - prev["frame"]) / float(next["frame"] - prev["frame"]), 0.0, 1.0)
		t = animation_manager._ease(t)
	return [prev, next, t]

func _add_object_tracks(anim: Animation, root: Node, node: Node, keys: Array, fps: float) -> void:
	if keys.is_empty():
		return
	var path := NodePath(str(root.get_path_to(node)))
	var tp: int = anim.add_track(Animation.TYPE_POSITION_3D)
	var tr: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	var ts: int = anim.add_track(Animation.TYPE_SCALE_3D)
	anim.track_set_path(tp, path)
	anim.track_set_path(tr, path)
	anim.track_set_path(ts, path)

	var last: int = keys[keys.size() - 1]["frame"]
	for f in range(0, last + 1):
		var p: Array = _pair(keys, f)
		var a: Dictionary = p[0]
		var b: Dictionary = p[1]
		var t: float = p[2]
		var time: float = float(f) / fps
		var pos: Vector3 = a["position"].lerp(b["position"], t)
		var rot: Vector3 = a["rotation"].lerp(b["rotation"], t)
		var scl: Vector3 = a["scale"].lerp(b["scale"], t)
		anim.position_track_insert_key(tp, time, pos)
		anim.rotation_track_insert_key(tr, time, Quaternion.from_euler(rot * (PI / 180.0)))
		anim.scale_track_insert_key(ts, time, scl)
	anim.length = max(anim.length, float(last) / fps)

func _add_bone_tracks(anim: Animation, root: Node, node: Node, bone_keyframes: Dictionary, fps: float) -> void:
	if bone_keyframes.is_empty():
		return
	var skeleton: Skeleton3D = selection_manager.find_skeleton_in(node)
	if skeleton == null:
		return
	var skel_path: String = str(root.get_path_to(skeleton))

	for bone_idx in bone_keyframes.keys():
		var keys: Array = bone_keyframes[bone_idx]
		if keys.is_empty() or int(bone_idx) >= skeleton.get_bone_count():
			continue
		var path := NodePath(skel_path + ":" + skeleton.get_bone_name(int(bone_idx)))
		var tp: int = anim.add_track(Animation.TYPE_POSITION_3D)
		var tr: int = anim.add_track(Animation.TYPE_ROTATION_3D)
		var ts: int = anim.add_track(Animation.TYPE_SCALE_3D)
		anim.track_set_path(tp, path)
		anim.track_set_path(tr, path)
		anim.track_set_path(ts, path)

		var last: int = keys[keys.size() - 1]["frame"]
		for f in range(0, last + 1):
			var p: Array = _pair(keys, f)
			var a: Dictionary = p[0]
			var b: Dictionary = p[1]
			var t: float = p[2]
			var time: float = float(f) / fps
			var pos: Vector3 = a.get("position", Vector3.ZERO).lerp(b.get("position", Vector3.ZERO), t)
			var scl: Vector3 = a.get("scale", Vector3.ONE).lerp(b.get("scale", Vector3.ONE), t)
			var q: Quaternion = (a["rotation"] as Quaternion).slerp(b["rotation"], t)
			anim.position_track_insert_key(tp, time, pos)
			anim.rotation_track_insert_key(tr, time, q)
			anim.scale_track_insert_key(ts, time, scl)
		anim.length = max(anim.length, float(last) / fps)
