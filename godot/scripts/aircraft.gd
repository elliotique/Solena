class_name Aircraft
extends Node3D
## Avion de ligne pilotable. Modèle de vol repris de la version navigateur : portance et traînée selon
## la vitesse, l'angle d'attaque, les volets et le train ; réacteurs lents à monter en régime ; commandes
## électriques (l'avion garde sa trajectoire manche relâché, inclinaison limitée à 35°) ; décrochage ;
## effet de sol ; freins et inversion de poussée ; atterrissage noté ; crash si trop brutal.

const FLAPS := [0, 5, 15, 20, 30]
const FLAP_CL := [0.0, 0.35, 0.7, 0.95, 1.2]
const FLAP_CD := [0.0, 0.008, 0.018, 0.03, 0.055]
const G := 9.81
const SPECS := {
	"777": {"name": "Boeing 777", "len": 64.0, "span": 61.0, "r": 3.1, "lift": 1.0, "thrust": 5.0, "engines": 2, "double": false, "tail": Color(0.12, 0.35, 0.75)},
	"A380": {"name": "Airbus A380", "len": 73.0, "span": 79.0, "r": 3.6, "lift": 0.86, "thrust": 4.6, "engines": 4, "double": true, "tail": Color(0.75, 0.12, 0.2)},
	"A320": {"name": "Airbus A320", "len": 38.0, "span": 34.0, "r": 2.0, "lift": 1.3, "thrust": 5.6, "engines": 2, "double": false, "tail": Color(1.0, 0.4, 0.15)},
}

var kind := "777"
var spec: Dictionary
var island: Island
var active := false
var home: Transform3D
var yaw := 0.0
var pitch := 0.0
var roll := 0.0
var va := 0.0
var gamma := 0.0
var hold_gamma := 0.0
var n1 := 0.0
var lever := 0.0
var flaps := 2
var gear := true
var on_ground := true
var vel := Vector3.ZERO
var warn := ""
var callout := ""
var toast := ""
var toast_t := 0.0
var crashed_msg := ""
var park := false
var autobrake := false
var gear_nodes: Array[Node3D] = []
var fans: Array[Node3D] = []
var beacon: StandardMaterial3D
var land_light: SpotLight3D

func setup(k: String, isl: Island, pos: Vector3, heading: float) -> void:
	kind = k
	spec = SPECS[k]
	island = isl
	yaw = heading
	position = pos
	home = Transform3D(Basis(Vector3.UP, heading), pos)
	_build_model()
	_apply_pose()

# ------------------------------------------------------------------ modèle 3D
func _mesh(m: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	(parent if parent != null else self).add_child(mi)
	return mi

func _box(size: Vector3, mat: Material, pos: Vector3, rot := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mesh(b, mat, pos, rot, Vector3.ONE, parent)

func _build_model() -> void:
	var L: float = spec.len
	var S: float = spec.span
	var r: float = spec.r
	var hy := 1.0
	if spec.double:
		hy = 1.3
	var gear_h := r * 1.15 + 1.4
	var cy := gear_h + r * hy
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.96, 0.97, 0.98)
	white.metallic = 0.3
	white.roughness = 0.25
	white.clearcoat_enabled = true
	white.clearcoat = 0.8
	var grey := Kit.color_mat(Color(0.62, 0.65, 0.7), 0.35, 0.7)
	var dark := Kit.color_mat(Color(0.08, 0.09, 0.11), 0.4, 0.3)
	var tailm := Kit.color_mat(spec.tail, 0.35, 0.2)
	var glass := Kit.color_mat(Color(0.05, 0.08, 0.12), 0.05, 0.9)
	var fus := CylinderMesh.new()
	fus.top_radius = r
	fus.bottom_radius = r
	fus.height = L * 0.72
	fus.radial_segments = 32
	_mesh(fus, white, Vector3(0, cy, L * 0.04), Vector3(PI / 2, 0, 0), Vector3(1, 1, hy))
	var nose := SphereMesh.new()
	nose.radius = r
	nose.height = r * 2
	nose.radial_segments = 32
	_mesh(nose, white, Vector3(0, cy - r * 0.05, L * 0.4), Vector3.ZERO, Vector3(1, hy, 2.3))
	var tail := CylinderMesh.new()
	tail.top_radius = r * 0.25
	tail.bottom_radius = r
	tail.height = L * 0.2
	tail.radial_segments = 24
	_mesh(tail, white, Vector3(0, cy + r * 0.3, -L * 0.42), Vector3(-PI / 2 + 0.08, 0, 0), Vector3(1, 1, hy))
	_box(Vector3(r * 1.6, r * 0.5, L * 0.7), tailm, Vector3(0, cy - r * hy * 0.78, L * 0.04))
	for side in [-1, 1]:
		_box(Vector3(0.12, 0.42, L * 0.66), dark, Vector3(side * r * 0.985, cy + r * hy * 0.18, L * 0.05))
		if spec.double:
			_box(Vector3(0.12, 0.42, L * 0.52), dark, Vector3(side * r * 0.9, cy + r * hy * 0.62, L * 0.06))
		_box(Vector3(0.2, 0.7, 2.2), glass, Vector3(side * r * 0.55, cy + r * hy * 0.48, L * 0.44), Vector3(0.5, side * 0.6, 0))
	for side in [-1, 1]:
		var inner := Vector3(side * (r + S * 0.13), cy - r * 0.55, L * 0.02)
		_box(Vector3(S * 0.27, 0.7, L * 0.16), grey, inner, Vector3(0, side * 0.42, side * -0.06))
		var outer := Vector3(side * (r + S * 0.36), cy - r * 0.35, -L * 0.07)
		_box(Vector3(S * 0.22, 0.45, L * 0.09), grey, outer, Vector3(0, side * 0.5, side * -0.06))
		_box(Vector3(0.3, 3.2, 2.6), tailm, Vector3(side * (S * 0.5 - 0.3), cy + 1.0, -L * 0.13), Vector3(0, 0, side * 0.15))
		_box(Vector3(S * 0.17, 0.35, L * 0.07), grey, Vector3(side * S * 0.09, cy + r * 0.45, -L * 0.42), Vector3(0, side * 0.5, 0))
	_box(Vector3(0.5, L * 0.17, L * 0.12), tailm, Vector3(0, cy + r + L * 0.08, -L * 0.42), Vector3(-0.45, 0, 0))
	var eng_x: Array = [S * 0.17] if spec.engines == 2 else [S * 0.15, S * 0.3]
	for ex in eng_x:
		for side in [-1, 1]:
			var er: float = r * (0.62 if spec.engines == 2 else 0.5)
			var nac := CylinderMesh.new()
			nac.top_radius = er
			nac.bottom_radius = er * 0.82
			nac.height = er * 3.4
			nac.radial_segments = 24
			var ep := Vector3(side * ex, cy - r * 0.55 - er * 1.05, L * 0.1 - (ex - S * 0.15) * 0.4)
			_mesh(nac, white, ep, Vector3(PI / 2, 0, 0))
			var fan := Node3D.new()
			fan.position = ep + Vector3(0, 0, er * 1.68)
			add_child(fan)
			var disc := CylinderMesh.new()
			disc.top_radius = er * 0.9
			disc.bottom_radius = er * 0.9
			disc.height = 0.1
			_mesh(disc, dark, Vector3.ZERO, Vector3(PI / 2, 0, 0), Vector3.ONE, fan)
			for b in 6:
				_box(Vector3(er * 1.6, 0.25, 0.05), grey, Vector3(0, 0, 0.06), Vector3(0, 0, b * PI / 6), fan)
			fans.append(fan)
	var wheel := CylinderMesh.new()
	wheel.top_radius = 0.65
	wheel.bottom_radius = 0.65
	wheel.height = 0.5
	var legs := [Vector3(0, 0, L * 0.36), Vector3(-r * 1.2, 0, -L * 0.02), Vector3(r * 1.2, 0, -L * 0.02)]
	for lp in legs:
		var g := Node3D.new()
		g.position = lp
		add_child(g)
		var leg := CylinderMesh.new()
		leg.top_radius = 0.2
		leg.bottom_radius = 0.2
		leg.height = gear_h
		_mesh(leg, grey, Vector3(0, gear_h * 0.5 + 0.3, 0), Vector3.ZERO, Vector3.ONE, g)
		for wx in [-0.45, 0.45]:
			for wz in ([0.0] if lp.x == 0 else [-0.8, 0.8]):
				_mesh(wheel, dark, Vector3(wx, 0.65, wz), Vector3(0, 0, PI / 2), Vector3.ONE, g)
		gear_nodes.append(g)
	beacon = Kit.glow_mat(Color(1, 0.1, 0.05), 4.0)
	var bs := SphereMesh.new()
	bs.radius = 0.35
	bs.height = 0.7
	_mesh(bs, beacon, Vector3(0, cy + r * hy + 0.2, 0))
	_mesh(bs, Kit.glow_mat(Color(1, 0.1, 0.1), 3.0), Vector3(-S * 0.5, cy, -L * 0.13))
	_mesh(bs, Kit.glow_mat(Color(0.1, 1, 0.2), 3.0), Vector3(S * 0.5, cy, -L * 0.13))
	land_light = SpotLight3D.new()
	land_light.position = Vector3(0, gear_h, L * 0.42)
	land_light.rotation = Vector3(-0.12, PI, 0)
	land_light.spot_range = 700.0
	land_light.spot_angle = 22.0
	land_light.light_energy = 0.0
	add_child(land_light)

func cockpit_offset() -> Vector3:
	var r: float = spec.r
	var hy := 1.3 if spec.double else 1.0
	return Vector3(-0.6, r * 1.15 + 1.4 + r * hy * 0.55, spec.len * 0.43)

# ------------------------------------------------------------------ commandes
func _k(k: Key) -> bool:
	return Input.is_physical_key_pressed(k)

func key_press(code: Key) -> bool:
	if not active:
		return false
	if code >= KEY_1 and code <= KEY_5:
		flaps = int(code - KEY_1)
		_toast("Volets %d" % FLAPS[flaps])
		return true
	if code == KEY_P:
		park = not park
		_toast("Frein de parc serré" if park else "Frein de parc desserré")
		return true
	if code == KEY_G:
		if on_ground and gear:
			_toast("Train sorti : impossible de le rentrer au sol")
		else:
			gear = not gear
			_toast("Train sorti" if gear else "Train rentré")
		return true
	return false

func _toast(s: String) -> void:
	toast = s
	toast_t = 2.5

func ground_y(x: float, z: float) -> float:
	return island.height_at(x, z) + 0.12

# ------------------------------------------------------------------ vol
func _physics_process(dt: float) -> void:
	var pitch_in := 0.0
	var roll_in := 0.0
	var thr_in := 0.0
	var brake := false
	if active:
		pitch_in = (1.0 if (_k(KEY_DOWN) or _k(KEY_S)) else 0.0) - (1.0 if (_k(KEY_UP) or _k(KEY_W)) else 0.0)
		roll_in = (1.0 if (_k(KEY_LEFT) or _k(KEY_A)) else 0.0) - (1.0 if (_k(KEY_RIGHT) or _k(KEY_D)) else 0.0)
		thr_in = (1.0 if (_k(KEY_SHIFT) or _k(KEY_PAGEUP)) else 0.0) - (1.0 if (_k(KEY_CTRL) or _k(KEY_PAGEDOWN)) else 0.0)
		brake = _k(KEY_SPACE) or park or autobrake
	else:
		lever = 0.0
	toast_t -= dt
	if autobrake and (va < 2.0 or lever > 0.3):
		autobrake = false
	lever = clampf(lever + thr_in * 0.45 * dt, 0.0, 1.0)
	n1 += (lever - n1) * minf(1.0, dt * (0.45 if lever > n1 else 0.7))
	for f in fans:
		f.rotation.z += (4.0 + n1 * 60.0) * dt
	beacon.emission_energy_multiplier = 6.0 if fmod(Time.get_ticks_msec() / 1000.0, 1.2) < 0.15 else 0.2
	if not active and va < 0.1 and on_ground:
		return
	var JK: float = 1.31e-3 * float(spec.lift)
	var T0: float = spec.thrust
	var stall := false
	var reverse := false
	var steps := 4
	var h := dt / steps
	for s in steps:
		var v := maxf(va, 0.1)
		var aoa := pitch - gamma
		var fcl: float = FLAP_CL[flaps]
		var cl_max := 1.4 + fcl * 0.85
		var aoa_stall := (cl_max - 0.25 - fcl) / 5.0
		var cl := 0.25 + 5.0 * aoa + fcl
		if aoa > aoa_stall:
			cl = maxf(0.3, cl_max - (aoa - aoa_stall) * 6.0)
			stall = not on_ground
		var hagl := position.y - ground_y(position.x, position.z)
		var ge := 1.0 - 0.4 * (1.0 - hagl / 30.0) if hagl < 30.0 else 1.0
		var cd: float = 0.022 + FLAP_CD[flaps] + (0.02 if gear else 0.0) + (0.06 if brake and not on_ground else 0.0) + 0.044 * cl * cl * ge
		var q := JK * v * v
		var lift := q * cl
		var drag := q * cd
		reverse = on_ground and brake and lever < 0.05 and va > 3.0 and not park
		var thrust := T0 * n1 * (1.0 - v / 420.0)
		if reverse:
			thrust = -T0 * 0.35 * minf(1.0, v / 20.0) * (0.4 + 0.6 * maxf(n1, 0.5))
		if on_ground:
			var fr := (0.015 + (0.38 if brake else 0.0)) * G * maxf(0.0, 1.0 - lift / G)
			va = maxf(0.0, va + (thrust - drag - fr * signf(va)) * h)
			yaw += roll_in * 0.35 * minf(1.0, 8.0 / maxf(v, 1.0)) * minf(1.0, v / 3.0) * h
			roll += -roll * minf(1.0, h * 5.0)
			if pitch_in > 0.0 and v > 50.0:
				pitch += 0.05 * h
			else:
				pitch += (0.0 - pitch) * minf(1.0, h * 1.2)
			if pitch > 0.19:
				pitch = 0.19
				_toast("Tailstrike ! La queue touche la piste")
			gamma = 0.0
			if lift * cos(roll) > G:
				on_ground = false
				gamma = 0.005
		else:
			if pitch_in != 0.0:
				pitch += pitch_in * 0.11 * h
				hold_gamma = gamma
			else:
				var cl_need := G * cos(hold_gamma) / maxf(JK * v * v * maxf(0.3, cos(roll)), 0.001)
				var aoa_need := clampf((cl_need - 0.25 - fcl) / 5.0, -0.1, aoa_stall * 0.9)
				var tgt := hold_gamma + aoa_need + (hold_gamma - gamma) * 1.5
				pitch += clampf(tgt - pitch, -0.08 * h, 0.08 * h)
			if stall:
				pitch -= 0.1 * h
			if roll_in != 0.0:
				roll += roll_in * 0.3 * h
			elif absf(roll) > 0.61:
				roll -= signf(roll) * 0.12 * h
			roll = clampf(roll, -1.05, 1.05)
			pitch = clampf(pitch, -0.45, 0.45)
			va += (thrust * cos(aoa) - drag - G * sin(gamma)) * h
			va = maxf(va, 5.0)
			gamma += ((lift + thrust * sin(aoa)) * cos(roll) - G * cos(gamma)) / va * h
			gamma = clampf(gamma, -1.3, 1.3)
			yaw += (lift * sin(roll)) / (va * maxf(0.2, cos(gamma))) * h
		var hs := va * cos(gamma)
		vel = Vector3(sin(yaw) * hs, va * sin(gamma), cos(yaw) * hs)
		position += vel * h
		var gy := ground_y(position.x, position.z)
		if not on_ground and position.y <= gy:
			var vs := vel.y
			if not gear:
				_crash("Atterrissage sur le ventre : train rentré !")
				return
			if vs < -6.0 or absf(roll) > 0.22 or pitch < -0.06:
				_crash("Crash : descente trop rapide (%d ft/min)" % int(-vs * 197) if vs < -6.0 else "Crash : l'aile ou le nez a touché le sol")
				return
			if gy < -1.5:
				_crash("Amerrissage forcé !")
				return
			position.y = gy
			on_ground = true
			autobrake = lever < 0.1
			gamma = 0.0
			_toast(("Atterrissage dur" if vs < -3.0 else "Kiss landing !") + " (%d ft/min)" % int(-vs * 197))
		if on_ground:
			position.y = gy
	var hg := position.y - ground_y(position.x, position.z)
	warn = ""
	if stall:
		warn = "STALL"
	elif not on_ground and hg < 120.0 and vel.y < -12.0:
		warn = "PULL UP"
	elif not on_ground and hg < 45.0 and not gear and vel.y < -1.0:
		warn = "TOO LOW GEAR"
	elif va > 185.0:
		warn = "OVERSPEED"
	callout = ""
	if on_ground and va > 1.0:
		callout = "ROTATE" if va > 63.0 else ("V1" if va > 55.0 else "")
	elif not on_ground and vel.y < -0.5 and hg < 17.0:
		callout = str(maxi(10, int(round(hg * 3.28 / 10.0)) * 10))
	elif not on_ground and vel.y > 3.0 and hg < 30.0:
		callout = "POSITIVE RATE"
	if reverse:
		callout = "REV"
	for gn in gear_nodes:
		gn.visible = gear
	land_light.light_energy = 6.0 if gear else 0.0
	_apply_pose()

func _apply_pose() -> void:
	rotation = Vector3(-pitch, yaw, -roll)

func _crash(msg: String) -> void:
	_toast(msg)
	crashed_msg = msg
	global_transform = home
	yaw = home.basis.get_euler().y
	pitch = 0.0
	roll = 0.0
	va = 0.0
	gamma = 0.0
	n1 = 0.0
	lever = 0.0
	gear = true
	flaps = 2
	on_ground = true
	_apply_pose()

# ------------------------------------------------------------------ écran de pilotage (PFD)
func draw_pfd(c: Control) -> void:
	var W := 560.0
	var H := 300.0
	var o := Vector2((c.size.x - W) * 0.5, c.size.y - H - 16.0)
	c.draw_rect(Rect2(o, Vector2(W, H)), Color(0.03, 0.04, 0.06, 0.82))
	var cx := o.x + W * 0.5
	var cy := o.y + 130.0
	var R := 100.0
	var pp := rad_to_deg(pitch) * 4.0
	var rot := Transform2D(roll, Vector2(cx, cy))
	var sky := PackedVector2Array([Vector2(-260, -400 + pp), Vector2(260, -400 + pp), Vector2(260, pp), Vector2(-260, pp)])
	var gnd := PackedVector2Array([Vector2(-260, pp), Vector2(260, pp), Vector2(260, 400 + pp), Vector2(-260, 400 + pp)])
	var clip := Rect2(cx - R, cy - R, 2 * R, 2 * R)
	var skyp := _clip(rot * sky, clip)
	var gndp := _clip(rot * gnd, clip)
	if skyp.size() >= 3:
		c.draw_colored_polygon(skyp, Color(0.18, 0.5, 0.85))
	if gndp.size() >= 3:
		c.draw_colored_polygon(gndp, Color(0.55, 0.36, 0.17))
	for d in range(-20, 25, 10):
		if d == 0:
			continue
		var a := rot * Vector2(-30, pp - d * 4.0)
		var b := rot * Vector2(30, pp - d * 4.0)
		if clip.has_point(a) and clip.has_point(b):
			c.draw_line(a, b, Color.WHITE, 2.0)
	c.draw_line(Vector2(cx - 60, cy), Vector2(cx - 20, cy), Color(1, 0.82, 0.4), 4.0)
	c.draw_line(Vector2(cx + 20, cy), Vector2(cx + 60, cy), Color(1, 0.82, 0.4), 4.0)
	c.draw_rect(Rect2(cx - 3, cy - 3, 6, 6), Color(1, 0.82, 0.4))
	var font := ThemeDB.fallback_font
	var kt := va * 1.944
	var ft := maxf(0.0, position.y - ground_y(position.x, position.z)) * 3.281
	var vs := vel.y * 196.9
	_tape(c, font, Vector2(cx - R - 90, cy), kt, "VITESSE kt", Color(1, 0.35, 0.35) if (kt < 125.0 and not on_ground) else Color.WHITE)
	_tape(c, font, Vector2(cx + R + 20, cy), ft, "ALTITUDE ft", Color.WHITE)
	c.draw_string(font, Vector2(cx + R + 98, cy - 20), "V/S", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.66, 0.66))
	c.draw_string(font, Vector2(cx + R + 98, cy + 2), "%+d" % int(round(vs / 10.0) * 10.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.35, 0.35) if vs < -1000.0 else Color(0.45, 0.9, 0.6))
	var hdg := fposmod(rad_to_deg(-yaw) + 180.0, 360.0)
	c.draw_string(font, Vector2(cx - 40, o.y + 22), "CAP %03d" % int(hdg), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
	var y2 := o.y + H - 40.0
	var items := [["N1", "%d %%" % int(n1 * 100)], ["MANETTE", "%d %%" % int(lever * 100)], ["VOLETS", str(FLAPS[flaps])],
		["TRAIN", "SORTI" if gear else "RENTRÉ"], ["SOL", "OUI" if on_ground else "NON"], ["FREINS", "PARC" if park else ("AUTO" if autobrake else ("OUI" if (active and Input.is_physical_key_pressed(KEY_SPACE)) else "-"))]]
	for i in items.size():
		var x := o.x + 14.0 + i * 92.0
		c.draw_string(font, Vector2(x, y2), items[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.66, 0.66))
		c.draw_string(font, Vector2(x, y2 + 22), items[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	c.draw_string(font, Vector2(o.x + 16, o.y + 22), spec.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.82, 0.4))
	if warn != "":
		var on := int(Time.get_ticks_msec() / 300) % 2 == 0
		c.draw_string(font, Vector2(cx - 70, cy + 70), warn, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 0.2, 0.2) if on else Color(0.5, 0.05, 0.05))
	elif callout != "":
		c.draw_string(font, Vector2(cx - 60, cy + 70), callout, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.45, 0.9, 0.6))
	if toast_t > 0.0:
		c.draw_string(font, Vector2(o.x, o.y - 14), toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.95, 0.8))

func _tape(c: Control, font: Font, center: Vector2, val: float, label: String, col: Color) -> void:
	c.draw_rect(Rect2(center.x, center.y - 100, 70, 200), Color(0.16, 0.17, 0.2, 0.9))
	c.draw_rect(Rect2(center.x - 4, center.y - 15, 78, 30), Color.BLACK)
	c.draw_rect(Rect2(center.x - 4, center.y - 15, 78, 30), col, false, 2.0)
	c.draw_string(font, Vector2(center.x + 6, center.y + 7), str(int(round(val))), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
	c.draw_string(font, Vector2(center.x, center.y - 106), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.66, 0.66))

func _clip(poly: PackedVector2Array, r: Rect2) -> PackedVector2Array:
	var box := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var res := Geometry2D.intersect_polygons(poly, box)
	return res[0] if res.size() > 0 else PackedVector2Array()
