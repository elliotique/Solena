class_name KenneyLib
extends RefCounted
## Bâtiments des packs Kenney : tours et immeubles en ville, maisons de banlieue, zone industrielle.
## Chaque modèle est mis à l'échelle réelle à partir de sa boîte englobante, tourné vers la route,
## et reçoit une collision. Si les packs sont absents, le jeu garde les bâtiments générés.

const COMMERCIAL := ["building-a", "building-b", "building-c", "building-d", "building-e", "building-f", "building-g",
	"building-h", "building-i", "building-j", "building-k", "building-l", "building-m", "building-n"]
const TOWERS := ["building-skyscraper-a", "building-skyscraper-b", "building-skyscraper-c", "building-skyscraper-d", "building-skyscraper-e"]
const HOUSES := ["building-type-a", "building-type-b", "building-type-c", "building-type-d", "building-type-e", "building-type-f",
	"building-type-g", "building-type-h", "building-type-i", "building-type-j", "building-type-k", "building-type-l", "building-type-m",
	"building-type-n", "building-type-o", "building-type-p", "building-type-q", "building-type-r", "building-type-s", "building-type-t", "building-type-u"]
const FACTORIES := ["building-a", "building-b", "building-c", "building-e", "building-f", "building-g", "building-l", "building-m",
	"building-q", "building-r", "building-t"]

static var _scenes := {}
static var _boxes := {}
static var available := -1
static var night_mat: StandardMaterial3D

static func _night_material() -> StandardMaterial3D:
	if night_mat == null:
		var imgs := Kit._facade_images(0)
		night_mat = StandardMaterial3D.new()
		night_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		night_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		night_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		night_mat.albedo_texture = imgs[2]
		night_mat.albedo_color = Color(0, 0, 0)
		night_mat.uv1_triplanar = true
		night_mat.uv1_world_triplanar = true
		night_mat.uv1_scale = Vector3.ONE / 9.6
	return night_mat

static func has_packs() -> bool:
	if available < 0:
		available = 1 if ResourceLoader.exists("res://assets/city-kit-commercial/building-a.glb") else 0
	return available == 1

static func _scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path) if ResourceLoader.exists(path) else null
	return _scenes[path]

static func _box(path: String, inst: Node3D) -> AABB:
	if _boxes.has(path):
		return _boxes[path]
	var a := AABB()
	var first := true
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D()
		var cur: Node = m
		while cur != inst and cur != null:
			if cur is Node3D:
				t = (cur as Node3D).transform * t
			cur = cur.get_parent()
		var b := t * (m as MeshInstance3D).get_aabb()
		a = b if first else a.merge(b)
		first = false
	_boxes[path] = a
	return a

## Place un modèle : base au sol en `pos`, façade (+Z du modèle) tournée vers `facing`,
## taille ajustée à l'emprise (larg. le long de la rue, prof.) ; `sy_mul` étire la hauteur.
static func place(parent: Node3D, body: StaticBody3D, path: String, pos: Vector3, facing: Vector3, width: float, depth: float, sy_mul := 1.0, lit := false) -> Node3D:
	var ps := _scene(path)
	if ps == null:
		return null
	var inst: Node3D = ps.instantiate()
	var box := _box(path, inst)
	var s := minf(width / maxf(box.size.x, 0.05), depth / maxf(box.size.z, 0.05)) * 0.97
	var sy := s * sy_mul
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.global_position = pos
	holder.rotation.y = atan2(facing.x, facing.z)
	inst.scale = Vector3(s, sy, s)
	inst.position = Vector3(-(box.position.x + box.size.x * 0.5) * s, -box.position.y * sy, -(box.position.z + box.size.z * 0.5) * s)
	holder.add_child(inst)
	if lit:
		var ov := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(box.size.x * s * 1.012, box.size.y * sy * 0.94, box.size.z * s * 1.012)
		ov.mesh = bm
		ov.material_override = _night_material()
		ov.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ov.position.y = bm.size.y * 0.5 + box.size.y * sy * 0.02
		holder.add_child(ov)
	if body != null:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(box.size.x * s, box.size.y * sy, box.size.z * s)
		cs.shape = sh
		body.add_child(cs)
		cs.global_transform = Transform3D(Basis(Vector3.UP, holder.rotation.y), pos + Vector3(0, sh.size.y * 0.5, 0))
	return holder

## Immeuble de ville (remplace le bâtiment généré) ; renvoie false si les packs sont absents.
static func city_building(world: Node3D, body: StaticBody3D, pos: Vector3, size: Vector3, street: Vector3, h: float, rng: RandomNumberGenerator) -> bool:
	if not has_packs():
		return false
	var along_x := street.z != 0.0
	var w := size.x if along_x else size.z       # largeur le long de la rue
	var d := size.z if along_x else size.x       # profondeur
	var gp := world.global_position + pos + Vector3(0, 0.15, 0)
	if h > 45.0:
		var name: String = TOWERS[rng.randi() % TOWERS.size()]
		var path := "res://assets/city-kit-commercial/%s.glb" % name
		var ps := _scene(path)
		if ps == null:
			return false
		var tmp: Node3D = ps.instantiate()
		var box := _box(path, tmp)
		tmp.free()
		var s := minf(w / box.size.x, d / box.size.z) * 0.97
		var mul := clampf(h / (box.size.y * s), 0.85, 1.7)
		place(world, body, path, gp, street, w, d, mul, true)
	else:
		var name2: String = COMMERCIAL[rng.randi() % COMMERCIAL.size()]
		var path2 := "res://assets/city-kit-commercial/%s.glb" % name2
		var ps2 := _scene(path2)
		if ps2 == null:
			return false
		var tmp2: Node3D = ps2.instantiate()
		var box2 := _box(path2, tmp2)
		tmp2.free()
		var s2 := minf(w / box2.size.x, d / box2.size.z) * 0.97
		var mul2 := clampf(h / (box2.size.y * s2), 0.8, 1.35)
		place(world, body, path2, gp, street, w, d, mul2, true)
	return true

## Maisons de banlieue le long des routes près des villes, et zone industrielle vers l'aéroport de Solena
static func dress_island(island: Island) -> void:
	if not has_packs():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var placed: Array[Vector2] = []
	for r in island.roads:
		if r.kind == "highway" or r.kind == "rail":
			continue
		var pts: PackedVector3Array = r.pts
		var i := 0
		while i < pts.size() - 2:
			var p := pts[i]
			var p2 := Vector2(p.x, p.z)
			var dc := minf(p2.distance_to(Island.CITY_A), p2.distance_to(Island.CITY_B))
			var t := pts[mini(i + 2, pts.size() - 1)] - pts[maxi(i - 2, 0)]
			t.y = 0
			t = t.normalized()
			var n := Vector3(-t.z, 0, t.x)
			var industrial: bool = r.name == "Avenue de l'Aéroport" and dc > 600.0 and dc < 1500.0
			if (dc > 520.0 and dc < 1250.0) or industrial:
				for side in [-1.0, 1.0]:
					if rng.randf() < (0.75 if industrial else 0.6):
						var off := float(r.w) + (26.0 if industrial else 17.0)
						var hp: Vector3 = p + n * float(side) * off
						var h2 := Vector2(hp.x, hp.z)
						if island.in_city(h2, 30.0) or island._near_airport(h2, 60.0) or island.desert_amount(h2) > 0.4:
							continue
						var ok := true
						for q in placed:
							if q.distance_to(h2) < (34.0 if industrial else 22.0):
								ok = false
								break
						if not ok:
							continue
						var y := island.height_at(hp.x, hp.z)
						var y2 := island.height_at(hp.x + 8, hp.z + 8)
						if absf(y - y2) > 2.5 or y < 0.5:
							continue
						placed.append(h2)
						var facing: Vector3 = -n * float(side)
						if industrial:
							var nm: String = FACTORIES[rng.randi() % FACTORIES.size()]
							place(island, island.body, "res://assets/city-kit-industrial/%s.glb" % nm, Vector3(hp.x, y - 0.3, hp.z), facing, 30.0, 26.0)
						else:
							var nm2: String = HOUSES[rng.randi() % HOUSES.size()]
							place(island, island.body, "res://assets/city-kit-suburban/%s.glb" % nm2, Vector3(hp.x, y - 0.2, hp.z), facing, 13.0, 12.0, 1.0, true)
			i += 4 if industrial else 3
	# repères de la zone industrielle : château d'eau et cheminées
	var c := Vector3(1000, 0, -520)
	for k in 3:
		var pp := c + Vector3(k * 60.0 - 60.0, 0, 90.0)
		var yy := island.height_at(pp.x, pp.z)
		if not island.near_flat(Vector2(pp.x, pp.z), 0.5):
			place(island, island.body, "res://assets/city-kit-industrial/%s.glb" % ["water-tower", "chimney-large", "detail-tank-large"][k], Vector3(pp.x, yy - 0.2, pp.z), Vector3(0, 0, 1), 12.0, 12.0)
