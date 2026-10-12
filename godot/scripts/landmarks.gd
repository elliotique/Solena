class_name Landmarks
extends RefCounted
## Grands lieux de l'île : ligne de chemin de fer Solena ↔ Porto Sol (deux gares, train en navette),
## aérogares dans lesquelles on entre à pied, et port de commerce géant (quais, conteneurs, grues, navires).

const RAIL := [Vector2(-620, -300), Vector2(-1050, -150), Vector2(-1550, 300), Vector2(-1850, 700), Vector2(-1900, 860)]

# ------------------------------------------------------------------ outils
static func _b(parent: Node3D, body: StaticBody3D, size: Vector3, pos: Vector3, mat: Material, collide := true, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	if collide and body != null:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		cs.position = pos
		cs.rotation.y = rot_y
		body.add_child(cs)
	return mi

static func _label(parent: Node3D, text: String, pos: Vector3, size: int, col: Color, rot_y := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.02
	l.modulate = col
	l.outline_size = 12
	l.position = pos
	l.rotation.y = rot_y
	parent.add_child(l)
	return l

static func _frame(isl: Island, origin: Vector2, fwd: Vector2, y: float) -> Node3D:
	# repère local : +Z = fwd ; renvoie un nœud placé et orienté
	var n := Node3D.new()
	isl.add_child(n)
	n.position = Vector3(origin.x, y, origin.y)
	n.rotation.y = atan2(fwd.x, fwd.y)
	return n

# ------------------------------------------------------------------ préparation (avant le relief)
static func plan_port(isl: Island) -> void:
	var ang := deg_to_rad(150.0)
	var dir := Vector2(cos(ang), sin(ang))
	var rc := 3000.0
	while rc < Island.HALF - 300.0 and isl.height_at(dir.x * rc, dir.y * rc) > Island.SEA + 0.5:
		rc += 20.0
	var center := dir * (rc - 120.0)
	var tang := Vector2(-dir.y, dir.x)
	isl.port = {"center": center, "dir": dir, "tang": tang, "coast": rc}
	isl._flatten_rect(center, 540.0, 170.0, rad_to_deg(atan2(tang.y, tang.x)), 1.5, 120.0)

static func extra_roads(isl: Island) -> void:
	var c: Vector2 = isl.port.center
	var d: Vector2 = isl.port.dir
	var rc: float = isl.port.coast
	isl.roads.append({"name": "Route du Port", "kind": "country", "w": 9.0, "pts": isl._poly([d * 3600.0, d * (3600.0 + (rc - 3600.0) * 0.45), c - d * 150.0])})
	isl.roads.append({"name": "Voie ferrée", "kind": "rail", "w": 4.0, "pts": isl._poly(RAIL, 4.0)})

static func build_all(isl: Island) -> void:
	_railway(isl)
	_port(isl)

# ------------------------------------------------------------------ chemin de fer
static func _railway(isl: Island) -> void:
	var pts: PackedVector3Array = PackedVector3Array()
	for r in isl.roads:
		if r.kind == "rail":
			pts = r.pts
	if pts.size() < 2:
		return
	var gravel := Kit.pbr("ballast", Kit.tint_image(128, Color(0.42, 0.4, 0.37), Color(0.6, 0.58, 0.54), 0.2, 301, 0.3, Color(0.3, 0.29, 0.27)), 1.0, 4.0, 1.5, true)
	var steel := Kit.color_mat(Color(0.55, 0.56, 0.6), 0.25, 0.9)
	isl._ribbon(pts, 2.4, 0.08, gravel)
	isl._ribbon(isl._offset(pts, 0.75), 0.07, 0.3, steel)
	isl._ribbon(isl._offset(pts, -0.75), 0.07, 0.3, steel)
	# traverses en bois
	var xf: Array = []
	var acc := 0.0
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var seg := Vector2(b.x - a.x, b.z - a.z).length()
		var t := (b - a).normalized()
		var yaw := atan2(t.x, t.z)
		var s := fmod(-acc, 0.8)
		if s < 0.0:
			s += 0.8
		while s < seg:
			xf.append(Transform3D(Basis(Vector3.UP, yaw), a.lerp(b, s / seg) + Vector3(0, 0.18, 0)))
			s += 0.8
		acc += seg
	var sl := BoxMesh.new()
	sl.size = Vector3(2.6, 0.18, 0.28)
	Kit.multimesh(isl, sl, xf, Kit.color_mat(Color(0.36, 0.26, 0.18), 0.9), false)
	_station(isl, pts, true, "GARE DE SOLENA")
	_station(isl, pts, false, "GARE DE PORTO SOL")
	var tr := TrainRunner.new()
	tr.pts = pts
	isl.add_child(tr)
	tr.build()
	isl.set_meta("train", tr)

static func _station(isl: Island, pts: PackedVector3Array, at_start: bool, name: String) -> void:
	var p := pts[0] if at_start else pts[pts.size() - 1]
	var q := pts[6] if at_start else pts[pts.size() - 7]
	var fwd := Vector2(q.x - p.x, q.z - p.z).normalized()
	var n := _frame(isl, Vector2(p.x, p.z) + fwd * 60.0, fwd, p.y)
	var body := StaticBody3D.new()
	n.add_child(body)
	var concrete := Kit.color_mat(Color(0.78, 0.77, 0.74), 0.85)
	var roof := Kit.color_mat(Color(0.2, 0.42, 0.55), 0.4, 0.4)
	var metal := Kit.color_mat(Color(0.25, 0.27, 0.3), 0.3, 0.8)
	for side in [-1, 1]:
		# quai de chaque côté de la voie, auvent sur poteaux
		_b(n, body, Vector3(6.0, 1.0, 140.0), Vector3(side * 5.2, 0.5, 0), concrete)
		_b(n, body, Vector3(0.4, 0.05, 140.0), Vector3(side * 2.35, 1.02, 0), Kit.color_mat(Color(1, 0.85, 0.2), 0.6), false)
		_b(n, null, Vector3(7.0, 0.3, 120.0), Vector3(side * 5.2, 5.4, 0), roof, false)
		for z in range(-55, 60, 15):
			_b(n, body, Vector3(0.3, 4.4, 0.3), Vector3(side * 6.8, 3.2, z), metal)
			_b(n, body, Vector3(1.6, 0.5, 0.5), Vector3(side * 6.2, 1.25, z + 6), Kit.color_mat(Color(0.55, 0.35, 0.2), 0.8))
		_label(n, name, Vector3(side * 4.0, 4.5, 0), 120, Color(1, 1, 1), PI / 2 if side < 0 else -PI / 2)
	# bâtiment voyageurs à côté du quai
	var fac := Kit.facade(1, Color(1, 0.96, 0.9))
	_b(n, body, Vector3(16, 9, 46), Vector3(18.0, 4.5, 0), fac)
	_b(n, null, Vector3(18, 0.6, 48), Vector3(18.0, 9.3, 0), roof, false)
	_label(n, name, Vector3(26.2, 7.6, 0), 140, Color(1, 0.9, 0.6), PI / 2)
	var clock := Label3D.new()
	clock.text = "🕒"
	n.add_child(clock)

# ------------------------------------------------------------------ aérogare (on peut y entrer à pied)
static func terminal(isl: Island, a: Dictionary, pos: Vector3, yaw: float) -> void:
	var n := Node3D.new()
	isl.add_child(n)
	n.position = pos
	n.rotation.y = yaw
	var body := StaticBody3D.new()
	n.add_child(body)
	var W := 360.0
	var D := 40.0
	var H := 16.0
	var fac := Kit.facade(2, Color(0.8, 0.9, 1.0))
	var floor_m := StandardMaterial3D.new()
	floor_m.albedo_color = Color(0.86, 0.85, 0.82)
	floor_m.roughness = 0.12
	floor_m.metallic = 0.1
	var roof := Kit.color_mat(Color(0.95, 0.95, 0.96), 0.4, 0.3)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.55, 0.75, 0.85, 0.28)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.03
	glass.metallic = 0.6
	var wood := Kit.color_mat(Color(0.5, 0.33, 0.2), 0.6)
	var dark := Kit.color_mat(Color(0.12, 0.13, 0.15), 0.4)
	# sol, toit, murs (porte de 16 m côté ville, baie vitrée côté pistes)
	_b(n, body, Vector3(W, 0.3, D), Vector3(0, -0.05, 0), floor_m)
	_b(n, body, Vector3(W + 20, 1.4, D + 12), Vector3(0, H + 0.7, 0), roof)
	for k in 10:
		_b(n, null, Vector3(W * 0.8 / 10.0, 0.15, 3.0), Vector3(-W * 0.4 + (k + 0.5) * W * 0.8 / 10.0, H - 0.1, 0), Kit.glow_mat(Color(1, 0.97, 0.9), 1.5), false)
	var seg := (W - 16.0) / 2.0
	for side in [-1, 1]:
		_b(n, body, Vector3(seg, H, 0.6), Vector3(side * (8.0 + seg / 2.0), H / 2.0, D / 2.0), fac)
		_b(n, body, Vector3(0.6, H, D), Vector3(side * W / 2.0, H / 2.0, 0), fac)
	_b(n, body, Vector3(16.0, H - 6.0, 0.6), Vector3(0, 6.0 + (H - 6.0) / 2.0, D / 2.0), fac)
	_b(n, body, Vector3(W, H, 0.4), Vector3(0, H / 2.0, -D / 2.0), glass)
	for x in range(-176, 180, 16):
		_b(n, null, Vector3(0.4, H, 0.6), Vector3(x, H / 2.0, -D / 2.0), dark, false)
	_label(n, "ENTRÉE · DÉPARTS", Vector3(0, 7.5, D / 2.0 + 0.5), 220, Color(1, 0.95, 0.85))
	_label(n, a.name, Vector3(0, H + 4.0, D / 2.0 + 2.0), 300, Color(1, 1, 1))
	# comptoirs d'enregistrement
	for k in 12:
		var x := -110.0 + k * 20.0
		_b(n, body, Vector3(8, 1.1, 1.4), Vector3(x, 0.55, 9.0), wood)
		_b(n, null, Vector3(8, 1.6, 0.2), Vector3(x, 3.2, 7.6), dark, false)
		_label(n, "ENREGISTREMENT %d" % (k + 1), Vector3(x, 3.2, 7.75), 70, Color(0.4, 0.9, 1.0))
	# tableau des départs
	_b(n, null, Vector3(30, 9, 0.4), Vector3(0, 9.5, 1.5), dark, false)
	var board := "DÉPARTS\nSO 212   PORTO SOL      14:20   À L'HEURE\nSO 418   PARIS CDG      15:05   EMBARQUEMENT\nSO 733   NEW YORK JFK   16:40   À L'HEURE\nSO 105   TOKYO HND      18:15   RETARDÉ\nSO 560   LONDRES LHR    19:30   À L'HEURE"
	var bl := _label(n, board, Vector3(0, 9.5, 1.75), 90, Color(1, 0.82, 0.3))
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	bl.font = null
	# rangées de sièges face aux pistes, portes d'embarquement
	var seats: Array = []
	for x in range(-160, 165, 4):
		for z in [-10.0, -13.0]:
			seats.append(Transform3D(Basis(), Vector3(x, 0.45, z)))
	var sm := BoxMesh.new()
	sm.size = Vector3(3.4, 0.9, 1.2)
	Kit.multimesh(n, sm, seats, Kit.color_mat(Color(0.15, 0.3, 0.6), 0.6), false)
	for g in 8:
		var gx := -140.0 + g * 40.0
		_label(n, "PORTE %s%d" % ["A" if g < 4 else "B", g % 4 + 1], Vector3(gx, 6.0, -D / 2.0 + 1.0), 120, Color(1, 0.85, 0.3), PI)
	# boutiques
	for s in [["DUTY FREE", -165.0], ["CAFÉ SOLENA", 165.0]]:
		_b(n, body, Vector3(12, 5, 10), Vector3(s[1], 2.5, 0), Kit.color_mat(Color(0.95, 0.9, 0.8), 0.5))
		_label(n, s[0], Vector3(s[1], 6.0, 5.2), 120, Color(1, 0.4, 0.6))
	# éclairage intérieur
	for k in 6:
		var l := OmniLight3D.new()
		l.position = Vector3(-150.0 + k * 60.0, H - 3.0, 0)
		l.omni_range = 45.0
		l.light_energy = 1.6
		l.light_color = Color(1, 0.96, 0.9)
		n.add_child(l)

# ------------------------------------------------------------------ port de commerce
static func _port(isl: Island) -> void:
	if isl.port.is_empty():
		return
	var c: Vector2 = isl.port.center
	var d: Vector2 = isl.port.dir
	var n := _frame(isl, c, d, 1.5)          # +Z = vers le large
	var body := StaticBody3D.new()
	n.add_child(body)
	var concrete := Kit.pbr("quai", Kit.tint_image(128, Color(0.62, 0.62, 0.6), Color(0.74, 0.74, 0.72), 0.1, 401, 0.1, Color(0.5, 0.5, 0.48)), 0.9, 2.0, 4.0, true)
	var water_y := Island.SEA - 1.5
	# terre-plein, mur de quai, 4 jetées
	_b(n, body, Vector3(1080, 1.0, 330), Vector3(0, -0.5, -20), concrete)
	_b(n, body, Vector3(1080, 14.0, 30), Vector3(0, -7.0, 130), concrete)
	var piers := [-390.0, -130.0, 130.0, 390.0]
	for px in piers:
		_b(n, body, Vector3(60, 14.0, 380), Vector3(px, -7.0, 330), concrete)
		_b(n, null, Vector3(1.0, 0.2, 380), Vector3(px - 29.5, 0.1, 330), Kit.color_mat(Color(1, 0.8, 0.1), 0.5), false)
	# conteneurs empilés (couleurs variées)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var xf: Array = []
	var cols: Array = []
	var palette := [Color(0.75, 0.15, 0.12), Color(0.1, 0.3, 0.65), Color(0.15, 0.5, 0.25), Color(0.9, 0.5, 0.1), Color(0.55, 0.57, 0.6), Color(0.85, 0.8, 0.2), Color(0.95, 0.95, 0.95)]
	for bx in range(-480, 481, 160):
		for row in 6:
			for col in 8:
				var h := rng.randi_range(1, 4)
				for k in h:
					xf.append(Transform3D(Basis(), Vector3(bx - 56 + col * 16.0, 1.3 + k * 2.6, -150 + row * 4.0 + (40 if bx > 0 else 0))))
					cols.append(palette[rng.randi() % palette.size()])
	var cm := BoxMesh.new()
	cm.size = Vector3(12.2, 2.55, 2.45)
	var cmat := StandardMaterial3D.new()
	cmat.vertex_color_use_as_albedo = true
	cmat.roughness = 0.6
	cmat.metallic = 0.3
	Kit.multimesh(n, cm, xf, cmat, true, cols)
	# grues portiques sur les jetées
	var red := Kit.color_mat(Color(0.8, 0.15, 0.12), 0.4, 0.5)
	var white := Kit.color_mat(Color(0.94, 0.94, 0.94), 0.4, 0.4)
	for px in piers:
		for z in [220.0, 400.0]:
			var side := 1.0 if px < 0 else -1.0
			var gx: float = px + side * 18.0
			for lx in [-9.0, 9.0]:
				for lz in [-8.0, 8.0]:
					_b(n, body, Vector3(1.6, 42, 1.6), Vector3(gx + lx, 21, z + lz), red)
			_b(n, null, Vector3(22, 3, 18), Vector3(gx, 43, z), white, false)
			_b(n, null, Vector3(70, 2.2, 3.5), Vector3(gx - side * 40.0, 45, z), red, false)
			_b(n, null, Vector3(6, 4, 4), Vector3(gx - side * 55.0, 41, z), white, false)
	# navires à quai : porte-conteneurs et paquebot
	var gaps := [-260.0, 0.0, 260.0]
	for gi in gaps.size():
		var gx2: float = gaps[gi]
		if gi == 0:
			_cruise_ship(n, body, Vector3(gx2, water_y, 330))
		else:
			_container_ship(n, body, Vector3(gx2, water_y, 320 + gi * 20.0), rng, palette)
	# phare au bout de la jetée extérieure
	var lh := CylinderMesh.new()
	lh.top_radius = 2.6
	lh.bottom_radius = 3.6
	lh.height = 30
	var mi := MeshInstance3D.new()
	mi.mesh = lh
	mi.material_override = white
	mi.position = Vector3(390, 15, 530)
	n.add_child(mi)
	var top := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 2.6
	sp.height = 5.2
	top.mesh = sp
	top.material_override = Kit.glow_mat(Color(1, 0.9, 0.6), 6.0)
	top.position = Vector3(390, 32, 530)
	n.add_child(top)
	# entrepôts et portail d'entrée
	for k in 6:
		var wx := -450.0 + k * 180.0
		var wh := KenneyLib.place(n, body, "res://assets/city-kit-industrial/building-%s.glb" % ["a", "b", "c", "e", "f", "g"][k], n.to_global(Vector3(wx, 0, -175)), n.global_transform.basis.z, 70.0, 40.0) if KenneyLib.has_packs() else null
		if wh == null:
			_b(n, body, Vector3(70, 14, 40), Vector3(wx, 7, -175), Kit.facade(0, Color(0.85, 0.85, 0.82)))
	_b(n, body, Vector3(2, 10, 2), Vector3(-14, 5, -192), red)
	_b(n, body, Vector3(2, 10, 2), Vector3(14, 5, -192), red)
	_b(n, null, Vector3(32, 3, 1.5), Vector3(0, 10.5, -192), red, false)
	_label(n, "PORT DE SOLENA", Vector3(0, 10.5, -192.9), 260, Color(1, 1, 1), PI)

static func _container_ship(n: Node3D, body: StaticBody3D, p: Vector3, rng: RandomNumberGenerator, palette: Array) -> void:
	var hull := Kit.color_mat(Color(0.1, 0.16, 0.3), 0.5, 0.3)
	var bottom := Kit.color_mat(Color(0.6, 0.12, 0.1), 0.6)
	_b(n, body, Vector3(32, 10, 230), p + Vector3(0, 5, 0), hull)
	_b(n, null, Vector3(32.2, 3, 230.2), p + Vector3(0, 0.5, 0), bottom, false)
	_b(n, null, Vector3(22, 3, 20), p + Vector3(0, 11.5, 118), hull, false)
	var sup := Kit.facade(0, Color(0.95, 0.95, 0.95))
	_b(n, body, Vector3(28, 20, 18), p + Vector3(0, 20, -100), sup)
	_b(n, null, Vector3(3, 8, 3), p + Vector3(0, 34, -104), Kit.color_mat(Color(0.2, 0.2, 0.22), 0.5), false)
	var xf: Array = []
	var cols: Array = []
	for z in range(-80, 105, 13):
		for x in range(-12, 13, 3):
			for k in rng.randi_range(2, 5):
				xf.append(Transform3D(Basis(Vector3.UP, PI / 2), p + Vector3(x, 11.3 + k * 2.6, z)))
				cols.append(palette[rng.randi() % palette.size()])
	var cm := BoxMesh.new()
	cm.size = Vector3(12.2, 2.55, 2.45)
	var cmat := StandardMaterial3D.new()
	cmat.vertex_color_use_as_albedo = true
	cmat.roughness = 0.6
	Kit.multimesh(n, cm, xf, cmat, true, cols)

static func _cruise_ship(n: Node3D, body: StaticBody3D, p: Vector3) -> void:
	var white := Kit.color_mat(Color(0.97, 0.97, 0.97), 0.3, 0.2)
	var deck := Kit.facade(2, Color(0.92, 0.96, 1.0))
	_b(n, body, Vector3(36, 14, 250), p + Vector3(0, 7, 0), white)
	_b(n, null, Vector3(36.2, 3, 250.2), p + Vector3(0, 0.5, 0), Kit.color_mat(Color(0.1, 0.18, 0.4), 0.5), false)
	for k in 5:
		_b(n, body, Vector3(34 - k * 2.0, 3.6, 210 - k * 18.0), p + Vector3(0, 15.8 + k * 3.6, -8 - k * 4.0), deck)
	_b(n, null, Vector3(9, 12, 14), p + Vector3(0, 40, -60), Kit.color_mat(Color(0.85, 0.15, 0.15), 0.5), false)
	_b(n, null, Vector3(20, 0.5, 30), p + Vector3(0, 34.3, 40), Kit.color_mat(Color(0.2, 0.6, 0.8), 0.1), false)

# ------------------------------------------------------------------ train en navette entre les deux gares
class TrainRunner extends Node3D:
	var pts: PackedVector3Array
	var dist: PackedFloat32Array
	var total := 0.0
	var s := 70.0
	var dir := 1.0
	var v := 0.0
	var wait := 20.0
	var cars: Array = []
	const CAR_LEN := 22.0

	func build() -> void:
		dist.resize(pts.size())
		dist[0] = 0.0
		for i in range(1, pts.size()):
			dist[i] = dist[i - 1] + pts[i].distance_to(pts[i - 1])
		total = dist[dist.size() - 1]
		var names := ["train-electric-city-a", "train-electric-city-b", "train-electric-city-b", "train-electric-city-c"]
		for k in names.size():
			var holder := AnimatableBody3D.new()
			add_child(holder)
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = Vector3(3.2, 4.2, CAR_LEN - 1.0)
			cs.shape = sh
			cs.position = Vector3(0, 2.4, 0)
			holder.add_child(cs)
			var path := "res://assets/train-kit/%s.glb" % names[k]
			var ok := false
			if ResourceLoader.exists(path):
				var ps: PackedScene = load(path)
				var inst: Node3D = ps.instantiate()
				var box := AABB()
				var first := true
				for m in inst.find_children("*", "MeshInstance3D", true, false):
					var t := Transform3D()
					var cur: Node = m
					while cur != inst and cur != null:
						if cur is Node3D:
							t = (cur as Node3D).transform * t
						cur = cur.get_parent()
					var b := t * (m as MeshInstance3D).get_aabb()
					box = b if first else box.merge(b)
					first = false
				var long_axis_x := box.size.x > box.size.z
				var len := box.size.x if long_axis_x else box.size.z
				var sc := CAR_LEN / maxf(len, 0.01)
				inst.scale = Vector3(sc, sc, sc)
				inst.rotation.y = PI / 2 if long_axis_x else 0.0
				var ctr := box.position + box.size * 0.5
				inst.position = (Basis(Vector3.UP, inst.rotation.y) * Vector3(-ctr.x, -box.position.y, -ctr.z)) * sc + Vector3(0, 0.3, 0)
				holder.add_child(inst)
				ok = true
			if not ok:
				var mi := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(3.2, 4.0, CAR_LEN - 1.0)
				mi.mesh = bm
				mi.material_override = Kit.color_mat(Color(0.9, 0.9, 0.92) if k % 2 else Color(0.8, 0.15, 0.15), 0.4, 0.3)
				mi.position = Vector3(0, 2.4, 0)
				holder.add_child(mi)
			cars.append(holder)
		_place()

	func _sample(at: float) -> Array:
		at = clampf(at, 0.0, total)
		var i := 1
		while i < dist.size() - 1 and dist[i] < at:
			i += 1
		var t := (at - dist[i - 1]) / maxf(dist[i] - dist[i - 1], 0.01)
		var p := pts[i - 1].lerp(pts[i], t)
		var tan := (pts[i] - pts[i - 1]).normalized()
		return [p, tan]

	func _place() -> void:
		for k in cars.size():
			var at := s - dir * k * CAR_LEN
			var sm := _sample(at)
			var p: Vector3 = sm[0]
			var tan: Vector3 = sm[1] * dir
			(cars[k] as Node3D).global_transform = Transform3D(Basis(Vector3.UP, atan2(tan.x, tan.z)), p + Vector3(0, 0.25, 0))

	func _physics_process(delta: float) -> void:
		if wait > 0.0:
			wait -= delta
			return
		var remaining := (total - 70.0 - s) if dir > 0 else (s - 70.0)
		var target := 28.0 if remaining > 400.0 else maxf(2.0, remaining * 0.07)
		v = move_toward(v, target, delta * 1.2)
		s += dir * v * delta
		if remaining <= 0.5:
			v = 0.0
			wait = 25.0
			dir = -dir
			s = clampf(s, 70.0, total - 70.0)
			# le train repart dans l'autre sens : la tête devient la queue
			s = s - dir * (cars.size() - 1) * CAR_LEN * -1.0
		_place()
