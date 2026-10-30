extends Node
## NightSfx.gd — 节点化夜潜场景的程序化音效层（P2.5「声音」+ 战役模式音频接线）。
##
## 与 scripts/Sfx.gd 同一套做法：不依赖外部音频资产，_ready() 时用正弦 / 噪声 + 包络离线烘焙成
## AudioStreamWAV。差别是本层面向 2.5D 世界，声音要能「闭眼定位」：
##   * play(name)                  —— 界面 / 结局等不定位的音色（配方与 Sfx.gd 一致，旧调用点不用改）
##   * play_at(name, pos)          —— 一次性音效走 AudioStreamPlayer2D，按 RADIUS_M 衰减
##   * attach_loop(node, name, r)  —— 挂在实体上的循环声（清杀兵面具呼吸：4 米内才听得见 = 潜行提示）
##   * register_ambient(p, role)   —— 接管场景里的 AMB_* 环境层：风雪随 cfg.cold 变强、天亮退去
##   * set_tension(k)              —— 紧张度（清杀兵警戒 / 狂暴者追击）驱动心跳
## 音色配方对齐《下一阶段开发规划》P2.5：面具呼吸、狂暴者低吼与扑咬、半人呻吟、
## 雪地 / 冰面 / 铁轨三种脚步、撬棍挥击与闷响；环境循环仍由 tools/art_gen 的 gen_vfx 出 WAV。
## 说明（与 P2.5 的偏差）：一次性音色改在运行时合成，不进 art/ —— 这样 headless 测试不必先跑导入，
## 而且每个实例可以带 ±5% 音高抖动；AMB_* 环境循环仍走管线，保持「美术走管线」的口径。

const RATE := 22050
const PPM := 64.0                # 1 逻辑米 = 64 px（AudioStreamPlayer2D 的距离单位是像素）
const POS_VOICES := 12
const FLAT_VOICES := 6

## 每种音色的可闻半径（米）→ AudioStreamPlayer2D.max_distance
const RADIUS_M := {
	"step_snow": 13.0, "step_ice": 17.0, "step_rail": 19.0,
	"growl": 20.0, "snarl": 22.0, "bite": 15.0,
	"moan": 15.0, "radio": 22.0, "klaxon": 44.0, "mask_breath": 4.0,
	"gunshot": 48.0, "akm": 48.0,
	"swing": 11.0, "crowbar_hit": 17.0, "rummage": 11.0,
	"can_throw": 13.0, "can": 28.0,
	"bonejam": 17.0, "dawn_horn": 120.0, "freeze": 80.0, "chill": 40.0,
	"beep": 40.0, "wedge": 22.0, "thirst": 40.0, "heartbeat": 8.0,
}

# 烘焙结果跨实例复用：测试里反复 instantiate 场景时不必每次重合成 ~16 秒音频。
static var CACHE: Dictionary = {}

var muted := false
var tension := 0.0               # 0..1：心跳的驱动量（NightExplore._tension）
var cold := 1.0                  # 战役 cfg.cold：风雪强度
var dawn := 0.0                  # 0..1：天亮进度（风声退去）

var _streams: Dictionary = {}
var _pos: Array[AudioStreamPlayer2D] = []
var _flat: Array[AudioStreamPlayer] = []
var _ambient: Array = []         # [AudioStreamPlayer/2D, role, base_db]
var _next_pos := 0
var _next_flat := 0
var _beat := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if CACHE.is_empty():
		_build_streams()
	_streams = CACHE
	for i in POS_VOICES:
		var p := AudioStreamPlayer2D.new()
		p.max_distance = 1200.0
		add_child(p)
		_pos.append(p)
	for i in FLAT_VOICES:
		var q := AudioStreamPlayer.new()
		q.volume_db = -5.0
		add_child(q)
		_flat.append(q)


func _process(delta: float) -> void:
	_mix_ambient()
	if muted or tension <= 0.22:
		_beat = 0.0
		return
	_beat -= delta
	if _beat <= 0.0:
		var k := clampf((tension - 0.22) / 0.78, 0.0, 1.0)
		_beat = lerpf(1.2, 0.5, k)
		play("heartbeat", lerpf(-17.0, -3.0, k))


# ============================================================================
# 对外 API
# ============================================================================
func has_stream(sname: String) -> bool:
	return _streams.has(sname)


func stream_count() -> int:
	return _streams.size()


func set_muted(value: bool) -> void:
	muted = value


func set_tension(k: float) -> void:
	tension = clampf(k, 0.0, 1.0)


func set_cold(value: float) -> void:
	cold = clampf(value, 0.2, 2.0)


func set_dawn(value: float) -> void:
	dawn = clampf(value, 0.0, 1.0)


## 不定位的一次性音色（界面、结局、玩家自己的动作）。
func play(sname: String, db := 0.0, jitter := 0.0) -> void:
	if muted or not _streams.has(sname) or _flat.is_empty():
		return
	var p := _flat[_next_flat]
	_next_flat = (_next_flat + 1) % _flat.size()
	p.stream = _streams[sname]
	p.volume_db = db - 5.0
	p.pitch_scale = 1.0 + _rng.randf_range(-jitter, jitter)
	p.play()


## 世界坐标里的一次性音色：距离衰减 + 音高抖动，让「谁在哪」能靠耳朵判断。
func play_at(sname: String, pos: Vector2, db := 0.0, jitter := 0.05) -> void:
	if muted or not _streams.has(sname) or _pos.is_empty():
		return
	var p := _pos[_next_pos]
	_next_pos = (_next_pos + 1) % _pos.size()
	p.stream = _streams[sname]
	p.global_position = pos
	p.volume_db = db
	p.pitch_scale = 1.0 + _rng.randf_range(-jitter, jitter)
	p.max_distance = float(RADIUS_M.get(sname, 18.0)) * PPM
	p.play()


## 挂在实体上的循环声（跟着它走）。radius_m = 多远以外就听不见。
func attach_loop(target: Node2D, sname: String, radius_m: float, db := -6.0) -> AudioStreamPlayer2D:
	if target == null or not _streams.has(sname):
		return null
	var p := AudioStreamPlayer2D.new()
	p.name = "Loop_" + sname
	p.stream = _streams[sname]
	p.max_distance = radius_m * PPM
	p.volume_db = db
	p.position = Vector2(0, -18)          # 面具在头的高度
	target.add_child(p)
	p.play()
	return p


## 接管场景里的 AMB_* 环境层。role：wind / fire / steam / lamp（其他名字按中性处理）。
func register_ambient(p: Node, role: String = "") -> void:
	if p == null or not p.has_method("play"):
		return
	for a in _ambient:
		if a[0] == p:
			return
	_ambient.append([p, role, float(p.get("volume_db"))])


func ambient_count() -> int:
	return _ambient.size()


func _mix_ambient() -> void:
	for a in _ambient:
		var p = a[0]                 # AudioStreamPlayer 或 AudioStreamPlayer2D（没有共同的 volume_db 基类）
		var role: String = a[1]
		var base: float = a[2]
		var db := base
		match role:
			"wind":
				# 战役的 cfg.cold 越大风越猛；天亮风雪退去
				db = base + clampf(cold - 1.0, -0.6, 0.9) * 7.0 - dawn * 9.0
			"fire", "steam":
				db = base - dawn * 2.5
		p.set("volume_db", db)


# ============================================================================
# 合成：通用工具
# ============================================================================
func _buf(sec: float) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	d.resize(int(sec * RATE))
	return d


func _lowpass(d: PackedFloat32Array, cutoff: float) -> void:
	var a := 1.0 - exp(-TAU * clampf(cutoff, 20.0, RATE * 0.45) / float(RATE))
	var acc := 0.0
	for i in d.size():
		acc += a * (d[i] - acc)
		d[i] = acc


func _bandpass(d: PackedFloat32Array, lo: float, hi: float) -> void:
	## 两个一阶低通相减 = 廉价的带通（面具滤芯 / 铁轨金属味的来源）
	var a1 := 1.0 - exp(-TAU * clampf(hi, 20.0, RATE * 0.45) / float(RATE))
	var a2 := 1.0 - exp(-TAU * clampf(lo, 20.0, RATE * 0.45) / float(RATE))
	var f := 0.0
	var s := 0.0
	for i in d.size():
		var x := d[i]
		f += a1 * (x - f)
		s += a2 * (x - s)
		d[i] = f - s


## 起 / 落包络（k = 0..1）：atk、rel 为占时长的比例。
func _env_ar(k: float, atk: float, rel: float) -> float:
	return minf(smoothstep(0.0, maxf(0.001, atk), k), smoothstep(0.0, maxf(0.001, rel), 1.0 - k))


func _sine_ring(d: PackedFloat32Array, freqs: Array, decay: float, amp: float, at := 0.0) -> void:
	var i0 := int(at * RATE)
	for f in freqs:
		var fr := float(f)
		var phase := 0.0
		for i in range(i0, d.size()):
			var t := float(i - i0) / float(RATE)
			phase += TAU * fr / float(RATE)
			d[i] += sin(phase) * exp(-t * decay) * amp


func _noise(d: PackedFloat32Array, rng: RandomNumberGenerator, amp: float, at := 0.0) -> void:
	for i in range(int(at * RATE), d.size()):
		d[i] += rng.randf_range(-amp, amp)


func _wav(d: PackedFloat32Array, loop := false, gain := 1.0) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(d.size() * 2)
	for i in d.size():
		bytes.encode_s16(i * 2, int(clampf(d[i] * gain, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = d.size()
	return s


# ============================================================================
# 合成：音色库
# ============================================================================
func _build_streams() -> void:
	# —— 与 Sfx.gd 同配方的六种旧音色（保证 NightExplore 里已有的调用点手感不变）——
	CACHE["beep"] = _tone(880.0, 0.08, 32.0, 0.0, 0.0, 0.30)
	CACHE["can"] = _triad([520.0, 780.0, 610.0], 0.055, 42.0)
	CACHE["wedge"] = _tone(150.0, 0.20, 16.0, 0.35, -80.0, 0.42)
	CACHE["akm"] = _tone(95.0, 0.16, 24.0, 0.88, -40.0, 0.50)
	CACHE["bonejam"] = _tone(68.0, 0.32, 9.0, 0.55, 20.0, 0.55)
	CACHE["thirst"] = _whisper(0.55)
	# —— 脚步：雪地 / 冰面 / 铁轨（P2.5 三种地面）——
	CACHE["step_snow"] = _step_snow()
	CACHE["step_ice"] = _step_ice()
	CACHE["step_rail"] = _step_rail()
	# —— 狂暴者：低吼（游荡）/ 嘶吼（追击起跳）/ 扑咬 ——
	CACHE["growl"] = _growl(0.75, 64.0, 46.0, 0.30, 900.0, 0.44, 31337)
	CACHE["snarl"] = _growl(0.46, 122.0, 78.0, 0.52, 1900.0, 0.55, 4241)
	CACHE["bite"] = _bite()
	# —— 半人：呻吟 ——
	CACHE["moan"] = _moan()
	# —— 清杀队：面具呼吸（循环，attach_loop 时 4 米内可闻）/ 电台 / 警报 ——
	CACHE["mask_breath"] = _mask_breath()
	CACHE["radio"] = _radio()
	CACHE["klaxon"] = _klaxon()
	CACHE["gunshot"] = _gunshot()
	# —— P5 战斗：步枪 / 双管 / 空仓 / 装填（撬棍的挥击与闷响上面已经有了）——
	CACHE["rifle_shot"] = _rifle_shot()
	CACHE["shotgun_shot"] = _shotgun_shot()
	CACHE["click"] = _tone(1500.0, 0.045, 70.0, 0.25, -260.0, 0.22)
	CACHE["reload"] = _reload()
	# —— 撬棍：挥击 / 闷响（P2.3 近战会复用；现在给「灭口」抉择用）——
	CACHE["swing"] = _swing()
	CACHE["crowbar_hit"] = _crowbar_hit()
	CACHE["rummage"] = _rummage()
	CACHE["can_throw"] = _can_throw()
	# —— 战役节拍：天亮号角 / 失温 / 心跳 ——
	CACHE["dawn_horn"] = _dawn_horn()
	CACHE["freeze"] = _freeze()
	CACHE["chill"] = _chill()
	CACHE["heartbeat"] = _heartbeat()


func _tone(freq: float, dur: float, decay: float, noise_mix: float,
		sweep: float, amp: float) -> AudioStreamWAV:
	var d := _buf(dur)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq * 131.0) + d.size()
	var phase := 0.0
	for i in d.size():
		var t := float(i) / float(RATE)
		phase += TAU * (freq + sweep * t) / float(RATE)
		var s := sin(phase)
		if noise_mix > 0.0:
			s = lerpf(s, rng.randf_range(-1.0, 1.0), noise_mix)
		d[i] = s * exp(-t * decay) * amp
	return _wav(d)


func _triad(freqs: Array, each: float, decay: float) -> AudioStreamWAV:
	var d := PackedFloat32Array()
	d.resize(int(each * RATE) * freqs.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = 7717
	var per := int(each * RATE)
	for k in freqs.size():
		var f := float(freqs[k])
		var phase := 0.0
		for i in per:
			var t := float(i) / float(RATE)
			phase += TAU * f / float(RATE)
			var s := lerpf(sin(phase), rng.randf_range(-1.0, 1.0), 0.18)
			d[k * per + i] = s * exp(-t * decay) * 0.30
	return _wav(d)


func _whisper(dur: float) -> AudioStreamWAV:
	# 瓦西里临终气音「……Пить……」：带通感噪声 + 缓慢包络 + 低频共振
	var d := _buf(dur)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var lp := 0.0
	var phase := 0.0
	for i in d.size():
		var t := float(i) / float(RATE)
		var env := sin(PI * clampf(t / dur, 0.0, 1.0))
		env *= env
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.12)
		phase += TAU * (180.0 + 40.0 * sin(t * 9.0)) / float(RATE)
		d[i] = (lp * 0.75 + sin(phase) * 0.25) * env * 0.22
	return _wav(d)


func _step_snow() -> AudioStreamWAV:
	var d := _buf(0.15)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1201
	_noise(d, rng, 0.55)
	_lowpass(d, 1650.0)
	for i in d.size():
		var t := float(i) / float(RATE)
		d[i] *= exp(-t * 30.0)
	# 雪粒挤压的三下脆响
	for k in 3:
		var at := 0.012 + 0.02 * float(k) + rng.randf() * 0.012
		var i0 := int(at * RATE)
		for i in range(i0, mini(i0 + 220, d.size())):
			d[i] += rng.randf_range(-0.35, 0.35) * exp(-float(i - i0) / 40.0)
	return _wav(d)


func _step_ice() -> AudioStreamWAV:
	var d := _buf(0.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1202
	_noise(d, rng, 0.6)
	_bandpass(d, 900.0, 5200.0)
	for i in d.size():
		var t := float(i) / float(RATE)
		d[i] *= exp(-t * 46.0)
	_sine_ring(d, [2450.0, 3720.0], 34.0, 0.18)
	return _wav(d)


func _step_rail() -> AudioStreamWAV:
	var d := _buf(0.24)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1203
	_noise(d, rng, 0.5)
	_lowpass(d, 2400.0)
	for i in d.size():
		var t := float(i) / float(RATE)
		d[i] *= exp(-t * 34.0)
	# 枕木与钢轨的金属回响
	_sine_ring(d, [1180.0, 1770.0, 2360.0], 17.0, 0.13)
	return _wav(d)


func _growl(dur: float, f0: float, f1: float, noise_mix: float, cutoff: float,
		amp: float, sd: int) -> AudioStreamWAV:
	var d := _buf(dur)
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var phase := 0.0
	for i in d.size():
		var k := float(i) / float(d.size())
		var t := float(i) / float(RATE)
		var f := lerpf(f0, f1, k) * (1.0 + 0.05 * sin(TAU * 6.3 * t))
		phase += TAU * f / float(RATE)
		# 高烧烧坏的嗓子：基频 + 两三次谐波，混一点粗糙噪声
		var s := sin(phase) + 0.42 * sin(2.0 * phase) + 0.2 * sin(3.0 * phase + 0.6)
		s = lerpf(s, rng.randf_range(-1.0, 1.0), noise_mix)
		d[i] = s * _env_ar(k, 0.14, 0.4) * amp
	_lowpass(d, cutoff)
	return _wav(d)


func _bite() -> AudioStreamWAV:
	var d := _buf(0.3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1301
	_noise(d, rng, 0.7)
	_bandpass(d, 300.0, 2600.0)
	for i in d.size():
		var t := float(i) / float(RATE)
		d[i] *= exp(-t * 26.0)
	_sine_ring(d, [86.0, 132.0], 20.0, 0.4)
	return _wav(d, false, 0.85)


func _moan() -> AudioStreamWAV:
	var dur := 1.15
	var d := _buf(dur)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1401
	var phase := 0.0
	var lp := 0.0
	for i in d.size():
		var k := float(i) / float(d.size())
		var t := float(i) / float(RATE)
		# 退烧中的呻吟：220 → 165 Hz，4.7 Hz 抖，气声很重
		var f := lerpf(220.0, 165.0, k) * (1.0 + 0.035 * sin(TAU * 4.7 * t))
		phase += TAU * f / float(RATE)
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.09)
		var s := lerpf(sin(phase) * 0.7 + sin(2.0 * phase) * 0.18, lp, 0.42)
		d[i] = s * _env_ar(k, 0.24, 0.42) * 0.45
	_lowpass(d, 1500.0)
	return _wav(d)


func _mask_breath() -> AudioStreamWAV:
	## 3.0 秒 = 两个 1.5 秒呼吸周期，循环点无缝。吸气 0.32s 处、呼气 1.02s 处，阀门在两周期交界咔哒。
	var dur := 3.0
	var d := _buf(dur)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var fast := 0.0
	var slow := 0.0
	for i in d.size():
		var t := float(i) / float(RATE)
		var ph := fmod(t, 1.5)
		var inhale := exp(-pow((ph - 0.32) / 0.19, 2.0))
		var exhale := exp(-pow((ph - 1.02) / 0.26, 2.0)) * 0.8
		var w := rng.randf_range(-1.0, 1.0)
		fast = lerpf(fast, w, 0.40)       # ~1800 Hz
		slow = lerpf(slow, w, 0.133)      # ~500 Hz
		var band := (fast - slow) * 1.5   # 500–1800 Hz：面具滤芯的呼吸带
		var s := band * (inhale + exhale)
		# 阀门咔哒
		var click := exp(-pow(ph / 0.008, 2.0)) + exp(-pow((ph - 0.74) / 0.01, 2.0)) * 0.6
		s += click * w * 0.22
		d[i] = s * 0.42
	return _wav(d, true)


func _radio() -> AudioStreamWAV:
	var d := _buf(0.34)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1501
	_noise(d, rng, 0.4)
	_bandpass(d, 1200.0, 3600.0)
	for i in d.size():
		var t := float(i) / float(RATE)
		d[i] *= exp(-t * 9.0) * 0.6
	_sine_ring(d, [1880.0], 26.0, 0.22, 0.01)
	_sine_ring(d, [1420.0], 22.0, 0.16, 0.12)
	return _wav(d)


func _klaxon() -> AudioStreamWAV:
	var d := _buf(0.95)
	var phase := 0.0
	for i in d.size():
		var t := float(i) / float(RATE)
		var f := 620.0 if fmod(t, 0.5) < 0.25 else 492.0
		phase += TAU * f / float(RATE)
		var s := signf(sin(phase)) * 0.55 + sin(phase) * 0.45
		d[i] = s * _env_ar(t / 0.95, 0.03, 0.18) * 0.34
	_lowpass(d, 2600.0)
	return _wav(d)


func _gunshot() -> AudioStreamWAV:
	var d := _buf(0.34)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1601
	_noise(d, rng, 0.72)
	for i in d.size():
		var t := float(i) / float(RATE)
		d[i] *= exp(-t * 62.0)                    # 脆裂的枪口冲击
	_sine_ring(d, [96.0, 148.0], 26.0, 0.4)       # 胸腔那一下
	var tail := _buf(0.34)
	_noise(tail, rng, 0.45)
	_lowpass(tail, 320.0)
	for i in tail.size():
		var t := float(i) / float(RATE)
		d[i] += tail[i] * exp(-t * 5.5) * 0.45    # 楼群里的回响
	return _wav(d, false, 0.72)


func _rifle_shot() -> AudioStreamWAV:
	# 莫辛：比手枪更沉、尾巴更长（山谷 / 楼群里的回声）
	var d := _buf(0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1611
	_noise(d, rng, 0.78)
	for i in d.size():
		var t := float(i) / float(RATE)
		d[i] *= exp(-t * 46.0)
	_sine_ring(d, [78.0, 120.0, 210.0], 20.0, 0.42)
	var tail := _buf(0.5)
	_noise(tail, rng, 0.4)
	_lowpass(tail, 260.0)
	for i in tail.size():
		var t := float(i) / float(RATE)
		d[i] += tail[i] * exp(-t * 3.6) * 0.5
	return _wav(d, false, 0.78)


func _shotgun_shot() -> AudioStreamWAV:
	# 截短双管：低频更足、更「闷」的一声，没有步枪那种尖啸
	var d := _buf(0.42)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1621
	_noise(d, rng, 0.8)
	_lowpass(d, 2600.0)
	for i in d.size():
		var t := float(i) / float(RATE)
		d[i] *= exp(-t * 34.0)
	_sine_ring(d, [62.0, 96.0], 16.0, 0.5)
	return _wav(d, false, 0.8)


func _reload() -> AudioStreamWAV:
	# 两下金属动作：退匣 / 推弹入膛
	var d := _buf(0.42)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1631
	for i in d.size():
		d[i] = 0.0
	for at in [0.02, 0.22]:
		var i0 := int(at * RATE)
		for k in int(0.06 * RATE):
			var t := float(k) / float(RATE)
			d[i0 + k] += rng.randf_range(-1.0, 1.0) * exp(-t * 70.0) * 0.35
		_sine_ring(d, [820.0, 1240.0], 55.0, 0.12, at)
	return _wav(d, false, 0.6)


func _swing() -> AudioStreamWAV:
	var d := _buf(0.26)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1701
	_noise(d, rng, 0.6)
	for i in d.size():
		var k := float(i) / float(d.size())
		# 扫过的风声：带通中心 500 → 2600 → 700 Hz
		d[i] *= sin(PI * k)
	_bandpass(d, 500.0, 2600.0)
	return _wav(d, false, 0.7)


func _crowbar_hit() -> AudioStreamWAV:
	var d := _buf(0.42)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1801
	_noise(d, rng, 0.7)
	for i in d.size():
		var t := float(i) / float(RATE)
		d[i] *= exp(-t * 90.0)
	_sine_ring(d, [430.0, 705.0, 1180.0, 1630.0], 15.0, 0.15)
	_sine_ring(d, [72.0], 22.0, 0.4)
	return _wav(d, false, 0.8)


func _rummage() -> AudioStreamWAV:
	var d := _buf(0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1901
	_noise(d, rng, 0.5)
	_lowpass(d, 1300.0)
	for i in d.size():
		var t := float(i) / float(RATE)
		# 手在铁皮 / 木箱里翻：不规则的幅度调制 + 两下磕碰
		var am := 0.45 + 0.55 * absf(sin(TAU * (2.6 + 1.7 * sin(t * 5.0)) * t + 0.8))
		d[i] *= am * _env_ar(t / 0.5, 0.1, 0.25)
	for at in [0.14, 0.33]:
		var i0 := int(at * RATE)
		_sine_ring(d, [520.0, 940.0], 40.0, 0.16, at)
		for i in range(i0, mini(i0 + 160, d.size())):
			d[i] += rng.randf_range(-0.2, 0.2) * exp(-float(i - i0) / 30.0)
	return _wav(d)


func _can_throw() -> AudioStreamWAV:
	var d := _buf(0.17)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2001
	_noise(d, rng, 0.45)
	_bandpass(d, 700.0, 3200.0)
	for i in d.size():
		var k := float(i) / float(d.size())
		d[i] *= sin(PI * k) * 0.7
	return _wav(d)


func _dawn_horn() -> AudioStreamWAV:
	## 天亮的信号：远处调车机车的汽笛（不是鸟 —— 诺沃斯克-17 的黎明是工业的）。
	var dur := 1.9
	var d := _buf(dur)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2101
	var phases := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
	var freqs := PackedFloat64Array([96.0, 144.5, 192.0, 289.0])
	for i in d.size():
		var k := float(i) / float(d.size())
		var t := float(i) / float(RATE)
		var vib := 1.0 + 0.006 * sin(TAU * 5.1 * t)
		var s := 0.0
		for j in 4:
			phases[j] += TAU * freqs[j] * vib / float(RATE)
			s += sin(phases[j]) / (1.0 + float(j) * 0.9)
		d[i] = s * _env_ar(k, 0.22, 0.45) * 0.34
	_lowpass(d, 1400.0)
	# 底下垫一层风雪，让汽笛听起来在户外
	var bed := _buf(dur)
	_noise(bed, rng, 0.3)
	_lowpass(bed, 420.0)
	for i in d.size():
		var k := float(i) / float(d.size())
		d[i] += bed[i] * _env_ar(k, 0.3, 0.4) * 0.5
	return _wav(d)


func _freeze() -> AudioStreamWAV:
	var dur := 1.3
	var d := _buf(dur)
	var phase := 0.0
	var phase2 := 0.0
	for i in d.size():
		var k := float(i) / float(d.size())
		var f := lerpf(470.0, 108.0, k * k)
		phase += TAU * f / float(RATE)
		phase2 += TAU * (f * 1.503) / float(RATE)
		d[i] = (sin(phase) * 0.6 + sin(phase2) * 0.22) * _env_ar(k, 0.06, 0.55) * 0.3
	return _wav(d)


func _chill() -> AudioStreamWAV:
	## 体温跌破一档时的玻璃质提示音（很轻，别盖住脚步）
	var d := _buf(0.7)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2201
	_sine_ring(d, [1560.0, 2340.0, 3120.0], 6.5, 0.26)
	_noise(d, rng, 0.14)
	_bandpass(d, 1200.0, 4200.0)
	for i in d.size():
		var t := float(i) / float(RATE)
		d[i] *= exp(-t * 4.2)
	return _wav(d)


func _heartbeat() -> AudioStreamWAV:
	var d := _buf(0.46)
	_sine_ring(d, [58.0, 88.0], 26.0, 0.5, 0.0)
	_sine_ring(d, [52.0, 78.0], 30.0, 0.34, 0.19)
	_lowpass(d, 220.0)
	return _wav(d)
