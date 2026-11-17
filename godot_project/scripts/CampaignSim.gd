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
			if not weapon_owned(Data.weapon(parts[1])):
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
		return "%s %s" % [String(w.get("ic", "⚙")), String(w.get("zh" if lang == "zh" else "en", parts[1]))]
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

func loc_unlocked(L: Dictionary) -> bool:
	if first_act_pending() and String(L.get("id", "")) != FIRST_ACT_LOC:
		return false
	if String(L.get("id", "")) == "sanitarium" and bool(story_done.get(FIRST_ACT_LOC, false)) \
			and not bool(flags.get("archive_lead", false)) and not bool(flags.get("lana_car3", false)):
		return false
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
	if first_act_pending() and String(L.get("id", "")) != FIRST_ACT_LOC:
		return "先完成第一幕：四号铁路冷库" if lang == "zh" else "Finish Act I at Rail Cold Storage No.4 first"
	if String(L.get("id", "")) == "sanitarium" and bool(story_done.get(FIRST_ACT_LOC, false)) \
			and not bool(flags.get("archive_lead", false)) and not bool(flags.get("lana_car3", false)):
		return "需要：先听维京娜提到的档案馆线索" if lang == "zh" else "Requires: follow Vikina's archive lead first"
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

# ============================================================================
# 目标
# ============================================================================
func objective() -> Dictionary:
	if not bool(story_done.get(FIRST_ACT_LOC, false)) and names.is_empty():
		return {
			"zh": "去城北四号铁路冷库领今天的征召工物资——顺便查查拉娜被带上了哪趟车。",
			"en": "Report to Cold Storage No.4 for conscript labour — and find out which train took Lana.",
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
		if intel_count() < 2 or med_count() < 1:
			return {
				"zh": "按维京娜提到的线索去档案馆电报局找调度底单；凑够情报 ×2 和医疗物资 ×1，再去疗养院找安娜（0419）。",
				"en": "Follow Vikina's lead to the Archive & Telegraph Office for dispatch records. Gather 2 Intel and 1 medical item, then find Anna (0419) at the sanatorium.",
			}
		return {
			"zh": "情报和医疗物资已经够了；去旧传染病疗养院地下室找安娜（0419）。",
			"en": "You have enough Intel and medical supplies. Find Anna (0419) in the sanatorium basement.",
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
	if sid != "" and not bool(story_done.get(sid, false)):
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
	if lang == "zh":
		var source_id := String(Data.STORY_SOURCE_SCENES.get(id, ""))
		if source_id != "":
			var source_lines := Data.script_scene(source_id)
			if not source_lines.is_empty():
				lines = source_lines
	if id == "market" and not mother_alive and not bool(flags.get("market_refuge_found", false)):
		lines.append_array([
			{"w": "阿列克谢", "mood": "sad",
				"zh": "母亲走后，602 室只剩那台停下来的机器。今晚我得找到一张床，哪怕只够躲过清杀队的搜查。",
				"en": "After Mother died, all that remained in Room 602 was the silent machine. Tonight I need a bed, even one that only hides me from OSK."},
			{"w": "老轨伊万", "mood": "calm",
				"zh": "市场最里面有间废信号室，门后能睡人。先活着找到它，别问是谁把钥匙留在那儿。",
				"en": "There's an abandoned signal room at the back of the market. A person can sleep behind that door. Find it alive; don't ask who left the key."},
		])
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
		"ash": ["灰烬", "灰烬贴着你的靴边低低呜咽，项圈下那圈旧伤被炉火照得发白。", "Ash presses against your boot and whines softly. The old ring of scar tissue pales in the furnace light."],
		"anna": ["安娜", "安娜", "Anna"],
		"gulya": ["古丽娅", "古丽娅", "Gulya"],
		"ivan": ["老轨伊万", "伊万", "Old Ivan"],
		"pavel": ["帕维尔老爹", "帕维尔", "Pavel"],
		"yelena": ["叶莲娜", "叶莲娜", "Yelena"],
	}
	for id in reactions:
		if not bool(mates.get(id, false)):
			continue
		var row: Array = reactions[id]
		var zh := String(row[1])
		var en := String(row[2])
		if id == "ash":
			out.append({"w": row[0], "mood": "sad" if ruthless else "calm", "zh": zh, "en": en})
			continue
		if ruthless:
			zh = "%s看着你，仍记得你救过车厢里的人；可你一路把其他人当成东西，他/她不会再把后背交给你。" % String(row[1])
			en = "%s remembers that you saved the boxcar, but will not trust you with their back after the people you treated as things." % String(row[2])
		elif compassionate:
			zh = "%s把手搭上你的肩。你一路留下的名字和救过的人，让他/她愿意与你一起守住广播。" % String(row[1])
			en = "%s rests a hand on your shoulder. The names you kept and lives you saved make them ready to defend the broadcast with you." % String(row[2])
		else:
			zh = "%s没有靠近也没有离开，只说：先把这一夜撑过去，之后再谈信任。" % String(row[1])
			en = "%s neither comes closer nor leaves. " + String(row[2]) + " says: survive this night first; we can speak of trust later."
		out.append({"w": row[0], "mood": "intense" if ruthless else ("sad" if not compassionate else "calm"), "zh": zh, "en": en})
	if bool(mates.get("zakhar", false)):
		if ruthless:
			out.append({"w": "核算员扎哈尔", "mood": "intense",
				"zh": "清杀队答应给我冬季配额。你把我带到这里，我就把你的坐标报给他们。",
				"en": "OSK offered me a winter ration quota. You brought me here; I will give them your position."})
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
	if story_id == FIRST_ACT_LOC and after_mate == "ash":
		select_mate("ash")
		var bridge := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("RaidBridge")
		if bridge != null and bridge.sim == self:
			bridge.cfg["mate"] = mate
	if story_id == "marshalling" and _route_is_ruthless() and bool(mates.get("zakhar", false)):
		flags["zakhar_betrayal_pending"] = true
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
	if story_id != "market_refuge" and bool(flags.get("market_refuge_story_pending", false)):
		flags.erase("market_refuge_story_pending")
		story_id = "market_refuge"
		story_open = true
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
	if bool(flags.get("broadcast_pending", false)) and bool(flags.get("broadcast_signal", false)) \
		and not bool(story_done.get("broadcast", false)) \
		and reason != "downed" and reason != "abort":
		story_id = "broadcast"
		story_open = true
		flags.erase("broadcast_pending")
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
	night_complete = true
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
		add_log("你在黑市废信号室找到一处临时栖身处。清杀队仍在搜查，天亮前不能久留。",
			"You find a temporary refuge in the market's abandoned signal room. OSK is still searching; you cannot stay long after dawn.")
		if not bool(story_done.get("market_refuge", false)):
			if story_open:
				flags["market_refuge_story_pending"] = true
			else:
				story_id = "market_refuge"
				story_open = true
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


func receive_vikina_lead() -> bool:
	if not bool(flags.get("vikina_clue_pending", false)) or bool(flags.get("archive_lead", false)):
		return false
	flags.erase("vikina_clue_pending")
	flags["archive_lead"] = true
	add_log("维京娜无意间提到，档案馆电报局留有 0420 号调度底单。阿列克谢决定今晚去找原件。",
		"Vikina casually mentions that the Archive & Telegraph Office keeps the dispatch copy for file 0420. Aleksei decides to look for the original tonight.")
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
	if key != "ENDING_C_NUMBNESS":
		t["zh"] = String(t["zh"]) + "\n\n" + Data.PASHA_EPILOGUE_ZH
		t["en"] = String(t["en"]) + "\n\n" + Data.PASHA_EPILOGUE_EN
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
