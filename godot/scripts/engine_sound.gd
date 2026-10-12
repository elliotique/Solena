class_name EngineSound
extends AudioStreamPlayer
## Son de moteur synthétisé en direct (aucun fichier audio) :
## voiture = régime qui monte et redescend à chaque rapport (dents de scie + grondement + souffle) ;
## avion = sifflement de turbine + souffle des réacteurs, selon le régime N1.

var kind := "car"          # "car", "jet" ou "none"
var rpm := 900.0           # voiture : tours/minute
var load := 0.0            # voiture : accélérateur 0..1
var n1 := 0.0              # avion : régime 0..1
var _pb: AudioStreamGeneratorPlayback
var _ph := 0.0
var _ph2 := 0.0
var _lp := 0.0
var _lp2 := 0.0
var _vol := 0.0
var _rng := RandomNumberGenerator.new()
const RATE := 22050.0

func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.12
	stream = gen
	volume_db = -6.0
	process_mode = Node.PROCESS_MODE_ALWAYS
	play()
	_pb = get_stream_playback()

func _process(_delta: float) -> void:
	if _pb == null:
		return
	var paused := get_tree().paused
	var frames := _pb.get_frames_available()
	var target_vol := 0.0 if (kind == "none" or paused) else 1.0
	for i in frames:
		_vol += (target_vol - _vol) * 0.0008
		var s := 0.0
		if kind == "jet":
			var f := 180.0 + n1 * 520.0
			_ph = fmod(_ph + f / RATE, 1.0)
			var whine := sin(_ph * TAU) * (0.06 + n1 * 0.12)
			var nz := _rng.randf_range(-1.0, 1.0)
			_lp += (nz - _lp) * (0.05 + n1 * 0.25)
			s = whine + _lp * (0.25 + n1 * 0.9)
		else:
			# moteur 4 cylindres : 2 explosions par tour
			var f2 := rpm / 60.0 * 2.0
			_ph = fmod(_ph + f2 / RATE, 1.0)
			_ph2 = fmod(_ph2 + f2 * 0.5 / RATE, 1.0)
			var saw := _ph * 2.0 - 1.0
			var thump := sin(_ph2 * TAU)
			var raw := saw * (0.35 + load * 0.35) + thump * 0.45
			_lp += (raw - _lp) * clampf(0.08 + rpm / 9000.0, 0.08, 0.6)
			var nz2 := _rng.randf_range(-1.0, 1.0)
			_lp2 += (nz2 - _lp2) * 0.15
			s = _lp * 0.55 + _lp2 * 0.08 * (0.3 + load)
		s *= _vol
		_pb.push_frame(Vector2(s, s))

## Régime de la voiture à partir de sa vitesse (boîte automatique à 6 rapports)
func set_car(speed_ms: float, throttle: float) -> void:
	kind = "car"
	var kmh := absf(speed_ms) * 3.6
	var gears := [0.0, 30.0, 55.0, 85.0, 120.0, 160.0, 400.0]
	var g := 1
	while g < gears.size() - 1 and kmh > gears[g]:
		g += 1
	var lo: float = gears[g - 1]
	var hi: float = gears[g]
	var t := clampf((kmh - lo) / maxf(hi - lo, 1.0), 0.0, 1.0)
	var target := 900.0 + t * 5200.0 + throttle * 600.0
	if kmh < 3.0:
		target = 850.0 + throttle * 2200.0
	rpm += (target - rpm) * 0.12
	load += (throttle - load) * 0.1
