extends Node2D
## CampaignBackdrop.gd — 战役各界面（标题 / 602 室 / 地图 / 结算 / 结局）的夜景背景。
##
## 不再用纯色方块拼「窗和床」，改用夜潜场景同一套程序化美术：
##   天空渐变 → 远景楼群剪影（Town 立面）→ 近景赫鲁晓夫楼（Khrushchyovka 立面）
##   → 加色窗光（VFX_Facade_WindowGlow，和场景里 PointLight2D 用的是同一张）
##   → 钠灯光晕 → 雪地 / 低雾 → 暗角 → 按界面压暗。
## 三层节点：本节点画「底」，Glow 子节点用加色混合画光，Front 子节点画雾 / 暗角 / 压暗。
## 只有钠灯呼吸和雾在动：Glow / Front 每帧重画，底层静态只在换模式时重画。

const TEX_NEAR := preload("res://art/20_tileset/TIL_Facade_Khrushchyovka_A.png")
const TEX_NEAR_GLOW := preload("res://art/50_vfx/VFX_Facade_WindowGlow.png")
const TEX_FAR := preload("res://art/20_tileset/TIL_Facade_Town_A.png")
const TEX_FAR_GLOW := preload("res://art/50_vfx/VFX_Facade_WindowGlow_Town.png")
const TEX_RADIAL := preload("res://art/50_vfx/VFX_Light_Radial_Soft.png")
const TEX_FOG := preload("res://art/50_vfx/VFX_FogNoise.png")

const SCREEN := Vector2(1920, 1080)
const HORIZON := 640.0          # 远景楼群的墙脚
const GROUND := 985.0           # 近景楼的墙脚 / 雪地上沿
const NEAR_SCALE := 0.66
const FAR_SCALE := 0.40

## 每个界面压暗多少（0 = 标题页全亮；面板多的界面压暗，避免背景抢字）
const DIM := {"title": 0.0, "base": 0.42, "map": 0.5, "report": 0.5, "ending": 0.38}

## 两盏钠灯：位置（灯头）、杆底 y
const LAMPS := [Vector2(250, 760), Vector2(1580, 772)]

var mode := "title":
	set(v):
		if v == mode:
			return
		mode = v
		queue_redraw()
		if _front != null:
			_front.queue_redraw()

var _t := 0.0
var _glow: Node2D
var _front: Node2D


func _ready() -> void:
	show_behind_parent = true          # 父节点 Campaign 的 _draw（雪 / 地图）画在背景之上
	_glow = Node2D.new()
	_glow.name = "Glow"
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	_front = Node2D.new()
	_front.name = "Front"
	_front.draw.connect(_draw_front)
	add_child(_front)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_glow.queue_redraw()
	_front.queue_redraw()


# ----------------------------------------------------------------------------
# 底：天空 / 远景 / 近景 / 灯杆 / 雪地
# ----------------------------------------------------------------------------
func _draw() -> void:
	# 天空：顶上沥青黑，地平线一层被城市灯光托起来的脏蓝
	_vgrad(0.0, HORIZON - 120.0, Color("03050a"), Color("0d1626"))
	_vgrad(HORIZON - 120.0, GROUND, Color("0d1626"), Color("111b2b"))
	# 远景：楼群剪影，几乎是黑的，只有窗光透出来
	var far := _facade_rect(TEX_FAR, FAR_SCALE, HORIZON, -260.0)
	for i in 2:
		var r := Rect2(far.position + Vector2(far.size.x * i, 0), far.size)
		draw_texture_rect(TEX_FAR, r, false, Color(0.07, 0.085, 0.13))
	# 近景：602 室对面那栋楼。夜里的预制板墙是冷蓝灰
	var near := _facade_rect(TEX_NEAR, NEAR_SCALE, GROUND, -60.0)
	draw_texture_rect(TEX_NEAR, near, false, Color(0.22, 0.27, 0.38))
	# 灯杆
	for lp in LAMPS:
		var foot := Vector2(lp.x, GROUND + 40.0)
		draw_line(foot, lp, Color("0a0d12"), 7.0)
		draw_line(lp, lp + Vector2(34, -10), Color("0a0d12"), 6.0)
		draw_rect(Rect2(lp + Vector2(26, -14), Vector2(26, 10)), Color("161b22"), true)
	# 雪地：楼脚往下是被踩实的雪，越往下越暗
	_vgrad(GROUND, SCREEN.y, Color("27324a"), Color("0a0e16"))
	draw_line(Vector2(0, GROUND), Vector2(SCREEN.x, GROUND), Color(0.55, 0.63, 0.78, 0.35), 2.0)


# ----------------------------------------------------------------------------
# 光（加色）：窗光 / 钠灯 / 雪地上的光斑
# ----------------------------------------------------------------------------
func _draw_glow() -> void:
	var far := _facade_rect(TEX_FAR, FAR_SCALE, HORIZON, -260.0)
	var fg_size := Vector2(TEX_FAR_GLOW.get_size()) * FAR_SCALE
	for i in 2:
		_glow.draw_texture_rect(TEX_FAR_GLOW,
			Rect2(far.position + Vector2(far.size.x * i, 0), fg_size), false, Color(0.55, 0.38, 0.2))
	var near := _facade_rect(TEX_NEAR, NEAR_SCALE, GROUND, -60.0)
	var ng_size := Vector2(TEX_NEAR_GLOW.get_size()) * NEAR_SCALE
	_glow.draw_texture_rect(TEX_NEAR_GLOW, Rect2(near.position, ng_size), false, Color(0.95, 0.66, 0.34))
	# 钠灯：一大一小两层，慢呼吸；右边那盏偶尔接触不良
	for i in LAMPS.size():
		var head: Vector2 = LAMPS[i] + Vector2(39, -4)
		var k := 0.92 + 0.08 * sin(_t * 1.3 + float(i) * 2.1)
		if i == 1 and fmod(_t, 7.3) < 0.12:
			k *= 0.35
		_radial(head, 420.0, Color(0.85, 0.5, 0.18, 0.55 * k))
		_radial(head, 110.0, Color(1.0, 0.78, 0.45, 0.9 * k))
		# 雪地上的光斑（压扁的椭圆）
		var pool := Vector2(head.x, GROUND + 52.0)
		_glow.draw_set_transform(pool, 0.0, Vector2(1.0, 0.28))
		_glow.draw_texture_rect(TEX_RADIAL, Rect2(Vector2(-260, -260), Vector2(520, 520)), false,
			Color(0.8, 0.52, 0.25, 0.5 * k))
		_glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ----------------------------------------------------------------------------
# 前：低雾 / 暗角 / 标题区压暗 / 按界面整体压暗
# ----------------------------------------------------------------------------
func _draw_front() -> void:
	# 低雾：两层反向漂移，只在地平线和雪地附近
	var drift := fmod(_t * 14.0, 512.0)
	for layer in 2:
		var off := drift if layer == 0 else -drift * 0.6
		var y0 := HORIZON - 40.0 if layer == 0 else GROUND - 90.0
		var x := -512.0 + fmod(off, 512.0)
		while x < SCREEN.x:
			_front.draw_texture_rect(TEX_FOG, Rect2(Vector2(x, y0), Vector2(512, 220)), false,
				Color(0.45, 0.55, 0.72, 0.07))
			x += 512.0
	# 标题页：字底下压一团暗，让钢印标题从夜景里站出来
	if mode == "title":
		_soft_dark(Rect2(SCREEN.x * 0.5 - 520.0, 260.0, 1040.0, 680.0), 0.62)
	# 暗角：四边往里收
	_edge_dark()
	var d: float = float(DIM.get(mode, 0.4))
	if d > 0.0:
		_front.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.012, 0.016, 0.024, d), true)


# ----------------------------------------------------------------------------
# 工具
# ----------------------------------------------------------------------------
## 立面按比例缩放、墙脚落在 base_y、水平偏移 x0（贴图上沿 = 墙顶）。
func _facade_rect(tex: Texture2D, s: float, base_y: float, x0: float) -> Rect2:
	var sz := Vector2(tex.get_size()) * s
	return Rect2(Vector2(x0, base_y - sz.y), sz)


func _vgrad(y0: float, y1: float, top: Color, bottom: Color) -> void:
	draw_polygon(
		PackedVector2Array([Vector2(0, y0), Vector2(SCREEN.x, y0), Vector2(SCREEN.x, y1), Vector2(0, y1)]),
		PackedColorArray([top, top, bottom, bottom]))


func _radial(c: Vector2, r: float, col: Color) -> void:
	_glow.draw_texture_rect(TEX_RADIAL, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, col)


## 矩形中间暗、四边渐隐到 0（四块梯形渐变拼出来，不需要贴图）。
func _soft_dark(r: Rect2, a: float) -> void:
	var feather := 220.0
	var inner := r.grow(-feather)
	var dark := Color(0.01, 0.012, 0.02, a)
	var clear := Color(0.01, 0.012, 0.02, 0.0)
	_front.draw_rect(inner, dark, true)
	var o := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	var i := [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]
	for k in 4:
		var k2 := (k + 1) % 4
		_front.draw_polygon(PackedVector2Array([o[k], o[k2], i[k2], i[k]]),
			PackedColorArray([clear, clear, dark, dark]))


func _edge_dark() -> void:
	var w := 360.0
	var dark := Color(0.0, 0.0, 0.01, 0.78)
	var clear := Color(0.0, 0.0, 0.01, 0.0)
	var S := SCREEN
	var bands := [
		[Vector2(0, 0), Vector2(S.x, 0), Vector2(S.x, w * 0.6), Vector2(0, w * 0.6)],       # 上
		[Vector2(0, S.y), Vector2(S.x, S.y), Vector2(S.x, S.y - w * 0.5), Vector2(0, S.y - w * 0.5)],  # 下
		[Vector2(0, 0), Vector2(0, S.y), Vector2(w, S.y), Vector2(w, 0)],                   # 左
		[Vector2(S.x, 0), Vector2(S.x, S.y), Vector2(S.x - w, S.y), Vector2(S.x - w, 0)],   # 右
	]
	for b in bands:
		_front.draw_polygon(PackedVector2Array(b), PackedColorArray([dark, dark, clear, clear]))
