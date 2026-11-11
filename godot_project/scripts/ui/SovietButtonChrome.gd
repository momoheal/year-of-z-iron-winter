extends Control
## SovietButtonChrome.gd — 按钮表面的切角、铆钉与机械刻线。
## 作为 Button 的透明子节点存在，不拦截鼠标，也不参与文字布局。

var accent := Color("8c7139")

func _ready() -> void:
	name = "CommandChrome"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x < 42.0 or size.y < 22.0:
		return
	var w: float = size.x
	var h: float = size.y
	var dark := Color(0.025, 0.028, 0.027, 0.96)
	var metal := Color(0.66, 0.65, 0.57, 0.58)
	# 两个冲切角：让轮廓像冲压件，而不是网页矩形。
	draw_colored_polygon(PackedVector2Array([
		Vector2(w - 8, 0), Vector2(w, 0), Vector2(w, 8)]), dark)
	draw_colored_polygon(PackedVector2Array([
		Vector2(w - 8, h), Vector2(w, h - 8), Vector2(w, h)]), dark)
	draw_line(Vector2(w - 8, 1), Vector2(w - 1, 8), accent, 1.0, true)
	draw_line(Vector2(w - 8, h - 1), Vector2(w - 1, h - 8), accent, 1.0, true)
	# 左铜边上的两枚铆钉。
	for y in [h * 0.5 - 8.0, h * 0.5 + 8.0]:
		draw_circle(Vector2(3.2, y), 1.45, Color(0.02, 0.02, 0.018, 0.9))
		draw_circle(Vector2(2.8, y - 0.4), 0.75, metal)
	# 右侧三条车床刻线；长按钮看起来像有独立机械编号区。
	if w >= 110.0:
		for i in 3:
			var x: float = w - 26.0 + float(i) * 4.0
			draw_line(Vector2(x, h * 0.5 - 5), Vector2(x - 3, h * 0.5 + 5),
				Color(accent.r, accent.g, accent.b, 0.58), 1.0, true)
	# 底部细钢线提供磨损边缘，而不是发光描边。
	draw_line(Vector2(13, h - 4), Vector2(minf(w * 0.28, 110.0), h - 4),
		Color(accent.r, accent.g, accent.b, 0.42), 1.0, true)
