extends Node2D
## NightOverlay.gd — 世界空间的玩法读数：噪声波纹、清杀兵的 ?/! 、狂暴者 / 半人辨识、可搜刮提示、飞罐、撤离点、浮字。
## 挂在 follow_viewport 的 CanvasLayer 下：坐标与世界一致，但不受 CanvasModulate 夜色压暗。

const SQ := 0.62
const REACH := 1.45
const Data := preload("res://scripts/CampaignData.gd")
const CAN_TEX := preload("res://art/30_props/PRP_TinCan.png")
const SPARK_TEX := preload("res://art/50_vfx/VFX_Impact_Spark.png")
const BLOOD_TEX := preload("res://art/50_vfx/VFX_Blood_Mist.png")
const CASING_TEX := preload("res://art/50_vfx/VFX_Shell_Casing.png")

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
	# 战斗特效：曳光 / 弹着 / 血雾 / 弹壳 / 命中标记
	for tr in ctl.tracers:
		var ta: float = clampf(float(tr["life"]) / 0.07, 0.0, 1.0)
		draw_line(tr["from"], tr["to"], Color(1.0, 0.86, 0.58, 0.85 * ta), 2.4, true)
		draw_circle(tr["to"], 2.2, Color(1.0, 0.94, 0.75, ta))
	for im in ctl.impacts:
		var life: float = float(im["life"])
		var tex: Texture2D = SPARK_TEX
		if String(im.get("tex", "")).ends_with("Blood_Mist.png"):
			tex = BLOOD_TEX
		elif String(im.get("tex", "")).ends_with("Impact_Spark.png"):
			tex = SPARK_TEX
		var kk: float = clampf(life / 0.3, 0.0, 1.0)
		var sc: float = float(im.get("scale", 1.0)) * lerpf(0.7, 1.25, 1.0 - kk)
		var sz: Vector2 = tex.get_size() * sc
		draw_texture_rect(tex, Rect2(Vector2(im["pos"]) - sz * 0.5, sz), false, Color(1, 1, 1, kk))
	for c in ctl.casings:
		draw_set_transform(Vector2(c["pos"]) + Vector2(0, 0), float(c["life"]) * 9.0)
		draw_texture(CASING_TEX, -CASING_TEX.get_size() * 0.5)
		draw_set_transform(Vector2.ZERO, 0.0)
	for hm in ctl.hit_marks:
		var ha: float = clampf(float(hm["life"]) / 0.45, 0.0, 1.0)
		var hc := Color(1.0, 0.82, 0.45, ha)
		if bool(hm.get("kill", false)):
			hc = Color(1.0, 0.28, 0.24, ha)
		var hp2: Vector2 = hm["pos"]
		for d in [Vector2(-7, -7), Vector2(7, 7), Vector2(-7, 7), Vector2(7, -7)]:
			draw_line(hp2, hp2 + d, hc, 2.4, true)
	# 撤离点
	var ex: Vector2 = ctl.exit_px
	var pulse := 0.5 + 0.5 * sin(ctl.t * 3.0)
	var ec := Color(0.35, 0.95, 0.6, 0.25 + 0.35 * pulse if ctl.pack.has("dial") else 0.18)
	_ellipse(ex, 46.0, 46.0 * SQ, ec, 2.0)
	if ctl.extract_prog > 0.0:
		_arc(ex, 58.0, ctl.extract_prog, Color(0.35, 0.95, 0.6, 0.95), 4.0)
	# 目标物资：走近才点亮，远处不剧透（关键物资 = 本关的 prize）
	if ctl.state == "play" and not ctl.pack.has(ctl.prize) and ctl.objective_px != Vector2.ZERO:
		var op: Vector2 = ctl.objective_px
		var od: float = ctl.dist_m(p, op)
		if od <= 18.0:
			var k0: float = clampf((18.0 - od) / 8.0, 0.0, 1.0)
			_ellipse(op, 30.0, 30.0 * SQ, Color(0.85, 0.72, 0.42, 0.22 + 0.3 * k0), 1.5)
			_text(op + Vector2(0, -78), "ЦЕЛЬ · 目标物资", Color(0.88, 0.76, 0.46, 0.55 + 0.35 * k0), 13)
	# 可搜刮提示
	if ctl.state == "play":
		var c2: Node2D = ctl.nearest_container()
		var hf = ctl.nearest_half()
		var mech: Dictionary = ctl.nearest_mechanism()
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
		elif not mech.is_empty():
			var mnode: Node2D = mech["node2d"]
			_ellipse(mnode.global_position, 38.0, 38.0 * SQ, Color(0.78, 0.63, 0.34, 0.55), 1.5)
			_text(p + Vector2(0, -132), "按 E · " + String(mech.get("prompt", "操作")), Color(0.88, 0.76, 0.46, 0.95), 15)
		elif ctl.dist_m(p, ex) <= REACH:
			_text(p + Vector2(0, -132), "长按 E 撤离：" + String(ctl.extract_zh), Color(0.6, 1.0, 0.75, 0.95), 15)
	# 清杀兵头顶读数
	for s in ctl.soldiers:
		if not s.is_alive():
			continue
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
	# 准星（枪）/ 挥击弧（撬棍）/ 装填环
	if ctl.state == "play":
		var mw: Vector2 = ctl.get_global_mouse_position()
		if ctl.cur_is_gun():
			var w: Dictionary = ctl.cur_w()
			var spread_px: float = clampf(float(w.get("spread", 2.0)) * 2.6, 5.0, 26.0)
			var cc := Color(0.98, 0.86, 0.52, 0.75)
			for a in [0.0, PI * 0.5, PI, PI * 1.5]:
				var u := Vector2(cos(a), sin(a))
				draw_line(mw + u * spread_px, mw + u * (spread_px + 6.0), cc, 1.6, true)
			draw_circle(mw, 1.6, cc)
			if ctl.reload_left > 0.0:
				var rk: float = 1.0 - ctl.reload_left / maxf(0.01, float(w.get("reload", 1.4)))
				_arc(p, 52.0, clampf(rk, 0.0, 1.0), Color(0.98, 0.8, 0.4, 0.9), 4.0)
		else:
			var sway: float = clampf(ctl.swing_t / 0.24, 0.0, 1.0)
			if sway > 0.0:
				var a0: float = ctl.player.facing - 0.85 + (1.0 - sway) * 1.7
				draw_arc(p + Vector2(0, -28), 62.0, a0 - 0.35, a0 + 0.35, 12,
					Color(0.9, 0.84, 0.66, 0.55 * sway), 5.0, true)
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
