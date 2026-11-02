extends RefCounted
## SovietUI.gd — 「铁冬」界面视觉系统（苏联重工业 / 军事档案风格）。
##
## 全部界面都从这一份调色板与控件工厂里长出来，改一处 = 全套换皮：
##   · 底色是沥青黑与生铁灰，不留圆角——钢板没有圆角；
##   · 唯一的高饱和色是军旗红（警示 / 红章）与黄铜（强调 / 表尺），
##     其余读数用骨白与霜蓝，绿色只留给电传机；
##   · 字体分三档：display（压缩体 / 钢印字，ит 用）、mono（电传打字机）、body（CJK 正文）；
##   · 边框一律「双线 + 铆钉 + 角标」由 SovietChrome 在整屏上画，本文件只负责控件本身。
##
## 用法（不要 class_name，避免全局类注册顺序问题）：
##     const SovietUI := preload("res://scripts/ui/SovietUI.gd")
##     label.add_theme_font_override("font", SovietUI.display_font())
##     panel.add_theme_stylebox_override("panel", SovietUI.plate(SovietUI.IRON, SovietUI.STEEL))
##
## 舰队命名（界面上出现的俄文一律写死在数据层，这里只提供排版工具）：
##     НОВОРСК-17 / ЖЕЛЕЗНАЯ ЗИМА / СССР / ОСК / ДЕЛО

# ============================================================================
# 调色板 —— 全项目界面配色的唯一数据源
# ============================================================================
const INK := Color("070809")          # 沥青黑：最深的一层
const IRON := Color("121618")         # 生铁：面板底
const IRON_LIT := Color("1b2023")     # 受光铁板：悬停 / 次级面板
const PLATE := Color("22282b")        # 铆接钢板：分区底
const STEEL := Color("343c3f")        # 钢：分隔线 / 边框
const STEEL_LIT := Color("4a5457")    # 高光钢：悬停边框
const RIVET := Color("565f62")        # 铆钉头
const BONE := Color("d8d1bf")         # 骨白：正文
const BONE_DIM := Color("928c7c")     # 旧纸：次要文字 / 注释
const OCHRE := Color("c8a257")        # 黄铜：强调、表尺、关键数字
const OCHRE_DIM := Color("8c7139")    # 氧化黄铜
const BLOOD := Color("8c1c14")        # 军旗红：红章 / 警示条
const BLOOD_LIT := Color("b8281c")    # 鲜红：闪烁的警示
const SIGNAL := Color("d9a326")       # 钠灯：可疑 / 提示
const FROST := Color("8fb4c4")        # 霜蓝：冷静读数
const CRT := Color("63d18a")          # 电传绿：只有电传机配用
const ASH := Color("6d7173")          # 灰：已勘 / 失效


# ============================================================================
# 字体 —— 系统字体栈，找不到就往下掉，永远有 CJK 兜底
# ============================================================================
static var _fonts: Dictionary = {}

## 钢印 / 标题：压缩无衬线优先（Oswald、Bahnschrift、Impact 这类），俄文与中文都有兜底。
static func display_font() -> SystemFont:
	if _fonts.has("display"):
		return _fonts["display"]
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"Oswald", "Bebas Neue", "Barlow Condensed", "Bahnschrift Condensed",
		"DIN Condensed", "Roboto Condensed", "Arial Narrow", "Impact",
		"Noto Sans CJK SC", "Noto Sans SC", "Microsoft YaHei", "SimHei",
		"PingFang SC", "Segoe UI", "Arial",
	])
	f.font_weight = 700
	_fonts["display"] = f
	return f


## 电传 / 数字：等宽优先，表格与读数对得齐。
static func mono_font() -> SystemFont:
	if _fonts.has("mono"):
		return _fonts["mono"]
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"JetBrains Mono", "Cascadia Mono", "Consolas", "DejaVu Sans Mono",
		"Liberation Mono", "Courier New",
		"Noto Sans CJK SC", "Noto Sans SC", "Microsoft YaHei", "SimHei",
		"PingFang SC", "Segoe UI", "Arial",
	])
	f.font_weight = 500
	_fonts["mono"] = f
	return f


## 正文：常规无衬线，中文优先。
static func body_font() -> SystemFont:
	if _fonts.has("body"):
		return _fonts["body"]
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"Noto Sans CJK SC", "Noto Sans SC", "Source Han Sans SC",
		"Microsoft YaHei", "SimHei", "PingFang SC",
		"Segoe UI", "Arial",
	])
	_fonts["body"] = f
	return f


# ============================================================================
# StyleBox 工厂 —— 方形、粗边、内衬留白
# ============================================================================
static func plate(bg: Color = IRON, border: Color = STEEL, bw: int = 2, margin: int = 16) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(0)                 # 钢板没有圆角
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = maxi(8, int(margin * 0.7))
	sb.content_margin_bottom = maxi(8, int(margin * 0.7))
	return sb


## 内嵌槽：比外框深一档、只留 1px 亮边，用来装读数 / 文本框。
static func inset(margin: int = 10) -> StyleBoxFlat:
	return plate(INK, STEEL, 1, margin)


## 红章条：军旗红底 + 亮一档的描边。
static func stamp(margin: int = 8) -> StyleBoxFlat:
	return plate(BLOOD, BLOOD_LIT, 1, margin)


## 黄铜条：强调块（目标 / 关键读数）。
static func brass(margin: int = 8) -> StyleBoxFlat:
	return plate(Color("2a2318"), OCHRE_DIM, 1, margin)


## 给 Button 一次性套上全部状态（normal / hover / pressed / disabled）。
static func dress_button(b: Button, primary: bool = false, font_size: int = 15) -> void:
	b.add_theme_font_override("font", display_font())
	b.add_theme_font_size_override("font_size", font_size)
	b.focus_mode = Control.FOCUS_NONE
	if primary:
		b.add_theme_stylebox_override("normal", plate(Color("3a1512"), BLOOD_LIT, 2, 12))
		b.add_theme_stylebox_override("hover", plate(Color("541c17"), OCHRE, 2, 12))
		b.add_theme_stylebox_override("pressed", plate(Color("240d0b"), BLOOD_LIT, 2, 12))
		b.add_theme_stylebox_override("disabled", plate(IRON, STEEL, 1, 12))
		b.add_theme_color_override("font_color", Color("f0e6d2"))
		b.add_theme_color_override("font_hover_color", Color("ffffff"))
	else:
		b.add_theme_stylebox_override("normal", plate(IRON_LIT, STEEL, 1, 12))
		b.add_theme_stylebox_override("hover", plate(PLATE, OCHRE_DIM, 1, 12))
		b.add_theme_stylebox_override("pressed", plate(INK, STEEL, 1, 12))
		b.add_theme_stylebox_override("disabled", plate(INK, Color("22282b"), 1, 12))
		b.add_theme_color_override("font_color", BONE)
		b.add_theme_color_override("font_hover_color", OCHRE)


## 1~2px 的分隔线（钢色）。
static func rule(col: Color = STEEL, h: int = 1) -> ColorRect:
	var c := ColorRect.new()
	c.color = col
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## 竖向分隔块（「│」的实体版）。
static func divider(col: Color = STEEL, w: int = 1) -> ColorRect:
	var c := ColorRect.new()
	c.color = col
	c.custom_minimum_size = Vector2(w, 0)
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## 把 Label 排成档案味：默认使用 display 字体 + 骨白。
static func label_font(l: Label, kind: String = "body") -> void:
	match kind:
		"display":
			l.add_theme_font_override("font", display_font())
		"mono":
			l.add_theme_font_override("font", mono_font())
		_:
			l.add_theme_font_override("font", body_font())


# ============================================================================
# 文本工具 —— 方位、时间、卌、危险度
# ============================================================================
const _BEAR_ZH := ["东", "东南", "南", "西南", "西", "西北", "北", "东北"]
const _BEAR_RU := ["В", "ЮВ", "Ю", "ЮЗ", "З", "СЗ", "С", "СВ"]
const _BEAR_ARROW := ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]


## 米制位移（x 向东、y 向南）→ 八方位索引 0..7（0 = 东）。
static func bearing_index(delta_m: Vector2) -> int:
	if delta_m.length_squared() < 0.0001:
		return 0
	return posmod(int(round(delta_m.angle() / (PI / 4.0))), 8)


static func bearing_zh(delta_m: Vector2) -> String:
	return _BEAR_ZH[bearing_index(delta_m)]


static func bearing_arrow(delta_m: Vector2) -> String:
	return _BEAR_ARROW[bearing_index(delta_m)]


## 一行「目标读数」：↖ 西北 23m
static func bearing_line(delta_m: Vector2) -> String:
	var d := delta_m.length()
	if d < 1.0:
		return "就在脚下"
	return "%s %s %dm" % [_BEAR_ARROW[bearing_index(delta_m)], _BEAR_ZH[bearing_index(delta_m)], int(round(d))]


## 秒 → mm:ss（电传钟）
static func clock(sec: float) -> String:
	var s := int(maxf(0.0, sec))
	return "%02d:%02d" % [int(s / 60.0), s % 60]


## 危险度 1~5 → ▲▲▲△△
static func danger_pips(level: int) -> String:
	var n := clampi(level, 1, 5)
	var s := ""
	for i in 5:
		s += "▲" if i < n else "△"
	return s


## 危险度用色（战役地图卡 / 关卡档案）：1 灰绿 → 5 军旗红
static func danger_color(level: int) -> Color:
	match clampi(level, 1, 5):
		1:
			return Color("6b7f6a")
		2:
			return Color("8c8a4a")
		3:
			return Color("b58a3c")
		4:
			return Color("b8622c")
		_:
			return Color("b8281c")


## 卌 划痕：每一道都是一个人（游戏里的「卌」= 亲手灭口一次）
static func tally_glyphs(n: int) -> String:
	if n <= 0:
		return "—"
	var s := ""
	for i in mini(n, 24):
		s += "卌"
	return s


## 汉字大写的夜数，HUD 上写「第 三 夜」时用；超出就退回阿拉伯数字。
static func night_zh(n: int) -> String:
	const NAMES := ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
	if n >= 0 and n < NAMES.size():
		return NAMES[n]
	return str(n)


## 百分比读数（仪表右侧的等宽数字）
static func pct(v: float) -> String:
	return "%3d%%" % int(round(clampf(v, 0.0, 1.0) * 100.0))
