extends CanvasLayer
## 可在游戏内浏览已登记的美术资源，以及 80_maps 中的完整俯视底图。

const SovietUI := preload("res://scripts/ui/SovietUI.gd")
const MANIFEST_PATH := "res://art/asset_manifest.json"
const PAGE_SIZE := 16
const CATEGORIES := [
	{"id": "all", "zh": "全部", "en": "All"},
	{"id": "maps", "zh": "地图", "en": "Maps"},
	{"id": "cg", "zh": "剧情 CG", "en": "Story CG"},
	{"id": "portrait", "zh": "角色肖像", "en": "Portraits"},
	{"id": "prop", "zh": "道具与伙伴", "en": "Props & Companions"},
	{"id": "character_sheet", "zh": "动作精灵", "en": "Character Sheets"},
	{"id": "tileset", "zh": "地面与立面", "en": "Tilesets"},
	{"id": "vfx", "zh": "光效与天气", "en": "VFX"},
	{"id": "concept", "zh": "概念图", "en": "Concepts"},
	{"id": "ui", "zh": "界面", "en": "UI"},
	{"id": "other", "zh": "其他", "en": "Other"},
]

var _items: Array[Dictionary] = []
var _category := "all"
var _page := 0
var _lang := "zh"
var _root: Control
var _grid: GridContainer
var _tabs: HBoxContainer
var _status: Label
var _page_label: Label
var _previous: Button
var _next: Button
var _tab_buttons: Dictionary = {}
var _font: Font


func configure(language: String) -> void:
	_lang = "en" if language == "en" else "zh"


func _ready() -> void:
	layer = 90
	_font = SovietUI.body_font()
	_load_items()
	_build()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		queue_free()
		get_viewport().set_input_as_handled()


func _load_items() -> void:
	var seen: Dictionary = {}
	var manifest_file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if manifest_file != null:
		var parsed: Variant = JSON.parse_string(manifest_file.get_as_text())
		if parsed is Dictionary:
			var assets: Variant = parsed.get("assets", {})
			if assets is Dictionary:
				for key in assets:
					var record: Variant = assets[key]
					if not record is Dictionary:
						continue
					var path := String(record.get("path", ""))
					var family := _family_category(String(record.get("family", "other")))
					_add_item(path, family, seen)
	# Some overview plates and exported maps predate the global index. Include every final
	# image under 80_maps so the campaign map and the archive can use them as well.
	_scan_images("res://art/80_maps", seen)
	_scan_images("res://art/90_concept", seen, "concept")
	_items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("path", "")) < String(b.get("path", "")))


func _family_category(family: String) -> String:
	match family:
		"map_plate":
			return "maps"
		"cg":
			return "cg"
		"portrait":
			return "portrait"
		"prop":
			return "prop"
		"character_sheet":
			return "character_sheet"
		"tileset":
			return "tileset"
		"vfx":
			return "vfx"
		"concept":
			return "concept"
		"ui":
			return "ui"
		"audio":
			return ""
		_:
			return "other"


func _add_item(path: String, category: String, seen: Dictionary) -> void:
	if path == "" or category == "" or seen.has(path):
		return
	if not (path.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]):
		return
	seen[path] = true
	_items.append({
		"path": path,
		"category": category,
		"name": path.get_file().get_basename().replace("_", " "),
	})


func _scan_images(path: String, seen: Dictionary, category: String = "maps") -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir():
			if not name.begins_with("."):
				_scan_images(path.path_join(name), seen, category)
		elif name.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]:
			_add_item(path.path_join(name), category, seen)
		name = dir.get_next()
	dir.list_dir_end()


func _build() -> void:
	_root = Control.new()
	_root.name = "ArtArchive"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.color = Color("#080b10")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 26)
	_root.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	column.add_child(header)
	var title := _label(_tr("诺沃斯克-17 · 美术档案", "Novorsk-17 · Art Archive"), 27, Color("#e7ddc6"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_status = _label("", 14, Color("#a99f8d"))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_status)
	var close := _button(_tr("关闭  Esc", "Close  Esc"), func(): queue_free(), false)
	header.add_child(close)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 7)
	column.add_child(_tabs)
	for tab in CATEGORIES:
		var id := String(tab["id"])
		var label := String(tab[_lang])
		var button := _button(label, _select_category.bind(id), false)
		_tabs.add_child(button)
		_tab_buttons[id] = button

	var rule := ColorRect.new()
	rule.color = Color("#503f24")
	rule.custom_minimum_size.y = 2
	column.add_child(rule)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(footer)
	_previous = _button(_tr("‹ 上一页", "‹ Previous"), func(): _change_page(-1), false)
	footer.add_child(_previous)
	_page_label = _label("", 14, Color("#d4c7a9"))
	_page_label.custom_minimum_size.x = 180
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_child(_page_label)
	_next = _button(_tr("下一页 ›", "Next ›"), func(): _change_page(1), false)
	footer.add_child(_next)


func _tr(zh: String, en: String) -> String:
	return zh if _lang == "zh" else en


func _label(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(value: String, callback: Callable, primary: bool) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(0, 38)
	SovietUI.dress_button(button, primary, 14)
	button.pressed.connect(callback)
	return button


func _select_category(id: String) -> void:
	_category = id
	_page = 0
	_refresh()


func _change_page(amount: int) -> void:
	_page += amount
	_refresh()


func _filtered_items() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item in _items:
		if _category == "all" or String(item.get("category", "")) == _category:
			out.append(item)
	return out


func _refresh() -> void:
	if _grid == null:
		return
	var filtered := _filtered_items()
	var page_count := maxi(1, int(ceil(float(filtered.size()) / float(PAGE_SIZE))) )
	_page = clampi(_page, 0, page_count - 1)
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var start := _page * PAGE_SIZE
	var finish := mini(start + PAGE_SIZE, filtered.size())
	for index in range(start, finish):
		_grid.add_child(_asset_card(filtered[index]))
	_status.text = _tr("%d 件视觉资源" % _items.size(), "%d visual assets" % _items.size())
	_page_label.text = "%d / %d" % [_page + 1, page_count]
	_previous.disabled = _page <= 0
	_next.disabled = _page >= page_count - 1
	for category_id in _tab_buttons:
		var tab_button: Button = _tab_buttons[category_id]
		tab_button.disabled = String(category_id) == _category


func _asset_card(item: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(410, 220)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", SovietUI.plate(Color("#161a1e"), Color("#45494a"), 1, 10))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)

	var preview_button := Button.new()
	preview_button.flat = true
	preview_button.custom_minimum_size = Vector2(0, 168)
	preview_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_button.pressed.connect(_show_detail.bind(item))
	var preview := TextureRect.new()
	var path := String(item.get("path", ""))
	if ResourceLoader.exists(path):
		preview.texture = ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_button.add_child(preview)
	column.add_child(preview_button)

	var title := _label(String(item.get("name", "")), 13, Color("#e3ddcd"))
	title.clip_text = true
	title.custom_minimum_size.y = 20
	column.add_child(title)
	var path_label := _label(path.replace("res://", ""), 10, Color("#77776e"))
	path_label.clip_text = true
	column.add_child(path_label)
	return panel


func _show_detail(item: Dictionary) -> void:
	var path := String(item.get("path", ""))
	if not ResourceLoader.exists(path):
		return
	var overlay := ColorRect.new()
	overlay.color = Color(0.01, 0.02, 0.03, 0.96)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(overlay)
	var texture_rect := TextureRect.new()
	texture_rect.texture = ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_rect.offset_left = 70
	texture_rect.offset_top = 76
	texture_rect.offset_right = -70
	texture_rect.offset_bottom = -82
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(texture_rect)
	var title := _label(String(item.get("name", "")) + "\n" + path, 15, Color("#e3ddcd"))
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 24
	title.offset_top = 18
	title.offset_right = -180
	title.offset_bottom = 66
	overlay.add_child(title)
	var close := _button(_tr("返回档案", "Back to archive"), func(): overlay.queue_free(), false)
	close.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close.offset_left = -170
	close.offset_top = 18
	close.offset_right = -24
	close.offset_bottom = 58
	overlay.add_child(close)
