class_name PlayerCar
extends VehicleBody3D
## Voiture du joueur : physique de véhicule Godot (suspensions, adhérence des pneus) + carrosserie arrondie.

@export var engine_max := 4200.0      # N par roue motrice
@export var brake_max := 22.0
@export var top_speed := 58.0          # m/s (≈ 210 km/h)
@export var steer_max := 0.55
@export var paint := Color(1.0, 0.24, 0.54)

var steer_in := 0.0
var throttle := 0.0
var brake_in := 0.0
var handbrake := false
var wheels: Array[VehicleWheel3D] = []
var brake_lights: StandardMaterial3D
var head_lights: StandardMaterial3D
var head_spot: SpotLight3D
var auto_input := {}   # utilisé par les tests automatiques

# Profil latéral (x = longueur depuis l'arrière, y = hauteur), comme dans la version navigateur
const LEN := 4.5
const WID := 1.86
const TOP := [[0, .5], [.05, .8], [.35, .94], [1.1, .98], [3.1, .95], [3.95, .82], [4.4, .64], [4.5, .48]]
const CAB := [[1.0, .96], [1.55, 1.3], [2.3, 1.42], [2.95, 1.37], [3.4, .95]]

func _ready() -> void:
	mass = 1350.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.35, 0.1)
	angular_damp = 0.4
	_build_body()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(WID, 0.9, LEN)
	cs.shape = sh
	cs.position = Vector3(0, 0.75, 0)
	add_child(cs)
	for zf in [1.4, -1.2]:
		for side in [-1, 1]:
			_add_wheel(Vector3(side * (WID / 2 - 0.12), 0.42, zf), zf > 0)

# ------------------------------------------------------------- carrosserie
func _spline(pts: Array, steps := 6) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	for i in n - 1:
		var p0 := Vector2(pts[max(i - 1, 0)][0], pts[max(i - 1, 0)][1])
		var p1 := Vector2(pts[i][0], pts[i][1])
		var p2 := Vector2(pts[i + 1][0], pts[i + 1][1])
		var p3 := Vector2(pts[min(i + 2, n - 1)][0], pts[min(i + 2, n - 1)][1])
		for k in steps:
			var t := float(k) / steps
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(Vector2(pts[n - 1][0], pts[n - 1][1]))
	return out

func _extrude(poly: PackedVector2Array, depth: float, material: Material) -> CSGPolygon3D:
	var c := CSGPolygon3D.new()
	var centered := PackedVector2Array()
	for p in poly:
		centered.append(Vector2(p.x - LEN / 2.0, p.y))
	c.polygon = centered
	c.depth = depth
	c.smooth_faces = true
	c.material = material
	c.rotation.y = -PI / 2.0         # longueur du profil -> axe Z (avant = +Z)
	c.position.x = -depth / 2.0
	add_child(c)
	return c

func _build_body() -> void:
	var paint_m := StandardMaterial3D.new()
	paint_m.albedo_color = paint
	paint_m.metallic = 0.35
	paint_m.roughness = 0.22
	paint_m.clearcoat_enabled = true
	paint_m.clearcoat = 1.0
	paint_m.clearcoat_roughness = 0.08
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.08, 0.12, 0.16)
	glass.metallic = 0.6
	glass.roughness = 0.05
	var body := _spline(TOP)
	# bas de caisse avec passages de roues
	var bottom := 0.28
	for ax in [3.65, 1.05]:
		body.append(Vector2(ax + 0.44, bottom))
		for k in range(0, 13):
			var a := float(k) / 12.0 * PI
			body.append(Vector2(ax + cos(a) * 0.44, bottom + sin(a) * 0.44))
	body.append(Vector2(0, bottom))
	_extrude(body, WID, paint_m)
	var cab := _spline(CAB)
	_extrude(cab, WID * 0.84, glass)
	var roof := PackedVector2Array()
	var up := _spline(CAB.slice(1, 4), 4)
	for p in up:
		roof.append(p + Vector2(0, 0.03))
	for i in range(up.size() - 1, -1, -1):
		roof.append(up[i] - Vector2(0, 0.04))
	_extrude(roof, WID * 0.82, paint_m)
	head_lights = StandardMaterial3D.new()
	head_lights.albedo_color = Color(1, 0.97, 0.9)
	head_lights.emission_enabled = true
	head_lights.emission = Color(1, 0.95, 0.85)
	head_lights.emission_energy_multiplier = 1.0
	brake_lights = StandardMaterial3D.new()
	brake_lights.albedo_color = Color(0.6, 0.02, 0.02)
	brake_lights.emission_enabled = true
	brake_lights.emission = Color(1, 0.08, 0.05)
	brake_lights.emission_energy_multiplier = 0.6
	head_spot = SpotLight3D.new()
	head_spot.position = Vector3(0, 0.8, LEN / 2)
	head_spot.rotation = Vector3(-0.08, PI, 0)   # vers l'avant (+Z)
	head_spot.spot_range = 70.0
	head_spot.spot_angle = 32.0
	head_spot.light_color = Color(1, 0.95, 0.85)
	head_spot.light_energy = 0.0
	add_child(head_spot)
	for side in [-1, 1]:
		_light(Vector3(side * 0.62, 0.7, LEN / 2 - 0.02), head_lights)
		_light(Vector3(side * 0.65, 0.72, -LEN / 2 + 0.02), brake_lights)

func _light(pos: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.36, 0.12, 0.06)
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	add_child(mi)

func _add_wheel(pos: Vector3, front: bool) -> void:
	var w := VehicleWheel3D.new()
	w.position = pos
	w.use_as_steering = front
	w.use_as_traction = not front
	w.wheel_radius = 0.34
	w.wheel_rest_length = 0.14
	w.suspension_travel = 0.18
	w.suspension_stiffness = 42.0
	w.suspension_max_force = 24000.0
	w.damping_compression = 0.35
	w.damping_relaxation = 0.55
	w.wheel_friction_slip = 2.9 if front else 2.7
	w.wheel_roll_influence = 0.12
	var tire := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.34
	cyl.bottom_radius = 0.34
	cyl.height = 0.25
	cyl.radial_segments = 20
	tire.mesh = cyl
	tire.rotation.z = PI / 2.0
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.08, 0.08, 0.09)
	tm.roughness = 0.95
	tire.material_override = tm
	w.add_child(tire)
	var rim := MeshInstance3D.new()
	var rc := CylinderMesh.new()
	rc.top_radius = 0.21
	rc.bottom_radius = 0.21
	rc.height = 0.27
	rim.mesh = rc
	rim.rotation.z = PI / 2.0
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.8, 0.82, 0.85)
	rm.metallic = 0.9
	rm.roughness = 0.25
	rim.material_override = rm
	w.add_child(rim)
	add_child(w)
	wheels.append(w)

# ------------------------------------------------------------- conduite
func _key(k: Key) -> bool:
	return Input.is_physical_key_pressed(k)

func _read_input() -> void:
	if not auto_input.is_empty():
		throttle = auto_input.get("gas", 0.0)
		brake_in = auto_input.get("brake", 0.0)
		steer_in = auto_input.get("steer", 0.0)
		handbrake = auto_input.get("hand", false)
		return
	throttle = 1.0 if (_key(KEY_UP) or _key(KEY_W)) else 0.0
	brake_in = 1.0 if (_key(KEY_DOWN) or _key(KEY_S)) else 0.0
	steer_in = (1.0 if (_key(KEY_LEFT) or _key(KEY_A)) else 0.0) - (1.0 if (_key(KEY_RIGHT) or _key(KEY_D)) else 0.0)
	handbrake = _key(KEY_SPACE)

func forward_speed() -> float:
	return linear_velocity.dot(global_transform.basis.z)

func _physics_process(delta: float) -> void:
	_read_input()
	var v := forward_speed()
	# direction : plus la vitesse est haute, moins on braque (et le volant tourne progressivement)
	var target := steer_in * steer_max / (1.0 + absf(v) / 16.0)
	steering = move_toward(steering, target, delta * 1.6)
	var force := 0.0
	var brk := 0.0
	if throttle > 0.0:
		force = engine_max * throttle * clampf(1.0 - pow(maxf(v, 0.0) / top_speed, 2.0), 0.0, 1.0)
	if brake_in > 0.0:
		if v > 1.0:
			brk = brake_max * brake_in
		else:
			force = -engine_max * 0.6 * brake_in   # marche arrière
	engine_force = force
	brake = brk
	for w in wheels:
		if not w.use_as_steering:
			w.brake = brake_max * 1.5 if handbrake else brk
			w.wheel_friction_slip = 1.1 if handbrake else 2.7
	brake_lights.emission_energy_multiplier = 3.0 if (brk > 0.0 or handbrake) else 0.6
	# résistance de l'air
	apply_central_force(-linear_velocity * linear_velocity.length() * 0.38)

func reset_upright() -> void:
	var yaw := global_rotation.y
	global_transform = Transform3D(Basis(Vector3.UP, yaw), global_position + Vector3(0, 1.2, 0))
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
