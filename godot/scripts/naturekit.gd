class_name NatureKit
extends RefCounted
## Végétation de l'île avec les modèles du Nature Kit (Kenney) : feuillus en plaine, pins en altitude,
## palmiers sur la côte, cactus dans le désert. Rendu instancié (MultiMesh), donc très léger.

const BASE := "res://assets/nature-kit/"
const BROADLEAF := ["tree_oak", "tree_default", "tree_detailed", "tree_fat", "tree_tall"]
const PINES := ["tree_pineTallA_detailed", "tree_pineRoundB", "tree_pineTallC_detailed", "tree_cone"]
const PALMS := ["tree_palmTall", "tree_palmBend", "tree_palmDetailedTall"]
const CACTI := ["cactus_tall", "cactus_short"]

static func _path(name: String) -> String:
	for ext in [".gltf", ".glb"]:
		if ResourceLoader.exists(BASE + name + ext):
			return BASE + name + ext
	return ""

## [maillage, boîte englobante, transformation locale] du premier maillage du modèle
static func _mesh_of(name: String) -> Array:
	var p := _path(name)
	if p == "":
		return []
	var inst: Node3D = (load(p) as PackedScene).instantiate()
	var mis := inst.find_children("*", "MeshInstance3D", true, false)
	if mis.is_empty():
		inst.free()
		return []
	var mi: MeshInstance3D = mis[0]
	var t := Transform3D()
	var cur: Node = mi
	while cur != inst and cur != null:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	var res := [mi.mesh, t * mi.get_aabb(), t]
	inst.free()
	return res

static func _render_group(isl: Node3D, names: Array, items: Array, height_range: Vector2, vis_end: float) -> void:
	var meshes: Array = []
	for n in names:
		var m := _mesh_of(n)
		if not m.is_empty():
			meshes.append(m)
	if meshes.is_empty():
		return
	var buckets: Array = []
	for k in meshes.size():
		buckets.append([])
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for it in items:
		var pos: Vector3 = it[0]
		var k := rng.randi() % meshes.size()
		var m: Array = meshes[k]
		var box: AABB = m[1]
		var target := rng.randf_range(height_range.x, height_range.y) * float(it[1])
		var s := target / maxf(box.size.y, 0.01)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), pos - Vector3(0, box.position.y * s - 0.1, 0)) * (m[2] as Transform3D)
		buckets[k].append(xf)
	for k in meshes.size():
		if (buckets[k] as Array).is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[k][0]
		mm.instance_count = (buckets[k] as Array).size()
		for i in mm.instance_count:
			mm.set_instance_transform(i, buckets[k][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.visibility_range_end = vis_end
		isl.add_child(mmi)

## Renvoie true si le Nature Kit est installé et que la végétation a été posée
static func render(isl: Node3D, trees: Array, palms: Array, cacti: Array) -> bool:
	if _path("tree_oak") == "":
		return false
	var low: Array = []
	var high: Array = []
	for t in trees:
		if (t[0] as Vector3).y > 40.0:
			high.append(t)
		else:
			low.append(t)
	_render_group(isl, BROADLEAF, low, Vector2(7.0, 10.0), 2200.0)
	_render_group(isl, PINES, high, Vector2(9.0, 14.0), 2400.0)
	_render_group(isl, PALMS, palms, Vector2(8.0, 11.0), 1800.0)
	var cac: Array = []
	for c in cacti:
		cac.append([(c as Transform3D).origin, 1.0])
	_render_group(isl, CACTI, cac, Vector2(3.0, 5.5), 1200.0)
	return true
