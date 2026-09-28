extends Node3D
## Solena (Godot) : construit le monde, gère la caméra, le cycle jour/nuit, l'éclairage urbain et l'interface.

const DAY_SECONDS := 540.0

var world: World
var car: PlayerCar
var cam: Camera3D
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var hud: Label
var hour := 17.2
var night := 0.0
var cam_yaw := 0.0
var cam_mode := 0
var lamp_pool: Array[OmniLight3D] = []
var lamp_t := 0.0
var test := ""
var frame := 0

func _ready() -> void:
	test = OS.get_environment("SOLENA_TEST")
	if test.begins_with("night"):
		hour = 22.5
	_environment()
	world = World.new()
	add_child(world)
	world.build()
	car = PlayerCar.new()
	add_child(car)
	car.global_transform = Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(-300, 0.6, 2.5))
	cam = Camera3D.new()
	cam.fov = 65
	cam.far = 4000
	add_child(cam)
	cam_yaw = car.global_rotation.y
	cam.global_position = car.global_position + Vector3(0, 3, -8)
	for k in 14:
		var l := OmniLight3D.new()
		l.light_color = Color(1, 0.82, 0.55)
		l.omni_range = 20.0
		l.omni_attenuation = 1.2
		l.light_energy = 0.0
		l.shadow_enabled = false
		add_child(l)
		lamp_pool.append(l)
	_hud()

# ------------------------------------------------------------- ambiance
func _environment() -> void:
	sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.55
	env.ambient_light_color = Color(0.62, 0.62, 0.6)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.2
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 1.6
	env.ssil_enabled = false
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.8, 0.9)
	env.fog_density = 0.0006
	env.fog_sky_affect = 0.3
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 260.0
	sun.light_angular_distance = 0.5
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.light_energy = 0.0
	moon.rotation_degrees = Vector3(-55, -40, 0)
	add_child(moon)

func _update_sky(delta: float) -> void:
	var speed := 40.0 if Input.is_physical_key_pressed(KEY_T) else 1.0
	hour = fmod(hour + delta * 24.0 / DAY_SECONDS * speed, 24.0)
	var ang := (hour - 6.0) / 12.0 * PI            # 0 au lever, PI au coucher
	var elev := sin(ang)
	sun.rotation = Vector3(-maxf(elev, -0.2) * 1.2 - 0.05, -ang + PI / 2.0, 0)
	var day := smoothstep(-0.08, 0.3, elev)
	var dusk := clampf(1.0 - absf(elev + 0.02) / 0.3, 0.0, 1.0)
	night = 1.0 - smoothstep(-0.05, 0.12, elev)
	sun.light_energy = 1.4 * day
	sun.light_color = Color(1, 0.95, 0.88).lerp(Color(1, 0.55, 0.3), dusk)
	sun.visible = day > 0.01
	moon.light_energy = 0.25 * night
	sky_mat.sky_top_color = Color(0.03, 0.05, 0.14).lerp(Color(0.22, 0.45, 0.85), day).lerp(Color(0.3, 0.25, 0.55), dusk * 0.5)
	sky_mat.sky_horizon_color = Color(0.1, 0.1, 0.25).lerp(Color(0.72, 0.84, 0.95), day).lerp(Color(1.0, 0.55, 0.4), dusk * 0.8)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color = Color(0.1, 0.12, 0.1)
	env.ambient_light_energy = 0.35 + 0.65 * day
	env.fog_light_color = sky_mat.sky_horizon_color
	for m in world.window_mats:
		m.emission_energy_multiplier = night * 2.2
	for m in world.shop_mats:
		m.emission_energy_multiplier = 0.15 + night * 1.0
	world.lamp_mat.emission_energy_multiplier = 0.2 + night * 6.0
	car.head_lights.emission_energy_multiplier = 1.0 + night * 5.0
	car.head_spot.light_energy = night * 6.0

func _update_lamps(delta: float) -> void:
	# les lampadaires les plus proches deviennent de vraies lumières
	lamp_t -= delta
	if lamp_t > 0.0:
		return
	lamp_t = 0.3
	var p: Vector3 = car.global_position
	var near: Array[Vector3] = world.lamp_heads.duplicate()
	near.sort_custom(func(a, b): return a.distance_squared_to(p) < b.distance_squared_to(p))
	for k in lamp_pool.size():
		var l := lamp_pool[k]
		if k < near.size() and night > 0.05:
			l.global_position = near[k] - Vector3(0, 0.4, 0)
			l.light_energy = 3.5 * night
			l.visible = true
		else:
			l.visible = false

# ------------------------------------------------------------- caméra
func _update_camera(delta: float) -> void:
	var yaw: float = car.global_rotation.y
	cam_yaw = lerp_angle(cam_yaw, yaw, minf(1.0, delta * 3.5))
	var back := Vector3(sin(cam_yaw), 0, cos(cam_yaw))       # avant de la voiture = +Z
	var spd: float = car.linear_velocity.length()
	var dist: float = (7.5 if cam_mode == 0 else 13.0) + spd * 0.04
	var height: float = (2.6 if cam_mode == 0 else 4.5) + spd * 0.01
	var target: Vector3 = car.global_position - back * dist + Vector3(0, height, 0)
	cam.global_position = cam.global_position.lerp(target, minf(1.0, delta * 8.0))
	cam.look_at(car.global_position + back * 4.0 + Vector3(0, 1.2, 0))
	cam.fov = 65.0 + clampf(spd / 55.0, 0, 1) * 14.0

# ------------------------------------------------------------- interface
func _hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(24, 18)
	hud.add_theme_font_size_override("font_size", 26)
	hud.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_theme_constant_override("outline_size", 6)
	layer.add_child(hud)
	var help := Label.new()
	help.text = "↑↓ ou W/S : accélérer, freiner   ← → ou A/D : tourner   Espace : frein à main   R : redresser   C : caméra   T : accélérer le temps"
	help.add_theme_font_size_override("font_size", 16)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	help.add_theme_constant_override("outline_size", 5)
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.position = Vector2(24, -40)
	layer.add_child(help)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R: car.reset_upright()
			KEY_C: cam_mode = (cam_mode + 1) % 2
			KEY_ESCAPE: get_tree().quit()

func _process(delta: float) -> void:
	frame += 1
	_update_sky(delta)
	_update_lamps(delta)
	_update_camera(delta)
	var kmh: int = int(round(absf(car.forward_speed()) * 3.6))
	hud.text = "%d km/h   %02d:%02d" % [kmh, int(hour), int(fmod(hour, 1.0) * 60.0)]
	if test != "":
		_run_test()

# ------------------------------------------------------------- tests automatiques (SOLENA_TEST)
func _run_test() -> void:
	var t := frame
	if test.ends_with("shot"):
		car.auto_input = {"gas": 1.0 if t > 5 else 0.0}
		if t == 25 or t == 60:
			get_viewport().get_texture().get_image().save_png("/tmp/godot_%s_%d.png" % [test, t])
			print("SHOT ", t, " t=", Time.get_ticks_msec())
		if t >= 60:
			get_tree().quit()
		return
	if t < 30:
		car.auto_input = {"gas": 0.0}
	elif t < 300:
		car.auto_input = {"gas": 1.0}
	elif t < 420:
		car.auto_input = {"gas": 0.6, "steer": 1.0}
	else:
		car.auto_input = {"brake": 1.0}
	if t % 60 == 0:
		var p: Vector3 = car.global_position
		print("TEST ms=%d f=%d pos=(%.1f, %.2f, %.1f) v=%.1f km/h fwd=%.2f yaw=%.2f" % [Time.get_ticks_msec(), t, p.x, p.y, p.z, car.linear_velocity.length() * 3.6, car.forward_speed(), car.global_rotation.y])
	if t == 200 or t == 400:
		get_viewport().get_texture().get_image().save_png("/tmp/godot_%s_%d.png" % [test, t])
	if t >= 520:
		get_tree().quit()
