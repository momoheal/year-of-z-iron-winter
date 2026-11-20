extends PanelContainer
## Field lessons run alongside the raid and follow actual player actions.

signal finished

const SovietUI := preload("res://scripts/ui/SovietUI.gd")
const OSK_RANGE_M := 18.0

var ctl: Node
var lang := "zh"
var _heading: Label
var _text: Label
var _step := 0
var _elapsed := 0.0
var _walked := 0.0
var _last_pos := Vector2.ZERO
var _osk_seen := false
var _osk_left := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 26
	offset_right = 416
	offset_bottom = -98
	offset_top = -98
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel",
		SovietUI.plate(Color(0.035, 0.046, 0.05, 0.96), SovietUI.OCHRE_DIM, 1, 12))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 5)
	add_child(column)
	_heading = Label.new()
	_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heading.add_theme_font_override("font", SovietUI.display_font())
	_heading.add_theme_font_size_override("font_size", 16)
	column.add_child(_heading)
	_text = Label.new()
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_override("font", SovietUI.body_font())
	_text.add_theme_font_size_override("font_size", 15)
	_text.add_theme_color_override("font_color", SovietUI.BONE)
	column.add_child(_text)
	_last_pos = ctl.player.global_position
	_show_step()


func _process(delta: float) -> void:
	var position_now: Vector2 = ctl.player.global_position
	var walked: float = ctl.dist_m(_last_pos, position_now)
	_last_pos = position_now
	visible = ctl.state == "play" and (_step < 4 or _osk_left > 0.0)
	if ctl.state != "play":
		return
	if not _osk_seen and _patrol_encountered():
		_osk_seen = true
		_osk_left = 12.0
		_show(
			"OSK · 清杀队", "OSK · Purge Squad",
			"他们会循声搜索，也会用手电扫人。头顶「?」表示起疑，「!」表示已锁定你。关手电，蹲着绕到掩体后。有空罐头时按 G 可引开巡逻。",
			"They investigate noise and sweep with flashlights. ? means suspicious. ! means they have spotted you. Switch off your light and crouch behind cover. Press G to throw a can if you have one.",
			SovietUI.SIGNAL)
	if _osk_left > 0.0:
		_osk_left = maxf(0.0, _osk_left - delta)
		if _osk_left == 0.0:
			_show_step()
		return

	_elapsed += delta
	if _step < 3 and (ctl.pack.has("dial") or ctl.extract_prog > 0.0):
		_step = 2
		_advance()
		return
	match _step:
		0:
			_walked += walked if walked < 2.0 else 0.0
			if (_walked >= 3.0 and _elapsed >= 2.0) or _elapsed >= 12.0:
				_advance()
		1:
			if (ctl.player.crouching and walked > 0.0 and _elapsed >= 3.0) or _elapsed >= 12.0:
				_advance()
		2:
			if _elapsed >= 14.0:
				_advance()
		3:
			if _elapsed >= 10.0:
				_advance()


func _patrol_encountered() -> bool:
	for soldier in ctl.soldiers:
		if not soldier.is_alive():
			continue
		if soldier.state == "alert":
			return true
		if (ctl.dist_m(soldier.global_position, ctl.player.global_position) <= OSK_RANGE_M
				and ctl.los_clear(soldier.global_position, ctl.player.global_position, 1)):
			return true
	return false


func _advance() -> void:
	_step += 1
	_elapsed = 0.0
	_show_step()


func _show_step() -> void:
	match _step:
		0:
			_show("移动", "Move", "用 WASD 或方向键移动。右上小地图标出你的位置、任务和撤离点。",
				"Move with WASD or the arrow keys. The map at the top right marks you, your objective and extraction.")
		1:
			_show("保持隐蔽", "Stay concealed", "按住 Ctrl 蹲行，利用暗处和掩体。F 开关手电，开灯更容易被发现。",
				"Hold Ctrl to crouch and use darkness and cover. F toggles your flashlight. Leaving it on makes you easier to spot.")
		2:
			_show("搜刮", "Search", "靠近目标箱，长按 E 搜刮。出发前带的物资也占背包格，留意左上余量。",
				"Get close to the marked container and hold E to search it. Supplies you brought also take up pack space.")
		3:
			_show("撤离", "Extract", "沿蓝色方位找到撤离点，进圈长按 E。天亮前撤离，可以带回背包里的全部物资。",
				"Follow the blue exit marker. Inside the circle, hold E to extract. Leave before dawn to bring everything in your pack home.")
		_:
			hide()


func _show(title_zh: String, title_en: String, text_zh: String, text_en: String,
		accent := SovietUI.OCHRE) -> void:
	_heading.text = ("%s    ·    X 关闭引导" % title_zh) if lang == "zh" else ("%s    ·    X Hide tips" % title_en)
	_heading.add_theme_color_override("font_color", accent)
	_text.text = text_zh if lang == "zh" else text_en
	show()


func _unhandled_input(event: InputEvent) -> void:
	if (ctl.state == "play" and event is InputEventKey and event.pressed and not event.echo
			and event.keycode == KEY_X):
		get_viewport().set_input_as_handled()
		finish()


func finish() -> void:
	finished.emit()
	queue_free()
