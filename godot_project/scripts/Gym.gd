extends Node2D
## Gym.gd — 5 合 1 灰盒测试场渲染 / 输入层。
##
## 与 HTML 原型相同的「单画布立即模式」思路：Sim（RefCounted 纯数据）每帧更新，
## 这里在 _draw() 里按 HTML renderGame() 的顺序绘制 5 个房间、探照灯锥、视野扇形、
## 声波波纹、子弹曳光、飞罐、浮字与靴印。HUD 是唯一的 CanvasLayer。
##
## 逻辑世界固定 1100×680（与 HTML WORLD_W/WORLD_H 一致），按 16:9 视口等比缩放后
## 居中到 VIEW_AREA；HUD 侧栏占据右侧 352px，因此世界不会被 HUD 挡住。

const SimScript := preload("res://scripts/GymSim.gd")
const HudScript := preload("res://scripts/GymHUD.gd")
const SfxScript := preload("res://scripts/Sfx.gd")

# 世界绘制区域（右侧留给 HUD 侧栏）
const VIEW_AREA := Rect2(10, 74, 1540, 992)

var sim
var hud
var sfx
var _f2_latch := false
# 手机触屏：左半屏虚拟摇杆移动，右半屏拖动瞄准、轻点挥刀。
var _touch_move_id := -1
var _touch_move_origin := Vector2.ZERO
var _touch_move_vec := Vector2.ZERO
var _touch_aim_id := -1
var _touch_aim_pos := Vector2.ZERO
var _touch_aim_start := Vector2.ZERO
var _touch_aim_press_ms := 0
var font: SystemFont

var view_scale: float = 1.0
var view_origin: Vector2 = Vector2(10, 74)

func _ready() -> void:
	sim = SimScript.new()
	font = SystemFont.new()
	font.font_names = PackedStringArray([
		"Noto Sans CJK SC", "Noto Sans SC", "Microsoft YaHei", "SimHei",
		"PingFang SC", "Segoe UI", "Arial",
	])
	hud = HudScript.new()
	add_child(hud)
	hud.bind_sim(sim)
	if hud.has_signal("ui_sfx"):
		hud.connect("ui_sfx", Callable(self, "_on_ui_sfx"))
	sfx = SfxScript.new()
	add_child(sfx)

# ============================================================================
# 主循环
# ============================================================================
func _process(delta: float) -> void:
	if sim == null:
		return
	_recalc_view()
	_handle_keys()
	var mouse_pos := get_viewport().get_mouse_position()
	if _touch_aim_id >= 0:
		mouse_pos = _touch_aim_pos
	var mouse_world := screen_to_world(mouse_pos)
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _touch_move_id >= 0:
		move = _touch_move_vec
	var sprinting := Input.is_action_pressed("sprint") or (_touch_move_id >= 0 and _touch_move_vec.length() > 0.95)
	sim.update(delta, move, sprinting, mouse_world)
	_drain_sfx()
	hud.refresh()
	queue_redraw()

func _handle_keys() -> void:
	if Input.is_action_just_pressed("crouch"):
		sim.toggle_crouch()
	if Input.is_action_just_pressed("throw_can"):
		sim.throw_can()
	if Input.is_action_just_pressed("interact"):
		sim.interact()
	if Input.is_action_just_pressed("drink"):
		sim.drink()
	if Input.is_action_just_pressed("toggle_logbook"):
		sim.toggle_logbook()
	if Input.is_action_just_pressed("gym_toggle_lang"):
		sim.toggle_lang()
	if Input.is_action_just_pressed("gym_toggle_glasses"):
		sim.toggle_glasses()
	if Input.is_action_just_pressed("gym_toggle_mute"):
		sim.toggle_mute()
		if sfx != null:
			sfx.set_muted(sim.muted)
	if Input.is_action_just_pressed("gym_reset"):
		sim.reset()
		_drain_sfx()
	if Input.is_action_just_pressed("gym_switch_scene"):
		# F1：回到战役主循环（一夜：基地 / 地图 / 夜潜 / 结算）
		get_tree().change_scene_to_file("res://scenes/campaign.tscn")
		return
	if Input.is_physical_key_pressed(KEY_F2) and not _f2_latch:
		_f2_latch = true
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	_f2_latch = Input.is_physical_key_pressed(KEY_F2)
	if Input.is_action_just_pressed("ui_cancel"):
		if sim.logbook_open:
			sim.logbook_open = false
		elif sim.choice_modal_open:
			sim.choose_a("A2")
	for i in 5:
		if Input.is_action_just_pressed("gym_room_%d" % (i + 1)):
			sim.teleport("ABCDE"[i])

func _unhandled_input(event: InputEvent) -> void:
	if sim == null:
		return
	if sim.logbook_open or sim.choice_modal_open:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not VIEW_AREA.has_point(touch.position):
			return
		if touch.pressed:
			if touch.position.x < VIEW_AREA.position.x + VIEW_AREA.size.x * 0.35 and _touch_move_id < 0:
				_touch_move_id = touch.index
				_touch_move_origin = touch.position
				_touch_move_vec = Vector2.ZERO
				get_viewport().set_input_as_handled()
			elif _touch_aim_id < 0:
				_touch_aim_id = touch.index
				_touch_aim_pos = touch.position
				_touch_aim_start = touch.position
				_touch_aim_press_ms = Time.get_ticks_msec()
				get_viewport().set_input_as_handled()
		else:
			if touch.index == _touch_move_id:
				_touch_move_id = -1
				_touch_move_vec = Vector2.ZERO
				get_viewport().set_input_as_handled()
			elif touch.index == _touch_aim_id:
				var tapped := touch.position.distance_to(_touch_aim_start) < 24.0 and Time.get_ticks_msec() - _touch_aim_press_ms < 400
				_touch_aim_id = -1
				if tapped:
					sim.swing()
				get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_move_id:
			var d := drag.position - _touch_move_origin
			if d.length() > 60.0:
				d = d.normalized() * 60.0
			_touch_move_vec = d / 60.0
			get_viewport().set_input_as_handled()
		elif drag.index == _touch_aim_id:
			_touch_aim_pos = drag.position
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not VIEW_AREA.has_point(mb.position):
			return
	if event.is_action_pressed("attack_primary"):
		sim.swing()
		get_viewport().set_input_as_handled()

func _on_ui_sfx(name: String) -> void:
	if sfx != null:
		sfx.play(name)

func _drain_sfx() -> void:
	if sfx == null or sim == null:
		return
	for name in sim.drain_sfx():
		sfx.play(name)

# ============================================================================
# 视口变换（逻辑 1100×680 → 屏幕）
# ============================================================================
func _recalc_view() -> void:
	var vp := get_viewport_rect().size
	view_scale = minf(VIEW_AREA.size.x / SimScript.WORLD_W, VIEW_AREA.size.y / SimScript.WORLD_H)
	var draw_size := Vector2(SimScript.WORLD_W, SimScript.WORLD_H) * view_scale
	view_origin = VIEW_AREA.position + (VIEW_AREA.size - draw_size) * 0.5

func screen_to_world(sp: Vector2) -> Vector2:
	return (sp - view_origin) / maxf(view_scale, 0.001)

func world_to_screen(wp: Vector2) -> Vector2:
	return view_origin + wp * view_scale

# ============================================================================
# 立即模式绘制
# ============================================================================
func _draw() -> void:
	if sim == null:
		return
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color("05070b"))
	# 世界外框
	draw_rect(VIEW_AREA, Color("0b1119"))
	draw_rect(VIEW_AREA.grow(1.0), Color("1c2634"), false, 1.0)

	draw_set_transform(view_origin, 0.0, Vector2(view_scale, view_scale))
	draw_rect(Rect2(0, 0, SimScript.WORLD_W, SimScript.WORLD_H), Color("080b10"))

	_draw_rooms()
	_draw_room_a_env()
	_draw_bootprints()
	_draw_room_b()
	_draw_room_c()
	_draw_room_d()
	_draw_room_e()
	_draw_searchlight()
	_draw_soldier()
	_draw_rabids()
	_draw_dog()
	_draw_player_vision()
	_draw_player()
	_draw_bullets()
	_draw_thrown_cans()
	_draw_ripples()
	_draw_floats()
	_draw_overlays()

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_touch_controls()

# ----------------------------------------------------------------------------
# 房间底板 / 网格 / 标题
# ----------------------------------------------------------------------------
func _draw_rooms() -> void:
	for rm in SimScript.ROOM_ZONES:
		var r: Rect2 = rm["rect"]
		var active: bool = sim.current_room()["id"] == rm["id"]
		draw_rect(r, Color("10151e"))
		# 40px 网格
		var gx := r.position.x + 40.0
		while gx < r.position.x + r.size.x:
			draw_line(Vector2(gx, r.position.y), Vector2(gx, r.position.y + r.size.y),
				Color(0.35, 0.45, 0.58, 0.07), 1.0)
			gx += 40.0
		var gy := r.position.y + 40.0
		while gy < r.position.y + r.size.y:
			draw_line(Vector2(r.position.x, gy), Vector2(r.position.x + r.size.x, gy),
				Color(0.35, 0.45, 0.58, 0.07), 1.0)
			gy += 40.0
		draw_rect(r, Color("2b3648"), false, 2.5)
		if active:
			draw_rect(r, Color(0.96, 0.62, 0.04, 0.55), false, 3.0)
		var title: String = rm["zh"] if sim.lang == "zh" else rm["en"]
		_text(r.position + Vector2(12, 22), title, 12, Color(0.58, 0.64, 0.71, 0.85))

# ----------------------------------------------------------------------------
# Room A：冻雪泥 + 高架蒸汽管 + 隐匿阴影带
# ----------------------------------------------------------------------------
func _draw_room_a_env() -> void:
	var slush: Rect2 = SimScript.SLUSH_RECT
	draw_rect(slush, Color(0.05, 0.45, 0.56, 0.28))
	draw_rect(slush, Color("0891b2"), false, 1.5)
	var x0 := slush.position.x + 6.0
	while x0 < slush.position.x + slush.size.x:
		draw_line(Vector2(x0, slush.position.y), Vector2(x0 + 8.0, slush.position.y),
			Color("0891b2"), 1.5)
		draw_line(Vector2(x0, slush.position.y + slush.size.y),
			Vector2(x0 + 8.0, slush.position.y + slush.size.y), Color("0891b2"), 1.5)
		x0 += 14.0
	_text(slush.position + Vector2(10, 20),
		sim.tr2("冻雪泥坑（减速35% / 留靴印）", "Frozen Slush (-35% Spd)"),
		10, Color("67e8f9"))

	var pipe: Rect2 = SimScript.STEAM_PIPE_RECT
	var shadow := Rect2(pipe.position.x - 10.0, pipe.position.y - 12.0,
		pipe.size.x + 20.0, pipe.size.y + 34.0)
	draw_rect(shadow, Color(0.06, 0.09, 0.16, 0.85))
	if sim.player.in_pipe_shadow:
		draw_rect(shadow, Color(0.13, 0.83, 0.93, 0.75), false, 2.0)
		_text(shadow.position + Vector2(6, shadow.size.y - 8),
			sim.tr2("隐匿中 · 探照灯 100% 免疫", "HIDDEN · 100% Light Immunity"),
			10, Color("67e8f9"))

	draw_rect(pipe, Color("475569"))
	draw_rect(pipe, Color("94a3b8"), false, 2.0)
	draw_rect(Rect2(pipe.position + Vector2(0, 6), Vector2(pipe.size.x, 4)), Color(0.12, 0.16, 0.22, 0.8))
	var cap_x := pipe.position.x
	while cap_x < pipe.position.x + pipe.size.x:
		draw_line(Vector2(cap_x, pipe.position.y), Vector2(cap_x, pipe.position.y + pipe.size.y),
			Color(0.70, 0.77, 0.85, 0.45), 1.0)
		cap_x += 28.0
	_text(pipe.position + Vector2(6, 16),
		sim.tr2("高架供暖蒸汽管（按 Ctrl 蹲伏隐匿）", "Steam Pipe (Hold Ctrl to Hide)"),
		10, Color("f8fafc"))

func _draw_bootprints() -> void:
	for bp in sim.bootprints:
		var a: float = clampf(bp.life / 300.0, 0.0, 1.0)
		draw_circle(Vector2(bp.x, bp.y), 3.0, Color(0.22, 0.74, 0.98, a))

# ----------------------------------------------------------------------------
# Room B：变形铁门 + 12cm 铁丝网底缝 + 铝饭盒
# ----------------------------------------------------------------------------
func _draw_room_b() -> void:
	var db = sim.door_b
	var wedged: bool = db.wedge_frames > 0.0
	draw_rect(Rect2(db.x, db.y, db.w, db.h), Color("d97706") if wedged else Color("334155"))
	draw_rect(Rect2(db.x, db.y, db.w, db.h), Color("fde047") if wedged else Color("94a3b8"), false, 2.0)
	var door_label := ""
	if wedged:
		door_label = sim.tr2("🔒 撬棍已卡死 (%.1fs)" % sim.wedge_seconds(),
			"🔒 Wedged (%.1fs)" % sim.wedge_seconds())
	else:
		door_label = sim.tr2("变形铁门 [按E用撬棍卡死]", "Steel Door [Press E to Wedge]")
	_text_c(Vector2(db.x + db.w * 0.5, db.y - 8.0), door_label, 10, Color("fde047"))

	var fl = sim.fence_box
	var fx: float = fl.x + 18.0
	var fy := 175.0
	while fy < 300.0:
		draw_line(Vector2(fx, fy), Vector2(fx, fy + 6.0), Color("94a3b8"), 1.5)
		fy += 10.0
	draw_line(Vector2(fx, 175.0), Vector2(fx, 300.0), Color(0.58, 0.65, 0.71, 0.25), 1.0)
	# 12cm 门底缝
	draw_line(Vector2(fl.x - 6.0, fl.y + 4.0), Vector2(fl.x + 40.0, fl.y + 4.0), Color("64748b"), 3.0)

	var box_pos := Vector2(fl.x + 30.0, fl.y - 8.0) if fl.delivered else Vector2(fl.x - 12.0, fl.y - 8.0)
	draw_rect(Rect2(box_pos, Vector2(16, 14)), Color("10b981") if fl.delivered else Color("f59e0b"))
	draw_rect(Rect2(box_pos + Vector2(3, 4), Vector2(10, 2)), Color(0.85, 0.9, 0.95, 0.55))
	var fl_label := ""
	if fl.delivered:
		fl_label = sim.tr2("✅ 铝饭盒已推入12cm窄缝", "✅ Lunchbox Pushed Under Gap")
	else:
		fl_label = sim.tr2("铝饭盒 [按E推过12cm铁网底缝]", "Lunchbox [Press E to Push]")
	_text_c(Vector2(fl.x, fl.y - 16.0), fl_label, 10, Color("e2e8f0"))

# ----------------------------------------------------------------------------
# Room C：电传终端 + 回退半人
# ----------------------------------------------------------------------------
func _draw_room_c() -> void:
	var st = sim.terminal
	var term_col: Color = Color("065f46") if st.recorded else Color("1e293b")
	var term_edge: Color = Color("34d399") if st.recorded else Color("ef4444")
	var tr := Rect2(st.x - 22.0, st.y - 16.0, 44.0, 32.0)
	draw_rect(tr, term_col)
	draw_rect(tr, term_edge, false, 2.0)
	# 电传指示灯
	draw_circle(Vector2(st.x + 15.0, st.y - 10.0), 2.2, Color("f87171") if not st.recorded else Color("6ee7b7"))
	for i in 3:
		draw_line(Vector2(st.x - 16.0, st.y - 6.0 + i * 7.0),
			Vector2(st.x + 6.0, st.y - 6.0 + i * 7.0),
			Color(0.45, 0.65, 0.55, 0.45), 1.0)
	var term_label := ""
	if st.recorded:
		term_label = sim.tr2("✓ 已手写记录谢尔盖母子真名", "✓ Sergey & Maria Recorded")
	else:
		term_label = sim.tr2("电传机报错:0人 [按E写下真名]", "Terminal: 0 Persons [Press E]")
	_text_c(Vector2(st.x, st.y - 24.0), term_label, 10,
		Color("6ee7b7") if st.recorded else Color("fca5a5"))

	var hh = sim.half_human
	var hh_col := Color("eab308")
	if hh.status == "saved_A1":
		hh_col = Color("10b981")
	elif hh.status == "killed_A3":
		hh_col = Color("7f1d1d")
	draw_circle(Vector2(hh.x, hh.y), 12.0, hh_col)
	draw_arc(Vector2(hh.x, hh.y), 15.0, 0, TAU, 28, Color(0.98, 0.94, 0.55, 0.55), 1.5, true)
	draw_circle(Vector2(hh.x - 3.0, hh.y - 3.0), 1.6, Color(0.16, 0.12, 0.05, 0.8))
	draw_circle(Vector2(hh.x + 3.0, hh.y - 3.0), 1.6, Color(0.16, 0.12, 0.05, 0.8))
	var hh_label := ""
	match hh.status:
		"saved_A1":
			hh_label = sim.tr2("已退烧半人（已告知拉娜线索）", "Recovered Youth (Shared Clue)")
		"killed_A3":
			hh_label = sim.tr2("已灭口 (+2道卌划痕)", "Executed (+2 Strokes)")
		_:
			hh_label = sim.tr2("回退期半人 [按E触发抉择A]", "Regressing Youth [Press E: Choice A]")
	_text_c(Vector2(hh.x, hh.y - 20.0), hh_label, 10,
		Color("6ee7b7") if hh.status == "saved_A1" else (Color("fca5a5") if hh.status == "killed_A3" else Color("fef08a")))

# ----------------------------------------------------------------------------
# Room D：三座铁笼（狼犬三态嗅觉测试）
# ----------------------------------------------------------------------------
func _draw_room_d() -> void:
	for cg in sim.cages:
		var edge := Color("ef4444")
		var fill := Color("dc2626")
		var lab := ""
		match cg.kind:
			"anna":
				edge = Color("38bdf8")
				fill = Color("0284c7")
				lab = sim.tr2("Ⅱ号笼：皮带自缚的安娜 (0419)", "Cage II: Self-Bound Anna (0419)")
			"father":
				edge = Color("10b981")
				fill = Color("059669")
				lab = sim.tr2("Ⅲ号笼：绑红袋送胰岛素的父亲", "Cage III: Father w/ Red Strip & Insulin")
			_:
				edge = Color("ef4444")
				fill = Color("dc2626")
				lab = sim.tr2("Ⅰ号笼：高热狂暴者 (>40℃)", "Cage I: Febrile Rabid (>40°C)")
		var cr := Rect2(cg.x - 48.0, cg.y - 34.0, 96.0, 68.0)
		draw_rect(cr, Color("17202c"))
		draw_rect(cr, edge, false, 2.0)
		# 铁栏
		var bx := cr.position.x + 8.0
		while bx < cr.position.x + cr.size.x - 4.0:
			draw_line(Vector2(bx, cr.position.y + 2.0), Vector2(bx, cr.position.y + cr.size.y - 2.0),
				Color(edge, 0.20), 1.0)
			bx += 12.0
		draw_circle(Vector2(cg.x, cg.y), 10.0, fill)
		if cg.kind == "anna":
			# 皮带自缚的双腕
			draw_arc(Vector2(cg.x, cg.y + 14.0), 11.0, 0.2, PI - 0.2, 18, Color("f472b6"), 2.0, true)
		_text_c(Vector2(cg.x, cg.y - 42.0), lab, 10, Color("f1f5f9"))
		if cg.kind == "anna":
			_text_c(Vector2(cg.x, cg.y + 48.0),
				sim.tr2("[靠近按E询问妹妹拉娜下落]", "[Press E to Ask About Sister Lana]"),
				9, Color("7dd3fc") if not cg.inspected else Color(0.45, 0.83, 0.98, 0.55))

# ----------------------------------------------------------------------------
# Room E：备餐砧板 + 杂物间 + 瓦西里
# ----------------------------------------------------------------------------
func _draw_room_e() -> void:
	var cp = sim.cleaver
	var cr := Rect2(cp.x - 42.0, cp.y - 20.0, 84.0, 40.0)
	draw_rect(cr, Color("291d18"))
	draw_rect(cr, Color("64748b") if cp.taken else Color("f59e0b"), false, 2.0)
	var bx := cr.position.x + 6.0
	while bx < cr.position.x + cr.size.x - 4.0:
		draw_line(Vector2(bx, cr.position.y + 4.0), Vector2(bx, cr.position.y + cr.size.y - 4.0),
			Color(0.55, 0.32, 0.18, 0.35), 1.0)
		bx += 10.0
	if not cp.taken:
		# 砍骨刀
		draw_rect(Rect2(cp.x - 16.0, cp.y - 4.0, 26.0, 8.0), Color("d6d3d1"))
		draw_rect(Rect2(cp.x + 8.0, cp.y - 2.0, 14.0, 4.0), Color("292524"))
	_text_c(Vector2(cp.x, cp.y - 28.0),
		sim.tr2("备餐砧板 (已拿取砍骨刀)", "Butcher Block (Cleaver Taken)") if cp.taken
			else sim.tr2("🔪 备餐砧板 [按E拾取砍骨刀]", "🔪 Butcher Block [Press E for Cleaver]"),
		10, Color("94a3b8") if cp.taken else Color("fde047"))

	# 杂物间门框
	draw_rect(Rect2(1006, 430, 16, 130), Color("1f2937"))
	draw_rect(Rect2(1006, 430, 16, 130), Color(0.42, 0.33, 0.24, 0.9), false, 2.0)

	var vas = sim.vasily
	var vcol := Color("991b1b")
	if vas.state == "resolved":
		vcol = Color("0284c7")
	elif vas.state == "charging" or vas.state == "jammed":
		vcol = Color("ef4444")
	draw_circle(Vector2(vas.x, vas.y), 13.0, vcol)
	draw_arc(Vector2(vas.x, vas.y), 16.0, 0, TAU, 30,
		Color("7dd3fc") if vas.state == "resolved" else Color("fca5a5"), 2.0, true)
	if vas.state == "resolved":
		# 瞳孔回色后的蓝眼睛
		draw_circle(Vector2(vas.x - 4.0, vas.y - 3.0), 2.0, Color("7dd3fc"))
		draw_circle(Vector2(vas.x + 4.0, vas.y - 3.0), 2.0, Color("7dd3fc"))
	var vlabel := ""
	if vas.state == "resolved":
		vlabel = sim.tr2("瓦西里（瞳孔回色·“……Пить渴……”）", "Vasily (Eyes Clear · '…Пить…')")
	else:
		vlabel = sim.tr2("瓦西里（40℃高烧谵妄）[按Space挥刀]", "Vasily (40°C Delirium) [Press Space]")
	_text_c(Vector2(vas.x, vas.y - 24.0), vlabel, 10,
		Color("7dd3fc") if vas.state == "resolved" else Color("f8fafc"))
	if vas.state == "jammed":
		_text_c(Vector2(vas.x, vas.y + 32.0),
			sim.tr2("刀卡在锁骨里！连按 6 次拔出！", "BLADE JAMMED! MASH 6 TIMES!"),
			11, Color("ef4444"))

# ----------------------------------------------------------------------------
# 探照灯 / 士兵 / 狂暴者 / 狼犬
# ----------------------------------------------------------------------------
func _draw_searchlight() -> void:
	var osk = sim.soldier
	var half := 0.39
	var n := 22
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	pts.append(Vector2(osk.x, osk.y))
	cols.append(Color(0.996, 0.941, 0.541, 0.42 if osk.alert_frames > 0.0 else 0.34))
	for k in n + 1:
		var a: float = osk.angle - half + 2.0 * half * (float(k) / float(n))
		pts.append(Vector2(osk.x + cos(a) * 245.0, osk.y + sin(a) * 245.0))
		cols.append(Color(0.98, 0.80, 0.08, 0.0))
	draw_polygon(pts, cols)
	# 锥体边界
	draw_line(Vector2(osk.x, osk.y),
		Vector2(osk.x + cos(osk.angle - half) * 245.0, osk.y + sin(osk.angle - half) * 245.0),
		Color(0.98, 0.86, 0.30, 0.35), 1.0)
	draw_line(Vector2(osk.x, osk.y),
		Vector2(osk.x + cos(osk.angle + half) * 245.0, osk.y + sin(osk.angle + half) * 245.0),
		Color(0.98, 0.86, 0.30, 0.35), 1.0)

func _draw_soldier() -> void:
	var osk = sim.soldier
	var alerting: bool = osk.alert_frames > 0.0
	draw_circle(Vector2(osk.x, osk.y), 12.0, Color("64748b"))
	draw_arc(Vector2(osk.x, osk.y), 13.0, 0, TAU, 28,
		Color("f87171") if alerting else Color("facc15"), 2.0, true)
	# 防毒面具眼片 + 肩灯
	draw_rect(Rect2(osk.x - 6.0, osk.y - 4.0, 12.0, 5.0), Color("0f172a"))
	draw_circle(Vector2(osk.x, osk.y - 1.0), 1.6, Color("fde68a"))
	draw_line(Vector2(osk.x, osk.y), Vector2(osk.x + cos(osk.angle) * 18.0, osk.y + sin(osk.angle) * 18.0),
		Color("0f172a"), 3.0)
	_text_c(Vector2(osk.x, osk.y - 18.0),
		sim.tr2("内务清杀兵(ОСК)", "O.S.K. Purge Soldier"), 10, Color("fef08a"))
	if alerting:
		_text_c(Vector2(osk.x, osk.y - 30.0),
			sim.tr2("⚠ 转向声源调查", "⚠ Investigating Noise"), 9, Color("fca5a5"))

func _draw_rabids() -> void:
	for rab in sim.rabids:
		if rab.alive:
			draw_circle(Vector2(rab.x, rab.y), 11.0, Color("dc2626"))
			draw_arc(Vector2(rab.x, rab.y), 12.0, 0, TAU, 24, Color("fca5a5"), 2.0, true)
			# 灰鳞剥落的肩
			draw_circle(Vector2(rab.x - 6.0, rab.y + 4.0), 2.4, Color("a8a29e"))
			draw_circle(Vector2(rab.x + 6.0, rab.y + 4.0), 2.4, Color("a8a29e"))
			draw_circle(Vector2(rab.x - 4.0, rab.y - 3.0), 1.5, Color("fef2f2"))
			draw_circle(Vector2(rab.x + 4.0, rab.y - 3.0), 1.5, Color("fef2f2"))
			_text_c(Vector2(rab.x, rab.y - 16.0),
				sim.tr2("灰鳞狂暴者 (%d%%)" % int(rab.hp), "Rabid (%d%%)" % int(rab.hp)),
				10, Color("fca5a5"))
		else:
			draw_circle(Vector2(rab.x, rab.y), 10.0, Color("334155"))
			draw_circle(Vector2(rab.x - 7.0, rab.y + 6.0), 4.0, Color(0.45, 0.06, 0.06, 0.55))
			_text_c(Vector2(rab.x, rab.y - 16.0),
				sim.tr2("已借刀清除", "Eliminated"), 9, Color("94a3b8"))

func _draw_dog() -> void:
	var d = sim.dog
	var col := Color("94a3b8")
	match d.state:
		"bark":
			col = Color("ef4444")
		"whimper":
			col = Color("f59e0b")
		"wag":
			col = Color("34d399")
	draw_circle(Vector2(d.x, d.y), 8.0, col)
	draw_arc(Vector2(d.x, d.y), 9.0, 0, TAU, 20, Color("f8fafc"), 1.8, true)
	# 耳朵
	draw_line(Vector2(d.x - 5.0, d.y - 6.0), Vector2(d.x - 8.0, d.y - 12.0), col, 2.0)
	draw_line(Vector2(d.x + 5.0, d.y - 6.0), Vector2(d.x + 8.0, d.y - 12.0), col, 2.0)
	var tag := ""
	match d.state:
		"bark":
			tag = sim.tr2("狂吠!", "BARK!")
		"whimper":
			tag = sim.tr2("低鸣…", "WHIMPER…")
		"wag":
			tag = sim.tr2("摇尾", "TAIL WAG")
		_:
			tag = ""
	_text_c(Vector2(d.x, d.y - 14.0), sim.tr2("灰烬(Пепел)", "Ash (Пепел)"), 9, Color("cbd5e1"))
	if tag != "":
		_text_c(Vector2(d.x, d.y - 25.0), tag, 9, col)

# ----------------------------------------------------------------------------
# 玩家：90° 视野扇形 + 挥击弧
# ----------------------------------------------------------------------------
func _draw_player_vision() -> void:
	var p = sim.player
	var radius: float = sim.vision_radius()
	var half := PI / 4.0
	var n := 24
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	pts.append(Vector2(p.x, p.y))
	var apex_col := Color(0.23, 0.51, 0.96, 0.26)
	if sim.glasses_cracked:
		apex_col = Color(0.96, 0.25, 0.37, 0.20)
	cols.append(apex_col)
	var rim_col := Color(0.23, 0.51, 0.96, 0.0)
	if sim.glasses_cracked:
		rim_col = Color(0.96, 0.25, 0.37, 0.0)
	for k in n + 1:
		var a: float = p.angle - half + 2.0 * half * (float(k) / float(n))
		pts.append(Vector2(p.x + cos(a) * radius, p.y + sin(a) * radius))
		cols.append(rim_col)
	draw_polygon(pts, cols)
	# 扇形边缘
	draw_line(Vector2(p.x, p.y), Vector2(p.x + cos(p.angle - half) * radius, p.y + sin(p.angle - half) * radius),
		Color(0.38, 0.65, 0.98, 0.35), 1.0)
	draw_line(Vector2(p.x, p.y), Vector2(p.x + cos(p.angle + half) * radius, p.y + sin(p.angle + half) * radius),
		Color(0.38, 0.65, 0.98, 0.35), 1.0)

func _draw_player() -> void:
	var p = sim.player
	# 挥击弧
	if p.swing_frames > 0.0:
		var swing_col: Color = Color("ef4444") if p.weapon == "cleaver" else Color("fbbf24")
		draw_arc(Vector2(p.x, p.y), 36.0, p.angle - 0.65, p.angle + 0.65, 24, swing_col, 5.0, true)
	# 脚下阴影
	draw_circle(Vector2(p.x, p.y + 3.0), 12.0, Color(0, 0, 0, 0.35))
	draw_circle(Vector2(p.x, p.y), SimScript.PLAYER_R, Color("0284c7") if p.in_pipe_shadow else Color("10b981"))
	draw_arc(Vector2(p.x, p.y), SimScript.PLAYER_R + 1.0, 0, TAU, 28, Color("ffffff"), 2.5, true)
	_text_c(Vector2(p.x, p.y + 4.0), "P", 10, Color("042f2e"))
	# 朝向刺
	draw_line(Vector2(p.x, p.y),
		Vector2(p.x + cos(p.angle) * 20.0, p.y + sin(p.angle) * 20.0), Color("f8fafc"), 2.0)
	if p.in_pipe_shadow:
		draw_arc(Vector2(p.x, p.y), 20.0, 0, TAU, 30, Color(0.13, 0.83, 0.93, 0.7), 2.0, true)
	if sim.qte_active:
		# 卡刀位置脉冲
		draw_circle(Vector2(sim.vasily.x, sim.vasily.y - 24.0), 7.0 + sin(sim.time * 12.0) * 1.5,
			Color(0.94, 0.27, 0.27, 0.85))

# ----------------------------------------------------------------------------
# 弹道 / 飞罐 / 波纹 / 浮字 / 全屏状态
# ----------------------------------------------------------------------------
func _draw_bullets() -> void:
	for b in sim.bullets:
		var a: float = clampf(b.life / 10.0, 0.0, 1.0)
		draw_line(Vector2(b.sx, b.sy), Vector2(b.tx, b.ty), Color(0.99, 0.88, 0.28, a), 2.5)

func _draw_thrown_cans() -> void:
	for tc in sim.thrown_cans:
		var pos := Vector2(tc.x, tc.y).lerp(Vector2(tc.tx, tc.ty), tc.progress)
		var arc: float = sin(tc.progress * PI) * 26.0
		draw_circle(Vector2(pos.x, pos.y - arc), 5.0, Color("fbbf24"))
		draw_arc(Vector2(pos.x, pos.y - arc), 6.0, 0, TAU, 14, Color(0.12, 0.1, 0.04, 0.6), 1.2, true)

func _draw_ripples() -> void:
	for rp in sim.ripples:
		var a: float = clampf(1.0 - rp.r / maxf(rp.max_r, 1.0), 0.0, 1.0)
		var col := Color(rp.color)
		col.a = a * 0.85
		draw_arc(Vector2(rp.x, rp.y), rp.r, 0, TAU, 40, col, 2.0, true)
		var label: String = rp.zh if sim.lang == "zh" else rp.en
		if label != "" and rp.r > rp.max_r * 0.25 and a > 0.2:
			col.a = a
			_text_c(Vector2(rp.x, rp.y - rp.r * 0.6), label, 10, col)

func _draw_floats() -> void:
	for ft in sim.floats:
		var a: float = clampf(ft.life / 35.0, 0.0, 1.0)
		var col := Color(ft.color)
		col.a = a
		var label: String = ft.zh if sim.lang == "zh" else ft.en
		_text_c(Vector2(ft.x, ft.y), label, 11, col)

func _draw_overlays() -> void:
	# PTSD 干渴耳鸣红色闪屏
	if sim.ptsd_flash > 0.0:
		var a: float = (sim.ptsd_flash / 90.0) * 0.28
		draw_rect(Rect2(0, 0, SimScript.WORLD_W, SimScript.WORLD_H), Color(0.75, 0.07, 0.24, a))
	# 破眼镜：红色透镜裂痕 + 边框
	if sim.glasses_cracked:
		draw_rect(Rect2(0, 0, SimScript.WORLD_W, SimScript.WORLD_H), Color(0.96, 0.25, 0.37, 0.06))
		draw_rect(Rect2(0, 0, SimScript.WORLD_W, SimScript.WORLD_H), Color(0.96, 0.25, 0.37, 0.35), false, 8.0)
		draw_line(Vector2(430, 0), Vector2(520, 250), Color(0.98, 0.55, 0.6, 0.30), 1.4)
		draw_line(Vector2(520, 250), Vector2(470, 430), Color(0.98, 0.55, 0.6, 0.30), 1.2)
		draw_line(Vector2(735, 90), Vector2(690, 300), Color(0.98, 0.55, 0.6, 0.22), 1.2)

# ----------------------------------------------------------------------------
# 手机触屏指示：只在触屏按下时画，桌面键盘鼠标不受影响。
# ----------------------------------------------------------------------------
func _draw_touch_controls() -> void:
	if _touch_move_id < 0 and _touch_aim_id < 0:
		return
	if _touch_move_id >= 0:
		draw_circle(_touch_move_origin, 60.0, Color(0.2, 0.3, 0.4, 0.25))
		draw_arc(_touch_move_origin, 60.0, 0, TAU, 32, Color(0.8, 0.9, 1.0, 0.5), 2.0, true)
		draw_circle(_touch_move_origin + _touch_move_vec * 50.0, 24.0, Color(0.9, 0.95, 1.0, 0.8))
	if _touch_aim_id >= 0:
		draw_arc(_touch_aim_pos, 14.0, 0, TAU, 24, Color(1.0, 0.8, 0.2, 0.7), 2.0, true)
		draw_line(_touch_aim_pos + Vector2(-20, 0), _touch_aim_pos + Vector2(-6, 0), Color(1.0, 0.8, 0.2, 0.7), 2.0)
		draw_line(_touch_aim_pos + Vector2(6, 0), _touch_aim_pos + Vector2(20, 0), Color(1.0, 0.8, 0.2, 0.7), 2.0)
		draw_line(_touch_aim_pos + Vector2(0, -20), _touch_aim_pos + Vector2(0, -6), Color(1.0, 0.8, 0.2, 0.7), 2.0)
		draw_line(_touch_aim_pos + Vector2(0, 6), _touch_aim_pos + Vector2(0, 20), Color(1.0, 0.8, 0.2, 0.7), 2.0)

# ----------------------------------------------------------------------------
# 文本工具
# ----------------------------------------------------------------------------
func _text(pos: Vector2, txt: String, size: int, color: Color) -> void:
	draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _text_c(pos: Vector2, txt: String, size: int, color: Color) -> void:
	var w: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, pos - Vector2(w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
