extends Node2D
## Room A 垂直切片 — 单 Node2D + RefCounted 数据对象 + 立即模式 _draw()。
## 1:1 对应 prototypes/Year_of_Z_Iron_Winter_Exploration_Demo.html 的夜潜场景：
## 手动移动/碰撞/分离、暗层挖洞雾、士兵光锥、声波波纹、斜俯视挤出墙体、雪粒子。
## 没有 CharacterBody2D / PointLight2D / 物理引擎 / 多场景。

const SimScript := preload("res://scripts/Sim.gd")
const HUD := preload("res://scripts/HUD.gd")

const COL_FLOOR := Color("232e3d")
const COL_FLOOR2 := Color("151c26")
const COL_GROUT := Color("334155")
const COL_SLUSH := Color("22323f")
const COL_SLUSH2 := Color("2b4657")
const COL_WALL_TOP := Color("4b5a70")
const COL_WALL_FRONT := Color("1e2836")
const COL_WALL_EDGE := Color("8fa1b8")
const COL_COVER := Color("3a4655")
const COL_COVER_RUST := Color("6a4a2a")
const COL_ENTRY := Color("4ade80")
const COL_BG := Color("05070a")
const COL_FOG := Color("04060a")

var sim                       # Sim 脚本实例（纯数据/逻辑，不使用静态类型以便动态访问）
var hud: CanvasLayer
var font: SystemFont

# 雾层低分辨率 CPU 图（对应 HTML 的 offscreen fogCv + destination-out）
var fog_img: Image
var fog_tex: ImageTexture
var vig_tex: ImageTexture
var _fog_w: int = 0
var _fog_h: int = 0
const FOG_DOWNSCALE := 6

func _ready() -> void:
	sim = SimScript.new()
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "SimHei", "Segoe UI", "Arial"])
	hud = HUD.new()
	add_child(hud)
	hud.bind_sim(sim)
	_build_vignette()

# ============================================================================
# 输入 + 主循环
# ============================================================================
func _physics_process(delta: float) -> void:
	var dt: float = minf(delta, 0.05)
	if sim.phase == 0:
		var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var crouch: bool = Input.is_action_pressed("crouch")
		var sprint: bool = Input.is_action_pressed("sprint")
		var hold_e: bool = Input.is_action_pressed("interact")
		var mouse_world := _unproject(get_viewport().get_mouse_position())
		if Input.is_action_just_pressed("throw_can"):
			sim.throw_can(mouse_world)
		if Input.is_action_just_pressed("drink"):
			sim.drink()
		sim.update(dt, move, crouch, sprint, mouse_world, hold_e)
	sim.shake = maxf(0.0, sim.shake - dt * 10.0)
	if Input.is_action_just_pressed("gym_switch_scene"):
		# F1：返回 5 合 1 灰盒测试场
		get_tree().change_scene_to_file("res://scenes/gym.tscn")
		return
	if Input.is_physical_key_pressed(KEY_F2) and not _f2_latch:
		_f2_latch = true
		get_tree().change_scene_to_file("res://scenes/campaign.tscn")
		return
	_f2_latch = Input.is_physical_key_pressed(KEY_F2)
	if sim.phase != 0 and Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return
	hud.refresh()
	queue_redraw()

# ============================================================================
# 投影（对应 HTML project / unproject）
# ============================================================================
func _vp() -> Vector2:
	return get_viewport_rect().size

func _project(wx: float, wy: float) -> Vector2:
	var vp := _vp()
	var shake_x: float = (sim.rng.randf() - 0.5) * sim.shake
	var shake_y: float = (sim.rng.randf() - 0.5) * sim.shake
	return Vector2((wx - sim.cam.x) * SimScript.PPM + vp.x * 0.5 + shake_x,
			(wy - sim.cam.y) * SimScript.PPM * SimScript.SQUASH + vp.y * 0.5 + shake_y)

func _unproject(sp: Vector2) -> Vector2:
	var vp := _vp()
	return Vector2((sp.x - vp.x * 0.5) / SimScript.PPM + sim.cam.x,
			(sp.y - vp.y * 0.5) / (SimScript.PPM * SimScript.SQUASH) + sim.cam.y)

# ============================================================================
# 立即模式绘制
# ============================================================================
func _draw() -> void:
	if sim == null:
		return
	var vp := _vp()
	var pw: float = SimScript.PPM
	var ph: float = SimScript.PPM * SimScript.SQUASH
	var ht: float = SimScript.WALL_H * SimScript.PPM

	# 底色
	draw_rect(Rect2(0, 0, vp.x, vp.y), COL_BG)

	var i0: int = maxi(0, int(floor(sim.cam.x - vp.x * 0.5 / pw)) - 1)
	var i1: int = mini(sim.W - 1, int(ceil(sim.cam.x + vp.x * 0.5 / pw)) + 1)
	var j0: int = maxi(0, int(floor(sim.cam.y - vp.y * 0.5 / ph)) - 2)
	var j1: int = mini(sim.H - 1, int(ceil(sim.cam.y + vp.y / ph)) + 2)

	# ---------- 地面 ----------
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var s := _project(i, j)
			var v: int = sim.at(i, j)
			if not sim.explored[j * sim.W + i]:
				draw_rect(Rect2(s.x, s.y, pw + 1, ph + 1), COL_BG)
				continue
			var col: Color
			if v == SimScript.TT_SLUSH:
				col = COL_SLUSH2 if (i + j) % 3 == 0 else COL_SLUSH
			else:
				col = COL_FLOOR2 if (i * 7 + j * 13) % 5 == 0 else COL_FLOOR
			draw_rect(Rect2(s.x, s.y, pw + 1, ph + 1), col)
			draw_rect(Rect2(s.x + 0.5, s.y + 0.5, pw, ph), COL_GROUT, false, 1.0)
			if v == SimScript.TT_SLUSH and (i * 3 + j * 5) % 4 == 0:
				draw_rect(Rect2(s.x + 4, s.y + 3, pw - 10, ph - 8), Color(0.20, 0.34, 0.42, 0.33))
			var fh: float = _hash2(i, j)
			if v == SimScript.TT_FLOOR or v == SimScript.TT_SLUSH:
				if fh < 0.35:
					draw_rect(Rect2(s.x + 3 + fh * 20, s.y + 2, 1.5, ph - 4), Color(0, 0, 0, 0.13))
				elif fh < 0.55:
					draw_rect(Rect2(s.x + 5 + fh * 14, s.y + 4, 3, 2), Color(0.89, 0.91, 0.95, 0.08))
					draw_rect(Rect2(s.x + 12 + fh * 8, s.y + ph - 6, 2, 2), Color(0.89, 0.91, 0.95, 0.08))

	# 蒸汽管南侧“安全阴影带”提示（地面半透明层）
	var sh0 := _project(4.0, 7.05)
	var sh1 := _project(11.0, 9.7)
	draw_rect(Rect2(sh0.x, sh0.y, sh1.x - sh0.x, sh1.y - sh0.y), Color(0.35, 0.55, 0.85, 0.10))
	_text(_project(4.1, 9.55), "蒸汽管阴影 · 按住 Ctrl 隐匿   PIPE SHADOW · HOLD CTRL", 11, Color(0.55, 0.7, 0.95, 0.85))
	_text(_project(8.6, 12.1), "冻雪泥：减速 ×0.65  噪声 ×2 / SLUSH", 11, Color(0.65, 0.78, 0.9, 0.8))

	# 血渍
	for dc in sim.decals:
		var s := _project(dc.x, dc.y)
		var c := Color(dc.c)
		_ellipse(s, 9, 5, Color(c, 0.67), true)
		_ellipse(s + Vector2(5, -2), 5, 3, Color(c, 0.67), true)
		_ellipse(s + Vector2(-6, 2), 4, 2.5, Color(c, 0.67), true)

	# ---------- 立面（按行绘制，实体穿插其中） ----------
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var v: int = sim.at(i, j)
			if not sim.explored[j * sim.W + i]:
				continue
			var s := _project(i, j)
			if v == SimScript.TT_WALL:
				var inner: bool = sim.at(i - 1, j) == SimScript.TT_WALL and sim.at(i + 1, j) == SimScript.TT_WALL \
						and sim.at(i, j - 1) == SimScript.TT_WALL and sim.at(i, j + 1) == SimScript.TT_WALL
				var wh: float = _hash2(i, j)
				if inner:
					_draw_box(s.x, s.y, pw, ph, ht, Color("2a3444"), Color("141a24"), Color("4a5a70"))
					draw_rect(Rect2(s.x + 1, s.y + 1, pw - 2, 3), Color(0.89, 0.91, 0.95, 0.33))
					if wh < 0.4:
						draw_rect(Rect2(s.x + 3, s.y + ph * 0.4, pw - 6, 2), Color("1e293b"))
				else:
					_draw_box(s.x, s.y, pw, ph, ht, COL_WALL_TOP, COL_WALL_FRONT, COL_WALL_EDGE)
					if wh < 0.6:
						draw_rect(Rect2(s.x + 1, s.y + 1, pw - 2, 3), Color(0.89, 0.91, 0.95, 0.33))
					draw_rect(Rect2(s.x + 4, s.y + ph + 3, 5, 5), Color(0.96, 0.62, 0.04, 0.53) if wh < 0.45 else Color("1e293b"))
					if wh > 0.3 and wh < 0.75:
						draw_rect(Rect2(s.x + pw - 9, s.y + ph + 3, 5, 5), Color("334155"))
			elif v == SimScript.TT_COVER:
				if i >= sim.pipe_x0 and i <= sim.pipe_x1 and j == sim.pipe_y:
					_draw_pipe_tile(i, j, pw, ph, ht, i == sim.pipe_x0, i == sim.pipe_x1)
				else:
					_draw_box(s.x, s.y + ph * 0.18, pw * 0.94, ph * 0.64, ht * 0.38, COL_COVER, Color("1d242e"), Color("556274"))
					for k in range(0, 3):
						draw_rect(Rect2(s.x + 3 + k * (pw / 3.0), s.y + ph * 0.3, pw * 0.16, ph * 0.4), Color(COL_COVER_RUST, 0.4))

		# 撤离点（在这一行）
		if int(floor(sim.exit_pos.y)) == j:
			var es := _project(sim.exit_pos.x, sim.exit_pos.y)
			# 斜俯视椭圆：y 轴压缩
			draw_set_transform(es, 0, Vector2(1, SimScript.SQUASH))
			draw_arc(Vector2.ZERO, pw * 0.55, 0, TAU, 36, COL_ENTRY, 2.0)
			draw_set_transform(Vector2.ZERO)
			_text(es + Vector2(-14, -ph * 1.1), "EXIT 撤离", 10, COL_ENTRY)

		# 实体（按 y 穿插）
		for e in sim.ents:
			if e.dead:
				continue
			if int(floor(e.y)) == j:
				_draw_ent(e)

	# 玩家
	_draw_player()

	# ---------- 雾（暗层挖洞） ----------
	_draw_fog()

	# ---------- 士兵光锥 ----------
	_draw_cones()

	# ---------- 声波波纹 ----------
	_draw_ripples()

	# ---------- EXIT 罗盘（离屏箭头） ----------
	_draw_compass()

	# ---------- 雪粒子 ----------
	_draw_flakes()

	# ---------- 受伤 / 低血量红色暗角 ----------
	var p = sim.player
	var vig: float = 0.0
	if p.hurt > 0.0:
		vig = maxf(vig, 0.55)
	if p.hp < 40.0:
		vig = maxf(vig, 0.35)
	if vig > 0.0:
		draw_texture_rect(vig_tex, Rect2(0, 0, vp.x, vp.y), false, Color(0.65, 0.05, 0.05, vig))

	# 准星
	var mp := get_viewport().get_mouse_position()
	draw_line(mp + Vector2(-7, 0), mp + Vector2(-2, 0), Color(0.85, 0.9, 0.95, 0.7), 1.5)
	draw_line(mp + Vector2(2, 0), mp + Vector2(7, 0), Color(0.85, 0.9, 0.95, 0.7), 1.5)
	draw_line(mp + Vector2(0, -7), mp + Vector2(0, -2), Color(0.85, 0.9, 0.95, 0.7), 1.5)
	draw_line(mp + Vector2(0, 2), mp + Vector2(0, 7), Color(0.85, 0.9, 0.95, 0.7), 1.5)

# ----------------------------------------------------------------------------
# 绘制小工具
# ----------------------------------------------------------------------------
func _text(pos: Vector2, txt: String, size: int, color: Color) -> void:
	draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw_box(sx: float, sy: float, w: float, h: float, hgt: float, top: Color, front: Color, edge: Color) -> void:
	draw_rect(Rect2(sx, sy + h, w, hgt), front)
	draw_rect(Rect2(sx, sy, w, h), top)
	draw_rect(Rect2(sx, sy, w, 1.5), edge)
	draw_rect(Rect2(sx + 0.5, sy + 0.5, w - 1, h + hgt - 1), Color("0a0e13"), false, 1.0)

func _draw_pipe_tile(i: int, j: int, pw: float, ph: float, ht: float, is_left: bool, is_right: bool) -> void:
	# 高架蒸汽管：横跨 pipe 行的锈色圆柱形管道
	var s := _project(i, j)
	var body_top: float = s.y + ph * 0.06
	var body_h: float = ph * 0.78
	var body_ht: float = ht * 0.55
	draw_rect(Rect2(s.x, body_top + body_h, pw, body_ht), Color("1d242e"))
	draw_rect(Rect2(s.x, body_top, pw, body_h), Color("4a3a28"))
	draw_rect(Rect2(s.x, body_top, pw, 2.5), Color("6a4a2a"))
	draw_rect(Rect2(s.x + 2, body_top + 3, pw - 4, 2.0), Color("7d5a36"))
	draw_rect(Rect2(s.x + 0.5, body_top + 0.5, pw - 1, body_h + body_ht - 1), Color("0a0e13"), false, 1.0)
	if is_left:
		draw_set_transform(Vector2(s.x, body_top + body_h * 0.5), 0, Vector2(1, SimScript.SQUASH * 1.25))
		draw_arc(Vector2.ZERO, body_h * 0.55, 0, TAU, 20, Color("2a2018"), 2.0)
		draw_set_transform(Vector2.ZERO)
	if is_right:
		draw_set_transform(Vector2(s.x + pw, body_top + body_h * 0.5), 0, Vector2(1, SimScript.SQUASH * 1.25))
		draw_arc(Vector2.ZERO, body_h * 0.55, 0, TAU, 20, Color("2a2018"), 2.0)
		draw_set_transform(Vector2.ZERO)

func _ellipse(center: Vector2, rx: float, ry: float, color: Color, filled: bool) -> void:
	draw_set_transform(center, 0, Vector2(1, ry / maxf(0.01, rx)))
	if filled:
		draw_arc(Vector2.ZERO, rx, 0, TAU, 28, color)
		draw_colored_polygon(_circle_points(Vector2.ZERO, rx, 28), color)
	else:
		draw_arc(Vector2.ZERO, rx, 0, TAU, 28, color, 1.6)
	draw_set_transform(Vector2.ZERO)

func _circle_points(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in range(0, n):
		var a: float = TAU * float(k) / float(n)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts

func _hash2(i: int, j: int) -> float:
	# 与 HTML hash2 等价（32 位整数位运算）
	var h: int = (i * 73856093) ^ (j * 19349663)
	h = int(h & 0xffffffff)
	h ^= h >> 13
	h = (h * 1274126177) & 0xffffffff
	h ^= h >> 16
	return float(h & 0xffffffff) / 4294967295.0

# ----------------------------------------------------------------------------
# 玩家与实体（对应 drawPlayer / drawEnt）
# ----------------------------------------------------------------------------
func _draw_player() -> void:
	var p = sim.player
	var s := _project(p.x, p.y)
	_ellipse(s + Vector2(0, 2), 11, 5, Color(0, 0, 0, 0.4), true)
	# 视野扇形（淡）——逐三角形扇面绘制，保证插值与合法多边形
	var cone_col := Color("cbd5e1", 0.078)
	var cone_edge := Color("cbd5e1", 0.0)
	for k in range(1, sim.poly.size() - 1):
		var q1 := _project(sim.poly[k].x, sim.poly[k].y)
		var q2 := _project(sim.poly[k + 1].x, sim.poly[k + 1].y)
		if q1.distance_squared_to(s) > 1.0 and q2.distance_squared_to(s) > 1.0 \
				and q1.distance_squared_to(q2) > 1.0 \
				and abs((q1 - s).cross(q2 - s)) > 0.2:
			draw_polygon(PackedVector2Array([s, q1, q2]),
				PackedColorArray([cone_col, cone_edge, cone_edge]))
	# 身体
	var coat: Color = Color("ef4444") if p.hurt > 0 else Color("3b4a5e")
	_ellipse(s + Vector2(0, -7), 8, 10, coat, true)
	draw_rect(Rect2(s.x - 8, s.y - 2, 16, 3), Color("232e3d"))
	draw_rect(Rect2(s.x - 9, s.y - 12, 4, 10), Color("92400e"))
	draw_circle(s + Vector2(0, -16), 6.0, Color("1e293b"))
	draw_circle(s + Vector2(0, -15), 3.6, Color("e2c9a8"))
	draw_circle(s + Vector2(1, -16), 1.4, Color("f59e0b"))
	# 朝向
	draw_line(s + Vector2(0, -4),
		s + Vector2(cos(p.face) * 17, sin(p.face) * 17 * SimScript.SQUASH) + Vector2(0, -4),
		Color("f59e0b", 0.8), 2.5)
	# 撤离进度
	if sim.extract_prog > 0.0:
		draw_rect(Rect2(s.x - 22, s.y - 52, 44, 7), Color(0.04, 0.06, 0.08, 0.87))
		draw_rect(Rect2(s.x - 21, s.y - 51, 42 * sim.extract_prog, 5), COL_ENTRY)
	if p.drink > 0.0:
		_text(s + Vector2(-5, -30), "♨", 10, Color("7dd3fc"))

func _draw_ent(e) -> void:
	var s := _project(e.x, e.y)
	if not sim.explored[int(floor(e.y)) * sim.W + int(floor(e.x))]:
		return
	var visible: bool = sim.vis[int(floor(e.y)) * sim.W + int(floor(e.x))] == 1 \
			or SimScript.hypotf(e.x - sim.player.x, e.y - sim.player.y) < 2.2
	_ellipse(s + Vector2(0, 2), 10, 4.5, Color(0, 0, 0, 0.33), true)
	if not visible:
		return
	var bob: float = sin(sim.time / 0.26 + e.x) * 1.2
	if e.kind == "rabid":
		_ellipse(s + Vector2(0, -9 + bob), 9, 11, Color("5a2e2e"), true)
		draw_rect(Rect2(s.x - 9, s.y - 2 + bob, 18, 3), Color("2e1a1a"))
		draw_circle(s + Vector2(0, -17 + bob), 5.5, Color("a8a29e"))
		draw_rect(Rect2(s.x - 4, s.y - 19 + bob, 2.4, 2.4), Color("ef4444"))
		draw_rect(Rect2(s.x + 1.6, s.y - 19 + bob, 2.4, 2.4), Color("ef4444"))
		draw_line(s + Vector2(-8, -12 + bob), s + Vector2(-13, -2 + bob), Color("5a2e2e"), 3.0)
		draw_line(s + Vector2(8, -12 + bob), s + Vector2(13, -2 + bob), Color("5a2e2e"), 3.0)
		if e.state == "chase":
			_text(s + Vector2(-2, -26 + bob), "!", 11, Color("ef4444"))
		if e.bite > 0.12:
			var bk: float = clampf(e.bite / 0.45, 0.0, 1.0)
			draw_set_transform(s + Vector2(0, -9), 0, Vector2(1, SimScript.SQUASH))
			draw_arc(Vector2.ZERO, 10 + (1 - bk) * 10, 0, TAU, 28, Color("ef4444"), 2.5)
			draw_set_transform(Vector2.ZERO)
	else:
		# osk：黑色制服 + 防毒面具 + 肩灯
		draw_rect(Rect2(s.x - 8, s.y - 20 + bob, 16, 20), Color("1f2937"))
		draw_rect(Rect2(s.x - 8, s.y - 14 + bob, 16, 4), Color("374151"))
		draw_circle(s + Vector2(0, -22 + bob), 6.0, Color("111827"))
		draw_rect(Rect2(s.x - 4, s.y - 23 + bob, 8, 4), Color("a16207"))
		draw_rect(Rect2(s.x - 2, s.y - 13 + bob, 4, 3), Color("ef4444") if e.lock > 0 else Color("fde68a"))
		draw_line(s + Vector2(0, -10 + bob),
			s + Vector2(cos(e.face) * 13, sin(e.face) * 13 * SimScript.SQUASH) + Vector2(0, -10 + bob),
			Color("0f172a"), 2.5)
		if e.lock > 0:
			draw_set_transform(s + Vector2(0, -13), 0, Vector2(1, SimScript.SQUASH))
			draw_arc(Vector2.ZERO, 9 + sin(sim.time / 0.09) * 2, 0, TAU, 28, Color("ef4444"), 2.0)
			draw_set_transform(Vector2.ZERO)
		# 血条（HTML 规则）
		if e.hp < 120:
			draw_rect(Rect2(s.x - 12, s.y - 32, 24, 4), Color("0b0f14"))
			draw_rect(Rect2(s.x - 11, s.y - 31, 22 * e.hp / 120.0, 2), Color("f59e0b"))

# ----------------------------------------------------------------------------
# 雾层（CPU 低分辨率 Image，模拟 offscreen destination-out）
# ----------------------------------------------------------------------------
func _draw_fog() -> void:
	var vp := _vp()
	var w2: int = int(ceil(vp.x / FOG_DOWNSCALE))
	var h2: int = int(ceil(vp.y / FOG_DOWNSCALE))
	if fog_img == null or w2 != _fog_w or h2 != _fog_h:
		fog_img = Image.create(w2, h2, false, Image.FORMAT_RGBA8)
		fog_tex = ImageTexture.create_from_image(fog_img)
		_fog_w = w2
		_fog_h = h2
	fog_img.fill(COL_FOG)
	var pw: float = SimScript.PPM
	var ph: float = SimScript.PPM * SimScript.SQUASH
	# 已探索格：地板留 58% 暗、墙留 28% 暗；可见格全透明
	for j in range(0, sim.H):
		for i in range(0, sim.W):
			if not sim.explored[j * sim.W + i]:
				continue
			var s0 := _project(i, j)
			var s1 := _project(i + 1, j + 1)
			var r0 := Rect2i(int(floor(s0.x / FOG_DOWNSCALE)), int(floor(s0.y / FOG_DOWNSCALE)),
					maxi(1, int(ceil((s1.x - s0.x) / FOG_DOWNSCALE)) + 1),
					maxi(1, int(ceil((s1.y - s0.y) / FOG_DOWNSCALE)) + 1))
			var v: int = sim.at(i, j)
			if sim.vis[j * sim.W + i]:
				fog_img.fill_rect(r0, Color(COL_FOG, 0.0))
			elif v == SimScript.TT_WALL:
				fog_img.fill_rect(r0, Color(COL_FOG, 0.28))
			else:
				fog_img.fill_rect(r0, Color(COL_FOG, 0.58))
	fog_tex.update(fog_img)
	draw_texture_rect(fog_tex, Rect2(0, 0, vp.x, vp.y), false)

# ----------------------------------------------------------------------------
# 士兵光锥（对应 drawCones，半角 22.5° / 14m / N=26 / 射线步长 0.4）
# ----------------------------------------------------------------------------
func _draw_cones() -> void:
	for e in sim.ents:
		if e.dead or e.kind != "osk":
			continue
		var apex := _project(e.x, e.y) + Vector2(0, -8)
		var half: float = deg_to_rad(22.5)
		var range_m: float = 14.0
		var n: int = 26
		var alpha: float = 0.30 if e.lock > 0 else 0.17
		var center_col := Color("fde68a", alpha)
		var rim_col := Color("fde68a", 0.0)
		var prev_q: Vector2 = apex
		for k in range(0, n + 1):
			var a: float = e.face - half + 2.0 * half * (float(k) / float(n))
			var d: float = 0.0
			while d < range_m:
				var nx: float = e.x + cos(a) * d
				var ny: float = e.y + sin(a) * d
				if sim.blocks_sight(sim.at(int(floor(nx)), int(floor(ny)))) and d > 0.3:
					break
				d += 0.4
			var q := _project(e.x + cos(a) * d, e.y + sin(a) * d) + Vector2(0, -8)
			if k > 0 and prev_q.distance_squared_to(q) > 0.01:
				draw_polygon(PackedVector2Array([apex, prev_q, q]), PackedColorArray([center_col, rim_col, rim_col]))
			prev_q = q

# ----------------------------------------------------------------------------
# 声波波纹（对应 drawRipples：rabid 锯齿 22 边，其他平滑椭圆）
# ----------------------------------------------------------------------------
func _draw_ripples() -> void:
	for r in sim.ripples:
		var s := _project(r.x, r.y)
		var alpha: float = clampf(r.life, 0.0, 1.0) * 0.75
		var c: Color = Color(r.color, alpha)
		var rpix: float = r.r * SimScript.PPM
		var pts := PackedVector2Array()
		if r.kind == "rabid":
			for k in range(0, 23):
				var th: float = float(k) / 22.0 * TAU
				var rr: float = rpix * (0.86 + 0.14 * sin(k * 3.1 + r.r))
				pts.append(s + Vector2(cos(th) * rr, sin(th) * rr * SimScript.SQUASH))
			draw_polyline(pts, c, 1.6, true)
		else:
			for k in range(0, 33):
				var th2: float = float(k) / 32.0 * TAU
				pts.append(s + Vector2(cos(th2) * rpix, sin(th2) * rpix * SimScript.SQUASH))
			draw_polyline(pts, c, 1.6, true)

# ----------------------------------------------------------------------------
# EXIT 罗盘（离屏箭头）
# ----------------------------------------------------------------------------
func _draw_compass() -> void:
	var vp := _vp()
	var sp := _project(sim.exit_pos.x, sim.exit_pos.y)
	if sp.x > 30 and sp.x < vp.x - 30 and sp.y > 30 and sp.y < vp.y - 30:
		return
	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.5
	var ang: float = atan2(sp.y - cy, sp.x - cx)
	var rx: float = vp.x * 0.5 - 46
	var ry: float = vp.y * 0.5 - 46
	# 椭圆边界上取点
	var t: float = 1.0 / sqrt((cos(ang) / rx) ** 2 + (sin(ang) / ry) ** 2)
	var base := Vector2(cx + cos(ang) * t, cy + sin(ang) * t)
	var dir := Vector2(cos(ang), sin(ang))
	var arrow := PackedVector2Array([
		base + dir * 12,
		base + dir.rotated(2.4) * 11,
		base + dir.rotated(-2.4) * 11,
	])
	draw_colored_polygon(arrow, Color("4ade80", 0.8))
	var d_m: int = roundi(SimScript.hypotf(sim.player.x - sim.exit_pos.x, sim.player.y - sim.exit_pos.y))
	var txt: String = "EXIT %dm" % d_m
	var tw: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_string(font, base + Vector2(-tw * 0.5, 22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COL_ENTRY)

# ----------------------------------------------------------------------------
# 雪粒子（对应 drawFlakes，130 个屏幕空间）
# ----------------------------------------------------------------------------
func _draw_flakes() -> void:
	var vp := _vp()
	var t: float = sim.time
	for k in range(0, 130):
		var seed: float = k * 97.13
		var x: float = fmod(seed * 13 + t * (40 + (k % 7) * 11), vp.x + 40) - 20
		var y: float = fmod(seed * 29 + t * (70 + (k % 5) * 17), vp.y + 40) - 20
		draw_rect(Rect2(x, y, 1.6, 1.6), Color("cbd5e1", 0.2))

# ----------------------------------------------------------------------------
# 暗角纹理（径向，中心透明）
# ----------------------------------------------------------------------------
func _build_vignette() -> void:
	var n: int = 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in range(0, n):
		for x in range(0, n):
			var d: float = SimScript.hypotf(float(x) - n * 0.5, float(y) - n * 0.5) / (n * 0.5)
			var a: float = clampf((d - 0.45) / 0.55, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	vig_tex = ImageTexture.create_from_image(img)
