class_name Traffic
extends Node3D
## Circulation : voitures physiques qui suivent leurs voies, tournent aux carrefours, respectent
## les feux de l'avenue, freinent derrière les autres et deviennent incontrôlées après un choc.

const COUNT := 30
const MODELS := ["sedan", "sedan", "hatch", "wagon", "suv", "van", "coupe", "micro", "pickup", "taxi", "taxi", "police"]

var world: World
var player: PlayerCar
var rng := RandomNumberGenerator.new()
var cars: Array = []
var light_t := 0.0
var org := Vector3.ZERO      # origine de la ville sur l'île
var dormant := false

func setup(w: World, p: PlayerCar) -> void:
	world = w
	player = p
	org = w.global_position
	rng.seed = 777 + int(org.x)
	for k in COUNT:
		var c := _make_car(MODELS[rng.randi() % MODELS.size()])
		cars.append(c)
		_respawn(c, true)

func _make_car(model: String) -> Dictionary:
	var rb := RigidBody3D.new()
	rb.mass = 1300.0
	rb.axis_lock_angular_x = true
	rb.axis_lock_angular_z = true
	rb.linear_damp = 0.05
	rb.contact_monitor = true
	rb.max_contacts_reported = 4
	add_child(rb)
	var info := CarBody.info(model)
	var col: Color = Color(1, 0.8, 0.2) if model == "taxi" else (Color(0.1, 0.12, 0.18) if model == "police" else CarBody.COLORS[rng.randi() % CarBody.COLORS.size()])
	CarBody.build(rb, model, col, true)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(info.W - 0.1, 1.0, info.L - 0.1)
	cs.shape = sh
	cs.position = Vector3(0, 0.75, 0)
	rb.add_child(cs)
	var c := {"body": rb, "model": model, "dir": Vector3.FORWARD, "line": 0.0, "road": 0, "off": 2.2, "speed": 0.0,
		"cruise": 12.0, "turned_at": 99999.0, "crash": 0.0, "grace": 1.0, "len": info.L, "color": col}
	rb.body_entered.connect(func(other): _on_hit(c, other))
	return c

func _on_hit(c: Dictionary, other: Node) -> void:
	# le sol et les trottoirs (StaticBody) ne comptent pas comme un choc
	if not (other is RigidBody3D):
		return
	var ov: Vector3 = other.linear_velocity if other is RigidBody3D else Vector3.ZERO
	var rel: float = ((c.body as RigidBody3D).linear_velocity - ov).length()
	if rel > 4.0:
		c.crash = 4.0 + rel * 0.15

## Voie : route d'indice i orientée selon `dir` (±X ou ±Z), décalée à droite du sens de marche
func _lane_offset(i: int, lane: int) -> float:
	if i == World.AVENUE:
		return 2.4 if lane == 0 else 6.0
	return 2.2

func _right_of(dir: Vector3) -> Vector3:
	return Vector3(-dir.z, 0, dir.x)

func _respawn(c: Dictionary, initial := false) -> void:
	var rb: RigidBody3D = c.body
	for attempt in 30:
		var i := rng.randi() % World.GRID.size()
		var along_z := rng.randf() < 0.5
		var sgn := 1.0 if rng.randf() < 0.5 else -1.0
		var dir := Vector3(0, 0, sgn) if along_z else Vector3(sgn, 0, 0)
		var lane := rng.randi() % 2 if i == World.AVENUE else 0
		var off := _lane_offset(i, lane)
		var s := rng.randf_range(-World.CITY + 20, World.CITY - 20)
		var line: float = World.GRID[i]
		var right := _right_of(dir)
		var pos := (Vector3(line, 0, s) if along_z else Vector3(s, 0, line)) + right * off
		var d := pos.distance_to(player.global_position - org)
		if d < (25.0 if initial else 90.0) or d > 260.0:
			continue
		var clear := true
		for o in cars:
			if o != c and (o.body.global_position - org).distance_to(pos) < 12.0:
				clear = false
		if not clear:
			continue
		c.dir = dir
		c.road = i
		c.line = line
		c.off = off
		c.cruise = (14.0 if i == World.AVENUE else 11.0) * rng.randf_range(0.85, 1.1)
		c.speed = c.cruise * 0.8
		c.turned_at = 99999.0
		c.crash = 0.0
		c.grace = 1.5
		rb.global_transform = Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z)), pos + org + Vector3(0, 0.3, 0))
		rb.linear_velocity = dir * c.speed
		rb.angular_velocity = Vector3.ZERO
		return

func light_green(moving_along_z: bool) -> bool:
	var phase := fmod(light_t, 30.0)
	return (phase < 13.0) if moving_along_z else (phase >= 15.0 and phase < 28.0)

func light_state(moving_along_z: bool) -> String:
	var phase := fmod(light_t, 30.0)
	if moving_along_z:
		return "g" if phase < 13.0 else ("o" if phase < 15.0 else "r")
	return "g" if (phase >= 15.0 and phase < 28.0) else ("o" if phase >= 28.0 else "r")

func _physics_process(delta: float) -> void:
	light_t += delta
	var pp := player.global_position - org
	# ville lointaine : voitures en sommeil (pas de calcul, invisibles)
	var far := Vector2(pp.x, pp.z).length() > 1100.0
	if far != dormant:
		dormant = far
		for c in cars:
			(c.body as RigidBody3D).visible = not far
			(c.body as RigidBody3D).freeze = far
			if not far:
				_respawn(c, true)
	if dormant:
		return
	for c in cars:
		var rb: RigidBody3D = c.body
		var pos := rb.global_position - org
		if pos.distance_to(pp) > 320.0 or pos.y < -5.0:
			_respawn(c)
			continue
		if c.crash > 0.0:
			c.crash -= delta
			if c.crash <= 0.0:
				_realign(c)
			continue
		var dir: Vector3 = c.dir
		var along_z := absf(dir.z) > 0.5
		var a := pos.z if along_z else pos.x
		# carrefour : on choisit une direction une seule fois par carrefour
		for g in World.GRID:
			if absf(a - g) < 1.2 and absf(g - c.turned_at) > 1.0:
				c.turned_at = g
				var r := rng.randf()
				var edge := absf(g) > World.CITY - 50 and signf(g) == signf(dir.z if along_z else dir.x)
				if r < 0.22 or (edge and r < 0.6):
					_turn(c, g, true)
				elif r < 0.44 or edge:
					_turn(c, g, false)
				dir = c.dir
				along_z = absf(dir.z) > 0.5
				break
		# demi-tour aux limites de la ville
		var a2 := pos.z if along_z else pos.x
		if absf(a2) > World.CITY + 5 and signf(a2) == signf(dir.z if along_z else dir.x):
			c.dir = -dir
			dir = c.dir
			c.turned_at = 99999.0
		var right := _right_of(dir)
		var lane_pt := Vector3(c.line + right.x * c.off, pos.y, pos.z) if along_z else Vector3(pos.x, pos.y, c.line + right.z * c.off)
		var correction := lane_pt - pos
		correction.y = 0.0
		var target_speed: float = c.cruise
		# feux de l'avenue (carrefours situés sur x = 0)
		for g in World.GRID:
			var ahead := (g - a2) * (dir.z if along_z else dir.x)
			var on_avenue_cross := (not along_z and absf(g - World.GRID[World.AVENUE]) < 0.1) or (along_z and absf(c.line - World.GRID[World.AVENUE]) < 0.1)
			if on_avenue_cross and ahead > 4.0 and ahead < 28.0 and light_state(along_z) != "g":
				target_speed = minf(target_speed, maxf(0.0, (ahead - 12.0) * 0.8))
		# distance au véhicule devant (autres voitures et joueur)
		var fwd := dir
		for o in cars:
			if o == c:
				continue
			var d: Vector3 = (o.body.global_position - org) - pos
			var along := d.dot(fwd)
			if along > 0.0 and along < 22.0 and absf(d.dot(right)) < 2.0:
				target_speed = minf(target_speed, maxf(0.0, (along - 7.0) * 0.9))
		var dp := pp - pos
		var alp := dp.dot(fwd)
		if alp > 0.0 and alp < 24.0 and absf(dp.dot(right)) < 2.4:
			target_speed = minf(target_speed, maxf(0.0, (alp - 7.0) * 0.8))
		c.speed = move_toward(c.speed, target_speed, delta * (7.0 if target_speed < c.speed else 3.0))
		var want: Vector3 = dir * float(c.speed) + correction.limit_length(3.0) * 1.2
		var v := rb.linear_velocity
		var hv := Vector3(v.x, 0, v.z).lerp(want, minf(1.0, delta * 4.0))
		rb.linear_velocity = Vector3(hv.x, v.y, hv.z)
		var yaw := atan2(dir.x, dir.z)
		var err := wrapf(yaw - rb.global_rotation.y, -PI, PI)
		rb.angular_velocity = Vector3(0, clampf(err * 4.0, -2.5, 2.5), 0)
		# après un gros écart (choc avec un obstacle), la voiture reste « sonnée »
		c.grace = maxf(0.0, c.grace - delta)
		if c.grace <= 0.0 and (v - dir * c.speed).length() > 12.0:
			c.crash = 3.0

func _turn(c: Dictionary, g: float, left: bool) -> void:
	var dir: Vector3 = c.dir
	var new_dir := Vector3(-dir.z, 0, dir.x) if left else Vector3(dir.z, 0, -dir.x)
	# la nouvelle route passe par le carrefour : son indice est celui de g dans la grille
	var idx := World.GRID.find(g)
	if idx < 0:
		return
	c.dir = new_dir
	c.road = idx
	c.line = g
	c.off = _lane_offset(idx, 0)
	c.cruise = (14.0 if idx == World.AVENUE else 11.0) * rng.randf_range(0.85, 1.1)
	c.speed = minf(c.speed, 7.0)
	c.grace = 2.0

func _realign(c: Dictionary) -> void:
	# reprend la voie la plus proche dans le sens où pointe la voiture
	var rb: RigidBody3D = c.body
	var f := rb.global_transform.basis.z
	var dir := Vector3(signf(f.x), 0, 0) if absf(f.x) > absf(f.z) else Vector3(0, 0, signf(f.z))
	var pos := rb.global_position - org
	var along_z := absf(dir.z) > 0.5
	var coord := pos.x if along_z else pos.z
	var best := 0
	for i in World.GRID.size():
		if absf(World.GRID[i] - coord) < absf(World.GRID[best] - coord):
			best = i
	if absf(World.GRID[best] - coord) > 14.0:
		c.crash = 2.0
		return
	c.dir = dir
	c.road = best
	c.line = World.GRID[best]
	c.off = _lane_offset(best, 0)
	c.speed = 0.0
	c.turned_at = 99999.0
	c.grace = 2.0
