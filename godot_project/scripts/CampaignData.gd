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
		"time": 60, "cold": 0.4, "story": "", "req": {}, "req_flag": ""},
	{"id": "coldstore", "x": 150, "y": 120, "dg": 2, "seed": 2202,
		"zh": "城北四号铁路冷库", "en": "Rail Cold Storage No.4",
		"loot": ["med", "food"],
		"hint_zh": "据说封着一批医疗耗材，也冻死过人。", "hint_en": "Sealed medical stock, and people who froze beside it.",
		"hint2_zh": "南库 3 号柱后有活人。冷库铁门可以撬棍卡死。",
		"hint2_en": "There are living people behind column 3. Cold-store doors can be wedged.",
		"time": 80, "cold": 0.9, "story": "coldstore", "req": {}, "req_flag": ""},
	{"id": "yard", "x": 340, "y": 215, "dg": 3, "seed": 3303,
		"zh": "夜间广轨货场", "en": "Broad-Gauge Freight Yard",
		"loot": ["scrap", "intel"],
		"hint_zh": "编组表和废件堆都在那，灯也最亮。", "hint_en": "Marshalling slips and scrap piles. Also the brightest lights.",
		"hint2_zh": "两座煤水塔可躲探照灯；清杀队 2 人一组巡逻。",
		"hint2_en": "Two water towers break the searchlights; purge squads patrol in pairs.",
		"time": 90, "cold": 1.0, "story": "yard", "req": {}, "req_flag": ""},
	{"id": "underpass", "x": 330, "y": 410, "dg": 2, "seed": 4404,
		"zh": "铁道下穿积冰道", "en": "Icy Rail Underpass",
		"loot": ["scrap", "warm"],
		"hint_zh": "黑冰很滑，声音会传得很远。有人在这儿烧火。", "hint_en": "Black ice is loud. Someone keeps a fire burning here.",
		"hint2_zh": "涉雪泥移动 ×0.65，噪声 ×2.0；火堆可回温。",
		"hint2_en": "Slush: speed ×0.65, noise ×2.0. The brazier restores warmth.",
		"time": 70, "cold": 1.3, "story": "", "req": {}, "req_flag": ""},
	{"id": "canteen", "x": 510, "y": 330, "dg": 3, "seed": 5505,
		"zh": "东街工人食堂 · 后厨", "en": "East Street Canteen · Kitchen",
		"loot": ["weapon", "food"],
		"hint_zh": "账面已清空的老楼，可里面还有十九只碗。", "hint_en": "Written off as empty. Nineteen bowls still inside.",
		"hint2_zh": "备餐台砧板上插着砍骨刀；窄门会被冲开。",
		"hint2_en": "A cleaver stands in the prep-table block; the narrow door can be breached.",
		"time": 90, "cold": 0.5, "story": "canteen", "req": {}, "req_flag": ""},
	{"id": "sanitarium", "x": 650, "y": 130, "dg": 4, "seed": 6606,
		"zh": "旧传染病疗养院 · 地下室", "en": "Old Sanatorium · Basement",
		"loot": ["med"],
		"hint_zh": "有人被皮带捆在铁架床上熬过了第四天。", "hint_en": "Someone was belted to a bed frame and survived the fourth day.",
		"hint2_zh": "地底铁笼区。需要至少 1 份医疗物资与 2 份情报线索。",
		"hint2_en": "Cage level. Needs 1 medical item and 2 intel leads.",
		"time": 110, "cold": 0.8, "story": "sanitarium", "req": {"intel": 2, "med": 1}, "req_flag": ""},
	{"id": "market", "x": 670, "y": 275, "dg": 2, "seed": 7707,
		"zh": "铁路黑市（废弃工人镇）", "en": "Rail Black Market",
		"loot": ["intel", "val"],
		"hint_zh": "拿东西换东西。别相信任何人递过来的手。", "hint_en": "Goods for goods. Never trust the hand that offers.",
		"hint2_zh": "人会开枪，但比清杀队讲道理。可交易情报。",
		"hint2_en": "People shoot, but they argue first. Intel can be traded.",
		"time": 80, "cold": 0.9, "story": "market", "req": {}, "req_flag": ""},
	{"id": "manor", "x": 835, "y": 95, "dg": 5, "seed": 8808,
		"zh": "松林庄园 · 二号恒温库", "en": "Pine Manor · Depot No.2",
		"loot": ["med", "val"],
		"hint_zh": "墙外 −35℃，墙里 26℃。409 批腹透液就在那儿。", "hint_en": "-35°C outside, 26°C inside. The Batch-409 fluid is in there.",
		"hint2_zh": "电网高墙 + 特勤值守。被发现基本等于死。",
		"hint2_en": "Electric fence, private guards. Seen means dead.",
		"time": 120, "cold": 0.3, "story": "manor", "req": {}, "req_flag": "manor_tip"},
	{"id": "marshalling", "x": 800, "y": 390, "dg": 4, "seed": 9909,
		"zh": "西站调车场", "en": "West Station Marshalling Yard",
		"loot": ["part", "intel"],
		"hint_zh": "报废守车里有零件，调度室外贴着今晚的发车令。",
		"hint_en": "Parts in the dead brake vans; tonight's dispatch order pinned outside.",
		"hint2_zh": "机车水箱里可能塞着手稿复写件。",
		"hint2_en": "Manuscript carbons might be stuffed in a tender toolbox.",
		"time": 100, "cold": 1.1, "story": "marshalling", "req": {}, "req_flag": "lana_car3"},
	{"id": "birch", "x": 620, "y": 470, "dg": 1, "seed": 1212,
		"zh": "白桦林废弃板房", "en": "Birch Grove Shacks",
		"loot": ["warm", "scrap"],
		"hint_zh": "风小，能捡到柴。偶尔有逃出来的人躲在这儿。",
		"hint_en": "Sheltered. Firewood, and sometimes people who ran.",
		"hint2_zh": "低风险补给点，适合缺体温的夜里。",
		"hint2_en": "Low-risk resupply. Good when you are freezing.",
		"time": 60, "cold": 1.5, "story": "", "req": {}, "req_flag": ""},
	{"id": "workshop", "x": 480, "y": 130, "dg": 2, "seed": 6606,
		"zh": "机修车间", "en": "Machine Workshop",
		"loot": ["scrap", "part"],
		"hint_zh": "车床边散落着零件，焊机还能打着火。",
		"hint_en": "Parts by the lathes; the welder still sparks.",
		"hint2_zh": "车间里工具多，但巡逻队常来查。",
		"hint2_en": "Plenty of tools — and patrols check in often.",
		"time": 70, "cold": 0.8, "story": "", "req": {}, "req_flag": ""},
	{"id": "greenhouse", "x": 480, "y": 470, "dg": 1, "seed": 7707,
		"zh": "温室大棚", "en": "Greenhouse",
		"loot": ["food", "warm"],
		"hint_zh": "塑料布还算严实，冻土里埋着去年的土豆。",
		"hint_en": "The plastic still holds; last year's potatoes are in the frozen soil.",
		"hint2_zh": "低风险食物点，适合缺粮的夜里。",
		"hint2_en": "Low-risk food. Good when you are hungry.",
		"time": 60, "cold": 0.6, "story": "", "req": {}, "req_flag": ""},
	{"id": "archive", "x": 920, "y": 250, "dg": 3, "seed": 8808,
		"zh": "档案馆电报局", "en": "Archive & Telegraph Office",
		"loot": ["intel", "val"],
		"hint_zh": "旧电报和花名册都在，值钱的情报也在。",
		"hint_en": "Old telegrams and rosters — and valuable intel.",
		"hint2_zh": "高风险：清杀队重点盯防的情报点。",
		"hint2_en": "High risk: an intel site the purge squads watch closely.",
		"time": 90, "cold": 0.7, "story": "", "req": {}, "req_flag": ""},
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
		"lines": [
			{"w": "", "zh": "南库 3 号柱后，一个男人正把儿子裹进自己的棉袄里。他们的通行证在终端上跳出刺眼的红字：",
				"en": "Behind column 3 in the south hall, a man is wrapping his son inside his own padded coat. The terminal spits red:"},
			{"w": "切尔诺夫中士", "zh": "档案 0892：已于昨日 22:00 移交乌拉尔山线站。当前坐标在册人数：0。",
				"en": "File 0892: transferred to the Ural line yesterday at 22:00. Persons at this coordinate: 0."},
			{"w": "", "zh": "配给箱的电子锁「咔」地锁死了。男人没有抬头，只是在结冰的地上摸索掉落的两粒黑麦。",
				"en": "The ration crate's lock snaps shut. The man does not look up; he only feels in the ice for two spilled grains of buckwheat."},
			{"w": "", "zh": "收发亭旁，一只脖颈勒着断铁丝的灰狼犬盯着你手里的半块冷黑麦饼。",
				"en": "By the dispatch hut, a wolfdog with a snapped wire collar stares at the half loaf of cold rye in your hand."},
		],
		"choices": [
			{"zh": "在《工作日志》背面写下：谢尔盖、玛丽亚，活人",
				"en": "Write in the logbook: Sergey & Maria, alive",
				"d_zh": "良知 ▲ · 记录一条真实姓名", "d_en": "Conscience ▲ · one real name survives",
				"cls": "good",
				"ops": [["name", "Сергей, Мария · 谢尔盖与玛丽亚"], ["conscience", 8], ["add", "scrap", 1]],
				"after_mate": "ash",
				"toast_zh": "钢笔划过纸面：又一条真名留下了。「灰烬」把前爪按在你靴子上。",
				"toast_en": "The pen scratches: another real name survives. Ash plants a paw on your boot."},
			{"zh": "什么也不写，低头搬你的箱子", "en": "Write nothing. Keep hauling crates.",
				"d_zh": "中立 · 省下麻烦", "d_en": "Neutral · save yourself the trouble",
				"cls": "",
				"ops": [["add", "scrap", 2]],
				"after_mate": "ash",
				"toast_zh": "你数完了箱子。你没数他们。「灰烬」还是跟了上来。",
				"toast_en": "You counted the crates. You did not count them. Ash follows anyway."},
		],
	},
	"yard": {
		"title_zh": "铁壳号的编组单", "title_en": "The Buran Consist",
		"lines": [
			{"w": "", "zh": "煤水塔的阴影里，一张被雪水泡烂的编组单贴在调度箱背面：",
				"en": "In the water tower's shadow, a consist sheet rots against the back of a switch box:"},
			{"w": "", "zh": "【布拉风号 · 第 7 次特别运输 · 闷罐车厢 03 · 编号 0401—0576 · 终点：乌拉尔鹰嘴崖】",
				"en": "[BURAN · Special Run 7 · Boxcar 03 · Files 0401–0576 · Terminus: Eagle's Crag, Urals]"},
			{"w": "", "zh": "你把单子折好塞进内袋。妹妹的档案号是 0420——就在这个区间里。",
				"en": "You fold it into your inner pocket. Lana is 0420. She is inside that range."},
		],
		"choices": [
			{"zh": "收好编组单（+1 情报）", "en": "Pocket the consist (+1 Intel)",
				"d_zh": "主线推进", "d_en": "Story lead", "cls": "good",
				"ops": [["add", "intel", 1]],
				"after_mate": "",
				"toast_zh": "编组单贴着你的肋骨。0420 就在那一节车厢里。",
				"toast_en": "The consist sits against your ribs. 0420 is in that car."},
		],
	},
	"canteen": {
		"title_zh": "锁骨里的砍骨刀", "title_en": "The Cleaver in the Collarbone",
		"lines": [
			{"w": "", "zh": "后厨杂物间的木门炸裂。炊事员的儿子瓦西里在 40℃ 谵妄里冲了出来，眼白是紫黑的。",
				"en": "The pantry door explodes. Vasily, the cook's son, comes out in 40°C delirium, sclera black-purple."},
			{"w": "", "zh": "你被逼到备餐台死角，手摸到砧板上那把宽背砍骨刀。",
				"en": "Cornered against the prep table, your hand finds the heavy-backed cleaver in the block."},
			{"w": "费奥多尔老爹", "zh": "……阿廖沙！他昨天还给四楼送饼——！",
				"en": "…Alyosha! He was delivering bread to the fourth floor yesterday!"},
		],
		"choices": [
			{"zh": "一刀劈进左锁骨窝", "en": "Swing into the left collarbone",
				"d_zh": "自卫击杀，不记划痕", "d_en": "Self-defence · no tally stroke", "cls": "",
				"ops": [["flag", "ptsd"], ["flag", "vasily"], ["add", "blade", 1], ["conscience", -4]],
				"after_mate": "pavel",
				"toast_zh": "刀卡在骨缝里。他的瞳孔回色了，吐出半个词：「……Пить（渴）……」帕维尔老爹替你修好了撬棍。",
				"toast_en": "The blade jams. His pupils clear and he breathes half a word: \"…Пить (Thirsty)…\" Old Pavel straightens your crowbar."},
		],
	},
	"market": {
		"title_zh": "老轨伊万", "title_en": "Old Ivan, the Railman",
		"lines": [
			{"w": "", "zh": "黑市的铁皮棚下，跑了二十年西伯利亚专列的老列车长吐掉烟头，把一张油纸拍在你胸口。",
				"en": "Under the market's tin awning, the conductor who ran Siberian trains for twenty years spits out his cigarette and slaps an oil-paper note on your chest."},
			{"w": "老轨伊万", "zh": "今晚十一点，不挂车次牌的铁壳号走鹰嘴崖线。第三节车厢里一百七十六个已经退烧的活人，拉进 3 号矿坑填埋。你要不要爬车？",
				"en": "Eleven tonight: an unnumbered Buran takes the Eagle's Crag line. One hundred seventy-six recovered people in Boxcar 3, dumped in Pit No.3. You climbing or not?"},
		],
		"choices": [
			{"zh": "C1 公平交易：付 2 废钢买路线（中立）", "en": "C1 Fair trade: pay 2 Scrap for the route",
				"d_zh": "情报 +1 · 解锁松林庄园线索", "d_en": "Intel +1 · unlocks the Pine Manor lead",
				"cls": "good",
				"ops": [["take", "scrap", 2], ["add", "intel", 1], ["flag", "manor_tip"]],
				"after_mate": "",
				"toast_zh": "伊万把路线画在油纸上：走水塔下的检修沟，别踩第三根枕木。",
				"toast_en": "Ivan sketches the route on the oil paper: use the maintenance trench under the water tower; skip the third sleeper."},
			{"zh": "C3 倾囊相助：把抗生素分给这里冻伤的人（良知▲）",
				"en": "C3 Give everything: hand out your antibiotics",
				"d_zh": "良知 ▲▲ · 伊万入队 · 解锁松林庄园", "d_en": "Conscience ▲▲ · Ivan joins · unlocks Pine Manor",
				"cls": "good",
				"ops": [["take", "abx", 1], ["conscience", 10], ["flag", "manor_tip"], ["mate", "ivan"]],
				"after_mate": "ivan",
				"toast_zh": "「老轨」伊万入队。他把一只冻僵的手套塞给你。",
				"toast_en": "Old Ivan joins your crew. He shoves a frozen glove into your hands."},
			{"zh": "C2 背叛：趁他引开哨兵，锁死铁门拿走磁卡（良知▼·卌+1）",
				"en": "C2 Betray: lock the door and take the keycard",
				"d_zh": "物资暴涨 · 卌 +1", "d_en": "Huge haul · tally +1", "cls": "bad",
				"ops": [["add", "abx", 2], ["add", "scrap", 3], ["add", "dial", 1],
					["tally", 1], ["conscience", -14], ["flag", "manor_tip"], ["flag", "betrayed"]],
				"after_mate": "",
				"toast_zh": "铁门在你身后合上。枪声很短。",
				"toast_en": "The door shuts behind you. The shots are very short."},
		],
	},
	"sanitarium": {
		"title_zh": "0419 号在呼吸", "title_en": "0419 Is Breathing",
		"lines": [
			{"w": "", "zh": "最深处的钢筋铁笼前，一个年轻姑娘用两根旧皮带把自己死死捆在铁架床栏杆上。",
				"en": "At the deepest cage, a young woman has belted her own wrists to the bed frame with two old straps."},
			{"w": "", "zh": "「灰烬」走上去，摇着尾巴用湿鼻尖碰了碰她的手背。她抬起头——眼白充血已退，神智完全清醒。",
				"en": "Ash walks up, tail low, and touches the back of her hand with a wet nose. The girl looks up — the blood has receded from her eyes. She is fully awake."},
			{"w": "安娜（0419）", "zh": "是拉娜！！三天前她就关在我隔壁！她的烧退到三十六度八了，手背的灰鳞都在掉！昨天夜里，他们把她和一百多个退烧的人锁进了铁壳号——第三节闷罐车厢！！",
				"en": "It's Lana!! Three days ago she was in the cage next to mine! Her fever broke at 36.8°C, the scales were falling off her hands! Last night they locked her and a hundred others into the Buran — Boxcar No.3!!"},
		],
		"choices": [
			{"zh": "撬开铁笼，带她们走（消耗 1 份医疗物资）", "en": "Pry the cage. Bring them out. (-1 medical)",
				"d_zh": "安娜 + 古丽娅 入队 · 解锁西站调车场", "d_en": "Anna + Dr. Gulya join · unlocks the marshalling yard",
				"cls": "good",
				"ops": [["mate", "anna"], ["mate", "gulya"], ["conscience", 6],
					["flag", "lana_car3"], ["flag", "manor_tip"]],
				"after_mate": "",
				"toast_zh": "安娜（0419）与古丽娅医师入队。铁笼的门轴在雪里尖叫。",
				"toast_en": "Anna (0419) and Dr. Gulya join. The cage hinge screams in the snow."},
		],
	},
	"manor": {
		"title_zh": "焦油黑雪", "title_en": "Tar-Black Snow",
		"lines": [
			{"w": "", "zh": "墙外零下三十五度，墙里二十六度。叉车把仅仅「临期十五天」的牛排、黄油和 409 批腹透液整铲推进 2000℃ 的焚化炉。",
				"en": "-35°C outside the wall, 26°C inside. A forklift shoves beef, butter and Batch-409 dialysis fluid — \"fifteen days past date\" — into a 2000°C furnace."},
			{"w": "", "zh": "烟囱喷出的黑烟混着大雪，飘向下风口两公里外的工人居住区。那就是「焦油黑雪」——闻着有烤肉脂香，抓进嘴里全是烧塑料的油垢。",
				"en": "The stack vomits black smoke into the snow and drifts two kilometres downwind to the workers' blocks. That is the tar-black snow: it smells like roast fat and tastes like burnt plastic."},
			{"w": "", "zh": "你举起相机，按下了快门。",
				"en": "You raise the camera and press the shutter."},
		],
		"choices": [
			{"zh": "拍下焚毁台账，带走腹透液", "en": "Photograph the ledger. Take the fluid.",
				"d_zh": "腹透液 +2 · 真相存活 · 母亲好转", "d_en": "Fluid +2 · truth survives · mother stabilises",
				"cls": "good",
				"ops": [["add", "dial", 2], ["add", "photo", 1], ["flag", "truth"], ["conscience", 5]],
				"after_mate": "",
				"toast_zh": "快门声像一声枪响。你把 409 批腹透液塞进背包。",
				"toast_en": "The shutter sounds like a gunshot. You stuff Batch-409 into your pack."},
		],
	},
	"marshalling": {
		"title_zh": "十一点的发车令", "title_en": "The 23:00 Dispatch Order",
		"lines": [
			{"w": "", "zh": "调度室外的铁皮板上钉着一张还没撕的发车令，红章新鲜得发黏。",
				"en": "A dispatch order is still pinned to the board outside the control room, the red stamp still tacky."},
			{"w": "", "zh": "【特别运输 · 不挂车次牌 · 23:00 · 鹰嘴崖线 · 第三节车厢 176 人 · 实毁数与账面数必须闭合】",
				"en": "[SPECIAL RUN · NO TRAIN NUMBER · 23:00 · EAGLE'S CRAG LINE · BOXCAR 3 · 176 PERSONS · PHYSICAL COUNT MUST EQUAL LEDGER]"},
			{"w": "", "zh": "你把红章的位置拍了下来。报废守车的工具箱里，躺着几块能拼成一支枪的钢件。",
				"en": "You photograph the stamp. In a dead brake van's toolbox lie the steel pieces of a gun."},
		],
		"choices": [
			{"zh": "拆走零件，抄下车次时刻", "en": "Strip the parts, copy the timetable",
				"d_zh": "猎枪零件 +1 · 情报 +1 · 终局预告", "d_en": "Shotgun part +1 · Intel +1 · endgame revealed",
				"cls": "good",
				"ops": [["add", "intel", 1], ["flag", "endgame_known"]],
				"after_mate": "",
				"toast_zh": "23:00。鹰嘴崖。一百七十六人。你终于知道了全部数字。",
				"toast_en": "23:00. Eagle's Crag. One hundred seventy-six. You finally know every number."},
		],
	},
}

# ============================================================================
# TEXT — UI 文案
# ============================================================================
const TEXT := {
	"zh": {
		"title": "《Z年纪事：凛冬铁轨》", "subtitle": "探索循环 DEMO · 无美术灰盒 · GODOT 4 移植版",
		"tagline": "在诺沃斯克-17，电传机亮绿灯即为温饱，档案号划掉即为清零。",
		"start": "进入 602 室（开始）", "help": "操作说明", "logbook": "工作日志",
		"base_title": "据点 · 第3居住区 赫鲁晓夫楼 602 室",
		"base_sub": "白昼的锚。母亲的透析机还在响，夜里你要翻出锅炉房气窗。",
		"map_title": "诺沃斯克-17 · 夜潜目标选择",
		"map_sub": "每夜只能去一处。情报越少，风险越高——先想清楚带谁、带什么、还剩多少时间到天亮。",
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
		"choice_a": "抉择 A · 风雪里伸出的那只手",
		"a1": "冒险喂阿司匹林与温水", "a2": "贴墙绕行，省下药水", "a3": "一撬棍灭口并搜走罐头",
	},
	"en": {
		"title": "Year of Z: Iron Winter", "subtitle": "Exploration Loop DEMO · Zero-Art Greybox · Godot 4 port",
		"tagline": "In Novorsk-17, when the teletype lights up green, everyone is fed; when a file number is crossed out, the person is zeroed.",
		"start": "Enter Room 602 (Start)", "help": "Controls", "logbook": "Logbook",
		"base_title": "Base · Khrushchyovka Block 3, Apt 602",
		"base_sub": "The daytime anchor. Mother's dialysis machine is still beeping; at night you pry open the boiler-room vent.",
		"map_title": "Novorsk-17 · Night Raid Target",
		"map_sub": "One location per night. Less intel = more risk. Decide who and what you bring.",
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
		"choice_a": "CHOICE A · The hand reaching out of the blizzard",
		"a1": "Feed aspirin + warm water", "a2": "Bypass along the wall", "a3": "Silence him with the crowbar",
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
