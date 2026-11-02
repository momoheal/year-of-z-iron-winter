extends Control
## SovietMeter.gd — 分段式仪表（体温 / 健康 / 氧气 / 危险度都用它）。
##
## 不是 ProgressBar：苏联机器的表盘是分格的，一格一格掉才看得见。
## 掉到 warn_at 以下，剩下的格子会像接触不良的指示灯一样闪。
## 全部用 _draw() 画，不依赖任何贴图；一行 16 格的 draw_rect 开销可以忽略。

var value := 1.0                 ## 0..1 当前读数
var segments := 16               ## 分格数
var fill := Color("c8a257")      ## 正常填充色
var fill_low := Color("b8281c")  ## 危险填充色
var track := Color("100e0c")     ## 空槽底
var edge := Color("4a5457")      ## 槽边框 / 空槽亮边
var warn_at := 0.35              ## 低于这个比例开始闪
var blink := true                ## 是否闪烁
var hatch := true                ## 空槽上是否画斜纹

var _t := 0.0
var _low := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(240, 18)
	set_process(false)
	queue_redraw()


## 外部每帧喂读数；只有变化超过半格才重画。
func set_value(v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	if absf(v - value) < 0.0015:
		return
	value = v
	var low := value <= warn_at
	if low != _low:
		_low = low
		set_process(low and blink)
	queue_redraw()


func _process(delta: float) -> void:
	if not _low:
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w: float = maxf(2.0, size.x)
	var h: float = maxf(4.0, size.y)
	draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), track, true)
	var gap := 2.0 if w >= 120.0 else 1.0
	var n: int = maxi(1, segments)
	var seg_w: float = maxf(1.0, (w - gap * float(n - 1)) / float(n))
	var filled: float = value * float(n)
	var col := fill
	if _low:
		var pulse := 0.35 + 0.65 * absf(sin(_t * 5.2))
		col = fill.lerp(fill_low, pulse)
	for i in n:
		var x := float(i) * (seg_w + gap)
		var lit: bool = float(i) < filled
		if lit:
			var frac: float = clampf(filled - float(i), 0.0, 1.0)
			draw_rect(Rect2(Vector2(x, 0), Vector2(maxf(1.0, seg_w * frac), h)), col, true)
			if frac < 0.999:
				_draw_empty(x + seg_w * frac, seg_w * (1.0 - frac), h)
		else:
			_draw_empty(x, seg_w, h)
	# 外框：一像素亮钢，四角不留圆角
	draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), edge, false, 1.0)


func _draw_empty(x: float, w: float, h: float) -> void:
	if w <= 0.5:
		return
	draw_rect(Rect2(Vector2(x, 0), Vector2(w, h)), Color(edge.r, edge.g, edge.b, 0.30), true)
	if hatch and h >= 10.0 and w >= 4.0:
		# 空槽中间压一道凹槽：比斜纹稳，也不会画出格
		draw_rect(Rect2(Vector2(x, h * 0.5 - 1.0), Vector2(w, 1.0)),
			Color(edge.r, edge.g, edge.b, 0.5), true)
