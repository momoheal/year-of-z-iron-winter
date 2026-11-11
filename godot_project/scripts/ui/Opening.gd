extends CanvasLayer
## 新游戏序章：两张画面与一段使用游戏角色精灵的实时演绎。
## 继续存档不调用本场景；Esc 可跳过，空格/回车推进。

const HERO := preload("res://art/10_characters/CHR_01_Aleksei/CHR_01_Aleksei_Sheet.png")
const SOLDIER := preload("res://art/10_characters/CHR_05_OSK/CHR_05_OSK_Sheet.png")
const SLIDES := [preload("res://art/60_ui/opening_dispatch.png"), preload("res://art/60_ui/opening_courtyard.png")]
const SovietUI := preload("res://scripts/ui/SovietUI.gd")
const TEXT_ZH := [
	"十天前，铁路调度员阿列克谢在 004 号车皮调拨单上签了字。作为奖励，母亲可以得到下一批腹透液。",
	"十天后，妹妹拉娜在筛查中被带走。她的编号是 0420。那节车厢，正驶向风雪深处。",
	"清杀队：封楼！所有人退回室内。\n阿列克谢：妈，我会带着药回来……也会找到拉娜。"
]
const TEXT_EN := [
	"Ten days ago, dispatcher Aleksei signed the order for carriage 004. In return, his mother would receive dialysis fluid.",
	"Ten days later, his sister Lana was taken during screening. Her file is 0420. The carriage disappears into the snow.",
	"OSK: Seal the building! Everyone back inside.\nAleksei: Mama, I'll bring the medicine back... and find Lana."
]

var lang := "zh"
var page := 0
var backdrop: TextureRect
var caption: Label
var counter: Label
var actors: Control
var hero: TextureRect
var soldier: TextureRect
var elapsed := 0.0

func _ready() -> void:
	layer = 100
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var black := ColorRect.new()
	black.color = Color("101820")
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(black)
	backdrop = TextureRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	root.add_child(backdrop)
	actors = Control.new()
	actors.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	actors.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(actors)
	hero = _actor(HERO, Vector2(0.50, 0.66))
	soldier = _actor(SOLDIER, Vector2(0.75, 0.66))
	var panel := ColorRect.new()
	panel.color = Color(0.018, 0.025, 0.03, 0.91)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -235
	root.add_child(panel)
	caption = Label.new()
	caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_left = 100
	caption.offset_right = -100
	caption.offset_top = -210
	caption.offset_bottom = -90
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", 27)
	caption.add_theme_font_override("font", SovietUI.body_font())
	caption.add_theme_color_override("font_color", Color("e7dfcc"))
	root.add_child(caption)
	counter = Label.new()
	counter.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	counter.offset_left = 100
	counter.offset_top = -65
	counter.offset_right = 1300
	counter.offset_bottom = -20
	counter.add_theme_font_size_override("font_size", 18)
	counter.add_theme_font_override("font", SovietUI.body_font())
	counter.add_theme_color_override("font_color", Color("c0a46c"))
	root.add_child(counter)
	var next := Button.new()
	next.text = "继续 / NEXT"
	next.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	next.offset_left = -270
	next.offset_right = -90
	next.offset_top = -70
	next.offset_bottom = -20
	next.pressed.connect(advance)
	root.add_child(next)
	_show_page()

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
	actors.add_child(actor)
	return actor

func _show_page() -> void:
	backdrop.texture = SLIDES[mini(page, 1)]
	actors.visible = page == 2
	caption.text = TEXT_ZH[page] if lang == "zh" else TEXT_EN[page]
	counter.text = ("序章  %d / 3   ·   空格 / 回车继续   ·   Esc 跳过" if lang == "zh" else "PROLOGUE  %d / 3   ·   Space / Enter to continue   ·   Esc to skip") % (page + 1)
	elapsed = 0.0

func _process(delta: float) -> void:
	if page != 2:
		return
	elapsed += delta
	# 原有游戏角色精灵逐帧行走，再停在封楼巡逻线前。
	var frame := 1 + int(elapsed * 5.0) % 4 if elapsed < 2.0 else 0
	(hero.texture as AtlasTexture).region.position.x = frame * 72
	(soldier.texture as AtlasTexture).region.position.x = frame * 72
	var hero_step := minf(elapsed * 28.0, 56.0)
	var soldier_step := minf(elapsed * 20.0, 40.0)
	hero.offset_left = -72 + hero_step
	hero.offset_right = 72 + hero_step
	soldier.offset_left = -72 - soldier_step
	soldier.offset_right = 72 - soldier_step

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			queue_free()
		elif event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			get_viewport().set_input_as_handled()
			advance()

func advance() -> void:
	page += 1
	if page >= 3:
		queue_free()
	else:
		_show_page()
