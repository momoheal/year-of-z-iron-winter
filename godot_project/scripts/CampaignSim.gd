extends RefCounted

const CutsceneData := preload("res://scripts/data/CutsceneData.gd")
## CampaignSim.gd — 探索循环 DEMO 的战役层纯逻辑。
##
## 1:1 对应 prototypes/Year_of_Z_Iron_Winter_Exploration_Demo.html 的：
##   newGame / itemName / addItem / takeItem / catCount / medCount / intelCount
##   nodeState / locUnlocked / weaponParts / weaponOwned / ownedWeapons
##   objectiveText / depart / endScene / renderReport 的数据部分 / advanceDay / openStory 的效果部分
##
## 阶段机：title → base → map → raid → report → base …（触发 DEMO 边界后 = ending）
## 全部状态放在这里，RaidSim 持有一个 campaign 引用回写良知 / 卌 / 背包。

const Data := preload("res://scripts/CampaignData.gd")
const RaidSimScript := preload("res://scripts/RaidSim.gd")
const FIRST_ACT_LOC := "coldstore"

# ---------------- 战役状态 ----------------
var day: int = 1
var mother_alive := true
var dial: float = 2.0            # 剩余腹透液（天）
var conscience: float = 50.0
var tally: int = 0
var stash: Dictionary = {}
var weapon_mods: Dictionary = {}   # 已装配改造：军械库武器 id -> [suppressor, scope]
var base_display: Array[String] = [] # 602 室陈列的物品 / 武器引用，不消耗库存
var dial_machine_bags: int = 0       # 已交给母亲、放在透析机旁的袋数
var night_complete := false          # 本日夜潜已结算；回到据点后先睡觉再出发
var mates: Dictionary = {}
var flags: Dictionary = {}
var names: Array[String] = []
var story_done: Dictionary = {}
var seen: Dictionary = {}        # 新手引导看过哪几段：base / map / night（随存档走）
var nodes: Dictionary = {}
var log: Array[Dictionary] = []

var mate: String = "none"
var load: Dictionary = {"can": 0, "water": 0, "asp": 0, "band": 0}
var last_report: Dictionary = {}

# ---------------- 阶段 / UI 状态 ----------------
var lang: String = "zh"
var sound_on := true             # 音效开关：跟着人走进节点化夜潜场景（cfg.sound_on），回来时写回
var phase: String = "title"      # title | base | map | raid | report | ending
var selected_loc: String = ""
var raid = null                  # RaidSim 实例（仅 raid 阶段非空）
var pending_scene: String = ""   # depart 后待切到的节点化场景（空=灰盒 raid 原地跑）
var story_open := false
var story_id: String = ""
var story_result: Dictionary = {}
var logbook_open := false
var help_open := false
var log_open := false
var abort_confirm := false
var day_message: String = ""
var events_log: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.seed = 20261023
	new_game()

# ============================================================================
# 开局
# ============================================================================
func new_game() -> void:
	day = 1
	mother_alive = true
	dial = 2.0
	conscience = 50.0
	tally = 0
	flags = {"first_act_pending": true}
	names = []
	story_done = {}
	seen = {}
	nodes = {}
	log = []
	mate = "none"
	load = {"can": 0, "water": 0, "asp": 0, "band": 0}
	last_report = {}
	sound_on = true
	phase = "title"
	selected_loc = FIRST_ACT_LOC
	finished_demo = false
	raid = null
	pending_scene = ""
	story_open = false
	story_id = ""
	story_result = {}
	logbook_open = false
	help_open = false
	abort_confirm = false
	day_message = ""
	events_log = []
	stash = {"rye": 3, "can": 2, "water": 1, "band": 1, "scrap": 2}
	weapon_mods = {}
	base_display = []
	dial_machine_bags = 0
	night_complete = false
	mates.clear()
	for m in Data.MATES:
		mates[String(m["id"])] = false
	for l in Data.LOCS:
		nodes[l["id"]] = {"visits": 0, "left": 1.0, "hint": 0}
	add_log("你回到 602 室。母亲在透析机旁睡着了，眉头仍因疼痛紧锁；你放轻脚步，仿佛连呼吸也会成为一笔开销。",
		"You return to Room 602. Mother sleeps beside the dialysis machine, her brow still knotted with pain; you soften even your breathing, as if it too had a price.")
	_sync_logbook()

# ============================================================================
# 文本 / 物品
# ============================================================================
func _tr(key: String, args: Array = []) -> String:
	var table: Dictionary = Data.TEXT.get(lang, Data.TEXT["zh"])
	var s: String = String(table.get(key, key))
	for a in args:
		s = s.replace("%d", str(a))
	return s

func other_lang() -> String:
	return "en" if lang == "zh" else "zh"

func toggle_lang() -> void:
	lang = "en" if lang == "zh" else "zh"

func item_name(id: String) -> String:
	if not Data.ITEMS.has(id):
		return id
	var it: Dictionary = Data.ITEMS[id]
	return String(it["zh"] if lang == "zh" else it["en"])

func item_icon(id: String) -> String:
	if not Data.ITEMS.has(id):
		return "·"
	return String(Data.ITEMS[id]["ic"])

func item_cat(id: String) -> String:
	if not Data.ITEMS.has(id):
		return ""
	return String(Data.ITEMS[id]["cat"])

func add_item(id: String, n: int) -> void:
	if n == 0 or not Data.ITEMS.has(id):
		return
	stash[id] = int(stash.get(id, 0)) + n
	if int(stash[id]) <= 0:
		stash.erase(id)

func take_item(id: String, n: int) -> bool:
	if n == 0:
		return true
	if int(stash.get(id, 0)) < n:
		return false
	stash[id] = int(stash.get(id, 0)) - n
	if int(stash[id]) <= 0:
		stash.erase(id)
		base_display.erase("item:" + id)
	return true


func hand_dial_to_mother() -> bool:
	if not mother_alive or dial_machine_bags >= 3 or not take_item("dial", 1):
		return false
	dial_machine_bags += 1
	add_log("你把一袋透析液放到机器旁，母亲轻轻点了点头。",
		"You place a bag of dialysis fluid beside the machine. Mother gives a small nod.")
	return true


func toggle_base_display(ref: String) -> bool:
	if base_display.has(ref):
		base_display.erase(ref)
		return true
	if base_display.size() >= 4:
		return false
	var parts := ref.split(":", false, 1)
	if parts.size() != 2:
		return false
	match parts[0]:
		"item":
			if not Data.ITEMS.has(parts[1]) or int(stash.get(parts[1], 0)) <= 0:
				return false
		"weapon":
			var w := Data.weapon(parts[1])
			if not weapon_owned(w) or not weapon_displayable(w):
				return false
		_:
			return false
	base_display.append(ref)
	return true


func base_display_name(ref: String) -> String:
	var parts := ref.split(":", false, 1)
	if parts.size() != 2:
		return ref
	if parts[0] == "item":
		return "%s %s" % [item_icon(parts[1]), item_name(parts[1])]
	if parts[0] == "weapon":
		var w := Data.weapon(parts[1])
		return "%s %s" % [String(w.get("ic", "ARM")), String(w.get("zh" if lang == "zh" else "en", parts[1]))]
	return ref

func has_item(id: String, n: int = 1) -> bool:
	return int(stash.get(id, 0)) >= n

func cat_count(cat: String) -> int:
	var s := 0
	for k in stash.keys():
		if item_cat(String(k)) == cat:
			s += int(stash[k])
	return s

func med_count() -> int:
	return int(stash.get("asp", 0)) + int(stash.get("band", 0)) \
		+ int(stash.get("abx", 0)) + int(stash.get("dial", 0))

func rescue_medicine() -> String:
	var stock := stash.duplicate()
	if raid != null:
		for item in raid.load:
			stock[item] = int(stock.get(item, 0)) + int(raid.load[item])
	for item in ["band", "asp", "abx"]:
		if int(stock.get(item, 0)) > 0:
			return item
	return ""

func intel_count() -> int:
	return int(stash.get("intel", 0))

func stash_sorted() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k in stash.keys():
		out.append({"id": String(k), "n": int(stash[k]), "cat": item_cat(String(k))})
	out.sort_custom(func(a, b): return String(a["id"]) < String(b["id"]))
	return out

# ============================================================================
# 地点 / 解锁
# ============================================================================
func node_state(id: String) -> Dictionary:
	if not nodes.has(id):
		nodes[id] = {"visits": 0, "left": 1.0, "hint": 0}
	return nodes[id]

func location(id: String) -> Dictionary:
	return Data.loc(id)

func first_act_pending() -> bool:
	return bool(flags.get("first_act_pending", false)) and not bool(story_done.get(FIRST_ACT_LOC, false))

func _lead_gate(loc_id: String) -> String:
	if loc_id == "sanitarium" and not bool(flags.get("story_yard", false)) \
			and not bool(story_done.get("yard", false)) and not bool(flags.get("lana_car3", false)):
		return "yard"
	if loc_id in ["marshalling", "mine"] and bool(flags.get("lana_car3", false)) \
			and not bool(flags.get("story_market", false)) and not bool(story_done.get("market", false)) \
			and not bool(flags.get("endgame_known", false)):
		return "market"
	return ""


func loc_unlocked(L: Dictionary) -> bool:
	if _lead_gate(String(L.get("id", ""))) != "":
		return false
	if first_act_pending() and String(L.get("id", "")) != FIRST_ACT_LOC:
		return false
	if String(L.get("id", "")) == "sanitarium" and bool(story_done.get(FIRST_ACT_LOC, false)) \
			and not bool(flags.get("archive_lead", false)) and not bool(flags.get("lana_car3", false)):
		return false
	var rf: String = String(L.get("req_flag", ""))
	if rf != "" and not bool(flags.get(rf, false)):
		return false
	for extra_flag in L.get("req_flags", []):
		if not bool(flags.get(String(extra_flag), false)):
			return false
	var req: Dictionary = L.get("req", {})
	if req.has("intel") and intel_count() < int(req["intel"]):
		return false
	if req.has("med") and rescue_medicine() == "":
		return false
	return true

func lock_reason(L: Dictionary) -> String:
	if first_act_pending() and String(L.get("id", "")) != FIRST_ACT_LOC:
		return "先完成第一幕：四号铁路冷库" if lang == "zh" else "Finish Act I at Rail Cold Storage No.4 first"
	if String(L.get("id", "")) == "sanitarium" and bool(story_done.get(FIRST_ACT_LOC, false)) \
			and not bool(flags.get("archive_lead", false)) and not bool(flags.get("lana_car3", false)):
		return "需要：先听维京娜提到的档案馆线索" if lang == "zh" else "Requires: follow Vikina's archive lead first"
	match _lead_gate(String(L.get("id", ""))):
		"yard":
			return "需要：先到广轨货场核对编组单" if lang == "zh" else "Requires: check the consist at the freight yard"
		"market":
			return "需要：先问老轨伊万这趟车的去向" if lang == "zh" else "Requires: ask Ivan where the train is going"
	var rf: String = String(L.get("req_flag", ""))
	if rf == "manor_tip":
		return "需要：铁路黑市 6.66 MHz 电台给出的庄园线索" if lang == "zh" \
			else "Requires: the 6.66 MHz radio lead in the rail market"
	if rf == "lana_car3":
		return "需要：先从安娜口中确认拉娜平安度过了高烧" if lang == "zh" \
			else "Requires: learn from Anna that Lana survived the fever"
	if rf == "endgame_known":
		return "需要：先在西站调车场找到红章发车令" if lang == "zh" \
			else "Requires: find the red-stamped dispatch order at West Station"
	if rf == "station_route":
		return "需要：先在布拉风货场确认鹰嘴崖检修路线" if lang == "zh" \
			else "Requires: confirm the Crag maintenance route at Buran Yard"
	if rf == "eagle_escape":
		return "需要：先从鹰嘴崖带幸存者撤离" if lang == "zh" \
			else "Requires: extract survivors from Eagle's Crag first"
	for extra_flag in L.get("req_flags", []):
		var flag_id := String(extra_flag)
		if not bool(flags.get(flag_id, false)):
			if flag_id == "truth":
				return "需要：先从松林庄园带回罪证" if lang == "zh" else "Requires: bring evidence back from Pine Manor"
			return ("需要：%s" if lang == "zh" else "Requires: %s") % flag_id
	var req: Dictionary = L.get("req", {})
	var parts: Array[String] = []
	if req.has("intel"):
		parts.append(("情报 ×%d" if lang == "zh" else "Intel ×%d") % int(req["intel"]))
	if req.has("med"):
		parts.append(("绷带、阿司匹林或抗生素 ×%d" if lang == "zh" else "Bandage, aspirin or antibiotics ×%d") % int(req["med"]))
	if parts.is_empty():
		return ""
	return ("需要：" if lang == "zh" else "Requires: ") + " · ".join(parts)

func unlocked_count() -> int:
	var n := 0
	for L in Data.LOCS:
		if loc_unlocked(L):
			n += 1
	return n

func node_title(L: Dictionary) -> String:
	return String(L["zh"] if lang == "zh" else L["en"])

func travel_minutes(L: Dictionary) -> int:
	var t := float(L["time"])
	if mate == "ivan":
		t *= 0.8
	return int(round(t))

# ============================================================================
# 武器
# ============================================================================
func weapon_parts(w: Dictionary) -> int:
	var n := 0
	for p in w.get("parts", []):
		if int(stash.get(String(p), 0)) > 0:
			n += 1
	return n

func weapon_owned(w: Dictionary) -> bool:
	if int(w.get("need", 0)) == 0:
		return true
	if bool(flags.get("salvaged_" + String(w.get("id", "")), false)):
		return true
	return weapon_parts(w) >= (w.get("parts", []) as Array).size()


func register_salvaged_weapon(id: String) -> void:
	if id != "mosin":
		return
	var w: Dictionary = Data.weapon(id)
	var already_owned := weapon_owned(w)
	flags["salvaged_" + id] = true
	if already_owned or phase != "report":
		return
	var new_weapons: Array = last_report.get("new_weapons", [])
	if not new_weapons.has(id):
		new_weapons.append(id)
		last_report["new_weapons"] = new_weapons

func owned_weapons() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w in Data.WEAPONS:
		if weapon_owned(w):
			out.append(w)
	return out

func weapon_owned_ids() -> Array[String]:
	var out: Array[String] = []
	for w in owned_weapons():
		out.append(String(w["id"]))
	return out

func best_weapon() -> Dictionary:
	# 与 HTML startScene 一致：莫辛 > 猎枪 > 砍骨刀 > 撬棍
	for id in ["mosin", "shotgun", "cleaver"]:
		var w: Dictionary = Data.weapon(id)
		if weapon_owned(w):
			return w
	return Data.weapon("crowbar")


func weapon_displayable(w: Dictionary) -> bool:
	## 赤手是战斗选项，不是可以放上 602 室架子的实物。
	return bool(w.get("displayable", true))

# ============================================================================
# 目标
# ============================================================================
func objective() -> Dictionary:
	if first_act_pending():
		return {
			"zh": "去四号铁路冷库。南库的封存箱里有母亲用的腹透液。拉娜也经过那儿吗？如果来得及，去北雨棚看看。",
			"en": "Go to Cold Storage No.4. The sealed crate in the south hall holds Mother's dialysis fluid. If there is time, check the north awning for a trace of Lana.",
		}
	if not mother_alive and not bool(flags.get("market_refuge_found", false)):
		return {
			"zh": "母亲走后，602 室已无法继续住下去。去铁路黑市找一处能躲过清杀队的栖身处。",
			"en": "With Mother gone, Room 602 is no longer a place to stay. Find a refuge at the rail black market, away from OSK patrols.",
		}
	if bool(flags.get("vikina_clue_pending", false)) and not bool(flags.get("archive_lead", false)):
		return {
			"zh": "回到 602 室听维京娜说完那句闲话；她提到的电报底单，也许能找到拉娜的去向。",
			"en": "Return to Room 602 and hear Vikina out. Her offhand remark about a telegram copy may point to Lana.",
		}
	if not bool(flags.get("lana_car3", false)):
		if bool(story_done.get(FIRST_ACT_LOC, false)) and not bool(flags.get("archive_lead", false)):
			return {
				"zh": "先在 602 室找维京娜确认档案馆线索。",
				"en": "Ask Vikina in Room 602 to confirm the archive lead first.",
			}
		if _lead_gate("sanitarium") == "yard":
			return {"zh": "去夜间广轨货场查编组单，核对拉娜的档案号。",
				"en": "Check Lana’s file number against the consist at the broad-gauge yard."}
		if intel_count() < 2 or rescue_medicine() == "":
			var lead_note_zh := ""
			var lead_note_en := ""
			if bool(flags.get("vikina_told_directly", false)):
				lead_note_zh = "你追问过维京娜；她确认底单退回了档案馆。"
				lead_note_en = "You asked Vikina directly; she confirmed the copy went back to the archive."
			elif bool(flags.get("vikina_kept_quiet", false)):
				lead_note_zh = "你没有惊动维京娜，把线索记在心里。"
				lead_note_en = "You kept Vikina out of it and memorized the clue."
			return {
				"zh": lead_note_zh + "按线索去档案馆电报局找调度底单；凑够情报 ×2 和救援药品 ×1（绷带、阿司匹林或抗生素），再去疗养院找安娜（0419）。",
				"en": lead_note_en + " Follow the lead to the Archive & Telegraph Office for dispatch records. Gather 2 Intel and one bandage, aspirin or antibiotics, then find Anna (0419) at the sanatorium.",
			}
		return {
			"zh": "情报和医疗物资已经够了；去旧传染病疗养院地下室找安娜（0419）。",
			"en": "You have enough Intel and medical supplies. Find Anna (0419) in the sanatorium basement.",
		}
	if not bool(flags.get("endgame_known", false)):
		if _lead_gate("marshalling") == "market":
			return {"zh": "去铁路黑市问伊万这趟车真正开往哪里。",
				"en": "Find Ivan at the rail market and ask where the train is really going."}
		return {
			"zh": "去西站调车场，抄下铁壳号的红章发车令。",
			"en": "Reach West Station yard and copy the Buran's red-stamped dispatch order.",
		}
	if not bool(flags.get("station_route", false)):
		return {"zh": "去布拉风货场找没有销账的交接底单，确认鹰嘴崖检修路线。",
			"en": "Find the unclosed handover copy at Buran Yard and confirm the Eagle's Crag route."}
	if not bool(flags.get("eagle_escape", false)):
		return {"zh": "沿检修路去鹰嘴崖，找到第三节车厢并带幸存者撤离。",
			"en": "Follow the maintenance route to Eagle's Crag, find Boxcar Three, and extract the survivors."}
	if not bool(flags.get("manor_tip", false)) and not bool(flags.get("truth", false)):
		return {"zh": "去铁路黑市找伊万，再到 6.66 MHz 电台棚勘踏。带着频率记录撤回后，听叶莲娜说出庄园线索。",
			"en": "Find Ivan at the rail market, then investigate the 6.66 MHz radio shed. Return with the frequency and hear Yelena's Manor lead."}
	if not bool(flags.get("truth", false)):
		return {"zh": "去松林庄园拍下焚化台账，带回 409 批腹透液和罪证。",
			"en": "Photograph the furnace ledger at Pine Manor and bring back Batch-409 fluid and evidence."}
	if not bool(flags.get("broadcast_complete", false)):
		return {"zh": "去 302 高地守住发射机，把证词和幸存者名单传遍全城。",
			"en": "Hold the transmitter at Hill 302 and broadcast the testimony and survivor list."}
	return {
		"zh": "证词已经播出。回到 602 室查看结局与母亲留下的东西。",
		"en": "The testimony is on air. Return to Room 602 to review the ending and Mother's things.",
	}

func objective_text() -> String:
	return String(objective()["zh" if lang == "zh" else "en"])

# ============================================================================
# 出战配置
# ============================================================================
func select_mate(id: String) -> void:
	if id == "none":
		mate = "none"
		return
	if bool(mates.get(id, false)):
		mate = id

func adjust_load(id: String, delta: int) -> void:
	if not load.has(id):
		return
	var cur: int = int(load[id])
	var max_n: int = int(stash.get(id, 0))
	load[id] = clampi(cur + delta, 0, max_n)

func load_total() -> int:
	var n := 0
	for k in load.keys():
		n += int(load[k])
	return n

func can_depart(L: Dictionary) -> bool:
	if L.is_empty() or night_complete:
		return false
	if not loc_unlocked(L):
		return false
	if float(node_state(String(L["id"]))["left"]) <= 0.06:
		return false
	return true

func depart(L: Dictionary) -> bool:
	if phase == "raid" or not can_depart(L):
		return false
	if String(L.get("id", "")) == "eagle_beak_cliff" and not bool(flags.get("eagle_escape", false)):
		# Remove route choices written by older builds before the boxcar is actually opened.
		flags.erase("crag_rescue_all")
		flags.erase("crag_rescue_lana")
	# 扣除携带物（与 HTML depart 一致）
	for k in load.keys():
		var n := int(load[k])
		if n > 0:
			if int(stash.get(k, 0)) < n:
				load[k] = int(stash.get(k, 0))
				n = int(load[k])
			take_item(String(k), n)
	var st: Dictionary = node_state(String(L["id"]))
	var cfg := {
		"loc": L,
		"day": day,
		"seed": int(L["seed"]) + day * 7,
		"left": float(st["left"]),
		"mate": mate if mate != "none" and bool(mates.get(mate, false)) else "",
		"pack_max": Data.BAG + (4 if mate == "anna" else 0),
		"weapon": best_weapon(),
		"weapon_mods": weapon_mods.duplicate(true),
		"load": load.duplicate(),
		"cold": float(L["cold"]),
		"danger": clampi(int(L["dg"]) + (1 if bool(flags.get("osk_alert", false)) else 0), 1, 5),
		"time": travel_minutes(L),
		"glasses": bool(flags.get("glasses", false)),
		"night": maxf(90.0, travel_minutes(L) * 2.4),
		"sound_on": sound_on,        # P2.5：战役里关过音效，节点化场景也别突然响起来
	}
	raid = RaidSimScript.new(self, cfg)
	phase = "raid"
	story_result = {}
	# 首次进入主线地点 → 播剧情
	var sid: String = String(L.get("story", ""))
	if sid != "" and not bool(story_done.get(sid, false)) \
			and (sid != "market" or bool(flags.get("lana_car3", false))):
		story_id = sid
		story_open = true
	# P1: 带 scene 字段的地点 → 常驻 sim 到 RaidBridge，切节点化夜潜场景；
	#     story_open 时先在 campaign.tscn 播完剧情，下一帧再切（见 Campaign._process）。
	var sc: String = String(L.get("scene", ""))
	if sc != "":
		# RefCounted 脚本不直接解析 autoload 全局名，动态取节点。
		var bridge := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("RaidBridge")
		if bridge:
			bridge.begin(self, cfg)
		pending_scene = sc
	return true

func cancel_departure() -> void:
	if raid == null:
		return
	for id in raid.load:
		add_item(String(id), int(raid.load[id]))
	raid = null
	pending_scene = ""
	story_open = false
	phase = "map"

# ============================================================================
# 剧情节拍
# ============================================================================
func story_of(id: String) -> Dictionary:
	if not Data.STORY.has(id):
		return {}
	return Data.STORY[id]

func story_lines(id: String) -> Array:
	var beat := story_of(id)
	if beat.is_empty():
		return []
	var lines: Array = beat.get("lines", []).duplicate(true)
	var source_id := String(Data.STORY_SOURCE_SCENES.get(id, ""))
	if source_id != "":
		var source_lines := Data.script_scene(source_id)
		if not source_lines.is_empty():
			var use_source := true
			if lang != "zh":
				# 英文模式：全量剧本必须每行都有非空 en，否则回退旧 STORY，
				# 避免 sync 重生成但忘记重新合并译文时把空字幕端给用户。
				for line in source_lines:
					if not line is Dictionary or String(line.get("en", "")).strip_edges() == "":
						use_source = false
						break
			if use_source:
				lines = source_lines
	if id == "canteen":
		# The pantry clash happens in the playable raid; pre-raid dialogue stops before the fatal swing.
		for i in lines.size():
			if String(lines[i].get("zh", "")).contains("阿列克谢猛地抽出砍骨刀"):
				lines = lines.slice(0, i)
				break
	if id == "manor":
		# The literary source also records this optional exchange. The live branch
		# uses the illustrated pages so the choice appears after the last beat.
		for i in lines.size():
			if String(lines[i].get("zh", "")).begins_with("> 叶莲娜同行时"):
				lines = lines.slice(0, i)
				break
		if mate == "yelena" and bool(mates.get("yelena", false)):
			lines.append_array(CutsceneData.story_event_slides("manor_confrontation", {"yelena_present": true}))
		else:
			lines.append_array([
				{"w": "茹科夫专员", "mood": "calm", "zh": "地下室还有几个人，名单上写的是零。桌上有一张配给凭条，也有能留下焚毁记录的底片。", "en": "There are several people in the cellar; the list calls them zero. On the desk are a ration slip and a negative that can preserve the burn record."},
				{"w": "阿列克谢", "mood": "calm", "zh": "门后还有人在敲。账本和配给都在眼前，我得先决定带走什么。", "en": "Someone is still knocking behind the door. The ledger and ration are in front of me; I have to decide what to take first."},
			])
	if id == "market":
		var ash_present := mate == "ash" and bool(mates.get("ash", false))
		var variants := []
		for line in lines:
			var zh := String(line.get("zh", ""))
			if zh.begins_with("> 灰烬同行") or zh.begins_with("> 灰烬缺席"):
				if zh.begins_with("> 灰烬同行") == ash_present:
					variants.append({
						"w": "",
						"zh": "阿列克谢挑开帘子。灰烬从他靴边冲出去，露出犬齿。药贩退到煤堆后面。" if ash_present else "阿列克谢挑开帘子，用撬棍敲响铁皮桶。烙铁落进雪泥，冒出一缕白汽。药贩退到煤堆后面。",
						"en": "Aleksei lifts the curtain. Ash rushes out from beside his boots and bares his teeth. The vendor backs behind the coal pile." if ash_present else "Aleksei lifts the curtain and strikes a tin drum with his crowbar. The iron lands in the slush. A curl of steam rises, and the vendor backs behind the coal pile."})
			elif zh != "阿列克谢挑开帘子。":
				variants.append(line)
		lines = variants
	if id == "sanitarium" and (mate != "ash" or not bool(mates.get("ash", false))):
		for i in lines.size():
			var text := String(lines[i].get("zh", ""))
			if "灰烬" in text and "鼻尖" in text:
				lines[i] = {"w": "", "zh": "阿列克谢走到床边，轻敲铁栏。姑娘抬起头，眼里的紫黑充血已经退了。",
					"en": "Aleksei comes to the bedside and taps the bars. She looks up. The purple has faded from her eyes."}
	if id == "station_buran_yard" and (mate != "ivan" or not bool(mates.get("ivan", false))):
		for i in lines.size():
			if String(lines[i].get("w", "")) == "老轨伊万":
				lines[i] = {"w": "阿列克谢", "zh": "表格只写了发车，没有写到站。交接底单还在车尾；没有销账章，就不能说车里的人已经死了。",
					"en": "The forms record the departure, not the arrival. The handover copy remains by the rear cars; without a closure stamp, nobody can say those aboard are dead."}
	if id == "market_refuge" and (String(last_report.get("mate", "")) != "ivan" \
		or not bool(last_report.get("mate_present", false))):
		for i in lines.size():
			if String(lines[i].get("w", "")) == "老轨伊万":
				lines[i] = {"w": "", "zh": "电台里断断续续传来一串调度呼号。阿列克谢把频率记进日志，没有听见熟悉的声音。",
					"en": "A broken dispatch call sign comes over the radio. Aleksei writes down the frequency and hears no familiar voice."}
	if id == "broadcast_tower_302":
		for i in lines.size():
			var speaker := String(lines[i].get("w", ""))
			if speaker == "叶莲娜" and (mate != "yelena" or not bool(mates.get("yelena", false))):
				lines[i] = {"w": "阿列克谢", "zh": "把底单和庄园照片接进播音台。证词不能只剩一串数字。",
					"en": "Feed the handover copy and Manor photographs into the board. The testimony cannot be reduced to numbers."}
			elif speaker == "帕维尔" and (mate != "pavel" or not bool(mates.get("pavel", false))):
				lines[i] = {"w": "阿列克谢", "zh": "发射机只要再响一分钟，够全城听见就够了。",
					"en": "Keep the transmitter alive for one more minute. If the city hears it, that is enough."}
	if id == "market" and not mother_alive and not bool(flags.get("market_refuge_found", false)):
		lines.append_array([
			{"w": "阿列克谢", "mood": "sad",
				"zh": "母亲走后，602 室只剩那台停下来的机器。今晚我得找到一张床，哪怕只够躲过清杀队的搜查。",
				"en": "After Mother died, all that remained in Room 602 was the silent machine. Tonight I need a bed, even one that only hides me from OSK."},
			{"w": "老轨伊万", "mood": "calm",
				"zh": "市场最里面有间废信号室，门后能睡人。先活着找到它，别问是谁把钥匙留在那儿。",
				"en": "There's an abandoned signal room at the back of the market. A person can sleep behind that door. Find it alive; don't ask who left the key."},
		])
		if mate != "ivan" or not bool(mates.get("ivan", false)):
			lines[lines.size() - 1] = {"w": "", "mood": "calm",
				"zh": "市场最里面有间废信号室，门后能睡人。钥匙留在门边，先活着找到它。",
				"en": "There is an abandoned signal room at the back of the market. A key rests by the door; find it alive."}
	if id == "marshalling":
		lines.append_array(_route_reaction_lines())
	return lines

func _route_is_ruthless() -> bool:
	return tally >= 2 or conscience <= 25.0

func _route_is_compassionate() -> bool:
	return tally == 0 and conscience >= 65.0

func _route_reaction_lines() -> Array:
	var out: Array = []
	var ruthless := _route_is_ruthless()
	var compassionate := _route_is_compassionate()
	var reactions := {
		"anna": ["安娜",
			["拉娜认得我的声音。车门一开，我先喊她。", "Lana knows my voice. When the door opens, I'll call her first."],
			["把「第三节」再念一遍。我怕一慌就记岔。", "Say 'Boxcar Three' again. I don't want to get it wrong if I panic."],
			["我跟你去找她。见了她，这一路的事你自己说。", "I'll help find her. When we do, you can tell her what happened on the way."]],
		"gulya": ["古丽娅",
			["车厢号报给我。我抄进病历，到了先看谁还能站。", "Give me the car number. I'll put it in the records and see who can stand when we get there."],
			["你去找检修线。我把干净绷带分好。", "Find the service line. I'll sort the clean bandages."],
			["药我背着。到了车门边，先让我看人。", "I'll carry the medicine. At the door, let me see the people first."]],
		"ivan": ["老轨伊万",
			["时刻我记住了。待会儿跟紧我，过道岔别打灯。", "I've got the time. Stay close, and keep your light off at the points."],
			["先核检修线，车可不等人。", "Check the service line first. The train won't wait."],
			["路我照样带。过道岔时你走前头，我得看得见你的手。", "I'll still show you the way. You go first at the points. I need to see your hands."]],
		"pavel": ["帕维尔老爹",
			["铁门要是卡死，我来扛。你腾两只手接里面的人。", "If the door jams, I'll hold it. Keep both hands free for the people inside."],
			["图递过来。先找准哪儿能下撬棍。", "Hand me the plan. Let's find where the bar can get a grip."],
			["门我照开，人我照接。出口我自己看。", "I'll open the door and help them out. I'll check the exit myself."]],
		"yelena": ["叶莲娜",
			["发车令我抄一份。你带原件，两份分开放。", "I'll copy the dispatch order. Take the original. We should keep them apart."],
			["把时刻念给我，我核一遍山线图。", "Read me the times. I'll check them against the mountain-line map."],
			["原件交给我。你记路线，别的到了再说。", "Give me the original. Remember the route. We'll talk about the rest when we get there."]],
	}
	if bool(mates.get(mate, false)) and reactions.has(mate):
		var row: Array = reactions[mate]
		var words: Array = row[3 if ruthless else (1 if compassionate else 2)]
		out.append({"w": row[0], "mood": "intense" if ruthless else "calm", "zh": words[0], "en": words[1]})
	elif mate == "ash" and bool(mates.get("ash", false)):
		out.append({"w": "", "mood": "calm",
			"zh": "灰烬把湿冷的鼻尖抵在你靴边，低低呜咽。它抬头望着调车场入口。",
			"en": "Ash presses his cold, wet nose against your boot and whines. He looks toward the yard entrance."})
	if mate == "zakhar" and bool(mates.get("zakhar", false)):
		if ruthless:
			out.append({"w": "核算员扎哈尔", "mood": "intense",
				"zh": "清杀队出一冬的煤和面粉，只买你今晚的去向。这样的单子，你当初也签过一张。",
				"en": "The OSK offered a winter's coal and flour for where you're going tonight. You signed an order like that once."})
		else:
			out.append({"w": "核算员扎哈尔", "mood": "calm",
				"zh": "只要配额还比不上活命，我就跟着你。别把这当忠诚。",
				"en": "As long as the quota is worth less than staying alive, I will follow. Do not mistake that for loyalty."})
	return out

func resolve_story(choice_index: int) -> Dictionary:
	if story_id == "" or not Data.STORY.has(story_id):
		story_open = false
		return {}
	if bool(story_done.get(story_id, false)):
		# 已经处理过的节拍不可重放（与 HTML「已看过就不再触发」一致）
		story_open = false
		return {}
	var beat: Dictionary = Data.STORY[story_id]
	var choices: Array = beat.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		story_open = false
		return {}
	if story_id == "pasha_watchtower" and choice_index == 0 and int(stash.get("asp", 0)) < 1:
		return {}
	var ch: Dictionary = choices[choice_index]
	var applied: Array[String] = []
	if story_id == "manor":
		flags.erase("manor_plan_evidence")
		flags.erase("manor_plan_trade")
		flags.erase("manor_plan_release")
	if story_id == "sanitarium":
		var medicine := rescue_medicine()
		if medicine == "":
			return {}
		if not take_item(medicine, 1):
			raid.load[medicine] = int(raid.load[medicine]) - 1
			var bridge := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("RaidBridge")
			if bridge != null and bridge.sim == self:
				bridge.cfg["load"][medicine] = raid.load[medicine]
		applied.append("−1 " + item_name(medicine))
	for op in ch.get("ops", []):
		var arr: Array = op
		if arr.is_empty():
			continue
		match String(arr[0]):
			"add":
				add_item(String(arr[1]), int(arr[2]))
				applied.append(("+%d %s" if lang == "zh" else "+%d %s") % [int(arr[2]), item_name(String(arr[1]))])
			"take":
				if take_item(String(arr[1]), int(arr[2])):
					applied.append(("-%d %s") % [int(arr[2]), item_name(String(arr[1]))])
			"conscience":
				conscience = clampf(conscience + float(arr[1]), 0.0, 100.0)
				applied.append(("良知 %+d" if lang == "zh" else "Conscience %+d") % int(arr[1]))
			"tally":
				add_tally(int(arr[1]),
					"剧情节拍：%s" % beat.get("title_zh", ""),
					"Story beat: %s" % beat.get("title_en", ""))
				applied.append("卌 %+d" % int(arr[1]))
			"flag":
				flags[String(arr[1])] = true
			"mate":
				mates[String(arr[1])] = true
				applied.append("+" + String(Data.mate(String(arr[1])).get("zh" if lang == "zh" else "en", arr[1])))
			"weapon":
				var weapon_id := String(arr[1])
				register_salvaged_weapon(weapon_id)
				if weapon_id == "mosin":
					applied.append("+莫辛纳甘步枪" if lang == "zh" else "+Mosin–Nagant rifle")
			"name":
				if not names.has(String(arr[1])):
					names.append(String(arr[1]))
				_sync_name(String(arr[1]))
				applied.append(String(arr[1]))
	var after_mate: String = String(ch.get("after_mate", ""))
	if after_mate != "" and not bool(mates.get(after_mate, false)):
		mates[after_mate] = true
		applied.append("+" + String(Data.mate(after_mate).get("zh" if lang == "zh" else "en", after_mate)))
	if story_id == FIRST_ACT_LOC and after_mate == "ash":
		select_mate("ash")
		var bridge := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("RaidBridge")
		if bridge != null and bridge.sim == self:
			bridge.cfg["mate"] = mate
	if story_id == "marshalling" and mate == "zakhar" and _route_is_ruthless() and bool(mates.get("zakhar", false)):
		flags["zakhar_betrayal_pending"] = true
	if story_id == "pasha_watchtower":
		flags["pasha_witness_seen"] = true
		if choice_index != 0:
			flags.erase("pasha_survived_to_crag")
		flags.erase("pasha_scene_pending")
	if story_id == "eagle_beak_cliff":
		flags["fire_rescue_mate"] = mate if bool(mates.get(mate, false)) else ""
		flags["fire_rescue_ash_present"] = mate == "ash" and bool(mates.get("ash", false))
		flags["fire_rescue_pending"] = true
		queue_story_slide("fire_rescue")
	story_done[story_id] = true
	flags["story_" + story_id] = true
	if story_id == FIRST_ACT_LOC and not bool(flags.get("archive_lead", false)):
		flags["vikina_clue_pending"] = true
	story_open = false
	add_log(
		String(ch.get("toast_zh", "")),
		String(ch.get("toast_en", ""))
	)
	story_result = {
		"id": story_id,
		"title": String(beat.get("title_zh" if lang == "zh" else "title_en", "")),
		"choice": String(ch.get("zh" if lang == "zh" else "en", "")),
		"applied": applied,
		"toast": String(ch.get("toast_zh" if lang == "zh" else "toast_en", "")),
	}
	_sync_logbook()
	if phase in ["base", "report"]:
		open_pending_market_refuge()
	return story_result

## 已发现且未作答就是待处理。旧档也能用这两个持久字段恢复。
func open_pending_market_refuge() -> void:
	if not story_open and bool(flags.get("market_refuge_found", false)) \
			and not bool(story_done.get("market_refuge", false)):
		story_id = "market_refuge"
		story_open = true

func close_story() -> void:
	story_open = false

# ============================================================================
# 夜潜回写（RaidSim 调用）
# ============================================================================
func raid_add_conscience(delta: float) -> void:
	conscience = clampf(conscience + delta, 0.0, 100.0)

func raid_add_tally(n: int, zh: String, en: String) -> void:
	add_tally(n, zh, en)

func raid_set_flag(flag: String) -> void:
	flags[flag] = true
	if flag == "glasses":
		pass

func add_tally(n: int, reason_zh: String, reason_en: String) -> void:
	tally = clampi(tally + n, 0, 5)
	_sync_tally(n, reason_zh, reason_en)

# ============================================================================
# 结算
# ============================================================================
func finish_raid(reason: String) -> Dictionary:
	if raid == null:
		return {}
	var r = raid
	var loc_id := String(r.loc["id"])
	var returned := reason in ["extracted", "dawn"]
	var previous_station_route := bool(flags.get("station_route", false))
	var previous_eagle_escape := bool(flags.get("eagle_escape", false))
	var previous_truth := bool(flags.get("truth", false))
	var previous_broadcast_complete := bool(flags.get("broadcast_complete", false))
	flags.erase("broadcast_pending") # 旧存档里的待播标记不跨夜使用
	if loc_id == "market" and returned and r.market_signal_found \
		and bool(flags.get("broadcast_signal", false)) and not bool(story_done.get("broadcast", false)):
		story_id = "broadcast"
		story_open = true
	if loc_id == "canteen" and returned and bool(flags.get("vasily_killed", false)):
		queue_story_slide("canteen_aftermath")
		if not bool(mates.get("pavel", false)):
			mates["pavel"] = true
			add_log("食堂回访后，机务段老钳工帕维尔答应同行。",
				"After the canteen visit, Pavel, the old depot fitter, offers to come along.")
	var kept: Array = []
	match reason:
		"downed", "abort":
			kept = []
		"dawn":
			for i in r.pack.size():
				if i % 2 == 0:
					kept.append(r.pack[i])
		_:
			kept = r.pack.duplicate()
	var archive_copy_returned: bool = loc_id == "archive" and r.archive_copy_slot >= 0 \
		and (reason == "extracted" or (reason == "dawn" and r.archive_copy_slot % 2 == 0))
	var p = r.player
	if reason == "dawn":
		p.hp = maxf(6.0, p.hp - 22.0)
	# 归还未消耗的携带物
	for k in r.load.keys():
		var n := int(r.load[k])
		if n > 0:
			add_item(String(k), n)
	var before := weapon_owned_ids()
	var gained: Dictionary = {}
	var gained_order: Array[String] = []
	for id in kept:
		var key := String(id)
		if not gained.has(key):
			gained[key] = 0
			gained_order.append(key)
		gained[key] = int(gained[key]) + 1
		add_item(key, 1)
	var after := weapon_owned_ids()
	var new_w: Array[String] = []
	for w in after:
		if not before.has(w):
			new_w.append(w)
	# 节点状态：每次踏足余量 -50%，余量下限 5%
	var loc: Dictionary = r.loc
	night_complete = true
	if returned:
		_settle_story_objective(loc_id, reason)
		if not previous_station_route and bool(flags.get("station_route", false)):
			queue_story_slide("station_route")
		if not previous_eagle_escape and bool(flags.get("eagle_escape", false)):
			queue_story_slide("eagle_escape")
		if (not previous_truth or not previous_eagle_escape) \
		and bool(flags.get("truth", false)) and bool(flags.get("eagle_escape", false)):
			queue_story_slide("evidence_handover")
		if not previous_broadcast_complete and bool(flags.get("broadcast_complete", false)):
			var broadcast_mate := String(r.mate_id)
			flags["broadcast_slide_mate"] = broadcast_mate if bool(mates.get(broadcast_mate, false)) else ""
			queue_story_slide("broadcast_complete")
	if archive_copy_returned and not bool(flags.get("archive_copy_found", false)):
		flags["archive_copy_found"] = true
		queue_story_slide("archive_copy")
	var st: Dictionary = node_state(String(loc["id"]))
	st["visits"] = int(st["visits"]) + 1
	st["left"] = clampf(float(st["left"]) - 0.5, 0.05, 1.0)
	if bool(flags.get("zakhar_betrayal_pending", false)) and bool(mates.get("zakhar", false)):
		mates["zakhar"] = false
		if mate == "zakhar":
			select_mate("none")
		flags.erase("zakhar_betrayal_pending")
		flags["zakhar_betrayed"] = true
		flags["osk_alert"] = true
		flags["betrayed"] = true
		queue_story_slide("zakhar_betrayed")
		add_log("扎哈尔把你的位置报给清杀队，换取冬季配额。他离开了队伍；清杀队已提高警戒。",
			"Zakhar reported your position to OSK for a winter ration quota and left the crew. OSK is now more alert.")
	last_report = {
		"reason": reason,
		"loc": loc,
		"gained": gained,
		"gained_order": gained_order,
		"events": r.events.duplicate(),
		"killed": r.killed,
		"half_saved": r.half_saved,
		"looted": r.looted,
		"total": r.total_cont,
		"hp": int(round(p.hp)),
		"warmth": int(round(p.warmth)),
		"new_weapons": new_w,
		"mate": String(r.mate_id),
		"mate_present": bool(mates.get(String(r.mate_id), false)),
		"day": day,
		"pack": kept.size(),
		"story": story_result.duplicate(),
	}
	var reached_market_refuge := String(loc.get("id", "")) == "market" \
		and not mother_alive and not bool(flags.get("market_refuge_found", false)) \
		and reason in ["extracted", "dawn"]
	if reached_market_refuge:
		flags["market_refuge_found"] = true
		last_report["market_refuge_found"] = true
		queue_story_slide("market_refuge")
		add_log("你在黑市废信号室找到一处临时栖身处。清杀队仍在搜查，天亮前不能久留。",
			"You find a temporary refuge in the market's abandoned signal room. OSK is still searching; you cannot stay long after dawn.")
		open_pending_market_refuge()
	if loc_id == "marshalling" and returned and not bool(story_done.get("pasha_watchtower", false)):
		flags["pasha_scene_pending"] = true
	# 天亮了/倒地后次日结算由「回到 602 室」触发
	raid = null
	phase = "report"
	story_result = {}
	_sync_logbook()
	return last_report

func _settle_story_objective(loc_id: String, reason: String) -> void:
	match loc_id:
		"station_buran_yard":
			if raid.story_objective_reached and not bool(flags.get("station_route", false)):
				flags["station_route"] = true
				_report_story_success("交接底单已抄回，鹰嘴崖检修路开放。", "The copied handover opens the Eagle's Crag maintenance route.")
		"eagle_beak_cliff":
			var rescue_scope := String(raid.crag_rescue_scope)
			if reason == "extracted" and raid.story_objective_reached \
			and rescue_scope in ["all", "lana"] and not bool(flags.get("eagle_escape", false)):
				flags.erase("crag_rescue_all")
				flags.erase("crag_rescue_lana")
				flags["crag_rescue_" + rescue_scope] = true
				flags["eagle_escape"] = true
				flags["eagle_escape_result_version"] = 2
				if rescue_scope == "lana":
					add_tally(1, "只带拉娜撤离", "Extracted only Lana")
					_report_story_success("拉娜已撤离，车厢里的人留在身后。", "Lana is safe. The others remain in the car.")
				else:
					conscience = minf(100.0, conscience + 5.0)
					_report_story_success("拉娜和能走的幸存者已撤离。", "Lana and the survivors able to walk are safe.")
		"manor":
			if reason in ["extracted", "dawn"] and raid.story_objective_reached:
				var manor_plan := "evidence"
				if bool(flags.get("manor_plan_trade", false)):
					manor_plan = "trade"
				elif bool(flags.get("manor_plan_release", false)):
					manor_plan = "release"
				var completed := false
				if manor_plan == "evidence":
					var photo_slot: int = raid.manor_photo_slot
					if photo_slot >= 0 and (reason == "extracted" or photo_slot % 2 == 0) \
					and not bool(flags.get("truth", false)):
						flags["truth"] = true
						conscience = minf(100.0, conscience + 5.0)
						_report_story_success("带回了焚化台账的照片。", "The photograph of the furnace ledger made it back.")
						completed = true
				elif manor_plan == "trade":
					var trade_slot: int = raid.manor_trade_slot
					if trade_slot == -2 or (trade_slot >= 0 and (reason == "extracted" or trade_slot % 2 == 0)):
						flags["manor_sold_semyon"] = true
						if trade_slot == -2:
							add_item("dial", 1)
						add_tally(1, "用老谢苗换取配给", "Traded old Semyon for a ration allocation")
						_report_story_success("你带着配给离开，老谢苗的位置进了茹科夫的账。", "You leave with the ration; old Semyon's location is now in Zhukov's ledger.")
						completed = true
				elif manor_plan == "release" and raid.manor_release_reached:
					flags["manor_workers_freed"] = true
					conscience = minf(100.0, conscience + 5.0)
					_report_story_success("地下室的工人沿围墙离开了庄园。", "The cellar workers escaped along the manor wall.")
					completed = true
				if completed:
					flags["manor_outcome_plan"] = manor_plan
					queue_story_slide("manor_outcome")
		"broadcast_tower_302":
			if raid.story_objective_reached and not bool(flags.get("broadcast_complete", false)):
				flags["broadcast_complete"] = true
				var broadcast_mate := String(raid.mate_id)
				flags["broadcast_slide_mate"] = broadcast_mate if bool(mates.get(broadcast_mate, false)) else ""
				if not bool(flags.get("broadcast_omit_names", false)):
					if bool(flags.get("broadcast_names", false)):
						conscience = minf(100.0, conscience + 5.0)
					_report_story_success("302 台播出了证词和幸存者名单。", "Tower 302 aired the testimony and the survivor list.")
				else:
					add_tally(1, "广播省略姓名", "Omitted names from the broadcast")
					_report_story_success("302 台播出了罪证，省略了幸存者姓名。", "Tower 302 aired the evidence and omitted the survivors' names.")

func _report_story_success(zh: String, en: String) -> void:
	raid.add_event("good", zh, en)
	add_log(zh, en)

func report_meta(reason: String) -> Dictionary:
	match reason:
		"extracted":
			return {"key": "extracted", "color": "#4ade80"}
		"dawn":
			return {"key": "dawn", "color": "#7dd3fc"}
		"downed":
			return {"key": "downed", "color": "#ef4444"}
		_:
			return {"key": "abort", "color": "#f59e0b"}

# ============================================================================
# 回到据点 / 次日
# ============================================================================
func to_base() -> void:
	phase = "base"


func queue_story_slide(event_id: String) -> void:
	if event_id == "":
		return
	var seen: Dictionary = flags.get("story_slide_seen", {})
	if bool(seen.get(event_id, false)):
		return
	var queue: Array = flags.get("story_slide_queue", [])
	if queue.has(event_id):
		return
	queue.append(event_id)
	flags["story_slide_queue"] = queue


func take_story_slide() -> String:
	var queue: Array = flags.get("story_slide_queue", [])
	if queue.is_empty():
		return ""
	var event_id := String(queue.pop_front())
	flags["story_slide_queue"] = queue
	if event_id == "fire_rescue":
		flags.erase("fire_rescue_pending")
	var seen: Dictionary = flags.get("story_slide_seen", {})
	seen[event_id] = true
	flags["story_slide_seen"] = seen
	return event_id


func has_pending_story_slides() -> bool:
	var queue: Array = flags.get("story_slide_queue", [])
	return not queue.is_empty()


func prepare_base_story_events() -> void:
	if phase != "base":
		return
	open_pending_market_refuge()
	# Reconstruct one-time beats for older saves from durable story outcomes.
	if bool(flags.get("archive_copy_found", false)):
		queue_story_slide("archive_copy")
	if bool(flags.get("station_route", false)):
		queue_story_slide("station_route")
	if bool(flags.get("eagle_escape", false)):
		queue_story_slide("eagle_escape")
	if not mother_alive:
		queue_story_slide("mother_lost")
	if bool(flags.get("truth", false)) and bool(flags.get("eagle_escape", false)):
		queue_story_slide("evidence_handover")
	if bool(flags.get("market_refuge_found", false)):
		queue_story_slide("market_refuge")
	if bool(flags.get("zakhar_betrayed", false)):
		queue_story_slide("zakhar_betrayed")
	if bool(flags.get("broadcast_complete", false)):
		queue_story_slide("broadcast_complete")
	if bool(flags.get("fire_rescue_pending", false)):
		queue_story_slide("fire_rescue")
	if story_open:
		return
	if bool(flags.get("pasha_scene_pending", false)) and not bool(story_done.get("pasha_watchtower", false)):
		story_id = "pasha_watchtower"
		story_open = true
		return
	if has_pending_story_slides():
		return
	if bool(flags.get("broadcast_complete", false)):
		finish_campaign()

func finish_campaign() -> void:
	if not flags.has("final_ending"):
		flags["final_ending"] = ending_key()
	flags["zero_scars_bonus"] = tally == 0
	finished_demo = true
	phase = "ending"

var finished_demo := false


func receive_vikina_lead() -> bool:
	if not bool(flags.get("vikina_clue_pending", false)) or bool(flags.get("archive_lead", false)):
		return false
	flags.erase("vikina_clue_pending")
	flags["archive_lead"] = true
	add_log("维京娜无意间提到，档案馆电报局留有 0420 号调度底单。阿列克谢决定今晚去找原件。",
		"Vikina casually mentions that the Archive & Telegraph Office keeps the dispatch copy for file 0420. Aleksei decides to look for the original tonight.")
	return true


func resolve_vikina_dialogue(choice_id: String) -> bool:
	if not bool(flags.get("archive_lead", false)):
		return false
	if choice_id not in ["vikina_ask", "vikina_quiet"]:
		return false
	flags["vikina_told_directly"] = choice_id == "vikina_ask"
	flags["vikina_kept_quiet"] = choice_id == "vikina_quiet"
	if choice_id == "vikina_ask":
		add_log("阿列克谢追问维京娜，她确认底单已退回档案馆；她不愿再多说。",
			"Aleksei asked Vikina directly. She confirmed the dispatch copy had gone back to the archive, then declined to say more.")
	else:
		add_log("阿列克谢没有惊动维京娜，记下了 0420 和退档线索。",
			"Aleksei left Vikina undisturbed and memorized 0420 and the archive lead.")
	return true

func advance_day() -> void:
	day += 1
	day_message = ""
	if mother_alive:
		if dial_machine_bags > 0:
			dial_machine_bags -= 1
			dial = minf(3.0, dial + 1.0)
			day_message = "你给母亲换上了新的一袋。她的呼吸平缓了一点。" if lang == "zh" \
				else "You hang a fresh bag. Her breathing eases."
		else:
			dial -= 1.0
			day_message = "透析液见底了。母亲的水肿又重了一分。" if lang == "zh" \
				else "No fluid left. The oedema climbs another notch."
			if dial <= 0.0:
				mother_alive = false
				flags["mother_lost"] = true
				queue_story_slide("mother_lost")
				conscience = clampf(conscience - 10.0, 0.0, 100.0)
				day_message = "母亲在急性肺水肿中走了。602 室已空；去铁路黑市找栖身处。" if lang == "zh" \
					else "She died of acute pulmonary oedema. Room 602 is empty; find shelter at the rail black market."
	else:
		day_message = "602 室安静得只剩风声。" if lang == "zh" \
			else "Room 602 is quiet except for the wind."
	night_complete = false
	add_log(String(day_message), String(day_message))
	phase = "base"
	_sync_logbook()

func sleep() -> void:
	if phase != "base":
		return
	advance_day()

# ============================================================================
# 日志 / 真相
# ============================================================================
func add_log(zh: String, en: String) -> void:
	if zh.strip_edges() == "" and en.strip_edges() == "":
		return
	log.append({"day": day, "zh": zh, "en": en})
	events_log.append({"day": day, "zh": zh, "en": en})
	if log.size() > 60:
		log = log.slice(log.size() - 60, log.size())

func recent_log(n: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var start := maxi(0, log.size() - n)
	for i in range(start, log.size()):
		out.append(log[i])
	return out

func tally_marks() -> String:
	if tally <= 0:
		return "—"
	var s := ""
	for i in tally:
		s += "｜"
	return s

func ending_key() -> String:
	if mother_alive and tally < 5 and bool(flags.get("truth", false)) and not bool(flags.get("betrayed", false)):
		return "TRUE_ALPHA_HELLO_LANA"
	if not bool(flags.get("truth", false)):
		return "ENDING_A_RETURN_HOME" if mother_alive else "ENDING_C_NUMBNESS"
	if tally >= 5:
		return "ENDING_B_FLAWED_LIBERATION"
	return "TRUE_BETA_OUTLAND_FIRE"

func ending_scene_context() -> Dictionary:
	var context := flags.duplicate(true)
	context["zero_scars_bonus"] = tally == 0
	return context

func ending_preview() -> Dictionary:
	var key := String(flags.get("final_ending", ending_key()))
	var texts := {
		"ENDING_A_RETURN_HOME": {
			"zh": "【结局 A · 留在 602】你回到母亲床边，决定到此为止。全城的收音机没有播出你找到的线索。",
			"en": "[ENDING A · Room 602] You return to Mother's bedside and end the search. The city's radios never air what you found."},
		"TRUE_ALPHA_HELLO_LANA": {
			"zh": "【真结局 α · 你好，拉娜】602 的灯还亮着。拉娜抬起手，敲了敲门。",
			"en": "[TRUE ENDING α · Hello, Lana] The light in Room 602 is still on. Lana raises her hand and knocks."},
		"TRUE_BETA_OUTLAND_FIRE": {
			"zh": "【真结局 β · 荒原之火】你带走了真相，却没能带回母亲；火在荒原上烧了整夜。",
			"en": "[TRUE ENDING β · Outland Fire] You carried out the truth, not your mother; the fire burned all night on the waste."},
		"ENDING_B_FLAWED_LIBERATION": {
			"zh": "【结局 B · 荒诞解放】拉娜活着走出了车厢。广播结束后，你还有话没能告诉她。",
			"en": "[ENDING B · Flawed Liberation] Lana walked out alive. After the broadcast, there are things you still haven't told her."},
		"ENDING_C_NUMBNESS": {
			"zh": "【结局 C · 麻木】你没有留下真相。第二天，诺沃斯克-17 的雪把一切都盖平了。",
			"en": "[ENDING C · Numbness] You kept no truth. By morning the snow of Novorsk-17 had levelled everything."},
		"_": {"zh": "", "en": ""},
	}
	var t: Dictionary = texts.get(key, texts["_"])
	if key == "TRUE_BETA_OUTLAND_FIRE" and mother_alive:
		t["zh"] = "【真结局 β · 荒原之火】母亲还在，真相已经播出。有人出卖了你们，拉娜陪你守着城外的火。"
		t["en"] = "[TRUE ENDING β · Outland Fire] Mother lives, and the truth is on air. Someone gave you up. Lana keeps watch by the fire outside the city."
	return {"key": key, "zh": String(t["zh"]), "en": String(t["en"])}

# ============================================================================
# LogbookManager autoload 同步（跨场景：gym / room A / campaign）
# ============================================================================
func _logbook() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var root := (loop as SceneTree).root
		if root != null:
			return root.get_node_or_null("LogbookManager")
	return null

func _sync_logbook() -> void:
	var lb := _logbook()
	if lb == null:
		return
	lb.set("tally_strokes", tally)
	lb.set("mother_alive", mother_alive)
	lb.set("ptsd_thirst_unlocked", bool(flags.get("ptsd", false)))
	if lb.has_method("record_real_name"):
		for i in names.size():
			lb.call("record_real_name", "campaign_name_%d" % i, names[i], names[i])

func _sync_tally(n: int, zh: String, en: String) -> void:
	var lb := _logbook()
	if lb != null and lb.has_method("add_tally_strokes"):
		lb.call("add_tally_strokes", n, zh, en)

func _sync_name(name: String) -> void:
	var lb := _logbook()
	if lb != null and lb.has_method("record_real_name"):
		lb.call("record_real_name", "campaign_" + name.md5_text(), name, name)
