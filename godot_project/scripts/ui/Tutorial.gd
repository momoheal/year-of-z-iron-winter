extends CanvasLayer
## Tutorial.gd — 战役界面的新手引导（602 室 / 城市地图）。
##
## 一段引导 = 若干张说明卡；每张卡可以「圈」出界面上的一块区域（四周压暗，黄铜框高亮）。
## 引导期间拦住下面界面的鼠标和按键，免得玩家没看完就点走了。
## 操作：空格 / 回车 / 「下一步」推进；Esc / 「跳过这一段」结束本段；「不再提示」关掉全部引导。
## 结束时发 finished(section, skip_all)，由 CampaignHUD 把 sim.seen 记上（随存档走）。
## 本脚本只管显示，不碰战役数据。

signal finished(section: String, skip_all: bool)

const SovietUI := preload("res://scripts/ui/SovietUI.gd")

## area：left / mid / right / top / map / mapside / ""（不圈，卡片居中）
const SECTIONS := {
	"base": [
		{"area": "",
			"t_zh": "602 室 · 你的据点", "t_en": "ROOM 602 · YOUR BASE",
			"zh": "每一天分成两半：白天在 602 室整理物资、照看母亲；夜里从锅炉房的通风口出去，只够去一个地方。\n下面用一分钟，带你把这间屋子认一遍。",
			"en": "Each day has two halves: in Room 602 you sort supplies and look after Mother; at night you slip out through the boiler-room vent, to one place only.\nGive it a minute and we will walk the room."},
		{"area": "left",
			"t_zh": "母亲与腹透液", "t_en": "MOTHER AND THE FLUID",
			"zh": "母亲每天要用掉一份腹透液。剩余天数归零，她就撑不过那一夜。\n腹透液只能在夜里找回来——这是你出门的第一个理由。",
			"en": "Mother uses one bag of dialysis fluid a day. When the days run out, she will not last the night.\nFluid is only found out there in the dark. That is your first reason to go."},
		{"area": "left",
			"t_zh": "良知与「卌」", "t_en": "CONSCIENCE AND STROKES",
			"zh": "「良知」记着你还把多少人当人看；「卌」是《工作日志》背面的划痕，每害死一个不该死的人就多一道。\n它们不会让你更强，但会决定结局——也决定拉娜还认不认得你。",
			"en": "Conscience tracks how many people you still treat as people. Strokes are scratched on the back of the logbook, one for each death you caused that you did not have to.\nNeither makes you stronger. Both decide the ending, and whether Lana still knows you."},
		{"area": "mid",
			"t_zh": "仓库 · 同伴 · 武器", "t_en": "STASH · COMPANIONS · WEAPONS",
			"zh": "夜里带回来的东西都放在这里。\n同伴会在主线剧情里加入，每夜只能带一个，各有本事；武器要靠捡来的零件一点点拼出来。",
			"en": "Everything you carry home ends up here.\nCompanions join through the story; you may take one per night, each with a talent. Weapons are assembled from parts you find."},
		{"area": "right",
			"t_zh": "今晚去哪", "t_en": "WHERE TO TONIGHT",
			"zh": "这一栏写着当前目标和最近发生的事。\n准备好了就点「去城市地图」。也可以「睡到明天」——只是腹透液照样会少一天。",
			"en": "This column shows the current objective and what happened lately.\nWhen you are ready, open the City Map. You may also sleep until tomorrow, but the fluid still runs down a day."},
		{"area": "top",
			"t_zh": "日志 · 帮助 · 存档", "t_en": "LOGBOOK · HELP · SAVES",
			"zh": "Tab 打开《工作日志》，「帮助」里有完整的操作表。\n每次回到 602 室和结算时会自动存档；点顶栏的「存档 / 读档」（F9）还能手动存进 3 个档位。",
			"en": "Tab opens the logbook; Help lists every control.\nThe game autosaves whenever you return to Room 602 or reach the report. The Save / Load button (F9) gives you three manual slots as well."},
	],
	"map": [
		{"area": "map",
			"t_zh": "城市地图", "t_en": "THE CITY MAP",
			"zh": "亮着的点是今晚能去的地方，琥珀色的点有主线剧情——点一下选中。\n越远的地方路上耗的时间越多，留给搜刮的夜就越短。",
			"en": "Lit dots are places you can reach tonight; amber dots carry the main story. Click one to select it.\nThe farther you go, the more of the night is spent walking and the less is left for searching."},
		{"area": "mapside",
			"t_zh": "出发之前", "t_en": "BEFORE YOU LEAVE",
			"zh": "右侧是这个地方的情报：危险度、寒冷、还剩多少物资。\n在这里选同伴，往背包里放罐头、热水、阿司匹林和绷带，然后出发。没用完的会原样带回来。",
			"en": "The right side is the dossier: danger, cold, and how much is left to find.\nPick a companion, pack tins, hot water, aspirin and bandages, then set out. Whatever you do not use comes home with you."},
		{"area": "",
			"t_zh": "夜潜的规矩", "t_en": "RULES OF THE NIGHT",
			"zh": "天亮前回到撤离点，才能带走全部物资；拖到天亮只带得回一半；倒下或放弃，一无所获。\n第一夜建议去近处、危险度低的地方。到了外面，屏幕上方会继续提示怎么走、怎么躲。",
			"en": "Reach the extraction point before dawn and you keep everything. Stay until dawn and you keep half. Go down or give up and you keep nothing.\nFor a first night, pick somewhere close and low-risk. Once outside, hints at the top of the screen will show you how to move and hide."},
	],
}

var section := "base"
var lang := "zh"
var step := 0

var _root: Control
var _shades: Array[ColorRect] = []
var _frame: Panel
var _card: PanelContainer
var _lbl_title: Label
var _lbl_text: Label
var _lbl_step: Label
var _btn_next: Button
var _closed := false


static func has_section(id: String) -> bool:
	return SECTIONS.has(id)


func steps() -> Array:
	return SECTIONS.get(section, [])


func _ready() -> void:
	layer = 60
	_build()
	if steps().is_empty():
		_finish.call_deferred(false)
		return
	_show_step()


func _build() -> void:
	_root = Control.new()
	_root.name = "TutorialRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP        # 引导期间下面的界面点不到
	add_child(_root)
	for i in 4:
		var sh := ColorRect.new()
		sh.color = Color(0.01, 0.015, 0.02, 0.78)
		sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(sh)
		_shades.append(sh)
	_frame = Panel.new()
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0, 0, 0, 0)
	fsb.border_color = Color("e0bf7e")
	fsb.set_border_width_all(3)
	_frame.add_theme_stylebox_override("panel", fsb)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_frame)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(620, 0)
	_card.add_theme_stylebox_override("panel", SovietUI.plate(SovietUI.IRON, SovietUI.OCHRE, 2, 22))
	_root.add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_card.add_child(v)
	_lbl_step = Label.new()
	_lbl_step.add_theme_font_override("font", SovietUI.mono_font())
	_lbl_step.add_theme_font_size_override("font_size", 13)
	_lbl_step.add_theme_color_override("font_color", SovietUI.BLOOD_LIT)
	v.add_child(_lbl_step)
	_lbl_title = Label.new()
	_lbl_title.add_theme_font_override("font", SovietUI.display_font())
	_lbl_title.add_theme_font_size_override("font_size", 28)
	_lbl_title.add_theme_color_override("font_color", SovietUI.OCHRE)
	v.add_child(_lbl_title)
	v.add_child(SovietUI.rule(SovietUI.STEEL))
	_lbl_text = Label.new()
	_lbl_text.custom_minimum_size = Vector2(576, 0)
	_lbl_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_text.add_theme_font_override("font", SovietUI.body_font())
	_lbl_text.add_theme_font_size_override("font_size", 19)
	_lbl_text.add_theme_constant_override("line_spacing", 6)
	_lbl_text.add_theme_color_override("font_color", SovietUI.BONE)
	v.add_child(_lbl_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	_btn_next = _button("", true)
	_btn_next.custom_minimum_size = Vector2(220, 44)
	_btn_next.pressed.connect(next)
	row.add_child(_btn_next)
	var b_skip := _button("跳过这一段 (Esc)" if lang == "zh" else "Skip this part (Esc)", false)
	b_skip.pressed.connect(func(): _finish(false))
	row.add_child(b_skip)
	var b_off := _button("不再提示" if lang == "zh" else "Never show hints", false)
	b_off.pressed.connect(func(): _finish(true))
	row.add_child(b_off)


func _button(txt: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(0, 44)
	b.focus_mode = Control.FOCUS_NONE
	SovietUI.dress_button(b, primary, 15)
	return b


## 把 area 名字换成屏幕矩形。按当前视口大小算：宽屏（aspect=expand）下右侧面板会跟着变宽。
func area_rect(area: String) -> Rect2:
	var vp := Vector2(1920, 1080)
	if is_inside_tree():
		vp = get_viewport().get_visible_rect().size
	match area:
		"top":
			return Rect2(0, 0, vp.x, 70)
		"left":
			return Rect2(22, 86, 452, vp.y - 104)
		"mid":
			return Rect2(488, 86, 566, vp.y - 104)
		"right":
			return Rect2(1068, 86, vp.x - 1090, vp.y - 104)
		"map":
			return Rect2(30, 128, 900, 520)
		"mapside":
			return Rect2(956, 86, vp.x - 978, vp.y - 104)
	return Rect2()


func _show_step() -> void:
	var list := steps()
	step = clampi(step, 0, list.size() - 1)
	var s: Dictionary = list[step]
	var zh := lang == "zh"
	_lbl_step.text = ("新手引导  %d / %d" if zh else "FIRST STEPS  %d / %d") % [step + 1, list.size()]
	_lbl_title.text = String(s.get("t_zh" if zh else "t_en", ""))
	_lbl_text.text = String(s.get("zh" if zh else "en", ""))
	var last := step >= list.size() - 1
	if zh:
		_btn_next.text = "知道了（空格）" if last else "下一步（空格）"
	else:
		_btn_next.text = "Got it (Space)" if last else "Next (Space)"
	_layout.call_deferred()


## 摆「压暗的四块 + 高亮框 + 说明卡」。卡片优先放在高亮区右侧，放不下换左侧，再不行居中。
func _layout() -> void:
	if _closed or not is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	var list := steps()
	var hole := area_rect(String((list[step] as Dictionary).get("area", "")))
	var has_hole := hole.size.x > 0.0 and hole.size.y > 0.0
	_frame.visible = has_hole
	if has_hole:
		_frame.position = hole.position - Vector2(3, 3)
		_frame.size = hole.size + Vector2(6, 6)
		_set_rect(_shades[0], Rect2(0, 0, vp.x, hole.position.y))
		_set_rect(_shades[1], Rect2(0, hole.end.y, vp.x, maxf(0.0, vp.y - hole.end.y)))
		_set_rect(_shades[2], Rect2(0, hole.position.y, hole.position.x, hole.size.y))
		_set_rect(_shades[3], Rect2(hole.end.x, hole.position.y, maxf(0.0, vp.x - hole.end.x), hole.size.y))
	else:
		_set_rect(_shades[0], Rect2(Vector2.ZERO, vp))
		for i in range(1, 4):
			_set_rect(_shades[i], Rect2())
	_card.reset_size()
	var cs := _card.get_combined_minimum_size()
	_card.size = cs
	var pos := (vp - cs) * 0.5
	if has_hole:
		if hole.size.x > vp.x * 0.8:
			# 顶栏这种横条：卡片放在它下面居中
			pos = Vector2((vp.x - cs.x) * 0.5, hole.end.y + 40.0)
		elif hole.end.x + 30.0 + cs.x <= vp.x - 20.0:
			pos = Vector2(hole.end.x + 30.0, hole.position.y + 60.0)
		elif hole.position.x - 30.0 - cs.x >= 20.0:
			pos = Vector2(hole.position.x - 30.0 - cs.x, hole.position.y + 60.0)
	pos.x = clampf(pos.x, 20.0, maxf(20.0, vp.x - cs.x - 20.0))
	pos.y = clampf(pos.y, 20.0, maxf(20.0, vp.y - cs.y - 20.0))
	_card.position = pos


func _set_rect(c: Control, r: Rect2) -> void:
	c.position = r.position
	c.size = r.size
	c.visible = r.size.x > 0.0 and r.size.y > 0.0


func next() -> void:
	if _closed:
		return
	if step >= steps().size() - 1:
		_finish(false)
		return
	step += 1
	_show_step()


func _finish(skip_all: bool) -> void:
	if _closed:
		return
	_closed = true
	finished.emit(section, skip_all)
	queue_free()


func _input(event: InputEvent) -> void:
	if _closed:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		get_viewport().set_input_as_handled()       # 引导期间所有按键都不往下漏
		if k == KEY_ESCAPE:
			_finish(false)
		elif k == KEY_SPACE or k == KEY_ENTER or k == KEY_KP_ENTER:
			next()


func _process(_delta: float) -> void:
	# 每帧重摆一次：自动换行的 Label 要过一帧才知道自己多高，窗口大小也可能变
	_layout()
