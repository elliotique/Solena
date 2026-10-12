class_name World
extends Node3D
## Génère Solena : avenues et rues, trottoirs avec bordures, immeubles texturés, commerces,
## parc, lampadaires, feux, arbres et palmiers, herbe, voitures garées, campagne, plage et mer.

const GRID: Array[float] = [-360.0, -240.0, -120.0, 0.0, 120.0, 240.0, 360.0]
const AVENUE := 3
const CITY := 400.0
const COAST := 900.0
const SHOP_NAMES := ["CAFÉ", "PIZZA", "SUSHI", "BOULANGERIE", "PHARMACIE", "FLEURS", "TACOS", "GLACES", "MODE", "LIBRAIRIE", "BAR", "HÔTEL", "CINÉ", "MARCHÉ"]
const NEON := [Color(1, 0.3, 0.6), Color(0.25, 0.9, 0.85), Color(1, 0.8, 0.35), Color(0.6, 0.4, 1), Color(1, 0.55, 0.25), Color(0.4, 1, 0.5)]

var rng := RandomNumberGenerator.new()
var lamp_heads: Array[Vector3] = []
var window_mats: Array[StandardMaterial3D] = []
var shop_mats: Array[StandardMaterial3D] = []
var sign_labels: Array[Label3D] = []
var lamp_mat: StandardMaterial3D
var traffic_lights: Array = []          # [position, axe] pour l'animation
var tl_mats := {}
var sidewalks: Array = []               # lignes de trottoir pour les piétons : [a, b]
var static_body: StaticBody3D           # un seul corps statique pour tout le décor fixe
var city_only := false                  # sur l'île : seulement la ville (le terrain, la mer et la campagne sont gérés par Island)
var seed_value := 424242
var city_name := "SOLENA"

func half(i: int) -> float:
	return 10.0 if i == AVENUE else 7.5

func build() -> void:
	rng.seed = seed_value
	static_body = StaticBody3D.new()
	add_child(static_body)
	if not city_only:
		_ground()
		_sea_and_beach()
	_roads()
	_blocks()
	_lamps_and_lights()
	_countryside()
	if not city_only:
		_hills()
	# trottoirs en coordonnées du monde (utile quand la ville est décalée sur l'île)
	var o := global_position
	for s in sidewalks:
		s[0] = (s[0] as Vector3) + o
		s[1] = (s[1] as Vector3) + o
	for i in lamp_heads.size():
		lamp_heads[i] += o

# ---------------------------------------------------------------- utilitaires
func _mesh(mesh: Mesh, pos: Vector3, material: Material, shadows := true, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _box(size: Vector3, pos: Vector3, material: Material, collide := false, shadows := true) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := _mesh(bm, pos, material, shadows)
	if collide:
		_collider_box(size, pos)
	return mi

func _collider_box(size: Vector3, pos: Vector3, yaw := 0.0) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	cs.rotation.y = yaw
	static_body.add_child(cs)

func _collider_cyl(r: float, h: float, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r
	sh.height = h
	cs.shape = sh
	cs.position = pos + Vector3(0, h / 2.0, 0)
	static_body.add_child(cs)

func _plane(size: Vector2, pos: Vector3, material: Material, subdiv := 0) -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = size
	pm.subdivide_width = subdiv
	pm.subdivide_depth = subdiv
	return _mesh(pm, pos, material, false)

func _on_road(p: Vector3, margin := 0.0) -> bool:
	if absf(p.x) < CITY + 30 + margin and absf(p.z) < CITY + 30 + margin:
		return true
	if absf(p.x) < 12 + margin or absf(p.z) < 12 + margin:
		return true
	if p.x > COAST - 75 - margin:
		return true
	return false

# ---------------------------------------------------------------- sol, mer, plage
func _ground() -> void:
	_plane(Vector2(4000, 4000), Vector3(0, 0, 0), Kit.grass_ground())
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	static_body.add_child(cs)
	for s in [-1, 1]:
		_collider_box(Vector3(10, 60, 3000), Vector3(s * 1450, 30, 0))
		_collider_box(Vector3(3000, 60, 10), Vector3(0, 30, s * 1450))

func _sea_and_beach() -> void:
	_plane(Vector2(70, 3000), Vector3(COAST + 5, 0.03, 0), Kit.sand())
	var sh := ShaderMaterial.new()
	sh.shader = load("res://shaders/water.gdshader")
	var nimg := Kit.noise_image(256, 0.06, 91)
	sh.set_shader_parameter("wave_normal", Kit.normal_from(nimg, 6.0))
	sh.set_shader_parameter("shore_x", COAST + 20)
	var sea := _plane(Vector2(1000, 3000), Vector3(COAST + 520, 0.05, 0), sh, 160)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_collider_box(Vector3(4, 12, 3000), Vector3(COAST + 22, 6, 0))
	# transats et parasols
	var z := -1300.0
	while z < 1300.0:
		var x := COAST + rng.randf_range(0, 14)
		var col: Color = NEON[rng.randi() % NEON.size()]
		var pole := CylinderMesh.new()
		pole.top_radius = 0.04
		pole.bottom_radius = 0.04
		pole.height = 2.4
		_mesh(pole, Vector3(x, 1.2, z), Kit.color_mat(Color(0.9, 0.9, 0.9)), false)
		var top := CylinderMesh.new()
		top.top_radius = 0.02
		top.bottom_radius = 1.6
		top.height = 0.6
		_mesh(top, Vector3(x, 2.35, z), Kit.color_mat(col, 0.8))
		_box(Vector3(0.7, 0.2, 1.9), Vector3(x + 1.6, 0.25, z), Kit.color_mat(Color(0.95, 0.94, 0.9)))
		z += rng.randf_range(18, 40)

# ---------------------------------------------------------------- routes
func _markings(center: Vector3, length: float, along_x: bool, off: float, dash: bool, col: Color, w := 0.15) -> void:
	var m := Kit.color_mat(col, 0.55)
	var xf: Array = []
	if dash:
		var count := int(length / 9.0)
		for k in count:
			var t := -length / 2.0 + 4.5 + k * 9.0
			var p := center + (Vector3(t, 0.045, off) if along_x else Vector3(off, 0.045, t))
			xf.append(Transform3D(Basis(), p))
		var bm := BoxMesh.new()
		bm.size = Vector3(3.5, 0.01, w) if along_x else Vector3(w, 0.01, 3.5)
		Kit.multimesh(self, bm, xf, m, false)
	else:
		var bm2 := BoxMesh.new()
		bm2.size = Vector3(length, 0.01, w) if along_x else Vector3(w, 0.01, length)
		_mesh(bm2, center + (Vector3(0, 0.045, off) if along_x else Vector3(off, 0.045, 0)), m, false)

func _road(center: Vector3, length: float, halfw: float, along_x: bool, kind: String) -> void:
	var size := Vector3(length, 0.04, halfw * 2) if along_x else Vector3(halfw * 2, 0.04, length)
	_mesh(_boxmesh(size), center + Vector3(0, 0.02, 0), Kit.asphalt(), false)
	var white := Color(0.93, 0.93, 0.9)
	var yellow := Color(0.95, 0.78, 0.2)
	if kind == "avenue":
		_markings(center, length, along_x, -0.2, false, yellow, 0.12)
		_markings(center, length, along_x, 0.2, false, yellow, 0.12)
		for s in [-1, 1]:
			_markings(center, length, along_x, s * 4.6, true, white)
			_markings(center, length, along_x, s * (halfw - 0.4), false, white, 0.12)
	elif kind == "street":
		_markings(center, length, along_x, 0.0, true, white)
		for s in [-1, 1]:
			_markings(center, length, along_x, s * 4.4, false, white, 0.1)   # bande de stationnement
	else:
		_markings(center, length, along_x, 0.0, true, yellow)
		for s in [-1, 1]:
			_markings(center, length, along_x, s * (halfw - 0.4), false, white, 0.12)

func _boxmesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

func _roads() -> void:
	for i in GRID.size():
		var hw := half(i)
		var kind := "avenue" if i == AVENUE else "street"
		# tronçons entre carrefours (pas de marquage dans les carrefours)
		for j in range(-1, GRID.size()):
			var a: float = -CITY - 10 if j < 0 else GRID[j] + half(j)
			var b: float = CITY + 10 if j == GRID.size() - 1 else GRID[j + 1] - half(j + 1)
			var mid := (a + b) / 2.0
			var len := b - a
			_road(Vector3(GRID[i], 0, mid), len, hw, false, kind)
			_road(Vector3(mid, 0, GRID[i]), len, hw, true, kind)
		# carrefours et passages piétons
		for j in GRID.size():
			var hj := half(j)
			_mesh(_boxmesh(Vector3(hw * 2, 0.04, hj * 2)), Vector3(GRID[i], 0.021, GRID[j]), Kit.asphalt(), false)
			_crosswalks(Vector3(GRID[i], 0, GRID[j]), hw, hj)
	if city_only:
		return
	# routes vers la campagne et route côtière
	_road(Vector3(0, 0, -(CITY + 510)), 1000, 6.5, false, "country")
	_road(Vector3(0, 0, CITY + 510), 1000, 6.5, false, "country")
	_road(Vector3(-(CITY + 510), 0, 0), 1000, 6.5, true, "country")
	_road(Vector3((CITY + 10 + COAST - 50) / 2.0, 0, 0), COAST - 50 - CITY - 10, 6.5, true, "country")
	_road(Vector3(COAST - 50, 0, 0), 2700, 6.5, false, "country")

func _crosswalks(c: Vector3, hx: float, hz: float) -> void:
	var m := Kit.color_mat(Color(0.95, 0.95, 0.92), 0.55)
	var xf: Array = []
	for side in [-1, 1]:
		for k in range(-int(hx / 1.2), int(hx / 1.2) + 1):
			xf.append(Transform3D(Basis(), c + Vector3(k * 1.2, 0.046, side * (hz + 2.2))))
	var bm := _boxmesh(Vector3(0.6, 0.01, 3.0))
	Kit.multimesh(self, bm, xf, m, false)
	var xf2: Array = []
	for side in [-1, 1]:
		for k in range(-int(hz / 1.2), int(hz / 1.2) + 1):
			xf2.append(Transform3D(Basis(), c + Vector3(side * (hx + 2.2), 0.046, k * 1.2)))
	Kit.multimesh(self, _boxmesh(Vector3(3.0, 0.01, 0.6)), xf2, m, false)

# ---------------------------------------------------------------- îlots
func _blocks() -> void:
	var curb := Kit.color_mat(Color(0.7, 0.7, 0.68), 0.8)
	var parked_xf: Array = []
	for i in GRID.size() - 1:
		for j in GRID.size() - 1:
			var x0 := GRID[i] + half(i)
			var x1 := GRID[i + 1] - half(i + 1)
			var z0 := GRID[j] + half(j)
			var z1 := GRID[j + 1] - half(j + 1)
			var c := Vector3((x0 + x1) / 2.0, 0, (z0 + z1) / 2.0)
			# trottoir surélevé de 15 cm (collision : les roues montent dessus) + bordures
			_box(Vector3(x1 - x0, 0.15, z1 - z0), c + Vector3(0, 0.075, 0), Kit.paving(), true, false)
			for e in [[Vector3(x1 - x0, 0.17, 0.3), Vector3(c.x, 0.085, z0 + 0.15)], [Vector3(x1 - x0, 0.17, 0.3), Vector3(c.x, 0.085, z1 - 0.15)],
					[Vector3(0.3, 0.17, z1 - z0), Vector3(x0 + 0.15, 0.085, c.z)], [Vector3(0.3, 0.17, z1 - z0), Vector3(x1 - 0.15, 0.085, c.z)]]:
				_box(e[0], e[1], curb, false, false)
			# lignes de marche pour les piétons (au milieu du trottoir)
			sidewalks.append([Vector3(x0 + 2.5, 0.15, z0 + 2.5), Vector3(x1 - 2.5, 0.15, z0 + 2.5)])
			sidewalks.append([Vector3(x0 + 2.5, 0.15, z1 - 2.5), Vector3(x1 - 2.5, 0.15, z1 - 2.5)])
			sidewalks.append([Vector3(x0 + 2.5, 0.15, z0 + 2.5), Vector3(x0 + 2.5, 0.15, z1 - 2.5)])
			sidewalks.append([Vector3(x1 - 2.5, 0.15, z0 + 2.5), Vector3(x1 - 2.5, 0.15, z1 - 2.5)])
			if i == 2 and j == 3:
				_park(x0, x1, z0, z1)
			elif i == 3 and j == 2:
				_plaza(x0, x1, z0, z1)
			else:
				_buildings(x0 + 5, x1 - 5, z0 + 5, z1 - 5)
				_street_trees(x0, x1, z0, z1, i, j)
	_parked_cars()

func _street_trees(x0: float, x1: float, z0: float, z1: float, i: int, j: int) -> void:
	# arbres d'alignement sur les rues (pas sur l'avenue, où il y a des palmiers)
	var pts: Array[Vector3] = []
	var t := x0 + 14
	while t < x1 - 14:
		if j != AVENUE:
			pts.append(Vector3(t, 0.15, z0 + 1.3))
		if j + 1 != AVENUE:
			pts.append(Vector3(t, 0.15, z1 - 1.3))
		t += 22
	t = z0 + 14
	while t < z1 - 14:
		if i != AVENUE:
			pts.append(Vector3(x0 + 1.3, 0.15, t))
		if i + 1 != AVENUE:
			pts.append(Vector3(x1 - 1.3, 0.15, t))
		t += 22
	for p in pts:
		_tree_points.append([p, rng.randf_range(0.75, 1.0), rng.randi() % 3])
		_collider_cyl(0.3, 3.0, p)

var _tree_points: Array = []    # [position, échelle, variante]
var _palm_points: Array = []    # [position, échelle]

func _park(x0: float, x1: float, z0: float, z1: float) -> void:
	var c := Vector3((x0 + x1) / 2.0, 0.15, (z0 + z1) / 2.0)
	_box(Vector3(x1 - x0 - 8, 0.06, z1 - z0 - 8), c + Vector3(0, 0.03, 0), Kit.grass_ground(), false, false)
	# allées en croix
	_box(Vector3(x1 - x0 - 8, 0.07, 4), c + Vector3(0, 0.035, 0), Kit.sand(), false, false)
	_box(Vector3(4, 0.07, z1 - z0 - 8), c + Vector3(0, 0.035, 0), Kit.sand(), false, false)
	# fontaine
	var basin := CylinderMesh.new()
	basin.top_radius = 8
	basin.bottom_radius = 8.3
	basin.height = 0.7
	basin.radial_segments = 48
	_mesh(basin, c + Vector3(0, 0.35, 0), Kit.color_mat(Color(0.86, 0.84, 0.8), 0.7))
	_collider_cyl(8.3, 0.7, c)
	var wat := CylinderMesh.new()
	wat.top_radius = 7.4
	wat.bottom_radius = 7.4
	wat.height = 0.05
	wat.radial_segments = 48
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.15, 0.45, 0.6)
	wm.roughness = 0.02
	wm.metallic = 0.2
	_mesh(wat, c + Vector3(0, 0.72, 0), wm, false)
	var col := CylinderMesh.new()
	col.top_radius = 0.5
	col.bottom_radius = 0.9
	col.height = 3.2
	_mesh(col, c + Vector3(0, 1.6, 0), Kit.color_mat(Color(0.9, 0.88, 0.82), 0.6))
	for k in 70:
		var p := Vector3(rng.randf_range(x0 + 8, x1 - 8), 0.2, rng.randf_range(z0 + 8, z1 - 8))
		if p.distance_to(c) < 14 or absf(p.x - c.x) < 4 or absf(p.z - c.z) < 4:
			continue
		if rng.randf() < 0.35:
			_palm_points.append([p, rng.randf_range(0.9, 1.25)])
		else:
			_tree_points.append([p, rng.randf_range(1.0, 1.5), rng.randi() % 3])
		_collider_cyl(0.35, 3.0, p)
	# bancs
	for k in 12:
		var a := k * TAU / 12.0
		_bench(c + Vector3(cos(a) * 11.5, 0, sin(a) * 11.5), a + PI / 2.0)

func _plaza(x0: float, x1: float, z0: float, z1: float) -> void:
	var c := Vector3((x0 + x1) / 2.0, 0.15, (z0 + z1) / 2.0)
	_box(Vector3(x1 - x0 - 4, 0.04, z1 - z0 - 4), c + Vector3(0, 0.02, 0), Kit.pbr("plaza", Kit.tint_image(256, Color(0.8, 0.74, 0.64), Color(0.9, 0.85, 0.76), 0.08, 17), 0.8, 2.0, 3.0, true), false, false)
	# kiosque central et palmiers en cercle
	var dome := SphereMesh.new()
	dome.radius = 5
	dome.height = 5
	dome.is_hemisphere = true
	_mesh(dome, c + Vector3(0, 6, 0), Kit.color_mat(Color(0.3, 0.6, 0.55), 0.4, 0.6))
	for k in 8:
		var a := k * TAU / 8.0
		var colm := CylinderMesh.new()
		colm.top_radius = 0.2
		colm.bottom_radius = 0.22
		colm.height = 6
		_mesh(colm, c + Vector3(cos(a) * 4.6, 3, sin(a) * 4.6), Kit.color_mat(Color(0.95, 0.94, 0.9), 0.6))
		_palm_points.append([c + Vector3(cos(a + 0.4) * 22, 0.05, sin(a + 0.4) * 22), rng.randf_range(1.0, 1.2)])
		_collider_cyl(0.35, 3.0, c + Vector3(cos(a + 0.4) * 22, 0, sin(a + 0.4) * 22))
		_bench(c + Vector3(cos(a + 0.2) * 12, 0, sin(a + 0.2) * 12), a + 0.2 + PI / 2.0)
	_collider_cyl(5.0, 6.0, c)
	var sign := Label3D.new()
	sign.text = "PLACE CENTRALE"
	sign.font_size = 160
	sign.pixel_size = 0.01
	sign.modulate = Color(1, 0.95, 0.8)
	sign.outline_size = 24
	sign.position = c + Vector3(0, 9.5, 0)
	sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	add_child(sign)

func _bench(p: Vector3, yaw: float) -> void:
	var wood := Kit.color_mat(Color(0.55, 0.36, 0.2), 0.8)
	var metal := Kit.color_mat(Color(0.2, 0.22, 0.24), 0.4, 0.8)
	var n := Node3D.new()
	n.position = p + Vector3(0, 0.15, 0)
	n.rotation.y = yaw
	add_child(n)
	for spec in [[Vector3(1.8, 0.06, 0.5), Vector3(0, 0.45, 0), wood], [Vector3(1.8, 0.4, 0.06), Vector3(0, 0.75, -0.25), wood],
			[Vector3(0.06, 0.45, 0.5), Vector3(-0.8, 0.22, 0), metal], [Vector3(0.06, 0.45, 0.5), Vector3(0.8, 0.22, 0), metal]]:
		var mi := MeshInstance3D.new()
		mi.mesh = _boxmesh(spec[0])
		mi.position = spec[1]
		mi.material_override = spec[2]
		n.add_child(mi)

func _buildings(x0: float, x1: float, z0: float, z1: float) -> void:
	var dn := rng.randf_range(16, 28)
	var ds := rng.randf_range(16, 28)
	_row(x0, x1, z0, dn, true, 1)
	_row(x0, x1, z1, ds, true, -1)
	var dw := rng.randf_range(16, 26)
	var de := rng.randf_range(16, 26)
	_row(z0 + dn, z1 - ds, x0, dw, false, 1)
	_row(z0 + dn, z1 - ds, x1, de, false, -1)

func _row(a0: float, a1: float, edge: float, depth: float, along_x: bool, inward: int) -> void:
	var a := a0
	while a1 - a > 8:
		var w := minf(rng.randf_range(12, 32), a1 - a)
		if a1 - a - w < 8:
			w = a1 - a
		var mid := a + w / 2.0
		var cc := edge + inward * depth / 2.0
		var pos := Vector3(mid, 0, cc) if along_x else Vector3(cc, 0, mid)
		var size := Vector3(w - 0.8, 0, depth) if along_x else Vector3(depth, 0, w - 0.8)
		var street_dir := Vector3(0, 0, -inward) if along_x else Vector3(-inward, 0, 0)
		_building(pos, size, street_dir)
		a += w

func _building(pos: Vector3, size: Vector3, street: Vector3) -> void:
	var d := Vector2(pos.x, pos.z).length()
	var t := clampf(1.0 - d / 470.0, 0.0, 1.0)
	var h := rng.randf_range(9, 20) + t * t * rng.randf_range(10, 120)
	h = snappedf(h, 3.2)
	if KenneyLib.city_building(self, static_body, pos, size, street, h, rng):
		return
	var style := 2 if (h > 48 and rng.randf() < 0.65) else (1 if rng.randf() < 0.35 else 0)
	var palette := [Color(1, 0.97, 0.9), Color(1, 0.87, 0.78), Color(0.88, 0.94, 1), Color(0.98, 0.92, 0.76),
		Color(1, 0.82, 0.86), Color(0.84, 0.92, 0.84), Color(0.95, 0.95, 0.97), Color(0.96, 0.85, 0.7)]
	var tint: Color = Color(0.75, 0.85, 0.95) if style == 2 else (Color(1, 1, 1) if style == 1 else palette[rng.randi() % palette.size()])
	var m := Kit.facade(style, tint)
	if not window_mats.has(m):
		window_mats.append(m)
	var base := 0.15
	var roof_m := Kit.color_mat(Color(0.42, 0.43, 0.45), 0.9)
	if h > 60 and rng.randf() < 0.6:
		var h1 := snappedf(h * 0.6, 3.2)
		_box(Vector3(size.x, h1, size.z), pos + Vector3(0, base + h1 / 2.0, 0), m, true)
		_box(Vector3(size.x + 0.3, 0.4, size.z + 0.3), pos + Vector3(0, base + h1 + 0.2, 0), roof_m, false)
		_box(Vector3(size.x * 0.68, h - h1, size.z * 0.68), pos + Vector3(0, base + h1 + (h - h1) / 2.0, 0), m, true)
	else:
		_box(Vector3(size.x, h, size.z), pos + Vector3(0, base + h / 2.0, 0), m, true)
	# toit : dalle, acrotère, équipements
	_box(Vector3(size.x * (0.68 if h > 60 else 1.0) + 0.4, 0.5, size.z * (0.68 if h > 60 else 1.0) + 0.4), pos + Vector3(0, base + h + 0.25, 0), roof_m, false)
	for k in rng.randi_range(1, 3):
		var off := Vector3(rng.randf_range(-0.3, 0.3) * size.x * 0.6, 0, rng.randf_range(-0.3, 0.3) * size.z * 0.6)
		_box(Vector3(2.2, 1.4, 1.6), pos + off + Vector3(0, base + h + 1.2, 0), Kit.color_mat(Color(0.75, 0.77, 0.8), 0.5, 0.6), false)
	if style == 1 and h < 40 and rng.randf() < 0.4:
		var tank := CylinderMesh.new()
		tank.top_radius = 1.8
		tank.bottom_radius = 1.8
		tank.height = 3.2
		_mesh(tank, pos + Vector3(size.x * 0.2, base + h + 3.4, 0), Kit.color_mat(Color(0.5, 0.36, 0.25), 0.9))
	if h > 70:
		var ant := CylinderMesh.new()
		ant.top_radius = 0.05
		ant.bottom_radius = 0.12
		ant.height = 10
		_mesh(ant, pos + Vector3(0, base + h + 5.5, 0), Kit.color_mat(Color(0.8, 0.8, 0.82), 0.4, 0.8))
	# rez-de-chaussée commerçant : vitrine lumineuse, auvent, enseigne néon
	if h < 80 and rng.randf() < 0.8:
		var neon: Color = NEON[rng.randi() % NEON.size()]
		var shop := StandardMaterial3D.new()
		shop.albedo_color = Color(0.06, 0.08, 0.1)
		shop.metallic = 0.6
		shop.roughness = 0.05
		shop.emission_enabled = true
		shop.emission = neon.lerp(Color(1, 0.95, 0.85), 0.6)
		shop.emission_energy_multiplier = 0.2
		shop_mats.append(shop)
		var depth_half := (size.z if street.z != 0 else size.x) / 2.0
		var off2 := street * depth_half
		var band := Vector3(size.x - 1.2, 3.0, 0.2) if street.z != 0 else Vector3(0.2, 3.0, size.z - 1.2)
		_box(band, pos + off2 + street * 0.12 + Vector3(0, base + 1.7, 0), shop, false, false)
		var frame_m := Kit.color_mat(Color(0.15, 0.15, 0.17), 0.4, 0.7)
		var n_mul := int((size.x if street.z != 0 else size.z) / 3.5)
		for q in range(n_mul + 1):
			var u := -((size.x if street.z != 0 else size.z) - 1.2) / 2.0 + q * ((size.x if street.z != 0 else size.z) - 1.2) / maxf(n_mul, 1)
			var along := Vector3(u, 0, 0) if street.z != 0 else Vector3(0, 0, u)
			_box(Vector3(0.14, 3.0, 0.3) if street.z != 0 else Vector3(0.3, 3.0, 0.14), pos + off2 + street * 0.2 + along + Vector3(0, base + 1.7, 0), frame_m, false, false)
		var awn := Vector3(size.x - 1.0, 0.12, 1.8) if street.z != 0 else Vector3(1.8, 0.12, size.z - 1.0)
		_box(awn, pos + off2 + street * 0.95 + Vector3(0, base + 3.6, 0), Kit.color_mat(neon.darkened(0.25), 0.8), false)
		var lbl := Label3D.new()
		lbl.text = SHOP_NAMES[rng.randi() % SHOP_NAMES.size()]
		lbl.font_size = 96
		lbl.pixel_size = 0.012
		lbl.outline_size = 0
		lbl.modulate = neon * 1.6
		lbl.shaded = false
		lbl.double_sided = false
		lbl.position = pos + off2 + street * 0.35 + Vector3(0, base + 4.4, 0)
		lbl.rotation.y = atan2(street.x, street.z)
		add_child(lbl)
		sign_labels.append(lbl)

# ---------------------------------------------------------------- voitures garées (poussables)
func _parked_cars() -> void:
	var models := ["sedan", "hatch", "wagon", "suv", "micro", "coupe", "van"]
	for i in GRID.size():
		if i == AVENUE:
			continue
		for side in [-1, 1]:
			var s := -CITY + 5
			while s < CITY - 5:
				var near := false
				for g in GRID:
					if absf(s - g) < 16:
						near = true
				if not near and rng.randf() < 0.12:
					var off: float = GRID[i] + side * 5.9
					# rue orientée selon Z puis selon X
					_parked_car(Vector3(off, 0.2, s), (0.0 if side > 0 else PI), models[rng.randi() % models.size()])
					_parked_car(Vector3(s, 0.2, off), (PI / 2.0 if side < 0 else -PI / 2.0), models[rng.randi() % models.size()])
				s += 6.5

func _parked_car(p: Vector3, yaw: float, model: String) -> void:
	var rb := RigidBody3D.new()
	rb.mass = 1300
	rb.position = p
	rb.rotation.y = yaw
	rb.can_sleep = true
	rb.sleeping = true
	rb.angular_damp = 1.5
	rb.linear_damp = 0.4
	add_child(rb)
	var M := CarBody.info(model)
	CarBody.build(rb, model, CarBody.COLORS[rng.randi() % CarBody.COLORS.size()], true)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(M.W - 0.1, 1.0, M.L - 0.1)
	cs.shape = sh
	cs.position = Vector3(0, 0.75, 0)
	rb.add_child(cs)
	_set_range(rb, 220.0)

func _set_range(n: Node, dist: float) -> void:
	for c in n.get_children():
		if c is GeometryInstance3D:
			c.visibility_range_end = dist
		_set_range(c, dist)

# ---------------------------------------------------------------- lampadaires, feux
func _lamps_and_lights() -> void:
	lamp_mat = StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(1, 0.95, 0.85)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1, 0.8, 0.52)
	lamp_mat.emission_energy_multiplier = 0.2
	var poles: Array = []
	var arms: Array = []
	var heads: Array = []
	for i in GRID.size():
		var off := half(i) + 1.0
		var s := -CITY
		while s < CITY:
			var near_cross := false
			for g in GRID:
				if absf(s - g) < 16:
					near_cross = true
			if not near_cross:
				for side in [-1, 1]:
					for along_z in [true, false]:
						var p: Vector3 = Vector3(GRID[i] + side * off, 0.15, s) if along_z else Vector3(s, 0.15, GRID[i] + side * off)
						var inward: Vector3 = Vector3(-side, 0, 0) if along_z else Vector3(0, 0, -side)
						var yaw := atan2(inward.x, inward.z)
						poles.append(Transform3D(Basis(), p + Vector3(0, 4.0, 0)))
						arms.append(Transform3D(Basis(Vector3.UP, yaw), p + Vector3(0, 7.9, 0) + inward * 1.0))
						var hp := p + Vector3(0, 7.75, 0) + inward * 2.0
						heads.append(Transform3D(Basis(Vector3.UP, yaw), hp))
						lamp_heads.append(hp)
						_collider_cyl(0.18, 8.0, p)
			s += 30
	var pole := CylinderMesh.new()
	pole.top_radius = 0.08
	pole.bottom_radius = 0.14
	pole.height = 8.0
	pole.radial_segments = 10
	var metal := Kit.color_mat(Color(0.22, 0.24, 0.26), 0.35, 0.8)
	Kit.multimesh(self, pole, poles, metal, true)
	Kit.multimesh(self, _boxmesh(Vector3(0.08, 0.08, 2.0)), arms, metal, true)
	var hm := CylinderMesh.new()
	hm.top_radius = 0.18
	hm.bottom_radius = 0.42
	hm.height = 0.22
	Kit.multimesh(self, hm, heads, lamp_mat, false)
	# feux tricolores aux carrefours de l'avenue
	var emit := {"r": Color(1, 0.1, 0.08), "o": Color(1, 0.7, 0.1), "g": Color(0.1, 1, 0.4)}
	for axis in ["z", "x"]:
		tl_mats[axis] = {}
		for c in ["r", "o", "g"]:
			var m := StandardMaterial3D.new()
			m.albedo_color = (emit[c] as Color).darkened(0.8)
			m.emission_enabled = true
			m.emission = emit[c]
			m.emission_energy_multiplier = 0.1
			tl_mats[axis][c] = m
	for j in GRID.size():
		var ha := half(AVENUE)
		var hj := half(j)
		for q in [[1, 1], [-1, -1]]:
			var p := Vector3(GRID[AVENUE] + q[0] * (ha + 1.2), 0.15, GRID[j] + q[1] * (hj + 1.2))
			var poleb := CylinderMesh.new()
			poleb.top_radius = 0.1
			poleb.bottom_radius = 0.12
			poleb.height = 4.8
			_mesh(poleb, p + Vector3(0, 2.4, 0), metal)
			var box := _box(Vector3(0.45, 1.5, 0.4), p + Vector3(0, 4.7, 0), Kit.color_mat(Color(0.1, 0.1, 0.11), 0.5), false)
			box.rotation.y = 0.0
			var k := 0
			for c in ["r", "o", "g"]:
				var sph := SphereMesh.new()
				sph.radius = 0.14
				sph.height = 0.28
				_mesh(sph, p + Vector3(0, 5.2 - k * 0.48, q[1] * 0.22), tl_mats["z"][c], false)
				_mesh(sph, p + Vector3(q[0] * 0.24, 5.2 - k * 0.48, 0), tl_mats["x"][c], false)
				k += 1
			_collider_cyl(0.15, 4.8, p)

# ---------------------------------------------------------------- campagne, arbres, herbe
func _countryside() -> void:
	# palmiers de l'avenue (terre-plein) et du bord de mer
	var z := -CITY
	while z < CITY:
		var near := false
		for g in GRID:
			if absf(z - g) < 14:
				near = true
		if not near:
			_palm_points.append([Vector3(GRID[AVENUE] + rng.randf_range(-0.2, 0.2), 0.05, z), rng.randf_range(0.95, 1.2)])
			_palm_points.append([Vector3(z, 0.05, GRID[AVENUE] + rng.randf_range(-0.2, 0.2)), rng.randf_range(0.95, 1.2)])
		z += 18
	if city_only:
		_render_vegetation()
		return
	z = -1300.0
	while z < 1300.0:
		_palm_points.append([Vector3(COAST - 32 + rng.randf_range(-5, 5), 0, z), rng.randf_range(0.9, 1.3)])
		_collider_cyl(0.35, 3.0, Vector3(COAST - 32, 0, z))
		z += rng.randf_range(14, 30)
	# champs cultivés
	var crops := [[Color(0.72, 0.62, 0.3), Color(0.88, 0.78, 0.42)], [Color(0.4, 0.3, 0.2), Color(0.55, 0.42, 0.28)],
		[Color(0.3, 0.48, 0.2), Color(0.45, 0.62, 0.28)], [Color(0.5, 0.4, 0.68), Color(0.66, 0.55, 0.85)], [Color(0.85, 0.7, 0.12), Color(0.98, 0.85, 0.25)]]
	for k in 40:
		var p := Vector3(rng.randf_range(-1300, 780), 0.04, rng.randf_range(-1300, 1300))
		var s := Vector2(rng.randf_range(70, 170), rng.randf_range(70, 170))
		if absf(p.x) - s.x / 2 < CITY + 40 and absf(p.z) - s.y / 2 < CITY + 40:
			continue
		if absf(p.x) < s.x / 2 + 14 or absf(p.z) < s.y / 2 + 14 or p.x + s.x / 2 > COAST - 80:
			continue
		var cc: Array = crops[rng.randi() % crops.size()]
		var mat := Kit.pbr("crop_%d_%d" % [k % 5, crops.find(cc)], _rows_image(cc[0], cc[1]), 0.95, 3.0, 12.0, false)
		var pl := _plane(s, p, mat)
		pl.rotation.y = rng.randf_range(-0.2, 0.2)
		if rng.randf() < 0.5:
			_farm(p + Vector3(s.x / 2 + 18, 0, 0))
	# forêts et arbres épars
	for k in 3200:
		var p := Vector3(rng.randf_range(-1400, COAST - 90), 0, rng.randf_range(-1400, 1400))
		if _on_road(p, 4):
			continue
		var forest := p.z < -600 and p.x < 300
		if not forest and rng.randf() < 0.55:
			continue
		_tree_points.append([p, rng.randf_range(0.9, 1.8), rng.randi() % 3])
		if p.length() < 900:
			_collider_cyl(0.4, 3.0, p)
	_render_vegetation()

func _rows_image(a: Color, b: Color) -> Image:
	var s := 128
	var img := Image.create(s, s, true, Image.FORMAT_RGB8)
	var n := Kit.noise_image(s, 0.08, int(a.r * 1000))
	for y in s:
		for x in s:
			var row := 0.5 + 0.5 * sin(x * TAU / 16.0)
			img.set_pixel(x, y, a.lerp(b, row * 0.7 + n.get_pixel(x, y).r * 0.3))
	return img

func _farm(p: Vector3) -> void:
	var walls := Kit.color_mat(Color(0.93, 0.88, 0.78), 0.9)
	var roofm := Kit.color_mat(Color(0.62, 0.25, 0.18), 0.8)
	_box(Vector3(12, 6, 9), p + Vector3(0, 3, 0), walls, true)
	var roof := PrismMesh.new()
	roof.size = Vector3(10, 3.2, 13)
	var r := _mesh(roof, p + Vector3(0, 7.6, 0), roofm)
	r.rotation.y = PI / 2.0
	_box(Vector3(10, 7, 14), p + Vector3(20, 3.5, 4), Kit.color_mat(Color(0.6, 0.16, 0.12), 0.9), true)

func _render_vegetation() -> void:
	# arbres : 3 formes de couronnes (sphères déformées), feuillage texturé et translucide
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.32
	trunk.height = 3.2
	trunk.radial_segments = 10
	var trunk_xf: Array = []
	var crowns := [[], [], []]
	for t in _tree_points:
		var p: Vector3 = t[0]
		var s: float = t[1]
		trunk_xf.append(Transform3D(Basis().scaled(Vector3(s, s, s)), p + Vector3(0, 1.6 * s, 0)))
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(2.6 * s, 2.8 * s, 2.6 * s))
		crowns[t[2]].append(Transform3D(b, p + Vector3(0, 4.4 * s, 0)))
	Kit.multimesh(self, trunk, trunk_xf, Kit.bark(), true)
	var tints := [Color(0.3, 0.52, 0.2), Color(0.38, 0.55, 0.18), Color(0.25, 0.45, 0.22)]
	for v in 3:
		Kit.multimesh(self, Kit.crown_mesh(100 + v), crowns[v], Kit.foliage(tints[v], "leaf_%d" % v), true)
	# palmiers : tronc bagué + palmes découpées
	var ptrunk := CylinderMesh.new()
	ptrunk.top_radius = 0.2
	ptrunk.bottom_radius = 0.32
	ptrunk.height = 8.0
	ptrunk.radial_segments = 12
	var pmat := Kit.pbr("palm_trunk", _palm_bark(), 0.9, 4.0, 1.0)
	var pxf: Array = []
	var fxf: Array = []
	for pp in _palm_points:
		var p: Vector3 = pp[0]
		var s: float = pp[1]
		var lean := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.08))
		pxf.append(Transform3D(lean.scaled(Vector3(s, s, s)), p + Vector3(0, 4 * s, 0)))
		var topp := p + lean * Vector3(0, 8 * s, 0)
		fxf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), topp))
	Kit.multimesh(self, ptrunk, pxf, pmat, true)
	Kit.multimesh(self, Kit.fronds_mesh(), fxf, Kit.frond_material(), true)
	# herbe haute : touffes autour de la ville et dans le parc
	if city_only:
		return
	var gxf: Array = []
	for k in 26000:
		var p := Vector3(rng.randf_range(-1100, COAST - 90), 0, rng.randf_range(-1100, 1100))
		if _on_road(p, 2):
			continue
		var s := rng.randf_range(0.5, 1.1)
		gxf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s * 1.4, s, s * 1.4)), p))
	var gm := Kit.multimesh(self, Kit.grass_card_mesh(), gxf, Kit.grass_card_material(), false)
	gm.visibility_range_end = 260.0

func _palm_bark() -> Image:
	var s := 128
	var img := Image.create(s, s, true, Image.FORMAT_RGB8)
	for y in s:
		for x in s:
			var ring := (y % 16) < 3
			var v := 0.55 + 0.1 * sin(x * 0.3)
			img.set_pixel(x, y, Color(v * 0.72, v * 0.6, v * 0.45) if not ring else Color(0.38, 0.3, 0.22))
	return img

# ---------------------------------------------------------------- collines à l'horizon
func _hills() -> void:
	var mat := Kit.pbr("hill", Kit.tint_image(256, Color(0.25, 0.38, 0.18), Color(0.42, 0.5, 0.26), 0.02, 81), 1.0, 2.0, 40.0, true)
	for k in 26:
		var a := rng.randf_range(0, TAU)
		var r := rng.randf_range(1650, 2000)
		var p := Vector3(cos(a) * r, -20, sin(a) * r)
		if p.x > 800:
			continue
		var sph := SphereMesh.new()
		sph.radius = 1.0
		sph.height = 2.0
		sph.radial_segments = 32
		sph.rings = 16
		var mi := _mesh(sph, p, mat, false)
		mi.scale = Vector3(rng.randf_range(250, 420), rng.randf_range(90, 220), rng.randf_range(250, 420))
