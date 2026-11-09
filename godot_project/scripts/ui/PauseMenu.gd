extends CanvasLayer
## PauseMenu.gd — 夜潜的暂停菜单（Esc）。
##
## 用 SceneTree.paused 冻结整个世界：清杀兵 / 狂暴者 / 物理 / 粒子 / 计时 / 音频全部停下，
## 只有本层（PROCESS_MODE_ALWAYS）还在响应。
## 菜单项：继续 · 主音量 · 放弃这次夜潜（要点两下确认）· 退出游戏。
## 宿主（NightExplore）连信号做实际动作，本脚本不碰战役数据。

const SovietUI := preload("res://scripts/ui/SovietUI.gd")

signal resumed
signal abort_requested
signal quit_requested

## 战役里是「放弃这次夜潜（背包清空）」；F2 独立跑是「返回战役」。
var abort_label := "放弃这次夜潜"
var abort_hint := "背包清空，活着回 602 室"

var _panel: PanelContainer
var _btn_abort: Button
var _lbl_hint: Label
var _slider: HSlider
var _lbl_vol: Label
var _abort_confirm := false


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	_abort_confirm = false
	_sync_abort_button()
	_slider.set_value_no_signal(SaveGame.master_volume * 100.0)
	_sync_volume_label()
	visible = true
	get_tree().paused = true


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	resumed.emit()


## 放弃夜潜：第一次只把按钮变成确认态，第二次才真的放弃。返回 true = 已放弃。
func request_abort() -> bool:
	if not _abort_confirm:
		_abort_confirm = true
		_sync_abort_button()
		return false
	visible = false
	get_tree().paused = false
	abort_requested.emit()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close()
			return
	# 菜单开着时，别让任何按键漏进被暂停的世界
	if event is InputEventKey:
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if visible and is_inside_tree():
		get_tree().paused = false


# ============================================================================
# 界面
# ============================================================================
func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.03, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(460, 0)
	_panel.add_theme_stylebox_override("panel", SovietUI.plate(SovietUI.IRON, SovietUI.STEEL_LIT, 2, 22))
	center.add_child(_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_panel.add_child(v)

	var head := Label.new()
	head.text = "ПАУЗА · 暂停"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_override("font", SovietUI.display_font())
	head.add_theme_font_size_override("font_size", 30)
	head.add_theme_color_override("font_color", SovietUI.BONE)
	v.add_child(head)

	var sub := Label.new()
	sub.text = "世界冻住了。雪还悬在半空。"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SovietUI.label_font(sub)
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", SovietUI.BONE_DIM)
	v.add_child(sub)
	v.add_child(SovietUI.rule(SovietUI.STEEL))

	var b_resume := _button("继续（Esc）", true)
	b_resume.pressed.connect(close)
	v.add_child(b_resume)

	# 主音量
	var vrow := HBoxContainer.new()
	vrow.add_theme_constant_override("separation", 10)
	var vl := Label.new()
	vl.text = "主音量"
	SovietUI.label_font(vl)
	vl.add_theme_font_size_override("font_size", 14)
	vl.add_theme_color_override("font_color", SovietUI.BONE)
	vrow.add_child(vl)
	_slider = HSlider.new()
	_slider.min_value = 0.0
	_slider.max_value = 100.0
	_slider.step = 5.0
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.focus_mode = Control.FOCUS_NONE
	_slider.value_changed.connect(_on_volume)
	vrow.add_child(_slider)
	_lbl_vol = Label.new()
	_lbl_vol.custom_minimum_size = Vector2(48, 0)
	_lbl_vol.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_vol.add_theme_font_override("font", SovietUI.mono_font())
	_lbl_vol.add_theme_font_size_override("font_size", 14)
	_lbl_vol.add_theme_color_override("font_color", SovietUI.OCHRE)
	vrow.add_child(_lbl_vol)
	v.add_child(vrow)

	v.add_child(SovietUI.rule(SovietUI.STEEL))

	_btn_abort = _button(abort_label)
	_btn_abort.pressed.connect(func(): request_abort())
	v.add_child(_btn_abort)
	_lbl_hint = Label.new()
	_lbl_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SovietUI.label_font(_lbl_hint)
	_lbl_hint.add_theme_font_size_override("font_size", 12)
	_lbl_hint.add_theme_color_override("font_color", SovietUI.BONE_DIM)
	v.add_child(_lbl_hint)

	var b_quit := _button("退出游戏")
	b_quit.pressed.connect(func(): quit_requested.emit())
	v.add_child(b_quit)

	var foot := Label.new()
	foot.text = "存档点：每次回到 602 室和结算页自动存档。夜潜中途退出 = 这一夜没发生过。"
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SovietUI.label_font(foot)
	foot.add_theme_font_size_override("font_size", 11)
	foot.add_theme_color_override("font_color", SovietUI.ASH)
	v.add_child(foot)


func _button(txt: String, primary := false) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(0, 44)
	SovietUI.dress_button(b, primary, 16)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _sync_abort_button() -> void:
	if _btn_abort == null:
		return
	if _abort_confirm:
		_btn_abort.text = "确认：%s？" % abort_label
		_btn_abort.add_theme_color_override("font_color", SovietUI.BLOOD_LIT)
		_lbl_hint.text = "再点一次确认 · " + abort_hint
	else:
		_btn_abort.text = abort_label
		_btn_abort.add_theme_color_override("font_color", SovietUI.BONE)   # dress_button 的非主按钮色
		_lbl_hint.text = abort_hint


func _on_volume(v: float) -> void:
	SaveGame.set_master_volume(v / 100.0)
	_sync_volume_label()


func _sync_volume_label() -> void:
	_lbl_vol.text = "%d%%" % int(round(_slider.value))
