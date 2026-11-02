extends CanvasLayer
## Room A HUD — 每帧从 Sim 纯数据对象读取，无信号连接。
## 生命/体力/体温、BPM、姿态/噪声、罐头/水、目标、撤离提示、toast、胜负横幅。

const SovietUI := preload("res://scripts/ui/SovietUI.gd")

var sim                       # Sim 纯数据对象（动态访问，不使用静态类型）
var _bars: Dictionary = {}
var _meta: Label
var _objective: Label
var _objective_en: Label
var _extract_hint: Label
var _extract_bar_bg: ColorRect
var _extract_bar: ColorRect
var _banner: Label
var _banner_en: Label
var _toast_box: VBoxContainer
var _toast_rows: Array = []

func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font = SovietUI.body_font()
	th.default_font_size = 13
	root.theme = th
	add_child(root)

	# --- 生命体征（左上） ---
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 14)
	panel.custom_minimum_size = Vector2(300, 0)
	panel.add_theme_stylebox_override("panel", SovietUI.plate(SovietUI.IRON, SovietUI.STEEL, 2, 14))
	root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "阿列克谢 · 602室夜潜者   |   ALEKSEI · NIGHT STALKER"
	title.add_theme_font_size_override("font_size", 12)
	vb.add_child(title)

	_add_bar(vb, "hp", "HP 健康", Color(0.85, 0.3, 0.3))
	_add_bar(vb, "stam", "体力 STA", Color(0.45, 0.8, 0.45))
	_add_bar(vb, "warm", "体温 TEMP", Color(0.95, 0.7, 0.3))
	_meta = Label.new()
	_meta.add_theme_font_size_override("font_size", 12)
	vb.add_child(_meta)

	# --- 目标（顶部居中） ---
	_objective = Label.new()
	_objective.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective.position = Vector2(420, 16)
	_objective.custom_minimum_size = Vector2(1080, 0)
	_objective.add_theme_font_size_override("font_size", 17)
	root.add_child(_objective)
	_objective_en = Label.new()
	_objective_en.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_objective_en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_en.position = Vector2(420, 42)
	_objective_en.custom_minimum_size = Vector2(1080, 0)
	_objective_en.add_theme_font_size_override("font_size", 12)
	_objective_en.modulate = Color(0.75, 0.8, 0.86)
	root.add_child(_objective_en)

	# --- 撤离提示（中央偏下） ---
	_extract_hint = Label.new()
	_extract_hint.set_anchors_preset(Control.PRESET_CENTER)
	_extract_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_extract_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_extract_hint.custom_minimum_size = Vector2(700, 40)
	_extract_hint.position = Vector2(610, 400)
	_extract_hint.add_theme_font_size_override("font_size", 20)
	root.add_child(_extract_hint)
	_extract_bar_bg = ColorRect.new()
	_extract_bar_bg.position = Vector2(760, 450)
	_extract_bar_bg.size = Vector2(400, 8)
	_extract_bar_bg.color = Color(0.05, 0.08, 0.06, 0.8)
	_extract_bar_bg.visible = false
	root.add_child(_extract_bar_bg)
	_extract_bar = ColorRect.new()
	_extract_bar.position = Vector2(760, 450)
	_extract_bar.size = Vector2(0, 8)
	_extract_bar.color = Color(0.29, 0.87, 0.5)
	_extract_bar.visible = false
	root.add_child(_extract_bar)

	# --- 胜负横幅 ---
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.custom_minimum_size = Vector2(1200, 90)
	_banner.position = Vector2(360, 430)
	_banner.add_theme_font_size_override("font_size", 42)
	root.add_child(_banner)
	_banner_en = Label.new()
	_banner_en.set_anchors_preset(Control.PRESET_CENTER)
	_banner_en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_en.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_en.custom_minimum_size = Vector2(1200, 40)
	_banner_en.position = Vector2(360, 510)
	_banner_en.add_theme_font_size_override("font_size", 18)
	root.add_child(_banner_en)

	# --- Toast 栈（底部居中） ---
	_toast_box = VBoxContainer.new()
	_toast_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast_box.position = Vector2(360, 880)
	_toast_box.custom_minimum_size = Vector2(1200, 160)
	_toast_box.add_theme_constant_override("separation", 4)
	root.add_child(_toast_box)

	# --- 操作帮助（左下） ---
	var help := Label.new()
	help.position = Vector2(16, 1000)
	help.custom_minimum_size = Vector2(1400, 50)
	help.add_theme_font_size_override("font_size", 13)
	help.text = "WASD 移动 · Ctrl 蹲伏（掩体/蒸汽管阴影内隐匿）· Shift 冲刺 · 鼠标定朝向\nG 扔空罐头（借刀杀人）· Q 喝水 · E 撤离 · Enter 重开 · F1 返回 5 合 1 灰盒测试场"
	root.add_child(help)
	var help_en := Label.new()
	help_en.position = Vector2(16, 1052)
	help_en.custom_minimum_size = Vector2(1400, 24)
	help_en.add_theme_font_size_override("font_size", 11)
	help_en.modulate = Color(0.6, 0.66, 0.72)
	help_en.text = "WASD move · Ctrl crouch (hide behind cover / pipe shadow) · Shift sprint · mouse aim | G throw tin (borrow the knife) · Q drink · E extract · Enter restart · F1 greybox gym"
	root.add_child(help_en)

func _add_bar(parent: Node, key: String, label: String, c: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var lab := Label.new()
	lab.text = label
	lab.custom_minimum_size = Vector2(72, 0)
	lab.add_theme_font_size_override("font_size", 12)
	row.add_child(lab)
	var bg := ColorRect.new()
	bg.custom_minimum_size = Vector2(180, 14)
	bg.size = Vector2(180, 14)
	bg.color = Color(0.1, 0.12, 0.15)
	var fill := ColorRect.new()
	fill.color = c
	fill.size = Vector2(180, 14)
	bg.add_child(fill)
	row.add_child(bg)
	parent.add_child(row)
	_bars[key] = fill

func bind_sim(s) -> void:
	sim = s

func refresh() -> void:
	if sim == null:
		return
	var p = sim.player
	_bars["hp"].size.x = 180.0 * p.hp / 100.0
	_bars["stam"].size.x = 180.0 * p.stam / 100.0
	_bars["warm"].size.x = 180.0 * p.warmth / 100.0
	var stance: String = "蹲伏潜行" if p.sneak else ("冲刺" if p.sprint else "步行")
	_meta.text = "BPM %d  ·  姿态:%s 噪声%.1fm  ·  空罐头×%d  ·  水×%d" % [
		roundi(p.bpm), stance, sim.noise_hint, sim.cans, sim.water]

	# 目标
	if sim.phase == 0:
		var k: int = sim.killed_rabids
		if k >= 2:
			_objective.text = "▸ 回到绿色撤离点（西南角），按住 E 撤离"
			_objective_en.text = "Return to the green EXIT point (SW) and hold E"
		else:
			_objective.text = "▸ 蹲伏躲进掩体阴影，按 G 把罐头扔到清杀兵光锥附近——借刀杀人 %d/2" % k
			_objective_en.text = "Crouch in shadow; throw the tin (G) into the soldier's cone — borrow the knife %d/2" % k

	# 撤离提示
	var dist_exit: float = Vector2(p.x - sim.exit_pos.x, p.y - sim.exit_pos.y).length()
	if sim.phase == 0 and dist_exit < 1.6:
		_extract_hint.text = "按住 E 撤离   ·   HOLD E TO EXTRACT"
		_extract_hint.modulate = Color(0.4, 1.0, 0.6)
		_extract_bar_bg.visible = true
		_extract_bar.visible = true
		_extract_bar.size.x = 400.0 * sim.extract_prog
	else:
		_extract_hint.text = ""
		_extract_bar_bg.visible = false
		_extract_bar.visible = false

	# Toast（sim 数据 → 行重建，保持简单）
	var want: int = mini(sim.toasts.size(), 5)
	while _toast_rows.size() < want:
		var lab := Label.new()
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_font_size_override("font_size", 15)
		lab.modulate = Color(0.9, 0.93, 0.97)
		_toast_box.add_child(lab)
		_toast_rows.append(lab)
	while _toast_rows.size() > want:
		var old: Label = _toast_rows.pop_back()
		old.queue_free()
	for i in range(0, want):
		_toast_rows[i].text = sim.toasts[sim.toasts.size() - 1 - i].text
		_toast_rows[i].modulate.a = clampf(sim.toasts[sim.toasts.size() - 1 - i].t / 0.8, 0.0, 1.0)

	# 胜负
	if sim.phase == 1:
		_banner.text = "撤离成功 · 借刀杀人"
		_banner.modulate = Color(0.4, 1.0, 0.6)
		_banner_en.text = "EXTRACTED — the knife was borrowed; you never fired a shot.\n按 Enter 重开 · Press Enter to restart"
	elif sim.phase == 2:
		_banner.text = "你在雪夜里倒下了"
		_banner.modulate = Color(1.0, 0.35, 0.3)
		_banner_en.text = "YOU FELL IN THE NIGHT — crouch in the pipe shadow; never let the light lock on.\n按 Enter 重开 · Press Enter to restart"
	else:
		_banner.text = ""
		_banner_en.text = ""
