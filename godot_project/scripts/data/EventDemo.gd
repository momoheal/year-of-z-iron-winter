class_name EventDemo
extends Control
## EventDemo.gd — 数据管线演示控制器。
##
## 串起「EventCatalog(.tres) -> EventPopup(通用UI) -> EventResolver(结算)
## -> PlayerState(状态) -> SignalBus(广播)」的完整闭环。
## 状态面板的刷新完全由 SignalBus 驱动，演示模块间解耦。

var catalog := EventCatalog.new()
var resolver := EventResolver.new()
var state := PlayerState.new()
var rng := RandomNumberGenerator.new()
var popup: EventPopup
var lang: String = "zh"

var _current_id: String = ""
var _state_label: Label
var _count_label: Label
var _draw_btn: Button

func _ready() -> void:
	# 全屏锚点已在 event_demo.tscn 中设置，这里不再用 set_anchors_preset（会写负 offset）。
	rng.randomize()
	state.reset({"scrap": 3, "can": 2, "water": 1, "rye": 2})
	catalog.load_all()

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 48)
	m.add_theme_constant_override("margin_right", 48)
	m.add_theme_constant_override("margin_top", 40)
	m.add_theme_constant_override("margin_bottom", 40)
	add_child(m)
	m.add_child(root)

	var title := Label.new()
	title.text = "数据管线演示 · Data Pipeline (events/*.tres)"
	root.add_child(title)

	_count_label = Label.new()
	root.add_child(_count_label)

	_state_label = Label.new()
	_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_state_label)

	_draw_btn = Button.new()
	_draw_btn.text = "抽取一个夜潜事件（Enter）"
	_draw_btn.custom_minimum_size = Vector2(0, 44)
	_draw_btn.pressed.connect(draw_event)
	root.add_child(_draw_btn)

	var lang_btn := Button.new()
	lang_btn.text = "切换语言 / Language"
	lang_btn.pressed.connect(_toggle_lang)
	root.add_child(lang_btn)

	popup = EventPopup.new()
	add_child(popup)
	popup.option_pressed.connect(_on_option)
	popup.continue_pressed.connect(_refresh_state)

	# 状态面板由信号驱动刷新
	SignalBus.resource_changed.connect(_on_resource_changed)
	SignalBus.stat_changed.connect(_on_stat_changed)
	SignalBus.crisis_escalated.connect(_on_crisis_escalated)

	_count_label.text = "已加载事件数：%d" % catalog.count()
	_refresh_state()

func _toggle_lang() -> void:
	lang = "en" if lang == "zh" else "zh"
	popup.set_lang(lang)
	_refresh_state()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") or event.is_action_pressed("interact"):
		draw_event()

func draw_event() -> void:
	if popup.visible:
		return
	var ev := catalog.roll_event("night", rng)
	if ev == null:
		_count_label.text = "没有可抽取的事件"
		return
	_current_id = ev.id
	popup.set_lang(lang)
	popup.show_event(ev)
	SignalBus.event_fired.emit(ev.id)

func _on_option(option: EventOptionData) -> void:
	var result: Dictionary = resolver.resolve_option(option, rng)
	SignalBus.event_option_selected.emit(_current_id, option.id)
	var deltas: Array[DeltaData] = result["deltas"]
	for d in deltas:
		var total: int = resolver.apply_delta(d, state)
		match d.target:
			"item":
				SignalBus.resource_changed.emit(d.key, d.amount, total)
			"stat":
				SignalBus.stat_changed.emit(d.key, state.stat_value(d.key))
			"crisis":
				SignalBus.crisis_escalated.emit(d.key, total)
			"flag":
				SignalBus.event_log.emit(d.label_zh, d.label_en)
	SignalBus.event_resolved.emit(_current_id, option.id, deltas)
	popup.show_result(result["result_text_zh"], result["result_text_en"])

# --- 信号 -> 状态 UI ---
func _on_resource_changed(_key: String, _delta: int, _total: int) -> void:
	_refresh_state()

func _on_stat_changed(_stat_id: String, _value: float) -> void:
	_refresh_state()

func _on_crisis_escalated(_crisis_id: String, _level: int) -> void:
	_refresh_state()

func _refresh_state() -> void:
	var items_txt := ""
	for key in state.items.keys():
		items_txt += "%s:%d  " % [key, state.items[key]]
	var s := state.stats
	var stats_txt := "HP %d · 温暖 %d · 理智 %d · 进度 %d" % [
		s["hp"], s["warmth"], s["sanity"], s["progress"]]
	var flags_txt := ""
	for fk in state.flags.keys():
		flags_txt += "[%s] " % fk
	_state_label.text = "背包：%s\n指标：%s\n标记：%s" % [items_txt, stats_txt, flags_txt]
