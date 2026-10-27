extends SceneTree
## seed_events.gd — 一次性内容播种工具（headless）。
##
## 用 ResourceSaver 生成 data/events/*.tres，保证 .tres 格式标准、
## 可在编辑器检视器里直接编辑。生成后这些 .tres 才是真正的数据源，
## 本脚本只是「重建默认事件」的工具，不参与运行时。
##
## Run:
##   Godot --headless --path godot_project -s tools/seed_events.gd

const EventDataScript := preload("res://scripts/data/EventData.gd")
const EventOptionScript := preload("res://scripts/data/EventOptionData.gd")
const DeltaScript := preload("res://scripts/data/DeltaData.gd")

const OUT_DIR := "res://data/events/"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var events: Array = [
		_ev_steam_leak(),
		_ev_frozen_child(),
		_ev_ration_choice(),
		_ev_wedged_door(),
		_ev_half_human(),
	]
	var saved := 0
	for ev in events:
		var path: String = OUT_DIR + ev.id + ".tres"
		var err := ResourceSaver.save(ev, path)
		if err != OK:
			print("FAILED to save ", path, " err=", err)
		else:
			print("saved ", path)
			saved += 1
	print("SEED_EVENTS_DONE saved=", saved)
	quit(0 if saved == events.size() else 1)

# ---------------------------------------------------------------------------
# 工厂辅助
# ---------------------------------------------------------------------------
func _delta(target: String, key: String, amount: int, zh: String = "", en: String = ""):
	var d = DeltaScript.new()
	d.target = target
	d.key = key
	d.amount = amount
	d.label_zh = zh
	d.label_en = en
	return d

func _deltas(arr: Array) -> Array[DeltaData]:
	var out: Array[DeltaData] = []
	for d in arr:
		out.append(d)
	return out

func _option(id: String, zh: String, en: String, chance: float,
		costs: Array, succ: Array, fail: Array, rzh: String = "", ren: String = ""):
	var o = EventOptionScript.new()
	o.id = id
	o.label_zh = zh
	o.label_en = en
	o.success_chance = chance
	o.costs = _deltas(costs)
	o.on_success = _deltas(succ)
	o.on_failure = _deltas(fail)
	o.result_text_zh = rzh
	o.result_text_en = ren
	return o

func _base(id: String, tzh: String, ten: String, dzh: String, den: String,
		phase: String, chance: float, options: Array, art_tag: String = ""):
	var ev = EventDataScript.new()
	ev.id = id
	ev.title_zh = tzh
	ev.title_en = ten
	ev.desc_zh = dzh
	ev.desc_en = den
	ev.phase = phase
	ev.trigger_chance = chance
	var t_opts: Array[EventOptionData] = []
	for op in options:
		t_opts.append(op)
	ev.options = t_opts
	ev.art_tag = art_tag
	return ev

# ---------------------------------------------------------------------------
# 5 个测试事件
# ---------------------------------------------------------------------------
func _ev_steam_leak():
	# 打断型：不立刻堵上就持续掉体温
	var opts := [
		_option("patch_scrap", "用废钢件临时封堵", "Patch with scrap steel", 0.8,
			[_delta("item", "scrap", -1, "废钢件", "Scrap")],
			[_delta("crisis", "steam_leak", -1, "解除蒸汽泄漏", "Leak sealed"),
			 _delta("stat", "warmth", 10, "蒸汽暖意", "Warmth from steam")],
			[_delta("stat", "hp", -15, "蒸汽烫伤", "Scalded"),
			 _delta("crisis", "steam_leak", 1, "泄漏加剧", "Leak worsens")],
			"你把裂口砸扁，白雾慢慢止住。", "You hammer the crack shut."),
		_option("patch_cloth", "撕下衣袖硬堵", "Tear your sleeve and plug", 0.6,
			[_delta("stat", "hp", -10, "冻伤", "Frostbite")],
			[_delta("crisis", "steam_leak", -1, "解除蒸汽泄漏", "Leak sealed")],
			[_delta("stat", "hp", -25, "严重烫伤", "Badly scalded")],
			"破布被蒸汽顶开，又被你死命按了回去。", "The rag holds, barely."),
		_option("ignore", "放任不管，继续走", "Leave it and move on", 1.0,
			[],
			[_delta("crisis", "steam_leak", 1, "泄漏升级", "Leak escalates"),
			 _delta("stat", "warmth", -8, "湿冷透骨", "Soaked and cold")],
			[],
			"白雾在身后继续喷涌。", "The white cloud keeps billowing."),
	]
	return _base("steam_pipe_leak", "蒸汽管破裂", "Burst Steam Pipe",
		"身旁一截蒸汽管突然爆裂，滚烫的白雾喷涌而出，必须立刻处理。",
		"A steam pipe bursts beside you, scalding white fog pouring out.",
		"night", 1.0, opts, "interrupt")

func _ev_frozen_child():
	var opts := [
		_option("give_water", "把热水壶留给她", "Leave her the hot water", 1.0,
			[_delta("item", "water", -1, "热水壶", "Hot water")],
			[_delta("stat", "sanity", 15, "心里一暖", "A flicker of warmth"),
			 _delta("flag", "child_saved", 1, "救下孩子", "Child saved")],
			[],
			"她捧着水壶，嘴唇终于有了一点颜色。", "Colour returns to her lips."),
		_option("give_rye", "分她半把黑麦", "Share some grits", 1.0,
			[_delta("item", "rye", -1, "黑麦碎粒", "Grits")],
			[_delta("stat", "sanity", 8, "稍感心安", "Some relief"),
			 _delta("flag", "child_fed", 1, "喂了孩子", "Child fed")],
			[],
			"你把碎粒塞进她冻僵的手心。", "You press the grits into her hand."),
		_option("leave", "什么都不留，走开", "Leave her nothing", 1.0,
			[],
			[_delta("stat", "sanity", -20, "愧疚", "Guilt"),
			 _delta("flag", "child_abandoned", 1, "抛下孩子", "Child abandoned")],
			[],
			"你听见身后的哭声一点点弱下去。", "The crying behind you fades."),
	]
	return _base("frozen_child", "冻僵的孩子", "The Frozen Child",
		"楼梯间里，一个孩子蜷在墙角，冻得只剩一口气。",
		"A child huddles in the stairwell, barely breathing from the cold.",
		"night", 0.9, opts, "moral")

func _ev_ration_choice():
	# 零和：只能二选一
	var opts := [
		_option("take_parts", "拿走焚化炉零件清单", "Take the furnace parts list", 1.0,
			[],
			[_delta("item", "intel", 1, "调度单", "Intel"),
			 _delta("stat", "progress", 10, "推进进度", "Progress")],
			[],
			"清单上标着几个还没被拆走的部件。", "It lists parts still unclaimed."),
		_option("take_meds", "拿走药品调拨单", "Take the medical chit", 1.0,
			[],
			[_delta("item", "abx", 1, "抗生素", "Antibiotics"),
			 _delta("item", "band", 1, "绷带", "Bandage")],
			[],
			"调拨单能在医务站换出一批药。", "The chit trades for medicine."),
	]
	return _base("ration_choice", "调度室的两难", "The Dispatch Dilemma",
		"调度室桌上摊着两份底单，时间只够你带走一份。",
		"Two slips lie on the desk; you have time to take only one.",
		"night", 1.0, opts, "zero_sum")

func _ev_wedged_door():
	var opts := [
		_option("break_force", "用撬棍暴力破门", "Force it with the crowbar", 0.7,
			[],
			[_delta("item", "scrap", 2, "废钢件", "Scrap"),
			 _delta("item", "kero", 1, "煤油", "Kerosene")],
			[_delta("stat", "hp", -20, "引来袭击", "Draws an attack"),
			 _delta("flag", "door_loud", 1, "破门巨响", "Loud break")],
			"门哐当一声被砸开，里面还有些存货。", "The door slams open."),
		_option("break_quiet", "慢慢拆下楔子", "Work the wedge out quietly", 0.95,
			[_delta("stat", "progress", -5, "耗费时间", "Costs time")],
			[_delta("item", "scrap", 1, "废钢件", "Scrap")],
			[_delta("stat", "progress", -10, "楔子卡死", "Wedge jams")],
			"你一点点把楔子退了出来。", "You ease the wedge out."),
		_option("abandon", "放弃这扇门", "Leave the door", 1.0,
			[],
			[_delta("stat", "sanity", -2, "错失物资", "Missed loot")],
			[],
			"你转身继续往深处走。", "You turn and move on."),
	]
	return _base("wedged_door", "被楔死的门", "The Wedged Door",
		"一扇门被人从里面楔死，门缝里隐约能看见物资。",
		"A door is wedged from inside; loot is visible through the gap.",
		"night", 0.95, opts, "probability")

func _ev_half_human():
	var opts := [
		_option("lure_can", "扔空罐把它引开", "Throw a can to lure it away", 0.9,
			[_delta("item", "can", -1, "空罐", "Can")],
			[_delta("flag", "bypassed", 1, "成功引开", "Lured away")],
			[_delta("stat", "hp", -15, "它没被引开", "It stays")],
			"罐头砸向远处，它循着声音摸了过去。", "It follows the sound away."),
		_option("sneak_past", "屏息贴墙摸过去", "Hold your breath and slip past", 0.5,
			[],
			[_delta("flag", "bypassed", 1, "潜行成功", "Sneaked past")],
			[_delta("stat", "hp", -30, "被它扑中", "It pounces")],
			"你贴着墙根，一寸寸挪了过去。", "You inch along the wall."),
		_option("strike_first", "挥刀先发制人", "Strike first", 0.75,
			[],
			[_delta("flag", "half_killed", 1, "放倒半人", "Cut down"),
			 _delta("stat", "sanity", -5, "下手的余悸", "Aftershock")],
			[_delta("stat", "hp", -25, "反扑", "It counterattacks"),
			 _delta("stat", "sanity", -10, "慌乱", "Panic")],
			"刀落下去，哭声戛然而止。", "The blade falls; the crying stops."),
	]
	return _base("half_human_cry", "黑暗里的半人", "The Half-Human in the Dark",
		"黑暗中传来退化半人的呜咽，它还没有发现你。",
		"A regressed half-human whimpers in the dark; it has not seen you.",
		"night", 0.85, opts, "crisis")
