extends RefCounted
## LevelBeats.gd — 夜潜关卡「档案层」：关卡档案头、地标勘踏、环境节拍、专属机关。
##
## 前三张节点化地图（yard / marshalling / manor）共用 NightExplore.gd 这一个脚本，
## 玩法差异全部收在这张数据表里。场景仍然是 tools/art_gen 生成的 .tscn，
## 这里只描述「怎么导、怎么读、什么时候该发生什么」，不碰美术管线，也不新增资产。
##
## 三个键：
##   landmarks  —— 地标。走近半径内 → 电传机「勘踏」一行 + 右侧档案面板 +1。
##                 不奖励物资，只奖励「你看懂了这块地方」——这是本作的叙事货币。
##   events     —— 环境节拍（定时循环的压迫感，带预警窗口，玩家有应对手段）：
##                   * hump  西站驼峰溜放：预警 2.6s（远处汽笛 + 广播），随后一辆车皮
##                           沿着某一股道从东滑到西（3.0s）。站在那股道上会被刮倒
##                           （掉血 + 掉体温 + 巨响引来狂暴者）。扳道岔可以换股。
##                   * flare 2000℃ 炉口爆燃：预警 2.4s（炉膛发白），随后 1.6s 全院子被
##                           照亮 —— 站在炉口视线内且没蹲下 = 影子被钉在雪上，
##                           附近的清杀队会直接朝你这边压过来。蹲下 / 松林 / 车皮背后是安全的。
##   mechanisms —— 关卡专属机关（靠近按 E）：
##                   * switch   扳道岔：切换驼峰溜放的目标股道（也会发出巨响）
##                   * forklift 发动叉车：一次性的「巨型罐头」，引开 16m 内所有敌我
##
## 坐标一律是「米」：x 向东、y 向南（和 levels/*.py 的布局同一套）。

const DEFAULT_LANDMARK_R := 4.0


## 场景路径 → 关卡 id（战役地图卡用：LOCS[].scene 是唯一入口）
static func id_for_scene(path: String) -> String:
	for k in LEVELS.keys():
		if String(LEVELS[k].get("scene", "")) == path:
			return String(k)
	return ""


## 一句话环境节拍（出发前给玩家看的「这地方会怎么弄死你」）
static func environment_zh(b: Dictionary) -> String:
	var parts: Array[String] = []
	for e in b.get("events", []):
		match String(e.get("kind", "")):
			"hump":
				parts.append("驼峰溜放 · 每 %d 秒一辆车皮下来" % int(e.get("period", 30.0)))
			"flare":
				parts.append("炉口爆燃 · 每 %d 秒整院发白" % int(e.get("period", 26.0)))
	if parts.is_empty():
		return "没有环境节拍 —— 只有人和冷。"
	return "　·　".join(parts)


## 一句话机关（这张图上你能动的东西）
static func mechanisms_zh(b: Dictionary) -> String:
	var names: Array[String] = []
	for m in b.get("mechanisms", []):
		match String(m.get("kind", "")):
			"switch":
				names.append("扳道岔")
			"forklift":
				names.append("发动叉车")
	if names.is_empty():
		return ""
	return "可动机关：" + "、".join(names)


static func for_level(id: String) -> Dictionary:
	var base := {
		"code": "ДЕЛО № 0420 · НОЧНОЙ РЕЙД",
		"zone": "НОВОРСК-17 · ЖЕЛЕЗНАЯ ЗИМА",
		"stamp": "СССР · НАРКОМАТ ПУТЕЙ",
		"danger": 3,
		"accent": "8c1c14",
		"brief": [],
		"landmarks": [],
		"events": [],
		"mechanisms": [],
		"first_beat": 0.0,
	}
	var data: Dictionary = LEVELS.get(id, {})
	var out := base.duplicate(true)
	for k in data.keys():
		out[k] = data[k]
	# 强调色以十六进制字符串存在数据里（const 字典里只放常量表达式），这里转成 Color
	out["accent"] = Color(String(out.get("accent", "8c1c14")))
	return out


# ============================================================================
# 关卡档案
# ============================================================================
const LEVELS := {
	# ------------------------------------------------------------------------
	"yard": {
		"scene": "res://scenes/night_explore.tscn",
		"code": "ДЕЛО № 0420-А · СЕВЕРНЫЙ ДВОР",
		"zone": "НОВОРСК-17 · СЕВЕРНЫЙ ГРУЗОВОЙ ДВОР",
		"danger": 3,
		"accent": "8c1c14",
		"brief": [
			"赫鲁晓夫楼的院子里，雪被踩成一条硬路。",
			"三号闷罐车厢停在货场最南端的股道上 —— 门口有一只壮硕的。",
		],
		"landmarks": [
			{"name": "三号闷罐车厢", "pos": [34.0, 34.4], "radius": 5.5,
			 "note": "«Буран» 装甲列车 · 第三节。拉娜的档案号还在车门上。"},
			{"name": "锅炉房通风口", "pos": [7.0, 4.8], "radius": 3.2,
			 "note": "焊死的铁栅栏被你撬开过。今晚也能从这里钻回去。"},
			{"name": "院子里的油桶火堆", "pos": [24.0, 10.2], "radius": 3.0,
			 "note": "谁点的没人知道。它整夜都不灭。"},
			{"name": "水泥游乐穹顶", "pos": [12.5, 14.6], "radius": 3.5,
			 "note": "孩子们早就不来了。铁架上挂着冻硬的围巾。"},
		],
		"events": [],
		"mechanisms": [],
		"first_beat": 0.0,
	},

	# ------------------------------------------------------------------------
	"marshalling": {
		"scene": "res://scenes/night_marshalling.tscn",
		"code": "ДЕЛО № 1100 · ЗАПАДНЫЙ ПАРК",
		"zone": "НОВОРСК-17 · ЗАПАДНЫЙ СОРТИРОВОЧНЫЙ ПАРК",
		"danger": 4,
		"accent": "8c7139",
		"brief": [
			"五股道在脚下分开。道砟缝里的雪被风磨成了砂。",
			"驼峰那头每隔一会儿就放一辆车皮下来 —— 别站在股道上。",
		],
		"landmarks": [
			{"name": "调度塔", "pos": [30.0, 3.0], "radius": 4.5,
			 "note": "窗里有两盏灯：一台电传，一盏台灯。里面的人整夜都没睡。"},
			{"name": "驼峰溜放线", "pos": [20.0, 9.6], "radius": 4.5,
			 "note": "车皮从坡上滑下来，靠重力编组。站在股道上就是站在铁砧上。"},
			{"name": "煤水塔", "pos": [40.0, 31.4], "radius": 4.0,
			 "note": "水箱底下结着半米厚的冰。有人把复写件塞进了检修口。"},
			{"name": "南侧涵洞", "pos": [9.0, 34.0], "radius": 3.5,
			 "note": "铁丝网在这里被撕开。进出都走这儿 —— 清杀队也知道。"},
		],
		"events": [
			{"kind": "hump", "warn": 2.6, "live": 3.0, "period": 30.0,
			 "lane": 15.6, "lane_alt": 20.2, "from": 43.0, "to": 1.0, "shove": 9.0},
		],
		"mechanisms": [
			{"kind": "switch", "node": "World/Props/SwitchStand01", "label": "1 号转辙器",
			 "prompt": "扳 1 号转辙器（让溜放车换股）", "radius": 2.0},
			{"kind": "switch", "node": "World/Props/SwitchStand02", "label": "2 号转辙器",
			 "prompt": "扳 2 号转辙器（让溜放车换股）", "radius": 2.0},
		],
		"first_beat": 22.0,
	},

	# ------------------------------------------------------------------------
	"manor": {
		"scene": "res://scenes/night_manor.tscn",
		"code": "ДЕЛО № 409 · ОБЪЕКТ «ПИХТА»",
		"zone": "НОВОРСК-17 · ОБЪЕКТ «ПИХТА» · ЗОНА 2",
		"danger": 5,
		"accent": "5c2417",
		"brief": [
			"墙外 −35℃，墙里 26℃。松针上积的不是雪，是炉灰。",
			"2000℃ 的炉口每隔一会儿爆一次燃 —— 那一瞬间，整片院子亮得像白天。",
		],
		"landmarks": [
			{"name": "二号恒温库防爆门", "pos": [13.0, 3.4], "radius": 4.5,
			 "note": "门缝里漏出冷白的光。409 批腹透液就码在门前的托盘上。"},
			{"name": "2000℃ 炉口", "pos": [34.0, 4.6], "radius": 5.0,
			 "note": "「零过期损耗」。十五天的牛排和一个人的病历，走的是同一道炉门。"},
			{"name": "二楼行政钢廊", "pos": [12.0, 3.6], "radius": 4.5,
			 "note": "钢廊上一直有人走动。靴底敲在格栅上，像秒针。"},
			{"name": "冻观赏池", "pos": [33.0, 24.0], "radius": 5.0,
			 "note": "池底沉着一条锦鲤的红色。抄近路要踩过整面冰 —— 声音会一直传到墙那边。"},
			{"name": "西侧松林", "pos": [3.0, 17.5], "radius": 4.0,
			 "note": "松枝替这面墙挡了风，也替两个人挡过探照灯。"},
		],
		"events": [
			{"kind": "flare", "warn": 2.4, "live": 1.6, "period": 26.0,
			 "pos": [34.0, 4.6], "radius": 22.0},
		],
		"mechanisms": [
			{"kind": "forklift", "node": "World/Props/Forklift", "label": "停着的叉车",
			 "prompt": "发动叉车（引开他们）", "radius": 2.8},
		],
		"first_beat": 18.0,
	},

	# ------------------------------------------------------------------------
	"mine": {
		"scene": "res://scenes/night_mine.tscn",
		"code": "ДЕЛО № 004 · ШАХТА №3",
		"zone": "НОВОРСК-17 · ШАХТА №3 · ЗАБОЙ",
		"danger": 5,
		"accent": "5c7d6e",
		"brief": [
			"温压爆破把永冻层整层掀开了。断面上那条灰黑色的带子是远古孢子粉尘 —— 灰鳞病是他们自己炸出来的。",
			"铝热剂码在断面根上。起爆器旁的台账记着他们炸开了什么 —— 任务代号「净账」。",
		],
		"landmarks": [
			{"name": "爆破断面", "pos": [36.5, 28.4], "radius": 5.0,
			 "note": "千层糕一样的冻土剖面。中间那条灰黑带子发暗光 —— 不是魔法，是粉尘。"},
			{"name": "起爆器与铝热剂堆", "pos": [29.5, 26.8], "radius": 4.0,
			 "note": "军用起爆箱、手摇柄、电缆盘。旁边的装药堆码得整齐得可怕。"},
			{"name": "假人哨塔", "pos": [38.5, 13.4], "radius": 4.5,
			 "note": "远看是哨位，近看是穿防化服的塑料模特。扩音器还在广播，灯一盏也没有。"},
			{"name": "斜井坑口", "pos": [7.5, 5.0], "radius": 4.0,
			 "note": "坑木支护的门脸，洞里有钠灯的暖光。运矸专线从这里出来，博伊科还守在里面。"},
		],
		"events": [],
		"mechanisms": [],
		"first_beat": 0.0,
	},
	"coldstore": {
		"scene": "res://scenes/night_coldstore.tscn",
		"code": "ДЕЛО № 0892 · ХОЛОДИЛЬНИК №4",
		"zone": "НОВОРСК-17 · СЕВЕРНЫЙ РАЙОН · ХОЛОДИЛЬНИК № 4",
		"danger": 2,
		"accent": "8ab0d0",
		"brief": [
			"白昼段侦察：城北四号铁路冷库。磁卡终端的红字说，当前南库坐标在册人数 0。",
			"可 3 号立柱后面有活人的呼吸。账面上全是死人 —— 活人不在这本账上。",
		],
		"landmarks": [
			{"name": "磁卡终端", "pos": [14.5, 5.2], "radius": 3.0,
			 "note": "红字：【档案 0892：已于昨日 22:00 移交乌拉尔山线站。当前南库坐标在册人数：0】。配给箱的电子锁已经锁死。"},
			{"name": "南库 3 号立柱", "pos": [25.0, 23.5], "radius": 4.0,
			 "note": "柱后缩着被转运车遗落、冻得濒死的谢尔盖与玛丽亚母子。半块黑面包，一双查无此人的通行证。"},
			{"name": "北雨棚排水窄缝", "pos": [33.5, 3.9], "radius": 3.0,
			 "note": "12 厘米。那截袖子消失在这里。只有痕迹：刮烂的铝饭盒、抓痕。不抱幻想。"},
			{"name": "冷库铁门", "pos": [37.5, 23.6], "radius": 2.6,
			 "note": "滑门还能拉。用撬棍卡死它 —— 把它们引过去（机关）。"},
			{"name": "封存医疗耗材箱", "pos": [11.5, 25.2], "radius": 2.6,
			 "note": "钢印封条完好。真药到底在哪？一半的答案在黑市的盘尼西林摊，另一半冻在这里。"},
		],
		"events": [],
		"mechanisms": [
			{"kind": "wedge", "node": "World/Props/ColdVaultDoor", "label": "冷库铁门",
			 "prompt": "用撬棍卡死铁门（把它们引过去）", "radius": 2.6},
		],
		"first_beat": 0.0,
	},
	"sanitarium": {
		"scene": "res://scenes/night_sanitarium.tscn",
		"code": "ДЕЛО № 0419 · САНАТОРИЙ",
		"zone": "НОВОРСК-17 · СТАРАЯ ДОРОГА · ПОДЗЕМНЫЙ ЭТАЖ САНАТОРИЯ",
		"danger": 4,
		"accent": "6a8f9c",
		"brief": [
			"旧传染病疗养院的地下室。第四天夜里，退烧的人开始掉鳞屑——灰鳞病在回退，账本不许它回退。",
			"铁笼区最里面，档案号 0419 的姑娘用两根旧皮带把自己捆在铁架床栏杆上，熬过了最后一次神经风暴。",
		],
		"landmarks": [
			{"name": "铁架床与皮带", "pos": [23.0, 5.0], "radius": 2.6,
			 "note": "安娜（0419）的铁架床：两根旧皮带缠在栏杆上，磨得发亮。她把自己捆在这里熬过了第四天。"},
			{"name": "笼3 回退半人", "pos": [31.0, 6.2], "radius": 2.4,
			 "note": "掉鳞屑、瞳孔正在回色的活标本。灰鳞病会自己回退——这件事正在铁栏后面发生。"},
			{"name": "药柜", "pos": [10.0, 23.5], "radius": 2.2,
			 "note": "医生工作区的钢制药柜。里面还有半片阿司匹林的同类（guaranteed asp）。"},
			{"name": "换气铁窗", "pos": [22.0, 3.0], "radius": 3.0,
			 "note": "贴近路基的带栏高窗。头顶「铁壳号」过弯时，闷罐车厢里退烧的人把病历单往雪地里抛。"},
			{"name": "笼区铁栅门", "pos": [22.0, 11.0], "radius": 2.4,
			 "note": "对开栅门 + 插销。撬棍能把它卡死（机关）——把没熬过的人关在里面。"},
		],
		"events": [],
		"mechanisms": [
			{"kind": "wedge", "node": "World/Props/CageGate", "label": "笼区铁栅门",
			 "prompt": "用撬棍卡死笼区铁栅门（把它们关在里面）", "radius": 2.4},
		],
		"first_beat": 0.0,
	},
	"canteen": {
		"scene": "res://scenes/night_canteen.tscn",
		"code": "ДЕЛО № 0019 · ВОСТОЧНАЯ СТОЛОВАЯ",
		"zone": "НОВОРСК-17 · УЛИЦА ВОСТОЧНАЯ · РАБОЧАЯ СТОЛОВАЯ",
		"danger": 3,
		"accent": "b87333",
		"brief": [
			"账面已清空的东街危楼。可楼里还有十九只碗——十九个没被清账的老铁路工。",
			"备餐台的砧板上插着那把砍骨刀。窄门后面，有什么东西烧到了四十度。",
		],
		"landmarks": [
			{"name": "备餐台砧板", "pos": [24.0, 8.2], "radius": 3.0,
			 "note": "宽背生锈砍骨刀插在油腻砧板上。刀刃有豁口，柄上是黑麦糊和血的混合干渍。"},
			{"name": "十九只碗", "pos": [22.0, 25.0], "radius": 5.0,
			 "note": "长条桌上十九只搪瓷碗，缺口朝外摆成一圈。账面说这楼清空了——碗不同意。"},
			{"name": "杂物间窄门", "pos": [32.0, 4.6], "radius": 2.4,
			 "note": "单向门，门框新裂。里面 40 度高烧的瓦西里在撞。撬棍能把它卡死（机关）。"},
			{"name": "黑麦糊桶", "pos": [18.0, 9.8], "radius": 2.6,
			 "note": "送来的黑麦糊还温着。十九个老铁路工的晚饭。"},
			{"name": "独眼老炊事员的灶", "pos": [12.0, 5.0], "radius": 2.8,
			 "note": "费奥多尔守着灶。他儿子在窄门后面烧了两天，今天夜里会冲出来。"},
		],
		"events": [],
		"mechanisms": [
			{"kind": "wedge", "node": "World/Props/NarrowDoor", "label": "杂物间窄门",
			 "prompt": "用撬棍卡住窄门（别让他冲出来）", "radius": 2.4},
		],
		"first_beat": 0.0,
	},
	"market": {
		"scene": "res://scenes/night_market.tscn",
		"code": "ДЕЛО № 0666 · БАРАХОЛКА",
		"zone": "НОВОРСК-17 · ЗАБРОШЕННЫЙ РАБОЧИЙ ПОСЁЛОК · БАРАХОЛКА",
		"danger": 2,
		"accent": "c98a3e",
		"brief": [
			"拿东西换东西。别相信任何人递过来的手。",
			"最深的棚子上架着一台短波收音机，指针钉死在 6.66。那个女声昼夜循环卖「特效退烧散」—— 那是清杀队的鱼钩。",
		],
		"landmarks": [
			{"name": "6.66 电台棚", "pos": [36.5, 25.0], "radius": 4.5,
			 "note": "老式短波收音机，指针钉死在 6.66。女声说喝下去立竿见影 —— 那是防冻液。"},
			{"name": "烫鳞后巷", "pos": [7.0, 24.9], "radius": 4.0,
			 "note": "炭炉上烧着一枚马蹄铁。赤脚医生把它按在病人的手背上，把灰鳞烫死。收费三罐罐头。"},
			{"name": "药棚铁门", "pos": [12.0, 23.2], "radius": 4.0,
			 "note": "真正的盘尼西林锁在门里。老谢苗守在门外 —— 清杀队的哨兵也在门外。"},
			{"name": "市集摊区", "pos": [24.5, 24.4], "radius": 5.0,
			 "note": "马灯下的一罐换八发。摊主比清杀队讲道理，但也只讲一点。"},
		],
		"events": [],
		"mechanisms": [],
		"first_beat": 0.0,
	},
}
