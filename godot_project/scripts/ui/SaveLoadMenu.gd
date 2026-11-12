extends CanvasLayer
## SaveLoadMenu.gd — 存档 / 读档面板（标题页「读取存档」、顶栏「存档 / 读档」、F9）。
##
## 四行：自动存档（只读）+ 3 个手动档位。每行显示第几天 / 母亲 / 良知 / 卌 / 同伴 / 存档时间。
##   · 保存到此：只有在 602 室或结算页（SaveGame.can_save）才可用；覆盖已有档要点两下。
##   · 读取：当前有进行中的战役时要点两下确认（没存的进度会丢）。
##   · 删除：点两下。
## 读档成功发 loaded(slot)，由 CampaignHUD 刷新界面；本脚本只和 SaveGame autoload 打交道。
## 打开期间拦住下面界面的鼠标与按键；Esc 关闭。

signal loaded(slot: int)
signal closed

const SovietUI := preload("res://scripts/ui/SovietUI.gd")

var sim = null
var lang := "zh"

var _list: VBoxContainer
var _status: Label
var _confirm := ""            # 等待二次确认的动作："save:2" / "load:0" / "del:3"
var _closed := false


func _ready() -> void:
	layer = 70
	_build()
	_rebuild()


func _sg() -> Node:
	return get_node_or_null("/root/SaveGame")


func _tr(zh: String, en: String) -> String:
	return zh if lang == "zh" else en


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.02, 0.84)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1080, 0)
	panel.add_theme_stylebox_override("panel", SovietUI.plate(SovietUI.IRON, SovietUI.STEEL_LIT, 2, 24))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	var head := Label.new()
	head.text = _tr("АРХИВ · 存档 / 读档", "АРХИВ · SAVE / LOAD")
	head.add_theme_font_override("font", SovietUI.display_font())
	head.add_theme_font_size_override("font_size", 30)
	head.add_theme_color_override("font_color", SovietUI.BONE)
	v.add_child(head)
	var sub := Label.new()
	sub.text = _tr(
		"每次回到 602 室和结算时自动存档。手动存档只能在 602 室或结算页进行；夜潜途中不能存。",
		"The game autosaves on every return to Room 602 and at the report. Manual saves work in Room 602 or on the report page, never mid-raid.")
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(1000, 0)
	SovietUI.label_font(sub)
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", SovietUI.BONE_DIM)
	v.add_child(sub)
	v.add_child(SovietUI.rule(SovietUI.STEEL))

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	v.add_child(_list)

	v.add_child(SovietUI.rule(SovietUI.STEEL))
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	v.add_child(foot)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SovietUI.label_font(_status)
	_status.add_theme_font_size_override("font_size", 15)
	_status.add_theme_color_override("font_color", SovietUI.OCHRE)
	foot.add_child(_status)
	var b_close := _button(_tr("关闭（Esc）", "Close (Esc)"), true)
	b_close.custom_minimum_size = Vector2(200, 44)
	b_close.pressed.connect(close)
	foot.add_child(b_close)


func _button(txt: String, primary := false) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(150, 44)
	b.focus_mode = Control.FOCUS_NONE
	SovietUI.dress_button(b, primary, 15)
	return b


## 当前有没有「读档会丢掉」的进行中战役（标题页 / 结局页读档不用确认）。
func _in_progress() -> bool:
	return sim != null and String(sim.phase) in ["base", "map", "report"]


func slot_title(slot: int) -> String:
	if slot == 0:
		return _tr("自动存档", "AUTOSAVE")
	return _tr("档位 %d", "SLOT %d") % slot


## 一行摘要文字；空位返回 ""。
func slot_text(info: Dictionary) -> String:
	if info.is_empty():
		return ""
	var mom := _tr("母亲健在", "mother alive") if bool(info.get("mother_alive", true)) \
		else _tr("母亲已离世", "mother lost")
	var txt := _tr("第 %d 天 · %s · 良知 %d · 卌 %d · 同伴 %d · 真名 %d",
		"Day %d · %s · conscience %d · strokes %d · companions %d · names %d") % [
		int(info.get("day", 1)), mom, int(info.get("conscience", 0)), int(info.get("tally", 0)),
		int(info.get("mates", 0)), int(info.get("names", 0))]
	if String(info.get("source", "main")) in ["backup", "tmp"]:
		txt += _tr(" · 主档损坏，读的是备份", " · main file damaged, using backup")
	return txt


func _rebuild() -> void:
	# 这里可能正处在某一行按钮的 pressed 回调里：旧行只隐藏 + 延迟释放，不立刻摘出树
	for c in _list.get_children():
		(c as Control).visible = false
		c.queue_free()
	var sg = _sg()
	if sg == null:
		_status.text = _tr("存档系统不可用。", "Save system unavailable.")
		return
	var can_save: bool = sg.can_save(sim)
	for slot in range(0, int(sg.MANUAL_SLOTS) + 1):
		var info: Dictionary = sg.summary(slot)
		var row_panel := PanelContainer.new()
		row_panel.add_theme_stylebox_override("panel",
			SovietUI.plate(SovietUI.PLATE, SovietUI.STEEL if slot > 0 else SovietUI.OCHRE_DIM, 1, 12))
		_list.add_child(row_panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row_panel.add_child(row)

		var name_lbl := Label.new()
		name_lbl.text = slot_title(slot)
		name_lbl.custom_minimum_size = Vector2(130, 0)
		name_lbl.add_theme_font_override("font", SovietUI.display_font())
		name_lbl.add_theme_font_size_override("font_size", 19)
		name_lbl.add_theme_color_override("font_color", SovietUI.OCHRE)
		row.add_child(name_lbl)

		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		row.add_child(col)
		var line := Label.new()
		line.text = slot_text(info) if not info.is_empty() else _tr("—— 空 ——", "—— empty ——")
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		SovietUI.label_font(line)
		line.add_theme_font_size_override("font_size", 16)
		line.add_theme_color_override("font_color", SovietUI.BONE if not info.is_empty() else SovietUI.ASH)
		col.add_child(line)
		var when := Label.new()
		when.text = String(info.get("saved_at", "")) if not info.is_empty() else ""
		when.add_theme_font_override("font", SovietUI.mono_font())
		when.add_theme_font_size_override("font_size", 12)
		when.add_theme_color_override("font_color", SovietUI.BONE_DIM)
		col.add_child(when)

		if slot > 0:
			var key_s := "save:%d" % slot
			var b_save := _button(_tr("保存到此", "Save here"))
			if _confirm == key_s:
				b_save.text = _tr("确认覆盖？", "Overwrite?")
				b_save.add_theme_color_override("font_color", SovietUI.BLOOD_LIT)
			b_save.disabled = not can_save
			b_save.pressed.connect(func(): _on_save(slot))
			row.add_child(b_save)
		var key_l := "load:%d" % slot
		var b_load := _button(_tr("读取", "Load"), slot == 0)
		if _confirm == key_l:
			b_load.text = _tr("确认读取？", "Load it?")
			b_load.add_theme_color_override("font_color", SovietUI.BLOOD_LIT)
		b_load.disabled = info.is_empty()
		b_load.pressed.connect(func(): _on_load(slot))
		row.add_child(b_load)
		if slot > 0:
			var key_d := "del:%d" % slot
			var b_del := _button(_tr("删除", "Delete"))
			b_del.custom_minimum_size = Vector2(110, 44)
			if _confirm == key_d:
				b_del.text = _tr("确认？", "Sure?")
				b_del.add_theme_color_override("font_color", SovietUI.BLOOD_LIT)
			b_del.disabled = info.is_empty()
			b_del.pressed.connect(func(): _on_delete(slot))
			row.add_child(b_del)
	if _status.text == "" and not can_save:
		_status.text = _tr("现在只能读档：回到 602 室或结算页后才能手动存档。",
			"Load only for now: manual saves need Room 602 or the report page.")


## 需要点两下的动作：第一次只进入确认态并返回 false。
func _armed(key: String, hint: String) -> bool:
	if _confirm == key:
		_confirm = ""
		return true
	_confirm = key
	_status.text = hint
	_rebuild()
	return false


func _on_save(slot: int) -> void:
	var sg = _sg()
	if sg == null or not sg.can_save(sim):
		return
	if sg.has_save(slot) and not _armed("save:%d" % slot,
			_tr("再点一次：覆盖%s里原有的存档。", "Click again to overwrite %s.") % slot_title(slot)):
		return
	_confirm = ""
	if sg.save(sim, slot):
		_status.text = _tr("已保存到%s。", "Saved to %s.") % slot_title(slot)
	else:
		_status.text = _tr("没存上：", "Save failed: ") + String(sg.last_error)
	_rebuild()


func _on_load(slot: int) -> void:
	var sg = _sg()
	if sg == null or sim == null:
		return
	if _in_progress() and not _armed("load:%d" % slot,
			_tr("再点一次：读取%s。当前没存的进度会丢失。", "Click again to load %s. Unsaved progress will be lost.") % slot_title(slot)):
		return
	_confirm = ""
	if not sg.load_into(sim, slot):
		_status.text = _tr("读档失败：这个存档已损坏。", "Load failed: this save is damaged.")
		_rebuild()
		return
	loaded.emit(slot)
	close()


func _on_delete(slot: int) -> void:
	var sg = _sg()
	if sg == null or slot <= 0:
		return
	if not _armed("del:%d" % slot,
			_tr("再点一次：永久删除%s。", "Click again to delete %s for good.") % slot_title(slot)):
		return
	sg.delete_save(slot)
	_status.text = _tr("已删除%s。", "%s deleted.") % slot_title(slot)
	_rebuild()


func close() -> void:
	if _closed:
		return
	_closed = true
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if _closed:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()       # 面板开着时按键不往下漏
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			close()
