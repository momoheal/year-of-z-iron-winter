extends Control
## SovietChrome.gd — 整屏金属框：暗角、角码、铆钉、扫描线、危险红边、厂标水印。
##
## 挂在 HUD/Root 最底下（先加 = 画在最底层）。它不是一个面板，而是「屏幕本身是一块铁」：
##   · 四角 L 形角码 + 边框上的铆钉（钢板是铆出来的，不是贴出来的）；
##   · 一圈由外向里递减的暗角，让画面像透过一段老镜头看；
##   · 极淡的水平扫描线（旧 CRT / 电传监视器）；
##   · danger > 0 时边缘渗出军旗红 —— 警报不靠弹窗，靠屏幕发烫；
##   · 右下角一枚红星 + 厂标（НОВОРСК-17 / 17-Я ДИСТАНЦИЯ ПУТИ）。
##
## 性能：静态元素只在尺寸变化时重画；危险度变化超过 0.04 才 queue_redraw()。
## 呼吸感由 modulate 驱动，不触发重绘。

const SovietUI := preload("res://scripts/ui/SovietUI.gd")

var font: Font
var danger := 0.0                ## 0..1，边缘红光强度
var accent := Color("8f1d16")    ## 角码颜色
var zone := "НОВОРСК-17 · 17-Я ДИСТАНЦИЯ ПУТИ"
var code := ""                   ## 右上角的档案号，例如 «ДЕЛО 0420-А»
var scanlines := true

var _danger_drawn := 0.0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_on_resized)
	set_process(true)
	if font == null:
		font = SovietUI.mono_font()


func _on_resized() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	# 极轻的「老管子」呼吸：只改 modulate，不重绘
	_t += delta
	modulate.a = 0.965 + 0.035 * sin(_t * 1.7)
	if absf(danger - _danger_drawn) > 0.04:
		_danger_drawn = danger
		queue_redraw()


func set_danger(v: float) -> void:
	danger = clampf(v, 0.0, 1.0)


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 8.0 or h < 8.0:
		return
	_draw_vignette(w, h)
	if scanlines:
		_draw_scanlines(w, h)
	_draw_corners(w, h)
	_draw_rivets(w, h)
	if danger > 0.01:
		_draw_alarm(w, h)
	_draw_mark(w, h)


## 由外向里递减的暗角：10 圈，每圈 9px，指数衰减比线性更像镜头。
func _draw_vignette(w: float, h: float) -> void:
	var bands := 10
	var bw := 9.0
	for i in bands:
		var k := float(i + 1) / float(bands)
		var a := 0.16 * pow(1.0 - k, 1.6) + 0.012
		var c := Color(0.0, 0.0, 0.0, a)
		var d := float(i) * bw
		draw_rect(Rect2(Vector2(0, d), Vector2(w, bw)), c, true)
		draw_rect(Rect2(Vector2(0, h - d - bw), Vector2(w, bw)), c, true)
		draw_rect(Rect2(Vector2(d, 0), Vector2(bw, h)), c, true)
		draw_rect(Rect2(Vector2(w - d - bw, 0), Vector2(bw, h)), c, true)


func _draw_scanlines(w: float, h: float) -> void:
	var c := Color(0.0, 0.0, 0.0, 0.055)
	var y := 0.0
	while y < h:
		draw_line(Vector2(0, y), Vector2(w, y), c, 1.0)
		y += 3.0


## 四角 L 形角码：边框是「铆上去的钢板」，不是圆角卡片。
func _draw_corners(w: float, h: float) -> void:
	var L := 74.0
	var t := 2.0
	var col := Color(accent.r, accent.g, accent.b, 0.62)
	var dim := Color(SovietUI.STEEL.r, SovietUI.STEEL.g, SovietUI.STEEL.b, 0.75)
	var pts := [
		[Vector2(6, 6), Vector2(6 + L, 6), Vector2(6, 6 + L)],
		[Vector2(w - 6, 6), Vector2(w - 6 - L, 6), Vector2(w - 6, 6 + L)],
		[Vector2(6, h - 6), Vector2(6 + L, h - 6), Vector2(6, h - 6 - L)],
		[Vector2(w - 6, h - 6), Vector2(w - 6 - L, h - 6), Vector2(w - 6, h - 6 - L)],
	]
	for p in pts:
		var o: Vector2 = p[0]
		draw_line(o, p[1], col, t)
		draw_line(o, p[2], col, t)
		# 内侧再压一条细钢线，双线才有厚度
		var inward := (p[1] - o).normalized() * 4.0 + (p[2] - o).normalized() * 4.0
		draw_line(o + inward, (p[1] as Vector2).lerp(o, 0.08) + inward, dim, 1.0)
		draw_line(o + inward, (p[2] as Vector2).lerp(o, 0.08) + inward, dim, 1.0)


## 上下边框上的铆钉：间距 132px，绕开四角的角码。
func _draw_rivets(w: float, h: float) -> void:
	var col := Color(SovietUI.RIVET.r, SovietUI.RIVET.g, SovietUI.RIVET.b, 0.55)
	var x := 108.0
	while x < w - 96.0:
		draw_circle(Vector2(x, 17.0), 2.2, col)
		draw_circle(Vector2(x, h - 17.0), 2.2, col)
		x += 132.0


func _draw_alarm(w: float, h: float) -> void:
	var k := danger
	var bands := 8
	var bw := 10.0
	for i in bands:
		var f := float(i + 1) / float(bands)
		var a := 0.30 * k * pow(1.0 - f, 1.5)
		var c := Color(SovietUI.BLOOD_LIT.r, SovietUI.BLOOD_LIT.g, SovietUI.BLOOD_LIT.b, a)
		var d := float(i) * bw
		draw_rect(Rect2(Vector2(0, d), Vector2(w, bw)), c, true)
		draw_rect(Rect2(Vector2(0, h - d - bw), Vector2(w, bw)), c, true)
		draw_rect(Rect2(Vector2(d, 0), Vector2(bw, h)), c, true)
		draw_rect(Rect2(Vector2(w - d - bw, 0), Vector2(bw, h)), c, true)


## 右下角：红星 + 厂标；右上角：档案号。都是低透明度，不抢读数。
func _draw_mark(w: float, h: float) -> void:
	var a := 0.30 + 0.10 * danger
	var col := Color(SovietUI.BONE_DIM.r, SovietUI.BONE_DIM.g, SovietUI.BONE_DIM.b, a)
	_star(Vector2(w - 214.0, h - 30.0), 7.0, Color(SovietUI.BLOOD_LIT.r, SovietUI.BLOOD_LIT.g,
		SovietUI.BLOOD_LIT.b, a + 0.18))
	if font != null:
		draw_string(font, Vector2(w - 196.0, h - 25.0), zone, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
		if code != "":
			draw_string(font, Vector2(0, 34.0), code, HORIZONTAL_ALIGNMENT_RIGHT, w - 34.0, 11,
				Color(col.r, col.g, col.b, col.a * 0.8))


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + float(i) * PI / 5.0
		var rr: float = r if i % 2 == 0 else r * 0.42
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)
