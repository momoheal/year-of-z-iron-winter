extends RefCounted
## CampaignData.gd — 《Z年纪事：凛冬铁轨》探索循环 DEMO 的静态数据层。
##
## 1:1 对应 prototypes/Year_of_Z_Iron_Winter_Exploration_Demo.html 的：
##   CFG / ITEMS / WEAPONS / MATES / LOCS / STORY / STR
## 全部为 const 数据；CampaignSim 只读，CampaignHUD 只读，RaidGen 只读。
## 多语言：每个条目同时携带 zh / en，由 CampaignSim.lang 决定取哪一份。

# ============================================================================
# CFG — 与 HTML 的 CFG 一致
# ============================================================================
const MAP_W := 64
const MAP_H := 48
const TILE := 1.0                 # 1 格 = 1 逻辑米
const PPM := 26.0                 # 每逻辑米像素（DEMO 用 26，世界缩放到 1920x1080 视口）
const SQUASH := 0.62              # 75° 斜俯视的 y 轴压缩
const WALL_H := 0.62
const FOV_DEG := 90.0
const SIGHT := 12.0
const SIGHT_CRACKED := 7.2

## 战斗浮字在标点或空格附近换行；保留完整文本，不截断文学扩写后的句子。
static func wrap_float_text(txt: String, limit: int = 32) -> String:
	if txt.length() <= limit:
		return txt
	var rows: Array[String] = []
	var line := ""
	var soft_breaks := "，。！？；：…,.!?; "
	for ch in txt:
		line += ch
		if line.length() >= limit and (soft_breaks.contains(ch) or line.length() >= limit + 6):
			rows.append(line.strip_edges())
			line = ""
	if not line.is_empty():
		rows.append(line.strip_edges())
	# 句子只在末尾出现标点时，柔性分行可能仍得到一整行；按上限硬切兜底。
	if rows.size() <= 1 and txt.length() > limit:
		rows.clear()
		for start in range(0, txt.length(), limit):
			rows.append(txt.substr(start, limit))
	return "\n".join(rows)
const NEAR_SENSE := 1.8
const BAG := 12
const SPEED_WALK := 3.2
const SPEED_SNEAK := 1.6
const SPEED_SPRINT := 5.0
const NOISE_WALK := 2.5
const NOISE_SNEAK := 0.8
const NOISE_SPRINT := 7.5
const NOISE_SEARCH := 3.2
const NOISE_CAN := 9.0
const NOISE_GUN := 25.0
const NIGHT_FROM := 22 * 60       # 22:00
const NIGHT_TO := 4 * 60          # 次日 04:00（120 分钟 = 1 夜）

# 瓦片
const TT_FLOOR := 0
const TT_WALL := 1
const TT_SLUSH := 2
const TT_COVER := 3
const TT_FENCE := 4
const TT_DOOR := 5
const TT_WEDGED := 6
const TT_BDOOR := 7

# ============================================================================
# ITEMS — 24 种物资
# ============================================================================
const ITEMS := {
	"rye": {"ic": "🌾", "cat": "food", "zh": "黑麦碎粒", "en": "Buckwheat Grits"},
	"can": {"ic": "🥫", "cat": "food", "zh": "铁皮罐头", "en": "Tin Can"},
	"water": {"ic": "🫖", "cat": "food", "zh": "热水壶", "en": "Hot Water Flask"},
	"asp": {"ic": "💊", "cat": "med", "zh": "阿司匹林", "en": "Aspirin"},
	"band": {"ic": "🩹", "cat": "med", "zh": "绷带", "en": "Bandage"},
	"abx": {"ic": "💉", "cat": "med", "zh": "抗生素", "en": "Antibiotics"},
	"dial": {"ic": "🧪", "cat": "med", "zh": "腹膜透析液", "en": "Dialysis Fluid"},
	"scrap": {"ic": "🔩", "cat": "scrap", "zh": "废钢件", "en": "Scrap Steel"},
	"wire": {"ic": "🧷", "cat": "scrap", "zh": "铁丝", "en": "Steel Wire"},
	"elec": {"ic": "🔌", "cat": "scrap", "zh": "电子元件", "en": "Electronics"},
	"wood": {"ic": "🪵", "cat": "scrap", "zh": "木柴", "en": "Firewood"},
	"kero": {"ic": "🛢️", "cat": "scrap", "zh": "煤油", "en": "Kerosene"},
	"intel": {"ic": "📄", "cat": "intel", "zh": "调度单/底单", "en": "Dispatch Slip"},
	"photo": {"ic": "📷", "cat": "intel", "zh": "焚化炉照片", "en": "Furnace Photos"},
	"barrel": {"ic": "🔫", "cat": "part", "zh": "枪管", "en": "Shotgun Barrel"},
	"stock": {"ic": "🪵", "cat": "part", "zh": "枪托", "en": "Gun Stock"},
	"pin": {"ic": "📌", "cat": "part", "zh": "击针", "en": "Firing Pin"},
	"bolt": {"ic": "⚙️", "cat": "part", "zh": "莫辛枪机", "en": "Mosin Bolt"},
	"ammo": {"ic": "🎯", "cat": "part", "zh": "步枪弹", "en": "Rifle Ammo"},
	"blade": {"ic": "🔪", "cat": "part", "zh": "宽背砍骨刀", "en": "Butcher Cleaver"},
	"vodka": {"ic": "🍾", "cat": "val", "zh": "伏特加", "en": "Vodka"},
	"watch": {"ic": "⌚", "cat": "val", "zh": "旧手表", "en": "Old Watch"},
	"tape": {"ic": "🎗️", "cat": "val", "zh": "黑绝缘胶布", "en": "Electrical Tape"},
	"glass": {"ic": "🍶", "cat": "val", "zh": "空玻璃瓶", "en": "Empty Bottle"},
}

# 战利品分类池（genLoot 的 CAT）
const LOOT_CATS := {
	"food": ["rye", "rye", "can", "water"],
	"med": ["asp", "band", "abx", "dial"],
	"scrap": ["scrap", "scrap", "wire", "elec", "wood"],
	"warm": ["wood", "wood", "kero", "water"],
	"intel": ["intel", "intel", "photo"],
	"part": ["barrel", "stock", "pin", "bolt", "ammo", "blade"],
	"weapon": ["blade", "barrel", "stock", "pin", "scrap", "scrap"],
	"val": ["vodka", "watch", "tape", "glass"],
}

# 容器类型 → 倾向分类池
const CONTAINER_CATS := {
	"medcab": ["med", "med"],
	"fridge": ["food", "med"],
	"crate": ["scrap", "food", "warm"],
	"locker": ["scrap", "food", "val"],
	"briefcase": ["intel", "val", "med"],
	"safe": ["val", "part", "med"],
	"hidden": ["part", "med", "val", "intel"],
	"car": ["scrap", "part", "food"],
	"dumpster": ["food", "scrap", "val"],
	"supply": ["food", "med", "warm"],
}

const CONTAINER_NAMES := {
	"crate": {"zh": "旧木箱", "en": "Old Crate"},
	"locker": {"zh": "铁皮柜", "en": "Steel Locker"},
	"medcab": {"zh": "医疗柜", "en": "Medicine Cabinet"},
	"briefcase": {"zh": "公文包", "en": "Briefcase"},
	"safe": {"zh": "保险柜", "en": "Safe"},
	"hidden": {"zh": "暗格", "en": "Hidden Stash"},
	"car": {"zh": "报废车", "en": "Dead Car"},
	"dumpster": {"zh": "垃圾箱", "en": "Dumpster"},
	"supply": {"zh": "配给箱", "en": "Supply Crate"},
	"fridge": {"zh": "冷柜", "en": "Freezer"},
}

# ============================================================================
# WEAPONS — 5 把武器（收集度决定火力）
# ============================================================================
const WEAPONS := [
	{"id": "fist", "ic": "✊", "zh": "赤手", "en": "Bare Fists", "dmg": 8.0, "range": 0.9,
		"arc": 70.0, "up": 0.2, "act": 0.1, "rec": 0.3, "need": 0, "parts": [],
		"note_zh": "空手上路。打不退狂暴者，只能推开挡路的人。",
		"note_en": "Empty hands. You cannot stop a rabid with these."},
	{"id": "crowbar", "ic": "🛠️", "zh": "铸铁道钉撬棍", "en": "Railway Crowbar", "dmg": 34.0,
		"range": 1.3, "arc": 60.0, "up": 0.35, "act": 0.15, "rec": 0.45, "need": 0, "parts": [],
		"note_zh": "可卡门（长按 E 锁门 15s）；弯头可把饭盒推进 12cm 门缝。",
		"note_en": "Wedge doors (hold E, 15s); the claw pushes tins through 12cm gaps."},
	{"id": "cleaver", "ic": "🔪", "zh": "东街生锈砍骨刀", "en": "Rusty Butcher Cleaver",
		"dmg": 46.0, "range": 1.0, "arc": 45.0, "up": 0.25, "act": 0.1, "rec": 0.35,
		"need": 1, "parts": ["blade"],
		"note_zh": "正面重劈狂暴者 100% 卡入锁骨缝，1.5s 内连按 6 次拔刀。",
		"note_en": "Frontal heavy strikes jam in the collarbone: 6 presses in 1.5s."},
	{"id": "shotgun", "ic": "🔫", "zh": "改装双管猎枪", "en": "Sawed-off Shotgun", "dmg": 95.0,
		"range": 9.0, "arc": 0.0, "up": 0.4, "act": 0.02, "rec": 0.9,
		"need": 3, "parts": ["barrel", "stock", "pin"], "ammo": 2,
		"note_zh": "散射角随心率扩张；一声枪响惊动全图清杀队。",
		"note_en": "Spread widens with BPM; the blast wakes every patrol on the map."},
	{"id": "mosin", "ic": "🎯", "zh": "莫辛纳甘步枪", "en": "Mosin–Nagant", "dmg": 150.0,
		"range": 18.0, "arc": 0.0, "up": 0.55, "act": 0.02, "rec": 1.35,
		"need": 2, "parts": ["bolt", "ammo"], "ammo": 3,
		"note_zh": "一枪一台阶，但拉栓慢、声音传得比风雪还远。",
		"note_en": "One shot, one body. Slow bolt, and the sound carries farther than the blizzard."},
]

# ============================================================================
# MATES — 每夜只能带 1 名
# ============================================================================
const MATES := [
	{"id": "ash", "ic": "🐺", "zh": "灰烬（灰狼犬）", "en": "Ash (Wolfdog)",
		"zh_p": "嗅觉预警：6m 内标出容器/生物；三态叫声分辨狂暴者、半人、求救者。",
		"en_p": "Olfactory warning: marks containers & creatures within 6m; tri-state bark separates rabid / half-human / kin.",
		"lock_zh": "城北冷库事件后入队", "lock_en": "Joins after the Cold Storage beat"},
	{"id": "anna", "ic": "👩", "zh": "安娜（0419）", "en": "Anna (0419)",
		"zh_p": "辨认半人：直接标注对方状态，避免误杀；背包 +4 格。",
		"en_p": "Tri-state readout: labels every figure; +4 pack slots.",
		"lock_zh": "疗养院地下室救援后入队", "lock_en": "Joins after the Sanatorium rescue"},
	{"id": "gulya", "ic": "🩺", "zh": "古丽娅（医师）", "en": "Gulya (Medic)",
		"zh_p": "每夜可救一次重伤；医疗类容器产出 +50%。",
		"en_p": "Revives you once per night; +50% medical haul.",
		"lock_zh": "与安娜一同获救", "lock_en": "Rescued together with Anna"},
	{"id": "pavel", "ic": "🧰", "zh": "帕维尔老爹（钳工）", "en": "Old Pavel (Fitter)",
		"zh_p": "可撬开焊死门与保险柜；武器耐久不损耗。",
		"en_p": "Opens welded doors & safes; weapons never degrade.",
		"lock_zh": "东街食堂事件后入队", "lock_en": "Joins after the Canteen beat"},
	{"id": "ivan", "ic": "🚂", "zh": "老轨伊万（列车长）", "en": "Old Ivan (Conductor)",
		"zh_p": "显示隐藏容器、撤离点常亮、路上耗时 -20%。",
		"en_p": "Reveals hidden stashes, keeps extraction marked, -20% travel time.",
		"lock_zh": "黑市抉择 C 后入队", "lock_en": "Joins after Black Market Choice C"},
]

# ============================================================================
# LOCS — 13 个 TWoM 式地图节点（x,y 为 900×520 城市地图坐标）
# ============================================================================
const LOCS := [
	{"id": "boiler", "x": 150, "y": 330, "dg": 1, "seed": 1101,
		"zh": "第3居住区 · 锅炉房后巷", "en": "Block 3 · Boiler Room Back Alley",
		"loot": ["food", "scrap"],
		"hint_zh": "楼下就能摸到，煤堆旁常有人堆杂物。", "hint_en": "Right downstairs; people stash junk by the coal pile.",
		"hint2_zh": "两只旧木箱、一台报废蒸汽泵。清杀队偶尔从东侧栅栏路过。",
		"hint2_en": "Two old crates, one dead steam pump. A patrol sometimes passes the east fence.",
		"time": 60, "cold": 0.4, "story": "", "req": {}, "req_flag": "",
		"scene": "res://scenes/night_boiler.tscn"},
	{"id": "coldstore", "x": 150, "y": 120, "dg": 2, "seed": 2202,
		"zh": "城北四号铁路冷库", "en": "Rail Cold Storage No.4",
		"loot": ["med", "food"],
		"hint_zh": "据说封着一批医疗耗材，也冻死过人。", "hint_en": "Sealed medical stock, and people who froze beside it.",
		"hint2_zh": "南库 3 号柱后有活人。冷库铁门可以撬棍卡死。",
		"hint2_en": "There are living people behind column 3. Cold-store doors can be wedged.",
		"time": 80, "cold": 0.9, "story": "coldstore", "req": {}, "req_flag": "",
		"scene": "res://scenes/night_coldstore.tscn"},
	{"id": "yard", "x": 340, "y": 215, "dg": 3, "seed": 3303,
		"zh": "夜间广轨货场", "en": "Broad-Gauge Freight Yard",
		"loot": ["scrap", "intel"],
		"hint_zh": "编组表和废件堆都在那，灯也最亮。", "hint_en": "Marshalling slips and scrap piles. Also the brightest lights.",
		"hint2_zh": "两座煤水塔可躲探照灯；清杀队 2 人一组巡逻。",
		"hint2_en": "Two water towers break the searchlights; purge squads patrol in pairs.",
		"time": 90, "cold": 1.0, "story": "yard", "req": {}, "req_flag": "",
		"scene": "res://scenes/night_explore.tscn"},
	{"id": "underpass", "x": 330, "y": 410, "dg": 2, "seed": 4404,
		"zh": "铁道下穿积冰道", "en": "Icy Rail Underpass",
		"loot": ["scrap", "warm"],
		"hint_zh": "黑冰很滑，声音会传得很远。有人在这儿烧火。", "hint_en": "Black ice is loud. Someone keeps a fire burning here.",
		"hint2_zh": "涉雪泥移动 ×0.65，噪声 ×2.0；火堆可回温。",
		"hint2_en": "Slush: speed ×0.65, noise ×2.0. The brazier restores warmth.",
		"time": 70, "cold": 1.3, "story": "", "req": {}, "req_flag": "",
		"scene": "res://scenes/night_underpass.tscn"},
	{"id": "canteen", "x": 510, "y": 330, "dg": 3, "seed": 5505,
		"zh": "东街工人食堂 · 后厨", "en": "East Street Canteen · Kitchen",
		"loot": ["weapon", "food"],
		"hint_zh": "账面已清空的老楼，可里面还有十九只碗。", "hint_en": "Written off as empty. Nineteen bowls still inside.",
		"hint2_zh": "备餐台砧板上插着砍骨刀；窄门会被冲开。",
		"hint2_en": "A cleaver stands in the prep-table block; the narrow door can be breached.",
		"time": 90, "cold": 0.5, "story": "canteen", "req": {}, "req_flag": "",
		"scene": "res://scenes/night_canteen.tscn"},
	{"id": "sanitarium", "x": 650, "y": 130, "dg": 4, "seed": 6606,
		"zh": "旧传染病疗养院 · 地下室", "en": "Old Sanatorium · Basement",
		"loot": ["med"],
		"hint_zh": "有人被皮带捆在铁架床上熬过了第四天。", "hint_en": "Someone was belted to a bed frame and survived the fourth day.",
		"hint2_zh": "地底铁笼区。需要至少 1 份医疗物资与 2 份情报线索。",
		"hint2_en": "Cage level. Needs 1 medical item and 2 intel leads.",
		"time": 110, "cold": 0.8, "story": "sanitarium", "req": {"intel": 2, "med": 1}, "req_flag": "",
		"scene": "res://scenes/night_sanitarium.tscn"},
	{"id": "market", "x": 670, "y": 275, "dg": 2, "seed": 7707,
		"zh": "铁路黑市（废弃工人镇）", "en": "Rail Black Market",
		"loot": ["intel", "val"],
		"hint_zh": "拿东西换东西。别相信任何人递过来的手。", "hint_en": "Goods for goods. Never trust the hand that offers.",
		"hint2_zh": "人会开枪，但比清杀队讲道理。可交易情报。",
		"hint2_en": "People shoot, but they argue first. Intel can be traded.",
		"time": 80, "cold": 0.9, "story": "market", "req": {}, "req_flag": "",
		"scene": "res://scenes/night_market.tscn"},
	{"id": "manor", "x": 835, "y": 95, "dg": 5, "seed": 8808,
		"zh": "松林庄园 · 二号恒温库", "en": "Pine Manor · Depot No.2",
		"loot": ["med", "val"],
		"hint_zh": "墙外 −35℃，墙里 26℃。409 批腹透液就在那儿。", "hint_en": "-35°C outside, 26°C inside. The Batch-409 fluid is in there.",
		"hint2_zh": "电网高墙 + 特勤值守。被发现基本等于死。",
		"hint2_en": "Electric fence, private guards. Seen means dead.",
		"time": 120, "cold": 0.3, "story": "manor", "req": {}, "req_flag": "manor_tip",
		"scene": "res://scenes/night_manor.tscn"},
	{"id": "marshalling", "x": 800, "y": 390, "dg": 4, "seed": 9909,
		"zh": "西站调车场", "en": "West Station Marshalling Yard",
		"loot": ["part", "intel"],
		"hint_zh": "报废守车里有零件，调度室外贴着今晚的发车令。",
		"hint_en": "Parts in the dead brake vans; tonight's dispatch order pinned outside.",
		"hint2_zh": "机车水箱里可能塞着手稿复写件。",
		"hint2_en": "Manuscript carbons might be stuffed in a tender toolbox.",
		"time": 100, "cold": 1.1, "story": "marshalling", "req": {}, "req_flag": "lana_car3",
		"scene": "res://scenes/night_marshalling.tscn"},
	{"id": "mine", "x": 860, "y": 470, "dg": 5, "seed": 1010,
		"zh": "3 号矿坑 · 温压爆破作业面", "en": "Mine Shaft No.3 · Blast Face",
		"loot": ["intel", "scrap"],
		"hint_zh": "灰鳞病的源头就埋在断面里。矿上还码着铝热剂。",
		"hint_en": "Grey-Scale's origin is cut open at the blast face. Thermite is stacked beside it.",
		"hint2_zh": "留守技术员博伊科守着起爆器；他手上的鳞屑正在掉。",
		"hint2_en": "Watch tech Boiko guards the detonator; his scales are flaking off.",
		"time": 100, "cold": 1.2, "story": "", "req": {}, "req_flag": "lana_car3",
		"scene": "res://scenes/night_mine.tscn"},
	{"id": "birch", "x": 620, "y": 470, "dg": 1, "seed": 1212,
		"zh": "白桦林废弃板房", "en": "Birch Grove Shacks",
		"loot": ["warm", "scrap"],
		"hint_zh": "风小，能捡到柴。偶尔有逃出来的人躲在这儿。",
		"hint_en": "Sheltered. Firewood, and sometimes people who ran.",
		"hint2_zh": "低风险补给点，适合缺体温的夜里。",
		"hint2_en": "Low-risk resupply. Good when you are freezing.",
		"time": 60, "cold": 1.5, "story": "", "req": {}, "req_flag": "",
		"scene": "res://scenes/night_birch.tscn"},
	{"id": "workshop", "x": 480, "y": 130, "dg": 2, "seed": 6606,
		"zh": "机修车间", "en": "Machine Workshop",
		"loot": ["scrap", "part"],
		"hint_zh": "车床边散落着零件，焊机还能打着火。",
		"hint_en": "Parts by the lathes; the welder still sparks.",
		"hint2_zh": "车间里工具多，但巡逻队常来查。",
		"hint2_en": "Plenty of tools — and patrols check in often.",
		"time": 70, "cold": 0.8, "story": "", "req": {}, "req_flag": "",
		"scene": "res://scenes/night_workshop.tscn"},
	{"id": "greenhouse", "x": 480, "y": 470, "dg": 1, "seed": 7707,
		"zh": "温室大棚", "en": "Greenhouse",
		"loot": ["food", "warm"],
		"hint_zh": "塑料布还算严实，冻土里埋着去年的土豆。",
		"hint_en": "The plastic still holds; last year's potatoes are in the frozen soil.",
		"hint2_zh": "低风险食物点，适合缺粮的夜里。",
		"hint2_en": "Low-risk food. Good when you are hungry.",
		"time": 60, "cold": 0.6, "story": "", "req": {}, "req_flag": "",
		"scene": "res://scenes/night_greenhouse.tscn"},
	{"id": "archive", "x": 860, "y": 250, "dg": 3, "seed": 8808,
		"zh": "档案馆电报局", "en": "Archive & Telegraph Office",
		"loot": ["intel", "val"],
		"hint_zh": "旧电报和花名册都在，值钱的情报也在。",
		"hint_en": "Old telegrams and rosters — and valuable intel.",
		"hint2_zh": "高风险：清杀队重点盯防的情报点。",
		"hint2_en": "High risk: an intel site the purge squads watch closely.",
		"time": 90, "cold": 0.7, "story": "", "req": {}, "req_flag": "",
		"scene": "res://scenes/night_archive.tscn"},
]

# ============================================================================
# STORY — 7 段主线剧情节拍（首次进入该地点时触发）
# choices[*].ops 为数据化效果：
#   ["add", item_id, n] / ["take", item_id, n] / ["conscience", delta]
#   ["tally", n] / ["flag", flag_id] / ["mate", mate_id] / ["name", string]
# ============================================================================
const STORY := {
	"coldstore": {
		"title_zh": "账面死人", "title_en": "The Paper Dead",
		"file": "0892",
		"lines": [
			{"w": "", "zh": "白天，你领到一枚「二级留观·临时征召工」的蓝印。护卫班长切尔诺夫中士带你来到四号铁路冷库，搬运封口膜和医疗耗材。",
				"en": "By daylight, you receive a blue stamp: Level Two Observation, Temporary Conscript Labour. Sergeant Chernov, the guard detail leader, takes you to Rail Cold Storage No.4 to move sealing film and medical supplies."},
			{"w": "切尔诺夫中士", "zh": "莫罗佐夫，去南库。三号柱边上那批箱子，按清单点一遍。",
				"en": "Morozov, south hall. Count the crates by column three against the manifest."},
			{"w": "", "zh": "你绕过南库三号柱，听见一阵压得很低的咳嗽。一个男人正用露出黑棉絮的袄子裹紧怀里的孩子。他说自己叫谢尔盖，孩子叫玛丽亚，转运车走的时候把他们落下了。",
				"en": "You round column three and hear a stifled cough. A man is wrapping his child in a coat split down to the stuffing. He says his name is Sergey, the child is Maria, and the transport left them behind."},
			{"w": "", "zh": "你叫来切尔诺夫。中士接过谢尔盖递来的通行证，往磁卡终端上一划。屏幕亮起一行红字，他照着念了出来。",
				"en": "You call Chernov over. The sergeant takes Sergey's pass and swipes it through the terminal. A line flashes red and he reads it aloud."},
			{"w": "切尔诺夫中士", "mood": "intense", "zh": "档案 0892：昨日 22:00 已移交乌拉尔山线站。按主脑台账，当前坐标在册活人：0。莫罗佐夫，按清单办。继续搬箱子。",
				"en": "File 0892: transferred to the Ural Line Station yesterday at 22:00. Persons registered at this coordinate: zero. Follow the manifest, Morozov. Keep moving those crates."},
			{"w": "", "mood": "sad", "zh": "配给箱的电子锁「咔」地一声落了死栓——多么干脆、多么合乎规矩的一声响！那男人竟连头也没有抬一下，只是跪在结了黑冰的水泥地上，用冻裂的指甲一寸寸抠着冰缝里掉出来的两粒黑麦。既然账本上写着「零」，那他们就连喊饿的权利也一并被注销了。",
				"en": "The ration crate's lock snaps shut. The man does not look up; he only feels in the ice for two spilled grains of buckwheat."},
			{"w": "", "zh": "傍晚，切尔诺夫带车队离开。你在废弃收发亭旁掰下半块冷黑麦饼，递给一只脖颈上还缠着断铁丝的灰狼犬。它叼走了饼。你想起柱子后面的两个人，摸到衣袋里的工作日志。",
				"en": "At dusk, Chernov leaves with the convoy. By the abandoned dispatch hut, you break off half a piece of cold rye for a wolfdog with wire caught around its neck. It takes the bread. You think of the two people behind the column and reach for the logbook in your pocket."},
		],
		"choices": [
			{"zh": "在《工作日志》背面写下：谢尔盖、玛丽亚，活人",
				"en": "Write in the logbook: Sergey & Maria, alive",
				"d_zh": "良知 ▲ · 记录一条真实姓名", "d_en": "Conscience ▲ · one real name survives",
				"cls": "good",
				"ops": [["name", "Сергей, Мария · 谢尔盖与玛丽亚"], ["conscience", 8], ["add", "scrap", 1]],
				"after_mate": "ash",
				"toast_zh": "钢笔尖刺破纸背：谢尔盖、玛丽亚——哪怕全世界的电传机都判了他们死刑，在这张纸上，他们还在喘气。「灰烬」无声地走上前，把冻湿的前爪轻轻按在了你的靴面上。",
				"toast_en": "The pen scratches: another real name survives. Ash plants a paw on your boot."},
			{"zh": "什么也不写，低头搬你的箱子", "en": "Write nothing. Keep hauling crates.",
				"d_zh": "中立 · 省下麻烦", "d_en": "Neutral · save yourself the trouble",
				"cls": "",
				"ops": [["add", "scrap", 2]],
				"after_mate": "ash",
				"toast_zh": "你卑怯地低下头，数清了公家的箱子，却唯独不敢去数近在咫尺的活人。「灰烬」在身后静静看着你，还是踩着你的脚印跟了上来。",
				"toast_en": "You counted the crates. You did not count them. Ash follows anyway."},
		],
	},
	"yard": {
		"title_zh": "铁壳号的编组单", "title_en": "The Buran Consist",
		"lines": [
			{"w": "", "zh": "煤水塔被黑冰包裹的背阴处，一张被冻雪泡得发胀的油印编组单，像一块揭不掉的伤疤似地黏在调度箱铁皮背面：",
				"en": "In the water tower's shadow, a consist sheet rots against the back of a switch box:"},
			{"w": "", "mood": "intense", "zh": "【布拉风号 · 第 7 次特别运输 · 闷罐车厢 03 · 档案编号 0401—0576 · 终到销账点：乌拉尔鹰嘴崖】",
				"en": "[BURAN · Special Run 7 · Boxcar 03 · Files 0401–0576 · Terminus: Eagle's Crag, Urals]"},
			{"w": "", "mood": "sad", "zh": "你的手指抖得几乎折不拢那张薄纸。拉娜的编号是 0420——不偏不倚，就像一颗被铁锤钉进棺木的钉子，死死夹在那串将死的数字中间。",
				"en": "You fold it into your inner pocket. Lana is 0420. She is inside that range."},
		],
		"choices": [
			{"zh": "收好编组单（+1 情报）", "en": "Pocket the consist (+1 Intel)",
				"d_zh": "主线推进", "d_en": "Story lead", "cls": "good",
				"ops": [["add", "intel", 1]],
				"after_mate": "",
				"toast_zh": "那张冰凉的编组单隔着衬衣紧贴着你的肋骨，像一块烧红的烙铁。0420，你的亲妹妹，此刻正在第三节闷罐车厢里等着被抹去。",
				"toast_en": "The consist sits against your ribs. 0420 is in that car."},
		],
	},
	"canteen": {
		"title_zh": "锁骨里的砍骨刀", "title_en": "The Cleaver in the Collarbone",
		"lines": [
			{"w": "", "zh": "后厨杂物间的朽木门轰然炸裂！炊事员的独子瓦西里在 40℃ 高烧的狂乱谵妄里扑了出来，那双原本憨厚的眼睛里，此刻只剩下一片令人胆寒的紫黑血翳。",
				"en": "The pantry door explodes. Vasily, the cook's son, comes out in 40°C delirium, sclera black-purple."},
			{"w": "", "zh": "后背已经抵死了冰冷的备餐铁台，退无可退。你在令人窒息的腥气里胡乱摸索，五指猛地攥住了油腻砧板上那把沉重的宽背砍骨刀。",
				"en": "Cornered against the prep table, your hand finds the heavy-backed cleaver in the block."},
			{"w": "费奥多尔老爹", "mood": "intense", "zh": "……阿廖沙！别下手啊！我的瓦西里是个好孩子，他昨天夜里还冒着暴风雪给四楼瘫在床上的老工友送黑麦饼啊——！",
				"en": "…Alyosha! He was delivering bread to the fourth floor yesterday!"},
		],
		"choices": [
			{"zh": "一刀劈进左锁骨窝", "en": "Swing into the left collarbone",
				"d_zh": "自卫击杀，不记划痕", "d_en": "Self-defence · no tally stroke", "cls": "",
				"ops": [["flag", "ptsd"], ["flag", "vasily"], ["add", "blade", 1], ["conscience", -4]],
				"after_mate": "pavel",
				"toast_zh": "钝重的刀刃卡进骨缝，瓦西里眼里的紫黑血翳却在临死前退去了：「……Пить（水/渴）……」系统没有给你记上杀戮划痕，可那个词从此在你耳膜里嗡嗡作响。两天后的深夜，你高烧着重返东街食堂。费奥多尔没有逃，正用温水擦洗儿子锁骨上的伤口，脚边还摆着你上次送来的黑麦糊。你本可以躲在阴影里，却推开门，跪进结冰的血水：「打死我吧，费奥多尔大叔！他冲出来时已经滑倒了，我本可以用撬棍柄砸他的腿……可我太害怕，只想快点脱身，挑了最省事的砍骨刀！」独眼老爹久久没有说话，最后只用满是老茧的手摸了摸你的头，把瓦西里生前的厚棉坎肩披到你肩上：「孩子，我们都在地狱里。你替我把他还活着的名字，写进你的本子里吧。」他没有原谅那致命的一刀，也没有把你变成一个凶手；他只是把继续背负这条命的权利，交还给了你。",
				"toast_en": "The blade jams. His pupils clear: \"…Пить (Thirsty)…\" Two nights later you return to the canteen and kneel before Fyodor, confessing that you chose the cleaver because fear made it quickest. He drapes Vasily's coat over your shoulders and asks you to write his son's living name in your book."},
		],
	},
	"market": {
		"title_zh": "老轨伊万", "title_en": "Old Ivan, the Railman",
		"lines": [
			{"w": "", "zh": "黑市低矮漏风的铁皮棚下，在这条西伯利亚死线上跑了整整二十年专列的老列车长吐掉嘴里的劣质烟蒂，带着一身煤油与劣酒的寒气，把一张浸透机油的路线纸重重拍在你的胸口上。",
				"en": "Under the market's tin awning, the conductor who ran Siberian trains for twenty years spits out his cigarette and slaps an oil-paper note on your chest."},
			{"w": "老轨伊万", "mood": "intense", "zh": "听着，调度员小子！今晚十一点整，那趟连车次牌都不敢挂的「铁壳号」要走鹰嘴崖死线！第三节闷罐车厢里锁着整整一百七十六个已经退了烧、会哭会喊的活人，全都要拉进 3 号废弃矿坑拿炸药活埋销账！你妹妹也在里头——我只问你一句：这趟地狱里的车，你敢不敢爬？！",
				"en": "Eleven tonight: an unnumbered Buran takes the Eagle's Crag line. One hundred seventy-six recovered people in Boxcar 3, dumped in Pit No.3. You climbing or not?"},
		],
		"choices": [
			{"zh": "C1 公平交易：付 2 废钢买路线（中立）", "en": "C1 Fair trade: pay 2 Scrap for the route",
				"d_zh": "情报 +1 · 解锁松林庄园线索", "d_en": "Intel +1 · unlocks the Pine Manor lead",
				"cls": "good",
				"ops": [["take", "scrap", 2], ["add", "intel", 1], ["flag", "manor_tip"]],
				"after_mate": "",
				"toast_zh": "伊万冷冷收下废钢，用粗黑的指甲在油纸上划出一道死线：「顺着西站水塔底下的排污检修沟摸过去；记住，第三根冻裂的枕木底下埋着雷，不想死就别往上踩。」",
				"toast_en": "Ivan sketches the route on the oil paper: use the maintenance trench under the water tower; skip the third sleeper."},
			{"zh": "C3 倾囊相助：把抗生素分给这里冻伤的人（良知▲）",
				"en": "C3 Give everything: hand out your antibiotics",
				"d_zh": "良知 ▲▲ · 伊万入队 · 解锁松林庄园", "d_en": "Conscience ▲▲ · Ivan joins · unlocks Pine Manor",
				"cls": "good",
				"ops": [["take", "abx", 1], ["conscience", 10], ["flag", "manor_tip"], ["mate", "ivan"]],
				"after_mate": "ivan",
				"toast_zh": "看着你把救命的药塞进冻烂脚趾的苦人手里，「老轨」伊万浑浊的眼底狠狠颤了一下。他没再要你的废钢，一言不发地将一只烤热了的厚帆布手套塞进你怀里，跟上了你的脚步。",
				"toast_en": "Old Ivan joins your crew. He shoves a frozen glove into your hands."},
			{"zh": "C2 背叛：趁他引开哨兵，锁死铁门拿走磁卡（良知▼·卌+1）",
				"en": "C2 Betray: lock the door and take the keycard",
				"d_zh": "物资暴涨 · 卌 +1", "d_en": "Huge haul · tally +1", "cls": "bad",
				"ops": [["add", "abx", 2], ["add", "scrap", 3], ["add", "dial", 1],
					["tally", 1], ["conscience", -14], ["flag", "manor_tip"], ["flag", "betrayed"]],
				"after_mate": "",
				"toast_zh": "沉重的铁门被你从外头死死落了锁。门后先是一声难以置信的闷哼，紧接着是微声步枪短促得像踩碎冰碴似的点射声。你的背包被抢来的物资撑得满满当当，可你的灵魂却在日志背面多了一道洗不掉的血痕。",
				"toast_en": "The door shuts behind you. The shots are very short."},
		],
	},
	"sanitarium": {
		"title_zh": "0419 号在呼吸", "title_en": "0419 Is Breathing",
		"lines": [
			{"w": "", "zh": "地底最深处那间结满白霜的钢筋铁笼前，一个瘦得只剩一把骨头的年轻姑娘，正用两根磨断了扣眼的旧皮带，将自己的一双手腕死死勒在铁架床的栏杆上，勒得皮肉翻卷、深可见骨。",
				"en": "At the deepest cage, a young woman has belted her own wrists to the bed frame with two old straps."},
			{"w": "", "zh": "「灰烬」安静地走上前，摇着尾巴，把温热湿润的鼻尖轻轻贴了贴她布满脱落鳞屑的手背。姑娘剧烈地颤栗了一下，缓缓抬起头——她眼白里的紫黑充血已经完全退净，那双深陷的眸子里闪烁着受尽苦难后刀锋般清醒的光。",
				"en": "Ash walks up, tail low, and touches the back of her hand with a wet nose. The girl looks up — the blood has receded from her eyes. She is fully awake."},
			{"w": "安娜（0419）", "mood": "intense", "zh": "是拉娜！！天哪，这是拉娜的照片！！三天前在西站铁皮棚里，她就关在我隔壁的笼子里！那时候她的烧已经退到三十六度八了，手背上的灰鳞一片片往下掉！她看我高烧撞墙，还从铁网眼儿里塞给我最后半片阿司匹林……可昨天夜里，他们根本不管谁退了烧，按着名单把她和一百多个清醒过来的活人，全都锁进了「铁壳号」的第三节闷罐车厢！！",
				"en": "It's Lana!! Three days ago she was in the cage next to mine! Her fever broke at 36.8°C, the scales were falling off her hands! Last night they locked her and a hundred others into the Buran — Boxcar No.3!!"},
		],
		"choices": [
			{"zh": "撬开铁笼，带她们走（消耗 1 份医疗物资）", "en": "Pry the cage. Bring them out. (-1 medical)",
				"d_zh": "安娜 + 古丽娅 入队 · 解锁西站调车场", "d_en": "Anna + Dr. Gulya join · unlocks the marshalling yard",
				"cls": "good",
				"ops": [["mate", "anna"], ["mate", "gulya"], ["conscience", 6],
					["flag", "lana_car3"], ["flag", "manor_tip"]],
				"after_mate": "",
				"toast_zh": "你用撬棍崩开了生锈的笼锁，替她解开了嵌进肉里的皮带。安娜（0419）与古丽娅医师搀扶着跟上了你，铁笼门轴在极夜的风雪里发出一声长长的、如释重负的悲鸣。",
				"toast_en": "Anna (0419) and Dr. Gulya join. The cage hinge screams in the snow."},
		],
	},
	"manor": {
		"title_zh": "焦油黑雪", "title_en": "Tar-Black Snow",
		"lines": [
			{"w": "", "zh": "一墙之隔，墙外是零下三十五度冻死骨头的苦寒地狱，墙里却是二十六度暖风熏人的特权天堂。履带叉车正轰鸣着，把一托盘又一托盘仅仅因为「距离保质期还有十五天」的谷饲牛排、黄油，连同你母亲救命的 409 批瑞士腹透液，整铲整铲地推进 2000℃ 的工业焚化炉！",
				"en": "-35°C outside the wall, 26°C inside. A forklift shoves beef, butter and Batch-409 dialysis fluid — \"fifteen days past date\" — into a 2000°C furnace."},
			{"w": "", "zh": "高耸的烟囱向着上风口喷吐出浓黑的脂臭油烟，混着鹅毛大雪飘向下风口两公里外的工人筒子楼。原来这就是落满全城窗台的「焦油黑雪」——饿极了的孩子闻着有烤肉的焦香，抓一把塞进嘴里，嚼碎的却全是烧化了的塑料包装袋与黑油垢！",
				"en": "The stack vomits black smoke into the snow and drifts two kilometres downwind to the workers' blocks. That is the tar-black snow: it smells like roast fat and tastes like burnt plastic."},
			{"w": "", "mood": "sad", "zh": "办公室里没有酒池肉林。茹科夫专员面前摆着的，也是一碗和白区饥民相同的冷水泡霉黑麦；他眼窝深陷，像许多夜没有睡过。签署三号矿坑活埋令的那只手没有躲你的撬棍，只是平静地指向窗外：「你以为我烧掉腹透液是因为贪婪？三十箱药，三百个病人。发下去，二十四座工人楼今夜就会拿菜刀互相开门。人类承受不起只有十分之一的人能活的自由。」",
				"en": "Zhukov's desk holds the same mouldy rye and cold water as the workers' canteen. He does not flinch from your crowbar: thirty crates, three hundred patients; distribution would mean a knife in every hallway by midnight."},
			{"w": "", "mood": "intense", "zh": "他低头喝了一口那碗霉水，仿佛在替全城领受圣餐：「他们也不能知道灰鳞病会自愈。知道了，过去每一张处决单都会变成他们亲手签的罪。只有电传机亮着绿灯，只有他们相信三号车厢里全是怪物，良民才睡得着。我把牛排烧成灰，把活人填进矿坑——是我替这十万个软弱的人背起下地狱的十字架。你去广播吧，阿列克谢。门一开，他们第一个撕碎的，也许不是我和我的台账，而是那个逼他们看见真相的你。」你的撬棍仍举在半空，可你忽然分不清，自己准备砸碎的是他的谎言，还是全城赖以活命的梦。",
				"en": "He drinks the mouldy water like communion. If the cured are human, every citizen becomes an accomplice; if they are monsters, the city can sleep. He calls the furnace his cross, and warns that the crowd may tear apart the witness before the executioner."},
			{"w": "", "zh": "你在令人作呕的热浪里举起相机，冻僵的食指狠狠按下了快门。",
				"en": "You raise the camera and press the shutter."},
		],
		"choices": [
			{"zh": "拍下焚毁台账，带走腹透液", "en": "Photograph the ledger. Take the fluid.",
				"d_zh": "腹透液 +2 · 真相存活 · 母亲好转", "d_en": "Fluid +2 · truth survives · mother stabilises",
				"cls": "good",
				"ops": [["add", "dial", 2], ["add", "photo", 1], ["flag", "truth"], ["conscience", 5]],
				"after_mate": "",
				"toast_zh": "机械快门「咔嚓」一响，在轰鸣的火炉旁清脆得像一发顶上膛的子弹。你把拍下罪证的胶卷贴胸藏好，将两袋滚烫的 409 批腹透液死死塞进了背包。",
				"toast_en": "The shutter sounds like a gunshot. You stuff Batch-409 into your pack."},
		],
	},
	"marshalling": {
		"title_zh": "十一点的发车令", "title_en": "The 23:00 Dispatch Order",
		"lines": [
			{"w": "", "zh": "西站调度室外的防寒铁皮板上，孤零零地钉着一张还没来得及撕毁的绝密发车令，上面内务部的红章新鲜得发黏，像一滩刚刚凝固的血：",
				"en": "A dispatch order is still pinned to the board outside the control room, the red stamp still tacky."},
			{"w": "", "zh": "【特别运输指令 · 严禁悬挂车次牌 · 发车时刻：23:00 · 行车区间：鹰嘴崖死线 · 第三节车厢核载：176 人 · 死令：实毁数与账面数必须绝对闭合】",
				"en": "[SPECIAL RUN · NO TRAIN NUMBER · 23:00 · EAGLE'S CRAG LINE · BOXCAR 3 · 176 PERSONS · PHYSICAL COUNT MUST EQUAL LEDGER]"},
			{"w": "", "zh": "你屏住呼吸拍下了那个鲜红的印鉴。而在一旁报废守车的铁工具箱底，正静静躺着几块抹了黄油、足以拼凑出一支致命猎枪的精钢枪机零件。",
				"en": "You photograph the stamp. In a dead brake van's toolbox lie the steel pieces of a gun."},
		],
		"choices": [
			{"zh": "拆走零件，抄下车次时刻", "en": "Strip the parts, copy the timetable",
				"d_zh": "猎枪零件 +1 · 情报 +1 · 终局预告", "d_en": "Shotgun part +1 · Intel +1 · endgame revealed",
				"cls": "good",
				"ops": [["add", "intel", 1], ["flag", "endgame_known"]],
				"after_mate": "",
				"toast_zh": "午夜 23:00。乌拉尔鹰嘴崖。一百七十六条退了烧的性命。所有的数字、所有的罪孽与最后的审判时刻，终于在你的脑海里严丝合缝地扣上了。",
				"toast_en": "23:00. Eagle's Crag. One hundred seventy-six. You finally know every number."},
		],
	},
}

# 清杀队战斗短对白：警告 → 追杀 → 阵亡；execute 为玩家被击毙前的处决短句。
# 与 STORY 分表存放，避免战斗事件反复触发时把七段主线剧情重新打开。
const OSK_BARKS := {
	"warning": {
		"speaker_zh": "清杀队 · 警戒", "speaker_en": "OSK · Suspicious", "mood": "calm",
		"lines": [
			{"zh": "阴影里是谁？滚到探照灯底下来，把印鉴卡举过头顶！", "en": "Who is there? Step into the light. Papers, now."},
			{"zh": "不准动！手放在光柱里，别让我提醒第二遍。", "en": "Do not move. Keep your hands where I can see them."},
			{"zh": "宵禁封锁区。转过身，面朝铁墙慢慢退过来！", "en": "This sector is sealed. Turn around and approach slowly."},
		],
	},
	"chase": {
		"speaker_zh": "清杀队 · 追杀", "speaker_en": "OSK · Pursuit", "mood": "intense",
		"lines": [
			{"zh": "是夜潜者！焊死前头路口，绝不能让他钻回居住区！", "en": "Target spotted! Seal the junction. Do not let him reach the blocks!"},
			{"zh": "他插翅难逃！二号从涵洞包抄，探照灯死死钉住他！", "en": "He will not escape. Two, flank him. Keep the light on him!"},
			{"zh": "站住！再往前一步，按灰鳞狂暴者就地销账！", "en": "Halt! Run again and we fire!"},
		],
	},
	"death": {
		"speaker_zh": "清杀队 · 阵亡", "speaker_en": "OSK · Down", "mood": "death",
		"lines": [
			{"zh": "三号中弹……探照灯……别让光灭了……黑……", "en": "Three is hit... the light... do not let it go out..."},
			{"zh": "电传机……还亮着吗……替我划掉……编号……", "en": "Is the radio... still on... tell them..."},
			{"zh": "面具碎了……好冷……报告督察……活人还在……", "en": "I cannot see... report... the target is still..."},
		],
	},
	"execute": {
		"speaker_zh": "清杀队 · 目标清除", "speaker_en": "OSK · Target Down", "mood": "intense",
		"lines": [
			{"zh": "目标已物理清零。核对档案号，恢复灯火封锁。", "en": "Target down. Verify the file number. Restore the cordon."},
			{"zh": "停止射击。实毁数加一，写进午夜交接底单。", "en": "Cease pursuit. Enter the scene in the handover log."},
		],
	},
}

# 终局共同余响：帕沙的圣愚行为不改变结局判定，只追问救人与尊严是否必须有利可图。
const PASHA_EPILOGUE_ZH := "鹰嘴崖谷底，十八岁的清杀队新兵帕沙在崖顶反戈，替你和拉娜挡下督察队的机枪，随后顺着雪坡滚到一具从闷罐车厢摔出的无名女尸旁。他知道自己快死了，却仍用满是血的手解那件铅灰色防化服，执意把厚重的衣服套在早已冻僵的女人身上：「大哥……帮我把扣子系上……她穿着单衣，雪太大了……督察官说防化服是公家财产，少一件要枪毙……可她也是个人啊，不能光着身子见上帝……」他的最后一息没有救活任何人，也没有改变一张台账。可在整座城都计算一件衣服能换几发子弹时，这个连字也认不全的少年偏要把最后一寸温暖送给死人；正是这毫无用处的举动，使所有精明的生存账忽然显得比死亡更加贫穷。"

const PASHA_EPILOGUE_EN := "At Eagle's Crag, eighteen-year-old Pasha turns his rifle on the inspectors and takes their fire for you and Lana. Dying beside a nameless woman thrown from the boxcar, he struggles to pull off his state-issued protective suit and dress her frozen body: she is a person too, and cannot meet God half naked. His last act saves no one and changes no ledger; its useless mercy makes every careful calculation of survival suddenly look poorer than death."

# ============================================================================
# TEXT — UI 文案
# ============================================================================
const TEXT := {
	"zh": {
		"title": "《Z年纪事：凛冬铁轨》", "subtitle": "探索循环 DEMO · 无美术灰盒 · GODOT 4 移植版",
		"tagline": "在诺沃斯克-17，电传机的绿灯证明配给已经抵达，档案上的划线证明一个人从未活过。",
		"start": "进入 602 室（开始）", "help": "操作说明", "logbook": "工作日志",
		"base_title": "据点 · 第3居住区 赫鲁晓夫楼 602 室",
		"base_sub": "透析机的低鸣替母亲数着剩下的时间。你白天替她换液，夜里翻过锅炉房气窗；每次回来，都要重新决定自己还是不是自己。",
		"map_title": "诺沃斯克-17 · 夜潜目标选择",
		"map_sub": "每夜只能去一个地方。你带走的不只是物资，也可能是某个人的最后一口气；先想清楚带谁、带什么，以及准备把谁留在黑暗里。",
		"back_base": "返回 602 室", "to_map": "前往夜潜地图",
		"sleep": "白昼：照顾母亲 / 休息到下一夜",
		"next_day": "回到 602 室（进入第二天）",
		"status": "状态", "party": "出战伙伴（每夜 1 名）", "story": "主线索记事板",
		"stash": "库存 / 储物", "weapons": "武器架 · 收集度决定火力",
		"mother": "卡佳妈妈 · 腹透液", "temp": "核心体温", "conscience": "良知",
		"tally": "卌 划痕", "truth": "真相存活", "day": "第 %d 天",
		"sortie": "携带", "depart": "出发（夜潜）", "danger": "危险度", "loot": "物资提示",
		"need": "需求", "time": "耗时", "state": "状态",
		"unexplored": "未踏足", "scouted": "已踏足", "story_tag": "主线", "solo": "独自行动",
		"extracted": "撤离成功", "downed": "重伤倒地 · 被拖回 602 室", "dawn": "天亮了 · 强行撤回",
		"abort": "放弃夜潜", "hp": "健康", "stam": "体力", "bpm": "心率", "warmth": "体温",
		"search": "搜刮中…", "open_door": "卡住这扇门", "extract_hint": "撤离点",
		"bag": "背包", "wpn": "武器", "mini": "小地图", "pack_full": "背包满了",
		"unlocked": "已解锁地点", "names": "日志背面的真名", "events": "事件记录",
		"objective": "当前目标", "haul": "带回的物资", "this_run": "本次记录",
		"events_report": "事件", "rack": "武器架更新", "back_page": "《双面工作日志》背面",
		"containers": "容器余量", "depart_ok": "出发（夜潜）", "locked": "未解锁",
		"night": "夜", "left": "剩余", "game_over": "DEMO 边界 · 第四幕",
		"ending_preview": "终局预演", "restart": "重新开始",
		"loaded": "已携带", "stock": "库存", "mate_none": "不带伙伴",
		"raid_help": "WASD 移动 · 鼠标定向 · Ctrl 蹲伏 · Shift 冲刺 · 左键/Space 攻击 · 按住 E 搜刮/卡门/撤离 · Q 喝水 · F 绷带 · R 装填 · Tab 日志 · Esc 放弃",
		"choice_a": "抉择 A · 你是否还承认他是人",
		"a1": "冒险喂他阿司匹林与温水，等他醒来", "a2": "贴墙绕行，把他的哭声留给黑暗", "a3": "一撬棍让他安静，再搜走他的罐头",
	},
	"en": {
		"title": "Year of Z: Iron Winter", "subtitle": "Exploration Loop DEMO · Zero-Art Greybox · Godot 4 port",
		"tagline": "In Novorsk-17, a green teletype light proves the rations arrived; a stroke through a file number proves a person never lived.",
		"start": "Enter Room 602 (Start)", "help": "Controls", "logbook": "Logbook",
		"base_title": "Base · Khrushchyovka Block 3, Apt 602",
		"base_sub": "The dialysis machine counts the time Mother has left. By day you change her fluid; by night you climb through the boiler-room vent and ask what remains of you.",
		"map_title": "Novorsk-17 · Night Raid Target",
		"map_sub": "One location per night. You may carry back more than supplies—or leave someone's last breath behind. Choose who and what to bring, and whom to abandon.",
		"back_base": "Back to Room 602", "to_map": "Go to night map",
		"sleep": "Daytime: tend mother / rest until next night",
		"next_day": "Return to Room 602 (next day)",
		"status": "Status", "party": "Companion (1 per night)", "story": "Case Board",
		"stash": "Stash", "weapons": "Weapon Rack · firepower = what you found",
		"mother": "Mama Katya · Dialysis", "temp": "Core Temp", "conscience": "Conscience",
		"tally": "卌 Strokes", "truth": "Truth Alive", "day": "Day %d",
		"sortie": "Loadout", "depart": "Depart (Night Raid)", "danger": "Danger", "loot": "Spoils",
		"need": "Requires", "time": "Travel", "state": "State",
		"unexplored": "Unvisited", "scouted": "Scouted", "story_tag": "Story", "solo": "Go alone",
		"extracted": "EXTRACTED", "downed": "DOWNED · DRAGGED HOME", "dawn": "DAWN · FORCED RETREAT",
		"abort": "RAID ABORTED", "hp": "Health", "stam": "Stamina", "bpm": "BPM", "warmth": "Warmth",
		"search": "Searching…", "open_door": "Wedge this door", "extract_hint": "Extraction",
		"bag": "Pack", "wpn": "Weapon", "mini": "Map", "pack_full": "Pack is full",
		"unlocked": "Unlocked locations", "names": "Names on the back page", "events": "Event log",
		"objective": "Current objective", "haul": "Haul", "this_run": "This run",
		"events_report": "Events", "rack": "Weapon rack", "back_page": "Back page of the logbook",
		"containers": "Containers", "depart_ok": "Depart (Night Raid)", "locked": "Locked",
		"night": "Night", "left": "left", "game_over": "DEMO BOUNDARY · ACT IV",
		"ending_preview": "Ending preview", "restart": "Restart",
		"loaded": "Loaded", "stock": "stock", "mate_none": "Go alone",
		"raid_help": "WASD move · mouse aim · Ctrl crouch · Shift sprint · LMB/Space attack · hold E search/wedge/extract · Q drink · F bandage · R reload · Tab logbook · Esc abort",
		"choice_a": "CHOICE A · Do you still call him human?",
		"a1": "Risk aspirin and warm water; wait for him to wake", "a2": "Slip past and leave his crying to the dark", "a3": "Silence him with the crowbar, then take his tin",
	},
}

# 战利品分类的显示名
const CAT_NAMES := {
	"food": {"ic": "🌾", "zh": "食物", "en": "Food"},
	"med": {"ic": "💊", "zh": "医疗", "en": "Medical"},
	"scrap": {"ic": "🔩", "zh": "废料", "en": "Scrap"},
	"intel": {"ic": "📄", "zh": "情报", "en": "Intel"},
	"warm": {"ic": "🔥", "zh": "取暖", "en": "Warmth"},
	"part": {"ic": "🔫", "zh": "枪械零件", "en": "Gun parts"},
	"weapon": {"ic": "🔪", "zh": "武器", "en": "Weapons"},
	"val": {"ic": "💎", "zh": "值钱物", "en": "Valuables"},
}

# ============================================================================
# 查询工具（静态）
# ============================================================================
static func loc(id: String) -> Dictionary:
	for l in LOCS:
		if l["id"] == id:
			return l
	return {}

static func weapon(id: String) -> Dictionary:
	for w in WEAPONS:
		if w["id"] == id:
			return w
	return WEAPONS[0]

static func mate(id: String) -> Dictionary:
	for m in MATES:
		if m["id"] == id:
			return m
	return {}
