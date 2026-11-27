class_name Music
extends Node
## Audio del juego: notas de tensión según la intensidad (alertas abiertas), alarma y fanfarrias.
## Sin música de fondo ni sonidos generados en tiempo real.

const RATE := 22050.0
const PENT := [110.0, 130.81, 146.83, 164.81, 196.0, 220.0, 261.63]

var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var master := .8
var music := .55
var sfx := .9
var intensity := 0.0
var enabled := true
var _ph1 := 0.0
var _ph2 := 0.0
var _lfo := 0.0
var _freq := 110.0
var _target := 110.0
var _ci := 0
var _chord_t := 0.0
var _arp_t := 0.0
var _lp := 0.0
var _plucks: Array = []   # [freq, t, dur, vol, phase]
var _cache := {}
var _sfx_players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = .25
	player = AudioStreamPlayer.new()
	player.bus = "Music"
	player.stream = gen
	add_child(player)
	# El generador en tiempo real ya no se reproduce (con FPS bajos sonaba con cortes y chasquidos).
	# Sin música de fondo (pedido del equipo): solo efectos y las notas de tensión de las alertas.
	for i in 4:
		var p := AudioStreamPlayer.new(); p.bus = "SFX"; add_child(p); _sfx_players.append(p)


func _process(dt: float) -> void:
	_chord_t += dt
	if _chord_t > 9:
		_chord_t = 0; _ci = (_ci + 1) % PENT.size(); _target = PENT[_ci]
	_arp_t += dt
	if _arp_t > .3:
		_arp_t = 0
		if intensity >= .15 and randf() >= .35:
			# notas de tensión como muestras cortas (no en tiempo real): sin cortes aunque bajen los FPS
			var ni := randi() % PENT.size()
			var key := "tension%d" % ni
			if not _cache.has(key): _play(key, _pluck_data(PENT[ni] * 4, .16, .03))
			else: _play(key, PackedVector2Array())
	_fill()


func _fill() -> void:
	if playback == null: return
	var n := playback.get_frames_available()
	var gain := master * music * .42 * (1.0 if enabled and not Game.muted else 0.0)
	for i in n:
		var s := 0.0
		for p in _plucks:
			if p[1] < p[2]:
				p[4] = fmod(p[4] + p[0] / RATE, 1.0)
				var tri: float = 1.0 - 4.0 * absf(p[4] - .5)
				s += tri * p[3] * pow(.0001 / maxf(p[3], .0002), p[1] / p[2]) * intensity * .9
				p[1] += 1.0 / RATE
		playback.push_frame(Vector2(s, s) * gain * 2.2)
	_plucks = _plucks.filter(func(p): return p[1] < p[2])


func _play(key: String, data: PackedVector2Array) -> void:
	if Game.muted: return
	var w: AudioStreamWAV = _cache.get(key)
	if w == null:
		w = AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = int(RATE); w.stereo = false
		var b := PackedByteArray(); b.resize(data.size() * 2)
		for i in data.size(): b.encode_s16(i * 2, int(clampf(data[i].x, -1, 1) * 32767))
		w.data = b
		_cache[key] = w
	for p in _sfx_players:
		if not p.playing:
			p.stream = w; p.volume_db = linear_to_db(maxf(.001, master * sfx)); p.play(); return


func step() -> void:
	var key := "step%d" % (randi() % 4)
	if not _cache.has(key):
		var n := int(RATE * .07)
		var d := PackedVector2Array(); d.resize(n)
		var bp := 0.0; var lp2 := 0.0
		var fq := 900.0 + randf() * 300
		for i in n:
			var x := randf() * 2 - 1
			lp2 += (x - lp2) * clampf(TAU * fq * 1.4 / RATE, 0, 1)
			bp += (lp2 - bp) * clampf(TAU * fq * .5 / RATE, 0, 1)
			d[i] = Vector2((lp2 - bp) * .05 * 9 * pow(.002, float(i) / n), 0)
		_play(key, d)
	else:
		_play(key, PackedVector2Array())


func _pluck_data(f: float, dur: float, vol: float) -> PackedVector2Array:
	var n := int(RATE * dur)
	var d := PackedVector2Array(); d.resize(n)
	var ph := 0.0
	for i in n:
		ph = fmod(ph + f / RATE, 1.0)
		d[i] = Vector2((1.0 - 4.0 * absf(ph - .5)) * vol * 4 * pow(.0001 / vol, float(i) / n), 0)
	return d


func alarm() -> void:
	var a := _pluck_data(196, .4, .12)
	var b := _pluck_data(147, .5, .12)
	var off := int(RATE * .16)
	var d := PackedVector2Array(); d.resize(off + b.size())
	for i in a.size(): d[i] += a[i]
	for i in b.size(): d[off + i] += b[i]
	_play("alarm", d)


func sting(good: bool) -> void:
	var fs := [523, 659, 784, 1047] if good else [392, 330, 262, 196]
	var step_n := int(RATE * .14)
	var d := PackedVector2Array(); d.resize(step_n * 3 + int(RATE * .35))
	for k in 4:
		var p := _pluck_data(fs[k], .35, .09)
		for i in p.size(): d[k * step_n + i] += p[i]
	_play("sting%s" % good, d)


func ui() -> void:
	_play("ui", _pluck_data(720, .06, .035))
