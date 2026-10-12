class_name Walker
extends CharacterBody3D
## Le joueur à pied : marche, course (Espace), gravité, monte les trottoirs, bras et jambes animés.

var speed := 0.0
var active := false
var phase := 0.0
var legs: Array = []
var arms: Array = []
var anim: AnimationPlayer

func _ready() -> void:
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	var skin := Kit.color_mat(Color(0.93, 0.76, 0.62), 0.8)
	var shirt := Kit.color_mat(Color(1.0, 0.25, 0.55), 0.7)
	var pants := Kit.color_mat(Color(0.12, 0.16, 0.28), 0.8)
	_part(self, _capsule(0.21, 0.64), shirt, Vector3(0, 1.28, 0))
	_part(self, _sphere(0.14), skin, Vector3(0, 1.74, 0))
	_part(self, _sphere(0.15), Kit.color_mat(Color(0.14, 0.09, 0.06), 0.9), Vector3(0, 1.79, 0.02)).scale = Vector3(1, 0.65, 1)
	for sx in [-0.1, 0.1]:
		var piv := Node3D.new()
		piv.position = Vector3(sx, 0.96, 0)
		add_child(piv)
		_part(piv, _capsule(0.08, 0.84), pants, Vector3(0, -0.46, 0))
		legs.append(piv)
	for sx in [-0.28, 0.28]:
		var piv := Node3D.new()
		piv.position = Vector3(sx, 1.54, 0)
		add_child(piv)
		_part(piv, _capsule(0.065, 0.62), shirt, Vector3(0, -0.29, 0))
		arms.append(piv)
	var kc := CharacterKit.make(self, 0)
	if kc.size() > 0:
		for ch in get_children():
			if ch != kc[0] and not (ch is CollisionShape3D):
				(ch as Node3D).visible = false
		anim = kc[1]

func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	return c

func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s

func _part(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi

func _physics_process(delta: float) -> void:
	if not visible:
		return
	var fwd_in := 0.0
	var turn := 0.0
	var run := false
	if active:
		fwd_in = (1.0 if (Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W)) else 0.0) - (0.6 if (Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S)) else 0.0)
		turn = (1.0 if (Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A)) else 0.0) - (1.0 if (Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D)) else 0.0)
		run = Input.is_physical_key_pressed(KEY_SPACE)
	rotation.y += turn * 2.6 * delta
	var target := fwd_in * (7.5 if run else 3.6)
	speed = move_toward(speed, target, delta * 14.0)
	var f := global_transform.basis.z
	velocity.x = f.x * speed
	velocity.z = f.z * speed
	if not is_on_floor():
		velocity.y -= 9.81 * delta
	else:
		velocity.y = maxf(velocity.y, -1.0)
	move_and_slide()
	# animation de marche
	phase += delta * (2.0 + absf(speed) * 2.4)
	var sw := sin(phase) * clampf(absf(speed) * 0.2, 0.0, 0.8)
	(legs[0] as Node3D).rotation.x = sw
	(legs[1] as Node3D).rotation.x = -sw
	(arms[0] as Node3D).rotation.x = -sw * 0.8
	(arms[1] as Node3D).rotation.x = sw * 0.8
	if anim != null:
		var want := "kit/run" if absf(speed) > 0.5 else "kit/idle"
		if anim.has_animation(want) and anim.current_animation != want:
			anim.play(want, 0.2)
		anim.speed_scale = clampf(absf(speed) / 6.0, 0.5, 1.4) if absf(speed) > 0.5 else 1.0
	if global_position.y < -20.0:
		global_position.y = 5.0
