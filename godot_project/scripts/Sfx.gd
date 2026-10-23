extends Node
## Sfx.gd — 与 HTML 原型 Web Audio 程序化合成等价的最小 Godot 音效层。
## 不依赖任何外部音频资产：启动时用正弦 / 噪声 + 指数包络离线烘焙成 AudioStreamWAV。
## HTML 的 beep / can / wedge / akm / bonejam / thirst 六种音色在此一一对应。

const RATE := 22050
const VOICE_COUNT := 8

var muted := false
var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _next: int = 0

func _ready() -> void:
	for i in VOICE_COUNT:
		var p := AudioStreamPlayer.new()
		p.volume_db = -5.0
		add_child(p)
		_players.append(p)
	_build_streams()

func set_muted(value: bool) -> void:
	muted = value

func play(name: String) -> void:
	if muted or not _streams.has(name) or _players.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.play()

# ----------------------------------------------------------------------------
# 合成
# ----------------------------------------------------------------------------
func _build_streams() -> void:
	_streams["beep"] = _tone(880.0, 0.08, 32.0, 0.0, 0.0, 0.30)
	_streams["can"] = _triad([520.0, 780.0, 610.0], 0.055, 42.0)
	_streams["wedge"] = _tone(150.0, 0.20, 16.0, 0.35, -80.0, 0.42)
	_streams["akm"] = _tone(95.0, 0.16, 24.0, 0.88, -40.0, 0.50)
	_streams["bonejam"] = _tone(68.0, 0.32, 9.0, 0.55, 20.0, 0.55)
	_streams["thirst"] = _whisper(0.55)

func _tone(freq: float, dur: float, decay: float, noise_mix: float,
		sweep: float, amp: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedFloat32Array()
	data.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq * 131.0) + n
	var phase := 0.0
	for i in n:
		var t := float(i) / float(RATE)
		var env: float = exp(-t * decay)
		phase += TAU * (freq + sweep * t) / float(RATE)
		var s := sin(phase)
		if noise_mix > 0.0:
			s = lerpf(s, rng.randf_range(-1.0, 1.0), noise_mix)
		data[i] = s * env * amp
	return _wav(data)

func _triad(freqs: Array, each: float, decay: float) -> AudioStreamWAV:
	var per := int(each * RATE)
	var n := per * freqs.size()
	var data := PackedFloat32Array()
	data.resize(n)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7717
	for k in freqs.size():
		var f: float = float(freqs[k])
		for i in per:
			var idx := k * per + i
			var t := float(i) / float(RATE)
			phase += TAU * f / float(RATE)
			var env: float = exp(-t * decay)
			var s := lerpf(sin(phase), rng.randf_range(-1.0, 1.0), 0.18)
			data[idx] = s * env * 0.30
	return _wav(data)

func _whisper(dur: float) -> AudioStreamWAV:
	# 瓦西里临终气音“……Пить……”：带通感噪声 + 缓慢包络 + 低频共振
	var n := int(dur * RATE)
	var data := PackedFloat32Array()
	data.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var lp := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / float(RATE)
		var env: float = sin(PI * clampf(t / dur, 0.0, 1.0))
		env *= env
		var white := rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, white, 0.12)
		phase += TAU * (180.0 + 40.0 * sin(t * 9.0)) / float(RATE)
		var s := lp * 0.75 + sin(phase) * 0.25
		data[i] = s * env * 0.22
	return _wav(data)

func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	return s
