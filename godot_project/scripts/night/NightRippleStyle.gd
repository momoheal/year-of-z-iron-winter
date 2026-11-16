extends RefCounted
## NightRippleStyle.gd — 声纹可访问性：六类声纹的「非颜色冗余编码」。
##
## 问题：NightExplore.emit_noise() 原先只用 col 区分声源（灰白 / 暗红 / 冷蓝 /
## 三档琥珀），NightOverlay 一律画同一条实线椭圆。三档琥珀 #fbbf24 / #e2c48a /
## #fcd9a0 明度接近，暗红 #b91c1c 对红绿色觉障碍难分；灰度下六种波纹糊成一种，
## 而声纹是潜行玩法里「谁在靠近」的唯一提示。
##
## 对策：每个色组配一套**互异的线型 + 互异的中心图标**（双重冗余），颜色原样保留。
## 冗余形状无条件常开 —— 不依赖任何设置开关，玩家不必先找到选项才看得懂。
## colorblind 模式只是把线加粗、图标放大、再叠一个单字标签，是增强而非开关。
##
## 本模块只做纯数据 / 纯函数映射：不碰半径、寿命、监听半径、AI 行为、颜色，
## 不改任何玩法数值。可脱离帧循环直接调用，便于 headless smoke 断言。
##
## 验收图：docs/ui/verify/ripple_accessibility_greyscale.png
## （由 tools/art_gen/gen_ripple_greyscale.py 合成的对照图，不是实机截图）。

# 六个色组 → 六套互异形状。线型 6 种互异、图标 6 种互异，灰度下双重可分。
const STYLES := {
	"": {
		"pattern": "solid",        "glyph": "dot",
		"label": "我", "tag": "YOU", "name_zh": "玩家 / 脚步 / 命中",
		"pattern_zh": "实线单环", "glyph_zh": "实心点", "hex": "#cbd5e1",
	},
	"rabid": {
		"pattern": "dashed",       "glyph": "triangle",
		"label": "狂", "tag": "RABID", "name_zh": "狂暴者低吼",
		"pattern_zh": "粗虚线八段", "glyph_zh": "实心三角", "hex": "#b91c1c",
	},
	"gun": {
		"pattern": "double",       "glyph": "square",
		"label": "兵", "tag": "OSK", "name_zh": "清杀队 / 枪声",
		"pattern_zh": "同心双环", "glyph_zh": "空心方块", "hex": "#7dd3fc",
	},
	"can": {
		"pattern": "dotted",       "glyph": "diamond",
		"label": "罐", "tag": "CAN", "name_zh": "飞罐诱饵",
		"pattern_zh": "点线廿四段", "glyph_zh": "菱形", "hex": "#fbbf24",
	},
	"search": {
		"pattern": "dashdot",      "glyph": "cross",
		"label": "搜", "tag": "SEARCH", "name_zh": "搜刮声",
		"pattern_zh": "长短交替", "glyph_zh": "十字", "hex": "#e2c48a",
	},
	"half": {
		"pattern": "split",        "glyph": "ring",
		"label": "半", "tag": "HALF", "name_zh": "半人呻吟",
		"pattern_zh": "上半虚 / 下半实", "glyph_zh": "空心圆环", "hex": "#fcd9a0",
	},
}

## NightExplore.emit_noise 的 match 只认 5 个 kind；step / hit 及任何未知 kind
## 都落到默认灰白 #cbd5e1，因此形状也归一到「自身」组 —— 形状与颜色一一对应。
## RaidSim / Sim 里的 self / osk / ash 等是另一套 emit_noise，不走 NightOverlay；
## 列在这里只为让本模块被别处复用时也不出错。
const ALIASES := {"step": "", "hit": "", "self": "", "osk": "gun", "ash": ""}


## 把任意 kind 收敛到六个色组之一，永不抛错。
static func canonical(kind: String) -> String:
	if STYLES.has(kind):
		return kind
	var c := String(ALIASES.get(kind, ""))
	return c if STYLES.has(c) else ""


## 六类各自的形状定义（只读数据）。
static func style_for(kind: String) -> Dictionary:
	return STYLES.get(canonical(kind), STYLES[""])


static func kinds() -> Array:
	return ["", "step", "hit", "can", "search", "rabid", "gun", "half"]


static func color_groups() -> Array:
	return STYLES.keys()


## 绘制层唯一入口：给一条 ripple 算出「画什么」。
## shape_always_on 恒为 true —— 形状冗余默认常开是安全底线，不受设置影响。
## colorblind 只影响线宽 / 图标尺寸 / 是否叠单字标签。
static func visual_for(r: Dictionary, colorblind: bool) -> Dictionary:
	var st := style_for(String(r.get("kind", "")))
	return {
		"pattern": String(st["pattern"]),
		"glyph": String(st["glyph"]),
		"label": String(st["label"]),
		"tag": String(st["tag"]),
		"width": 3.6 if colorblind else 2.6,
		"glyph_scale": 1.35 if colorblind else 1.0,
		"show_label": colorblind,
		"shape_always_on": true,
	}
