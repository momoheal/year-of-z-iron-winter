extends Node2D
## 地面上的三区色带：白区冷白、红区赭红、黑区深青，加一条上沿虚线和地面标签。
##
## 只画一次（静态图），z_index = -1：盖在地面大图之上、所有立起来的精灵之下，
## 所以道具 / 人物 / 灯光都不受影响，只是「地面告诉你这是哪个区」。
## 数据来自场景根节点与自己的 metadata/zones（build_scene.py 写），格式见 NightZones.gd。

const Zones := preload("res://scripts/night/NightZones.gd")
const SovietUI := preload("res://scripts/ui/SovietUI.gd")
const PPM := 64.0
const SQ := 0.62

var zones: Array = []


func _ready() -> void:
	var src := String(get_meta("zones", ""))
	if src == "" and get_parent() != null:
		src = String(get_parent().get_meta("zones", ""))
	zones = Zones.parse(src)
	queue_redraw()


func _zrect(r: Rect2) -> Rect2:
	return Rect2(r.position.x * PPM, r.position.y * PPM * SQ, r.size.x * PPM, r.size.y * PPM * SQ)


func _draw() -> void:
	if zones.is_empty():
		return
	# 地面喷字用压缩钢印体（和 HUD 标题同一套），不是引擎默认字体
	var font: Font = SovietUI.display_font()
	if font == null:
		font = ThemeDB.fallback_font
	for z in zones:
		var zid := String(z["id"])
		var inf := Zones.info(zid)
		if inf.is_empty():
			continue
		var col: Color = inf["col"]
		var a := float(inf["tint"])
		for r in z["rects"]:
			var rc := _zrect(r as Rect2)
			# 区带淡染：逐水平细条 + 上下边缘 smoothstep 羽化，相邻区柔和过渡、无明显分界线；
			# 不再画上沿虚线 / 下沿细线（那是硬分界，用户要求去掉）
			var feather := 110.0
			var y := rc.position.y
			while y < rc.end.y:
				var seg := 4.0
				var cy := y + seg * 0.5
				var d := minf(cy - rc.position.y, rc.end.y - cy)
				var w := smoothstep(0.0, 1.0, clampf(d / feather, 0.0, 1.0))
				draw_rect(Rect2(rc.position.x, y, rc.size.x, seg + 1.0), Color(col.r, col.g, col.b, a * w), true)
				y += seg
			# 3) 地面喷字（俄文模板字）：左右各一处，避免镜头在中间时看不到；
			#    很淡，像被雪盖了一半 —— 当前在哪个区以 HUD 为准，这里只是环境叙事
			var tag := String(inf["tag"])
			if font != null and tag != "":
				var ty := rc.position.y + 84.0
				for tx in [rc.position.x + 40.0, rc.position.x + rc.size.x * 0.62]:
					draw_string(font, Vector2(tx, ty), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 40,
						Color(col.r, col.g, col.b, 0.17))


func _dash(x0: float, x1: float, y: float, col: Color, dash: float, gap: float) -> void:
	var x := x0
	while x < x1:
		draw_line(Vector2(x, y), Vector2(minf(x + dash, x1), y), col, 3.0)
		x += dash + gap
