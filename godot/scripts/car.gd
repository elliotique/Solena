class_name PlayerCar
extends VehicleBody3D
## Voiture du joueur : physique de véhicule Godot (suspensions, pneus) avec anti-roulis,
## appui aérodynamique et amortisseurs réglés pour ne plus se retourner.

@export var model := "sports"
@export var paint := Color(1.0, 0.24, 0.54)
@export var engine_max := 3900.0      # N par roue motrice (propulsion)
@export var brake_max := 30.0
@export var top_speed := 62.0          # m/s (≈ 225 km/h)
@export var steer_max := 0.5

var steer_in := 0.0
var throttle := 0.0
var brake_in := 0.0
var handbrake := false
var wheels: Array[VehicleWheel3D] = []
var brake_lights: StandardMaterial3D
var head_lights: StandardMaterial3D
var head_spot: SpotLight3D
var auto_input := {}   # utilisé par les tests automatiques
var info: Dictionary
var active := true

func _ready() -> void:
	info = CarBody.info(model)
	var L: float = info.L
	var W: float = info.W
	mass = 1400.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.1, 0.05)
	angular_damp = 0.6
	contact_monitor = true
	max_contacts_reported = 4
	var mats := CarBody.build(self, model, paint, false, true)
	head_lights = mats.head
	brake_lights = mats.tail
	# collision : caisse (boîte + capsule couchée) ; le bas reste au-dessus des trottoirs
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(W - 0.1, 0.5, L - 0.2)
	cs.shape = sh
	cs.position = Vector3(0, 0.9, 0)
	add_child(cs)
	var cs2 := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = L - 0.2
	cs2.shape = cap
	cs2.rotation.x = PI / 2.0
	cs2.position = Vector3(0, 1.0, 0)
	add_child(cs2)
	var R: float = info.R
	for ax in info.arches:
		for side in [-1, 1]:
			_add_wheel(Vector3(side * (W / 2 - 0.14), R + 0.15, ax - L / 2), ax > L / 2, R)
	head_spot = SpotLight3D.new()
	head_spot.position = Vector3(0, 0.75, L / 2 + 0.1)
	head_spot.rotation = Vector3(-0.07, PI, 0)
	head_spot.spot_range = 80.0
	head_spot.spot_angle = 30.0
	head_spot.light_color = Color(1, 0.95, 0.85)
	head_spot.light_energy = 0.0
	head_spot.shadow_enabled = true
	add_child(head_spot)

func _add_wheel(pos: Vector3, front: bool, r: float) -> void:
	var w := VehicleWheel3D.new()
	w.position = pos
	w.use_as_steering = front
	w.use_as_traction = not front
	w.wheel_radius = r
	w.wheel_rest_length = 0.2
	w.suspension_travel = 0.32
	w.suspension_stiffness = 48.0          # ressort (par kg) : environ 1,1 Hz, confortable
	w.suspension_max_force = 14000.0
	w.damping_compression = 3.2            # amortisseurs réellement amortis : fini les rebonds qui retournent la voiture
	w.damping_relaxation = 4.2
	w.wheel_friction_slip = 3.1 if front else 3.4   # l'arrière accroche un peu plus : pas de toupie
	w.wheel_roll_influence = 0.008
	w.add_child(CarBody.wheel_visual(r))
	add_child(w)
	wheels.append(w)

# ------------------------------------------------------------- conduite
func _key(k: Key) -> bool:
	return Input.is_physical_key_pressed(k)

func _read_input() -> void:
	if not active:
		throttle = 0.0
		brake_in = 0.0
		steer_in = 0.0
		handbrake = true
		return
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

func grounded() -> bool:
	for w in wheels:
		if w.is_in_contact():
			return true
	return false

func _physics_process(delta: float) -> void:
	_read_input()
	var v := forward_speed()
	var spd := linear_velocity.length()
	var target := steer_in * steer_max / (1.0 + absf(v) / 9.0)
	steering = move_toward(steering, target, delta * (2.2 if absf(target) > absf(steering) else 3.5))
	var force := 0.0
	var brk := 0.0
	if throttle > 0.0:
		force = engine_max * throttle * clampf(1.0 - pow(maxf(v, 0.0) / top_speed, 2.2), 0.0, 1.0) * (1.25 if v < 12.0 else 1.0)
		if v < -1.0:
			brk = brake_max
	if brake_in > 0.0:
		if v > 1.0:
			brk = brake_max * brake_in
		else:
			force = -engine_max * 0.7 * brake_in
	engine_force = force
	brake = brk
	for w in wheels:
		if not w.use_as_steering:
			w.brake = brake_max * 1.6 if handbrake else brk
			w.wheel_friction_slip = 1.5 if handbrake else 3.4
	brake_lights.emission_energy_multiplier = 3.0 if (brk > 0.0 or handbrake) else 0.6
	var up := global_transform.basis.y
	# résistance de l'air et appui aérodynamique
	apply_central_force(-linear_velocity * spd * 0.36)
	if grounded():
		apply_central_force(-up * spd * spd * 1.6)
	# barre anti-roulis : ramène la caisse à plat et amortit les oscillations
	var axis := up.cross(Vector3.UP)
	var tilt := asin(clampf(axis.length(), 0.0, 1.0))
	if tilt > 0.001:
		var ax := axis.normalized()
		var k := 65000.0 if grounded() else 9000.0
		apply_torque(ax * tilt * k - ax * angular_velocity.dot(ax) * 9000.0)

func reset_upright() -> void:
	var yaw := global_rotation.y
	global_transform = Transform3D(Basis(Vector3.UP, yaw), global_position + Vector3(0, 1.2, 0))
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
