extends CanvasLayer
## StorySlides.gd — 通用「图片幻灯」演出层（序章 / 关键抉择后的余波 / 结局都用它）。
##
## 一页 = 一张图（缓慢推拉的 Ken Burns 镜头）+ 一段逐字打出的旁白；页间黑场淡入。
## 没有专属插图的页会退回「人物胸像 + 档案底纹」；带 card 的页在画面中央盖一张「档案变更」卡。
##
## 每页的数据（Dictionary，全部可选）：
##   img        String / Texture2D / Array —— 插图；Array 时取第一张存在的（方便以后补图自动生效）
##   portrait   String —— 没有插图时显示的人物胸像
##   zh / en    旁白
##   focus      Vector2(0..1) —— 镜头推向画面的哪个位置（默认正中）
##   zoom       Vector2(from, to) —— 镜头缩放（默认 1.03 → 1.12）
##   card       {"title": String, "lines": Array[String]} —— 中央结果卡
##   actors     bool —— 序章「封楼」那一页的实时小人演出
##
## 操作：空格 / 回车 / 鼠标左键 —— 文字没打完先补全，打完了翻页；Esc 整段跳过。
## 结束（看完或跳过）时发 finished 并 queue_free。本层不碰任何战役数据。

signal finished

const SovietUI := preload("res://scripts/ui/SovietUI.gd")
const HERO := preload("res://art/10_characters/CHR_01_Aleksei/CHR_01_Aleksei_Sheet.png")
const SOLDIER := preload("res://art/10_characters/CHR_05_OSK/CHR_05_OSK_Sheet.png")

const FADE_TIME := 0.5
const TYPE_SPEED := 46.0          # 每秒打出的字符数
const SLIDE_SPAN := 9.0           # 镜头推拉走完全程的秒数

var slides: Array = []
var lang := "zh"
var heading_zh := "序章"
var heading_en := "PROLOGUE"

var page := 0
var elapsed := 0.0
var backdrop: TextureRect
var caption: Label
var counter: Label
var heading: Label
var actors: Control
var hero: TextureRect
var soldier: TextureRect
var portrait_frame: PanelContainer
var portrait_rect: TextureRect
var card_panel: PanelContainer
var card_box: VBoxContainer

var _root: Control
var _fade: ColorRect
var _typed := 0.0
var _closed := false
var _focus := Vector2(0.5, 0.5)
var _zoom := Vector2(1.03, 1.12)


## 把 img 字段解析成贴图：路径不存在（图还没画 / 还没导入）时返回 null，由调用方退回胸像。
static func tex_of(v: Variant) -> Texture2D:
	if v is Texture2D:
		return v
	if v is String:
		var path: String = v
		if path != "" and ResourceLoader.exists(path):
			return load(path) as Texture2D
		return null
	if v is Array:
		for item in v:
			var t := tex_of(item)
			if t != null:
				return t
	return null


func _ready() -> void:
	layer = 100
	_build()
	if slides.is_empty():
		close.call_deferred()
		return
	_show_page()


func _build() -> void:
	_root = Control.new()
	_root.name = "SlidesRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.clip_contents = true
	_root.gui_input.connect(_on_gui_input)
	add_child(_root)

	var black := ColorRect.new()
	black.color = Color("0b1016")
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(black)

	backdrop = TextureRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(backdrop)

	actors = Control.new()
	actors.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	actors.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(actors)
	hero = _actor(HERO, Vector2(0.50, 0.66))
	soldier = _actor(SOLDIER, Vector2(0.75, 0.66))
	actors.visible = false

	# ---- 没有插图时的人物胸像 ----
	var pc := CenterContainer.new()
	pc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pc.offset_top = 70
	pc.offset_bottom = -250
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(pc)
	portrait_frame = PanelContainer.new()
	portrait_frame.add_theme_stylebox_override("panel",
		SovietUI.plate(Color("0d0f12"), Color("c8a257"), 3, 10))
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.visible = false
	pc.add_child(portrait_frame)
	portrait_rect = TextureRect.new()
	portrait_rect.custom_minimum_size = Vector2(460, 460)
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(portrait_rect)

	# ---- 中央「档案变更」结果卡 ----
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.offset_top = 70
	cc.offset_bottom = -250
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(cc)
	card_panel = PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(760, 0)
	card_panel.add_theme_stylebox_override("panel",
		SovietUI.plate(Color(0.03, 0.04, 0.05, 0.9), Color("c8a257"), 2, 26))
	card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_panel.visible = false
	cc.add_child(card_panel)
	card_box = VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 10)
	card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_panel.add_child(card_box)

	# ---- 上下黑边：上边放章节名，下边放旁白 ----
	var top := ColorRect.new()
	top.color = Color(0.012, 0.018, 0.024, 0.94)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 70
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top)
	heading = Label.new()
	heading.set_anchors_preset(Control.PRESET_TOP_WIDE)
	heading.offset_left = 100
	heading.offset_right = -100
	heading.offset_top = 18
	heading.offset_bottom = 60
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_font_override("font", SovietUI.display_font())
	heading.add_theme_color_override("font_color", Color("c0a46c"))
	_root.add_child(heading)

	var panel := ColorRect.new()
	panel.color = Color(0.012, 0.018, 0.024, 0.92)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -250
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)
	var rule := ColorRect.new()
	rule.color = Color("8c1c13")
	rule.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	rule.offset_top = -250
	rule.offset_bottom = -247
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(rule)

	caption = Label.new()
	caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_left = 100
	caption.offset_right = -100
	caption.offset_top = -226
	caption.offset_bottom = -84
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", 27)
	caption.add_theme_constant_override("line_spacing", 8)
	caption.add_theme_font_override("font", SovietUI.body_font())
	caption.add_theme_color_override("font_color", Color("e7dfcc"))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(caption)

	counter = Label.new()
	counter.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	counter.offset_left = 100
	counter.offset_top = -65
	counter.offset_right = 1400
	counter.offset_bottom = -20
	counter.add_theme_font_size_override("font_size", 18)
	counter.add_theme_font_override("font", SovietUI.body_font())
	counter.add_theme_color_override("font_color", Color("c0a46c"))
	counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(counter)

	var next := Button.new()
	next.text = "继续 ▸" if lang == "zh" else "NEXT ▸"
	next.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	next.offset_left = -270
	next.offset_right = -90
	next.offset_top = -70
	next.offset_bottom = -20
	next.focus_mode = Control.FOCUS_NONE
	SovietUI.dress_button(next, true, 16)
	next.pressed.connect(press)
	_root.add_child(next)

	var skip := Button.new()
	skip.text = "跳过 (Esc)" if lang == "zh" else "SKIP (Esc)"
	skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip.offset_left = -440
	skip.offset_right = -290
	skip.offset_top = -70
	skip.offset_bottom = -20
	skip.focus_mode = Control.FOCUS_NONE
	SovietUI.dress_button(skip, false, 14)
	skip.pressed.connect(close)
	_root.add_child(skip)

	# 页间黑场：最后加，盖在所有东西上面
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)


func _actor(texture: Texture2D, at: Vector2) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(0, 0, 72, 112)
	var actor := TextureRect.new()
	actor.texture = atlas
	actor.anchor_left = at.x
	actor.anchor_right = at.x
	actor.anchor_top = at.y
	actor.anchor_bottom = at.y
	actor.offset_left = -72
	actor.offset_top = -112
	actor.offset_right = 72
	actor.offset_bottom = 112
	actor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	actor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	actor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actors.add_child(actor)
	return actor


func current() -> Dictionary:
	if page < 0 or page >= slides.size():
		return {}
	var s: Variant = slides[page]
	return s if s is Dictionary else {}


func _show_page() -> void:
	var s := current()
	var tex := tex_of(s.get("img", ""))
	backdrop.texture = tex
	backdrop.modulate = Color(1, 1, 1, 1)
	var card: Dictionary = s.get("card", {}) if s.get("card", {}) is Dictionary else {}
	var has_card := not card.is_empty()
	if has_card:
		backdrop.modulate = Color(0.42, 0.44, 0.48, 1)      # 结果卡那页把底图压暗
	actors.visible = bool(s.get("actors", false))
	var ptex := tex_of(s.get("portrait", ""))
	portrait_frame.visible = tex == null and ptex != null and not has_card
	portrait_rect.texture = ptex
	card_panel.visible = has_card
	if has_card:
		_fill_card(card)
	var f: Variant = s.get("focus", Vector2(0.5, 0.5))
	_focus = f if f is Vector2 else Vector2(0.5, 0.5)
	var z: Variant = s.get("zoom", Vector2(1.03, 1.12))
	_zoom = z if z is Vector2 else Vector2(1.03, 1.12)
	caption.text = String(s.get("zh" if lang == "zh" else "en", ""))
	caption.visible_characters = 0
	_typed = 0.0
	heading.text = heading_zh if lang == "zh" else heading_en
	var fmt := "%d / %d   ·   空格 / 回车 / 点击 继续   ·   Esc 跳过" if lang == "zh" \
		else "%d / %d   ·   Space / Enter / click to continue   ·   Esc to skip"
	counter.text = fmt % [page + 1, slides.size()]
	elapsed = 0.0
	_apply_camera()


func _fill_card(card: Dictionary) -> void:
	for c in card_box.get_children():
		card_box.remove_child(c)
		c.queue_free()
	var stamp := Label.new()
	stamp.text = "ДЕЛО № 0420 · 档案变更" if lang == "zh" else "ДЕЛО № 0420 · FILE AMENDED"
	stamp.add_theme_font_override("font", SovietUI.mono_font())
	stamp.add_theme_font_size_override("font_size", 14)
	stamp.add_theme_color_override("font_color", Color("b3261a"))
	card_box.add_child(stamp)
	var title := Label.new()
	title.text = String(card.get("title", ""))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(700, 0)
	title.add_theme_font_override("font", SovietUI.display_font())
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("e0bf7e"))
	card_box.add_child(title)
	card_box.add_child(SovietUI.rule(Color("5a5548")))
	var lines: Array = card.get("lines", []) if card.get("lines", []) is Array else []
	for l in lines:
		var row := Label.new()
		row.text = "▪ " + String(l)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size = Vector2(700, 0)
		row.add_theme_font_override("font", SovietUI.body_font())
		row.add_theme_font_size_override("font_size", 22)
		row.add_theme_color_override("font_color", Color("e7dfcc"))
		card_box.add_child(row)


## 镜头：以 focus 为轴心缓慢放大。scale ≥ 1 且轴心在画面内，所以永远盖满屏幕、不露黑边。
func _apply_camera() -> void:
	var k := clampf(elapsed / SLIDE_SPAN, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)                             # smoothstep：起止都慢
	var sc := lerpf(_zoom.x, _zoom.y, k)
	backdrop.pivot_offset = backdrop.size * _focus
	backdrop.scale = Vector2(sc, sc)
	portrait_rect.pivot_offset = portrait_rect.size * 0.5
	var ps := lerpf(1.0, 1.06, k)
	portrait_rect.scale = Vector2(ps, ps)


func _process(delta: float) -> void:
	if _closed:
		return
	elapsed += delta
	_fade.color.a = clampf(1.0 - elapsed / FADE_TIME, 0.0, 1.0)
	_apply_camera()
	# 逐字打出旁白
	var total := caption.get_total_character_count()
	if caption.visible_characters >= 0:
		_typed += delta * TYPE_SPEED
		if int(_typed) >= total:
			caption.visible_characters = -1
		else:
			caption.visible_characters = int(_typed)
	if actors.visible:
		_animate_actors()


## 序章「封楼」页：游戏内角色精灵逐帧行走，再停在封楼巡逻线前。
func _animate_actors() -> void:
	var frame := 0
	if elapsed < 2.0:
		frame = 1 + int(elapsed * 5.0) % 4
	(hero.texture as AtlasTexture).region.position.x = frame * 72
	(soldier.texture as AtlasTexture).region.position.x = frame * 72
	var hero_step := minf(elapsed * 28.0, 56.0)
	var soldier_step := minf(elapsed * 20.0, 40.0)
	hero.offset_left = -72 + hero_step
	hero.offset_right = 72 + hero_step
	soldier.offset_left = -72 - soldier_step
	soldier.offset_right = 72 - soldier_step


func text_done() -> bool:
	return caption.visible_characters < 0


func _input(event: InputEvent) -> void:
	if _closed:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close()
		elif k == KEY_SPACE or k == KEY_ENTER or k == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			press()
		else:
			# 演出期间别让其它热键（L / M / F1…）漏到下面的战役界面
			get_viewport().set_input_as_handled()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			press()


## 玩家按了「继续」：文字还在打就先补全，已经打完才翻页。
func press() -> void:
	if _closed:
		return
	if not text_done():
		caption.visible_characters = -1
		return
	advance()


## 直接翻到下一页（最后一页之后关闭）。
func advance() -> void:
	if _closed:
		return
	page += 1
	if page >= slides.size():
		close()
	else:
		_show_page()


func close() -> void:
	if _closed:
		return
	_closed = true
	finished.emit()
	queue_free()
