extends Control
## SovietStarMeter.gd — 十格五角星生命 / 体温仪表。
## 每个星角沿中线拆成两个三角形半角；半个星角 = 10% 读数。
## 不使用贴图，保持任何分辨率下的锐利轮廓。

var value := 1.0
var segments := 10
var fill := Color("b8281c"):
	set(v):
		fill = v
		queue_redraw()
var fill_low := Color("e04432")
var track := Color("100e0c")
var edge := Color("7b7160")
var warn_at := 0.30
var blink := true
var show_mount := true

var _t := 0.0
var _low := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(92, 92)
	set_process(false)
	queue_redraw()

func set_value(v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	var low := v <= warn_at
	if absf(v - value) < 0.001 and low == _low:
		return
	value = v
	_low = low
	set_process(low and blink)
	queue_redraw()

func lit_segments() -> int:
	return int(ceil(value * float(segments) - 0.0001))

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _point(center: Vector2, radius: float, angle: float, inner := false) -> Vector2:
	var r: float = radius * (0.43 if inner else 1.0)
	return center + Vector2(cos(angle), sin(angle)) * r

func _draw() -> void:
	var radius: float = maxf(8.0, minf(size.x, size.y) * 0.5 - 5.0)
	var center: Vector2 = size * 0.5
	var col: Color = fill
	if _low:
		var pulse: float = 0.55 + 0.45 * absf(sin(_t * 4.6)) if blink else 0.8
		col = fill.lerp(fill_low, pulse)
	if show_mount:
		# 仪表不是悬浮图标，而是拧在铁板上的一枚旧徽章。
		draw_circle(center + Vector2(2, 3), radius + 3.0, Color(0, 0, 0, 0.42))
		draw_arc(center, radius + 2.0, 0.0, TAU, 60, Color(edge.r, edge.g, edge.b, 0.22), 1.0, true)
		for i in 5:
			var a: float = -PI / 2.0 + float(i) * TAU / 5.0
			var screw: Vector2 = center + Vector2(cos(a), sin(a)) * (radius + 1.0)
			draw_circle(screw, 1.5, Color(edge.r, edge.g, edge.b, 0.65))
	var filled: float = value * float(segments)
	for i in segments:
		var point_index: int = i / 2
		var a: float = -PI / 2.0 + float(point_index) * TAU / 5.0
		var outer := _point(center, radius, a)
		var before := _point(center, radius, a - PI / 5.0, true)
		var after := _point(center, radius, a + PI / 5.0, true)
		var tri := PackedVector2Array()
		if i % 2 == 0:
			tri.append_array([center, before, outer])
		else:
			tri.append_array([center, outer, after])
		var frac: float = clampf(filled - float(i), 0.0, 1.0)
		var facet: Color = track if frac <= 0.0 else track.lerp(col, maxf(0.18, frac))
		draw_colored_polygon(tri, facet)
		tri.append(tri[0])
		draw_polyline(tri, Color(edge.r, edge.g, edge.b, 0.52), 1.0, true)
		if frac < 0.99:
			var tip: Vector2 = outer if i % 2 == 0 else after
			var root: Vector2 = before if i % 2 == 0 else outer
			draw_line(center.lerp(tip, 0.42), root.lerp(tip, 0.82),
				Color(edge.r, edge.g, edge.b, 0.25), 1.0, true)
	# 外轮廓与轴心铆钉，强化五角星而非饼图的读法。
	var outline := PackedVector2Array()
	for i in 10:
		var a: float = -PI / 2.0 + float(i) * PI / 5.0
		outline.append(_point(center, radius, a, i % 2 == 1))
	outline.append(outline[0])
	draw_polyline(outline, edge, 1.6, true)
	draw_circle(center, maxf(2.0, radius * 0.075), Color("17191a"))
	draw_circle(center, maxf(1.0, radius * 0.035), edge)
