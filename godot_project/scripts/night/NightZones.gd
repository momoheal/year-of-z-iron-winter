extends RefCounted
## 三区（白 / 红 / 黑）—— 纯数据 + 纯函数，NightExplore 与 NightZoneField 共用，也方便 headless 测。
##
## 地图按南北切成三条带（也允许一个区写多块矩形拼 L 形）：
##   white 白区 · 安全区   居民区。没有丧尸，清杀队也不进来。
##   red   红区 · 管制带   白区外围。清杀队巡逻、丧尸少、**白区居民禁止进入**。
##   black 黑区 · 沉降带   离白区最远。丧尸成群、资源最多，黑市与幸存者在这儿。
##
## 场景根节点上的 `metadata/zones` 由 build_scene.py 写成：
##   "white:0,0,48,12|red:0,12,48,21.5|black:0,21.5,48,40"
## 每一段 = id : (x0,y0,x1,y1)[;(x0,y0,x1,y1)…]，单位米。

const PPM := 64.0
const SQ := 0.62
const ORDER := ["white", "red", "black"]

## 区的展示信息：颜色 / 淡染强度 / 地面标签 / 规则说明
const INFO := {
	"white": {
		"zh": "白区 · 安全区", "en": "WHITE ZONE · SAFE", "rule": "safe",
		"col": Color("#9fc6e0"), "tint": 0.075, "tag": "ZONE A · SAFE",
		"note_zh": "居民区：没有丧尸，清杀队也不进来",
		"hud_col": Color("#bfe0f2"),
	},
	"red": {
		"zh": "红区 · 管制带", "en": "RED ZONE · CURFEW", "rule": "curfew",
		"col": Color("#c8483a"), "tint": 0.115, "tag": "ZONE B · CURFEW",
		"note_zh": "白区居民禁止进入 · 清杀队巡逻 · 丧尸较少",
		"hud_col": Color("#e8836f"),
	},
	"black": {
		"zh": "黑区 · 沉降带", "en": "BLACK ZONE · SUNKEN", "rule": "sunken",
		"col": Color("#3aa0b4"), "tint": 0.165, "tag": "ZONE C · SUNKEN",
		"note_zh": "丧尸成群 · 资源最多 · 黑市与幸存者",
		"hud_col": Color("#7fe0ef"),
	},
}

## 红区里的「白区居民禁止进入」宽限：进来多久开始被盘问、多久被上手
const CURFEW_WARN := 3.5
const CURFEW_CHALLENGE := 7.0


static func parse(src: String) -> Array:
	"""把 metadata/zones 解析成 [{id, rects:[Rect2(米)]}]，坏数据直接跳过。"""
	var out: Array = []
	for chunk in src.split("|"):
		var c := chunk.strip_edges()
		if c == "":
			continue
		var parts := c.split(":", false, 1)
		if parts.size() != 2:
			continue
		var zid := parts[0].strip_edges()
		var rects: Array = []
		for rs in parts[1].split(";", false):
			var n := rs.split(",", false)
			if n.size() != 4:
				continue
			var x0 := float(n[0])
			var y0 := float(n[1])
			var x1 := float(n[2])
			var y1 := float(n[3])
			rects.append(Rect2(minf(x0, x1), minf(y0, y1), absf(x1 - x0), absf(y1 - y0)))
		if rects.is_empty():
			continue
		out.append({"id": zid, "rects": rects})
	return out


static func zone_at(zones: Array, p_m: Vector2) -> String:
	"""世界米坐标落在哪个区；落在所有区之外返回 ""（老场景 / 没写 zones）。"""
	for z in zones:
		for r in z["rects"]:
			if (r as Rect2).has_point(p_m):
				return String(z["id"])
	return ""


static func info(zid: String) -> Dictionary:
	return INFO.get(zid, {})


static func display_zh(zid: String) -> String:
	return String(INFO.get(zid, {}).get("zh", "未划定区"))


static func rule(zid: String) -> String:
	return String(INFO.get(zid, {}).get("rule", ""))


## 黑区：资源加成（同一个容器多翻一件）
static func loot_bonus(zid: String) -> int:
	return 1 if zid == "black" else 0


## 开局提示：进关卡时先告诉玩家地图是怎么分的
static func intro_lines(zones: Array) -> Array:
	var out: Array = []
	for z in zones:
		var inf: Dictionary = INFO.get(String(z["id"]), {})
		if inf.is_empty():
			continue
		out.append("%s — %s" % [String(inf["zh"]), String(inf["note_zh"])])
	return out
