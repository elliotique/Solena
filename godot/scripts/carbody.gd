class_name CarBody
extends RefCounted
## Carrosseries arrondies (profils latéraux lissés + arêtes biseautées), phares, feux, jantes.
## Convention : avant de la voiture vers +Z, origine au sol au centre.

const MODELS := {
	"sedan":  {"L": 4.6, "W": 1.84, "R": 0.34, "archR": 0.42, "bottom": 0.28, "arches": [1.05, 3.6],
		"top": [[0, .5], [.04, .8], [.3, .95], [1.1, 1.0], [3.2, .97], [4.1, .84], [4.52, .66], [4.6, .5]],
		"cab": [[1.0, .98], [1.5, 1.33], [2.3, 1.45], [2.95, 1.4], [3.45, .97]]},
	"sports": {"L": 4.4, "W": 1.92, "R": 0.34, "archR": 0.4, "bottom": 0.24, "arches": [1.0, 3.45],
		"top": [[0, .48], [.05, .76], [.4, .9], [1.1, .92], [2.9, .86], [3.8, .7], [4.34, .54], [4.4, .42]],
		"cab": [[1.05, .9], [1.65, 1.16], [2.25, 1.21], [2.7, 1.12], [3.2, .86]]},
	"coupe":  {"L": 4.5, "W": 1.86, "R": 0.34, "archR": 0.42, "bottom": 0.26, "arches": [1.0, 3.55],
		"top": [[0, .5], [.05, .82], [.35, .94], [1.2, .96], [3.1, .93], [4.0, .8], [4.45, .62], [4.5, .48]],
		"cab": [[.8, .95], [1.4, 1.2], [2.2, 1.3], [2.8, 1.25], [3.3, .93]]},
	"hatch":  {"L": 3.9, "W": 1.76, "R": 0.32, "archR": 0.4, "bottom": 0.26, "arches": [.75, 3.2],
		"top": [[0, .55], [.03, .93], [.2, 1.0], [2.7, .98], [3.5, .82], [3.85, .62], [3.9, .46]],
		"cab": [[.12, 1.0], [.28, 1.4], [1.2, 1.5], [2.0, 1.46], [2.8, .98]]},
	"micro":  {"L": 3.6, "W": 1.7, "R": 0.32, "archR": 0.4, "bottom": 0.26, "arches": [.7, 2.9],
		"top": [[0, .5], [.1, .84], [.5, .95], [2.6, .95], [3.3, .84], [3.6, .5]],
		"cab": [[.55, .95], [.9, 1.33], [1.6, 1.5], [2.3, 1.35], [2.7, .95]]},
	"wagon":  {"L": 4.8, "W": 1.84, "R": 0.34, "archR": 0.42, "bottom": 0.28, "arches": [1.05, 3.8],
		"top": [[0, .5], [.03, .85], [.2, .98], [3.3, .98], [4.3, .85], [4.75, .66], [4.8, .5]],
		"cab": [[.2, .98], [.3, 1.42], [2.6, 1.48], [3.1, 1.42], [3.6, .98]]},
	"suv":    {"L": 4.8, "W": 1.98, "R": 0.42, "archR": 0.5, "bottom": 0.36, "arches": [1.05, 3.85],
		"top": [[0, .6], [.03, 1.05], [.2, 1.15], [3.5, 1.15], [4.5, 1.02], [4.78, .8], [4.8, .6]],
		"cab": [[.3, 1.15], [.4, 1.7], [2.8, 1.8], [3.3, 1.72], [3.85, 1.15]]},
	"van":    {"L": 5.0, "W": 2.0, "R": 0.38, "archR": 0.46, "bottom": 0.32, "arches": [1.0, 4.1],
		"top": [[0, .6], [.02, 1.2], [.1, 1.3], [4.1, 1.3], [4.8, 1.0], [5.0, .6]],
		"cab": [[.1, 1.3], [.15, 2.02], [3.3, 2.12], [3.8, 2.0], [4.4, 1.3]]},
	"pickup": {"L": 5.3, "W": 1.98, "R": 0.42, "archR": 0.5, "bottom": 0.38, "arches": [1.1, 4.3],
		"top": [[0, .55], [.02, 1.05], [2.5, 1.08], [4.3, 1.08], [5.05, .98], [5.28, .72], [5.3, .55]],
		"cab": [[2.55, 1.08], [2.65, 1.7], [3.6, 1.76], [3.95, 1.7], [4.4, 1.08]]},
}
const COLORS := [Color("e9e4da"), Color("2f5d8a"), Color("8a2f3a"), Color("3c3c44"), Color("1f1f24"), Color("5b7f4a"),
	Color("f2f2f2"), Color("6a4c93"), Color("1f8a8a"), Color("c2a36b"), Color("9fb3c4"), Color("ff9f4a"), Color("d94f8a")]

static var _mesh_cache := {}
# Modèles 3D Kenney (Car Kit) utilisés à la place des carrosseries générées quand ils sont présents
const KENNEY := {"sedan": "sedan", "sports": "sedan-sports", "coupe": "hatchback-sports", "hatch": "hatchback-sports", "micro": "hatchback-sports", "wagon": "sedan", "suv": "suv", "van": "van", "pickup": "truck", "taxi": "taxi", "police": "police"}
static var _kcache := {}
static var glass: StandardMaterial3D
static var chrome: StandardMaterial3D
static var trim: StandardMaterial3D
static var tire: StandardMaterial3D
static var head_shared: StandardMaterial3D
static var tail_shared: StandardMaterial3D

static func _init_mats() -> void:
	if glass != null:
		return
	glass = StandardMaterial3D.new()
	glass.albedo_color = Color(0.06, 0.09, 0.12)
	glass.metallic = 0.8
	glass.roughness = 0.04
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	chrome = Kit.color_mat(Color(0.85, 0.87, 0.9), 0.15, 1.0)
	trim = Kit.color_mat(Color(0.08, 0.08, 0.09), 0.6)
	tire = Kit.color_mat(Color(0.06, 0.06, 0.065), 0.95)
	head_shared = Kit.glow_mat(Color(1, 0.96, 0.88), 1.0)
	tail_shared = Kit.glow_mat(Color(0.9, 0.05, 0.04), 0.6)

static func base_of(model: String) -> String:
	return "sedan" if model == "taxi" or model == "police" else model

static func info(model: String) -> Dictionary:
	return MODELS[base_of(model)]

static func _meshes(base: String) -> Array:
	if _mesh_cache.has(base):
		return _mesh_cache[base]
	var M: Dictionary = MODELS[base]
	var body := Kit.spline(M.top, 6)
	var bottom: float = M.bottom
	var ar: float = M.archR
	var arches: Array = M.arches.duplicate()
	arches.sort()
	arches.reverse()
	for ax in arches:
		body.append(Vector2(ax + ar, bottom))
		for k in range(0, 13):
			var a := float(k) / 12.0 * PI
			body.append(Vector2(ax + cos(a) * ar, bottom + sin(a) * ar))
	body.append(Vector2(0, bottom))
	var W: float = M.W
	var cab := Kit.spline(M.cab, 6)
	var roof := PackedVector2Array()
	var up := Kit.spline(M.cab.slice(1, M.cab.size() - 1), 5)
	for p in up:
		roof.append(p + Vector2(0, 0.035))
	for i in range(up.size() - 1, -1, -1):
		roof.append(up[i] - Vector2(0, 0.04))
	var L: float = M.L
	var res := [Kit.extrude_rounded(body, W, 0.12, 3, L), Kit.extrude_rounded(cab, W * 0.82, 0.06, 2, L), Kit.extrude_rounded(roof, W * 0.8, 0.05, 2, L)]
	_mesh_cache[base] = res
	return res

## Construit la carrosserie sous `parent`. Renvoie les matériaux utiles (peinture, feux).
static func build(parent: Node3D, model: String, paint_color: Color, with_wheels: bool, unique_lights := false) -> Dictionary:
	_init_mats()
	var base := base_of(model)
	var M: Dictionary = MODELS[base]
	var L: float = M.L
	var W: float = M.W
	var ks := _kenney_scene(model)
	if ks != null:
		return _build_kenney(parent, ks, M, with_wheels, unique_lights)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = paint_color
	paint.metallic = 0.25
	paint.roughness = 0.3
	paint.clearcoat_enabled = true
	paint.clearcoat = 1.0
	paint.clearcoat_roughness = 0.06
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ms := _meshes(base)
	var body_node := Node3D.new()
	body_node.name = "Body"
	parent.add_child(body_node)
	for k in 3:
		var mi := MeshInstance3D.new()
		mi.mesh = ms[k]
		mi.material_override = glass if k == 1 else paint
		body_node.add_child(mi)
	var head := Kit.glow_mat(Color(1, 0.96, 0.88), 1.0) if unique_lights else head_shared
	var tail := Kit.glow_mat(Color(0.9, 0.05, 0.04), 0.6) if unique_lights else tail_shared
	var top: Array = M.top
	var ly: float = top[top.size() - 2][1] - 0.12
	var ty: float = top[1][1] - 0.1
	for side in [-1, 1]:
		_ellipse(body_node, head, Vector3(side * (W / 2 - 0.38), ly, L / 2 - 0.02), 0.13)
		_ellipse(body_node, tail, Vector3(side * (W / 2 - 0.32), ty, -L / 2 + 0.02), 0.1)
		var mir := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 0.1, 0.22)
		mir.mesh = bm
		mir.material_override = paint
		var cabf: Array = M.cab[M.cab.size() - 1]
		mir.position = Vector3(side * (W / 2 + 0.05), M.cab[0][1] + 0.12, cabf[0] - L / 2 - 0.25)
		body_node.add_child(mir)
	# pare-chocs et calandre
	_box(body_node, trim, Vector3(W * 0.88, 0.16, 0.22), Vector3(0, M.bottom + 0.1, L / 2 - 0.08))
	_box(body_node, trim, Vector3(W * 0.88, 0.16, 0.22), Vector3(0, M.bottom + 0.1, -L / 2 + 0.08))
	_box(body_node, chrome, Vector3(W * 0.4, 0.13, 0.04), Vector3(0, ly - 0.14, L / 2 + 0.01))
	if model == "taxi":
		_box(body_node, Kit.glow_mat(Color(1, 0.85, 0.3), 1.2), Vector3(0.7, 0.2, 0.3), Vector3(0, M.cab[2][1] + 0.15, 0))
	if model == "police":
		_box(body_node, Kit.glow_mat(Color(1, 0.1, 0.1), 2.0), Vector3(0.5, 0.14, 0.28), Vector3(-0.3, M.cab[2][1] + 0.12, 0))
		_box(body_node, Kit.glow_mat(Color(0.15, 0.3, 1), 2.0), Vector3(0.5, 0.14, 0.28), Vector3(0.3, M.cab[2][1] + 0.12, 0))
	if with_wheels:
		for ax in M.arches:
			for side in [-1, 1]:
				var w := wheel_visual(M.R)
				w.position = Vector3(side * (W / 2 - 0.12), M.R, ax - L / 2)
				parent.add_child(w)
	return {"paint": paint, "head": head, "tail": tail, "body": body_node}

static func wheel_visual(r: float) -> Node3D:
	_init_mats()
	var n := Node3D.new()
	var t := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = 0.26
	cyl.radial_segments = 24
	t.mesh = cyl
	t.rotation.z = PI / 2.0
	t.material_override = tire
	n.add_child(t)
	var rim := MeshInstance3D.new()
	var rc := CylinderMesh.new()
	rc.top_radius = r * 0.64
	rc.bottom_radius = r * 0.64
	rc.height = 0.28
	rc.radial_segments = 16
	rim.mesh = rc
	rim.rotation.z = PI / 2.0
	rim.material_override = chrome
	n.add_child(rim)
	return n

static func _ellipse(parent: Node3D, m: Material, pos: Vector3, r: float) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = 0.06
	c.radial_segments = 16
	mi.mesh = c
	mi.rotation.x = PI / 2.0
	mi.scale = Vector3(1.6, 1, 1)
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)

static func _box(parent: Node3D, m: Material, size: Vector3, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)

static func _kenney_scene(model: String) -> PackedScene:
	if not KENNEY.has(model):
		return null
	var path: String = "res://assets/car-kit/%s.glb" % KENNEY[model]
	if _kcache.has(path):
		return _kcache[path]
	var ps: PackedScene = null
	if ResourceLoader.exists(path):
		ps = load(path)
	_kcache[path] = ps
	return ps

static func _xf(n: Node, root: Node) -> Transform3D:
	var t := Transform3D()
	var cur := n
	while cur != root and cur != null:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t

## Voiture Kenney mise à l'échelle réelle (longueur et largeur du modèle de jeu), avec feux lumineux
static func _build_kenney(parent: Node3D, ks: PackedScene, M: Dictionary, with_wheels: bool, unique_lights: bool) -> Dictionary:
	var body_node := Node3D.new()
	body_node.name = "Body"
	parent.add_child(body_node)
	var inst: Node3D = ks.instantiate()
	var box := AABB()
	var first := true
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var b := _xf(m, inst) * (m as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	var L: float = M.L
	var W: float = M.W
	var sx := W / maxf(box.size.x, 0.1)
	var sz := L / maxf(box.size.z, 0.1)
	var sy := (sx + sz) * 0.5 * 0.92
	inst.scale = Vector3(sx, sy, sz)
	inst.position = Vector3(-(box.position.x + box.size.x * 0.5) * sx, -box.position.y * sy, -(box.position.z + box.size.z * 0.5) * sz)
	body_node.add_child(inst)
	if not with_wheels:
		for w in inst.find_children("wheel*", "", true, false):
			(w as Node3D).visible = false
	var head := Kit.glow_mat(Color(1, 0.96, 0.88), 1.0) if unique_lights else head_shared
	var tail := Kit.glow_mat(Color(0.9, 0.05, 0.04), 0.6) if unique_lights else tail_shared
	var hy := box.size.y * sy * 0.42
	for side in [-1, 1]:
		_ellipse(body_node, head, Vector3(side * (W / 2 - 0.35), hy, L / 2 + 0.02), 0.12)
		_ellipse(body_node, tail, Vector3(side * (W / 2 - 0.3), hy, -L / 2 - 0.02), 0.1)
	return {"paint": StandardMaterial3D.new(), "head": head, "tail": tail, "body": body_node}
