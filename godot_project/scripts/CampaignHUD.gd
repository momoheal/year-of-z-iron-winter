extends CanvasLayer
## CampaignHUD.gd — 「一夜」探索循环的 CanvasLayer 界面层（纯代码构建，无 .tscn 依赖）。
##
## 对应 HTML Exploration Demo 的四块界面：
##   · 顶栏：标题 / 第 N 天 / 卌 划痕 / 语言 / 日志 / 帮助 / 音效 / 跳转灰盒场
##   · 基地：三栏（状态 · 队伍与武器库 · 目标 / 地点 / 真名 / 事件）
##   · 地图：右侧节点卡（危险 / 时长 / 寒冷 / 物资 / 容器余量 / 伙伴 / 携带物 / 出发）
##   · 结算：带回物资 / 本次记录 / 事件 / 武器架更新 / 日志背面
## 以及四个模态框：剧情节拍、抉择 A、日志、帮助、放弃夜潜确认。
##
## 刷新策略：界面闲置时按状态签名整块重建（简单可靠）；夜潜进行中只更新常驻标签，
## 不重建控件，避免每帧 GC。世界本身由 Campaign.gd 的 _draw() 绘制。

signal ui_sfx(name: String)

const Data := preload("res://scripts/CampaignData.gd")

const SCREEN := Vector2(1920, 1080)
const TOP_H := 70.0
const PANEL_W_L := 452.0
const PANEL_W_M := 566.0
const FONT_SIZES := {"h1": 34, "h2": 22, "h3": 17, "body": 14, "small": 12}

var sim
var game
var font: SystemFont
var root: Control
var body: Control
var modal: Control
var top_bar: PanelContainer

var sound_on := true
var _sig := ""
var _modal_kind := ""
var _live: Dictionary = {}

# 顶栏标签
var _lbl_day: Label
var _lbl_tally: Label
var _lbl_sub: Label
var _btn_lang: Button
var _btn_sound: Button

func bind_campaign(campaign_sim, campaign_node) -> void:
	sim = campaign_sim
	game = campaign_node
	if root != null:
		_refresh(true)

func _ready() -> void:
	layer = 12
	font = SystemFont.new()
	font.font_names = PackedStringArray([
		"Noto Sans CJK SC", "Noto Sans SC", "Microsoft YaHei", "SimHei",
		"PingFang SC", "Segoe UI", "Arial",
	])
	root = Control.new()
	root.name = "CampaignUIRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_top_bar()

	body = Control.new()
	body.name = "Body"
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_top = TOP_H + 8
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(body)

	modal = Control.new()
	modal.name = "Modal"
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(modal)

	if sim != null:
		_refresh(true)

# ============================================================================
# 控件工厂
# ============================================================================
func _sb(bg: Color, border: Color, radius: int = 8, border_w: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

func _label(txt: String, size: int = 14, col: Color = Color("#cbd5e1")) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _rich(size: int = 14) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.add_theme_font_override("normal_font", font)
	r.add_theme_font_override("bold_font", font)
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_color_override("default_color", Color("#cbd5e1"))
	return r

func _btn(txt: String, cb: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 15)
	b.focus_mode = Control.FOCUS_NONE
	if primary:
		b.add_theme_stylebox_override("normal", _sb(Color("#2a4a34"), Color("#4ade80"), 8))
		b.add_theme_stylebox_override("hover", _sb(Color("#356045"), Color("#86efac"), 8))
		b.add_theme_stylebox_override("pressed", _sb(Color("#1e3726"), Color("#4ade80"), 8))
		b.add_theme_color_override("font_color", Color("#dcfce7"))
	else:
		b.add_theme_stylebox_override("normal", _sb(Color("#18212c"), Color("#334155"), 7))
		b.add_theme_stylebox_override("hover", _sb(Color("#22303f"), Color("#64748b"), 7))
		b.add_theme_stylebox_override("pressed", _sb(Color("#111925"), Color("#475569"), 7))
		b.add_theme_color_override("font_color", Color("#dbe3ee"))
	b.pressed.connect(cb)
	b.pressed.connect(func(): ui_sfx.emit("beep"))
	return b

func _panel(min_w: float = 0.0, min_h: float = 0.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(Color("#0c1219"), Color("#22303f"), 10))
	if min_w > 0.0 or min_h > 0.0:
		p.custom_minimum_size = Vector2(min_w, min_h)
	return p

func _vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

func _hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

func _bar(pct: float, col: Color, h: float = 10.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = 0.0
	b.max_value = 100.0
	b.value = clampf(pct, 0.0, 100.0)
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, h)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#0a1017")
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = col
	fg.set_corner_radius_all(4)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b

func _sep() -> Control:
	var c := ColorRect.new()
	c.color = Color("#1b2735")
	c.custom_minimum_size = Vector2(0, 1)
	return c

func _chip(txt: String, col: Color = Color("#334155"), txt_col: Color = Color("#cbd5e1")) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _sb(Color("#111a24"), col, 6, 1)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	var l := _label(txt, FONT_SIZES["small"], txt_col)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	p.add_child(l)
	return p

func _clear(node: Node) -> void:
	if node == null:
		return
	for c in node.get_children():
		c.queue_free()
		node.remove_child(c)

func _tr(zh: String, en: String) -> String:
	return zh if sim != null and sim.lang == "zh" else en

# ============================================================================
# 顶栏
# ============================================================================
func _build_top_bar() -> void:
	top_bar = PanelContainer.new()
	top_bar.add_theme_stylebox_override("panel", _sb(Color("#070b10"), Color("#16202b"), 0, 0))
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = TOP_H
	top_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(top_bar)

	var h := _hbox(14)
	h.add_theme_constant_override("separation", 16)
	top_bar.add_child(h)

	var tl := _vbox(0)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.add_child(_label("一年之后 · 铁冬", 24, Color("#e2e8f0")))
	_lbl_sub = _label("YEAR OF Z: IRON WINTER · EXPLORATION LOOP", 11, Color("#5f7a83"))
	tl.add_child(_lbl_sub)
	h.add_child(tl)

	_lbl_day = _label("第 1 天 · 夜", 17, Color("#94a3b8"))
	h.add_child(_lbl_day)
	_lbl_tally = _label("卌 0", 17, Color("#fbbf24"))
	h.add_child(_lbl_tally)

	_btn_lang = _btn("中文 / EN (L)", func(): sim.toggle_lang())
	h.add_child(_btn_lang)
	var b_log := _btn("日志 (Tab)", func(): sim.logbook_open = true)
	h.add_child(b_log)
	var b_help := _btn("帮助 (?)", func(): sim.help_open = true)
	h.add_child(b_help)
	_btn_sound = _btn("音效：开 (M)", _toggle_sound)
	h.add_child(_btn_sound)
	var b_gym := _btn("灰盒场 (F1)", func(): get_tree().change_scene_to_file("res://scenes/gym.tscn"))
	h.add_child(b_gym)

func _toggle_sound() -> void:
	sound_on = not sound_on
	if _btn_sound != null:
		_btn_sound.text = "音效：开 (M)" if sound_on else "音效：关 (M)"

# ============================================================================
# 刷新
# ============================================================================
func refresh() -> void:
	if sim == null:
		return
	_refresh(false)

func _refresh(force: bool) -> void:
	if sim == null or root == null:
		return
	_lbl_day.text = ("第 %d 天 · 夜" % sim.day) if sim.lang == "zh" else ("DAY %d · NIGHT" % sim.day)
	_lbl_tally.text = "卌 %d" % sim.tally
	_lbl_sub.text = ("探索循环 · 灰盒 DEMO" if sim.lang == "zh" else "EXPLORATION LOOP · GREYBOX DEMO")
	_btn_lang.text = "EN (L)" if sim.lang == "zh" else "中文 (L)"
	var sig := _make_sig()
	if force or sig != _sig:
		_sig = sig
		_rebuild_body()
		_rebuild_modal()
	else:
		_update_live()

func _make_sig() -> String:
	if sim.phase == "raid":
		# 夜潜中每帧都在变的是生命体征，不参与重建签名（由 _update_live 就地更新）
		return "raid|%s|%s|%s|%s|%s" % [sim.lang, str(sim.story_open), str(sim.help_open),
			str(sim.logbook_open), str(sim.abort_confirm)]
	var s := "%s|%s|%d|%s|%s" % [str(sim.phase), sim.lang, sim.day, sim.mate, sim.selected_loc]
	s += "|" + str(sim.stash) + str(sim.load) + str(sim.flags)
	s += "|" + str(sim.names) + "|" + str(sim.log.size())
	s += "|" + str(sim.mother_alive) + str(sim.dial) + str(int(sim.conscience)) + str(sim.tally)
	s += "|" + str(sim.help_open) + str(sim.logbook_open) + str(sim.story_open) + sim.story_id
	s += "|" + str(sim.abort_confirm) + str(sim.finished_demo)
	s += "|" + str(sim.last_report.get("reason", "")) + str(sim.last_report.get("day", 0))
	if sim.phase == "raid" and sim.raid != null:
		s += "|" + str(sim.raid.over) + str(sim.raid.phase)
	return s

func _rebuild_body() -> void:
	_clear(body)
	_live.clear()
	match str(sim.phase):
		"title":
			_build_title()
		"base":
			_build_base()
		"map":
			_build_map()
		"raid":
			_build_raid_hud()
		"report":
			_build_report()
		"ending":
			_build_ending()
		_:
			_build_title()

func _update_live() -> void:
	if sim.phase != "raid" or sim.raid == null:
		return
	var R = sim.raid
	var p = R.player
	if _live.has("clock"):
		(_live["clock"] as Label).text = R.clock_text()
	if _live.has("hp"):
		(_live["hp"] as Label).text = "HP %d" % int(round(p.hp))
	if _live.has("hp_bar"):
		(_live["hp_bar"] as ProgressBar).value = clampf(p.hp, 0.0, 100.0)
	if _live.has("warm"):
		(_live["warm"] as Label).text = ("体温 %d" if sim.lang == "zh" else "WARMTH %d") % int(round(p.warmth))
	if _live.has("warm_bar"):
		(_live["warm_bar"] as ProgressBar).value = clampf(p.warmth, 0.0, 100.0)
	if _live.has("stam_bar"):
		(_live["stam_bar"] as ProgressBar).value = clampf(p.stam, 0.0, 100.0)
	if _live.has("bpm"):
		(_live["bpm"] as Label).text = "%d BPM" % int(round(p.bpm))
	if _live.has("night"):
		(_live["night"] as ProgressBar).value = clampf(100.0 * R.night_left / maxf(1.0, R.night_max), 0.0, 100.0)
	if _live.has("night_txt"):
		(_live["night_txt"] as Label).text = ("夜剩余 %ds" if sim.lang == "zh" else "NIGHT %ds") % int(ceil(R.night_left))
	if _live.has("pack"):
		(_live["pack"] as Label).text = _pack_text()
	if _live.has("prompt"):
		var tgt: Dictionary = R.nearest_interact()
		var txt: String = R.objective_hint()
		if txt == "" and tgt.has("type"):
			txt = R.interact_label()
		(_live["prompt"] as Label).text = txt
		(_live["prompt"] as Label).visible = txt != ""
	var ev: Array = R.events
	var toast := ""
	if not ev.is_empty():
		var last: Dictionary = ev[ev.size() - 1]
		toast = String(last.get("zh" if sim.lang == "zh" else "en", ""))
	if _live.has("toast"):
		(_live["toast"] as Label).text = toast
		(_live["toast"] as Label).visible = toast != ""
	if _live.has("weapon"):
		var w: Dictionary = R.weapon
		var nm := String(w.get("zh" if sim.lang == "zh" else "en", ""))
		if w.has("ammo"):
			nm += "  %d / %d" % [R.ammo, int(w["ammo"])]
		(_live["weapon"] as Label).text = nm
	if _live.has("jam"):
		(_live["jam"] as PanelContainer).visible = R.jam_active
		if R.jam_active:
			(_live["jam_label"] as Label).text = \
				("锁骨卡刀！连按空格 %d / 6（%.1fs）" if sim.lang == "zh" else "BLADE JAM! SPACE %d / 6 (%.1fs)") % [R.jam_hits, maxf(0.0, R.jam_timer)]
	if _live.has("choice"):
		(_live["choice"] as PanelContainer).visible = R.choice_open

func _pack_text() -> String:
	if sim.raid == null:
		return ""
	var R = sim.raid
	var parts: Array[String] = []
	var counts: Dictionary = {}
	for id in R.pack:
		counts[id] = int(counts.get(String(id), 0)) + 1
	for k in counts.keys():
		parts.append("%s×%d" % [sim.item_name(String(k)), int(counts[k])])
	var head := "背包 %d/%d" if sim.lang == "zh" else "PACK %d/%d"
	return (head % [R.pack.size(), R.pack_max]) + ("  ·  " + "  ".join(parts) if not parts.is_empty() else "")

# ============================================================================
# 标题
# ============================================================================
func _build_title() -> void:
	var c := _vbox(18)
	c.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	c.custom_minimum_size = Vector2(760, 0)
	c.offset_left = -380
	c.offset_right = 380
	c.offset_top = -260
	c.offset_bottom = 260
	body.add_child(c)

	var t := _label("一年之后 · 铁冬", 56, Color("#e2e8f0"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(t)
	var sub := _label("EXPLORATION LOOP · 基地 → 地图 → 夜潜 → 撤离 → 结算",
		FONT_SIZES["h3"], Color("#64748b"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(sub)

	var p := _panel()
	var pv := _vbox(12)
	pv.add_child(_label(_tr(
		"诺沃斯克-17，第 4 号铁路冷库的征召工。母亲在 602 室的透析机旁等你带回下一袋腹透液。\n" \
		+ "每晚只能去一个地方：搜刮、救人、或者杀人。天亮之前回到撤离点，否则你带不回任何东西。",
		"Novorsk-17, conscript labourer at Cold Storage No.4. Your mother waits beside the dialysis machine in Room 602.\n" \
		+ "One place per night: loot, rescue, or kill. Be back at the extraction point before dawn, or you carry nothing home."),
		FONT_SIZES["body"], Color("#93a3b8")))
	pv.add_child(_sep())
	pv.add_child(_label(_tr(
		"WASD 移动 · Ctrl 潜行 · Shift 冲刺 · 鼠标瞄准 · 空格/左键 攻击 · 长按 E 交互\n" \
		+ "Q 热水 · H 绷带 · G 扔空罐 · R 装弹 · Tab 日志 · Esc 取消 · F1 灰盒测试场",
		"WASD move · Ctrl sneak · Shift sprint · mouse aim · Space/LMB attack · hold E interact\n" \
		+ "Q water · H bandage · G throw tin · R reload · Tab logbook · Esc cancel · F1 gym"),
		FONT_SIZES["small"], Color("#5f7a83")))
	p.add_child(pv)
	c.add_child(p)

	var row := _hbox(12)
	var b_start := _btn(_tr("开始第一夜（Enter）", "Begin Night One (Enter)"), _start_game, true)
	b_start.custom_minimum_size = Vector2(300, 52)
	row.add_child(b_start)
	var b_lang := _btn(_tr("English", "中文"), func(): sim.toggle_lang())
	b_lang.custom_minimum_size = Vector2(160, 52)
	row.add_child(b_lang)
	var b_gym := _btn(_tr("灰盒测试场（F1）", "Greybox Gym (F1)"),
		func(): get_tree().change_scene_to_file("res://scenes/gym.tscn"))
	b_gym.custom_minimum_size = Vector2(240, 52)
	row.add_child(b_gym)
	c.add_child(row)

func _start_game() -> void:
	sim.new_game()
	sim.phase = "base"
	_sig = ""

# ============================================================================
# 基地
# ============================================================================
func _build_base() -> void:
	var h := _hbox(14)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 22
	h.offset_right = -22
	h.offset_top = 8
	h.offset_bottom = -18
	body.add_child(h)

	# ---- 左：状态 ----
	var left := _panel(PANEL_W_L)
	left.custom_minimum_size = Vector2(PANEL_W_L, 0)
	var lv := _vbox(8)
	var lh := _hbox(8)
	lh.add_child(_label(_tr("状态", "STATUS"), FONT_SIZES["h2"], Color("#e2e8f0")))
	lh.add_child(_chip(_tr("第 %d 天", "DAY %d") % sim.day, Color("#334155")))
	lv.add_child(lh)
	lv.add_child(_sep())

	lv.add_child(_label(_tr("母亲 · 腹膜透析", "Mother · Peritoneal Dialysis"), FONT_SIZES["body"], Color("#94a3b8")))
	var dial_col := Color("#86efac") if sim.dial > 1.0 else Color("#fca5a5")
	if not sim.mother_alive:
		dial_col = Color("#6b7280")
	var dial_row := _hbox(8)
	dial_row.add_child(_label(_tr("剩余", "left"), FONT_SIZES["small"], Color("#64748b")))
	var dv := _label(("%.1f 天" if sim.lang == "zh" else "%.1f days") % sim.dial, FONT_SIZES["h3"], dial_col)
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dial_row.add_child(dv)
	dial_row.add_child(_chip("🧪 ×%d" % int(sim.stash.get("dial", 0)), Color("#334155")))
	lv.add_child(dial_row)
	lv.add_child(_bar(clampf(sim.dial / 3.0 * 100.0, 0.0, 100.0), Color("#38bdf8")))
	var md := _label(_tr(
		"每过一天消耗 1 袋腹透液；断供两天以上，母亲会死于急性肺水肿。",
		"One bag of fluid per day. Two days without it and she dies of acute pulmonary oedema."),
		FONT_SIZES["small"], Color("#64748b"))
	lv.add_child(md)

	lv.add_child(_sep())
	lv.add_child(_label(_tr("良知", "CONSCIENCE"), FONT_SIZES["body"], Color("#94a3b8")))
	lv.add_child(_bar(sim.conscience, Color("#4ade80")))
	lv.add_child(_label("%d / 100" % int(round(sim.conscience)), FONT_SIZES["small"], Color("#86efac")))
	lv.add_child(_sep())
	var trow := _hbox(10)
	trow.add_child(_label(_tr("日志背面（卌）", "Back page (卌)"), FONT_SIZES["body"], Color("#94a3b8")))
	trow.add_child(_label(sim.tally_marks(), 20, Color("#fbbf24")))
	lv.add_child(trow)
	var truth := _tr("是（手稿 / 照片在手）", "YES") if bool(sim.flags.get("truth", false)) else _tr("否", "NO")
	lv.add_child(_label(_tr("真相在手：", "Truth in hand: ") + truth, FONT_SIZES["body"],
		Color("#86efac") if bool(sim.flags.get("truth", false)) else Color("#6b7280")))
	var flags_row := _hbox(6)
	if bool(sim.flags.get("ptsd", false)):
		flags_row.add_child(_chip(_tr("PTSD 干渴幻听", "PTSD thirst"), Color("#7f1d1d"), Color("#fca5a5")))
	if bool(sim.flags.get("glasses", false)):
		flags_row.add_child(_chip(_tr("镜片碎裂", "cracked lens"), Color("#7c2d12"), Color("#fdba74")))
	if bool(sim.flags.get("betrayed", false)):
		flags_row.add_child(_chip(_tr("曾背叛同类", "betrayed kin"), Color("#7f1d1d"), Color("#fca5a5")))
	if not sim.mother_alive:
		flags_row.add_child(_chip(_tr("失母", "motherless"), Color("#334155"), Color("#94a3b8")))
	lv.add_child(flags_row)

	lv.add_child(_sep())
	lv.add_child(_label(_tr("库存", "STASH"), FONT_SIZES["h3"], Color("#e2e8f0")))
	var stash_scroll := ScrollContainer.new()
	stash_scroll.custom_minimum_size = Vector2(0, 240)
	stash_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var sv := _vbox(4)
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rows: Array[Dictionary] = sim.stash_sorted()
	if rows.is_empty():
		sv.add_child(_label(_tr("（空）", "(empty)"), FONT_SIZES["small"], Color("#64748b")))
	for r in rows:
		var line := _hbox(8)
		var nm := _label("%s %s" % [sim.item_icon(String(r["id"])), sim.item_name(String(r["id"]))],
			FONT_SIZES["body"], Color("#cbd5e1"))
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(nm)
		line.add_child(_label("×%d" % int(r["n"]), FONT_SIZES["body"], Color("#94a3b8")))
		sv.add_child(line)
	stash_scroll.add_child(sv)
	lv.add_child(stash_scroll)
	left.add_child(lv)
	h.add_child(left)

	# ---- 中：队伍与武器库 ----
	var mid := _panel(PANEL_W_M)
	mid.custom_minimum_size = Vector2(PANEL_W_M, 0)
	var mv := _vbox(8)
	var mh := _hbox(8)
	mh.add_child(_label(_tr("队伍", "PARTY"), FONT_SIZES["h2"], Color("#e2e8f0")))
	mh.add_child(_chip(_tr("独自", "solo") if sim.mate == "none" else "1 / 1", Color("#334155")))
	mv.add_child(mh)
	mv.add_child(_sep())
	mv.add_child(_mate_row("none", "🚶", _tr("独自行动", "Go alone"),
		_tr("没有伙伴的噪音与破绽，也没有他们的能力。", "No companion noise, no companion perks."), true))
	for m in Data.MATES:
		var ok: bool = bool(sim.mates.get(String(m["id"]), false))
		mv.add_child(_mate_row(String(m["id"]), String(m["ic"]),
			String(m["zh"] if sim.lang == "zh" else m["en"]),
			String(m["zh_p"] if sim.lang == "zh" else m["en_p"]), ok))
	mv.add_child(_sep())
	mv.add_child(_label(_tr("武器库 · 收集度决定火力", "WEAPON RACK · firepower follows what you collect"),
		FONT_SIZES["h3"], Color("#e2e8f0")))
	for w in Data.WEAPONS:
		mv.add_child(_weapon_row(w))
	mid.add_child(mv)
	h.add_child(mid)

	# ---- 右：目标 / 地点 / 真名 / 事件 ----
	var right := _panel()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rv := _vbox(8)
	var rh := _hbox(8)
	rh.add_child(_label(_tr("剧情", "STORY"), FONT_SIZES["h2"], Color("#e2e8f0")))
	rh.add_child(_chip("%d / %d" % [sim.unlocked_count(), Data.LOCS.size()], Color("#334155")))
	rv.add_child(rh)
	rv.add_child(_label(_tr("当前目标", "Current objective"), FONT_SIZES["small"], Color("#64748b")))
	var obj_panel := PanelContainer.new()
	obj_panel.add_theme_stylebox_override("panel", _sb(Color("#141a12"), Color("#f59e0b"), 7))
	obj_panel.add_child(_label(sim.objective_text(), FONT_SIZES["body"], Color("#e2e8f0")))
	rv.add_child(obj_panel)
	rv.add_child(_label(_tr("地点", "Locations"), FONT_SIZES["small"], Color("#64748b")))
	var loc_scroll := ScrollContainer.new()
	loc_scroll.custom_minimum_size = Vector2(0, 300)
	loc_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var lv2 := _vbox(3)
	lv2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for L in Data.LOCS:
		var ok2: bool = sim.loc_unlocked(L)
		var st: Dictionary = sim.node_state(String(L["id"]))
		var line2 := _hbox(8)
		var col := Color("#cbd5e1") if ok2 else Color("#475569")
		var txt := ("◼ " if ok2 else "◻ ") + sim.node_title(L)
		if String(L.get("story", "")) != "":
			txt += "  ▲"
		var nm2 := _label(txt, FONT_SIZES["body"], col)
		nm2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line2.add_child(nm2)
		if int(st.get("visits", 0)) > 0:
			line2.add_child(_label(_tr("余量 %d%%", "left %d%%") % int(round(float(st["left"]) * 100.0)),
				FONT_SIZES["small"], Color("#5f6f83")))
		if not ok2:
			line2.add_child(_label("🔒", FONT_SIZES["small"], Color("#475569")))
		lv2.add_child(line2)
	loc_scroll.add_child(lv2)
	rv.add_child(loc_scroll)

	rv.add_child(_sep())
	rv.add_child(_label(_tr("日志背面的真名（%d）", "NAMES ON THE BACK PAGE (%d)") % sim.names.size(),
		FONT_SIZES["small"], Color("#64748b")))
	if sim.names.is_empty():
		rv.add_child(_label(_tr("还没有人为你在纸上活下来。", "Nobody is alive on paper yet."),
			FONT_SIZES["small"], Color("#64748b")))
	else:
		for n in sim.names:
			rv.add_child(_label("✒ " + String(n), FONT_SIZES["body"], Color("#cbd5e1")))

	rv.add_child(_sep())
	rv.add_child(_label(_tr("事件记录", "Event log"), FONT_SIZES["small"], Color("#64748b")))
	var recent: Array[Dictionary] = sim.recent_log(6)
	recent.reverse()
	if recent.is_empty():
		rv.add_child(_label("—", FONT_SIZES["small"], Color("#475569")))
	for l in recent:
		rv.add_child(_label("Д%d · %s" % [int(l["day"]), String(l["zh"] if sim.lang == "zh" else l["en"])],
			FONT_SIZES["small"], Color("#8fa0b4")))
	rv.add_child(_sep())
	var brow := _hbox(8)
	var b_map := _btn(_tr("去城市地图（M）", "City map (M)"), func(): sim.phase = "map", true)
	b_map.custom_minimum_size = Vector2(300, 46)
	brow.add_child(b_map)
	brow.add_child(_btn(_tr("睡到明天（Enter）", "Sleep (Enter)"), _sleep))
	brow.add_child(_btn(_tr("结局预览", "Ending preview"), func(): sim.phase = "ending"))
	rv.add_child(brow)
	right.add_child(rv)
	h.add_child(right)

func _mate_row(id: String, ic: String, name: String, desc: String, unlocked: bool) -> Control:
	var sel: bool = sim.mate == id
	var p := PanelContainer.new()
	var border := Color("#4ade80") if sel else Color("#22303f")
	p.add_theme_stylebox_override("panel", _sb(Color("#0f1620"), border, 8))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var h := _hbox(10)
	h.add_child(_label("🔒" if not unlocked else ic, 22, Color("#94a3b8")))
	var v := _vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_label(name, FONT_SIZES["body"], Color("#e2e8f0") if unlocked else Color("#64748b")))
	v.add_child(_label(desc, FONT_SIZES["small"], Color("#64748b")))
	h.add_child(v)
	p.add_child(h)
	if unlocked:
		p.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed \
					and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				sim.select_mate(id)
				_sig = "")
	return p

func _weapon_row(w: Dictionary) -> Control:
	var own: bool = sim.weapon_owned(w)
	var got: int = sim.weapon_parts(w)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(Color("#0f1620"), Color("#2a3a2a") if own else Color("#1b2735"), 7))
	var h := _hbox(10)
	h.add_child(_label(String(w["ic"]), 22, Color("#e2e8f0") if own else Color("#3f4a57")))
	var v := _vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := _hbox(8)
	var nm := _label(String(w["zh"] if sim.lang == "zh" else w["en"]), FONT_SIZES["body"],
		Color("#e2e8f0") if own else Color("#64748b"))
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nm)
	var pips := ""
	for part in w.get("parts", []):
		pips += "●" if int(sim.stash.get(String(part), 0)) > 0 else "○"
	if pips != "":
		top.add_child(_label(pips, FONT_SIZES["body"], Color("#fbbf24")))
	v.add_child(top)
	v.add_child(_label(String(w["note_zh"] if sim.lang == "zh" else w["note_en"]), FONT_SIZES["small"], Color("#64748b")))
	if not own:
		var need := []
		for part in w.get("parts", []):
			need.append("%s %d" % [sim.item_name(String(part)), int(sim.stash.get(String(part), 0))])
		v.add_child(_label(_tr("收集度 %d/%d · ", "Collected %d/%d · ") % [got, int(w["need"])] + " · ".join(need),
			FONT_SIZES["small"], Color("#8b6914")))
	h.add_child(v)
	p.add_child(h)
	return p

func _sleep() -> void:
	sim.advance_day()
	_sig = ""

# ============================================================================
# 地图
# ============================================================================
func _build_map() -> void:
	var h := _hbox(14)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 22
	h.offset_right = -22
	h.offset_top = 8
	h.offset_bottom = -18
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(h)

	# 左侧留白给 Campaign.gd 画的城市地图；不拦鼠标，点击要能落到 _unhandled_input
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(920, 0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(spacer)

	var right := _panel()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rv := _vbox(8)
	var L: Dictionary = sim.location(sim.selected_loc)
	if L.is_empty():
		rv.add_child(_label(_tr("在地图上点选一个目标。", "Select a target on the map."),
			FONT_SIZES["h3"], Color("#94a3b8")))
		var back := _btn(_tr("返回基地（Esc 取消）", "Back to base"), func(): sim.phase = "base")
		rv.add_child(back)
		right.add_child(rv)
		h.add_child(right)
		return

	var ok: bool = sim.loc_unlocked(L)
	var st: Dictionary = sim.node_state(String(L["id"]))
	var title := _hbox(10)
	title.add_child(_label(sim.node_title(L), 26, Color("#e2e8f0")))
	if String(L.get("story", "")) != "":
		title.add_child(_chip(_tr("▲ 主线", "▲ STORY"), Color("#f59e0b"), Color("#fde68a")))
	rv.add_child(title)

	var chips := _hbox(8)
	chips.add_child(_label(_tr("危险", "DANGER"), FONT_SIZES["small"], Color("#64748b")))
	var dots := ""
	for k in 5:
		dots += "●" if k < int(L["dg"]) else "○"
	chips.add_child(_label(dots, 16, Color("#ef4444")))
	chips.add_child(_label(_tr("路程 ", "TIME ") + "%d %s" % [sim.travel_minutes(L), _tr("分", "m")],
		FONT_SIZES["body"], Color("#94a3b8")))
	var snow_marks := ""
	for k in int(round(float(L["cold"]) * 3.0)):
		snow_marks += "❄"
	chips.add_child(_label(_tr("寒冷 ", "COLD ") + snow_marks, FONT_SIZES["body"], Color("#7dd3fc")))
	rv.add_child(chips)

	var loot_row := _hbox(6)
	var goods := {"food": _tr("食物", "Food"), "med": _tr("医疗", "Medical"), "scrap": _tr("废料", "Scrap"),
		"intel": _tr("情报", "Intel"), "warm": _tr("取暖", "Warmth"), "part": _tr("枪械零件", "Gun parts"),
		"weapon": _tr("武器", "Weapons"), "val": _tr("值钱物", "Valuables")}
	for c in L.get("loot", []):
		loot_row.add_child(_chip(String(goods.get(String(c), String(c))), Color("#2a3a4a")))
	loot_row.add_child(_chip(_tr("容器余量 %d%%", "Containers %d%%") % int(round(float(st["left"]) * 100.0)),
		Color("#2a3a4a")))
	rv.add_child(loot_row)
	rv.add_child(_sep())

	var hint := String(L["hint2_zh"] if int(st.get("visits", 0)) > 0 else L["hint_zh"])
	if sim.lang != "zh":
		hint = String(L["hint2_en"] if int(st.get("visits", 0)) > 0 else L["hint_en"])
	rv.add_child(_label(hint, FONT_SIZES["body"], Color("#93a3b8")))
	if int(st.get("visits", 0)) == 0:
		rv.add_child(_label(_tr("（未踏足：只听人说，没亲眼见过。）", "(Unvisited: rumour only, nothing verified.)"),
			FONT_SIZES["small"], Color("#5f6f83")))
	if not ok:
		var why: String = sim.lock_reason(L)
		if why != "":
			var lp := PanelContainer.new()
			lp.add_theme_stylebox_override("panel", _sb(Color("#1a1410"), Color("#b45309"), 6))
			lp.add_child(_label("🔒 " + why, FONT_SIZES["small"], Color("#fdba74")))
			rv.add_child(lp)

	rv.add_child(_sep())
	rv.add_child(_label(_tr("同行（每夜只能带 1 名）", "COMPANION (one per night)"),
		FONT_SIZES["small"], Color("#64748b")))
	var mrow := _hbox(6)
	mrow.add_child(_mate_chip("none", "🚶 " + _tr("独自", "solo"), true))
	for m in Data.MATES:
		if bool(sim.mates.get(String(m["id"]), false)):
			mrow.add_child(_mate_chip(String(m["id"]),
				String(m["ic"]) + " " + String(m["zh"] if sim.lang == "zh" else m["en"]), false))
	rv.add_child(mrow)

	rv.add_child(_sep())
	rv.add_child(_label(_tr("携带物（从库存扣除）", "SORTIE LOADOUT (taken from stash)"),
		FONT_SIZES["small"], Color("#64748b")))
	var lrow := _hbox(8)
	for k in ["can", "water", "asp", "band"]:
		lrow.add_child(_load_slot(String(k)))
	rv.add_child(lrow)

	var depart := _btn(_tr("🗺 出发（Enter）", "🗺 DEPART (Enter)"), func(): _depart(L), true)
	depart.custom_minimum_size = Vector2(0, 54)
	depart.disabled = not sim.can_depart(L)
	rv.add_child(depart)
	if not sim.can_depart(L):
		rv.add_child(_label(_tr("这个地点今晚去不了。", "This place is out of reach tonight."),
			FONT_SIZES["small"], Color("#fca5a5")))
	var brow := _hbox(8)
	brow.add_child(_btn(_tr("返回基地", "Back to base"), func(): sim.phase = "base"))
	brow.add_child(_btn(_tr("帮助", "Help"), func(): sim.help_open = true))
	rv.add_child(brow)
	right.add_child(rv)
	h.add_child(right)

func _mate_chip(id: String, txt: String, is_none: bool) -> Control:
	var sel: bool = sim.mate == id
	var b := _btn(txt, func(): sim.select_mate(id))
	b.custom_minimum_size = Vector2(0, 34)
	if sel:
		b.add_theme_stylebox_override("normal", _sb(Color("#193024"), Color("#4ade80"), 7))
	return b

func _load_slot(id: String) -> Control:
	var p := _panel()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := _vbox(4)
	v.add_child(_label("%s %s" % [sim.item_icon(id), sim.item_name(id)], FONT_SIZES["small"], Color("#cbd5e1")))
	v.add_child(_label(_tr("库存 %d", "stock %d") % int(sim.stash.get(id, 0)),
		FONT_SIZES["small"], Color("#5f6f83")))
	var row := _hbox(4)
	row.add_child(_btn("−", func(): _adjust_load(id, -1)))
	var mid := _label(str(int(sim.load.get(id, 0))), FONT_SIZES["body"], Color("#e2e8f0"))
	mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mid)
	row.add_child(_btn("+", func(): _adjust_load(id, 1)))
	v.add_child(row)
	p.add_child(v)
	return p

func _adjust_load(id: String, d: int) -> void:
	sim.adjust_load(id, d)
	_sig = ""

func _depart(L: Dictionary) -> void:
	if sim.depart(L):
		_sig = ""

# ============================================================================
# 夜潜 HUD
# ============================================================================
func _build_raid_hud() -> void:
	if sim.raid == null:
		return
	_live.clear()
	# ---- 左上：时钟 / 生命体征 ----
	var tl := _panel()
	tl.custom_minimum_size = Vector2(380, 0)
	var tv := _vbox(6)
	var hrow := _hbox(10)
	hrow.add_child(_label("🕯", 20, Color("#fbbf24")))
	var clock := _label(sim.raid.clock_text(), 24, Color("#e2e8f0"))
	_live["clock"] = clock
	hrow.add_child(clock)
	var loc_now: Dictionary = sim.raid.loc
	hrow.add_child(_chip(String(loc_now["zh"] if sim.lang == "zh" else loc_now["en"]), Color("#334155")))
	tv.add_child(hrow)
	var nrow := _hbox(8)
	var night := _bar(100.0 * sim.raid.night_left / maxf(1.0, sim.raid.night_max), Color("#7dd3fc"), 8)
	night.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	night.custom_minimum_size = Vector2(180, 8)
	_live["night"] = night
	nrow.add_child(night)
	var night_txt := _label("", FONT_SIZES["small"], Color("#7dd3fc"))
	_live["night_txt"] = night_txt
	nrow.add_child(night_txt)
	tv.add_child(nrow)

	var hp_row := _hbox(8)
	var hp := _label("", FONT_SIZES["body"], Color("#86efac"))
	hp.custom_minimum_size = Vector2(70, 0)
	_live["hp"] = hp
	hp_row.add_child(hp)
	var hp_bar := _bar(sim.raid.player.hp, Color("#4ade80"), 10)
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_live["hp_bar"] = hp_bar
	hp_row.add_child(hp_bar)
	tv.add_child(hp_row)

	var warm_row := _hbox(8)
	var warm := _label("", FONT_SIZES["body"], Color("#7dd3fc"))
	warm.custom_minimum_size = Vector2(70, 0)
	_live["warm"] = warm
	warm_row.add_child(warm)
	var warm_bar := _bar(sim.raid.player.warmth, Color("#38bdf8"), 8)
	warm_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_live["warm_bar"] = warm_bar
	warm_row.add_child(warm_bar)
	tv.add_child(warm_row)

	var stam_row := _hbox(8)
	stam_row.add_child(_label("STA", FONT_SIZES["small"], Color("#64748b")))
	var stam := _bar(sim.raid.player.stam, Color("#a3e635"), 6)
	stam.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_live["stam_bar"] = stam
	stam_row.add_child(stam)
	var bpm := _label("", FONT_SIZES["body"], Color("#fca5a5"))
	bpm.custom_minimum_size = Vector2(90, 0)
	bpm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_live["bpm"] = bpm
	stam_row.add_child(bpm)
	tv.add_child(stam_row)

	var wrow := _hbox(8)
	var wpn := _label("", FONT_SIZES["body"], Color("#fbbf24"))
	_live["weapon"] = wpn
	wrow.add_child(wpn)
	wrow.add_child(_label("  Q 水 · H 绷带 · G 罐 · R 装弹", FONT_SIZES["small"], Color("#5f6f83")))
	tv.add_child(wrow)
	tl.add_child(tv)
	body.add_child(tl)
	var tl_ms: Vector2 = tl.get_combined_minimum_size()
	tl.offset_left = 18.0
	tl.offset_top = 12.0
	tl.offset_right = 18.0 + maxf(380.0, tl_ms.x)
	tl.offset_bottom = 12.0 + tl_ms.y

	# ---- 左下：背包 / 事件 ----
	var bl := _panel()
	bl.custom_minimum_size = Vector2(560, 0)
	var bv := _vbox(6)
	var pack := _label("", FONT_SIZES["small"], Color("#94a3b8"))
	pack.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_live["pack"] = pack
	bv.add_child(pack)
	var toast := _label("", FONT_SIZES["body"], Color("#fde68a"))
	_live["toast"] = toast
	bv.add_child(toast)
	var erow := _hbox(8)
	erow.add_child(_btn(_tr("日志 (Tab)", "Log (Tab)"), func(): sim.logbook_open = true))
	erow.add_child(_btn(_tr("帮助 (?)", "Help (?)"), func(): sim.help_open = true))
	erow.add_child(_btn(_tr("放弃夜潜 (Esc)", "Abort (Esc)"), func(): sim.abort_confirm = true))
	bv.add_child(erow)
	bl.add_child(bv)
	body.add_child(bl)
	var bl_ms: Vector2 = bl.get_combined_minimum_size()
	var body_h: float = SCREEN.y - (TOP_H + 8.0)
	bl.offset_left = 18.0
	bl.offset_top = body_h - 18.0 - bl_ms.y
	bl.offset_right = 18.0 + maxf(560.0, bl_ms.x)
	bl.offset_bottom = body_h - 18.0

	# ---- 底部中：交互提示 ----
	var prompt := _label("", 20, Color("#fde68a"))
	_live["prompt"] = prompt
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -420
	prompt.offset_right = 420
	prompt.offset_bottom = -40
	prompt.offset_top = -96
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.add_child(prompt)

	# ---- 卡刀 QTE ----
	var jam := _panel(0, 0)
	jam.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	jam.offset_left = -330
	jam.offset_right = 330
	jam.offset_top = -60
	jam.offset_bottom = 60
	jam.add_theme_stylebox_override("panel", _sb(Color("#2a0d12"), Color("#f43f5e"), 10, 2))
	var jl := _label("", 22, Color("#fecdd3"))
	jl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	jl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_live["jam_label"] = jl
	jam.add_child(jl)
	jam.visible = sim.raid.jam_active
	_live["jam"] = jam
	body.add_child(jam)

	# ---- 抉择 A 提示 ----
	var ch := _panel(0, 0)
	ch.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	ch.offset_left = -300
	ch.offset_right = 300
	ch.offset_top = 130
	ch.offset_bottom = 190
	ch.add_theme_stylebox_override("panel", _sb(Color("#1a1408"), Color("#f59e0b"), 10))
	var cl := _label(_tr("按住 E 靠近他 —— 抉择 A", "Hold E to approach — Choice A"),
		FONT_SIZES["h3"], Color("#fde68a"))
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ch.add_child(cl)
	ch.visible = sim.raid.choice_open
	_live["choice"] = ch
	body.add_child(ch)

# ============================================================================
# 结算
# ============================================================================
func _build_report() -> void:
	var R: Dictionary = sim.last_report
	if R.is_empty():
		_build_base()
		return
	var meta := {"extracted": ["#4ade80", _tr("撤离成功", "EXTRACTED")],
		"dawn": ["#7dd3fc", _tr("天亮了 · 强行撤回", "DAWN · FORCED RETREAT")],
		"downed": ["#ef4444", _tr("重伤倒地 · 被拖回 602 室", "DOWNED · DRAGGED HOME")],
		"abort": ["#f59e0b", _tr("放弃夜潜", "RAID ABORTED")]}
	var reason := String(R["reason"])
	var m: Array = meta.get(reason, meta["abort"])
	var loc: Dictionary = R["loc"]

	var wrap := _vbox(12)
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.offset_left = 760
	wrap.offset_right = -40
	wrap.offset_top = 12
	wrap.offset_bottom = -20
	body.add_child(wrap)

	var head := _hbox(12)
	head.add_child(_label("■", 26, Color(String(m[0]))))
	var ttl := _label(String(m[1]) + " · " + String(loc["zh"] if sim.lang == "zh" else loc["en"]),
		30, Color("#e2e8f0"))
	ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(ttl)
	head.add_child(_chip(_tr("第 %d 天", "DAY %d") % int(R["day"]), Color("#334155")))
	wrap.add_child(head)

	var cols := _hbox(12)
	# 左列
	var left := _panel()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lv := _vbox(6)
	lv.add_child(_label(_tr("带回的物资", "HAUL"), FONT_SIZES["h3"], Color("#e2e8f0")))
	var gained: Dictionary = R["gained"]
	var order: Array = R.get("gained_order", gained.keys())
	if order.is_empty():
		lv.add_child(_label(_tr("空手而归。", "Nothing. You came back empty."), FONT_SIZES["body"], Color("#94a3b8")))
	var ggrid := _hbox(6)
	for k in order:
		ggrid.add_child(_chip("%s %s ×%d" % [sim.item_icon(String(k)), sim.item_name(String(k)), int(gained[k])],
			Color("#2a3a4a")))
	lv.add_child(ggrid)
	lv.add_child(_sep())
	lv.add_child(_label(_tr("本次记录", "THIS RUN"), FONT_SIZES["h3"], Color("#e2e8f0")))
	lv.add_child(_kv(_tr("搜刮容器", "Containers searched"), "%d / %d" % [int(R["looted"]), int(R["total"])]))
	lv.add_child(_kv(_tr("击杀狂暴者", "Rabid killed"), str(int(R["killed"]))))
	lv.add_child(_kv(_tr("救助半人", "Half-humans helped"), str(int(R["half_saved"]))))
	lv.add_child(_kv(_tr("归队状态", "Condition"),
		"%d HP · %d %s" % [int(R["hp"]), int(R["warmth"]), _tr("体温", "warmth")]))
	lv.add_child(_sep())
	lv.add_child(_label(_tr("武器架更新", "WEAPON RACK"), FONT_SIZES["h3"], Color("#e2e8f0")))
	var nw: Array = R.get("new_weapons", [])
	if nw.is_empty():
		lv.add_child(_label(_tr("没有新武器。收集度决定火力。", "Nothing new. Firepower follows what you collect."),
			FONT_SIZES["small"], Color("#94a3b8")))
	for wid in nw:
		var wd: Dictionary = Data.weapon(String(wid))
		var wn: String = String(wd.get("zh" if sim.lang == "zh" else "en", String(wid)))
		lv.add_child(_chip("🔓 " + _tr("解锁：", "Unlocked: ") + wn, Color("#166534"), Color("#bbf7d0")))
	left.add_child(lv)
	cols.add_child(left)

	# 右列
	var right := _panel()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rv := _vbox(6)
	rv.add_child(_label(_tr("事件", "EVENTS"), FONT_SIZES["h3"], Color("#e2e8f0")))
	var evs: Array = R.get("events", [])
	if evs.is_empty():
		rv.add_child(_label(_tr("什么都没发生。这在诺沃斯克是好事。",
			"Nothing happened. In Novorsk-17 that is a good night."), FONT_SIZES["small"], Color("#94a3b8")))
	var icons := {"good": "✚", "bad": "✖", "note": "·", "kill": "☠", "knife": "⚔", "witness": "👁"}
	var ev_scroll := ScrollContainer.new()
	ev_scroll.custom_minimum_size = Vector2(0, 330)
	ev_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var evv := _vbox(4)
	evv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for e in evs:
		var kind := String((e as Dictionary).get("t", "note"))
		var col2 := Color("#7f1d1d") if kind == "bad" else (Color("#166534") if kind == "good" else Color("#243040"))
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", _sb(Color("#0f1620"), col2, 5))
		var txt := String((e as Dictionary).get("zh" if sim.lang == "zh" else "en", ""))
		p.add_child(_label(String(icons.get(kind, "·")) + " " + txt, FONT_SIZES["small"], Color("#cbd5e1")))
		evv.add_child(p)
	ev_scroll.add_child(evv)
	rv.add_child(ev_scroll)
	rv.add_child(_sep())
	rv.add_child(_label(_tr("《双面工作日志》背面", "Back page of the logbook"), FONT_SIZES["small"], Color("#64748b")))
	rv.add_child(_label(sim.tally_marks(), 22, Color("#fbbf24")))
	rv.add_child(_label(_tr("良知 %d · 真名 %d", "Conscience %d · Names %d") % [int(sim.conscience), sim.names.size()],
		FONT_SIZES["small"], Color("#94a3b8")))
	if sim.mother_alive:
		rv.add_child(_sep())
		var mtxt := _tr("母亲：剩余腹透液可撑 %.1f 天。", "Mother: fluid left for %.1f days.") % sim.dial
		if sim.dial <= 1.0:
			mtxt += _tr(" 明晚之前必须带回 409 批腹透液。", " Bring back Batch-409 before tomorrow night.")
		rv.add_child(_label(mtxt, FONT_SIZES["small"],
			Color("#fca5a5") if sim.dial <= 1.0 else Color("#94a3b8")))
	right.add_child(rv)
	cols.add_child(right)
	wrap.add_child(cols)

	var brow := _hbox(10)
	var b_home := _btn(_tr("回到 602 室 · 睡到明天（Enter）", "Return to Room 602 · sleep (Enter)"), _report_sleep, true)
	b_home.custom_minimum_size = Vector2(520, 50)
	brow.add_child(b_home)
	brow.add_child(_btn(_tr("查看日志", "Logbook"), func(): sim.logbook_open = true))
	brow.add_child(_btn(_tr("帮助", "Help"), func(): sim.help_open = true))
	wrap.add_child(brow)

func _kv(k: String, v: String) -> Control:
	var h := _hbox(8)
	var kl := _label(k, FONT_SIZES["body"], Color("#94a3b8"))
	kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(kl)
	h.add_child(_label(v, FONT_SIZES["body"], Color("#e2e8f0")))
	return h

func _report_sleep() -> void:
	sim.to_base()
	sim.advance_day()
	_sig = ""

# ============================================================================
# 结局
# ============================================================================
func _build_ending() -> void:
	var prev: Dictionary = sim.ending_preview()
	var c := _vbox(16)
	c.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	c.offset_left = -520
	c.offset_right = 520
	c.offset_top = -280
	c.offset_bottom = 280
	body.add_child(c)
	var t := _label(_tr("一年之后 · 铁冬", "YEAR OF Z: IRON WINTER"), 40, Color("#e2e8f0"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(t)
	var sub := _label(String(prev["key"]), FONT_SIZES["body"], Color("#64748b"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(sub)
	var p := _panel()
	var pv := _vbox(12)
	pv.add_child(_label(_tr("结局判定", "ENDING RESOLUTION"), FONT_SIZES["h3"], Color("#94a3b8")))
	pv.add_child(_label(String(prev["zh"] if sim.lang == "zh" else prev["en"]), 20, Color("#fde68a")))
	pv.add_child(_sep())
	pv.add_child(_kv(_tr("第几天", "Day"), str(sim.day)))
	pv.add_child(_kv(_tr("母亲", "Mother"), _tr("健在", "alive") if sim.mother_alive else _tr("已离世", "lost")))
	pv.add_child(_kv(_tr("卌 划痕", "Strokes"), sim.tally_marks()))
	pv.add_child(_kv(_tr("良知", "Conscience"), str(int(sim.conscience))))
	pv.add_child(_kv(_tr("真名", "Names"), str(sim.names.size())))
	pv.add_child(_kv(_tr("真相在手", "Truth"), _tr("是", "yes") if bool(sim.flags.get("truth", false)) else _tr("否", "no")))
	p.add_child(pv)
	c.add_child(p)
	var row := _hbox(12)
	row.add_child(_btn(_tr("回到 602 室", "Back to Room 602"), func(): sim.phase = "base"))
	row.add_child(_btn(_tr("重新开始", "New game"), _start_game))
	row.add_child(_btn(_tr("灰盒测试场（F1）", "Greybox Gym (F1)"),
		func(): get_tree().change_scene_to_file("res://scenes/gym.tscn")))
	c.add_child(row)

# ============================================================================
# 模态框
# ============================================================================
func _build_modal() -> void:
	_clear(modal)
	_modal_kind = ""
	if sim.story_open:
		_build_story_modal()
	elif sim.logbook_open:
		_build_logbook_modal()
	elif sim.help_open:
		_build_help_modal()
	elif sim.abort_confirm:
		_build_abort_modal()
	elif sim.phase == "raid" and sim.raid != null and sim.raid.choice_open:
		_build_choice_modal()

func _dim() -> ColorRect:
	var d := ColorRect.new()
	d.color = Color(0.01, 0.02, 0.03, 0.82)
	d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	d.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_child(d)
	return d

func _modal_panel(w: float) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(center)
	var p := _panel(w)
	p.custom_minimum_size = Vector2(w, 0)
	center.add_child(p)
	var v := _vbox(12)
	p.add_child(v)
	return v

func _build_story_modal() -> void:
	_modal_kind = "story"
	_dim()
	var beat: Dictionary = Data.STORY.get(sim.story_id, {})
	if beat.is_empty():
		sim.story_open = false
		return
	var v := _modal_panel(940.0)
	v.add_child(_label("▲ " + String(beat.get("title_zh" if sim.lang == "zh" else "title_en", "")),
		30, Color("#f59e0b")))
	v.add_child(_sep())
	for line in beat.get("lines", []):
		var w := String((line as Dictionary).get("w", ""))
		if w != "":
			var who := PanelContainer.new()
			who.add_theme_stylebox_override("panel", _sb(Color("#101820"), Color("#3b4a5c"), 6))
			who.add_child(_label(w, FONT_SIZES["small"], Color("#7dd3fc")))
			v.add_child(who)
		v.add_child(_label(String((line as Dictionary).get("zh" if sim.lang == "zh" else "en", "")),
			FONT_SIZES["body"], Color("#cbd5e1")))
	v.add_child(_sep())
	v.add_child(_label(_tr("你写下 / 做了什么：", "What you write / do:"), FONT_SIZES["small"], Color("#64748b")))
	var choices: Array = beat.get("choices", [])
	for i in choices.size():
		var c: Dictionary = choices[i]
		var cls := String(c.get("cls", ""))
		var col := Color("#34d399") if cls == "good" else (Color("#f43f5e") if cls == "bad" else Color("#475569"))
		var b := _btn(String(c.get("zh" if sim.lang == "zh" else "en", "")), func(): _resolve_story(i), cls == "good")
		b.custom_minimum_size = Vector2(0, 46)
		b.add_theme_stylebox_override("normal", _sb(Color("#131b25"), col, 8))
		b.add_theme_stylebox_override("hover", _sb(Color("#1c2836"), col, 8))
		v.add_child(b)
		v.add_child(_label("　" + String(c.get("d_zh" if sim.lang == "zh" else "d_en", "")),
			FONT_SIZES["small"], Color("#8fa0b4")))

func _resolve_story(idx: int) -> void:
	var res: Dictionary = sim.resolve_story(idx)
	if not res.is_empty():
		ui_sfx.emit("beep")
	_sig = ""

func _build_choice_modal() -> void:
	_modal_kind = "choice"
	if sim.raid == null or sim.raid.choice_ent == null:
		sim.raid.choice_open = false
		return
	_dim()
	var e = sim.raid.choice_ent
	var R = sim.raid
	var has_med: bool = int(R.load.get("asp", 0)) > 0 and int(R.load.get("water", 0)) > 0
	var v := _modal_panel(900.0)
	v.add_child(_label(_tr("抉择 A · 他在发烧", "CHOICE A · He Is Burning Up"), 28, Color("#f59e0b")))
	v.add_child(_label(_tr(
		"一个半人蜷在暖气井里。瞳孔还在，但体温高得吓人。对面楼顶有清杀队的红外点。",
		"A half-human curled in the heating shaft. His pupils are still there, but his fever is terrifying. An IR dot moves on the roof opposite."),
		FONT_SIZES["body"], Color("#cbd5e1")))
	v.add_child(_sep())
	v.add_child(_btn(_tr("A1 喂阿司匹林 + 热水（消耗各 1）", "A1 Aspirin + hot water (1 each)"),
		func(): _choice(0), true))
	if not has_med:
		v.add_child(_label(_tr("　你身上没有阿司匹林和热水。", "　You have no aspirin or water."),
			FONT_SIZES["small"], Color("#fca5a5")))
	v.add_child(_btn(_tr("A2 绕行，别惹麻烦（良知 −2）", "A2 Walk away (Conscience −2)"),
		func(): _choice(1)))
	v.add_child(_btn(_tr("A3 撬棍灭口，划一道卌（良知 −10）", "A3 Crowbar. One more stroke (Conscience −10)"),
		func(): _choice(2)))
	v.add_child(_sep())
	v.add_child(_label(_tr("按 Esc 先不决定（他会继续烧）。", "Esc to decide later (he keeps burning)."),
		FONT_SIZES["small"], Color("#64748b")))

func _choice(idx: int) -> void:
	if sim.raid == null:
		return
	sim.raid.set_choice(idx)
	if sim.raid.choice_result.get("ok", true) == false:
		sim.raid.choice_open = false
	_sig = ""

func _build_logbook_modal() -> void:
	_modal_kind = "logbook"
	_dim()
	var v := _modal_panel(860.0)
	v.add_child(_label(_tr("《双面工作日志》", "THE TWO-SIDED WORK LOGBOOK"), 30, Color("#e2e8f0")))
	v.add_child(_label(_tr("正面是调度单编号，背面是只有你能看懂的字。",
		"The front is dispatch numbers. The back is writing only you can read."),
		FONT_SIZES["body"], Color("#94a3b8")))
	v.add_child(_sep())
	v.add_child(_kv(_tr("第几天", "Day"), str(sim.day)))
	v.add_child(_kv(_tr("母亲", "Mother"), _tr("健在", "alive") if sim.mother_alive else _tr("已离世", "lost")))
	v.add_child(_kv(_tr("良知", "Conscience"), str(int(sim.conscience))))
	v.add_child(_sep())
	v.add_child(_label(_tr("背面 · 卌 划痕", "BACK PAGE · STROKES"), FONT_SIZES["h3"], Color("#fbbf24")))
	v.add_child(_label(sim.tally_marks(), 30, Color("#fbbf24")))
	v.add_child(_label(_tr("每划一道，就有一个人的名字从纸上消失。",
		"Every stroke is a name erased from the paper."), FONT_SIZES["small"], Color("#8b6914")))
	v.add_child(_sep())
	v.add_child(_label(_tr("真名（%d）", "REAL NAMES (%d)") % sim.names.size(), FONT_SIZES["h3"], Color("#e2e8f0")))
	if sim.names.is_empty():
		v.add_child(_label(_tr("还没有人为你在纸上活下来。", "Nobody is alive on paper yet."),
			FONT_SIZES["body"], Color("#64748b")))
	for n in sim.names:
		v.add_child(_label("✒ " + String(n), FONT_SIZES["body"], Color("#cbd5e1")))
	v.add_child(_sep())
	v.add_child(_label(_tr("事件记录", "EVENT LOG"), FONT_SIZES["h3"], Color("#e2e8f0")))
	for l in sim.recent_log(10):
		v.add_child(_label("Д%d · %s" % [int(l["day"]), String(l["zh"] if sim.lang == "zh" else l["en"])],
			FONT_SIZES["small"], Color("#8fa0b4")))
	v.add_child(_btn(_tr("合上（Tab / Esc）", "Close (Tab / Esc)"), func(): sim.logbook_open = false))

func _build_help_modal() -> void:
	_modal_kind = "help"
	_dim()
	var v := _modal_panel(940.0)
	v.add_child(_label(_tr("操作 · 规则", "CONTROLS · RULES"), 30, Color("#e2e8f0")))
	v.add_child(_sep())
	var rows := [
		[_tr("移动 / 瞄准", "Move / aim"), "WASD · 鼠标"],
		[_tr("潜行 / 冲刺", "Sneak / sprint"), _tr("Ctrl · Shift（耗体力）", "Ctrl · Shift (stamina)")],
		[_tr("攻击", "Attack"), _tr("空格 / 左键（砍骨刀正向命中会卡刀，1.5s 内连按 6 次）",
			"Space / LMB (cleaver front hit jams: 6 presses in 1.5s)")],
		[_tr("交互", "Interact"), _tr("按住 E：搜刮 1.7s · 卡门 1.2s（锁 15s）· 破门 0.8s · 撤离 1.5s",
			"Hold E: search 1.7s · wedge 1.2s (15s lock) · pry 0.8s · extract 1.5s")],
		[_tr("热水 / 绷带", "Water / bandage"), _tr("Q（体温 +22）· H（生命 +26）", "Q (+22 warmth) · H (+26 HP)")],
		[_tr("扔罐 / 装弹", "Throw tin / reload"), "G · R"],
		[_tr("日志 / 帮助 / 语言", "Logbook / help / lang"), "Tab · ? · L"],
		[_tr("放弃夜潜", "Abort raid"), "Esc"],
	]
	for r in rows:
		var h := _hbox(12)
		var k := _label(String(r[0]), FONT_SIZES["body"], Color("#7dd3fc"))
		k.custom_minimum_size = Vector2(240, 0)
		h.add_child(k)
		var val := _label(String(r[1]), FONT_SIZES["body"], Color("#cbd5e1"))
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(val)
		v.add_child(h)
	v.add_child(_sep())
	v.add_child(_label(_tr(
		"视野 90°、12m（镜片碎裂后 7.2m），1.8m 内为近身感知。体温降到 25 以下开始掉血。\n" \
		+ "天亮前没到撤离点：只带得回一半物资（偶数位）并 −22 HP；倒地或放弃：什么都带不回。",
		"FOV 90°, 12m sight (7.2m once the lens cracks), 1.8m near-sense. Below 25 warmth you start losing HP.\n" \
		+ "Not back by dawn: you keep every other item and lose 22 HP. Downed or abort: nothing comes home."),
		FONT_SIZES["small"], Color("#94a3b8")))
	v.add_child(_btn(_tr("知道了（Esc）", "Got it (Esc)"), func(): sim.help_open = false))

func _build_abort_modal() -> void:
	_modal_kind = "abort"
	_dim()
	var v := _modal_panel(720.0)
	v.add_child(_label(_tr("放弃这次夜潜？", "Abort this raid?"), 28, Color("#f59e0b")))
	v.add_child(_label(_tr("你会丢掉背包里的一切，但能活着回到 602 室。母亲还在等那袋腹透液。",
		"You lose everything in the pack but walk home alive. Your mother is still waiting for that bag."),
		FONT_SIZES["body"], Color("#cbd5e1")))
	var row := _hbox(10)
	row.add_child(_btn(_tr("继续夜潜（Esc）", "Keep going (Esc)"), func(): sim.abort_confirm = false, true))
	row.add_child(_btn(_tr("撤（放弃一切）", "Abort (lose all)"), func(): _do_abort))
	v.add_child(row)

func _do_abort() -> void:
	sim.abort_confirm = false
	if sim.raid != null:
		sim.raid.finish("abort")
		sim.finish_raid("abort")
	_sig = ""
