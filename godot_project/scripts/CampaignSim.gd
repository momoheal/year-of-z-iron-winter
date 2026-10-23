extends RefCounted
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

# ---------------- 战役状态 ----------------
var day: int = 1
var mother_alive := true
var dial: float = 2.0            # 剩余腹透液（天）
var conscience: float = 50.0
var tally: int = 0
var stash: Dictionary = {}
var mates: Dictionary = {}
var flags: Dictionary = {}
var names: Array[String] = []
var story_done: Dictionary = {}
var nodes: Dictionary = {}
var log: Array[Dictionary] = []

var mate: String = "none"
var load: Dictionary = {"can": 0, "water": 0, "asp": 0, "band": 0}
var last_report: Dictionary = {}

# ---------------- 阶段 / UI 状态 ----------------
var lang: String = "zh"
var phase: String = "title"      # title | base | map | raid | report | ending
var selected_loc: String = ""
var raid = null                  # RaidSim 实例（仅 raid 阶段非空）
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
	flags = {}
	names = []
	story_done = {}
	nodes = {}
	log = []
	mate = "none"
	load = {"can": 0, "water": 0, "asp": 0, "band": 0}
	last_report = {}
	phase = "title"
	selected_loc = ""
	raid = null
	story_open = false
	story_id = ""
	story_result = {}
	logbook_open = false
	help_open = false
	abort_confirm = false
	day_message = ""
	events_log = []
	stash = {"rye": 3, "can": 2, "water": 1, "band": 1, "scrap": 2}
	mates = {"ash": false, "anna": false, "gulya": false, "pavel": false, "ivan": false}
	for l in Data.LOCS:
		nodes[l["id"]] = {"visits": 0, "left": 1.0, "hint": 0}
	add_log("进入 602 室。母亲在透析机旁睡着了。",
		"Entered Room 602. Mother is asleep beside the dialysis machine.")
	_sync_logbook()

# ============================================================================
# 文本 / 物品
# ============================================================================
func tr(key: String, args: Array = []) -> String:
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
	if int(stash.get(id, 0)) < n:
		return false
	stash[id] = int(stash[id]) - n
	if int(stash[id]) <= 0:
		stash.erase(id)
	return true

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

func loc_unlocked(L: Dictionary) -> bool:
	var rf: String = String(L.get("req_flag", ""))
	if rf != "" and not bool(flags.get(rf, false)):
		return false
	var req: Dictionary = L.get("req", {})
	if req.has("intel") and intel_count() < int(req["intel"]):
		return false
	if req.has("med") and med_count() < int(req["med"]):
		return false
	return true

func lock_reason(L: Dictionary) -> String:
	var rf: String = String(L.get("req_flag", ""))
	if rf == "manor_tip":
		return "需要：黑市或安娜给出的松林庄园线索" if lang == "zh" \
			else "Requires: the Pine Manor lead from the market or Anna"
	if rf == "lana_car3":
		return "需要：先确认妹妹在第三节车厢（救援安娜）" if lang == "zh" \
			else "Requires: confirm Lana is in Boxcar 3 (rescue Anna)"
	var req: Dictionary = L.get("req", {})
	var parts: Array[String] = []
	if req.has("intel"):
		parts.append(("情报 ×%d" if lang == "zh" else "Intel ×%d") % int(req["intel"]))
	if req.has("med"):
		parts.append(("医疗 ×%d" if lang == "zh" else "Medical ×%d") % int(req["med"]))
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
	return weapon_parts(w) >= (w.get("parts", []) as Array).size()

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

# ============================================================================
# 目标
# ============================================================================
func objective() -> Dictionary:
	if names.is_empty():
		return {
			"zh": "去城北四号铁路冷库领今天的征召工物资——顺便查查拉娜被带上了哪趟车。",
			"en": "Report to Cold Storage No.4 for conscript labour — and find out which train took Lana.",
		}
	if not bool(flags.get("lana_car3", false)):
		return {
			"zh": "凑够情报（调度单 ×2）和一份医疗物资，去旧传染病疗养院地下室找安娜（0419）。",
			"en": "Gather 2 Intel and 1 medical item, then find Anna (0419) in the sanatorium basement.",
		}
	if not bool(flags.get("endgame_known", false)):
		return {
			"zh": "去西站调车场，抄下今晚 23:00 铁壳号的发车令。",
			"en": "Reach West Station yard and copy tonight's 23:00 Buran dispatch order.",
		}
	return {
		"zh": "去松林庄园二号库，拍下焚化炉，把 409 批腹透液带回来。",
		"en": "Infiltrate Pine Manor Depot No.2: photograph the furnace, bring back Batch-409 fluid.",
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
	if L.is_empty():
		return false
	if not loc_unlocked(L):
		return false
	if float(node_state(String(L["id"]))["left"]) <= 0.06:
		return false
	return true

func depart(L: Dictionary) -> bool:
	if not can_depart(L):
		return false
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
		"load": load.duplicate(),
		"cold": float(L["cold"]),
		"danger": int(L["dg"]),
		"time": travel_minutes(L),
		"glasses": bool(flags.get("glasses", false)),
		"night": maxf(90.0, travel_minutes(L) * 2.4),
	}
	raid = RaidSimScript.new(self, cfg)
	phase = "raid"
	story_result = {}
	# 首次进入主线地点 → 播剧情
	var sid: String = String(L.get("story", ""))
	if sid != "" and not bool(story_done.get(sid, false)):
		story_id = sid
		story_open = true
	return true

# ============================================================================
# 剧情节拍
# ============================================================================
func story_of(id: String) -> Dictionary:
	if not Data.STORY.has(id):
		return {}
	return Data.STORY[id]

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
	var ch: Dictionary = choices[choice_index]
	var applied: Array[String] = []
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
			"name":
				if not names.has(String(arr[1])):
					names.append(String(arr[1]))
				_sync_name(String(arr[1]))
				applied.append(String(arr[1]))
	var after_mate: String = String(ch.get("after_mate", ""))
	if after_mate != "" and not bool(mates.get(after_mate, false)):
		mates[after_mate] = true
		applied.append("+" + String(Data.mate(after_mate).get("zh" if lang == "zh" else "en", after_mate)))
	story_done[story_id] = true
	flags["story_" + story_id] = true
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
	return story_result

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
	var st: Dictionary = node_state(String(loc["id"]))
	st["visits"] = int(st["visits"]) + 1
	st["left"] = clampf(float(st["left"]) - 0.5, 0.05, 1.0)
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
		"day": day,
		"pack": kept.size(),
		"story": story_result.duplicate(),
	}
	# 天亮了/倒地后次日结算由「回到 602 室」触发
	raid = null
	phase = "report"
	story_result = {}
	_sync_logbook()
	return last_report

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
	if bool(flags.get("endgame_known", false)) and bool(flags.get("truth", false)):
		finished_demo = true

var finished_demo := false

func advance_day() -> void:
	day += 1
	day_message = ""
	if mother_alive:
		if int(stash.get("dial", 0)) > 0:
			take_item("dial", 1)
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
				conscience = clampf(conscience - 10.0, 0.0, 100.0)
				day_message = "母亲在急性肺水肿中走了。失母·荒原线开启。" if lang == "zh" \
					else "She died of acute pulmonary oedema. The motherless route opens."
	else:
		day_message = "602 室安静得只剩风声。" if lang == "zh" \
			else "Room 602 is quiet except for the wind."
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
	if mother_alive and tally == 0 and bool(flags.get("truth", false)) and not bool(flags.get("betrayed", false)):
		return "TRUE_ALPHA_HELLO_LANA"
	if not bool(flags.get("truth", false)):
		return "ENDING_C_NUMBNESS"
	if tally > 0:
		return "ENDING_B_FLAWED_LIBERATION"
	return "TRUE_BETA_OUTLAND_FIRE"

func ending_preview() -> Dictionary:
	var key := ending_key()
	var texts := {
		"TRUE_ALPHA_HELLO_LANA": {
			"zh": "【真结局 α · 你好，拉娜】零划痕、母亲存活、真相在手——鹰嘴崖的第三节车厢门被撬开。",
			"en": "[TRUE ENDING α · Hello, Lana] Zero strokes, mother alive, the truth in hand — Boxcar 3 opens at Eagle's Crag."},
		"TRUE_BETA_OUTLAND_FIRE": {
			"zh": "【真结局 β · 荒原之火】你带走了真相，却没能带回母亲；火在荒原上烧了整夜。",
			"en": "[TRUE ENDING β · Outland Fire] You carried out the truth, not your mother; the fire burned all night on the waste."},
		"ENDING_B_FLAWED_LIBERATION": {
			"zh": "【结局 B · 荒诞解放】车厢门开了，但《工作日志》背面的划痕让拉娜认不出你。",
			"en": "[ENDING B · Flawed Liberation] The car opens, but the strokes on your logbook's back page mean Lana does not recognise you."},
		"ENDING_C_NUMBNESS": {
			"zh": "【结局 C · 麻木】你没有留下真相。第二天，诺沃斯克-17 的雪把一切都盖平了。",
			"en": "[ENDING C · Numbness] You kept no truth. By morning the snow of Novorsk-17 had levelled everything."},
		"_": {"zh": "", "en": ""},
	}
	var t: Dictionary = texts.get(key, texts["_"])
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
