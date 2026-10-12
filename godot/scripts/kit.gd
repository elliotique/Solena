class_name Kit
extends RefCounted
## Boîte à outils : textures générées (bruit, briques, fenêtres, pavés, feuillage), matériaux PBR et maillages lissés.

static var _cache := {}

# ------------------------------------------------------------------ textures
static func noise_image(size: int, freq: float, seed_v: int, octaves := 4) -> Image:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.frequency = freq
	n.fractal_octaves = octaves
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	return n.get_seamless_image(size, size)

## Image couleur : mélange de deux teintes selon un bruit, + petites taches
static func tint_image(size: int, a: Color, b: Color, freq: float, seed_v: int, speck := 0.0, speck_col := Color.WHITE) -> Image:
	var src := noise_image(size, freq, seed_v)
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for y in size:
		for x in size:
			var t := src.get_pixel(x, y).r
			var c := a.lerp(b, t)
			if speck > 0.0 and rng.randf() < speck:
				c = c.lerp(speck_col, 0.5)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return img

static func normal_from(img: Image, strength := 2.0) -> ImageTexture:
	var h := img.duplicate() as Image
	h.clear_mipmaps()
	h.convert(Image.FORMAT_RGB8)
	h.bump_map_to_normal_map(strength)
	h.generate_mipmaps()
	return ImageTexture.create_from_image(h)

static func tex(img: Image) -> ImageTexture:
	if not img.has_mipmaps():
		img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# ------------------------------------------------------------------ matériaux
static func pbr(key: String, albedo: Image, rough := 0.9, normal_strength := 2.0, scale := 1.0, world_tri := false, metal := 0.0) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(albedo)
	m.normal_enabled = true
	m.normal_texture = normal_from(albedo, normal_strength)
	m.roughness = rough
	m.metallic = metal
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if world_tri:
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE / scale
	else:
		m.uv1_scale = Vector3(scale, scale, scale)
	_cache[key] = m
	return m

static func asphalt() -> StandardMaterial3D:
	if _cache.has("asphalt"):
		return _cache["asphalt"]
	var img := tint_image(512, Color(0.1, 0.105, 0.115), Color(0.2, 0.2, 0.21), 0.035, 11, 0.08, Color(0.35, 0.35, 0.36))
	var m := pbr("asphalt", img, 0.93, 1.2, 8.0, true)
	m.metallic_specular = 0.3
	return m

static func paving() -> StandardMaterial3D:
	if _cache.has("paving"):
		return _cache["paving"]
	var s := 256
	var base := noise_image(s, 0.05, 21)
	var img := Image.create(s, s, true, Image.FORMAT_RGB8)
	for y in s:
		for x in s:
			var joint := (x % 64) < 3 or (y % 64) < 3
			var v := 0.62 + base.get_pixel(x, y).r * 0.12
			img.set_pixel(x, y, Color(v * 0.5, v * 0.5, v * 0.48) if joint else Color(v, v * 0.98, v * 0.94))
	return pbr("paving", img, 0.85, 3.0, 2.4, true)

static func grass_ground() -> StandardMaterial3D:
	if _cache.has("grass_ground"):
		return _cache["grass_ground"]
	var img := tint_image(512, Color(0.2, 0.36, 0.13), Color(0.4, 0.52, 0.2), 0.02, 31, 0.15, Color(0.55, 0.6, 0.3))
	return pbr("grass_ground", img, 0.95, 2.5, 6.0, true)

static func sand() -> StandardMaterial3D:
	return pbr("sand", tint_image(256, Color(0.82, 0.74, 0.54), Color(0.93, 0.86, 0.66), 0.05, 41, 0.1, Color(0.7, 0.62, 0.45)), 0.95, 1.5, 4.0, true)

static func bark() -> StandardMaterial3D:
	if _cache.has("bark"):
		return _cache["bark"]
	var s := 128
	var img := Image.create(s, s, true, Image.FORMAT_RGB8)
	var n := noise_image(s, 0.08, 51)
	for y in s:
		for x in s:
			var v := 0.25 + n.get_pixel(x, (y * 4) % s).r * 0.25 + (0.08 if (x % 16) < 2 else 0.0)
			img.set_pixel(x, y, Color(v * 1.1, v * 0.85, v * 0.62))
	return pbr("bark", img, 0.95, 4.0, 1.0)

static func foliage(tint: Color, key: String) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key]
	var img := tint_image(256, tint.darkened(0.45), tint.lightened(0.15), 0.12, hash(key) % 1000, 0.25, tint.lightened(0.35))
	var m := pbr(key, img, 0.85, 5.0, 2.0)
	m.backlight_enabled = true
	m.backlight = Color(0.35, 0.5, 0.15)
	return m

## Palme : texture avec transparence (folioles en épi)
static func frond_material() -> StandardMaterial3D:
	if _cache.has("frond"):
		return _cache["frond"]
	var w := 128
	var h := 512
	var img := Image.create(w, h, true, Image.FORMAT_RGBA8)
	for y in h:
		var v := float(y) / h
		var halfw := 0.48 * sin(clampf(v, 0.02, 1.0) * PI * 0.95 + 0.12)
		for x in w:
			var u := absf(float(x) / w - 0.5)
			var a := 0.0
			var col := Color(0.2, 0.45, 0.16)
			if u < 0.018:
				a = 1.0
				col = Color(0.42, 0.5, 0.2)
			elif u < halfw:
				var stripe := fmod(v * 46.0 + u * 22.0, 1.0)
				if stripe < 0.62:
					a = 1.0
					col = Color(0.16, 0.42, 0.14).lerp(Color(0.36, 0.6, 0.22), stripe / 0.62)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.75
	m.backlight_enabled = true
	m.backlight = Color(0.3, 0.45, 0.12)
	_cache["frond"] = m
	return m

## Touffes d'herbe (cartes croisées)
static func grass_card_material() -> StandardMaterial3D:
	if _cache.has("grass_card"):
		return _cache["grass_card"]
	var s := 128
	var img := Image.create(s, s, true, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	for b in 34:
		var x0 := rng.randf_range(6, s - 6)
		var hgt := rng.randf_range(0.45, 1.0) * s
		var lean := rng.randf_range(-18, 18)
		var col := Color(0.25, 0.45, 0.14).lerp(Color(0.55, 0.65, 0.25), rng.randf())
		for yy in int(hgt):
			var t := float(yy) / hgt
			var xx := int(x0 + lean * t * t)
			var wdt := int(lerpf(3.0, 0.0, t)) + 1
			for dx in wdt:
				var px := clampi(xx + dx, 0, s - 1)
				img.set_pixel(px, s - 1 - yy, col.darkened(0.3 * (1.0 - t)))
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	m.backlight_enabled = true
	m.backlight = Color(0.3, 0.4, 0.12)
	_cache["grass_card"] = m
	return m

## Façade : fenêtres en retrait (carte de normales), fenêtres allumées la nuit (émission)
static func facade(style: int, tint: Color) -> StandardMaterial3D:
	var key := "facade_%d_%s" % [style, tint.to_html()]
	if _cache.has(key):
		return _cache[key]
	var tex_key := "facade_tex_%d" % style
	var imgs: Array
	if _cache.has(tex_key):
		imgs = _cache[tex_key]
	else:
		imgs = _facade_images(style)
		_cache[tex_key] = imgs
	var m := StandardMaterial3D.new()
	m.albedo_texture = imgs[0]
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = imgs[1]
	m.emission_enabled = true
	m.emission_texture = imgs[2]
	m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	m.emission = Color(1, 1, 1)
	m.emission_energy_multiplier = 0.0
	m.roughness_texture = imgs[3]
	m.roughness = 1.0
	m.metallic = 0.25 if style == 2 else 0.0
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / 12.8     # une tuile = 4 fenêtres x 4 étages de 3,2 m
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[key] = m
	return m

static func _facade_images(style: int) -> Array:
	# style 0 : enduit + fenêtres ; 1 : briques ; 2 : mur-rideau vitré
	var s := 256
	var cell := 64
	var alb := Image.create(s, s, true, Image.FORMAT_RGB8)
	var hgt := Image.create(s, s, false, Image.FORMAT_RGB8)
	var emi := Image.create(s, s, true, Image.FORMAT_RGB8)
	var rou := Image.create(s, s, true, Image.FORMAT_RGB8)
	var n := noise_image(s, 0.03, 71 + style)
	var rng := RandomNumberGenerator.new()
	rng.seed = 700 + style
	var lit := []
	for k in 16:
		lit.append(rng.randf() < 0.45)
	var warm := []
	for k in 16:
		warm.append(Color(1.0, 0.8, 0.52) if rng.randf() < 0.7 else Color(0.78, 0.86, 1.0))
	for y in s:
		for x in s:
			var cx := x % cell
			var cy := y % cell
			var idx := int(x / cell) + int(y / cell) * 4
			var nv := n.get_pixel(x, y).r
			var wall := Color(0.92, 0.9, 0.86) * (0.9 + nv * 0.12)
			var h := 0.6
			var r := 0.9
			var e := Color(0, 0, 0)
			if style == 1:
				var row := int(y / 5)
				var bx := (x + (6 if row % 2 == 1 else 0)) % 13
				var mortar := (y % 5) < 1 or bx < 1
				wall = (Color(0.62, 0.62, 0.6) if mortar else Color(0.72, 0.42, 0.33) * (0.85 + nv * 0.3))
				h = 0.45 if mortar else 0.6
			var win := false
			var frame := false
			if style == 2:
				win = cx > 1 and cy > 3
				frame = not win
			else:
				win = cx > 13 and cx < 51 and cy > 15 and cy < 54
				frame = cx > 10 and cx < 54 and cy > 12 and cy < 57 and not win
			if win:
				var refl := 0.25 + 0.35 * (1.0 - float(cy) / cell)
				wall = Color(0.18, 0.24, 0.3) + Color(refl, refl, refl) * 0.35
				h = 0.2
				r = 0.08
				if lit[idx]:
					e = warm[idx] * (0.85 + 0.15 * nv)
				if style != 2 and cx == 32:
					wall = Color(0.85, 0.85, 0.82)
					h = 0.5
			elif frame:
				wall = Color(0.95, 0.95, 0.93) if style != 2 else Color(0.55, 0.6, 0.66)
				h = 0.75
				r = 0.5
			alb.set_pixel(x, y, wall)
			hgt.set_pixel(x, y, Color(h, h, h))
			emi.set_pixel(x, y, e)
			rou.set_pixel(x, y, Color(r, r, r))
	alb.generate_mipmaps()
	emi.generate_mipmaps()
	rou.generate_mipmaps()
	hgt.bump_map_to_normal_map(6.0)
	hgt.generate_mipmaps()
	return [ImageTexture.create_from_image(alb), ImageTexture.create_from_image(hgt), ImageTexture.create_from_image(emi), ImageTexture.create_from_image(rou)]

static func color_mat(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var key := "col_%s_%.2f_%.2f" % [c.to_html(), rough, metal]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	_cache[key] = m
	return m

static func glow_mat(c: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m

# ------------------------------------------------------------------ maillages
## Extrusion d'un profil 2D (x = de l'arrière vers l'avant, y = hauteur) sur une largeur (axe X),
## avec arêtes arrondies. L'avant du maillage est vers +Z (convention du VehicleBody3D).
static func extrude_rounded(profile: PackedVector2Array, width: float, bevel := 0.08, steps := 3, ref_len := -1.0) -> ArrayMesh:
	var n := profile.size()
	var length := 0.0
	var area := 0.0
	for i in n:
		length = maxf(length, profile[i].x)
		var q := profile[(i + 1) % n]
		area += profile[i].x * q.y - q.x * profile[i].y
	var ccw := area > 0.0
	if ref_len > 0.0:
		length = ref_len
	# normales 2D sortantes (moyennées) à chaque sommet
	var outs := PackedVector2Array()
	for i in n:
		var t := (profile[(i + 1) % n] - profile[(i - 1 + n) % n]).normalized()
		outs.append(Vector2(t.y, -t.x) if ccw else Vector2(-t.y, t.x))
	var angles: Array = []
	for k in range(steps, -1, -1):
		angles.append([-1.0, float(k) / steps * PI / 2.0])
	for k in range(0, steps + 1):
		angles.append([1.0, float(k) / steps * PI / 2.0])
	var rings: Array = []
	for sa in angles:
		var sgn: float = sa[0]
		var a: float = sa[1]
		var xw: float = sgn * (width / 2.0 - bevel + bevel * sin(a))
		var shrink: float = bevel * (1.0 - cos(a))
		var pts := PackedVector3Array()
		var nrm := PackedVector3Array()
		for i in n:
			var q := profile[i] - outs[i] * shrink
			pts.append(Vector3(xw, q.y, q.x - length / 2.0))
			nrm.append(Vector3(sgn * sin(a), outs[i].y * cos(a), outs[i].x * cos(a)).normalized())
		rings.append([pts, nrm])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rings.size() - 1:
		var A: PackedVector3Array = rings[r][0]
		var B: PackedVector3Array = rings[r + 1][0]
		var NA: PackedVector3Array = rings[r][1]
		var NB: PackedVector3Array = rings[r + 1][1]
		for i in n:
			var j := (i + 1) % n
			var quad := [[A[i], NA[i]], [B[i], NB[i]], [B[j], NB[j]], [A[i], NA[i]], [B[j], NB[j]], [A[j], NA[j]]]
			for v in quad:
				st.set_normal(v[1])
				st.add_vertex(v[0])
	# bouchons latéraux
	for side in [0, rings.size() - 1]:
		var R: PackedVector3Array = rings[side][0]
		var flat := PackedVector2Array()
		for p in R:
			flat.append(Vector2(p.z, p.y))
		var tris := Geometry2D.triangulate_polygon(flat)
		var sx := -1.0 if side == 0 else 1.0
		for k in range(0, tris.size(), 3):
			for id in [tris[k], tris[k + 1], tris[k + 2]]:
				st.set_normal(Vector3(sx, 0, 0))
				st.add_vertex(R[id])
	return st.commit()

static func spline(pts: Array, steps := 6) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pts.size() - 1:
		var p0: Vector2 = Vector2(pts[maxi(i - 1, 0)][0], pts[maxi(i - 1, 0)][1])
		var p1 := Vector2(pts[i][0], pts[i][1])
		var p2 := Vector2(pts[i + 1][0], pts[i + 1][1])
		var p3: Vector2 = Vector2(pts[mini(i + 2, pts.size() - 1)][0], pts[mini(i + 2, pts.size() - 1)][1])
		for s in steps:
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(Vector2(pts[pts.size() - 1][0], pts[pts.size() - 1][1]))
	return out

## Couronne d'arbre : sphère déformée par du bruit (organique, lisse)
static func crown_mesh(seed_v: int, lumps := 0.35) -> ArrayMesh:
	var key := "crown_%d" % seed_v
	if _cache.has(key):
		return _cache[key]
	var sph := SphereMesh.new()
	sph.radial_segments = 20
	sph.rings = 12
	var arr := sph.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var noise := FastNoiseLite.new()
	noise.seed = seed_v
	noise.frequency = 1.6
	for i in verts.size():
		var v := verts[i]
		var d := 1.0 + noise.get_noise_3dv(v * 1.0) * lumps
		verts[i] = v * d * Vector3(1, 0.85, 1)
	arr[Mesh.ARRAY_VERTEX] = verts
	var st := SurfaceTool.new()
	st.create_from_arrays(arr)
	st.generate_normals()
	var m := st.commit()
	_cache[key] = m
	return m

## Palmes : 9 feuilles courbées
static func fronds_mesh() -> ArrayMesh:
	if _cache.has("fronds"):
		return _cache["fronds"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 6
	for k in 9:
		var yaw := k * TAU / 9.0 + (0.2 if k % 2 else 0.0)
		var tilt := 0.35 + (k % 3) * 0.12
		var basis := Basis(Vector3.UP, yaw)
		var length := 4.4
		for s in segs:
			var t0 := float(s) / segs
			var t1 := float(s + 1) / segs
			var pts := []
			for t in [t0, t1]:
				var dist: float = t * length
				var y: float = sin(tilt) * dist - pow(t, 2.0) * 1.9
				pts.append(Vector3(0, y, dist))
			var w := 0.7
			var quad := [Vector3(-w, 0, 0) + pts[0], Vector3(w, 0, 0) + pts[0], Vector3(w, 0, 0) + pts[1], Vector3(-w, 0, 0) + pts[1]]
			var uvs := [Vector2(0, 1.0 - t0), Vector2(1, 1.0 - t0), Vector2(1, 1.0 - t1), Vector2(0, 1.0 - t1)]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_normal(basis * Vector3(0, 1, 0))
				st.set_uv(uvs[idx])
				st.add_vertex(basis * (quad[idx] as Vector3))
	var m := st.commit()
	_cache["fronds"] = m
	return m

static func grass_card_mesh() -> ArrayMesh:
	if _cache.has("grass_mesh"):
		return _cache["grass_mesh"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for a in [0.0, PI / 3.0, 2.0 * PI / 3.0]:
		var b := Basis(Vector3.UP, a)
		var q := [Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(0.5, 1, 0), Vector3(-0.5, 1, 0)]
		var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(uv[idx])
			st.add_vertex(b * (q[idx] as Vector3))
	var m := st.commit()
	_cache["grass_mesh"] = m
	return m

static func multimesh(parent: Node, mesh: Mesh, xforms: Array, material: Material, shadows := true, colors := []) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors.size() > 0
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if colors.size() > 0:
			mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return mmi
