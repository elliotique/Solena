class_name Boat
extends Node3D
## Bateau à moteur pilotable : suit la houle (mêmes vagues que la mer), cabre à l'accélération,
## s'incline en virage, ne peut pas monter sur la terre.

var island: Island
var active := false
var v := 0.0
var yaw := 0.0
var steer := 0.0
var throttle := 0.0
var home: Transform3D
var dock := Vector3.ZERO      # point du quai où l'on débarque

func setup(isl: Island, pos: Vector3, heading: float, dock_point: Vector3, hull_col: Color) -> void:
	island = isl
	position = pos
	yaw = heading
	dock = dock_point
	home = Transform3D(Basis(Vector3.UP, heading), pos)
	var white := Kit.color_mat(Color(0.97, 0.97, 0.97), 0.3, 0.1)
	var hullm := Kit.color_mat(hull_col, 0.35, 0.2)
	_box(Vector3(4.2, 1.4, 11.0), hullm, Vector3(0, 0.3, 0))
	_box(Vector3(4.4, 0.25, 11.2), white, Vector3(0, 1.05, 0))
	var bow := MeshInstance3D.new()
	var pr := PrismMesh.new()
	pr.size = Vector3(4.2, 2.8, 1.4)
	bow.mesh = pr
	bow.material_override = hullm
	bow.position = Vector3(0, 0.3, 6.2)
	bow.rotation = Vector3(PI / 2, 0, 0)
	add_child(bow)
	_box(Vector3(3.0, 1.6, 3.4), white, Vector3(0, 1.9, -0.6))
	_box(Vector3(2.8, 0.9, 0.12), Kit.color_mat(Color(0.1, 0.15, 0.2), 0.05, 0.8), Vector3(0, 2.1, 1.15))
	_box(Vector3(3.6, 0.6, 2.6), Kit.color_mat(Color(0.55, 0.36, 0.2), 0.7), Vector3(0, 1.4, -3.8))

func _box(size: Vector3, m: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	add_child(mi)

func _k(k: Key) -> bool:
	return Input.is_physical_key_pressed(k)

func _physics_process(dt: float) -> void:
	throttle = 0.0
	var st := 0.0
	if active:
		throttle = (1.0 if (_k(KEY_UP) or _k(KEY_W)) else 0.0) - (0.6 if (_k(KEY_DOWN) or _k(KEY_S)) else 0.0)
		st = (1.0 if (_k(KEY_LEFT) or _k(KEY_A)) else 0.0) - (1.0 if (_k(KEY_RIGHT) or _k(KEY_D)) else 0.0)
	steer = move_toward(steer, st, dt * 2.5)
	v = move_toward(v, throttle * 24.0, dt * (5.0 if throttle != 0.0 else 2.5))
	yaw += steer * dt * 0.8 * clampf(absf(v) / 6.0, 0.15, 1.0) * (1.0 if v >= 0.0 else -1.0)
	var f := Vector3(sin(yaw), 0, cos(yaw))
	var np := position + f * v * dt
	if island.height_at(np.x, np.z) > Island.SEA - 0.8:
		v = -v * 0.3          # touche le fond ou la côte : rebond
	else:
		position.x = np.x
		position.z = np.z
	var t := Time.get_ticks_msec() / 1000.0
	var wave := sin(position.x * 0.045 + t * 0.9) * 0.3 + cos(position.z * 0.035 + t * 0.7) * 0.25
	position.y = Island.SEA + 0.15 + wave
	rotation = Vector3(-v * 0.006 + sin(t * 1.1) * 0.025, yaw, -steer * absf(v) * 0.007 + sin(t * 0.9) * 0.03)
