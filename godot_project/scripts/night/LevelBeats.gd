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
}
