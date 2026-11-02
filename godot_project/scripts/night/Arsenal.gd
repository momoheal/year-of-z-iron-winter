extends RefCounted
## Arsenal.gd — 夜潜军械库（P5 战斗切片）。
##
## 纯数据 + 静态查询：NightExplore 负责手感与命中，这里只放「这支家伙是什么」。
## 三条设计纪律：
##   * 撬棍永远在手上 —— 安静、慢、必进；它才是这一夜的基调。
##   * 枪是「花钱买路」—— 一枪换一次暴露，所以噪声半径远大于射程。
##   * 弹药稀缺：初始一个弹匣 + 一个备用弹匣，剩下的只能在弹药箱里翻。
##
## 单位：伤害 = HP 点数；射程 / 噪声 = 逻辑米；散布 = 角度（度）。

const ORDER := ["crowbar", "pistol", "rifle", "shotgun"]

## hold / scale 是「握在手里」的精灵摆位：枪口朝 +x，pivot 在握把。
const WEAPONS := {
	"crowbar": {
		"zh": "铸铁道钉撬棍", "en": "RAILWAY CROWBAR", "short": "撬棍",
		"kind": "melee", "dmg": 34.0, "rate": 1.45, "reach": 1.9, "arc": 0.85,
		"noise": 4.5, "mag": 0, "reserve": 0, "reload": 0.0,
		"tex": "res://art/30_props/PRP_Crowbar_Rail.png",
		"hold_x": 10.0, "hold_y": -42.0, "hold_rot": -0.30, "scale": 0.50,
		"sfx": "swing", "sfx_hit": "crowbar_hit",
	},
	"pistol": {
		"zh": "ТТ-33 手枪", "en": "TT-33 PISTOL", "short": "ТТ-33",
		"kind": "gun", "dmg": 42.0, "rate": 3.6, "reach": 16.0, "arc": 0.0,
		"noise": 26.0, "mag": 8, "reserve": 16, "reserve_max": 32, "reload": 1.35,
		"spread": 2.6, "pellets": 1,
		"tex": "res://art/30_props/PRP_Pistol_TT.png",
		"hold_x": 17.0, "hold_y": -46.0, "hold_rot": 0.0, "scale": 0.46,
		"sfx": "gunshot", "sfx_hit": "",
	},
	"rifle": {
		"zh": "莫辛纳甘步枪", "en": "MOSIN-NAGANT", "short": "莫辛",
		"kind": "gun", "dmg": 96.0, "rate": 1.05, "reach": 28.0, "arc": 0.0,
		"noise": 44.0, "mag": 5, "reserve": 10, "reserve_max": 25, "reload": 2.6,
		"spread": 1.1, "pellets": 1,
		"tex": "res://art/30_props/PRP_Rifle_Mosin.png",
		"hold_x": 22.0, "hold_y": -44.0, "hold_rot": 0.0, "scale": 0.42,
		"sfx": "rifle_shot", "sfx_hit": "",
	},
	"shotgun": {
		"zh": "截短双管猎枪", "en": "SAWN-OFF DOUBLE", "short": "双管",
		"kind": "gun", "dmg": 15.0, "rate": 1.15, "reach": 9.5, "arc": 0.0,
		"noise": 38.0, "mag": 2, "reserve": 8, "reserve_max": 20, "reload": 2.9,
		"spread": 7.5, "pellets": 6,
		"tex": "res://art/30_props/PRP_Shotgun_Sawn.png",
		"hold_x": 16.0, "hold_y": -44.0, "hold_rot": 0.0, "scale": 0.44,
		"sfx": "shotgun_shot", "sfx_hit": "",
	},
}

## 搜到这些东西 = 补弹（物品 id 来自 CampaignData.ITEMS）
const AMMO_FROM_ITEM := {
	"ammo": {"pistol": 8, "rifle": 5, "shotgun": 4},
	"bolt": {"rifle": 5},
	"part": {"pistol": 4},
}

## 命中判定的「身体半径」（米）：狂暴者最粗，半人最瘦
const HIT_R := {"soldier": 0.46, "rabid": 0.52, "half": 0.40}


static func spec(id: String) -> Dictionary:
	return WEAPONS.get(id, WEAPONS["crowbar"])


static func has(id: String) -> bool:
	return WEAPONS.has(id)


static func is_gun(id: String) -> bool:
	return String(spec(id).get("kind", "melee")) == "gun"


static func name_zh(id: String) -> String:
	return String(spec(id).get("zh", id))


static func short_zh(id: String) -> String:
	return String(spec(id).get("short", id))


static func label(id: String, mag: int, reserve: int) -> String:
	var w := spec(id)
	if String(w.get("kind", "melee")) != "gun":
		return "%s · 近战" % String(w.get("zh", id))
	return "%s · %d / %d" % [String(w.get("zh", id)), mag, reserve]


## 弹匣 / 备弹的初始值（战役里带进来的枪只看有没有，不看余弹）
static func start_mag(id: String) -> int:
	return int(spec(id).get("mag", 0))


static func start_reserve(id: String) -> int:
	return int(spec(id).get("reserve", 0))


## 这件战利品能给什么弹（没有就是空字典）
static func ammo_for(item_id: String) -> Dictionary:
	return AMMO_FROM_ITEM.get(item_id, {})
