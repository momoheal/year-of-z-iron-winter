extends CanvasLayer
## NightCoach.gd — 第一次夜潜的「边走边教」提示（不暂停、不拦输入）。
##
## 屏幕上方一块小牌子，一次只讲一件事；玩家真的做了那个动作（走动 / 蹲行 / 开手电 / 搜到东西）
## 才翻到下一条，纯说明的条目按时间自动翻。X 键随时关掉。
## 全部看完或按 X → 发 finished，由 NightExplore 把 sim.seen["night"] 记上，以后的夜里不再出现。
## 中途倒下 / 放弃不算看完，下一夜会从头再教。
##
## 宿主（ctl）只需要有：state（"play" 时才计时）、player（Node2D）、pack（Array）。

signal finished

const SovietUI := preload("res://scripts/ui/SovietUI.gd")

## kind：move 走够 3 米 / crouch 蹲行累计 1 秒 / light 按过 F / loot 背包里多了东西 / read 纯阅读
const STEPS := [
	{"kind": "move", "max": 30.0, "title": "走动",
		"text": "WASD 移动，鼠标指向哪里，人就面朝哪里。\n先走几步试试。"},
	{"kind": "crouch", "max": 30.0, "title": "蹲行",
		"text": "按住 Ctrl 蹲着走：脚步声小得多，也更不容易被光扫到。\nShift 冲刺很快，但很响。现在蹲着走一小段。"},
	{"kind": "light", "max": 16.0, "title": "手电",
		"text": "F 开关手电。开着看得远，也让别人更容易看见你。\n按一下 F 试试。"},
	{"kind": "loot", "max": 45.0, "title": "搜刮",
		"text": "走到箱子、柜子、车皮旁边，按住 E 搜刮。\n背包有上限——先拿腹透液和药。"},
	{"kind": "read", "max": 11.0, "title": "清杀队与探照灯",
		"text": "别站进探照灯和清杀队的手电光里。贴着暗处绕，或者按 G 扔个空罐头把他们引开。\n左键攻击是最后的办法：枪声会把所有东西都招来。"},
	{"kind": "read", "max": 11.0, "title": "天亮之前",
		"text": "留意体温和天亮倒计时。拿到东西后回到撤离点，按住 E 撤离。\n倒下 = 这一夜的东西全丢。Esc 可以暂停。"},
]

var ctl = null
var step := 0

var _panel: PanelContainer
var _lbl_head: Label
var _lbl_text: Label
var _t := 0.0                 # 当前这条已经显示了多久
var _prog := 0.0              # 当前这条的完成进度（米 / 秒）
var _last_pos := Vector2.ZERO
var _has_pos := false
var _pack0 := 0
var _closed := false


func _ready() -> void:
	layer = 30                # 在夜潜 HUD 之上、暂停菜单（40）之下
	_build()
	_enter_step()


func _build() -> void:
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_TOP_WIDE)
	holder.offset_top = 150
	holder.offset_bottom = 330
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(700, 0)
	_panel.add_theme_stylebox_override("panel",
		SovietUI.plate(Color(0.05, 0.065, 0.075, 0.9), SovietUI.OCHRE, 2, 16))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(v)
	_lbl_head = Label.new()
	_lbl_head.add_theme_font_override("font", SovietUI.display_font())
	_lbl_head.add_theme_font_size_override("font_size", 19)
	_lbl_head.add_theme_color_override("font_color", SovietUI.OCHRE)
	v.add_child(_lbl_head)
	_lbl_text = Label.new()
	_lbl_text.custom_minimum_size = Vector2(664, 0)
	_lbl_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_text.add_theme_font_override("font", SovietUI.body_font())
	_lbl_text.add_theme_font_size_override("font_size", 17)
	_lbl_text.add_theme_color_override("font_color", SovietUI.BONE)
	v.add_child(_lbl_text)


func _enter_step() -> void:
	_t = 0.0
	_prog = 0.0
	_has_pos = false
	_pack0 = _pack_size()
	var s: Dictionary = STEPS[step]
	_lbl_head.text = "新手引导 %d/%d · %s　　　X 关闭引导" % [step + 1, STEPS.size(), String(s["title"])]
	_lbl_text.text = String(s["text"])
	_panel.modulate = Color(1, 1, 1, 0)


func _pack_size() -> int:
	if ctl != null and ctl.get("pack") is Array:
		return (ctl.get("pack") as Array).size()
	return 0


func _playing() -> bool:
	return ctl == null or String(ctl.get("state")) == "play"


func _process(delta: float) -> void:
	if _closed:
		return
	_panel.modulate.a = minf(1.0, _panel.modulate.a + delta * 3.0)
	if not _playing():
		return
	_t += delta
	var s: Dictionary = STEPS[step]
	var done := false
	match String(s["kind"]):
		"move":
			_prog += _moved_m()
			done = _prog >= 3.0
		"crouch":
			if Input.is_action_pressed("crouch") and _moved_m() > 0.0:
				_prog += delta
			done = _prog >= 1.0
		"light":
			done = Input.is_key_pressed(KEY_F) and _t > 0.4
		"loot":
			done = _pack_size() > _pack0
		_:
			done = false
	# 做到了也至少让这条停留 1.5 秒，免得一闪而过；一直没做到就超时自动翻
	if (done and _t >= 1.5) or _t >= float(s["max"]):
		advance()


## 玩家这一帧走了多少米（64 像素 = 1 米，和夜潜场景一致）。
func _moved_m() -> float:
	if ctl == null or not (ctl.get("player") is Node2D):
		return 0.0
	var pos: Vector2 = (ctl.get("player") as Node2D).global_position
	var d := 0.0
	if _has_pos:
		d = pos.distance_to(_last_pos) / 64.0
	_last_pos = pos
	_has_pos = true
	return d if d < 2.0 else 0.0          # 瞬移（重生 / 过场）不算


func advance() -> void:
	if _closed:
		return
	step += 1
	if step >= STEPS.size():
		close()
	else:
		_enter_step()


func close() -> void:
	if _closed:
		return
	_closed = true
	finished.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if _closed:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_X:
			get_viewport().set_input_as_handled()
			close()
