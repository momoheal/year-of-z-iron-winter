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
		_ev_drunk_father(),
		_ev_mirror_double(),
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
# 7 个默认事件
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
			"你抄起沉重的废钢件狠命砸扁了翻卷的管口，刺耳的嘶鸣声渐渐平息，白雾终于止住了。", "You hammer the crack shut."),
		_option("patch_cloth", "撕下衣袖硬堵", "Tear your sleeve and plug", 0.6,
			[_delta("stat", "hp", -10, "冻伤", "Frostbite")],
			[_delta("crisis", "steam_leak", -1, "解除蒸汽泄漏", "Leak sealed")],
			[_delta("stat", "hp", -25, "严重烫伤", "Badly scalded")],
			"你扯下厚棉衣袖死命按在裂口上，滚烫的蒸汽一次次把破布顶开，又被你烫起水泡的双手硬生生按了回去。", "The rag holds, barely."),
		_option("ignore", "放任不管，继续走", "Leave it and move on", 1.0,
			[],
			[_delta("crisis", "steam_leak", 1, "泄漏升级", "Leak escalates"),
			 _delta("stat", "warmth", -8, "湿冷透骨", "Soaked and cold")],
			[],
			"你没有停留，任由那股救命的供暖白雾在身后的极夜里白白喷涌、消散。", "The white cloud keeps billowing."),
	]
	return _base("steam_pipe_leak", "蒸汽管破裂", "Burst Steam Pipe",
		"身旁一截生锈的市政高压蒸汽管突然崩裂，滚烫刺耳的白雾夹着铁锈味喷涌而出，一旦惊动远处的哨兵便万劫不复。",
		"A steam pipe bursts beside you, scalding white fog pouring out.",
		"night", 1.0, opts, "interrupt")

func _ev_frozen_child():
	var opts := [
		_option("give_water", "把热水壶留给她", "Leave her the hot water", 1.0,
			[_delta("item", "water", -1, "热水壶", "Hot water")],
			[_delta("stat", "sanity", 15, "心里一暖", "A flicker of warmth"),
			 _delta("flag", "child_saved", 1, "救下孩子", "Child saved")],
			[],
			"她用冻得像胡萝卜似的小手死死抱住温热的水壶，贴在心口，青紫的嘴唇上终于泛起了一丝活人的血色。", "Colour returns to her lips."),
		_option("give_rye", "分她半把黑麦", "Share some grits", 1.0,
			[_delta("item", "rye", -1, "黑麦碎粒", "Grits")],
			[_delta("stat", "sanity", 8, "稍感心安", "Some relief"),
			 _delta("flag", "child_fed", 1, "喂了孩子", "Child fed")],
			[],
			"你把粗糙的冷黑麦碎粒塞进她僵硬的手心，她连雪带米一口吞了下去，仰起脸冲你流下一行无声的泪。", "You press the grits into her hand."),
		_option("leave", "什么都不留，走开", "Leave her nothing", 1.0,
			[],
			[_delta("stat", "sanity", -20, "愧疚", "Guilt"),
			 _delta("flag", "child_abandoned", 1, "抛下孩子", "Child abandoned")],
			[],
			"你狠下心裹紧大衣快步走上台阶，身后那点微弱得像小猫一样的抽泣声，在风雪里一点点彻底冷了下去。", "The crying behind you fades."),
	]
	return _base("frozen_child", "冻僵的孩子", "The Frozen Child",
		"结满冰溜子的楼梯间死角里，一个瘦小的女孩蜷缩在水泥墙根下，冻得乌青的嘴唇只剩下一丝若有若无的白气。",
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
			"你一把扯下零件清单塞进怀里——上面用红铅笔圈着几个尚未被拆走的军工级精钢部件。", "It lists parts still unclaimed."),
		_option("take_meds", "拿走药品调拨单", "Take the medical chit", 1.0,
			[],
			[_delta("item", "abx", 1, "抗生素", "Antibiotics"),
			 _delta("item", "band", 1, "绷带", "Bandage")],
			[],
			"你抓走了盖着红印的药品调拨单——凭着这页薄纸，还能从黑市医务站里换出一批救命的盘尼西林。", "The chit trades for medicine."),
	]
	return _base("ration_choice", "调度室的两难", "The Dispatch Dilemma",
		"废弃调度室结霜的木桌上摊着两份还没来得及归档的电传底单，外头巡逻队的靴声已近，时间只够你抓走其中一份。",
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
			"道钉撬棍带着回音「哐当」一声砸烂了门闩，你在满地碎木屑里翻出了前人留下的救命存货。", "The door slams open."),
		_option("break_quiet", "慢慢拆下楔子", "Work the wedge out quietly", 0.95,
			[_delta("stat", "progress", -5, "耗费时间", "Costs time")],
			[_delta("item", "scrap", 1, "废钢件", "Scrap")],
			[_delta("stat", "progress", -10, "楔子卡死", "Wedge jams")],
			"你屏住呼吸，用撬棍扁平的尖端顺着门缝一点点拨动，没发出一丝惊动暗处的声响便退出了木楔。", "You ease the wedge out."),
		_option("abandon", "放弃这扇门", "Leave the door", 1.0,
			[],
			[_delta("stat", "sanity", -2, "错失物资", "Missed loot")],
			[],
			"你深深看了一眼门缝里的暗影，没有去惊扰那扇门后的死寂，转身继续向黑暗深处走去。", "You turn and move on."),
	]
	return _base("wedged_door", "被楔死的门", "The Wedged Door",
		"一扇厚重的铁皮木门被人从里面用木楔死死顶住，透过结霜的门缝，隐约能看见屋角散落着几罐还没开封的配给物资。",
		"A door is wedged from inside; loot is visible through the gap.",
		"night", 0.95, opts, "probability")

func _ev_half_human():
	var opts := [
		_option("lure_can", "扔空罐把它引开", "Throw a can to lure it away", 0.9,
			[_delta("item", "can", -1, "空罐", "Can")],
			[_delta("flag", "bypassed", 1, "成功引开", "Lured away")],
			[_delta("stat", "hp", -15, "它没被引开", "It stays")],
			"空铁皮罐头在远处的冰面上砸出清脆的回响，那个可怜的影子笨拙地转过身，循着响动跌跌撞撞地摸了过去。", "It follows the sound away."),
		_option("sneak_past", "屏息贴墙摸过去", "Hold your breath and slip past", 0.5,
			[],
			[_delta("flag", "bypassed", 1, "潜行成功", "Sneaked past")],
			[_delta("stat", "hp", -30, "被它扑中", "It pounces")],
			"你死死咬住冻僵的嘴唇，贴着滴水的冰冷砖墙，像一抹真正的幽灵般从他颤抖的脊背旁一寸寸挪了过去。", "You inch along the wall."),
		_option("strike_first", "挥刀先发制人", "Strike first", 0.75,
			[],
			[_delta("flag", "half_killed", 1, "放倒半人", "Cut down"),
			 _delta("stat", "sanity", -5, "下手的余悸", "Aftershock")],
			[_delta("stat", "hp", -25, "反扑", "It counterattacks"),
			 _delta("stat", "sanity", -10, "慌乱", "Panic")],
			"冰冷的铁器带着风声狠狠劈落，那阵令人心烦意乱的呜咽声戛然而止——黑暗重新归于死寂，只剩你自己的喘息。", "The blade falls; the crying stops."),
	]
	return _base("half_human_cry", "黑暗里的半人", "The Half-Human in the Dark",
		"伸手不见五指的废墟死角里，传来退化半人抱头撞墙的痛苦呜咽，他正陷在高热的神经风暴里，还没有察觉你的气息。",
		"A regressed half-human whimpers in the dark; it has not seen you.",
		"night", 0.85, opts, "crisis")

func _ev_drunk_father():
	var opts := [
		_option("replace_medicine", "用自己的抗生素换回那半瓶酒精", "Trade your own antibiotics for the bottle", 1.0,
			[_delta("item", "abx", -1, "抗生素", "Antibiotics")],
			[_delta("stat", "sanity", 8, "替孩子留住一次天亮", "One more dawn for the child"),
			 _delta("flag", "makar_child", 1, "药送回地窖", "Medicine returned")],
			[],
			"马卡尔捏着你给他的药，忽然不笑了。他把酒精推回来，像推开一具自己的尸体：「你为什么现在才来？我已经把最不要脸的话说完了……」他抱着药爬回地窖，脚步仍旧踉跄。你没有见证退烧的奇迹，只替那个孩子留住了一次尚不确定的天亮。",
			"You trade your antibiotics for the bottle. Makar crawls back to the cellar; no miracle is promised, only another uncertain dawn."),
		_option("drag_home", "夺下酒瓶，拖他回女儿身边", "Take the bottle and drag him home", 0.85,
			[],
			[_delta("stat", "sanity", 4, "没有让他独自逃走", "No solitary escape"),
			 _delta("flag", "makar_returned", 1, "父亲回到地窖", "Father returned")],
			[_delta("stat", "hp", -5, "挣扎时撞伤", "Hurt in the struggle"),
			 _delta("stat", "sanity", -2, "他仍在咒骂自己", "He still curses himself")],
			"他一边同你争夺酒瓶，一边恳求你再打得重些，仿佛疼痛是唯一不必付费的赦罪。你最终把他拖回地窖门口；他不敢进去，只隔着门听见女儿烧得说胡话，便跪在雪里号啕大哭。门没有因此变成天堂，但他至少没有再逃走。",
			"You drag him to the cellar door. He cannot enter, but he no longer runs; outside, he weeps at the sound of his daughter's fever."),
		_option("leave_makar", "让他跪在雪里，不替他裁决", "Leave him in the snow without judging him", 1.0,
			[],
			[_delta("stat", "sanity", -5, "无力回答", "No answer"),
			 _delta("flag", "makar_abandoned", 1, "离开马卡尔", "Makar left")],
			[],
			"你转身走了。身后的人还在大声咒骂自己，仿佛只要抢先把自己骂成畜生，别人的审判就再也伤不到他。你没有唾弃他，也没有原谅他；你只是忽然害怕，他那套听上去无比丑恶的账，自己在某个夜里也曾悄悄算过。",
			"You walk away without spitting or absolving. His self-hatred sounds obscene because some part of you recognises the arithmetic."),
	]
	return _base("drunk_father", "酒馆里的换药人", "The Father Who Sold the Medicine",
		"黑市篝火旁，前市立中学语文教师马卡尔当着众人的面，把古丽娅给他女儿退烧的两粒阿司匹林换成半瓶掺水工业酒精，仰头灌下，又跪在雪泥里揪着头发狂笑：「来啊，往我脸上吐唾沫！我是个吃女儿肉的畜生！可她熬过四天又能怎样？醒过来还是要被塞进铁壳号！我喝掉这两粒药，是因为我连看她清醒着被烧死的勇气都没有！阿列克谢，你撬得开铁门，撬得开人心里这口棺材吗？！」地窖里，他的女儿仍在四十度高烧中喊冷；他越把这句话喊得响亮，越像是在等谁替他把最后一丝做人的资格也拿走。",
		"At the market fire, former schoolteacher Makar trades the two aspirin meant for his feverish daughter for diluted industrial alcohol. He begs the crowd to spit on him: even if she survives, the Buran will take her. His self-abasement is both confession and refuge.",
		"night", 0.8, opts, "confession")

func _ev_mirror_double():
	var opts := [
		_option("defy_double", "回答：拉娜不是一行油墨", "Answer: Lana is not a line of ink", 1.0,
			[],
			[_delta("stat", "sanity", 8, "拒绝体面的赦免", "Refuse respectable absolution"),
			 _delta("stat", "hp", -3, "击碎玻璃的伤", "Cut by the mirror"),
			 _delta("flag", "double_defied", 1, "拒绝白昼自我", "Double defied")],
			[],
			"你一拳砸向那张温和的笑脸。镜子裂开，每一片里却仍坐着一个戴蓝袖章的你；血流进掌纹时，他们齐声纠正：「是 0420。」你疼得发抖，却第一次敢直视那些碎片：「不。她先是我妹妹，然后才是你们的一行字。」白昼的幻象消失了，冻疮和罪却一样也没有少。",
			"You strike the mirror. Every fragment answers \"0420,\" but you insist she was your sister before she was their ink. The vision vanishes; your wounds and guilt remain."),
		_option("accept_double", "承认：我只想做个合乎规矩的庸人", "Admit: I only want to be ordinary and obedient", 1.0,
			[],
			[_delta("stat", "sanity", 3, "暂时不必再争辩", "A temporary truce"),
			 _delta("flag", "double_accepted", 1, "接受白昼逻辑", "Double accepted")],
			[],
			"镜中的人满意地点头，把一张二等核算主任的任命书贴在玻璃另一侧。可你伸手去接时，摸到的仍是自己冰凉的指尖。没有两箱腹透液，没有暖房，也没有谁真来赦免你；只有你终于承认，所谓庸人的幸福，有时不过是不再追问别人被运去了哪里。",
			"You accept his respectable appointment and find only your own cold fingertips. The comfort is real for one moment: the comfort of no longer asking where the trains go."),
		_option("beg_double", "跪下，求那个体面的自己替你决定", "Kneel and let your respectable self decide", 1.0,
			[],
			[_delta("stat", "sanity", -6, "把判断交给幻影", "Surrender judgement"),
			 _delta("flag", "double_begged", 1, "向幻影求助", "Begged the double")],
			[],
			"你跪下来，求他告诉你究竟怎样才算无罪。蓝袖章的幻影俯身扶你，动作温柔得像一位兄长：「你看，阿廖沙，连你的反抗也需要我批准。只要你还只想证明自己是个好人，你就永远是我的。」你猛然抬头，镜前却只剩一个人跪着，分不清刚才被扶起的是身体，还是最后一点抵抗。",
			"You beg him for innocence. He gently replies that even your rebellion needs his approval so long as you only wish to prove yourself good. When you look up, only one man is kneeling."),
	]
	return _base("mirror_double", "锅炉房镜子里的核算员", "The Clerk in the Boiler-Room Mirror",
		"午夜一点，你刚在《双面工作日志》背面划下一道血痕，锅炉房结霜的破镜里便走出另一个阿列克谢：蓝袖章、雪亮眼镜、体面铁路制服，连指甲缝也没有煤灰。他坐上蒸汽管，温和得像来探病的旧友：「阿廖沙，何必呢？拉娜已经是一行 0420 的油墨，你救不出墨水。把古丽娅那三页废纸交给督察官吧，你能换两箱瑞士 409 批腹透液，还能升任二等核算主任。妈能多活三年，你也能睡在有暖气的屋子里——做个合乎规矩的庸人有什么错？为什么非要当个满手冻疮的圣徒？」他没有辱骂你，也没有撒谎；正因如此，你才想立刻杀死他。",
		"At 01:00 a blue-armbanded Aleksei steps from the frosted boiler-room mirror: clean uniform, bright glasses, no soot beneath his nails. Trade Gulya's pages for dialysis fluid and promotion, he says; Lana is already ink. His gentleness is worse than mockery because none of his arithmetic is false.",
		"night", 0.75, opts, "double")
