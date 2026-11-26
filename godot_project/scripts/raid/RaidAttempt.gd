extends RefCounted
## RaidAttempt.gd — 节点化夜潜的「当局容器」（M1 / T04）。
##
## 出发去带 scene 字段的地点时，CampaignSim 不再构建整张灰盒 RaidSim（地图生成、实体、视野…），
## 只放这个轻量容器：它只承载本局的标识、出发配置里结算要用的部分，以及夜里记下的剧情进度。
## 字段名与 RaidSim 保持一致，RaidResult.from_raid_sim() / 结算 / NightExplore 可以不区分两者。
## 它不碰战役状态；夜里的一切都在 NightExplore 本地，收场时收成 RaidResult 一次提交。

const Data := preload("res://scripts/CampaignData.gd")

## 结算适配器读 player.hp / player.warmth；节点化夜潜的真实数值由 NightExplore 写进 RaidResult。
class Vitals extends RefCounted:
	var hp: float = 100.0
	var warmth: float = 100.0

var is_attempt := true             # 区分灰盒 RaidSim：战役场景只在灰盒时跑 update / 画地图

var raid_id: String = ""
var loc: Dictionary = {}
var mate_id: String = ""
var pack_max: int = Data.BAG
var weapon: Dictionary = {}
var ammo: int = 0
var load: Dictionary = {}
var player := Vitals.new()
var pack: Array[String] = []
var events: Array[Dictionary] = []
var killed: int = 0
var half_saved: int = 0
var looted: int = 0
var total_cont: int = 0
var over := false
var phase: String = "raid"
# 剧情进度：夜里由 NightExplore 记录，结算时由 CampaignSim 判定
var market_signal_found := false
var story_objective_reached := false
var manor_photo_slot := -1
var manor_trade_slot := -1
var manor_release_reached := false
var crag_rescue_scope := ""
var archive_copy_slot := -1
# 灰盒 RaidSim 夜里攒下、结算时一次性入账的战役改动；节点化路径恒为空（NightExplore 直接写进 RaidResult）
var conscience_delta: float = 0.0
var tally_marks: Array[Dictionary] = []
var flags_set: Array[String] = []
var node_left_delta: float = 0.0


func _init(cfg: Dictionary = {}) -> void:
	raid_id = String(cfg.get("raid_id", ""))
	var lv: Variant = cfg.get("loc", {})
	loc = (lv as Dictionary) if lv is Dictionary else {}
	mate_id = String(cfg.get("mate", ""))
	pack_max = int(cfg.get("pack_max", Data.BAG))
	var wv: Variant = cfg.get("weapon", {})
	weapon = (wv as Dictionary) if wv is Dictionary else Data.weapon(String(wv))
	ammo = int(weapon.get("ammo", 0))
	var ld: Variant = cfg.get("load", {})
	load = (ld as Dictionary).duplicate() if ld is Dictionary else {}


func add_event(kind: String, zh: String, en: String) -> void:
	events.append({"t": kind, "zh": zh, "en": en})


func finish(reason: String) -> void:
	if over:
		return
	over = true
	phase = reason


func drain_sfx() -> Array[String]:
	return []
