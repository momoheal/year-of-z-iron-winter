extends RefCounted
## RaidConfig.gd — 一次出发的类型化配置（M1 / T02）。
##
## 由 CampaignSim.depart() 生成，经 to_dict() 交给 RaidSim / RaidBridge（旧 cfg Dictionary 口径不变，
## 只多一个 raid_id 键）。字段含义、单位与生产 / 消费方见 docs/zh/夜潜交接契约_字段清单_T01.md。
##
## 约定：武器只存 id，整张武器表由 CampaignData.weapon(id) 查；时间一律写明单位（分钟 / 秒）。

const Data := preload("res://scripts/CampaignData.gd")
const SELF_PATH := "res://scripts/raid/RaidConfig.gd"

var raid_id: String = ""
var loc: Dictionary = {}               # CampaignData.LOCS 条目（RaidSim 生成地图要用整表）
var loc_id: String = ""
var day: int = 1
var seed: int = 1234
var left: float = 1.0                  # 节点剩余物资 0..1
var mate_id: String = ""               # "" = 没带伙伴
var pack_max: int = Data.BAG           # 背包格数
var weapon_id: String = "crowbar"
var load: Dictionary = {}              # 携带物 id -> 件数（出发时已从仓库扣除）
var cold: float = 1.0                  # 体温下降倍率
var danger: int = 1
var travel_minutes: int = 0            # 路程（分钟）
var glasses: bool = false
var night_seconds: float = 200.0       # 天亮倒计时（秒）
var sound_on: bool = true


static func from_dict(d: Dictionary):
	## 旧 cfg Dictionary → RaidConfig。weapon 兼容整张表或 id 字符串。
	# 成员变量叫 load，这里显式用 ResourceLoader 取本脚本
	var c = ResourceLoader.load(SELF_PATH).new()
	c.raid_id = String(d.get("raid_id", ""))
	var lv: Variant = d.get("loc", {})
	c.loc = (lv as Dictionary) if lv is Dictionary else {}
	c.loc_id = String(c.loc.get("id", d.get("loc_id", "")))
	c.day = int(d.get("day", 1))
	c.seed = int(d.get("seed", 1234))
	c.left = float(d.get("left", 1.0))
	c.mate_id = String(d.get("mate", ""))
	c.pack_max = int(d.get("pack_max", Data.BAG))
	c.weapon_id = weapon_id_of(d.get("weapon", "crowbar"))
	var ld: Variant = d.get("load", {})
	c.load = (ld as Dictionary).duplicate() if ld is Dictionary else {}
	c.cold = float(d.get("cold", 1.0))
	c.danger = int(d.get("danger", 1))
	c.travel_minutes = int(d.get("time", 0))
	c.glasses = bool(d.get("glasses", false))
	c.night_seconds = float(d.get("night", 200.0))
	c.sound_on = bool(d.get("sound_on", true))
	return c


static func weapon_id_of(v: Variant) -> String:
	if v is Dictionary:
		return String((v as Dictionary).get("id", "crowbar"))
	var s := String(v) if v != null else ""
	return s if s != "" else "crowbar"


func weapon() -> Dictionary:
	## 整张武器表（与 CampaignData.WEAPONS 中的条目是同一份数据）。
	return Data.weapon(weapon_id)


func to_dict() -> Dictionary:
	## RaidConfig → 旧 cfg Dictionary（RaidSim / RaidBridge / NightExplore 现有读法）。
	return {
		"raid_id": raid_id,
		"loc": loc,
		"day": day,
		"seed": seed,
		"left": left,
		"mate": mate_id,
		"pack_max": pack_max,
		"weapon": weapon(),
		"load": load.duplicate(),
		"cold": cold,
		"danger": danger,
		"time": travel_minutes,
		"glasses": glasses,
		"night": night_seconds,
		"sound_on": sound_on,
	}
