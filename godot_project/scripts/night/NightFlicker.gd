extends Node2D
## NightFlicker.gd — 灯具「灯光对」的亮度调制。
##
## 每个灯具节点下挂两盏 PointLight2D：Ground（只照地面、投影）+ Objects（只照立着的精灵、不投影），
## 这样 2.5D 立面不会被自己的遮挡体压黑。本脚本统一调这两盏灯的 energy，可选再调一个光晕精灵。
##   fire   ：火堆，低频噪声 + 偶发跳动
##   sodium ：钠灯，稳定但偶尔断电闪两下
##   crt    ：电传机 CRT，轻微扫描抖动
##   steady ：不动

@export_enum("fire", "sodium", "crt", "steady") var mode := "fire"
@export var strength := 1.0
@export var flicker_seed := 0

var _base: Dictionary = {}     # PointLight2D -> 基础 energy
var _halo_a := {}              # CanvasItem -> 基础 alpha
var _t := 0.0
var _drop := 0.0               # 钠灯断电剩余时间
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = flicker_seed
	_t = _rng.randf() * 10.0
	for c in find_children("*", "PointLight2D", true, false):
		_base[c] = (c as PointLight2D).energy
	for c in find_children("Halo*", "CanvasItem", true, false):
		_halo_a[c] = (c as CanvasItem).modulate.a

func _process(delta: float) -> void:
	_t += delta
	var k := 1.0
	match mode:
		"fire":
			k = 0.82 + 0.12 * sin(_t * 7.3) + 0.08 * sin(_t * 13.7 + 1.3) + 0.05 * sin(_t * 23.1)
			if _rng.randf() < delta * 1.5:
				k += 0.18
		"sodium":
			if _drop > 0.0:
				_drop -= delta
				k = 0.15 if fmod(_drop, 0.16) < 0.08 else 0.85
			else:
				k = 0.96 + 0.04 * sin(_t * 50.0)
				if _rng.randf() < delta * 0.12:
					_drop = 0.5 + _rng.randf() * 0.4
		"crt":
			k = 0.9 + 0.06 * sin(_t * 31.0) + 0.04 * sin(_t * 3.1)
		_:
			k = 1.0
	k = lerpf(1.0, k, strength)
	for l in _base:
		(l as PointLight2D).energy = float(_base[l]) * k
	for h in _halo_a:
		var ci := h as CanvasItem
		ci.modulate.a = float(_halo_a[h]) * clampf(k, 0.0, 1.2)
