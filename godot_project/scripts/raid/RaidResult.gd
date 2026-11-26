extends RefCounted
## RaidResult.gd — 一次夜潜的最终结果（M1 / T02）。
##
## 夜潜（节点化 NightExplore 或旧灰盒 RaidSim）只负责构建它，交给
## CampaignSim.submit_raid_result() 这一个入口结算；本对象不持有场景节点、不写永久状态。
## 字段含义、单位与生产 / 消费方见 docs/zh/夜潜交接契约_字段清单_T01.md。
##
## 携带物口径（防双倍返还）：
##   · pack        —— 背包里带出来的物品，按收场原因走损失规则；
##   · refund_load —— 没并进背包、原样归还的携带物（灰盒 = RaidSim.load 剩余；节点化 = 恒为 {}，
##                    因为 water / asp / band 出发时已经并进 pack）。

const SELF_PATH := "res://scripts/raid/RaidResult.gd"
const VALID_REASONS := ["extracted", "downed", "dawn", "abort"]

var raid_id: String = ""
var loc_id: String = ""
var reason: String = ""
var pack: Array[String] = []
var refund_load: Dictionary = {}
var hp: float = 100.0
var warmth: float = 100.0
var ammo: int = 0                       # 只记录：弹药现在不跨夜入库
var conscience_delta: float = 0.0       # 结算时一次性加到良知（灰盒在夜里已实时写入，恒为 0）
var tally_delta: int = 0                # 结算时一次性加的卌划痕
var tally_reason_zh: String = ""
var tally_reason_en: String = ""
var killed: int = 0
var half_saved: int = 0
var looted: int = 0
var total_cont: int = 0
var events: Array[Dictionary] = []
var mate_id: String = ""
# 战役偏好 / 装配：null = 不改
var sound_on: Variant = null
var weapon_mods: Variant = null
# 剧情进度（夜里记在当局容器上，结算时由战役判定是否成立）
var story_objective_reached: bool = false
var market_signal_found: bool = false
var manor_photo_slot: int = -1
var manor_trade_slot: int = -1
var manor_release_reached: bool = false
var crag_rescue_scope: String = ""
var archive_copy_slot: int = -1
var coldstore_trace: Variant = null     # null = 这一夜不是首访冷库；bool = 是否看过北雨棚残票
var salvaged_weapons: Array[String] = []
# T04：夜里不再直接写战役，这些在结算时一次性入账（任何收场都入账，与原先实时写入等价）
var conscience_steps: Array[float] = []   # 灰盒逐笔良知（按顺序重放，每笔 clamp）
var tally_marks: Array[Dictionary] = []   # 灰盒逐笔卌 {n, zh, en}
var flags_set: Array[String] = []         # 夜里触发的永久旗标（如 vasily_killed、redzone_mother_seen）
var seen_set: Array[String] = []          # 看完的新手引导段（如 night）
var node_left_delta: float = 0.0          # 灰盒搜刮带走的节点余量


static func normalize_reason(r: String) -> String:
	## 节点化场景的 "frozen"（冻倒）按 downed 结算。
	return "downed" if r == "frozen" else r


static func is_valid_reason(r: String) -> bool:
	return VALID_REASONS.has(r)


static func create():
	return ResourceLoader.load(SELF_PATH).new()


static func from_raid_sim(r, p_reason: String):
	## 旧灰盒适配：把 RaidSim 的字段原样搬进结果（行为与改造前 finish_raid 读取的口径一致）。
	var res = create()
	res.raid_id = String(r.get("raid_id")) if r.get("raid_id") != null else ""
	res.loc_id = String(r.loc.get("id", ""))
	res.reason = normalize_reason(p_reason)
	for id in r.pack:
		res.pack.append(String(id))
	res.refund_load = (r.load as Dictionary).duplicate()
	res.hp = float(r.player.hp)
	res.warmth = float(r.player.warmth)
	res.ammo = int(r.ammo)
	res.killed = int(r.killed)
	res.half_saved = int(r.half_saved)
	res.looted = int(r.looted)
	res.total_cont = int(r.total_cont)
	for e in r.events:
		res.events.append((e as Dictionary).duplicate())
	res.mate_id = String(r.mate_id)
	res.story_objective_reached = bool(r.story_objective_reached)
	res.market_signal_found = bool(r.market_signal_found)
	res.manor_photo_slot = int(r.manor_photo_slot)
	res.manor_trade_slot = int(r.manor_trade_slot)
	res.manor_release_reached = bool(r.manor_release_reached)
	res.crag_rescue_scope = String(r.crag_rescue_scope)
	res.archive_copy_slot = int(r.archive_copy_slot)
	for c in r.get("conscience_steps") if r.get("conscience_steps") != null else []:
		res.conscience_steps.append(float(c))
	for m in r.get("tally_marks") if r.get("tally_marks") != null else []:
		res.tally_marks.append((m as Dictionary).duplicate())
	for f in r.get("flags_set") if r.get("flags_set") != null else []:
		res.flags_set.append(String(f))
	res.node_left_delta = float(r.get("node_left_delta")) if r.get("node_left_delta") != null else 0.0
	return res


func add_event(kind: String, zh: String, en: String) -> void:
	events.append({"t": kind, "zh": zh, "en": en})


func to_dict() -> Dictionary:
	var ev: Array = []
	for e in events:
		ev.append(e.duplicate())
	return {
		"raid_id": raid_id, "loc_id": loc_id, "reason": reason,
		"pack": Array(pack), "refund_load": refund_load.duplicate(),
		"hp": hp, "warmth": warmth, "ammo": ammo,
		"conscience_delta": conscience_delta, "tally_delta": tally_delta,
		"tally_reason_zh": tally_reason_zh, "tally_reason_en": tally_reason_en,
		"killed": killed, "half_saved": half_saved, "looted": looted, "total_cont": total_cont,
		"events": ev, "mate_id": mate_id,
		"sound_on": sound_on,
		"weapon_mods": (weapon_mods as Dictionary).duplicate(true) if weapon_mods is Dictionary else null,
		"story_objective_reached": story_objective_reached,
		"market_signal_found": market_signal_found,
		"manor_photo_slot": manor_photo_slot, "manor_trade_slot": manor_trade_slot,
		"manor_release_reached": manor_release_reached,
		"crag_rescue_scope": crag_rescue_scope, "archive_copy_slot": archive_copy_slot,
		"coldstore_trace": coldstore_trace,
		"salvaged_weapons": Array(salvaged_weapons),
		"conscience_steps": Array(conscience_steps), "tally_marks": Array(tally_marks).duplicate(true),
		"flags_set": Array(flags_set), "seen_set": Array(seen_set), "node_left_delta": node_left_delta,
	}


static func from_dict(d: Dictionary):
	var res = create()
	res.raid_id = String(d.get("raid_id", ""))
	res.loc_id = String(d.get("loc_id", ""))
	res.reason = normalize_reason(String(d.get("reason", "")))
	for id in d.get("pack", []):
		res.pack.append(String(id))
	var rl: Variant = d.get("refund_load", {})
	res.refund_load = (rl as Dictionary).duplicate() if rl is Dictionary else {}
	res.hp = float(d.get("hp", 100.0))
	res.warmth = float(d.get("warmth", 100.0))
	res.ammo = int(d.get("ammo", 0))
	res.conscience_delta = float(d.get("conscience_delta", 0.0))
	res.tally_delta = int(d.get("tally_delta", 0))
	res.tally_reason_zh = String(d.get("tally_reason_zh", ""))
	res.tally_reason_en = String(d.get("tally_reason_en", ""))
	res.killed = int(d.get("killed", 0))
	res.half_saved = int(d.get("half_saved", 0))
	res.looted = int(d.get("looted", 0))
	res.total_cont = int(d.get("total_cont", 0))
	for e in d.get("events", []):
		if e is Dictionary:
			res.events.append((e as Dictionary).duplicate())
	res.mate_id = String(d.get("mate_id", ""))
	var so: Variant = d.get("sound_on", null)
	res.sound_on = bool(so) if so != null else null
	var wm: Variant = d.get("weapon_mods", null)
	res.weapon_mods = (wm as Dictionary).duplicate(true) if wm is Dictionary else null
	res.story_objective_reached = bool(d.get("story_objective_reached", false))
	res.market_signal_found = bool(d.get("market_signal_found", false))
	res.manor_photo_slot = int(d.get("manor_photo_slot", -1))
	res.manor_trade_slot = int(d.get("manor_trade_slot", -1))
	res.manor_release_reached = bool(d.get("manor_release_reached", false))
	res.crag_rescue_scope = String(d.get("crag_rescue_scope", ""))
	res.archive_copy_slot = int(d.get("archive_copy_slot", -1))
	var ct: Variant = d.get("coldstore_trace", null)
	res.coldstore_trace = bool(ct) if ct != null else null
	for w in d.get("salvaged_weapons", []):
		res.salvaged_weapons.append(String(w))
	for c in d.get("conscience_steps", []):
		res.conscience_steps.append(float(c))
	for m in d.get("tally_marks", []):
		if m is Dictionary:
			res.tally_marks.append((m as Dictionary).duplicate())
	for f in d.get("flags_set", []):
		res.flags_set.append(String(f))
	for k in d.get("seen_set", []):
		res.seen_set.append(String(k))
	res.node_left_delta = float(d.get("node_left_delta", 0.0))
	return res
