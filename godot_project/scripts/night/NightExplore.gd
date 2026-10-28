extends Node2D
## NightExplore.gd — 「夜间广轨货场」（L03 · yard）夜潜美术切片的总控。
##
## 与 Campaign.gd 的 _draw() 灰盒不同，这个场景是完整的节点化 2.5D 场景：
##   Ground（烘焙地面，light_mask=2）+ World（Y-sort 的道具 / 角色精灵）
##   + 2D 灯光（Ground 灯投影 / Objects 灯不投影）+ CanvasModulate 夜色 + 雪粒子 + 后处理。
## 玩法是 Exploration Demo 的子集：三方潜行（玩家 / 灰鳞狂暴者 / ОСК 清杀队）、手电、噪声、
## 扔罐头借刀杀人、搜刮、体温、撤离。
## 物品与容器掉落表直接读 CampaignData，后续可以把本场景接进 CampaignSim 的夜潜阶段。
##
## 操作：WASD 移动 · 鼠标朝向 · Ctrl 蹲伏 · Shift 冲刺 · 长按 E 搜刮/撤离 · G 扔罐头
##       F 手电 · M 静音 · R 重来 · Esc 返回战役

const Data := preload("res://scripts/CampaignData.gd")
const SfxScript := preload("res://scripts/Sfx.gd")

const PPM := 64.0
const SQ := 0.62
const SEARCH_TIME := 2.2
const EXTRACT_TIME := 1.6
const REACH := 1.45
const WARMTH_DECAY := 100.0 / 240.0
const WARMTH_FIRE := 7.0
const CAN_RANGE := 9.0
const CAN_NOISE := 9.0
const BAG_MAX := 8
const CORPSE_CATS := ["med", "val", "intel"]

var state := "play"            # play | caught | frozen | downed | extracted
var pack: Array[String] = []
var warmth := 100.0
var hp := 100.0
var hurt := 0.0                # 受伤闪红计时
var borrowed := 0              # 借刀杀人：清杀队替你清掉的狂暴者
var rabids: Array = []
var cans := 3
var search_target: Node2D = null
var search_prog := 0.0
var extract_prog := 0.0
var exit_px := Vector2.ZERO
var ripples: Array[Dictionary] = []
var floats: Array[Dictionary] = []
var thrown: Array[Dictionary] = []
var soldiers: Array = []
var containers: Array = []
var slush: Array = []          # [center_m: Vector2, radii_m: Vector2]
var warm_lights: Array = []    # [pos_px, radius_m]
var fade_props: Array = []
var caught_by := ""
var muted := false
var t := 0.0

var player
var font: SystemFont
var sfx
var rng := RandomNumberGenerator.new()
var _search_noise := 0.0

@onready var cam: Camera2D = $Camera2D
@onready var post: ColorRect = $Post/Grade
@onready var hud_root: Control = $HUD/Root

var _lbl_status: Label
var _lbl_bag: Label
var _lbl_hint: Label
var _lbl_center: Label
var _bar_warm: ProgressBar
var _bar_hp: ProgressBar

static func to_m(p: Vector2) -> Vector2:
	return Vector2(p.x / PPM, p.y / (PPM * SQ))

static func dist_m(a: Vector2, b: Vector2) -> float:
	return to_m(a - b).length()

func _ready() -> void:
	rng.randomize()
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK SC", "Noto Sans SC", "Microsoft YaHei", "SimHei",
		"PingFang SC", "Segoe UI", "Arial"])
	sfx = SfxScript.new()
	add_child(sfx)
	player = $World/Player
	player.ctl = self
	for s in get_tree().get_nodes_in_group("night_osk"):
		s.ctl = self
		soldiers.append(s)
	for n in get_tree().get_nodes_in_group("night_searchlight"):
		n.ctl = self
	for r in get_tree().get_nodes_in_group("night_rabid"):
		r.ctl = self
		rabids.append(r)
	containers = get_tree().get_nodes_in_group("night_container")
	fade_props = get_tree().get_nodes_in_group("night_fade")
	for z in get_tree().get_nodes_in_group("night_slush"):
		slush.append([to_m(z.global_position), Vector2(float(z.get_meta("rx", 1.0)), float(z.get_meta("ry", 1.0)))])
	for w in get_tree().get_nodes_in_group("night_warm"):
		warm_lights.append([w.global_position, float(w.get_meta("radius", 2.5))])
	exit_px = $Markers/Exit.global_position
	player.global_position = $Markers/Spawn.global_position
	cam.global_position = player.global_position
	cam.reset_smoothing()
	for a in find_children("*", "AudioStreamPlayer*", true, false):
		_loop_audio(a)
	_build_hud()

func _loop_audio(p: Node) -> void:
	var s = p.get("stream")
	if s is AudioStreamWAV:
		var w := (s as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
		p.set("stream", w)
		p.call("play")

# ============================================================================
# 主循环
# ============================================================================
func _process(delta: float) -> void:
	t += delta
	hurt = maxf(0.0, hurt - delta)
	cam.global_position = player.global_position + Vector2(0, -40)
	if state == "play":
		_update_interact(delta)
		_update_warmth(delta)
	_update_fx(delta)
	_update_fade()
	_update_post()
	_refresh_hud()
	$OverlayLayer/Overlay.queue_redraw()

func _update_interact(delta: float) -> void:
	var holding := Input.is_action_pressed("interact")
	var near_exit := dist_m(player.global_position, exit_px) <= REACH
	var c := nearest_container()
	player.frozen = false
	if holding and near_exit and c == null:
		extract_prog += delta / EXTRACT_TIME
		player.frozen = true
		if extract_prog >= 1.0:
			_end("extracted")
		return
	extract_prog = 0.0
	if holding and c != null:
		if search_target != c:
			search_target = c
			search_prog = 0.0
		search_prog += delta / SEARCH_TIME
		player.frozen = true
		_search_noise -= delta
		if _search_noise <= 0.0:
			emit_noise(c.global_position, 1.5, "search")
			_search_noise = 0.7
		if search_prog >= 1.0:
			_finish_search(c)
	else:
		search_target = null
		search_prog = 0.0

func nearest_container() -> Node2D:
	var best: Node2D = null
	var bd := REACH
	for c in containers:
		if bool(c.get_meta("searched", false)):
			continue
		var d := dist_m(player.global_position, interact_point(c))
		if d < bd:
			bd = d
			best = c
	return best

func interact_point(c: Node2D) -> Vector2:
	return c.global_position + Vector2(c.get_meta("interact_offset", Vector2.ZERO))

func _finish_search(c: Node2D) -> void:
	c.set_meta("searched", true)
	var spr := c.get_node_or_null("Sprite") as CanvasItem
	if spr != null:
		spr.self_modulate = Color(0.78, 0.8, 0.86)
	var kind := String(c.get_meta("container", "crate"))
	var got: Array[String] = []
	var g := String(c.get_meta("guaranteed", ""))
	if g != "":
		got.append(g)
	var cats: Array = Data.CONTAINER_CATS.get(kind, CORPSE_CATS)
	var n := 1 + (1 if rng.randf() < 0.45 else 0)
	for i in n:
		var pool: Array = Data.LOOT_CATS[cats[rng.randi() % cats.size()]]
		got.append(String(pool[rng.randi() % pool.size()]))
	var names: Array[String] = []
	for id in got:
		if pack.size() >= BAG_MAX:
			spawn_float(c.global_position + Vector2(0, -90), "背包满了 · Bag full", Color("#fbbf24"))
			break
		pack.append(id)
		names.append(item_name(id))
	if not names.is_empty():
		spawn_float(c.global_position + Vector2(0, -90), "+ " + "、".join(names), Color("#fde68a"))
	if g == "dial":
		spawn_float(c.global_position + Vector2(0, -122), "找到了妈妈的透析液", Color("#7dd3fc"))
	sfx.play("beep")
	search_target = null
	search_prog = 0.0

func item_name(id: String) -> String:
	var it: Dictionary = Data.ITEMS.get(id, {})
	return String(it.get("zh", id))

func _update_warmth(delta: float) -> void:
	var near_fire := false
	for w in warm_lights:
		if dist_m(player.global_position, w[0]) <= float(w[1]):
			near_fire = true
	if near_fire:
		warmth = minf(100.0, warmth + WARMTH_FIRE * delta)
	else:
		warmth -= WARMTH_DECAY * delta * (1.25 if player.on_slush else 1.0)
	if warmth <= 0.0:
		warmth = 0.0
		_end("frozen")

func is_slush(p: Vector2) -> bool:
	var m := to_m(p)
	for z in slush:
		var d: Vector2 = (m - z[0]) / z[1]
		if d.length_squared() <= 0.9:
			return true
	return false

func is_lit(p: Vector2) -> bool:
	for w in warm_lights:
		if dist_m(p, w[0]) <= float(w[1]) * 1.8:
			return true
	return false

# ============================================================================
# 感知：清杀兵手电 / 探照灯塔
# ============================================================================
func can_see_player(origin: Vector2, range_m: float, half: float, facing: float, is_beam: bool) -> float:
	if state != "play":
		return 0.0
	var p: Vector2 = player.global_position
	var d := to_m(p - origin)
	var dist := d.length()
	var rng_m := range_m * (1.3 if (player.flashlight_on and not is_beam) else 1.0)
	if dist > rng_m:
		return 0.0
	var in_cone := absf(angle_difference(facing, d.angle())) <= half
	if not in_cone:
		if is_beam or dist > 1.6:
			return 0.0
	var mask := 1 | (2 if player.crouching else 0)
	var q := PhysicsRayQueryParameters2D.create(origin, p, mask)
	if not get_world_2d().direct_space_state.intersect_ray(q).is_empty():
		return 0.0
	if is_beam:
		return 1.0
	var f := 1.0 - dist / rng_m * 0.55
	if player.crouching:
		f *= 0.5
	if player.sprinting:
		f *= 1.4
	if player.flashlight_on:
		f *= 1.5
	elif not is_lit(p):
		f *= 0.7
	return f

func los_clear(a: Vector2, b: Vector2, mask: int) -> bool:
	var q := PhysicsRayQueryParameters2D.create(a, b, mask)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()

## 狂暴者视线：360°，近距离；墙挡，蹲在低矮掩体后也挡；开手电更远。
func rabid_sees_player(r: Node2D) -> bool:
	if state != "play":
		return false
	var p: Vector2 = player.global_position
	var dist := dist_m(p, r.global_position)
	var rng_m: float = r.SIGHT * (1.3 if player.flashlight_on else 1.0) * (0.7 if player.crouching else 1.0)
	if dist > rng_m:
		return false
	return los_clear(r.global_position, p, 1 | (2 if player.crouching else 0))

## 三色声纹：灰白=玩家 / 暗红=狂暴者 / 冷蓝=清杀队；琥珀=罐头。
## 谁听得见：清杀兵听玩家与罐头；狂暴者听一切人造声音（含枪声），不理同类的低吼。
func emit_noise(pos: Vector2, radius_m: float, kind: String) -> void:
	var col := Color("#cbd5e1")
	match kind:
		"can":
			col = Color("#fbbf24")
		"search":
			col = Color("#e2c48a")
		"rabid":
			col = Color("#b91c1c")
		"gun":
			col = Color("#7dd3fc")
	ripples.append({"pos": pos, "r": 0.0, "max": radius_m, "col": col, "life": 1.0})
	if kind != "rabid" and kind != "gun":
		for s in soldiers:
			if dist_m(s.global_position, pos) <= radius_m:
				s.hear(pos, kind)
	if kind != "rabid":
		for r in rabids:
			if r.is_alive() and dist_m(r.global_position, pos) <= radius_m:
				r.hear(pos, kind)

func damage_player(amount: float, _by: Node) -> void:
	if state != "play":
		return
	hp = maxf(0.0, hp - amount)
	hurt = 0.35
	sfx.play("bonejam")
	emit_noise(player.global_position, 6.0, "hit")
	spawn_float(player.global_position + Vector2(0, -120), "-%d 被咬了！" % int(amount), Color("#f87171"))
	if hp <= 0.0:
		_end("downed")

func on_soldier_fired(s: Node2D, at: Vector2) -> void:
	sfx.play("akm")
	emit_noise(s.global_position, 10.0, "gun")
	emit_noise(at, 3.0, "gun")

func on_rabid_killed(r: Node2D, by: String) -> void:
	var splat := Sprite2D.new()
	splat.texture = load("res://art/50_vfx/VFX_Blood_Splat.png")
	splat.light_mask = 2
	splat.position = r.global_position + Vector2(0, -4)
	splat.rotation = rng.randf() * 0.4 - 0.2
	$Decals.add_child(splat)
	if by != "":
		borrowed += 1
		spawn_float(r.global_position + Vector2(0, -130), "借刀杀人：清杀队替你清掉 1 只狂暴者", Color("#7dd3fc"))

func raise_alarm(pos: Vector2, _by: Node) -> void:
	sfx.play("thirst")
	spawn_float(pos + Vector2(0, -120), "探照灯锁定！", Color("#f43f5e"))
	for s in soldiers:
		if dist_m(s.global_position, pos) <= 30.0:
			s.alert_to(pos)

func on_soldier_alert(_s: Node) -> void:
	sfx.play("thirst")

func caught(by: Node) -> void:
	if state != "play":
		return
	caught_by = String(by.name)
	sfx.play("akm")
	_end("caught")

func _end(reason: String) -> void:
	state = reason
	player.frozen = true
	match reason:
		"extracted":
			sfx.play("beep")
		"frozen", "downed":
			sfx.play("thirst")

# ============================================================================
# 输入
# ============================================================================
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		match k:
			KEY_F:
				if state == "play":
					player.toggle_flashlight()
					sfx.play("wedge")
			KEY_G:
				if state == "play":
					_throw_can(get_global_mouse_position())
			KEY_M:
				muted = not muted
				sfx.set_muted(muted)
				AudioServer.set_bus_mute(0, muted)
			KEY_R:
				get_tree().reload_current_scene()
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://scenes/campaign.tscn")
			KEY_ENTER, KEY_KP_ENTER:
				if state != "play":
					get_tree().reload_current_scene()

func _throw_can(target: Vector2) -> void:
	if cans <= 0:
		spawn_float(player.global_position + Vector2(0, -120), "没有空罐头了", Color("#94a3b8"))
		return
	var from: Vector2 = player.global_position
	var d := to_m(target - from)
	if d.length() > CAN_RANGE:
		d = d.normalized() * CAN_RANGE
		target = from + Vector2(d.x * PPM, d.y * PPM * SQ)
	cans -= 1
	thrown.append({"from": from, "to": target, "t": 0.0, "dur": 0.25 + d.length() / CAN_RANGE * 0.5})

# ============================================================================
# 表现
# ============================================================================
func spawn_float(pos: Vector2, txt: String, col: Color) -> void:
	floats.append({"pos": pos, "txt": txt, "col": col, "life": 2.2})

func _update_fx(delta: float) -> void:
	for r in ripples:
		r["r"] = float(r["r"]) + delta * maxf(6.0, float(r["max"]) * 2.2)
		r["life"] = clampf(1.0 - float(r["r"]) / maxf(0.01, float(r["max"])), 0.0, 1.0)
	ripples = ripples.filter(func(r): return float(r["life"]) > 0.0)
	for f in floats:
		f["life"] = float(f["life"]) - delta
		f["pos"] = Vector2(f["pos"]) + Vector2(0, -22.0 * delta)
	floats = floats.filter(func(f): return float(f["life"]) > 0.0)
	var landed: Array = []
	for c in thrown:
		c["t"] = float(c["t"]) + delta / float(c["dur"])
		if float(c["t"]) >= 1.0:
			landed.append(c)
	for c in landed:
		thrown.erase(c)
		emit_noise(c["to"], CAN_NOISE, "can")
		sfx.play("can")

func _update_fade() -> void:
	var p: Vector2 = player.global_position
	for n in fade_props:
		var spr := n.get_node_or_null("Sprite") as Sprite2D
		if spr == null:
			continue
		var r := spr.get_rect()
		var top_left: Vector2 = n.global_position + r.position
		var behind: bool = p.y < n.global_position.y and p.x > top_left.x and p.x < top_left.x + r.size.x \
			and p.y > top_left.y + 20.0
		var target := 0.55 if behind else 1.0
		spr.modulate.a = move_toward(spr.modulate.a, target, get_process_delta_time() * 3.0)

func _update_post() -> void:
	var mat := post.material as ShaderMaterial
	if mat == null:
		return
	var alarm := 0.0
	for s in soldiers:
		alarm = maxf(alarm, clampf(float(s.suspicion), 0.0, 1.0) if s.state == "alert" else 0.0)
	for r in rabids:
		if r.state in ["windup", "lunge"]:
			alarm = maxf(alarm, 0.6)
	if state == "caught" or state == "downed":
		alarm = 1.0
	alarm = maxf(alarm, hurt / 0.35)
	mat.set_shader_parameter("frost", clampf((35.0 - warmth) / 35.0, 0.0, 1.0))
	mat.set_shader_parameter("alarm", alarm)
	mat.set_shader_parameter("cam_offset", cam.get_screen_center_position())

# ============================================================================
# HUD
# ============================================================================
func _build_hud() -> void:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.06, 0.72)
	sb.border_color = Color(0.2, 0.27, 0.33, 0.8)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(24, 24)
	hud_root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	var title := _label("夜间广轨货场 · 第 1 夜   BROAD-GAUGE FREIGHT YARD", 17, Color("#cbd5e1"))
	v.add_child(title)
	var row := HBoxContainer.new()
	row.add_child(_label("体温 WARMTH ", 14, Color("#94a3b8")))
	_bar_warm = ProgressBar.new()
	_bar_warm.custom_minimum_size = Vector2(220, 14)
	_bar_warm.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#f59e0b")
	_bar_warm.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.12, 0.15, 0.9)
	_bar_warm.add_theme_stylebox_override("background", bg)
	row.add_child(_bar_warm)
	v.add_child(row)
	var row2 := HBoxContainer.new()
	row2.add_child(_label("健康 HEALTH ", 14, Color("#94a3b8")))
	_bar_hp = ProgressBar.new()
	_bar_hp.custom_minimum_size = Vector2(220, 14)
	_bar_hp.show_percentage = false
	var fill2 := StyleBoxFlat.new()
	fill2.bg_color = Color("#e05656")
	_bar_hp.add_theme_stylebox_override("fill", fill2)
	_bar_hp.add_theme_stylebox_override("background", bg)
	row2.add_child(_bar_hp)
	v.add_child(row2)
	_lbl_status = _label("", 14, Color("#94a3b8"))
	v.add_child(_lbl_status)
	_lbl_bag = _label("", 14, Color("#e2e8f0"))
	_lbl_bag.custom_minimum_size = Vector2(420, 0)
	_lbl_bag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_lbl_bag)

	_lbl_hint = _label("", 15, Color(0.8, 0.85, 0.9, 0.85))
	_lbl_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_lbl_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_hint.offset_left = -760
	_lbl_hint.offset_right = 760
	_lbl_hint.offset_top = -64
	_lbl_hint.offset_bottom = -30
	hud_root.add_child(_lbl_hint)

	_lbl_center = _label("", 30, Color("#f1f5f9"))
	_lbl_center.set_anchors_preset(Control.PRESET_CENTER)
	_lbl_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_center.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_center.offset_left = -700
	_lbl_center.offset_right = 700
	_lbl_center.offset_top = -170
	_lbl_center.offset_bottom = 170
	_lbl_center.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_lbl_center.add_theme_constant_override("outline_size", 8)
	hud_root.add_child(_lbl_center)

func _label(txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _refresh_hud() -> void:
	if _bar_warm == null:
		return
	_bar_warm.value = warmth
	_bar_hp.value = hp
	var stance := "蹲伏" if player.crouching else ("冲刺" if player.sprinting else "步行")
	var light := "手电 开" if player.flashlight_on else "手电 关"
	var lit := "（暴露）" if player.flashlight_on or is_lit(player.global_position) else "（暗处）"
	var ground := " · 冻雪泥！" if player.on_slush else ""
	var chasing := 0
	for r in rabids:
		if r.state in ["chase", "windup", "lunge"]:
			chasing += 1
	var threat := (" · 被 %d 只狂暴者盯上" % chasing) if chasing > 0 else ""
	_lbl_status.text = "%s · %s%s · 空罐头 ×%d · 借刀 ×%d%s%s" % [stance, light, lit, cans, borrowed, ground, threat]
	var names: Array[String] = []
	for id in pack:
		names.append(item_name(id))
	_lbl_bag.text = "背包 %d/%d：%s" % [pack.size(), BAG_MAX, "、".join(names) if not names.is_empty() else "—"]
	var has_dial := pack.has("dial")
	if has_dial:
		_lbl_hint.text = "透析液到手 —— 回锅炉房通风口长按 E 撤离   ·   R 重来  Esc 返回战役"
	else:
		_lbl_hint.text = "目标：在三号闷罐车厢找到妈妈的透析液   ·   WASD 移动  Ctrl 蹲  Shift 跑  E 搜刮  G 罐头  F 手电"
	match state:
		"play":
			_lbl_center.text = ""
		"caught":
			_lbl_center.text = "被清杀队发现\nОСК открыл огонь\n\nR / Enter 重来"
			_lbl_center.add_theme_color_override("font_color", Color("#fca5a5"))
		"downed":
			_lbl_center.text = "被狂暴者扑倒了\n高烧的身体烫得像炉子。\n\nR / Enter 重来"
			_lbl_center.add_theme_color_override("font_color", Color("#fca5a5"))
		"frozen":
			_lbl_center.text = "体温耗尽，倒在了雪里\n\nR / Enter 重来"
			_lbl_center.add_theme_color_override("font_color", Color("#bae6fd"))
		"extracted":
			var names2: Array[String] = []
			for id in pack:
				names2.append(item_name(id))
			var line := "妈妈今晚有透析液了。" if has_dial else "空着手回去，妈妈还在等透析液。"
			_lbl_center.text = "撤离成功 · %d 件物资 · 借刀 ×%d\n%s\n%s\n\nR / Enter 再来一夜   Esc 返回战役" % [
				pack.size(), borrowed, "、".join(names2), line]
			_lbl_center.add_theme_color_override("font_color", Color("#bbf7d0"))
