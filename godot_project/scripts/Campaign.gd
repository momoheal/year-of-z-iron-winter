extends Node2D
## Campaign.gd — 「一夜」探索循环的渲染 / 输入层（对应 HTML Exploration Demo）。
##
## 结构沿用 Gym.gd：CampaignSim（RefCounted 纯数据）+ 本文件的立即模式 _draw() + CampaignHUD（CanvasLayer）。
## 本文件负责三块视觉：
##   1. 城市地图（900×520，13 个节点 + 已解锁路径）
##   2. 夜潜世界（26px/米、y 轴 0.62 压缩的 75° 斜俯视，程序化街区 + 雾 + 探照锥 + 波纹）
##   3. 基地 / 结算 / 结局的背景氛围（雪、窗光、暗角）
## 所有可点击的按钮都在 HUD 里；地图节点本身用鼠标在世界里点选（_unhandled_input）。

const SimScript := preload("res://scripts/CampaignSim.gd")
const HudScript := preload("res://scripts/CampaignHUD.gd")
const SfxScript := preload("res://scripts/Sfx.gd")
const Data := preload("res://scripts/CampaignData.gd")

const SCREEN := Vector2(1920, 1080)
const TOP := 74.0                    # 顶栏高度
const VIEW_C := Vector2(960.0, 600.0)  # 世界投影中心（顶栏以下的视觉中心）
const MAP_RECT := Rect2(30, 128, 900, 520)
const MAP_PICK_R := 62.0

const COL := {
	"bg": Color("#05070a"),
	"floor": Color("#1a2230"),
	"floor2": Color("#161d29"),
	"slush": Color("#24404e"),
	"grout": Color("#0c1118"),
	"wallTop": Color("#2a3444"),
	"wallFront": Color("#141a24"),
	"wallEdge": Color("#4a5a70"),
	"door": Color("#6b4a2b"),
	"wedge": Color("#9a7425"),
	"cover": Color("#3a3f46"),
	"fence": Color("#64748b"),
	"player": Color("#e2e8f0"),
	"rabid": Color("#ef4444"),
	"osk": Color("#38bdf8"),
	"half": Color("#f59e0b"),
	"mate": Color("#4ade80"),
	"good": Color("#34d399"),
	"warn": Color("#fbbf24"),
	"bad": Color("#f43f5e"),
}

const SFX_ALIAS := {
	"good": "beep", "hit": "akm", "swing": "wedge", "jam": "bonejam",
	"extract": "beep", "bad": "thirst", "osk": "akm", "gun": "akm",
	"can": "can", "wedge": "wedge", "rabid": "thirst", "half": "thirst",
}

var sim
var hud
var sfx
var font: SystemFont
var snow: Array[Vector3] = []      # x, y, speed
var t: float = 0.0
var shake := 0.0

func _ready() -> void:
	# P1: 从夜潜场景回来时，RaidBridge 持有原 CampaignSim（含 stash/day/flags），
	# 取回复用；否则才开新档。
	if RaidBridge.active:
		sim = RaidBridge.take_sim()
	else:
		sim = SimScript.new()
	font = SystemFont.new()
	font.font_names = PackedStringArray([
		"Noto Sans CJK SC", "Noto Sans SC", "Microsoft YaHei", "SimHei",
		"PingFang SC", "Segoe UI", "Arial",
	])
	hud = HudScript.new()
	add_child(hud)
	hud.bind_campaign(sim, self)
	if hud.has_signal("ui_sfx"):
		hud.connect("ui_sfx", Callable(self, "_on_ui_sfx"))
	sfx = SfxScript.new()
	add_child(sfx)
	for i in 160:
		snow.append(Vector3(randf() * SCREEN.x, randf() * SCREEN.y, 12.0 + randf() * 46.0))

func _on_ui_sfx(name: String) -> void:
	if sfx != null and sfx.has_method(name):
		sfx.call(name)

# ============================================================================
# 主循环
# ============================================================================
func _process(delta: float) -> void:
	if sim == null:
		return
	# P1: depart 设了 pending_scene → 切到节点化夜潜场景
	#     （story_open 时先在本场景播完剧情，下一帧再切）
	if sim.pending_scene != "":
		var sc: String = sim.pending_scene
		sim.pending_scene = ""
		get_tree().change_scene_to_file(sc)
		return
	t += delta
	if sfx != null:
		sfx.set_muted(not hud.sound_on)
	var paused: bool = sim.story_open or sim.abort_confirm or sim.logbook_open or sim.help_open
	if sim.phase == "raid" and sim.raid != null and not sim.raid.over and not paused:
		var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var mouse_world := screen_to_world(get_viewport().get_mouse_position())
		sim.raid.update(delta, move, Input.is_action_pressed("crouch"),
			Input.is_action_pressed("sprint"), mouse_world, Input.is_action_pressed("interact"))
		_drain_sfx()
		if sim.raid.over and sim.phase == "raid":
			sim.finish_raid(sim.raid.phase)
	shimmy_snow(delta)
	hud.refresh()
	queue_redraw()

func _drain_sfx() -> void:
	if sim.raid == null or sfx == null:
		return
	for e in sim.raid.drain_sfx():
		var name: String = String(SFX_ALIAS.get(String(e), String(e)))
		sfx.play(name)

func shimmy_snow(dt: float) -> void:
	for i in snow.size():
		var s := snow[i]
		s.y += s.z * dt
		s.x += sin(t * 0.6 + float(i)) * 6.0 * dt
		if s.y > SCREEN.y:
			s.y = -4.0
			s.x = randf() * SCREEN.x
		snow[i] = s

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_ESCAPE:
			if sim.phase == "raid":
				sim.abort_confirm = not sim.abort_confirm
			elif sim.story_open:
				sim.story_open = false
			elif sim.help_open:
				sim.help_open = false
			elif sim.logbook_open:
				sim.logbook_open = false
			return
		if k == KEY_F1:
			get_tree().change_scene_to_file("res://scenes/gym.tscn")
			return
		if k == KEY_F2:
			get_tree().change_scene_to_file("res://scenes/night_explore.tscn")
			return
		if k == KEY_L and sim.phase != "raid":
			sim.toggle_lang()
			return
		if sim.phase == "raid" and sim.raid != null:
			_raid_key(k)
			return
		if k == KEY_ENTER or k == KEY_KP_ENTER:
			if sim.phase == "title":
				sim.new_game()
				sim.phase = "base"
			elif sim.phase == "report":
				sim.to_base()
				sim.advance_day()
			elif sim.phase == "base":
				if sim.selected_loc == "":
					for L in Data.LOCS:
						if sim.loc_unlocked(L):
							sim.selected_loc = String(L["id"])
							break
				sim.phase = "map"
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if sim.phase == "map":
				_pick_node(get_viewport().get_mouse_position())
			elif sim.phase == "raid" and sim.raid != null and not sim.raid.over \
					and not (sim.story_open or sim.abort_confirm or sim.logbook_open or sim.help_open):
				sim.raid.attack()

func _raid_key(k: int) -> void:
	if sim.raid.over:
		return
	match k:
		KEY_Q:
			sim.raid.drink()
		KEY_H:
			sim.raid.use_bandage()
		KEY_R:
			sim.raid.reload_gun()
		KEY_G:
			sim.raid.throw_can(screen_to_world(get_viewport().get_mouse_position()))
		KEY_SPACE:
			sim.raid.attack()

func _pick_node(mouse: Vector2) -> void:
	var local := (mouse - MAP_RECT.position)
	if not MAP_RECT.has_point(mouse):
		return
	var best := ""
	var bd := MAP_PICK_R
	for L in Data.LOCS:
		var d := Vector2(float(L["x"]) - local.x, float(L["y"]) - local.y).length()
		if d < bd:
			bd = d
			best = String(L["id"])
	if best != "":
		sim.selected_loc = best
		sim.phase = "map"

# ============================================================================
# 世界 ↔ 屏幕
# ============================================================================
func screen_to_world(sp: Vector2) -> Vector2:
	if sim.phase != "raid" or sim.raid == null:
		return Vector2.ZERO
	var cam: Vector2 = sim.raid.cam
	return Vector2((sp.x - VIEW_C.x) / Data.PPM + cam.x,
		(sp.y - VIEW_C.y) / (Data.PPM * Data.SQUASH) + cam.y)

func project(sim_raid, wx: float, wy: float) -> Vector2:
	var cam: Vector2 = sim_raid.cam
	return Vector2((wx - cam.x) * Data.PPM + VIEW_C.x,
		(wy - cam.y) * Data.PPM * Data.SQUASH + VIEW_C.y)

# ============================================================================
# 绘制
# ============================================================================
func _draw() -> void:
	if sim == null:
		return
	draw_rect(Rect2(Vector2.ZERO, SCREEN), COL["bg"], true)
	match sim.phase:
		"title":
			_draw_title()
		"base":
			_draw_base()
		"map":
			_draw_base()
			_draw_city_map()
		"raid":
			_draw_raid()
		"report":
			_draw_report_bg()
		"ending":
			_draw_report_bg()
	_draw_snow()
	if sim.phase == "raid" and sim.raid != null:
		_draw_raid_overlays()

func _draw_snow() -> void:
	var a := 0.05 if sim.phase == "raid" else 0.16
	for s in snow:
		draw_circle(Vector2(s.x, s.y), 1.2, Color(0.88, 0.94, 1.0, a))

func _draw_title() -> void:
	# 602 室的窗：一块冷光，窗外是雪
	draw_rect(Rect2(0, 0, SCREEN.x, SCREEN.y), Color("#080b11"), true)
	draw_rect(Rect2(1260, 150, 420, 330), Color("#16202e"), true)
	draw_rect(Rect2(1272, 162, 396, 306), Color("#0d1520"), true)
	for i in 5:
		draw_line(Vector2(1272 + i * 99, 162), Vector2(1272 + i * 99, 468), Color("#1b2735"), 2.0)
	draw_line(Vector2(1272, 315), Vector2(1668, 315), Color("#1b2735"), 2.0)
	# 床沿与点滴架
	draw_rect(Rect2(1150, 600, 520, 120), Color("#121821"), true)
	draw_rect(Rect2(1150, 600, 520, 10), Color("#1e2836"), true)
	draw_line(Vector2(1120, 380), Vector2(1120, 610), Color("#2b3a4d"), 3.0)
	draw_line(Vector2(1120, 392), Vector2(1180, 392), Color("#2b3a4d"), 3.0)
	draw_circle(Vector2(1180, 402), 9.0, Color("#7dd3fc33"))
	draw_circle(Vector2(1180, 402), 4.0, Color("#7dd3fc88"))
	# 地板与门
	draw_rect(Rect2(0, 780, SCREEN.x, 300), Color("#0b0f15"), true)
	for i in 12:
		draw_line(Vector2(i * 160, 780), Vector2(i * 160 - 120, 1080), Color("#0f151d"), 2.0)
	draw_rect(Rect2(760, 640, 180, 320), Color("#0e141c"), true)
	draw_rect(Rect2(760, 640, 180, 6), Color("#1d2836"), true)

func _draw_base() -> void:
	# 基地背景：暖气片 + 结霜的窗 + 母亲的床（左三分之一留给状态栏）
	draw_rect(Rect2(0, TOP, SCREEN.x, SCREEN.y - TOP), Color("#080b11"), true)
	draw_rect(Rect2(0, TOP, SCREEN.x, 6), Color("#111a26"), true)
	# 窗
	draw_rect(Rect2(120, 150, 300, 210), Color("#141d29"), true)
	draw_rect(Rect2(130, 160, 280, 190), Color("#0c141e"), true)
	draw_line(Vector2(270, 160), Vector2(270, 350), Color("#1b2735"), 3.0)
	draw_line(Vector2(130, 255), Vector2(410, 255), Color("#1b2735"), 3.0)
	# 床
	draw_rect(Rect2(90, 780, 560, 130), Color("#11171f"), true)
	draw_rect(Rect2(90, 780, 560, 8), Color("#1e2836"), true)
	draw_rect(Rect2(110, 760, 120, 30), Color("#26303e"), true)
	# 点滴
	draw_line(Vector2(690, 470), Vector2(690, 790), Color("#2b3a4d"), 3.0)
	draw_line(Vector2(690, 482), Vector2(650, 482), Color("#2b3a4d"), 3.0)
	draw_circle(Vector2(648, 494), 8.0, Color("#7dd3fc44"))
	# 暖气片
	for i in 14:
		draw_rect(Rect2(1000 + i * 26, 860, 14, 90), Color("#1a232e"), true)
	draw_line(Vector2(990, 900), Vector2(1420, 900), Color("#243040"), 3.0)
	# 桌面 / 地图
	draw_rect(Rect2(1460, 780, 400, 24), Color("#18202b"), true)
	draw_rect(Rect2(1470, 700, 380, 80), Color("#1c2a22"), true)
	for i in 6:
		draw_line(Vector2(1480 + i * 60, 706), Vector2(1480 + i * 60, 774), Color("#243a2c"), 1.0)

func _draw_city_map() -> void:
	# 地图底板
	draw_rect(MAP_RECT, Color("#0a1013"), true)
	draw_rect(MAP_RECT, Color("#1d2a26"), false, 2.0)
	# 河 / 铁路
	draw_line(MAP_RECT.position + Vector2(0, 400), MAP_RECT.position + Vector2(900, 360),
		Color("#123243"), 26.0)
	for i in 9:
		var x := MAP_RECT.position.x + 10 + i * 108
		draw_line(Vector2(x, MAP_RECT.position.y + 372 - i * 4),
			Vector2(x + 74, MAP_RECT.position.y + 366 - i * 4), Color("#26303c"), 2.0)
	# 街区网格
	for i in 13:
		var gx := MAP_RECT.position.x + i * 70
		draw_line(Vector2(gx, MAP_RECT.position.y + 8), Vector2(gx - 24, MAP_RECT.end.y - 8),
			Color("#0f1a1a"), 1.0)
	for j in 8:
		var gy := MAP_RECT.position.y + j * 66
		draw_line(Vector2(MAP_RECT.position.x + 8, gy), Vector2(MAP_RECT.end.x - 8, gy + 12),
			Color("#0f1a1a"), 1.0)
	# 路径：从 3 号居住区（基地）连到每个已解锁节点
	var base_pos := Vector2(150, 330)
	for L in Data.LOCS:
		var ok: bool = sim.loc_unlocked(L)
		if not ok:
			continue
		var p := MAP_RECT.position + Vector2(float(L["x"]), float(L["y"]))
		var q := MAP_RECT.position + base_pos
		draw_dashed_line(q, p, Color("#2c4a3a"), 2.0, 9.0)
	# 节点
	for L in Data.LOCS:
		var p2 := MAP_RECT.position + Vector2(float(L["x"]), float(L["y"]))
		var ok2: bool = sim.loc_unlocked(L)
		var sel: bool = String(L["id"]) == sim.selected_loc
		var st: Dictionary = sim.node_state(String(L["id"]))
		var rad := 9.0 if ok2 else 6.0
		var col := Color("#8aa0b4") if ok2 else Color("#2f3a46")
		if String(L.get("story", "")) != "":
			col = Color("#f59e0b") if ok2 else Color("#4a3a1a")
		draw_circle(p2, rad + 2.0, Color(0.02, 0.03, 0.04, 0.9))
		draw_circle(p2, rad, col)
		if ok2:
			draw_arc(p2, rad + 5.0, 0.0, TAU, 24, Color(0.02, 0.03, 0.04, 0.55), 2.0)
			if float(st.get("left", 1.0)) < 0.35:
				draw_circle(p2, rad * 0.45, Color("#0b1015"))
		if sel:
			draw_arc(p2, rad + 12.0, -PI / 2, -PI / 2 + TAU, 28, Color("#fbbf24"), 2.0)
		var label: String = String(L["zh"] if sim.lang == "zh" else L["en"])
		if label.contains(" · "):
			label = label.split(" · ")[1]
		var fs := 14
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, p2 + Vector2(-tw / 2.0, 30), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.72, 0.79, 0.86, 0.9 if ok2 else 0.35))
	draw_string(font, MAP_RECT.position + Vector2(16, 30),
		"НОВОРСК-17 · 第 %d 夜" % sim.day if sim.lang == "zh" else "NOVORSK-17 · NIGHT %d" % sim.day,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.45, 0.6, 0.55, 0.8))

func _draw_report_bg() -> void:
	draw_rect(Rect2(0, TOP, SCREEN.x, SCREEN.y - TOP), Color("#080b11"), true)
	# 一张压在桌上的日志纸
	draw_rect(Rect2(90, 150, 640, 780), Color("#141a20"), true)
	draw_rect(Rect2(90, 150, 640, 780), Color("#233040"), false, 2.0)
	for i in 14:
		draw_line(Vector2(120, 240 + i * 46), Vector2(700, 240 + i * 46), Color("#1c2530"), 1.0)
	draw_line(Vector2(120, 210), Vector2(430, 210), Color("#2a3a4a"), 3.0)
	# 窗光
	draw_rect(Rect2(1290, 200, 460, 380), Color("#101823"), true)
	for i in 4:
		draw_line(Vector2(1290, 200 + i * 95), Vector2(1750, 200 + i * 95), Color("#1a2634"), 3.0)

# ----------------------------------------------------------------------------
# 夜潜世界
# ----------------------------------------------------------------------------
func _draw_raid() -> void:
	var R = sim.raid
	if R == null:
		return
	var g: PackedByteArray = R.grid
	var W: int = R.W
	var H: int = R.H
	var pw := Data.PPM
	var ph := Data.PPM * Data.SQUASH
	var ht := Data.WALL_H * Data.PPM
	var cam: Vector2 = R.cam
	var i0: int = maxi(0, int(floor(cam.x - VIEW_C.x / pw)) - 1)
	var i1: int = mini(W - 1, int(ceil(cam.x + VIEW_C.x / pw)) + 1)
	var j0: int = maxi(0, int(floor(cam.y - VIEW_C.y / ph)) - 1)
	var j1: int = mini(H - 1, int(ceil(cam.y + (SCREEN.y - VIEW_C.y) / ph)) + 1)

	# ---- 地面 ----
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var s: Vector2 = project(R, float(i), float(j))
			if R.explored[j * W + i] == 0:
				draw_rect(Rect2(s, Vector2(pw + 1, ph + 1)), COL["bg"], true)
				continue
			var v: int = g[j * W + i]
			var c: Color = COL["floor"]
			if v == Data.TT_SLUSH:
				c = COL["slush"]
			elif v == Data.TT_COVER:
				c = Color("#1b222b")
			elif v == Data.TT_FENCE:
				c = Color("#171e26")
			elif v == Data.TT_WALL:
				c = Color("#111822")
			elif v == Data.TT_DOOR or v == Data.TT_WEDGED or v == Data.TT_BDOOR:
				c = Color("#1a212b")
			if (i * 3 + j * 5) % 11 == 0:
				c = c.lightened(0.04)
			draw_rect(Rect2(s, Vector2(pw + 1, ph + 1)), c, true)
			draw_rect(Rect2(s, Vector2(pw + 1, ph + 1)), COL["grout"], false, 1.0)
			if v == Data.TT_SLUSH and (i * 3 + j * 5) % 4 == 0:
				draw_rect(Rect2(s + Vector2(4, 3), Vector2(pw - 10, ph - 8)),
					Color(0.2, 0.34, 0.42, 0.35), true)

	# ---- 血渍 ----
	for d in R.decals:
		var ds: Vector2 = project(R, float(d["x"]), float(d["y"]))
		var dc := Color(String(d["c"]))
		dc.a = 0.62
		draw_circle(ds, 8.0, dc)
		draw_circle(ds + Vector2(5, -2), 4.5, dc)
		draw_circle(ds + Vector2(-6, 2), 3.5, dc)

	# ---- 立面（按行 y 排序，天然遮挡）----
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			if R.explored[j * W + i] == 0:
				continue
			var vv: int = g[j * W + i]
			var sp: Vector2 = project(R, float(i), float(j))
			if vv == Data.TT_WALL:
				var inner: bool = R.at(i - 1, j) == Data.TT_WALL and R.at(i + 1, j) == Data.TT_WALL \
					and R.at(i, j - 1) == Data.TT_WALL and R.at(i, j + 1) == Data.TT_WALL
				if inner:
					_draw_box(sp, pw, ph, ht, Color("#232d3b"), Color("#101620"), Color("#38465a"))
				else:
					_draw_box(sp, pw, ph, ht, COL["wallTop"], COL["wallFront"], COL["wallEdge"])
					draw_rect(Rect2(sp + Vector2(1, 1), Vector2(pw - 2, 3)),
						Color(0.89, 0.91, 0.94, 0.22), true)
					var wh: float = float((i * 37 + j * 61) % 100) / 100.0
					if wh < 0.45:
						draw_rect(Rect2(sp + Vector2(4, ph + 3), Vector2(5, 5)),
							Color("#f59e0b88"), true)
					else:
						draw_rect(Rect2(sp + Vector2(4, ph + 3), Vector2(5, 5)),
							Color("#1e293b"), true)
			elif vv == Data.TT_BDOOR:
				_draw_box(sp, pw, ph, ht * 0.9, Color("#6b4a2b"), Color("#2a1e12"), Color("#8a6a3c"))
				draw_rect(Rect2(sp + Vector2(pw * 0.45, ph * 0.3), Vector2(3, ht * 0.5)),
					Color("#1a1208"), true)
			elif vv == Data.TT_WEDGED:
				_draw_box(sp, pw, ph, ht * 0.95, COL["wedge"], Color("#2f2410"), Color("#c99b33"))
				draw_line(sp + Vector2(pw * 0.2, ph + ht * 0.55), sp + Vector2(pw * 0.8, ph + ht * 0.2),
					Color("#f59e0b"), 3.0)
			elif vv == Data.TT_DOOR:
				draw_rect(Rect2(sp, Vector2(pw + 1, ph + 1)), Color("#1a212b"), true)
				draw_rect(Rect2(sp + Vector2(0, -ht * 0.7), Vector2(pw * 0.14, ht * 0.72)),
					COL["door"], true)
				draw_rect(Rect2(sp + Vector2(pw * 0.86, -ht * 0.7), Vector2(pw * 0.14, ht * 0.72)),
					COL["door"], true)
				draw_rect(Rect2(sp + Vector2(0, -ht * 0.74), Vector2(pw, ht * 0.18)),
					Color("#3f2d1a"), true)
			elif vv == Data.TT_COVER:
				_draw_box(sp + Vector2(0, ph * 0.18), pw * 0.94, ph * 0.64, ht * 0.38,
					COL["cover"], Color("#1d242e"), Color("#556274"))
				for k in 3:
					draw_rect(Rect2(sp + Vector2(3 + k * (pw / 3.0), ph * 0.3),
						Vector2(pw * 0.16, ph * 0.4)), Color(0.45, 0.3, 0.18, 0.35), true)
			elif vv == Data.TT_FENCE:
				for k in 4:
					draw_line(sp + Vector2(k * (pw / 4.0), 0),
						sp + Vector2(k * (pw / 4.0), -ht * 0.8), COL["fence"], 1.0)
				draw_line(sp + Vector2(0, -ht * 0.8), sp + Vector2(pw, -ht * 0.8), COL["fence"], 1.0)
		# 该行容器
		for c in R.conts:
			if int(floor(float(c["y"]))) != j:
				continue
			if R.explored[j * W + int(floor(float(c["x"])))] == 0:
				continue
			_draw_container(R, c, pw, ph, ht)

	# ---- 火堆 ----
	for f in R.fires:
		var fs2: Vector2 = project(R, f.x, f.y)
		var pulse := 1.0 + sin(t * 3.1 + f.x) * 0.12
		for ring in 3:
			var rr: float = (16.0 + ring * 11.0) * pulse
			draw_circle(fs2, rr, Color(1.0, 0.55, 0.15, 0.045))
		draw_circle(fs2, 7.0, Color("#f59e0b"))
		draw_circle(fs2, 3.5, Color("#fde68a"))

	# ---- 实体 ----
	for e in R.ents:
		if e.dead:
			continue
		if R.explored[int(floor(e.y)) * W + int(floor(e.x))] == 0:
			continue
		var es: Vector2 = project(R, e.x, e.y)
		if not R.tile_visible_at(e.x, e.y) and e.kind != "mate":
			continue
		match e.kind:
			"rabid":
				_draw_rabid(es, e)
			"osk":
				_draw_osk(es, e)
			"half":
				_draw_half(es, e)
			"mate":
				draw_circle(es, 8.0, COL["mate"])
				draw_circle(es + Vector2(0, -14), 5.0, Color("#bbf7d0"))
				_draw_name(es + Vector2(0, -26), _mate_name(e.id), "#4ade80")
			"survivor":
				draw_circle(es, 8.0, COL["mate"])
	# 容器上的「暗格」提示（伊万）
	for c2 in R.conts:
		if bool(c2.get("searched", false)) or String(c2["type"]) != "hidden":
			continue
		if sim.mate != "ivan":
			continue
		var cs: Vector2 = project(R, float(c2["x"]), float(c2["y"]))
		draw_arc(cs, 14.0, 0.0, TAU, 18, Color(0.98, 0.75, 0.14, 0.6), 1.5)

	# ---- 玩家 ----
	_draw_player(R, pw, ph)

	# ---- 雾 / 已知区域压暗 ----
	for j2 in range(j0, j1 + 1):
		for i2 in range(i0, i1 + 1):
			var vis: bool = R.vis[j2 * W + i2] == 1
			if vis:
				continue
			var s3: Vector2 = project(R, float(i2), float(j2))
			var expl: bool = R.explored[j2 * W + i2] == 1
			draw_rect(Rect2(s3, Vector2(pw + 1, ph + 1)),
				Color(0.02, 0.03, 0.04, 0.55 if expl else 1.0), true)

	# ---- 视野扇形边缘柔光 ----
	if R.poly.size() > 2:
		var pts := PackedVector2Array()
		for p in R.poly:
			pts.append(project(R, p.x, p.y) + Vector2(0, -2))
		draw_colored_polygon(pts, Color(0.88, 0.94, 1.0, 0.035))

	# ---- 波纹 ----
	for r in R.ripples:
		var rs: Vector2 = project(R, r.x, r.y)
		var a2: float = clampf(1.0 - r.r / maxf(0.01, r.max_r), 0.0, 1.0) * 0.7 * r.life
		var col := Color(String(r.color))
		col.a = a2
		_ellipse_arc(rs, r.r * Data.PPM, r.r * Data.PPM * Data.SQUASH, 0.0, TAU, 30, col, 1.6)

	# ---- 飞罐 ----
	for c3 in R.thrown_cans:
		var cp: Vector2 = project(R, lerpf(c3.x, c3.tx, c3.progress), lerpf(c3.y, c3.ty, c3.progress))
		draw_rect(Rect2(cp - Vector2(4, 4), Vector2(8, 8)), Color("#94a3b8"), true)

	# ---- 浮字 ----
	for f2 in R.floats:
		var fp: Vector2 = project(R, f2.x, f2.y)
		var txt: String = String(f2.zh if sim.lang == "zh" else f2.en)
		var fs3 := 17
		var w2: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs3).x
		var fc := Color(String(f2.color))
		fc.a = clampf(f2.life, 0.0, 1.0)
		draw_string(font, fp + Vector2(-w2 / 2.0, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs3, fc)

func _draw_box(sp: Vector2, w: float, h: float, ht: float, top: Color, front: Color, edge: Color) -> void:
	draw_rect(Rect2(sp + Vector2(0, -ht), Vector2(w + 1, h + 1)), top, true)
	draw_rect(Rect2(sp + Vector2(0, -ht), Vector2(w + 1, h + 1)), edge, false, 1.0)
	draw_rect(Rect2(sp + Vector2(0, h - ht), Vector2(w + 1, ht)), front, true)
	draw_line(sp + Vector2(0, h - ht), sp + Vector2(w, h - ht), edge, 1.0)

func _draw_container(R, c: Dictionary, pw: float, ph: float, ht: float) -> void:
	var sp: Vector2 = project(R, float(c["x"]) - 0.35, float(c["y"]) - 0.35)
	var w := pw * 0.85
	var h := ph * 0.85
	var hh := ht * 0.55
	var pal := {
		"crate": [Color("#6b5232"), Color("#2e2314"), Color("#8a6a3c")],
		"locker": [Color("#3a4c60"), Color("#161d26"), Color("#4f6478")],
		"medcab": [Color("#d7dde5"), Color("#6b7280"), Color("#f1f5f9")],
		"briefcase": [Color("#4b3b2a"), Color("#1e1710"), Color("#6b5540")],
		"safe": [Color("#4a4f57"), Color("#1b1f26"), Color("#6b7280")],
		"hidden": [Color("#22303a"), Color("#0e151b"), Color("#2f4654")],
		"car": [Color("#3b4a3e"), Color("#151c18"), Color("#586e5c")],
		"dumpster": [Color("#2f4a3a"), Color("#121b16"), Color("#486b54")],
		"supply": [Color("#5c4a2e"), Color("#241c11"), Color("#7d6a45")],
		"fridge": [Color("#8fa3b3"), Color("#3b4650"), Color("#c7d4de")],
		"corpse": [Color("#3a2a28"), Color("#160f0e"), Color("#5a3f3b")],
	}
	var t := String(c.get("type", "crate"))
	var p: Array = pal.get(t, pal["crate"])
	if bool(c.get("searched", false)):
		p = [Color("#25292e"), Color("#12151a"), Color("#2f353c")]
	_draw_box(sp, w, h, hh, p[0], p[1], p[2])
	if t == "medcab" and not bool(c.get("searched", false)):
		draw_rect(Rect2(sp + Vector2(w * 0.4, -hh * 0.65), Vector2(w * 0.2, hh * 0.2)),
			Color("#ef4444"), true)
	if t == "hidden" and not bool(c.get("searched", false)) and sim.mate == "ivan":
		draw_arc(sp + Vector2(w * 0.5, -hh * 0.6), 12.0, 0.0, TAU, 16,
			Color(0.98, 0.75, 0.14, 0.75), 2.0)

func _draw_player(R, pw: float, ph: float) -> void:
	var p = R.player
	var s: Vector2 = project(R, p.x, p.y)
	# 影子
	draw_circle(s + Vector2(0, 2), 9.0 * (1.0 if not p.sneak else 0.85),
		Color(0.0, 0.0, 0.0, 0.45))
	# 光锥
	var half: float = Data.FOV_DEG * PI / 360.0
	var rng_vis: float = R.sight_range
	var pts := PackedVector2Array([s + Vector2(0, -4)])
	for k in range(0, 25):
		var a: float = p.face - half + 2.0 * half * float(k) / 24.0
		pts.append(s + Vector2(cos(a) * rng_vis * pw, sin(a) * rng_vis * ph) + Vector2(0, -4))
	var gc := Color(0.85, 0.93, 1.0, 0.05)
	draw_colored_polygon(pts, gc)
	# 躯干
	var body := COL["player"]
	if p.hurt > 0.0:
		body = Color("#fecaca")
	draw_circle(s + Vector2(0, -10), 10.0, Color("#0b0f14"))
	draw_circle(s + Vector2(0, -10), 8.0, body)
	draw_circle(s + Vector2(0, -22), 6.0, Color("#cbd5e1"))
	var aim: Vector2 = Vector2(cos(p.face), sin(p.face) * Data.SQUASH)
	draw_line(s + Vector2(0, -12), s + Vector2(0, -12) + aim * 22.0, Color("#94a3b8"), 2.0)
	# 头顶血条（只在受伤时）
	if p.hp < 100.0:
		var wgt := 34.0
		draw_rect(Rect2(s + Vector2(-wgt / 2.0, -40), Vector2(wgt, 4)), Color(0.0, 0.0, 0.0, 0.6), true)
		draw_rect(Rect2(s + Vector2(-wgt / 2.0, -40), Vector2(wgt * clampf(p.hp / 100.0, 0.0, 1.0), 4)),
			COL["good"] if p.hp > 45.0 else COL["bad"], true)

func _draw_rabid(s: Vector2, e) -> void:
	var c := COL["rabid"].darkened(0.15 if e.brute else 0.0)
	draw_circle(s + Vector2(0, 2), 11.0 if e.brute else 9.0, Color(0.0, 0.0, 0.0, 0.5))
	draw_circle(s + Vector2(0, -8), 10.0 if e.brute else 8.0, c)
	draw_circle(s + Vector2(0, -18), 5.5, Color("#fca5a5"))
	# 撕咬前摇
	if float(e.bite) > 0.2:
		draw_arc(s + Vector2(0, -8), 16.0, -0.7, 0.7, 8, Color(1.0, 0.4, 0.4, 0.7), 2.0)
	if float(e.hit_flash) > 0.0:
		draw_circle(s + Vector2(0, -8), 12.0, Color(1.0, 1.0, 1.0, 0.35))
	if e.state == "chase":
		draw_string(font, s + Vector2(-8, -34), "!",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#ef4444"))

func _draw_osk(s: Vector2, e) -> void:
	draw_circle(s + Vector2(0, 2), 9.0, Color(0.0, 0.0, 0.0, 0.5))
	draw_circle(s + Vector2(0, -8), 8.0, Color("#1f3346"))
	draw_circle(s + Vector2(0, -8), 8.0, COL["osk"], false, 2.0)
	draw_circle(s + Vector2(0, -18), 5.0, Color("#0f1b26"))
	# 手电锥
	var half: float = 22.5 * PI / 180.0
	var cone := PackedVector2Array([s + Vector2(0, -10)])
	for k in range(0, 15):
		var a: float = float(e.face) - half + 2.0 * half * float(k) / 14.0
		cone.append(s + Vector2(cos(a) * 14.0 * Data.PPM, sin(a) * 14.0 * Data.PPM * Data.SQUASH) + Vector2(0, -10))
	draw_colored_polygon(cone, Color(0.55, 0.83, 0.98, 0.055 + 0.06 * clampf(float(e.suspect), 0.0, 1.0)))
	draw_line(s + Vector2(0, -10), s + Vector2(0, -10) +
		Vector2(cos(e.face), sin(e.face) * Data.SQUASH) * 20.0, COL["osk"], 2.0)
	if float(e.lock) > 0.05:
		draw_arc(s + Vector2(0, -8), 13.0, -PI / 2, -PI / 2 + TAU * clampf(float(e.lock), 0.0, 1.0),
			18, Color("#7dd3fc"), 2.0)

func _draw_half(s: Vector2, e) -> void:
	var a := 0.85 + sin(float(e.ph) * 2.0) * 0.1
	draw_circle(s + Vector2(0, 2), 7.0, Color(0.0, 0.0, 0.0, 0.4))
	draw_circle(s + Vector2(0, -6), 6.5, Color(0.96, 0.62, 0.04, a))
	draw_circle(s + Vector2(0, -14), 4.5, Color(0.99, 0.78, 0.3, a))
	if sim.mate == "anna":
		_draw_name(s + Vector2(0, -26), "0419 · 半人", "#f59e0b")
	elif e.used:
		_draw_name(s + Vector2(0, -26), "已救助", "#34d399")

func _draw_name(pos: Vector2, txt: String, hex: String) -> void:
	var c := Color(hex)
	c.a = 0.85
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(font, pos + Vector2(-w / 2.0, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, c)

func _mate_name(id: String) -> String:
	var m: Dictionary = Data.mate(id)
	return String(m.get("zh" if sim.lang == "zh" else "en", id))

func _ellipse_arc(c: Vector2, rx: float, ry: float, a0: float, a1: float, steps: int,
		col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for k in range(steps + 1):
		var a: float = a0 + (a1 - a0) * float(k) / float(steps)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, col, width, true)

func _draw_raid_overlays() -> void:
	var R = sim.raid
	if R == null:
		return
	var p = R.player
	# 受伤红边
	if p.hp < 40.0 or p.hurt > 0.0:
		var a := clampf((40.0 - p.hp) / 60.0, 0.0, 0.55)
		draw_rect(Rect2(0, TOP, SCREEN.x, SCREEN.y - TOP), Color(0.94, 0.27, 0.27, a * 0.22), true)
		for k in 4:
			draw_rect(Rect2(0, TOP + k * 6, SCREEN.x, 6), Color(0.94, 0.27, 0.27, a * 0.10), true)
	# 失温蓝边
	if p.warmth < 35.0:
		var a2 := clampf((35.0 - p.warmth) / 35.0, 0.0, 1.0) * 0.22
		draw_rect(Rect2(0, TOP, SCREEN.x, SCREEN.y - TOP), Color(0.49, 0.83, 0.99, a2 * 0.5), true)
		for k in 4:
			draw_rect(Rect2(0, SCREEN.y - (k + 1) * 7, SCREEN.x, 7), Color(0.49, 0.83, 0.99, a2 * 0.2), true)
	# 交互进度环
	if R.search_prog > 0.0:
		_ellipse_arc(VIEW_C, 120.0, 40.0, -PI / 2, -PI / 2 + TAU * R.search_prog, 40,
			Color(0.98, 0.85, 0.4, 0.85), 4.0)
	if R.extract_prog > 0.0:
		_ellipse_arc(project(R, R.entry.x, R.entry.y), 26.0, 18.0, -PI / 2,
			-PI / 2 + TAU * R.extract_prog, 30, Color(0.2, 0.9, 0.5, 0.9), 3.0)
	if R.wedge_prog > 0.0:
		_ellipse_arc(VIEW_C, 90.0, 30.0, -PI / 2, -PI / 2 + TAU * R.wedge_prog, 32,
			Color(0.98, 0.75, 0.14, 0.9), 4.0)
	if R.bdoor_prog > 0.0:
		_ellipse_arc(VIEW_C, 90.0, 30.0, -PI / 2, -PI / 2 + TAU * R.bdoor_prog, 32,
			Color(0.75, 0.6, 0.3, 0.9), 4.0)

