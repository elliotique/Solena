class_name World
extends Node3D
## Génère la ville de Solena : routes, trottoirs, immeubles, parc, lampadaires, campagne, plage.

const GRID: Array[float] = [-360.0, -240.0, -120.0, 0.0, 120.0, 240.0, 360.0]
const AVENUE := 3
const CITY := 400.0
const COAST := 900.0

var rng := RandomNumberGenerator.new()
var lamp_heads: Array[Vector3] = []
var window_mats: Array[StandardMaterial3D] = []
var shop_mats: Array[StandardMaterial3D] = []
var lamp_mat: StandardMaterial3D
var _mat_cache := {}
var _win_albedo: ImageTexture
var _win_emit: ImageTexture

func half(i: int) -> float:
	return 9.0 if i == AVENUE else 6.5

func build() -> void:
	rng.seed = 424242
	_make_window_textures()
	_ground()
	_sea_and_beach()
	_roads()
	_blocks()
	_lamps()
	_countryside()

# ---------------------------------------------------------------- matériaux
func _mat(color: Color, rough := 0.9, metal := 0.0) -> StandardMaterial3D:
	var key := "%s_%s_%s" % [color.to_html(), rough, metal]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	_mat_cache[key] = m
	return m

func _make_window_textures() -> void:
	# 4 x 4 fenêtres par tuile de 16 m, allumées au hasard la nuit
	var n := 256
	var a := Image.create(n, n, false, Image.FORMAT_RGB8)
	var e := Image.create(n, n, false, Image.FORMAT_RGB8)
	a.fill(Color(1, 1, 1))
	e.fill(Color(0, 0, 0))
	for gx in 4:
		for gy in 4:
			var lit := rng.randf() < 0.45
			var warm := Color(1.0, 0.82, 0.55) if rng.randf() < 0.7 else Color(0.75, 0.85, 1.0)
			for x in range(gx * 64 + 10, gx * 64 + 54):
				for y in range(gy * 64 + 14, gy * 64 + 50):
					a.set_pixel(x, y, Color(0.32, 0.38, 0.46))
					if lit:
						e.set_pixel(x, y, warm)
	a.generate_mipmaps()
	e.generate_mipmaps()
	_win_albedo = ImageTexture.create_from_image(a)
	_win_emit = ImageTexture.create_from_image(e)

func _facade(color: Color, glass: bool) -> StandardMaterial3D:
	var key := "fac_%s_%s" % [color.to_html(), glass]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = _win_albedo
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / 16.0
	m.roughness = 0.25 if glass else 0.85
	m.metallic = 0.35 if glass else 0.0
	m.emission_enabled = true
	m.emission_texture = _win_emit
	m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	m.emission = Color(1, 1, 1)
	m.emission_energy_multiplier = 0.0
	_mat_cache[key] = m
	window_mats.append(m)
	return m

# ---------------------------------------------------------------- utilitaires
func _box(size: Vector3, pos: Vector3, material: Material, collide := false, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = material
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		body.position = pos
		body.add_child(cs)
		add_child(body)
	return mi

func _plane(size: Vector2, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = material
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _wall(size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.position = pos
	body.add_child(cs)
	add_child(body)

# ---------------------------------------------------------------- sol, mer
func _ground() -> void:
	var g := _mat(Color(0.36, 0.55, 0.25), 1.0)
	_plane(Vector2(4000, 4000), Vector3(0, 0, 0), g)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	body.add_child(cs)
	add_child(body)
	# limites du monde
	for s in [-1, 1]:
		_wall(Vector3(10, 40, 3000), Vector3(s * 1450, 20, 0))
		_wall(Vector3(3000, 40, 10), Vector3(0, 20, s * 1450))

func _sea_and_beach() -> void:
	_plane(Vector2(60, 3000), Vector3(COAST - 10, 0.02, 0), _mat(Color(0.86, 0.78, 0.56), 1.0))
	var sea := StandardMaterial3D.new()
	sea.albedo_color = Color(0.08, 0.42, 0.58)
	sea.roughness = 0.08
	sea.metallic = 0.3
	_plane(Vector2(1200, 3000), Vector3(COAST + 620, 0.05, 0), sea)
	_wall(Vector3(4, 10, 3000), Vector3(COAST + 16, 5, 0))

# ---------------------------------------------------------------- routes
func _road_strip(center: Vector3, length: float, width: float, along_x: bool, lane_marks: bool, y := 0.03) -> void:
	var asphalt := _mat(Color(0.16, 0.17, 0.19), 0.92)
	var size := Vector3(length, 0.02, width) if along_x else Vector3(width, 0.02, length)
	_box(size, center + Vector3(0, y, 0), asphalt, false, false)
	if lane_marks:
		var white := _mat(Color(0.92, 0.92, 0.88), 0.6)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var dash := BoxMesh.new()
		dash.size = Vector3(3, 0.01, 0.15) if along_x else Vector3(0.15, 0.01, 3)
		mm.mesh = dash
		var count := int(length / 8.0)
		mm.instance_count = count
		for k in count:
			var t := -length / 2.0 + 4.0 + k * 8.0
			var p := center + (Vector3(t, y + 0.02, 0) if along_x else Vector3(0, y + 0.02, t))
			mm.set_instance_transform(k, Transform3D(Basis(), p))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = white
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)

func _roads() -> void:
	for i in GRID.size():
		var w := half(i) * 2.0
		_road_strip(Vector3(GRID[i], 0, 0), CITY * 2 + 20, w, false, true, 0.03)
		_road_strip(Vector3(0, 0, GRID[i]), CITY * 2 + 20, w, true, true, 0.031)
	# sorties vers la campagne et route côtière
	_road_strip(Vector3(0, 0, -(CITY + 500)), 1000, 12, false, true)
	_road_strip(Vector3(0, 0, CITY + 500), 1000, 12, false, true)
	_road_strip(Vector3(-(CITY + 500), 0, 0), 1000, 12, true, true)
	_road_strip(Vector3((CITY + COAST - 40) / 2.0, 0, 0), COAST - 40 - CITY, 12, true, true)
	_road_strip(Vector3(COAST - 50, 0, 0), 2600, 10, false, true)

# ---------------------------------------------------------------- îlots
func _blocks() -> void:
	var sidewalk := _mat(Color(0.62, 0.61, 0.58), 0.95)
	for i in GRID.size() - 1:
		for j in GRID.size() - 1:
			var x0 := GRID[i] + half(i)
			var x1 := GRID[i + 1] - half(i + 1)
			var z0 := GRID[j] + half(j)
			var z1 := GRID[j + 1] - half(j + 1)
			var c := Vector3((x0 + x1) / 2.0, 0, (z0 + z1) / 2.0)
			_box(Vector3(x1 - x0, 0.15, z1 - z0), c + Vector3(0, 0.075, 0), sidewalk, true, false)
			if i == 2 and j == 3:
				_park(x0, x1, z0, z1)
			else:
				_buildings(x0 + 4, x1 - 4, z0 + 4, z1 - 4)

func _park(x0: float, x1: float, z0: float, z1: float) -> void:
	_box(Vector3(x1 - x0 - 6, 0.05, z1 - z0 - 6), Vector3((x0 + x1) / 2.0, 0.17, (z0 + z1) / 2.0), _mat(Color(0.3, 0.55, 0.25), 1.0), false, false)
	var c := Vector3((x0 + x1) / 2.0, 0.15, (z0 + z1) / 2.0)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.2, 0.55, 0.75)
	water.roughness = 0.05
	var basin := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 7
	cyl.bottom_radius = 7
	cyl.height = 0.6
	basin.mesh = cyl
	basin.material_override = _mat(Color(0.85, 0.82, 0.76), 0.8)
	basin.position = c + Vector3(0, 0.3, 0)
	add_child(basin)
	_plane(Vector2(12.5, 12.5), c + Vector3(0, 0.62, 0), water)
	var palms: Array[Vector3] = []
	for k in 40:
		var p := Vector3(rng.randf_range(x0 + 6, x1 - 6), 0.15, rng.randf_range(z0 + 6, z1 - 6))
		if p.distance_to(c) > 12:
			palms.append(p)
	_palms(palms)

func _buildings(x0: float, x1: float, z0: float, z1: float) -> void:
	var dn := rng.randf_range(14, 26)
	var ds := rng.randf_range(14, 26)
	_row(x0, x1, z0, dn, true, 1)
	_row(x0, x1, z1, ds, true, -1)
	var dw := rng.randf_range(14, 24)
	var de := rng.randf_range(14, 24)
	_row(z0 + dn, z1 - ds, x0, dw, false, 1)
	_row(z0 + dn, z1 - ds, x1, de, false, -1)

func _row(a0: float, a1: float, edge: float, depth: float, along_x: bool, inward: int) -> void:
	var a := a0
	while a1 - a > 8:
		var w := minf(rng.randf_range(12, 30), a1 - a)
		if a1 - a - w < 8:
			w = a1 - a
		var mid := a + w / 2.0
		var cc := edge + inward * depth / 2.0
		var pos := Vector3(mid, 0, cc) if along_x else Vector3(cc, 0, mid)
		var size := Vector3(w - 0.6, 0, depth) if along_x else Vector3(depth, 0, w - 0.6)
		var street_dir := Vector3(0, 0, -inward) if along_x else Vector3(-inward, 0, 0)
		_building(pos, size, street_dir)
		a += w

func _building(pos: Vector3, size: Vector3, street: Vector3) -> void:
	var d := Vector2(pos.x, pos.z).length()
	var t := clampf(1.0 - d / 460.0, 0.0, 1.0)
	var h := rng.randf_range(8, 18) + t * t * rng.randf_range(10, 110)
	var glass := h > 45 and rng.randf() < 0.7
	var palette := [Color(0.93, 0.9, 0.84), Color(0.95, 0.8, 0.72), Color(0.82, 0.88, 0.92), Color(0.9, 0.85, 0.7),
		Color(0.78, 0.55, 0.45), Color(0.95, 0.75, 0.8), Color(0.75, 0.82, 0.74), Color(0.88, 0.88, 0.9)]
	var col: Color = Color(0.55, 0.68, 0.8) if glass else palette[rng.randi() % palette.size()]
	var m := _facade(col, glass)
	var base := 0.15
	if h > 60 and rng.randf() < 0.6:
		# tour en gradins
		var h1 := h * 0.6
		_box(Vector3(size.x, h1, size.z), pos + Vector3(0, base + h1 / 2.0, 0), m, true)
		_box(Vector3(size.x * 0.7, h - h1, size.z * 0.7), pos + Vector3(0, base + h1 + (h - h1) / 2.0, 0), m, true)
	else:
		_box(Vector3(size.x, h, size.z), pos + Vector3(0, base + h / 2.0, 0), m, true)
		# corniche
		_box(Vector3(size.x + 0.4, 0.5, size.z + 0.4), pos + Vector3(0, base + h + 0.25, 0), _mat(col.darkened(0.25), 0.9), false)
	# rez-de-chaussée commerçant côté rue
	if h < 70 and rng.randf() < 0.75:
		var shop := StandardMaterial3D.new()
		var neon := [Color(1, 0.3, 0.6), Color(0.25, 0.9, 0.85), Color(1, 0.8, 0.35), Color(0.6, 0.4, 1), Color(1, 0.55, 0.25)]
		shop.albedo_color = Color(0.9, 0.95, 1)
		shop.emission_enabled = true
		shop.emission = neon[rng.randi() % neon.size()]
		shop.emission_energy_multiplier = 0.15
		shop.albedo_color = Color(0.55, 0.6, 0.65)
		shop_mats.append(shop)
		var off := street * (size.z if street.z != 0 else size.x) / 2.0
		var band := Vector3(size.x - 1.0, 3.2, 0.3) if street.z != 0 else Vector3(0.3, 3.2, size.z - 1.0)
		_box(band, pos + off + street * 0.1 + Vector3(0, base + 1.8, 0), shop, false, false)
		var awn := Vector3(size.x - 1.0, 0.15, 1.6) if street.z != 0 else Vector3(1.6, 0.15, size.z - 1.0)
		_box(awn, pos + off + street * 0.8 + Vector3(0, base + 3.7, 0), _mat(shop.emission.darkened(0.3), 0.8), false)

# ---------------------------------------------------------------- lampadaires
func _lamps() -> void:
	lamp_mat = StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(1, 0.95, 0.85)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1, 0.8, 0.5)
	lamp_mat.emission_energy_multiplier = 0.2
	var poles: Array[Transform3D] = []
	var heads: Array[Transform3D] = []
	for i in GRID.size():
		var off := half(i) + 1.4
		var s := -CITY
		while s < CITY:
			var near_cross := false
			for g in GRID:
				if absf(s - g) < 14:
					near_cross = true
			if not near_cross:
				for side in [-1, 1]:
					var p1 := Vector3(GRID[i] + side * off, 0, s)
					var p2 := Vector3(s, 0, GRID[i] + side * off)
					var h1 := p1 + Vector3(-side * 1.4, 7.1, 0)
					var h2 := p2 + Vector3(0, 7.1, -side * 1.4)
					poles.append(Transform3D(Basis(), p1 + Vector3(0, 3.6, 0)))
					poles.append(Transform3D(Basis(), p2 + Vector3(0, 3.6, 0)))
					heads.append(Transform3D(Basis(), h1))
					heads.append(Transform3D(Basis(), h2))
					lamp_heads.append(h1)
					lamp_heads.append(h2)
			s += 32
	_multi(poles, _cyl_mesh(0.12, 7.2), _mat(Color(0.3, 0.32, 0.35), 0.5, 0.6), true)
	var hm := BoxMesh.new()
	hm.size = Vector3(0.8, 0.2, 0.8)
	_multi(heads, hm, lamp_mat, false)

func _cyl_mesh(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r * 1.3
	c.height = h
	c.radial_segments = 8
	return c

func _multi(xf: Array[Transform3D], mesh: Mesh, material: Material, shadows: bool) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for k in xf.size():
		mm.set_instance_transform(k, xf[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

# ---------------------------------------------------------------- végétation, campagne
func _palms(points: Array[Vector3]) -> void:
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	for p in points:
		var s := rng.randf_range(0.85, 1.25)
		trunks.append(Transform3D(Basis().scaled(Vector3(s, s, s)), p + Vector3(0, 4 * s, 0)))
		crowns.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s * 3.2, s * 1.1, s * 3.2)), p + Vector3(0, 8 * s, 0)))
	_multi(trunks, _cyl_mesh(0.22, 8.0), _mat(Color(0.5, 0.38, 0.25), 0.9), true)
	var crown := SphereMesh.new()
	crown.radial_segments = 7
	crown.rings = 3
	_multi(crowns, crown, _mat(Color(0.22, 0.5, 0.22), 0.9), true)

func _on_road(p: Vector3) -> bool:
	if absf(p.x) < CITY + 20 and absf(p.z) < CITY + 20:
		return true
	if absf(p.x) < 14 or absf(p.z) < 14:
		return true
	if absf(p.x - (COAST - 50)) < 14 or p.x > COAST - 70:
		return true
	return false

func _countryside() -> void:
	# champs colorés
	var crops := [Color(0.85, 0.75, 0.35), Color(0.55, 0.42, 0.28), Color(0.45, 0.62, 0.28), Color(0.62, 0.52, 0.8), Color(0.95, 0.8, 0.2)]
	for k in 36:
		var p := Vector3(rng.randf_range(-1300, 800), 0.04, rng.randf_range(-1300, 1300))
		var s := Vector2(rng.randf_range(60, 160), rng.randf_range(60, 160))
		if _on_road(p) or absf(p.x) - s.x / 2 < CITY + 30 and absf(p.z) - s.y / 2 < CITY + 30:
			continue
		if absf(p.x) < s.x / 2 + 12 or absf(p.z) < s.y / 2 + 12:
			continue
		_plane(s, p, _mat(crops[rng.randi() % crops.size()], 1.0))
	# arbres
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	for k in 2500:
		var p := Vector3(rng.randf_range(-1400, COAST - 80), 0, rng.randf_range(-1400, 1400))
		if _on_road(p):
			continue
		var s := rng.randf_range(0.8, 1.6)
		trunks.append(Transform3D(Basis().scaled(Vector3(s, s, s)), p + Vector3(0, 1.5 * s, 0)))
		crowns.append(Transform3D(Basis().scaled(Vector3(3 * s, 3.4 * s, 3 * s)), p + Vector3(0, 4.6 * s, 0)))
	_multi(trunks, _cyl_mesh(0.25, 3.0), _mat(Color(0.4, 0.28, 0.18), 0.9), true)
	var crown := SphereMesh.new()
	crown.radial_segments = 8
	crown.rings = 5
	_multi(crowns, crown, _mat(Color(0.27, 0.48, 0.22), 0.95), true)
	# palmiers le long de la plage
	var palms: Array[Vector3] = []
	var z := -1300.0
	while z < 1300:
		palms.append(Vector3(COAST - 30 + rng.randf_range(-4, 4), 0, z))
		z += rng.randf_range(18, 40)
	_palms(palms)
