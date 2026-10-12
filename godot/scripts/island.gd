class_name Island
extends Node3D
## L'île de Solena : terrain en relief (plages, plaines, collines, montagnes enneigées, désert et canyon),
## deux villes (Solena et Porto Sol), routes qui suivent le relief, deux aéroports orientés différemment,
## forêts, cactus, palmiers, herbe et mer.

const SIZE := 11200.0            # côté du terrain (m)
const RES := 897                # sommets par côté (maille de 12,5 m)
const CHUNKS := 14              # le terrain est découpé en 10 x 10 morceaux (affichage plus rapide)
const SEA := -3.0               # niveau de la mer ; les villes sont à 0
const HALF := SIZE / 2.0

# plan de l'île (x, z)
const CITY_A := Vector2(0, 0)            # Solena
const CITY_B := Vector2(-1900, 1400)     # Porto Sol
const CITY_R := 470.0
const DESERT_C := Vector2(1800, 1500)
const MOUNT_A := Vector2(-2200, -1500)
const MOUNT_B := Vector2(-700, -2300)
# aéroports : pistes à 30° et 125°, jamais parallèles
const AIRPORTS := [
	{"name": "AÉROPORT DE SOLENA", "pos": Vector2(1550, -1150), "yaw": 30.0, "len": 2000.0, "term_side": 1},
	{"name": "AÉROPORT DE PORTO SOL", "pos": Vector2(-450, 1600), "yaw": 125.0, "len": 1500.0, "term_side": 1},
]

var cell: float = SIZE / (RES - 1)
var h: PackedFloat32Array
var flat_w: PackedFloat32Array
var flat_h: PackedFloat32Array
var splat: PackedColorArray
var noise := FastNoiseLite.new()
var noise2 := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()
var roads: Array = []            # {pts: PackedVector3Array, w: float, kind: String, name: String}
var cities: Array = []           # nœuds World
var body: StaticBody3D
var height_tex: ImageTexture
var tree_pts: Array = []
var palm_pts: Array = []
var port := {}

func build() -> void:
	rng.seed = 2026
	noise.seed = 11
	noise.frequency = 0.0006
	noise.fractal_octaves = 5
	noise2.seed = 23
	noise2.frequency = 0.003
	noise2.fractal_octaves = 3
	body = StaticBody3D.new()
	add_child(body)
	_heights()
	_flatten_zones()
	_define_roads()
	_flatten_roads()
	_apply_flatten()
	_splat()
	_terrain_meshes()
	_terrain_collision()
	_sea()
	_clouds()
	_road_meshes()
	_airports()
	_cities()
	KenneyLib.dress_island(self)
	Landmarks.build_all(self)
	_desert_mesas()
	_vegetation()

# ------------------------------------------------------------------ utilitaires de grille
func idx(i: int, j: int) -> int:
	return j * RES + i

func to_grid(x: float, z: float) -> Vector2:
	return Vector2((x + HALF) / cell, (z + HALF) / cell)

## Hauteur du terrain en un point (interpolation bilinéaire)
func height_at(x: float, z: float) -> float:
	var g := to_grid(x, z)
	var i := clampi(int(g.x), 0, RES - 2)
	var j := clampi(int(g.y), 0, RES - 2)
	var fx := clampf(g.x - i, 0.0, 1.0)
	var fz := clampf(g.y - j, 0.0, 1.0)
	var a := lerpf(h[idx(i, j)], h[idx(i + 1, j)], fx)
	var b := lerpf(h[idx(i, j + 1)], h[idx(i + 1, j + 1)], fx)
	return lerpf(a, b, fz)

func in_city(p: Vector2, margin := 0.0) -> bool:
	for c in [CITY_A, CITY_B]:
		if absf(p.x - c.x) < CITY_R + margin and absf(p.y - c.y) < CITY_R + margin:
			return true
	return false

func in_city_core(p: Vector2) -> bool:
	for c in [CITY_A, CITY_B]:
		if absf(p.x - c.x) < 405.0 and absf(p.y - c.y) < 405.0:
			return true
	return false

## proche d'une route, d'une ville ou d'un aéroport (bande aplanie)
func near_flat(p: Vector2, level := 0.15) -> bool:
	var g := to_grid(p.x, p.y)
	var k := idx(clampi(int(round(g.x)), 0, RES - 1), clampi(int(round(g.y)), 0, RES - 1))
	return flat_w[k] > level

func desert_amount(p: Vector2) -> float:
	return clampf(1.0 - (p.distance_to(DESERT_C) - 700.0) / 500.0, 0.0, 1.0)

# ------------------------------------------------------------------ relief
func _heights() -> void:
	h.resize(RES * RES)
	flat_w.resize(RES * RES)
	flat_h.resize(RES * RES)
	for j in RES:
		for i in RES:
			var x := -HALF + i * cell
			var z := -HALF + j * cell
			var p := Vector2(x, z)
			# contour de l'île : rayon irrégulier (caps, baies)
			var ang := atan2(z, x)
			var rad := 4700.0 + noise.get_noise_2d(cos(ang) * 900.0, sin(ang) * 900.0) * 700.0 + sin(ang * 3.0 + 1.0) * 180.0
			var d := p.length()
			var land := clampf((rad - d) / 380.0, 0.0, 1.0)
			var base := 1.5 + (noise.get_noise_2dv(p) * 0.5 + 0.5) * 14.0 + noise2.get_noise_2dv(p) * 2.5
			# chaîne de montagnes au nord-ouest (neige au sommet)
			var seg := Geometry2D.get_closest_point_to_segment(p, MOUNT_A, MOUNT_B)
			var md := p.distance_to(seg)
			var mount := pow(clampf(1.0 - md / 900.0, 0.0, 1.0), 1.6) * (220.0 + noise2.get_noise_2d(x * 0.7, z * 0.7) * 90.0)
			# désert : dunes basses
			var des := desert_amount(p)
			var dunes := des * (sin(x * 0.02 + noise2.get_noise_2dv(p) * 3.0) * 2.5 + 3.0)
			var height := base + mount + dunes
			h[idx(i, j)] = lerpf(SEA - 14.0, height, smoothstep(0.0, 1.0, land))
			flat_w[idx(i, j)] = 0.0

## Zones rendues plates : villes (à 0 m) et aéroports (à 1 m)
func _flatten_rect(center: Vector2, half_len: float, half_wid: float, yaw_deg: float, target: float, blend: float) -> void:
	var yaw := deg_to_rad(yaw_deg)
	var ax := Vector2(cos(yaw), sin(yaw))
	var ay := Vector2(-ax.y, ax.x)
	var r := half_len + half_wid + blend
	var g0 := to_grid(center.x - r, center.y - r)
	var g1 := to_grid(center.x + r, center.y + r)
	for j in range(maxi(0, int(g0.y)), mini(RES, int(g1.y) + 2)):
		for i in range(maxi(0, int(g0.x)), mini(RES, int(g1.x) + 2)):
			var p := Vector2(-HALF + i * cell, -HALF + j * cell) - center
			var dl := absf(p.dot(ax)) - half_len
			var dw := absf(p.dot(ay)) - half_wid
			var d := maxf(maxf(dl, dw), 0.0)
			var w := 1.0 - smoothstep(0.0, blend, d)
			var k := idx(i, j)
			if w > flat_w[k]:
				flat_w[k] = w
				flat_h[k] = target

func _flatten_zones() -> void:
	for c in [CITY_A, CITY_B]:
		_flatten_rect(c, CITY_R + 30.0, CITY_R + 30.0, 0.0, 0.0, 160.0)
	for a in AIRPORTS:
		_flatten_rect(a.pos, a.len / 2.0 + 150.0, 330.0, a.yaw, 1.0, 180.0)
	Landmarks.plan_port(self)

func airport_frame(a: Dictionary) -> Array:
	var yaw := deg_to_rad(a.yaw)
	var ax := Vector2(cos(yaw), sin(yaw))
	var ay := Vector2(-ax.y, ax.x) * float(a.term_side)
	return [ax, ay]

# ------------------------------------------------------------------ routes
func _poly(points: Array, step := 6.0) -> PackedVector3Array:
	# courbe lisse (Catmull-Rom) passant par les points, échantillonnée tous les `step` mètres
	var out := PackedVector3Array()
	for s in points.size() - 1:
		var p0: Vector2 = points[maxi(s - 1, 0)]
		var p1: Vector2 = points[s]
		var p2: Vector2 = points[s + 1]
		var p3: Vector2 = points[mini(s + 2, points.size() - 1)]
		var n := maxi(2, int(p1.distance_to(p2) / step))
		for k in n:
			var t := float(k) / n
			var t2 := t * t
			var t3 := t2 * t
			var q := 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
			out.append(Vector3(q.x, 0, q.y))
	var last: Vector2 = points[points.size() - 1]
	out.append(Vector3(last.x, 0, last.y))
	return out

func terminal_point(a: Dictionary, extra := 0.0) -> Vector2:
	var fr := airport_frame(a)
	return (a.pos as Vector2) + (fr[1] as Vector2) * (230.0 + extra)

func _define_roads() -> void:
	var tA := terminal_point(AIRPORTS[0], 120.0)
	var tB := terminal_point(AIRPORTS[1], 120.0)
	var defs := [
		# autoroute entre les deux villes, par les plaines
		["Autoroute A1", "highway", 12.0, [Vector2(-410, 0), Vector2(-900, 250), Vector2(-1250, 700), Vector2(-1500, 1100), Vector2(-1490, 1400)]],
		# Solena → aéroport de Solena (arrive côté aérogare, ne croise pas la piste)
		["Avenue de l'Aéroport", "country", 8.0, [Vector2(410, -120), Vector2(800, -300), Vector2(1100, -600), tA]],
		# Porto Sol → aéroport de Porto Sol
		["Route de l'Aéroport Sud", "country", 8.0, [Vector2(-1430, 1520), Vector2(-1150, 1560), tB]],
		# route de montagne au nord
		["Route des Cimes", "country", 7.0, [Vector2(0, -410), Vector2(-250, -1000), Vector2(-700, -1500), Vector2(-1300, -1750), Vector2(-1900, -2000), Vector2(-2450, -1500), Vector2(-2600, -700), Vector2(-2300, 200)]],
		["Route du Sud", "country", 7.5, [Vector2(2200, 1750), Vector2(1500, 2250), Vector2(800, 2400), Vector2(100, 2350), Vector2(-650, 2550), Vector2(-1350, 2300), Vector2(-1900, 1870)]],
		# route du désert et du canyon vers le sud-est
		["Route du Désert", "country", 7.5, [Vector2(0, 410), Vector2(300, 900), Vector2(900, 1250), Vector2(1600, 1450), Vector2(2200, 1750)]],
		# route côtière de l'est
		["Route du Littoral", "country", 7.5, [Vector2(410, 120), Vector2(1100, 250), Vector2(2000, 350), Vector2(2500, 800), Vector2(2400, 1400), Vector2(2200, 1750)]],
		# route des fermes, à l'ouest
		["Route des Vergers", "country", 7.0, [Vector2(-410, -120), Vector2(-1000, -400), Vector2(-1700, -300), Vector2(-2300, 200), Vector2(-2350, 900), Vector2(-2370, 1300)]],
		# route panoramique : tour complet de l'île, et liaisons vers les routes intérieures
		["Route Panoramique", "country", 7.5, [Vector2(3600, 0), Vector2(3118, 1800), Vector2(1800, 3118), Vector2(0, 3600), Vector2(-1800, 3118), Vector2(-3118, 1800), Vector2(-3600, 0), Vector2(-3118, -1800), Vector2(-1800, -3118), Vector2(0, -3600), Vector2(1800, -3118), Vector2(3118, -1800), Vector2(3600, 0)]],
		["Liaison Ouest", "country", 7.0, [Vector2(-2600, -700), Vector2(-3050, -820), Vector2(-3477, -932)]],
		["Liaison Est", "country", 7.0, [Vector2(2500, 800), Vector2(3000, 870), Vector2(3477, 932)]],
		["Liaison Sud", "country", 7.0, [Vector2(800, 2400), Vector2(870, 2950), Vector2(932, 3477)]],
	]
	for d in defs:
		roads.append({"name": d[0], "kind": d[1], "w": d[2], "pts": _poly(d[3])})
	Landmarks.extra_roads(self)

func _flatten_roads() -> void:
	# profil en long lissé (pas de bosses brutales), puis aplanissement d'une bande autour de la route
	for r in roads:
		var pts: PackedVector3Array = r.pts
		var raw := PackedFloat32Array()
		for p in pts:
			var g := to_grid(p.x, p.z)
			var k := idx(clampi(int(round(g.x)), 0, RES - 1), clampi(int(round(g.y)), 0, RES - 1))
			var hh := lerpf(h[k], flat_h[k], flat_w[k])
			raw.append(maxf(hh, 0.6))
		var win := 20
		for i in pts.size():
			var s := 0.0
			var n := 0
			for k in range(maxi(0, i - win), mini(pts.size(), i + win + 1)):
				s += raw[k]
				n += 1
			var y := s / n
			if in_city(Vector2(pts[i].x, pts[i].z), 40.0):
				y = 0.0
			pts[i] = Vector3(pts[i].x, y, pts[i].z)
		r.pts = pts
		var reach: float = r.w + 28.0
		for i in range(0, pts.size(), 1):
			var p := pts[i]
			var g0 := to_grid(p.x - reach, p.z - reach)
			var g1 := to_grid(p.x + reach, p.z + reach)
			for j in range(maxi(0, int(g0.y)), mini(RES, int(g1.y) + 2)):
				for ii in range(maxi(0, int(g0.x)), mini(RES, int(g1.x) + 2)):
					var q := Vector2(-HALF + ii * cell, -HALF + j * cell)
					var d := q.distance_to(Vector2(p.x, p.z)) - float(r.w)
					var w := 1.0 - smoothstep(0.0, 26.0, d)
					var k := idx(ii, j)
					if w > flat_w[k]:
						flat_w[k] = w
						flat_h[k] = p.y - 0.05

func _apply_flatten() -> void:
	for k in h.size():
		if flat_w[k] > 0.0:
			h[k] = lerpf(h[k], flat_h[k], flat_w[k])

# ------------------------------------------------------------------ couleurs du sol (sable, roche, sec, neige)
func _splat() -> void:
	splat.resize(RES * RES)
	for j in RES:
		for i in RES:
			var k := idx(i, j)
			var x := -HALF + i * cell
			var z := -HALF + j * cell
			var y := h[k]
			var hx := h[idx(mini(i + 1, RES - 1), j)] - h[idx(maxi(i - 1, 0), j)]
			var hz := h[idx(i, mini(j + 1, RES - 1))] - h[idx(i, maxi(j - 1, 0))]
			var slope := Vector2(hx, hz).length() / (2.0 * cell)
			var sand := clampf(1.0 - (y - (SEA + 1.0)) / 3.5, 0.0, 1.0)
			var des := desert_amount(Vector2(x, z))
			sand = maxf(sand, des * 0.9)
			var rock := clampf((slope - 0.35) * 3.0, 0.0, 1.0) + clampf((y - 110.0) / 60.0, 0.0, 1.0)
			var dry := clampf(noise2.get_noise_2d(x * 0.3, z * 0.3) * 0.8 + 0.2, 0.0, 0.6) * (1.0 - des)
			var snow := clampf((y - 230.0) / 40.0, 0.0, 1.0)
			if flat_w[k] > 0.9 and y > -0.5 and y < 1.5 and des < 0.5:
				dry = 0.35
			splat[k] = Color(clampf(sand, 0, 1), clampf(rock, 0, 1), dry, snow)

# ------------------------------------------------------------------ maillage du terrain (9 x 9 morceaux)
func _terrain_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/terrain.gdshader")
	m.set_shader_parameter("tex_grass", Kit.tex(Kit.tint_image(512, Color(0.22, 0.38, 0.14), Color(0.42, 0.55, 0.22), 0.03, 31, 0.15, Color(0.55, 0.62, 0.3))))
	m.set_shader_parameter("tex_dry", Kit.tex(Kit.tint_image(256, Color(0.52, 0.5, 0.28), Color(0.68, 0.62, 0.38), 0.04, 32, 0.1, Color(0.4, 0.38, 0.22))))
	m.set_shader_parameter("tex_sand", Kit.tex(Kit.tint_image(256, Color(0.8, 0.68, 0.46), Color(0.93, 0.84, 0.62), 0.05, 41, 0.1, Color(0.7, 0.58, 0.4))))
	m.set_shader_parameter("tex_rock", Kit.tex(Kit.tint_image(256, Color(0.38, 0.35, 0.32), Color(0.6, 0.56, 0.5), 0.06, 51, 0.2, Color(0.3, 0.28, 0.26))))
	var nimg := Kit.noise_image(256, 0.05, 61)
	m.set_shader_parameter("tex_normal", Kit.normal_from(nimg, 3.0))
	return m

func _terrain_meshes() -> void:
	var mat := _terrain_material()
	var per := (RES - 1) / CHUNKS
	var w := per + 1
	var ids := PackedInt32Array()
	for j in per:
		for i in per:
			var a := j * w + i
			ids.append_array([a, a + 1, a + w, a + 1, a + w + 1, a + w])
	for cj in CHUNKS:
		for ci in CHUNKS:
			var verts := PackedVector3Array()
			var norms := PackedVector3Array()
			var cols := PackedColorArray()
			verts.resize(w * w)
			norms.resize(w * w)
			cols.resize(w * w)
			var n := 0
			for j in range(cj * per, cj * per + w):
				for i in range(ci * per, ci * per + w):
					var k := idx(i, j)
					var hx := h[idx(mini(i + 1, RES - 1), j)] - h[idx(maxi(i - 1, 0), j)]
					var hz := h[idx(i, mini(j + 1, RES - 1))] - h[idx(i, maxi(j - 1, 0))]
					norms[n] = Vector3(-hx, 2.0 * cell, -hz).normalized()
					cols[n] = splat[k]
					verts[n] = Vector3(-HALF + i * cell, h[k], -HALF + j * cell)
					n += 1
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = verts
			arr[Mesh.ARRAY_NORMAL] = norms
			arr[Mesh.ARRAY_COLOR] = cols
			arr[Mesh.ARRAY_INDEX] = ids
			var am := ArrayMesh.new()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var mi := MeshInstance3D.new()
			mi.mesh = am
			mi.material_override = mat
			add_child(mi)

func _terrain_collision() -> void:
	# carte de hauteurs physique (unités de la grille, mise à l'échelle uniforme)
	var shape := HeightMapShape3D.new()
	shape.map_width = RES
	shape.map_depth = RES
	var data := PackedFloat32Array()
	data.resize(RES * RES)
	for k in h.size():
		data[k] = h[k] / cell
	shape.map_data = data
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3(cell, cell, cell)
	body.add_child(cs)
	# murs invisibles au large
	for s in [-1, 1]:
		var b1 := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(20, 400, SIZE)
		b1.shape = sh
		b1.position = Vector3(s * (HALF - 150), 150, 0)
		body.add_child(b1)
		var b2 := CollisionShape3D.new()
		var sh2 := BoxShape3D.new()
		sh2.size = Vector3(SIZE, 400, 20)
		b2.shape = sh2
		b2.position = Vector3(0, 150, s * (HALF - 150))
		body.add_child(b2)

# ------------------------------------------------------------------ mer
func _sea() -> void:
	var img := Image.create(RES, RES, false, Image.FORMAT_RF)
	for j in RES:
		for i in RES:
			img.set_pixel(i, j, Color(h[idx(i, j)], 0, 0))
	height_tex = ImageTexture.create_from_image(img)
	var sh := ShaderMaterial.new()
	sh.shader = load("res://shaders/water.gdshader")
	sh.set_shader_parameter("wave_normal", Kit.normal_from(Kit.noise_image(256, 0.06, 91), 6.0))
	sh.set_shader_parameter("terrain_height", height_tex)
	sh.set_shader_parameter("terrain_size", SIZE)
	sh.set_shader_parameter("sea_level", SEA)
	var pm := PlaneMesh.new()
	pm.size = Vector2(SIZE + 40000, SIZE + 40000)
	pm.subdivide_width = 220
	pm.subdivide_depth = 220
	var sea := MeshInstance3D.new()
	sea.mesh = pm
	sea.material_override = sh
	sea.position = Vector3(0, SEA, 0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)

# ------------------------------------------------------------------ routes (rubans qui épousent le relief)
func _ribbon(pts: PackedVector3Array, half_w: float, y_off: float, mat: Material, uv_len := 0.0) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dist := 0.0
	for i in pts.size():
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, pts.size() - 1)]
		var t := (b - a)
		t.y = 0
		t = t.normalized()
		var n := Vector3(-t.z, 0, t.x)
		if i > 0:
			dist += Vector2(pts[i].x - pts[i - 1].x, pts[i].z - pts[i - 1].z).length()
		var v := dist / uv_len if uv_len > 0.0 else dist / 10.0
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0, v))
		st.add_vertex(pts[i] + n * half_w + Vector3(0, y_off, 0))
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(1, v))
		st.add_vertex(pts[i] - n * half_w + Vector3(0, y_off, 0))
	for i in pts.size() - 1:
		var a := i * 2
		st.add_index(a)
		st.add_index(a + 2)
		st.add_index(a + 1)
		st.add_index(a + 1)
		st.add_index(a + 2)
		st.add_index(a + 3)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _dash_material(col: Color, dashed: bool) -> StandardMaterial3D:
	var img := Image.create(8, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 8:
			var on := (not dashed) or y < 26
			img.set_pixel(x, y, Color(col.r, col.g, col.b, 1.0 if on else 0.0))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.roughness = 0.6
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _road_meshes() -> void:
	var asphalt := Kit.asphalt()
	var shoulder := Kit.color_mat(Color(0.52, 0.5, 0.45), 0.95)
	var white := _dash_material(Color(0.93, 0.93, 0.9), true)
	var edge := _dash_material(Color(0.93, 0.93, 0.9), false)
	var yellow := _dash_material(Color(0.95, 0.78, 0.2), false)
	for r in roads:
		if r.kind == "rail":
			continue
		var pts: PackedVector3Array = r.pts
		# on ne dessine pas les tronçons à l'intérieur des villes (elles ont leurs propres rues)
		var runs: Array = []
		var cur := PackedVector3Array()
		for p in pts:
			if in_city_core(Vector2(p.x, p.z)):
				if cur.size() > 1:
					runs.append(cur)
				cur = PackedVector3Array()
			else:
				cur.append(p)
		if cur.size() > 1:
			runs.append(cur)
		for run in runs:
			_ribbon(run, float(r.w) + 1.6, 0.03, shoulder)
			_ribbon(run, float(r.w), 0.06, asphalt)
			if r.kind == "highway":
				_ribbon(_offset(run, 0.25), 0.1, 0.075, yellow)
				_ribbon(_offset(run, -0.25), 0.1, 0.075, yellow)
				_ribbon(_offset(run, 5.8), 0.08, 0.075, white, 9.0)
				_ribbon(_offset(run, -5.8), 0.08, 0.075, white, 9.0)
			else:
				_ribbon(run, 0.08, 0.075, white, 9.0)
			_ribbon(_offset(run, float(r.w) - 0.4), 0.08, 0.075, edge)
			_ribbon(_offset(run, -float(r.w) + 0.4), 0.08, 0.075, edge)

func _offset(pts: PackedVector3Array, off: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in pts.size():
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, pts.size() - 1)]
		var t := (b - a)
		t.y = 0
		t = t.normalized()
		out.append(pts[i] + Vector3(-t.z, 0, t.x) * off)
	return out

# ------------------------------------------------------------------ aéroports
func _airports() -> void:
	for a in AIRPORTS:
		var fr := airport_frame(a)
		var ax: Vector2 = fr[0]
		var ay: Vector2 = fr[1]
		var c: Vector2 = a.pos
		var yaw := -atan2(ax.y, ax.x)
		var L: float = a.len
		var y := 1.0
		# piste avec marquages
		var rw := _box(Vector3(L, 0.1, 60), Vector3(c.x, y, c.y), Kit.asphalt(), yaw)
		rw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var white := Kit.color_mat(Color(0.95, 0.95, 0.92), 0.6)
		for s in range(-int(L / 2) + 80, int(L / 2) - 80, 60):
			_box(Vector3(30, 0.02, 1.0), _v(c + ax * s, y + 0.06), white, yaw)
		for side in [-1, 1]:
			for k in 8:
				_box(Vector3(40, 0.02, 2.2), _v(c + ax * side * (L / 2 - 40) + ay * (k - 3.5) * 5.5, y + 0.06), white, yaw)
			_box(Vector3(L, 0.02, 0.8), _v(c + ay * side * 27.0, y + 0.06), white, yaw)
		# feux de bord de piste
		var lamps: Array = []
		for s in range(-int(L / 2), int(L / 2) + 1, 60):
			for side in [-1, 1]:
				lamps.append(Transform3D(Basis(), _v(c + ax * s + ay * side * 31.0, y + 0.2)))
		var sph := SphereMesh.new()
		sph.radius = 0.35
		sph.height = 0.7
		Kit.multimesh(self, sph, lamps, Kit.glow_mat(Color(1, 0.95, 0.8), 2.5), false)
		# voie de circulation, tarmac, aérogare, tour, hangars
		_box(Vector3(L * 0.9, 0.08, 24), _v(c + ay * 110.0, y), Kit.asphalt(), yaw)
		_box(Vector3(600, 0.08, 150), _v(c + ay * 190.0, y), Kit.color_mat(Color(0.6, 0.6, 0.58), 0.9), yaw)
		var term := c + ay * 300.0
		var fac := Kit.facade(2, Color(0.8, 0.9, 1.0))
		Landmarks.terminal(self, a, _v(term, y), yaw)
		var lbl := Label3D.new()
		lbl.text = a.name
		lbl.font_size = 220
		lbl.pixel_size = 0.03
		lbl.modulate = Color(1, 0.95, 0.85)
		lbl.outline_size = 30
		lbl.position = _v(term - ay * 21.0, y + 21.0)
		lbl.rotation.y = yaw + (PI if a.term_side > 0 else 0.0)
		add_child(lbl)
		var tower := c + ay * 250.0 + ax * 260.0
		var cyl := CylinderMesh.new()
		cyl.top_radius = 3.0
		cyl.bottom_radius = 4.0
		cyl.height = 40
		_mesh(cyl, _v(tower, y + 20), Kit.color_mat(Color(0.95, 0.95, 0.95), 0.5))
		var cab := CylinderMesh.new()
		cab.top_radius = 6.5
		cab.bottom_radius = 5.0
		cab.height = 5
		_mesh(cab, _v(tower, y + 42.5), Kit.glow_mat(Color(0.5, 0.8, 1.0), 0.6))
		_col_box(Vector3(9, 46, 9), _v(tower, y + 23), 0)
		for k in 2:
			var hp := c + ay * 230.0 - ax * (330.0 + k * 110.0)
			_box(Vector3(90, 22, 70), _v(hp, y + 11), Kit.facade(2, Color(0.85, 0.87, 0.9)), yaw, true)

func _v(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)

func _mesh(m: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi

func _box(size: Vector3, pos: Vector3, mat: Material, yaw := 0.0, collide := false) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := _mesh(bm, pos, mat)
	mi.rotation.y = yaw
	if collide:
		_col_box(size, pos, yaw)
	return mi

func _col_box(size: Vector3, pos: Vector3, yaw: float) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	cs.rotation.y = yaw
	body.add_child(cs)

# ------------------------------------------------------------------ villes
func _cities() -> void:
	var defs := [[CITY_A, 424242, "SOLENA"], [CITY_B, 777111, "PORTO SOL"]]
	for d in defs:
		var w := World.new()
		w.city_only = true
		w.seed_value = d[1]
		w.city_name = d[2]
		w.position = Vector3((d[0] as Vector2).x, 0, (d[0] as Vector2).y)
		add_child(w)
		w.build()
		cities.append(w)

# ------------------------------------------------------------------ désert : mesas en strates
func _desert_mesas() -> void:
	var strata := [Color(0.71, 0.38, 0.23), Color(0.79, 0.48, 0.29), Color(0.64, 0.33, 0.18), Color(0.85, 0.6, 0.38)]
	for k in 70:
		var p := DESERT_C + Vector2(rng.randf_range(-900, 900), rng.randf_range(-800, 800))
		if desert_amount(p) < 0.8 or _near_road(p, 60.0) or _near_airport(p, 250.0):
			continue
		var r0 := rng.randf_range(14, 42)
		var hh := rng.randf_range(20, 75)
		var layers := rng.randi_range(3, 5)
		var yb := height_at(p.x, p.y) - 2.0
		var r := r0
		for l in layers:
			var lh := hh / layers * rng.randf_range(0.8, 1.2)
			var cm := CylinderMesh.new()
			cm.top_radius = r * rng.randf_range(0.82, 0.95)
			cm.bottom_radius = r
			cm.height = lh
			cm.radial_segments = 11
			var mi := _mesh(cm, Vector3(p.x, yb + lh / 2.0, p.y), Kit.pbr("mesa_%d" % (l % 4), Kit.tint_image(128, strata[l % 4], (strata[l % 4] as Color).lightened(0.15), 0.08, 70 + l), 0.95, 4.0, 1.0))
			mi.rotation.y = rng.randf() * TAU
			yb += lh
			r *= rng.randf_range(0.72, 0.9)
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = r0 * 0.95
		sh.height = hh + 4.0
		cs.shape = sh
		cs.position = Vector3(p.x, height_at(p.x, p.y) + hh / 2.0, p.y)
		body.add_child(cs)

func _near_road(p: Vector2, dist: float) -> bool:
	for r in roads:
		var pts: PackedVector3Array = r.pts
		for i in range(0, pts.size(), 3):
			if absf(pts[i].x - p.x) < dist and absf(pts[i].z - p.y) < dist and Vector2(pts[i].x, pts[i].z).distance_to(p) < dist:
				return true
	return false

func _near_airport(p: Vector2, dist: float) -> bool:
	for a in AIRPORTS:
		var fr := airport_frame(a)
		var q: Vector2 = p - (a.pos as Vector2)
		if absf(q.dot(fr[0])) < a.len / 2.0 + dist and absf(q.dot(fr[1]) - 150.0) < 250.0 + dist:
			return true
	return false

# ------------------------------------------------------------------ végétation
func _vegetation() -> void:
	var cacti: Array = []
	var grass: Array = []
	for k in 120000:
		var p := Vector2(rng.randf_range(-HALF + 200, HALF - 200), rng.randf_range(-HALF + 200, HALF - 200))
		var y := height_at(p.x, p.y)
		if y < SEA + 1.2 or y > 200.0:
			continue
		if in_city(p, 20.0) or _near_airport(p, 40.0):
			continue
		var des := desert_amount(p)
		var md := p.distance_to(Geometry2D.get_closest_point_to_segment(p, MOUNT_A, MOUNT_B))
		var forest := md < 1300.0 and noise2.get_noise_2dv(p) > -0.25
		var coast := y < SEA + 4.5
		var prob := 0.02
		if forest:
			prob = 0.55
		elif coast:
			prob = 0.25
		elif des > 0.5:
			prob = 0.08
		if rng.randf() > prob:
			continue
		if near_flat(p, 0.08):
			continue
		var pos := Vector3(p.x, y - 0.2, p.y)
		if des > 0.5:
			cacti.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.5)), pos))
		elif coast:
			palm_pts.append([pos, rng.randf_range(0.9, 1.3)])
		else:
			tree_pts.append([pos, rng.randf_range(0.9, 1.9) if forest else rng.randf_range(0.8, 1.4), rng.randi() % 3])
		if tree_pts.size() + palm_pts.size() < 9000:
			var cs := CollisionShape3D.new()
			var sh := CylinderShape3D.new()
			sh.radius = 0.4
			sh.height = 4.0
			cs.shape = sh
			cs.position = pos + Vector3(0, 2, 0)
			body.add_child(cs)
	# herbe haute le long des routes et dans les plaines
	for k in 140000:
		var p := Vector2(rng.randf_range(-HALF + 300, HALF - 300), rng.randf_range(-HALF + 300, HALF - 300))
		var y := height_at(p.x, p.y)
		if y < SEA + 2.0 or y > 120.0 or desert_amount(p) > 0.3 or in_city(p, 10.0) or _near_airport(p, 20.0) or near_flat(p, 0.6):
			continue
		var s := rng.randf_range(0.5, 1.1)
		grass.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s * 1.4, s, s * 1.4)), Vector3(p.x, y - 0.05, p.y)))
	var grass_mm := Kit.multimesh(self, Kit.grass_card_mesh(), grass, Kit.grass_card_material(), false)
	grass_mm.visibility_range_end = 320.0
	if NatureKit.render(self, tree_pts, palm_pts, cacti):
		return
	# rendu instancié (mêmes modèles que dans les villes)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.32
	trunk.height = 3.2
	trunk.radial_segments = 8
	var trunk_xf: Array = []
	var crowns := [[], [], []]
	for t in tree_pts:
		var p: Vector3 = t[0]
		var s: float = t[1]
		trunk_xf.append(Transform3D(Basis().scaled(Vector3(s, s, s)), p + Vector3(0, 1.6 * s, 0)))
		crowns[t[2]].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(2.6 * s, 2.8 * s, 2.6 * s)), p + Vector3(0, 4.4 * s, 0)))
	var tr := Kit.multimesh(self, trunk, trunk_xf, Kit.bark(), true)
	tr.visibility_range_end = 1400.0
	var tints := [Color(0.28, 0.5, 0.2), Color(0.36, 0.53, 0.18), Color(0.22, 0.42, 0.2)]
	for v in 3:
		var cm := Kit.multimesh(self, Kit.crown_mesh(100 + v), crowns[v], Kit.foliage(tints[v], "leaf_%d" % v), true)
		cm.visibility_range_end = 2200.0
	var ptrunk := CylinderMesh.new()
	ptrunk.top_radius = 0.2
	ptrunk.bottom_radius = 0.32
	ptrunk.height = 8.0
	var pxf: Array = []
	var fxf: Array = []
	for pp in palm_pts:
		var p: Vector3 = pp[0]
		var s: float = pp[1]
		pxf.append(Transform3D(Basis().scaled(Vector3(s, s, s)), p + Vector3(0, 4 * s, 0)))
		fxf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), p + Vector3(0, 8 * s, 0)))
	Kit.multimesh(self, ptrunk, pxf, Kit.bark(), true)
	Kit.multimesh(self, Kit.fronds_mesh(), fxf, Kit.frond_material(), true)
	# cactus (tronc + deux bras)
	var cactus_parts: Array = []
	var arm := CylinderMesh.new()
	arm.top_radius = 0.28
	arm.bottom_radius = 0.32
	arm.height = 1.8
	var stem := CylinderMesh.new()
	stem.top_radius = 0.42
	stem.bottom_radius = 0.5
	stem.height = 4.4
	var cmat := Kit.pbr("cactus", Kit.tint_image(64, Color(0.25, 0.45, 0.2), Color(0.35, 0.55, 0.28), 0.2, 88), 0.8, 3.0, 1.0)
	var stems: Array = []
	var arms: Array = []
	for t in cacti:
		var tt: Transform3D = t
		stems.append(tt * Transform3D(Basis(), Vector3(0, 2.2, 0)))
		arms.append(tt * Transform3D(Basis(), Vector3(0.75, 2.8, 0)))
		arms.append(tt * Transform3D(Basis(), Vector3(-0.75, 2.2, 0)))
	Kit.multimesh(self, stem, stems, cmat, true)
	Kit.multimesh(self, arm, arms, cmat, true)

# ------------------------------------------------------------------ nuages
func _clouds() -> void:
	var sh := ShaderMaterial.new()
	sh.shader = load("res://shaders/clouds.gdshader")
	sh.set_shader_parameter("noise_a", Kit.tex(Kit.noise_image(512, 0.012, 7)))
	var pm := PlaneMesh.new()
	pm.size = Vector2(SIZE * 3.0, SIZE * 3.0)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = sh
	mi.position = Vector3(0, 1100, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
