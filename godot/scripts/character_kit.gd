class_name CharacterKit
extends RefCounted
## Personnage animé Kenney (Animated Characters Retro) : modèle articulé, textures homme/femme,
## animations repos / course / saut récupérées dans les fichiers séparés et ajoutées au personnage.

const BASE := "res://assets/animated-characters-retro/"
static var _scene: PackedScene
static var _lib: AnimationLibrary
static var _skins: Array = []
static var _tried := false

static func _prep() -> bool:
	if _tried:
		return _scene != null
	_tried = true
	if not ResourceLoader.exists(BASE + "characterMedium.fbx"):
		return false
	_scene = load(BASE + "characterMedium.fbx")
	_lib = AnimationLibrary.new()
	for nm in ["idle", "run", "jump"]:
		var p: String = BASE + nm + ".fbx"
		if not ResourceLoader.exists(p):
			continue
		var sc: Node = (load(p) as PackedScene).instantiate()
		var aps := sc.find_children("*", "AnimationPlayer", true, false)
		if aps.size() > 0:
			var ap: AnimationPlayer = aps[0]
			for an in ap.get_animation_list():
				if an == "RESET":
					continue
				var a: Animation = ap.get_animation(an)
				if a != null:
					var cp := a.duplicate() as Animation
					cp.loop_mode = Animation.LOOP_NONE if nm == "jump" else Animation.LOOP_LINEAR
					_lib.add_animation(nm, cp)
					break
		sc.free()
	for s in ["humanMaleA", "humanFemaleA"]:
		if ResourceLoader.exists(BASE + s + ".png"):
			_skins.append(load(BASE + s + ".png"))
	return true

## Crée le personnage sous `parent` (environ 1,8 m) ; renvoie [modèle, AnimationPlayer] ou [] si indisponible
static func make(parent: Node3D, skin: int) -> Array:
	if not _prep():
		return []
	var inst: Node3D = _scene.instantiate()
	parent.add_child(inst)
	var meshes := inst.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		inst.queue_free()
		return []
	var box := AABB()
	var first := true
	for m in meshes:
		var t := Transform3D()
		var cur: Node = m
		while cur != inst and cur != null:
			if cur is Node3D:
				t = (cur as Node3D).transform * t
			cur = cur.get_parent()
		var b := t * (m as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	var s := 1.8 / maxf(box.size.y, 0.01)
	inst.scale = Vector3(s, s, s)
	inst.position.y = -box.position.y * s
	if _skins.size() > 0:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = _skins[skin % _skins.size()]
		mat.roughness = 0.8
		for m in meshes:
			(m as MeshInstance3D).material_override = mat
	var ap: AnimationPlayer = null
	var aps := inst.find_children("*", "AnimationPlayer", true, false)
	if aps.size() > 0:
		ap = aps[0]
	else:
		ap = AnimationPlayer.new()
		inst.add_child(ap)
	if not ap.has_animation_library("kit"):
		ap.add_animation_library("kit", _lib)
	if ap.has_animation("kit/idle"):
		ap.play("kit/idle")
	return [inst, ap]
