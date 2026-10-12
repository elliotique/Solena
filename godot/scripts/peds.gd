class_name Peds
extends Node3D
## Piétons : marchent sur les trottoirs (bras et jambes animés), sont projetés si on les percute,
## se relèvent et s'enfuient.

const COUNT := 60
const SKIN := [Color(0.95, 0.8, 0.66), Color(0.85, 0.64, 0.48), Color(0.66, 0.45, 0.3), Color(0.42, 0.28, 0.2)]
const SHIRT := [Color(1, 0.3, 0.6), Color(0.25, 0.85, 0.8), Color(1, 0.82, 0.35), Color(0.95, 0.95, 0.95), Color(0.2, 0.45, 0.75),
	Color(0.85, 0.25, 0.2), Color(0.25, 0.6, 0.35), Color(0.55, 0.35, 0.85), Color(0.15, 0.15, 0.17)]
const PANTS := [Color(0.16, 0.22, 0.36), Color(0.1, 0.1, 0.11), Color(0.72, 0.62, 0.45), Color(0.3, 0.32, 0.35), Color(0.9, 0.88, 0.82)]

var world: World
var player: PlayerCar
var rng := RandomNumberGenerator.new()
var peds: Array = []
var _meshes := {}

func setup(w: World, p: PlayerCar) -> void:
	world = w
	player = p
	rng.seed = 99 + int(w.global_position.x)
	_meshes["torso"] = _capsule(0.2, 0.62)
	_meshes["head"] = _sphere(0.13)
	_meshes["hair"] = _sphere(0.14)
	_meshes["limb"] = _capsule(0.075, 0.8)
	_meshes["arm"] = _capsule(0.06, 0.62)
	for k in COUNT:
		var pd := _make()
		peds.append(pd)
		_place(pd, true)

func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 12
	c.rings = 4
	return c

func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 14
	s.rings = 8
	return s

func _part(parent: Node3D, mesh: Mesh, col: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Kit.color_mat(col, 0.8)
	mi.position = pos
	parent.add_child(mi)
	return mi

func _make() -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var fig := Node3D.new()
	root.add_child(fig)
	var shirt: Color = SHIRT[rng.randi() % SHIRT.size()]
	var pants: Color = PANTS[rng.randi() % PANTS.size()]
	var skin: Color = SKIN[rng.randi() % SKIN.size()]
	var scale := rng.randf_range(0.9, 1.08)
	fig.scale = Vector3(scale, scale, scale)
	_part(fig, _meshes.torso, shirt, Vector3(0, 1.28, 0))
	_part(fig, _meshes.head, skin, Vector3(0, 1.72, 0))
	_part(fig, _meshes.hair, Color(0.15, 0.1, 0.07) if rng.randf() < 0.7 else Color(0.8, 0.65, 0.35), Vector3(0, 1.77, -0.02)).scale = Vector3(1, 0.7, 1)
	var legs := []
	for sx in [-0.1, 0.1]:
		var piv := Node3D.new()
		piv.position = Vector3(sx, 0.95, 0)
		fig.add_child(piv)
		_part(piv, _meshes.limb, pants, Vector3(0, -0.45, 0))
		legs.append(piv)
	var arms := []
	for sx in [-0.27, 0.27]:
		var piv := Node3D.new()
		piv.position = Vector3(sx, 1.52, 0)
		fig.add_child(piv)
		_part(piv, _meshes.arm, shirt, Vector3(0, -0.28, 0))
		_part(piv, _meshes.head, skin, Vector3(0, -0.6, 0)).scale = Vector3(0.45, 0.45, 0.45)
		arms.append(piv)
	var kc := CharacterKit.make(fig, rng.randi() % 2)
	var ap: AnimationPlayer = null
	if kc.size() > 0:
		for ch in fig.get_children():
			if ch != kc[0]:
				(ch as Node3D).visible = false
		ap = kc[1]
	return {"root": root, "fig": fig, "legs": legs, "arms": arms, "seg": 0, "t": 0.0, "dir": 1.0, "speed": 1.3,
		"phase": rng.randf() * TAU, "state": "walk", "timer": 0.0, "vel": Vector3.ZERO, "anim": ap}

func _place(pd: Dictionary, initial := false) -> void:
	var pp := player.global_position
	for attempt in 40:
		var si := rng.randi() % world.sidewalks.size()
		var seg: Array = world.sidewalks[si]
		var t := rng.randf()
		var p: Vector3 = (seg[0] as Vector3).lerp(seg[1], t)
		var d := p.distance_to(pp)
		if d < (8.0 if initial else 40.0) or d > 150.0:
			continue
		pd.seg = si
		pd.t = t
		pd.dir = 1.0 if rng.randf() < 0.5 else -1.0
		pd.speed = rng.randf_range(1.1, 1.6)
		pd.state = "walk"
		pd.fig.rotation = Vector3.ZERO
		pd.fig.position = Vector3.ZERO
		pd.root.global_position = p
		pd.root.visible = true
		return
	pd.root.visible = false

var dormant := false

func _physics_process(delta: float) -> void:
	# ville lointaine : piétons cachés, aucun calcul
	var far := (player.global_position - world.global_position).length() > 1100.0
	if far:
		if not dormant:
			dormant = true
			for pd in peds:
				pd.root.visible = false
		return
	dormant = false
	var pp := player.global_position
	var pv := player.linear_velocity
	var pspeed := pv.length()
	var pfwd := player.global_transform.basis.z
	for pd in peds:
		var root: Node3D = pd.root
		if not root.visible or root.global_position.distance_to(pp) > 170.0:
			_place(pd)
			continue
		match pd.state:
			"walk", "flee":
				var seg: Array = world.sidewalks[pd.seg]
				var a: Vector3 = seg[0]
				var b: Vector3 = seg[1]
				var seg_len := a.distance_to(b)
				var v: float = pd.speed * (3.0 if pd.state == "flee" else 1.0)
				pd.t += pd.dir * v * delta / maxf(seg_len, 1.0)
				if pd.t > 1.0 or pd.t < 0.0:
					pd.t = clampf(pd.t, 0.0, 1.0)
					pd.dir = -pd.dir
				var p := a.lerp(b, pd.t)
				var heading: Vector3 = (b - a).normalized() * float(pd.dir)
				root.global_position = p
				root.rotation.y = atan2(heading.x, heading.z)
				pd.phase += delta * v * 4.2
				var sw := sin(pd.phase) * 0.55
				pd.legs[0].rotation.x = sw
				pd.legs[1].rotation.x = -sw
				pd.arms[0].rotation.x = -sw * 0.8
				pd.arms[1].rotation.x = sw * 0.8
				var pa: AnimationPlayer = pd.anim
				if pa != null:
					if pa.current_animation != "kit/run" and pa.has_animation("kit/run"):
						pa.play("kit/run")
					pa.speed_scale = 0.55 if pd.state == "walk" else 1.3
				if pd.state == "flee":
					pd.timer -= delta
					if pd.timer <= 0.0:
						pd.state = "walk"
				# percuté par la voiture du joueur
				var rel := p - pp
				if pspeed > 2.5 and absf(rel.dot(pfwd)) < 2.7 and absf(rel.dot(player.global_transform.basis.x)) < 1.3 and absf(rel.y) < 2.0:
					pd.state = "down"
					pd.timer = 3.5
					pd.vel = pv * 0.9 + Vector3(0, 2.5 + pspeed * 0.2, 0)
				# la voiture fonce vers lui : il s'écarte en courant
				elif pd.state == "walk" and pspeed > 8.0 and rel.length() < 14.0 and rel.dot(pv) > 0.0:
					pd.state = "flee"
					pd.timer = 3.0
			"down":
				pd.vel.y -= 9.81 * delta
				var np: Vector3 = root.global_position + pd.vel * delta
				if np.y < 0.15:
					np.y = 0.15
					pd.vel *= 0.3
					pd.vel.y = 0.0
				root.global_position = np
				pd.fig.rotation.x = move_toward(pd.fig.rotation.x, -PI / 2.0, delta * 6.0)
				pd.fig.position.y = 0.2 if pd.fig.rotation.x < -1.2 else 0.0
				pd.timer -= delta
				if pd.timer <= 0.0:
					pd.fig.rotation = Vector3.ZERO
					pd.fig.position = Vector3.ZERO
					# se relève sur le trottoir le plus proche, puis s'enfuit
					var best := 0
					var bd := 1e9
					for si in world.sidewalks.size():
						var s: Array = world.sidewalks[si]
						var cp := Geometry3D.get_closest_point_to_segment(np, s[0], s[1])
						var dd := cp.distance_to(np)
						if dd < bd:
							bd = dd
							best = si
					var s2: Array = world.sidewalks[best]
					var cp2 := Geometry3D.get_closest_point_to_segment(np, s2[0], s2[1])
					pd.seg = best
					pd.t = (cp2 - (s2[0] as Vector3)).length() / maxf((s2[0] as Vector3).distance_to(s2[1]), 1.0)
					pd.state = "flee"
					pd.timer = 5.0
