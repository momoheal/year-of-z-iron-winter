extends Node2D
## NightOverlay.gd — 世界空间的玩法读数：噪声波纹、清杀兵的 ?/! 、狂暴者 / 半人辨识、可搜刮提示、飞罐、撤离点、浮字。
## 挂在 follow_viewport 的 CanvasLayer 下：坐标与世界一致，但不受 CanvasModulate 夜色压暗。

const SQ := 0.62
const REACH := 1.45
const Data := preload("res://scripts/CampaignData.gd")
const CAN_TEX := preload("res://art/30_props/PRP_TinCan.png")

@onready var ctl = owner

func _draw() -> void:
	if ctl == null or ctl.player == null:
		return
	var p: Vector2 = ctl.player.global_position
	# 噪声波纹（按地面压缩成椭圆）
	for r in ctl.ripples:
		var rad: float = float(r["r"]) * 64.0
		var c: Color = r["col"]
		c.a = 0.55 * float(r["life"])
		_ellipse(r["pos"], rad, rad * SQ, c, 2.0)
	# 撤离点
	var ex: Vector2 = ctl.exit_px
	var pulse := 0.5 + 0.5 * sin(ctl.t * 3.0)
	var ec := Color(0.35, 0.95, 0.6, 0.25 + 0.35 * pulse if ctl.pack.has("dial") else 0.18)
	_ellipse(ex, 46.0, 46.0 * SQ, ec, 2.0)
	if ctl.extract_prog > 0.0:
		_arc(ex, 58.0, ctl.extract_prog, Color(0.35, 0.95, 0.6, 0.95), 4.0)
	# 可搜刮提示
	if ctl.state == "play":
		var c2: Node2D = ctl.nearest_container()
		var hf = ctl.nearest_half()
		if hf != null:
			_ellipse(hf.global_position, 34.0, 34.0 * SQ, Color(0.96, 0.62, 0.04, 0.6), 1.5)
			_text(p + Vector2(0, -132), "按 E · 他在发烧（半人 %s）" % hf.tag, Color("#fcd34d"), 15)
		elif c2 != null:
			var ip: Vector2 = ctl.interact_point(c2)
			_ellipse(ip, 34.0, 34.0 * SQ, Color(0.99, 0.85, 0.45, 0.5), 1.5)
			var nm := _cont_name(c2)
			_text(p + Vector2(0, -132), "长按 E 搜刮 · " + nm, Color(0.99, 0.9, 0.6, 0.95), 15)
			if ctl.search_prog > 0.0:
				_arc(p + Vector2(0, -50), 34.0, ctl.search_prog, Color(0.99, 0.85, 0.4, 0.95), 4.0)
		elif ctl.dist_m(p, ex) <= REACH:
			_text(p + Vector2(0, -132), "长按 E 钻回锅炉房（撤离）", Color(0.6, 1.0, 0.75, 0.95), 15)
	# 清杀兵头顶读数
	for s in ctl.soldiers:
		var sp: Vector2 = s.global_position + Vector2(0, -128)
		var su: float = clampf(float(s.suspicion), 0.0, 1.0)
		if s.state == "alert":
			_text(sp, "!", Color("#f43f5e"), 30)
		elif su > 0.05 or s.state in ["investigate", "search"]:
			_text(sp, "?", Color(0.99, 0.75, 0.2, 0.5 + su * 0.5), 26)
			_arc(sp + Vector2(0, -8), 18.0, su, Color(0.99, 0.75, 0.2, 0.85), 3.0)
		if s.aim_target != null:
			if s.aim_target in ctl.halfs:
				_text(sp + Vector2(0, -26), "瞄准 —— 那是半人！", Color("#f87171"), 15)
			else:
				_text(sp + Vector2(0, -26), "瞄准", Color(0.49, 0.83, 0.99, 0.9), 14)
	# 狂暴者读数：追击 ! / 起跳预警红圈（0.45s）/ 循声 ?
	for r in ctl.rabids:
		if not r.is_alive():
			continue
		var rp: Vector2 = r.global_position
		if r.state == "windup":
			var k: float = clampf(r.windup / r.WINDUP, 0.0, 1.0)
			_ellipse(rp, 30.0 + 26.0 * (1.0 - k), (30.0 + 26.0 * (1.0 - k)) * SQ, Color(0.94, 0.27, 0.27, 0.5 + 0.5 * k), 3.0)
			_text(rp + Vector2(0, -124), "!!", Color("#ef4444"), 30)
		elif r.state in ["chase", "lunge"]:
			_text(rp + Vector2(0, -124), "!", Color("#ef4444"), 28)
		elif r.state == "investigate":
			_text(rp + Vector2(0, -124), "?", Color(0.73, 0.11, 0.11, 0.8), 22)
	# 回退半人：嗅觉辨识（7m 内标注「半人」，和狂暴者区分开）
	for h in ctl.halfs:
		if not h.is_alive():
			continue
		var hp: Vector2 = h.global_position
		var d: float = ctl.dist_m(p, hp)
		if h.state == "saved":
			if d <= 4.0:
				_text(hp + Vector2(0, -70), "退烧了 · 睡着", Color(0.53, 0.94, 0.67, 0.8), 13)
			continue
		var top := -84.0 if h.state == "huddle" else -118.0      # 蜷坐时矮一截
		if d <= 7.0 and h != ctl.nearest_half():                  # 可交互时由「按 E」提示代替
			var a := clampf((7.0 - d) / 2.0, 0.0, 1.0)
			_text(hp + Vector2(0, top), "半人 %s" % h.tag, Color(0.99, 0.83, 0.3, 0.9 * a), 15)
		if h.state == "flinch":
			_text(hp + Vector2(0, top - 20.0), "!", Color(0.99, 0.85, 0.5, 0.9), 22)
		elif h.state == "drift":
			_text(hp + Vector2(0, top - 20.0), "…", Color(0.99, 0.85, 0.5, 0.8), 22)
	# 飞罐（抛物线）
	for c3 in ctl.thrown:
		var k: float = clampf(float(c3["t"]), 0.0, 1.0)
		var pos: Vector2 = Vector2(c3["from"]).lerp(c3["to"], k) + Vector2(0, -sin(k * PI) * 90.0 - 40.0 * (1.0 - k))
		draw_texture(CAN_TEX, pos - Vector2(8, 13))
	# 浮字
	for f in ctl.floats:
		var fc: Color = f["col"]
		fc.a = clampf(float(f["life"]), 0.0, 1.0)
		_text(f["pos"], String(f["txt"]), fc, 17)

func _cont_name(c: Node) -> String:
	var k := String(c.get_meta("container", "crate"))
	if k == "corpse":
		return "冻僵的尸体"
	if k == "supply" and String(c.get_meta("guaranteed", "")) != "":
		return "三号闷罐车厢"
	var d: Dictionary = Data.CONTAINER_NAMES.get(k, {})
	return String(d.get("zh", k))

func _text(pos: Vector2, s: String, c: Color, size: int) -> void:
	var w: float = ctl.font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string_outline(ctl.font, pos - Vector2(w / 2.0, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5,
		Color(0, 0, 0, c.a * 0.8))
	draw_string(ctl.font, pos - Vector2(w / 2.0, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)

func _ellipse(c: Vector2, rx: float, ry: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 41:
		var a := TAU * float(i) / 40.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, col, w, true)

func _arc(c: Vector2, r: float, frac: float, col: Color, w: float) -> void:
	draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * clampf(frac, 0.0, 1.0), 40, col, w, true)
