extends Node3D
## Solena (Godot) : monde, rendu (illumination globale SDFGI, réflexions SSR, brouillard volumétrique),
## cycle jour/nuit, caméra, circulation, piétons, interface.

const DAY_SECONDS := 540.0

var world: World
var island: Island
var all_traffic: Array = []
var all_peds: Array = []
var car: PlayerCar
var walker: Walker
var engine: EngineSound
var boats: Array = []
var boat: Boat = null
var train: Node3D = null
var planes: Array = []
var plane: Aircraft = null
var pfd: Control
var mode := "car"
var traffic: Traffic
var peds: Peds
var cam: Camera3D
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var hud: Label
var help_label: Label
var pause_label: Label
var hour := 16.8
var night := 0.0
var cam_yaw := 0.0
var cam_mode := 0
var lamp_pool: Array[OmniLight3D] = []
var lamp_t := 0.0
var test := ""
var frame := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	test = OS.get_environment("SOLENA_TEST")
	if test.begins_with("night"):
		hour = 22.5
	_environment()
	# l'île entière : relief, mer, routes, aéroports, et les deux villes (Solena, Porto Sol)
	island = Island.new()
	island.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(island)
	island.build()
	world = island.cities[0]
	car = PlayerCar.new()
	car.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(car)
	car.global_transform = Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(-300, 0.8, 2.3))
	for c in island.cities:
		var tr := Traffic.new()
		tr.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(tr)
		tr.setup(c, car)
		all_traffic.append(tr)
		var pd := Peds.new()
		pd.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(pd)
		pd.setup(c, car)
		all_peds.append(pd)
	traffic = all_traffic[0]
	peds = all_peds[0]
	cam = Camera3D.new()
	cam.fov = 65
	cam.far = 9000
	cam.near = 0.1
	add_child(cam)
	cam_yaw = car.global_rotation.y
	cam.global_position = car.global_position + Vector3(0, 3, -8)
	for k in 24:
		var l := OmniLight3D.new()
		l.light_color = Color(1, 0.8, 0.55)
		l.omni_range = 22.0
		l.omni_attenuation = 1.4
		l.light_energy = 0.0
		l.light_volumetric_fog_energy = 1.5
		l.shadow_enabled = false
		add_child(l)
		lamp_pool.append(l)
	_hud()
	walker = Walker.new()
	walker.process_mode = Node.PROCESS_MODE_PAUSABLE
	walker.visible = false
	add_child(walker)
	engine = EngineSound.new()
	add_child(engine)
	# avions de ligne : 777 en bout de piste et A320 sur le tarmac à Solena, A380 en bout de piste à Porto Sol
	for sp in [[0, "777", true], [0, "A320", false], [1, "A380", true]]:
		var ap: Dictionary = Island.AIRPORTS[sp[0]]
		var fr: Array = island.airport_frame(ap)
		var ax: Vector2 = fr[0]
		var ay: Vector2 = fr[1]
		var c: Vector2 = ap.pos
		var p2: Vector2 = (c - ax * (float(ap.len) * 0.5 - 160.0)) if sp[2] else (c + ay * 190.0 - ax * 150.0)
		var fwd: Vector2 = ax if sp[2] else -ay
		var pl := Aircraft.new()
		pl.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(pl)
		pl.setup(sp[1], island, Vector3(p2.x, island.height_at(p2.x, p2.y) + 0.12, p2.y), atan2(fwd.x, fwd.y))
		planes.append(pl)
	if island.has_meta("train"):
		train = island.get_meta("train")
	# bateaux amarrés au bout des jetées du port
	if not island.port.is_empty():
		var pc: Vector2 = island.port.center
		var pd2: Vector2 = island.port.dir
		var pt := Vector2(-pd2.y, pd2.x)
		var cols := [Color(0.1, 0.35, 0.75), Color(0.85, 0.2, 0.2), Color(0.1, 0.55, 0.45)]
		var offs := [-130.0, 130.0, 390.0]
		for k in 3:
			var off: float = offs[k]
			var bp: Vector2 = pc + pd2 * 562.0 - pt * off
			var dk: Vector2 = pc + pd2 * 512.0 - pt * off
			var b := Boat.new()
			b.process_mode = Node.PROCESS_MODE_PAUSABLE
			add_child(b)
			b.setup(island, Vector3(bp.x, Island.SEA, bp.y), atan2(pd2.x, pd2.y), Vector3(dk.x, 2.2, dk.y), cols[k])
			boats.append(b)
	pfd = Control.new()
	pfd.set_anchors_preset(Control.PRESET_FULL_RECT)
	pfd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pfd.draw.connect(_draw_pfd)
	hud.get_parent().add_child(pfd)
	walker.global_position = Vector3(0, -50, 0)

# ------------------------------------------------------------- ambiance
func _environment() -> void:
	var lite := test.contains("lite")
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 25.0
	sky_mat.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	# illumination globale temps réel : la lumière rebondit sur les façades et la route
	env.sdfgi_enabled = not lite
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.5
	env.sdfgi_energy = 1.0
	# réflexions dans les vitres, sur la carrosserie et l'asphalte
	env.ssr_enabled = true
	env.ssr_max_steps = 64
	env.ssr_fade_in = 0.1
	env.ssr_fade_out = 2.0
	env.ssao_enabled = true
	env.ssao_radius = 1.0
	env.ssao_intensity = 0.9
	env.ssil_enabled = not lite
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# brouillard volumétrique : halos des lampadaires la nuit, profondeur de l'air le jour
	env.volumetric_fog_enabled = not lite
	env.volumetric_fog_density = 0.0007
	env.volumetric_fog_albedo = Color(0.9, 0.92, 1.0)
	env.volumetric_fog_length = 180.0
	env.volumetric_fog_sky_affect = 0.2
	env.fog_enabled = true
	env.fog_density = 0.00005
	env.fog_sky_affect = 0.05
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	env.adjustment_contrast = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 320.0
	sun.shadow_blur = 1.2
	sun.light_angular_distance = 0.6
	sun.light_volumetric_fog_energy = 0.6
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.light_energy = 0.0
	moon.rotation_degrees = Vector3(-55, -40, 0)
	moon.shadow_enabled = true
	add_child(moon)

func _update_sky(delta: float) -> void:
	var speed := 40.0 if Input.is_physical_key_pressed(KEY_T) else 1.0
	hour = fmod(hour + delta * 24.0 / DAY_SECONDS * speed, 24.0)
	var ang := (hour - 6.0) / 12.0 * PI
	var elev := sin(ang)
	sun.rotation = Vector3(-maxf(elev, -0.2) * 1.2 - 0.05, -ang + PI / 2.0, 0)
	var day := smoothstep(-0.08, 0.3, elev)
	var dusk := clampf(1.0 - absf(elev + 0.02) / 0.3, 0.0, 1.0)
	night = 1.0 - smoothstep(-0.05, 0.12, elev)
	sun.light_energy = 1.6 * day
	sun.light_color = Color(1, 0.96, 0.9).lerp(Color(1, 0.55, 0.3), dusk)
	sun.visible = day > 0.01
	moon.light_energy = 0.18 * night
	moon.visible = night > 0.05
	sky_mat.sky_top_color = Color(0.02, 0.03, 0.09).lerp(Color(0.2, 0.42, 0.82), day).lerp(Color(0.3, 0.25, 0.55), dusk * 0.5)
	sky_mat.sky_horizon_color = Color(0.06, 0.07, 0.16).lerp(Color(0.7, 0.82, 0.95), day).lerp(Color(1.0, 0.55, 0.4), dusk * 0.8)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color = Color(0.08, 0.09, 0.08)
	sky_mat.sky_energy_multiplier = 0.25 + 0.75 * day
	env.ambient_light_energy = 0.6 + 0.6 * day
	env.fog_light_color = sky_mat.sky_horizon_color
	env.volumetric_fog_density = lerpf(0.0005, 0.0035, night)
	if KenneyLib.night_mat != null:
		KenneyLib.night_mat.albedo_color = Color(1.0, 0.85, 0.6) * (night * 1.7)
	for w in island.cities:
		_city_lights(w)
	car.head_lights.emission_energy_multiplier = 1.0 + night * 6.0
	car.head_spot.light_energy = night * 7.0

func _city_lights(cw: World) -> void:
	for m in cw.window_mats:
		m.emission_energy_multiplier = night * 2.6
	for m in cw.shop_mats:
		m.emission_energy_multiplier = 0.05 + night * 1.2
	for l in cw.sign_labels:
		l.visible = true
	cw.lamp_mat.emission_energy_multiplier = 0.3 + night * 9.0
	# feux tricolores
	for axis in ["z", "x"]:
		var st := traffic.light_state(axis == "z")
		for c in ["r", "o", "g"]:
			(cw.tl_mats[axis][c] as StandardMaterial3D).emission_energy_multiplier = 5.0 if c == st else 0.08

func _update_lamps(delta: float) -> void:
	lamp_t -= delta
	if lamp_t > 0.0:
		return
	lamp_t = 0.25
	var p: Vector3 = walker.global_position if mode == "foot" else (plane.global_position if mode == "plane" else (boat.global_position if mode == "boat" else ((train.cars[0] as Node3D).global_position if mode == "train" else car.global_position)))
	var best: World = island.cities[0]
	for cw in island.cities:
		if (cw as World).global_position.distance_to(p) < best.global_position.distance_to(p):
			best = cw
	var near: Array[Vector3] = best.lamp_heads.duplicate()
	near.sort_custom(func(a, b): return a.distance_squared_to(p) < b.distance_squared_to(p))
	for k in lamp_pool.size():
		var l := lamp_pool[k]
		if k < near.size() and night > 0.05:
			l.global_position = near[k] - Vector3(0, 0.5, 0)
			l.light_energy = 5.0 * night
			l.visible = true
		else:
			l.visible = false

# ------------------------------------------------------------- caméra (ne traverse pas les murs)
func _update_camera(delta: float) -> void:
	var tn: Node3D = walker if mode == "foot" else (plane if mode == "plane" else (boat if mode == "boat" else (train.cars[0] if mode == "train" else car)))
	var yaw: float = tn.global_rotation.y
	cam_yaw = lerp_angle(cam_yaw, yaw, minf(1.0, delta * 3.2))
	var back := Vector3(sin(cam_yaw), 0, cos(cam_yaw))
	var spd: float = walker.velocity.length() if mode == "foot" else (plane.va if mode == "plane" else (absf(boat.v) if mode == "boat" else (train.v if mode == "train" else car.linear_velocity.length())))
	var dist: float = (float(plane.spec.len) * 1.15 if mode == "plane" else (26.0 if mode == "train" else (13.0 if mode == "boat" else ((4.2 if mode == "foot" else 7.0) if cam_mode == 0 else 12.5)))) + spd * 0.04
	var height: float = (float(plane.spec.len) * 0.22 if mode == "plane" else (8.0 if mode == "train" else (4.0 if mode == "boat" else ((1.9 if mode == "foot" else 2.4) if cam_mode == 0 else 4.4)))) + spd * 0.01
	var pivot: Vector3 = tn.global_position + Vector3(0, 1.3, 0)
	var target: Vector3 = tn.global_position - back * dist + Vector3(0, height, 0)
	var q := PhysicsRayQueryParameters3D.create(pivot, target)
	q.exclude = [car.get_rid(), walker.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		target = (hit.position as Vector3) + (pivot - target).normalized() * 0.4
	cam.global_position = cam.global_position.lerp(target, minf(1.0, delta * 9.0))
	cam.look_at(tn.global_position + back * 4.0 + Vector3(0, 1.1, 0))
	cam.fov = 65.0 + clampf(spd / 55.0, 0, 1) * 14.0
	if mode == "plane" and cam_mode == 1:
		cam.global_transform = plane.global_transform * Transform3D(Basis(Vector3.UP, PI), plane.cockpit_offset())
		cam.fov = 70.0
	if pfd != null:
		pfd.queue_redraw()

# ------------------------------------------------------------- interface
func _hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(24, 18)
	hud.add_theme_font_size_override("font_size", 28)
	hud.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_theme_constant_override("outline_size", 7)
	layer.add_child(hud)
	var help := Label.new()
	help.text = "↑↓ / W S : accélérer, freiner   ← → / A D : tourner   E : monter, descendre (voiture, avion, bateau, train)   Avion : Maj/Ctrl gaz, 1-5 volets, G train, P frein de parc, Espace freins, C cockpit   Espace : frein à main   R : redresser   C : caméra   T : accélérer le temps   Échap : pause"
	help.add_theme_font_size_override("font_size", 16)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	help.add_theme_constant_override("outline_size", 5)
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.position = Vector2(24, -40)
	help.visible = false
	layer.add_child(help)
	help_label = help
	pause_label = Label.new()
	pause_label.text = "PAUSE\nÉchap : reprendre   Q : quitter le jeu"
	pause_label.add_theme_font_size_override("font_size", 42)
	pause_label.add_theme_color_override("font_outline_color", Color.BLACK)
	pause_label.add_theme_constant_override("outline_size", 10)
	pause_label.position = Vector2(60, 120)
	pause_label.visible = false
	layer.add_child(pause_label)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if mode == "plane" and plane.key_press(event.physical_keycode):
			return
		match event.physical_keycode:
			KEY_R: car.reset_upright()
			KEY_E: _toggle_vehicle()
			KEY_F: _toggle_vehicle()
			KEY_C: cam_mode = (cam_mode + 1) % 2
			KEY_ESCAPE:
				get_tree().paused = not get_tree().paused
				help_label.visible = get_tree().paused
				pause_label.visible = get_tree().paused
			KEY_Q:
				if get_tree().paused:
					get_tree().quit()

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	frame += 1
	_update_sky(delta)
	_update_lamps(delta)
	_update_camera(delta)
	if mode == "car":
		engine.set_car(car.forward_speed(), car.throttle)
	elif mode == "plane":
		engine.kind = "jet"
		engine.n1 = plane.n1
	elif mode == "boat":
		engine.set_car(boat.v * 0.6, absf(boat.throttle))
	else:
		engine.kind = "none"
	var kmh: int = int(round(absf(car.forward_speed()) * 3.6))
	hud.text = "%d km/h   %02d:%02d   %d ips" % [kmh, int(hour), int(fmod(hour, 1.0) * 60.0), Engine.get_frames_per_second()]
	if test != "":
		_run_test()

# ------------------------------------------------------------- tests automatiques (SOLENA_TEST)
func _run_test() -> void:
	var t := frame
	if test.contains("aerial"):
		cam.global_position = Vector3(2600, 2600, 3600)
		cam.look_at(Vector3(-200, 0, 0))
		if t == 12:
			get_viewport().get_texture().get_image().save_png("/tmp/godot_%s.png" % test)
			print("SHOT aerial")
			get_tree().quit()
		return
	if test.contains("shot"):
		car.auto_input = {"gas": 1.0 if t > 5 else 0.0}
		if t == 20 or t == 45:
			get_viewport().get_texture().get_image().save_png("/tmp/godot_%s_%d.png" % [test, t])
			print("SHOT ", t, " t=", Time.get_ticks_msec())
		if t >= 45:
			get_tree().quit()
		return
	if t < 30:
		car.auto_input = {"gas": 0.0}
	elif t < 420:
		car.auto_input = {"gas": 1.0}
	elif t < 560:
		car.auto_input = {"gas": 1.0, "steer": 1.0}
	elif t < 700:
		car.auto_input = {"gas": 1.0, "steer": -1.0, "hand": t < 600}
	else:
		car.auto_input = {"brake": 1.0}
	if t % 60 == 0:
		var p: Vector3 = car.global_position
		var up: Vector3 = car.global_transform.basis.y
		print("phys_t=%.1fs TEST f=%d pos=(%.1f, %.2f, %.1f) v=%.1f km/h up.y=%.2f traffic_moving=%d" % [Engine.get_physics_frames() / 120.0, t, p.x, p.y, p.z, car.linear_velocity.length() * 3.6, up.y,
			traffic.cars.filter(func(c): return c.body.linear_velocity.length() > 3.0).size()])
		print("  crash=%d peds_visible=%d" % [traffic.cars.filter(func(c): return c.crash > 0.0).size(), peds.peds.filter(func(p): return p.root.visible).size()])
	if t >= 780:
		get_tree().quit()

# ------------------------------------------------------------- sortir, marcher, changer de véhicule
func _toggle_vehicle() -> void:
	if get_tree().paused:
		return
	if mode == "boat":
		if absf(boat.v) < 2.0 and boat.global_position.distance_to(boat.home.origin) < 90.0:
			boat.active = false
			walker.global_position = boat.dock
			walker.visible = true
			walker.active = true
			boat = null
			mode = "foot"
		return
	if mode == "train":
		if train.wait > 0.0:
			var c0: Node3D = train.cars[1]
			walker.global_position = c0.global_position + c0.global_transform.basis.x * 5.5 + Vector3(0, 1.5, 0)
			walker.visible = true
			walker.active = true
			mode = "foot"
		return
	if mode == "plane":
		if plane.on_ground and plane.va < 3.0:
			plane.active = false
			walker.global_position = plane.global_position + plane.global_transform.basis.x * (float(plane.spec.r) + 5.0) + Vector3(0, 0.5, 0)
			walker.visible = true
			walker.active = true
			plane = null
			mode = "foot"
		return
	if mode == "foot":
		for b in boats:
			if (b as Boat).global_position.distance_to(walker.global_position) < 55.0:
				boat = b
				boat.active = true
				walker.visible = false
				walker.active = false
				walker.global_position = Vector3(0, -50, 0)
				mode = "boat"
				return
		if train != null:
			for tc in train.cars:
				if (tc as Node3D).global_position.distance_to(walker.global_position) < 9.0:
					walker.visible = false
					walker.active = false
					walker.global_position = Vector3(0, -50, 0)
					mode = "train"
					return
		for pl in planes:
			if (pl as Aircraft).global_position.distance_to(walker.global_position) < float(pl.spec.len) * 0.45:
				plane = pl
				plane.active = true
				walker.visible = false
				walker.active = false
				walker.global_position = Vector3(0, -50, 0)
				mode = "plane"
				return
	if mode == "car":
		if car.linear_velocity.length() > 5.0:
			return
		car.active = false
		var side: Vector3 = -car.global_transform.basis.x
		walker.global_position = car.global_position + side * 1.9 + Vector3(0, 0.4, 0)
		walker.rotation.y = car.global_rotation.y
		walker.visible = true
		walker.active = true
		mode = "foot"
		return
	var best: Node3D = null
	var bd := 5.0
	for n in get_children():
		if n is PlayerCar and (n as Node3D).global_position.distance_to(walker.global_position) < bd:
			bd = (n as Node3D).global_position.distance_to(walker.global_position)
			best = n
	var steal := {}
	var steal_tr: Traffic = null
	for tr in all_traffic:
		for c in tr.cars:
			var d: float = (c.body as Node3D).global_position.distance_to(walker.global_position)
			if d < bd:
				bd = d
				best = null
				steal = c
				steal_tr = tr
	if best == null and steal.is_empty():
		return
	if best == null:
		var body: RigidBody3D = steal.body
		var nc := PlayerCar.new()
		nc.model = steal.model
		nc.paint = steal.get("color", Color(0.8, 0.8, 0.8))
		nc.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(nc)
		nc.global_transform = body.global_transform
		steal_tr.cars.erase(steal)
		body.queue_free()
		best = nc
	car = best as PlayerCar
	car.active = true
	for tr in all_traffic:
		tr.player = car
	for pd in all_peds:
		pd.player = car
	walker.visible = false
	walker.active = false
	walker.global_position = Vector3(0, -50, 0)
	mode = "car"

func _draw_pfd() -> void:
	if plane != null:
		plane.draw_pfd(pfd)
