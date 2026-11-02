extends CanvasLayer
## GymHUD.gd — 5 合 1 灰盒测试场的 CanvasLayer HUD（纯代码构建，无 .tscn 依赖）。
##
## 对应 HTML 原型的右侧栏 + 顶栏 + 三个模态框：
##   · 顶栏：区域名 / 姿态 / 灰狼犬三态 / HP / BPM / 罐头皮 / 卌 划痕 / 语言
##   · 侧栏：生命体征、5 项灰盒验证清单、房间简报、实时电传事件流、功能按钮
##   · 模态框：《双面工作日志》(Tab)、抉择 A（A1/A2/A3）、锁骨卡刀 6 连按 QTE
## HUD 每帧由 Gym.gd 调用 refresh() 从 Sim 拉取数据，不做信号耦合；
## 只有按钮点击会直接调用 Sim 的方法，并通过 ui_sfx 信号请求音效。

signal ui_sfx(name: String)

const SimScript := preload("res://scripts/GymSim.gd")
const SovietUI := preload("res://scripts/ui/SovietUI.gd")
const SovietChrome := preload("res://scripts/ui/SovietChrome.gd")

const SCREEN := Vector2(1920, 1080)
const SIDEBAR_X := 1556.0
const SIDEBAR_W := 350.0

var sim
var font: SystemFont
var ui_theme: Theme
var root: Control

# 顶栏
var _title: Label
var _subtitle: Label
var _zone: Label
var _stance: Label
var _dog: Label
var _hp_top: Label
var _bpm_top: Label
var _cans_top: Label
var _tally_top: Label
var _lang_badge: Label

# 侧栏
var _hp_bar: ProgressBar
var _hp_side: Label
var _weapon: Label
var _tally_side: Label
var _task_rows: Array = []
var _task_progress: Label
var _brief_title: Label
var _brief_desc: Label
var _feed_box: VBoxContainer
var _feed_sig := ""
var _names_sig := ""
var _act_crouch: Button
var _act_throw: Button
var _act_interact: Button
var _act_swing: Button
var _act_drink: Button
var _btn_logbook: Button
var _btn_lang: Button
var _btn_glasses: Button
var _btn_mute: Button
var _btn_reset: Button
var _hint: Label
var _banner: Label

# 日志模态框
var _logbook_root: Control
var _logbook_title: Label
var _logbook_names: VBoxContainer
var _logbook_tally_row: HBoxContainer
var _logbook_tally_count: Label
var _logbook_tally_desc: Label
var _logbook_close: Button
var _tally_marks: Array = []

# 抉择 A 模态框
var _choice_root: Control
var _choice_title: Label
var _choice_body: Label
var _choice_a1: Button
var _choice_a2: Button
var _choice_a3: Button
var _choice_a1_desc: Label
var _choice_a2_desc: Label
var _choice_a3_desc: Label

# QTE
var _qte_root: Control
var _qte_title: Label
var _qte_sub: Label
var _qte_bar: ProgressBar
var _qte_count: Label
var _qte_btn: Button
var _qte_hint: Label

func _ready() -> void:
	layer = 20
	font = SovietUI.body_font()
	ui_theme = Theme.new()
	ui_theme.default_font = font
	ui_theme.default_font_size = 13

	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = ui_theme
	add_child(root)

	# 整屏金属框：灰盒测试场也穿同一身制服
	var chrome := SovietChrome.new()
	chrome.name = "Chrome"
	chrome.font = SovietUI.mono_font()
	chrome.zone = "НОВОРСК-17 · ПОЛИГОН 5-В-1"
	chrome.accent = SovietUI.OCHRE_DIM
	root.add_child(chrome)

	_build_top_bar()
	_build_sidebar()
	_build_hint()
	_build_logbook_modal()
	_build_choice_modal()
	_build_qte_modal()

func bind_sim(s) -> void:
	sim = s
	refresh()

# ============================================================================
# 构建
# ============================================================================
func _style(bg: Color, border: Color, bw: int = 1, _radius: int = 6, margin: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = bw
	sb.border_width_top = bw
	sb.border_width_right = bw
	sb.border_width_bottom = bw
	sb.corner_radius_top_left = 0
	sb.corner_radius_top_right = 0
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin * 0.7
	sb.content_margin_bottom = margin * 0.7
	return sb

func _label(parent: Node, text: String, size: int = 13, color: Color = Color("#e3ddcd")) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _wrap_label(parent: Node, text: String, size: int = 12, color: Color = Color("#928c7c")) -> Label:
	var l := _label(parent, text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(320, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _card(parent: Node, min_height: float, bg: Color = Color(0.043, 0.06, 0.086, 0.94),
		border: Color = Color(0.13, 0.17, 0.23, 1.0)) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(bg, border, 1, 6, 10))
	panel.custom_minimum_size = Vector2(SIDEBAR_W, min_height)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vb)
	return vb

func _button(parent: Node, text: String, size: int = 12) -> Button:
	var b := Button.new()
	b.text = text
	SovietUI.dress_button(b, false, size)
	b.custom_minimum_size = Vector2(0, 30)
	parent.add_child(b)
	return b

func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.position = Vector2.ZERO
	bar.size = Vector2(SCREEN.x, 66)
	bar.custom_minimum_size = Vector2(SCREEN.x, 66)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", _style(
		Color(0.035, 0.047, 0.063, 0.97), Color(0.15, 0.19, 0.25, 1.0), 0, 0, 14))
	root.add_child(bar)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(hb)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 1)
	left.custom_minimum_size = Vector2(520, 0)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(left)
	_title = _label(left, "", 16, Color("#f5efdd"))
	_subtitle = _label(left, "", 11, Color("#6d6f66"))

	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 2)
	mid.custom_minimum_size = Vector2(600, 0)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(mid)
	_zone = _label(mid, "", 14, Color("#c8a257"))
	_stance = _label(mid, "", 11, Color("#a7e8bf"))
	_dog = _label(mid, "", 11, Color("#b2ab9f"))

	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 18)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_END
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(right)
	_hp_top = _label(right, "", 14, Color("#e0897e"))
	_bpm_top = _label(right, "", 14, Color("#e0897e"))
	_cans_top = _label(right, "", 14, Color("#d9a326"))
	_tally_top = _label(right, "", 14, Color("#c8a257"))
	_lang_badge = _label(right, "", 12, Color("#b2ab9f"))

func _build_sidebar() -> void:
	var col := VBoxContainer.new()
	col.position = Vector2(SIDEBAR_X, 76)
	col.size = Vector2(SIDEBAR_W, 990)
	col.custom_minimum_size = Vector2(SIDEBAR_W, 990)
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)

	# --- 生命体征 ---
	var vit := _card(col, 150, Color(0.055, 0.07, 0.09, 0.94), Color(0.2, 0.25, 0.32, 1.0))
	var vh := HBoxContainer.new()
	vh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vit.add_child(vh)
	_label(vh, "生命体征  VITALS", 12, Color("#928c7c"))
	_hp_side = _label(vit, "HP 100%", 12, Color("#e0897e"))
	_hp_bar = ProgressBar.new()
	_hp_bar.max_value = 100.0
	_hp_bar.value = 100.0
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(SIDEBAR_W - 24, 10)
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#b8281c")
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	_hp_bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.13, 0.18, 1.0)
	_hp_bar.add_theme_stylebox_override("background", bg)
	vit.add_child(_hp_bar)
	_weapon = _label(vit, "", 11, Color("#e3ddcd"))
	_tally_side = _label(vit, "", 11, Color("#c8a257"))

	# --- 灰盒验证清单 ---
	var chk := _card(col, 178, Color(0.055, 0.07, 0.09, 0.94), Color(0.2, 0.25, 0.32, 1.0))
	_label(chk, "📋 5 合 1 灰盒验证清单  GREYBOX TASKS", 12, Color("#c8a257"))
	for i in 5:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chk.add_child(row)
		var mark := _label(row, "○", 12, Color("#6d6f66"))
		mark.custom_minimum_size = Vector2(14, 0)
		var txt := _wrap_label(row, "", 11, Color("#928c7c"))
		txt.custom_minimum_size = Vector2(292, 0)
		_task_rows.append({"mark": mark, "text": txt, "id": "ABCDE"[i]})
	_task_progress = _label(chk, "0 / 5", 11, Color("#a7e8bf"))

	# --- 房间简报 ---
	var brief := _card(col, 190, Color(0.055, 0.07, 0.09, 0.94), Color(0.2, 0.25, 0.32, 1.0))
	_label(brief, "本轮测试区  ROOM BRIEF", 12, Color("#928c7c"))
	_brief_title = _label(brief, "", 12, Color("#c8a257"))
	_brief_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_brief_title.custom_minimum_size = Vector2(320, 0)
	_brief_desc = _wrap_label(brief, "", 11, Color(0.72, 0.78, 0.85))

	# --- 动作按钮（纯鼠标可玩，对应 HTML 底部操作栏） ---
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 5)
	col.add_child(acts)
	_act_crouch = _button(acts, "蹲伏", 11)
	_act_crouch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_act_crouch.pressed.connect(_on_crouch_pressed)
	_act_throw = _button(acts, "投罐", 11)
	_act_throw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_act_throw.pressed.connect(_on_throw_pressed)
	_act_interact = _button(acts, "交互", 11)
	_act_interact.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_act_interact.pressed.connect(_on_interact_pressed)
	_act_swing = _button(acts, "挥刀", 11)
	_act_swing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_act_swing.pressed.connect(_on_swing_pressed)
	_act_drink = _button(acts, "喝水", 11)
	_act_drink.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_act_drink.pressed.connect(_on_drink_pressed)

	# --- 功能按钮 ---
	var b1 := HBoxContainer.new()
	b1.add_theme_constant_override("separation", 6)
	col.add_child(b1)
	_btn_logbook = _button(b1, "📓 日志 [Tab]")
	_btn_logbook.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_logbook.pressed.connect(_on_logbook_pressed)
	_btn_lang = _button(b1, "🌐 EN / 中文")
	_btn_lang.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_lang.pressed.connect(_on_lang_pressed)

	var b2 := HBoxContainer.new()
	b2.add_theme_constant_override("separation", 6)
	col.add_child(b2)
	_btn_glasses = _button(b2, "👓 眼镜")
	_btn_glasses.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_glasses.pressed.connect(_on_glasses_pressed)
	_btn_mute = _button(b2, "🔊 音效")
	_btn_mute.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_mute.pressed.connect(_on_mute_pressed)
	_btn_reset = _button(b2, "↺ 重置")
	_btn_reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_reset.pressed.connect(_on_reset_pressed)

	# --- 实时电传 ---
	var feed_card := _card(col, 210, Color(0.055, 0.07, 0.09, 0.94), Color(0.2, 0.25, 0.32, 1.0))
	_label(feed_card, "📻 诺沃斯克-17 实时电传  LIVE TELETYPE", 12, Color("#928c7c"))
	_feed_box = VBoxContainer.new()
	_feed_box.add_theme_constant_override("separation", 4)
	_feed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feed_card.add_child(_feed_box)


func _build_hint() -> void:
	var bar := PanelContainer.new()
	bar.position = Vector2(20, 1036)
	bar.custom_minimum_size = Vector2(1500, 30)
	bar.size = Vector2(1500, 30)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", _style(
		Color(0.02, 0.03, 0.04, 0.82), Color(0.12, 0.16, 0.21, 1.0), 1, 5, 6))
	root.add_child(bar)
	_hint = _label(bar, "", 11, Color(0.65, 0.71, 0.78))

	_banner = _label(root, "", 20, Color("#63d18a"))
	_banner.position = Vector2(500, 84)
	_banner.custom_minimum_size = Vector2(800, 0)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_banner.add_theme_constant_override("shadow_offset_x", 2)
	_banner.add_theme_constant_override("shadow_offset_y", 2)
	_banner.visible = false

func _build_logbook_modal() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.visible = false
	root.add_child(dim)
	_logbook_root = dim

	var panel := PanelContainer.new()
	panel.position = Vector2(430, 130)
	panel.custom_minimum_size = Vector2(1060, 800)
	panel.size = Vector2(1060, 800)
	panel.add_theme_stylebox_override("panel", _style(
		Color(0.075, 0.066, 0.055, 0.99), Color(0.45, 0.35, 0.22, 1.0), 2, 10, 18))
	dim.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var head := HBoxContainer.new()
	vb.add_child(head)
	_logbook_title = _label(head, "《工作日志》 Рабочий Журнал", 20, Color("f5deb3"))
	_logbook_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_logbook_close = _button(head, "✕ 合上 [Tab]", 12)
	_logbook_close.custom_minimum_size = Vector2(150, 34)
	_logbook_close.pressed.connect(_on_logbook_pressed)

	vb.add_child(HSeparator.new())
	_label(vb, "背面 · 真名与已验证的活人   VERIFIED REAL NAMES", 13, Color("a8a29e"))
	_logbook_names = VBoxContainer.new()
	_logbook_names.add_theme_constant_override("separation", 4)
	vb.add_child(_logbook_names)

	vb.add_child(HSeparator.new())
	_label(vb, "背面 · 俄式五道划痕「卌」   TALLY OF BLOOD", 13, Color("a8a29e"))
	_logbook_tally_row = HBoxContainer.new()
	_logbook_tally_row.add_theme_constant_override("separation", 14)
	vb.add_child(_logbook_tally_row)
	for i in 5:
		var mark := _label(_logbook_tally_row,
			"╱" if i == 4 else "｜", 34, Color("#5c2417"))
		mark.custom_minimum_size = Vector2(26, 46)
		_tally_marks.append(mark)
	_logbook_tally_count = _label(vb, "0 / 5 STROKES", 13, Color("#e0897e"))
	_logbook_tally_desc = _wrap_label(vb, "", 13, Color("d6d3d1"))
	_logbook_tally_desc.custom_minimum_size = Vector2(980, 0)

	vb.add_child(HSeparator.new())
	var footer := _label(vb,
		"正面：官方台账（0 人 / 已签收）  ·  背面：真名与划痕  ·  [Tab] 合上",
		12, Color("78716c"))
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _build_choice_modal() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.visible = false
	root.add_child(dim)
	_choice_root = dim

	var panel := PanelContainer.new()
	panel.position = Vector2(430, 240)
	panel.custom_minimum_size = Vector2(1060, 560)
	panel.size = Vector2(1060, 560)
	panel.add_theme_stylebox_override("panel", _style(
		Color(0.055, 0.06, 0.07, 0.99), Color(0.36, 0.24, 0.16, 1.0), 2, 10, 20))
	dim.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	_choice_title = _label(vb, "抉择 A · CHOICE A", 22, Color("#c8a257"))
	_choice_body = _wrap_label(vb,
		"涵洞里蜷缩着一个手背灰鳞正在剥落、体温正在回退的年轻人。他还有心跳、还有名字——但电传机已经把他划成了 0 人。",
		13, Color(0.85, 0.88, 0.92))
	_choice_body.custom_minimum_size = Vector2(1000, 40)
	vb.add_child(HSeparator.new())

	_choice_a1 = _button(vb, "[A1] 💊 喂阿司匹林与温水（+0 划痕）", 14)
	_choice_a1.custom_minimum_size = Vector2(1000, 38)
	_choice_a1.pressed.connect(_on_choice.bind("A1"))
	_choice_a1_desc = _wrap_label(vb,
		"救下他。他将告诉你老伊万在西站水塔的暗号，并证实拉娜被锁进铁壳号第三节车厢。工作日志保持零划痕。",
		11, Color("#a7e8bf"))
	_choice_a1_desc.custom_minimum_size = Vector2(1000, 0)

	_choice_a3 = _button(vb, "[A3] 🩸 撬棍灭口并搜刮（+2 道卌字血划痕）", 14)
	_choice_a3.custom_minimum_size = Vector2(1000, 38)
	_choice_a3.pressed.connect(_on_choice.bind("A3"))
	_choice_a3_desc = _wrap_label(vb,
		"砸死他，搜出两只罐头。工作日志背面会多出两道划痕；终局鹰嘴崖的救赎将被永久关闭。",
		11, Color("#e0897e"))
	_choice_a3_desc.custom_minimum_size = Vector2(1000, 0)

	_choice_a2 = _button(vb, "[A2] 🚪 退开半步（暂不处置）", 14)
	_choice_a2.custom_minimum_size = Vector2(1000, 38)
	_choice_a2.pressed.connect(_on_choice.bind("A2"))
	_choice_a2_desc = _wrap_label(vb, "离开涵洞。他还在那里抽搐，声波会继续在黑暗里回荡。",
		11, Color("#928c7c"))
	_choice_a2_desc.custom_minimum_size = Vector2(1000, 0)

func _build_qte_modal() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.42)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.visible = false
	root.add_child(dim)
	_qte_root = dim

	var panel := PanelContainer.new()
	panel.position = Vector2(560, 700)
	panel.custom_minimum_size = Vector2(800, 250)
	panel.size = Vector2(800, 250)
	panel.add_theme_stylebox_override("panel", _style(
		Color(0.075, 0.045, 0.045, 0.98), Color(0.62, 0.19, 0.19, 1.0), 2, 10, 18))
	dim.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	_qte_title = _label(vb, "🩸 锁骨卡刀 · COLLARBONE BLADE JAM", 20, Color("#e0897e"))
	_qte_sub = _wrap_label(vb,
		"砍骨刀卡死在瓦西里的左锁骨缝里。连按 6 次把刀拔出来！",
		13, Color(0.9, 0.85, 0.85))
	_qte_sub.custom_minimum_size = Vector2(740, 0)

	_qte_bar = ProgressBar.new()
	_qte_bar.max_value = 6.0
	_qte_bar.value = 0.0
	_qte_bar.show_percentage = false
	_qte_bar.custom_minimum_size = Vector2(740, 18)
	var qfill := StyleBoxFlat.new()
	qfill.bg_color = Color("#b8281c")
	qfill.corner_radius_top_left = 4
	qfill.corner_radius_top_right = 4
	qfill.corner_radius_bottom_left = 4
	qfill.corner_radius_bottom_right = 4
	_qte_bar.add_theme_stylebox_override("fill", qfill)
	var qbg := StyleBoxFlat.new()
	qbg.bg_color = Color(0.16, 0.09, 0.09, 1.0)
	_qte_bar.add_theme_stylebox_override("background", qbg)
	vb.add_child(_qte_bar)

	_qte_btn = _button(vb, "🗡️ 用力拔刀！[SPACE / 左键]", 15)
	_qte_btn.custom_minimum_size = Vector2(740, 44)
	_qte_btn.pressed.connect(_on_qte_pressed)
	_qte_count = _label(vb, "0 / 6", 13, Color("#e0897e"))
	_qte_hint = _label(vb, "连按得越快，越能听见他恢复清醒的呼吸。", 11, Color("a8a29e"))

# ============================================================================
# 每帧刷新
# ============================================================================
func refresh() -> void:
	if sim == null or root == null:
		return
	var zh: bool = sim.lang == "zh"
	_title.text = "《Z年纪事：凛冬铁轨 v4.0》5合1 可玩灰盒测试场" if zh \
		else "Year of Z: Iron Winter v4.0 — Playable 5-in-1 Greybox Gym"
	_subtitle.text = ("WASD 移动 · 鼠标定向 · Ctrl 蹲伏 · Shift 冲刺 · G 投掷罐头 · E 交互 · Space 挥刀 · Q 喝水"
		if zh else
		"WASD Move · Mouse Aim · Ctrl Crouch · Shift Sprint · G Throw Can · E Interact · Space Swing · Q Drink")
	_zone.text = ("区域  " if zh else "ZONE  ") + String(sim.current_room()["zh"] if zh else sim.current_room()["en"])
	_stance.text = ("姿态  " if zh else "STANCE  ") + sim.stance_text()
	_dog.text = ("灰烬  " if zh else "ASH  ") + sim.dog_state_text()
	_hp_top.text = "HP %d%%" % int(sim.player.hp)
	_bpm_top.text = "BPM %d" % int(sim.player.bpm)
	_cans_top.text = ("🍾 罐头 %d" if zh else "🍾 CANS %d") % sim.player.cans
	_tally_top.text = "卌 %d/5" % sim.tally_stroke_marks()
	_lang_badge.text = "中文" if zh else "EN"

	_hp_bar.value = sim.player.hp
	_hp_side.text = ("HP %d%%   ·   心率 %d BPM" if zh else "HP %d%%   ·   %d BPM") \
		% [int(sim.player.hp), int(sim.player.bpm)]
	_weapon.text = ("武器  " if zh else "WEAPON  ") + sim.weapon_text()
	_tally_side.text = ("卌 划痕 %d/5   ·   罐头 %d" if zh else "卌 TALLY %d/5   ·   CANS %d") \
		% [sim.tally_stroke_marks(), sim.player.cans]

	var done: int = int(sim.tasks_done_count())
	_task_progress.text = ("%d / 5 已验证" if zh else "%d / 5 Verified") % done
	for i in _task_rows.size():
		var row: Dictionary = _task_rows[i]
		var t: Dictionary = SimScript.TASKS[i]
		var finished: bool = sim.tasks_done[row["id"]]
		row["mark"].text = "✓" if finished else "○"
		row["mark"].add_theme_color_override("font_color",
			Color("#63d18a") if finished else Color("#6d6f66"))
		row["text"].text = t["zh"] if zh else t["en"]
		row["text"].add_theme_color_override("font_color",
			Color("#a7e8bf") if finished else Color("#928c7c"))

	var room_id: String = sim.current_room()["id"]
	var brief: Dictionary = SimScript.ROOM_BRIEF[room_id]
	_brief_title.text = String(sim.current_room()["zh"] if zh else sim.current_room()["en"])
	_brief_desc.text = brief["zh"] if zh else brief["en"]

	var sig := ("zh" if zh else "en") + "|"
	var shown: int = mini(3, sim.feed.size())
	for i in shown:
		sig += String(sim.feed[i]["time"]) + String(sim.feed[i]["zh"])
	if sig != _feed_sig:
		_feed_sig = sig
		_rebuild_feed(shown, zh)

	# 模态框可见性
	_logbook_root.visible = sim.logbook_open
	_choice_root.visible = sim.choice_modal_open
	_qte_root.visible = sim.qte_active
	if sim.qte_active:
		_qte_bar.value = sim.qte_count
		_qte_count.text = "%d / %d" % [sim.qte_count, sim.qte_needed]
		_qte_btn.text = ("🗡️ 用力拔刀！(%d / %d)" if zh else "🗡️ Wrench It Free! (%d / %d)") \
			% [sim.qte_count, sim.qte_needed]

	_update_logbook(zh)
	_update_choice(zh)
	_update_buttons(zh)

	_hint.text = ("WASD 移动 · 鼠标定朝向 · Ctrl 蹲伏 · Shift 冲刺 · G 投掷空罐头 · E 交互/卡门/推饭盒 · Space 挥刀 · Q 喝水 · Tab 日志 · 1~5 传送 · L 语言 · F 眼镜 · M 音效 · F5 重置 · F1 战役主循环 · F2 Room A 夜潜切片 · 触屏：左半屏摇杆移动（推满冲刺）· 右半屏拖动瞄准 · 轻点挥刀"
		if zh else
		"WASD Move · Mouse Aim · Ctrl Crouch · Shift Sprint · G Throw Can · E Interact/Wedge · Space Swing · Q Drink · Tab Logbook · 1–5 Teleport · L Language · F Glasses · M Mute · F5 Reset · F1 Campaign · F2 Room A Slice · Touch: left joystick move (full push = sprint) · right drag aim · tap swing")

	_banner.visible = done >= 5
	_banner.text = ("✅ 5 / 5 灰盒验证全部通过 · 按 F2 进入 Room A 夜潜垂直切片" if zh
		else "✅ 5 / 5 GREYBOX VERIFIED · Press F2 for the Room A night-stalk slice")

func _rebuild_feed(shown: int, zh: bool) -> void:
	for c in _feed_box.get_children():
		_feed_box.remove_child(c)
		c.queue_free()
	for i in shown:
		var item: Dictionary = sim.feed[i]
		var txt := "[%s] %s" % [String(item["time"]), String(item["zh"] if zh else item["en"])]
		var l := _label(_feed_box, txt, 10, _feed_color(String(item["color"])))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(312, 0)
	if shown == 0:
		_label(_feed_box, "…", 10, Color("#6d6f66"))

func _feed_color(cls: String) -> Color:
	if cls.contains("emerald"):
		return Color("#a7e8bf")
	if cls.contains("rose"):
		return Color("fda4af")
	if cls.contains("amber"):
		return Color("#d9a326")
	if cls.contains("cyan"):
		return Color("67e8f9")
	if cls.contains("sky"):
		return Color("#b2ab9f")
	return Color("#d8d1bf")

func _update_logbook(zh: bool) -> void:
	if not sim.logbook_open:
		return
	_logbook_title.text = "《工作日志》 Рабочий Журнал" if zh else "The Work Logbook · Рабочий Журнал"
	_logbook_close.text = "✕ 合上 [Tab]" if zh else "✕ Close [Tab]"
	var names_sig := ("zh" if zh else "en") + "|" + str(sim.verified_names.size())
	for item in sim.verified_names:
		names_sig += String(item["id"])
	if names_sig != _names_sig:
		_names_sig = names_sig
		for c in _logbook_names.get_children():
			_logbook_names.remove_child(c)
			c.queue_free()
		_label(_logbook_names, "正面 · 官方台账：0 人 / 已签收 / 档案号已划除" if zh
			else "FRONT · OFFICIAL LEDGER: 0 PERSONS / SIGNED / FILE NUMBER CROSSED OUT",
			11, Color("78716c"))
		for item in sim.verified_names:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			_logbook_names.add_child(row)
			_label(row, "✓", 12, Color("#63d18a"))
			var name_l := _wrap_label(row, String(item["zh"] if zh else item["en"]), 11, Color("e7e5e4"))
			name_l.custom_minimum_size = Vector2(830, 0)
			_label(row, "VERIFIED", 10, Color("#63d18a"))
	var strokes: int = sim.tally_stroke_marks()
	for i in _tally_marks.size():
		var mark: Label = _tally_marks[i]
		mark.add_theme_color_override("font_color",
			Color("b91c1c") if i < strokes else Color(0.35, 0.3, 0.26, 0.35))
	_logbook_tally_count.text = "%d / 5 STROKES" % strokes
	if zh:
		_logbook_tally_desc.text = "当前背面纸页干净（0 道划痕）。若保持零划痕至终局鹰嘴崖，可救活第三节车厢里的妹妹拉娜（0420）。" \
			if strokes == 0 else \
			"当前已划下 %d 道血痕（卌）。在鹰嘴崖终局将触发【结局 B：荒诞解放（破门但痛失妹妹）】。" % strokes
	else:
		_logbook_tally_desc.text = "Back page is unstained (0 strokes). Maintaining zero strokes to Eagle's Crag saves Sister Lana (0420)." \
			if strokes == 0 else \
			"Carved %d blood strokes (卌). Will trigger [Ending B: Absurd Liberation (Gates open, Sister lost)]." % strokes

func _update_choice(zh: bool) -> void:
	if not sim.choice_modal_open:
		return
	_choice_title.text = "抉择 A · CHOICE A" if zh else "CHOICE A · 抉择 A"
	_choice_body.text = ("涵洞里蜷缩着一个手背灰鳞正在剥落、体温正在回退的年轻人。他还有心跳、还有名字——但电传机已经把他划成了 0 人。"
		if zh else
		"A youth trembles in the culvert, grey scales peeling from his hands as his fever breaks. He still has a heartbeat, still has a name—but the teletype already zeroed him.")
	_choice_a1.text = "[A1] 💊 喂阿司匹林与温水（+0 划痕）" if zh else "[A1] 💊 Feed Aspirin & Warm Water (+0 Strokes)"
	_choice_a2.text = "[A2] 🚪 退开半步（暂不处置）" if zh else "[A2] 🚪 Step Back (Leave Him)"
	_choice_a3.text = "[A3] 🩸 撬棍灭口并搜刮（+2 道划痕）" if zh else "[A3] 🩸 Crowbar Execution (+2 Strokes)"
	_choice_a1_desc.text = ("救下他。他将告诉你老伊万在西站水塔的暗号，并证实拉娜被锁进铁壳号第三节车厢。工作日志保持零划痕。"
		if zh else
		"Save him. He reveals Old Ivan's water-tower cipher and confirms Lana is locked in Carriage No. 3. Logbook stays at zero strokes.")
	_choice_a2_desc.text = ("离开涵洞。他还在那里抽搐，声波会继续在黑暗里回荡。"
		if zh else "Walk away. He keeps convulsing; his acoustic ripples keep echoing in the dark.")
	_choice_a3_desc.text = ("砸死他，搜出两只罐头。工作日志背面会多出两道划痕；终局鹰嘴崖的救赎将被永久关闭。"
		if zh else
		"Kill him and loot two tins. Two strokes scar the Logbook; redemption at Eagle's Crag is permanently closed.")

func _update_buttons(zh: bool) -> void:
	_act_crouch.text = "蹲伏 Ctrl" if zh else "Crouch Ctrl"
	_act_throw.text = "投罐 G" if zh else "Throw G"
	_act_interact.text = "交互 E" if zh else "Use E"
	_act_swing.text = "挥刀 Space" if zh else "Swing Space"
	_act_drink.text = "喝水 Q" if zh else "Drink Q"
	_btn_logbook.text = "📓 日志 [Tab]" if zh else "📓 Logbook [Tab]"
	_btn_lang.text = "🌐 EN / 中文"
	_btn_glasses.text = ("👓 眼镜: 破损" if sim.glasses_cracked else "👓 眼镜: 完好") if zh \
		else ("👓 Cracked" if sim.glasses_cracked else "👓 Intact")
	_btn_mute.text = ("🔇 静音" if sim.muted else "🔊 音效") if zh else ("🔇 Muted" if sim.muted else "🔊 SFX")
	_btn_reset.text = "↺ 重置全场" if zh else "↺ Reset Gym"

# ============================================================================
# 按钮回调
# ============================================================================
func _on_crouch_pressed() -> void:
	if sim == null:
		return
	sim.toggle_crouch()
	ui_sfx.emit("beep")

func _on_throw_pressed() -> void:
	if sim == null:
		return
	sim.throw_can()
	ui_sfx.emit("can")

func _on_interact_pressed() -> void:
	if sim == null:
		return
	sim.interact()
	ui_sfx.emit("beep")

func _on_swing_pressed() -> void:
	if sim == null:
		return
	sim.swing()
	ui_sfx.emit("wedge")

func _on_drink_pressed() -> void:
	if sim == null:
		return
	sim.drink()
	ui_sfx.emit("beep")

func _on_logbook_pressed() -> void:
	if sim == null:
		return
	sim.toggle_logbook()
	ui_sfx.emit("beep")

func _on_lang_pressed() -> void:
	if sim == null:
		return
	sim.toggle_lang()
	_feed_sig = ""
	_names_sig = ""
	ui_sfx.emit("beep")

func _on_glasses_pressed() -> void:
	if sim == null:
		return
	sim.toggle_glasses()
	ui_sfx.emit("beep")

func _on_mute_pressed() -> void:
	if sim == null:
		return
	sim.toggle_mute()
	ui_sfx.emit("beep")

func _on_reset_pressed() -> void:
	if sim == null:
		return
	sim.reset()
	_feed_sig = ""
	_names_sig = ""
	ui_sfx.emit("beep")

func _on_choice(choice: String) -> void:
	if sim == null:
		return
	sim.choose_a(choice)
	_names_sig = ""

func _on_qte_pressed() -> void:
	if sim == null:
		return
	sim.qte_hit()
	ui_sfx.emit("wedge")
