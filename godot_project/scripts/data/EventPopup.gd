class_name EventPopup
extends Control
## EventPopup.gd — 通用事件弹窗（唯一的事件/交互 UI 预制体）。
##
## 给定一个 EventData 就自动渲染标题、描述与选项按钮；
## 不含任何事件专属逻辑，所有文字与功能都来自 Resource。
## 点击选项时只发出 option_pressed 信号，由上层结算（解耦）。

signal option_pressed(option: EventOptionData)
signal continue_pressed()

var _lang: String = "zh"
var _current: EventData
var _dimmer: ColorRect
var _panel: PanelContainer
var _title: Label
var _desc: Label
var _buttons: VBoxContainer
var _result: Label
var _continue_btn: Button

func _ready() -> void:
	# 显式设置全屏锚点与 offsets（不能用 set_anchors_preset：控件当前尺寸为 0 时，
	# 它会写入负 offset 来“保持” 0 尺寸，导致弹窗永远是 0×0）。
	anchor_left = 0
	anchor_top = 0
	anchor_right = 1
	anchor_bottom = 1
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_STOP

	_dimmer = ColorRect.new()
	_dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dimmer.color = Color(0, 0, 0, 0.62)
	add_child(_dimmer)

	# 面板：四个锚点都在中心，向四周生长，宽度固定、高度随内容自适应。
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(640, 0)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_desc)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 8)
	box.add_child(_buttons)

	_result = Label.new()
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.visible = false
	box.add_child(_result)

	_continue_btn = Button.new()
	_continue_btn.text = "继续 / Continue"
	_continue_btn.visible = false
	_continue_btn.pressed.connect(_on_continue)
	box.add_child(_continue_btn)

	visible = false

func set_lang(lang: String) -> void:
	_lang = lang

func _t(zh: String, en: String) -> String:
	return zh if _lang == "zh" else en

func show_event(ev: EventData) -> void:
	_current = ev
	_title.text = _t(ev.title_zh, ev.title_en)
	_desc.text = _t(ev.desc_zh, ev.desc_en)
	_result.visible = false
	_continue_btn.visible = false
	for child in _buttons.get_children().duplicate():
		_buttons.remove_child(child)
		child.free()
	for option in ev.options:
		var b := Button.new()
		b.text = _t(option.label_zh, option.label_en)
		b.pressed.connect(_on_option.bind(option))
		_buttons.add_child(b)
	visible = true

func show_result(text_zh: String, text_en: String) -> void:
	_result.text = _t(text_zh, text_en)
	_result.visible = true
	for child in _buttons.get_children():
		child.disabled = true
	_continue_btn.visible = true

func close_popup() -> void:
	visible = false

func _on_option(option: EventOptionData) -> void:
	option_pressed.emit(option)

func _on_continue() -> void:
	close_popup()
	continue_pressed.emit()
