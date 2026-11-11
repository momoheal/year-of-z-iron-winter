extends SceneTree
## Headless smoke test for the multi-level night pipeline (P4).
## Run:  Godot_v4.7.2-stable_win64_console.exe --headless --path godot_project -s tests/night_level_smoke.gd
##
## 覆盖：
##   * 战役里每个带 scene 字段的地点，场景文件都得在（CampaignData 是唯一数据源）
##   * yard（night_explore.tscn）现在也带关卡 metadata，且资产指向 yard 那套大图
##   * marshalling（night_marshalling.tscn）：节点装配 / 容器口径（发车令=intel、守车=零件）/
##     脚步材质（五股道 = 铁轨声）/ 冻雪泥 / 铁丝网豁口 / 镜头边界 / 环境音 / 天亮窗口
##   * 两关共用同一个 NightExplore：音效库、震动、后处理 dawn 参数都在
##
## 关卡结构本身的静态体检（manifest ↔ 场景 ↔ 规格三层对表）在
## tools/art_gen/check_levels.py，沙箱里不用 Godot 也能跑。

var passes: int = 0
var failures: Array[String] = []

const PPM := 64.0
const GY := 39.68
const Data := preload("res://scripts/CampaignData.gd")

func _init() -> void:
	_run.call_deferred()

func _assert(cond: bool, n: String, detail: String = "") -> void:
	if cond:
		passes += 1
		print("  PASS  ", n)
	else:
		failures.append(n + ((" — " + detail) if detail != "" else ""))
		print("  FAIL  ", n, "  ", detail)

func _m(x: float, y: float) -> Vector2:
	return Vector2(x * PPM, y * GY)

func _scene(path: String) -> Node:
	for c in root.get_children():
		if c.name == "NightExplore":
			root.remove_child(c)
			c.free()
	var s: Node = (load(path) as PackedScene).instantiate()
	root.add_child(s)
	return s

func _run() -> void:
	print("== night_level_smoke ==")
	_registry()
	_yard()
	_marshalling()
	_manor()
	_mine()
	_market()
	_coldstore()
	_canteen()
	_sanitarium()
	print("== RESULT: %d passed, %d failed ==" % [passes, failures.size()])
	for f in failures:
		print("   FAILED: ", f)
	if failures.size() > 0:
		quit(1)
	quit(0)

# ---------------------------------------------------------------------------
func _registry() -> void:
	var with_scene := 0
	for L in Data.LOCS:
		var sc: String = String(L.get("scene", ""))
		if sc == "":
			continue
		with_scene += 1
		_assert(ResourceLoader.exists(sc), "LOCS[%s].scene 存在 (%s)" % [L.id, sc])
	_assert(with_scene >= 8, "至少八关有节点化场景（yard/marshalling/manor/mine/market/coldstore/canteen/sanitarium）", str(with_scene))
	# 每个带 scene 的地点：CampaignData 的 loot 类别都得在表里（夜潜掉落读同一张表）
	for L in Data.LOCS:
		for cat in L.loot:
			_assert(Data.LOOT_CATS.has(cat), "LOCS[%s] 的 loot 类别 %s 在 LOOT_CATS 里" % [L.id, cat])

# ---------------------------------------------------------------------------
func _yard() -> void:
	var y: Node = _scene("res://scenes/night_explore.tscn")
	_assert(y.level_id == "yard", "yard metadata.level_id", y.level_id)
	_assert(y.level_zh == "夜间广轨货场", "yard metadata.level_zh", y.level_zh)
	_assert(y.level_en == "Broad-Gauge Freight Yard", "yard metadata.level_en", y.level_en)
	_assert(y.prize == "dial", "yard prize = dial", y.prize)
	_assert(y.rail_y == [26.0, 33.0], "yard rail_y 元数据", str(y.rail_y))
	_assert(y.objective_zh.contains("三号车厢"), "yard objective 元数据", y.objective_zh)
	_assert(String(y.get_node("Ground").texture.resource_path).ends_with("TIL_Ground_NightYard_Baked.png"),
			"yard 地面大图", y.get_node("Ground").texture.resource_path)
	_assert(String(y.get_node("World/Facade/Sprite").texture.resource_path).ends_with(
			"TIL_Facade_Khrushchyovka_A.png"), "yard 立面", y.get_node("World/Facade/Sprite").texture.resource_path)
	_assert(y.get_node_or_null("Lights/Terminal") != null, "yard 有电传终端灯")
	_assert(y.get_node_or_null("Lights/BoilerVent") != null, "yard 有锅炉房通风口灯")
	_assert(y.get_node_or_null("Lights/Tower") == null, "yard 没有调度塔灯")
	_assert(y.warm_lights.size() == 1, "yard 一个回温点", str(y.warm_lights.size()))
	_assert(y.cam.limit_right == 3072 and y.cam.limit_bottom - y.CAM_PAD_BOTTOM == 1587, "yard 镜头边界",
			"%d/%d" % [y.cam.limit_right, y.cam.limit_bottom - y.CAM_PAD_BOTTOM])
	_shared(y, "yard")

# ---------------------------------------------------------------------------
func _marshalling() -> void:
	var m: Node = _scene("res://scenes/night_marshalling.tscn")
	_assert(m.level_id == "marshalling", "marshalling metadata.level_id", m.level_id)
	_assert(m.level_zh == "西站调车场", "marshalling metadata.level_zh", m.level_zh)
	_assert(m.level_en == "West Station Marshalling Yard", "marshalling metadata.level_en", m.level_en)
	_assert(m.prize == "intel", "marshalling prize = intel（发车令）", m.prize)
	_assert(m.objective_zh.contains("发车令"), "marshalling objective 元数据", m.objective_zh)
	_assert(m.extract_zh.contains("涵洞"), "marshalling extract 元数据", m.extract_zh)
	_assert(m.rail_y.size() == 5, "marshalling 五股道 rail_y", str(m.rail_y))
	# 装配
	_assert(m.soldiers.size() == 3, "marshalling 3 组清杀队", str(m.soldiers.size()))
	_assert(m.rabids.size() == 10, "marshalling 10 只狂暴者（红区 2 + 黑区 8）", str(m.rabids.size()))
	var brutes := 0
	for r in m.rabids:
		if r.brute:
			brutes += 1
	_assert(brutes == 3, "其中 3 只壮硕（守车 01 / 煤水塔 / 东南车棚）", str(brutes))
	_assert(m.halfs.size() == 2, "marshalling 2 个回退半人", str(m.halfs.size()))
	_assert(m.containers.size() >= 10, "marshalling ≥10 个可搜刮容器", str(m.containers.size()))
	_assert(m.slush.size() == 5, "marshalling 5 块冻雪泥", str(m.slush.size()))
	_assert(m.warm_lights.size() == 2, "marshalling 两个回温点（240s 长夜）", str(m.warm_lights.size()))
	# 资产指向本关的大图
	_assert(String(m.get_node("Ground").texture.resource_path).ends_with(
			"TIL_Ground_NightMarshalling_Baked.png"), "marshalling 地面大图",
			m.get_node("Ground").texture.resource_path)
	_assert(String(m.get_node("World/Facade/Sprite").texture.resource_path).ends_with(
			"TIL_Facade_Depot_A.png"), "marshalling 机车库立面",
			m.get_node("World/Facade/Sprite").texture.resource_path)
	_assert(m.get_node_or_null("Lights/Tower") != null, "marshalling 有调度塔灯（CRT + 台灯）")
	_assert(m.get_node_or_null("Lights/Terminal") == null, "marshalling 没有电传终端灯")
	_assert(m.get_node_or_null("Lights/BoilerVent") == null, "marshalling 没有锅炉通风口灯")
	_assert(m.get_node_or_null("Searchlight") != null, "marshalling 有探照灯")
	# 故事锚点：发车令板 / 守车零件 / 水箱复写件
	var board: Node = m.get_node_or_null("World/Props/DispatchBoard")
	_assert(board != null and String(board.get_meta("container", "")) == "briefcase"
			and String(board.get_meta("guaranteed", "")) == "intel",
			"发车令板 = briefcase 容器且必出 intel（调度室外的发车令）")
	var van: Node = m.get_node_or_null("World/Props/BrakeVan02")
	_assert(van != null and String(van.get_meta("guaranteed", "")) == "bolt",
			"报废守车必出零件（莫辛枪机）")
	var tower: Node = m.get_node_or_null("World/Props/WaterTower")
	_assert(tower != null and String(tower.get_meta("container", "")) == "hidden"
			and String(tower.get_meta("guaranteed", "")) == "intel",
			"煤水塔 = hidden 容器且必出复写件")
	# 地表 → 脚步材质
	_assert(m.step_sound(_m(20.0, 20.2), false) == "step_rail", "踩在 3 道中心 = 铁轨脚步",
			m.step_sound(_m(20.0, 20.2), false))
	_assert(m.step_sound(_m(20.0, 5.6), false) == "step_snow", "站台便道 = 雪地脚步",
			m.step_sound(_m(20.0, 5.6), false))
	_assert(m.step_sound(_m(22.5, 22.5), true) == "step_ice", "冻雪泥 = 冰面脚步")
	_assert(m.is_slush(_m(22.5, 22.5)), "3、4 道之间是冻雪泥")
	_assert(not m.is_slush(_m(20.0, 5.6)), "站台便道不是冻雪泥")
	# 铁丝网：涵洞（x 8~10）是唯一缺口
	var fl: Node = m.get_node("World/FenceLine")
	_assert(fl.get_node("West").shape.size.x == 8.0 * PPM, "涵洞以西整段挡路",
			str(fl.get_node("West").shape.size.x))
	_assert(fl.get_node("East").shape.size.x == 34.0 * PPM, "涵洞以东整段挡路",
			str(fl.get_node("East").shape.size.x))
	# 镜头边界 = 本关 W/H
	_assert(m.cam.limit_right == int(44.0 * PPM), "marshalling limit_right", str(m.cam.limit_right))
	_assert(m.cam.limit_bottom - m.CAM_PAD_BOTTOM == int(36.0 * GY), "marshalling limit_bottom", str(m.cam.limit_bottom))
	_assert(m.cam.limit_top == int(3.0 * GY - 600), "marshalling limit_top（立面顶）", str(m.cam.limit_top))
	# 环境音四路都在
	for nm in ["Wind", "SteamAudio", "LampBuzz", "FireAudio"]:
		_assert(m.get_node_or_null(nm) != null, "marshalling 环境音 " + nm)
	# 天亮窗口在第二张图上同样是最后 20%
	m.in_campaign = true
	m.night_max = 100.0
	m.night_left = 100.0
	_assert(m.dawn_progress() == 0.0, "marshalling 夜刚开始 dawn=0")
	m.night_left = 10.0
	_assert(is_equal_approx(m.dawn_progress(), 0.5), "marshalling 最后 20% 的一半 dawn=0.5",
			str(m.dawn_progress()))
	_shared(m, "marshalling")

# ---------------------------------------------------------------------------
func _manor() -> void:
	var g: Node = _scene("res://scenes/night_manor.tscn")
	_assert(g.level_id == "manor", "manor metadata.level_id", g.level_id)
	_assert(g.level_zh == "松林庄园 · 二号恒温库", "manor metadata.level_zh", g.level_zh)
	_assert(g.level_en == "Pine Manor · Depot No.2", "manor metadata.level_en", g.level_en)
	_assert(g.prize == "dial", "manor prize = dial（409 批腹透液）", g.prize)
	_assert(g.objective_zh.contains("409"), "manor objective 元数据", g.objective_zh)
	_assert(g.extract_zh.contains("电网"), "manor extract 元数据（剪开的电网豁口）", g.extract_zh)
	_assert(g.rail_y.size() == 0, "manor 没有铁轨（rail_y 空串 ≠ 兜底）", str(g.rail_y))
	# 装配：4 组特勤 / 8 只狂暴者（2 壮硕）/ 2 个半人 / 9 个容器 / 5 块冻雪泥
	_assert(g.soldiers.size() == 4, "manor 4 组特勤巡逻", str(g.soldiers.size()))
	_assert(g.rabids.size() == 8, "manor 8 只狂暴者（红区 1 + 黑区 7）", str(g.rabids.size()))
	var brutes := 0
	for r in g.rabids:
		if r.brute:
			brutes += 1
	_assert(brutes == 2, "其中 2 只壮硕（焚化院看守 + 车道尽头）", str(brutes))
	_assert(g.halfs.size() == 2, "manor 2 个回退半人", str(g.halfs.size()))
	_assert(g.containers.size() == 9, "manor 9 个可搜刮容器", str(g.containers.size()))
	_assert(g.slush.size() == 5, "manor 5 块冻雪泥（冻观赏池等）", str(g.slush.size()))
	# 三个回温点：两个火堆 + 2000℃ 炉口
	_assert(g.warm_lights.size() == 3, "manor 三个回温点（火堆×2 + 炉口）", str(g.warm_lights.size()))
	_assert(g.get_node_or_null("Lights/Furnace") != null, "manor 有焚化炉口灯")
	_assert(g.get_node_or_null("Lights/Catwalk") != null, "manor 有二楼钢廊灯")
	_assert(g.get_node_or_null("Lights/Tower") == null, "manor 没有调度塔灯")
	_assert(g.get_node_or_null("Lights/Terminal") == null, "manor 没有电传终端灯")
	_assert(g.get_node_or_null("Searchlight") != null, "manor 有探照灯（东南岗塔）")
	# 资产指向本关的大图
	_assert(String(g.get_node("Ground").texture.resource_path).ends_with(
			"TIL_Ground_NightManor_Baked.png"), "manor 地面大图",
			g.get_node("Ground").texture.resource_path)
	_assert(String(g.get_node("World/Facade/Sprite").texture.resource_path).ends_with(
			"TIL_Facade_Manor_A.png"), "manor 恒温库+焚化车间立面",
			g.get_node("World/Facade/Sprite").texture.resource_path)
	# 故事锚点：409 托盘 / 进料口里的焚化炉照片 / 木箱里的阿司匹林
	var pallet: Node = g.get_node_or_null("World/Props/BatchPallet")
	_assert(pallet != null and String(pallet.get_meta("container", "")) == "fridge"
			and String(pallet.get_meta("guaranteed", "")) == "dial",
			"防爆门前托盘 = fridge 容器且必出 409 批腹透液")
	var feed: Node = g.get_node_or_null("World/Props/IncineratorFeed")
	_assert(feed != null and String(feed.get_meta("container", "")) == "hidden"
			and String(feed.get_meta("guaranteed", "")) == "photo",
			"焚化炉进料口 = hidden 容器且必出焚化炉照片")
	var crates: Node = g.get_node_or_null("World/Props/CrateStack")
	_assert(crates != null and String(crates.get_meta("guaranteed", "")) == "asp",
			"木箱堆必出阿司匹林（喂半人退烧）")
	# 地表 → 脚步材质：没有铁轨，主道也是踩雪；冻观赏池是冰面
	_assert(g.step_sound(_m(20.5, 20.0), false) == "step_snow", "中央车道 = 雪地脚步（无铁轨）",
			g.step_sound(_m(20.5, 20.0), false))
	_assert(g.step_sound(_m(33.0, 24.0), true) == "step_ice", "冻观赏池 = 冰面脚步")
	_assert(g.is_slush(_m(33.0, 24.0)), "池塘整面是冻雪泥")
	_assert(not g.is_slush(_m(20.5, 20.0)), "中央车道不是冻雪泥")
	# 电网高墙：剪开的豁口（x 6~8.5）是唯一缺口
	var fl: Node = g.get_node("World/FenceLine")
	_assert(fl.get_node("West").shape.size.x == 6.0 * PPM, "豁口以西整段电网挡路",
			str(fl.get_node("West").shape.size.x))
	_assert(fl.get_node("East").shape.size.x == 37.5 * PPM, "豁口以东整段电网挡路",
			str(fl.get_node("East").shape.size.x))
	# 镜头边界 = 本关 W/H + 立面顶
	_assert(g.cam.limit_right == int(46.0 * PPM), "manor limit_right", str(g.cam.limit_right))
	_assert(g.cam.limit_bottom - g.CAM_PAD_BOTTOM == int(38.0 * GY), "manor limit_bottom", str(g.cam.limit_bottom))
	_assert(g.cam.limit_top == int(3.0 * GY - 600), "manor limit_top（立面顶）", str(g.cam.limit_top))
	# 环境音：高墙里风小、没有蒸汽管 → 只有风/火/钠灯嗡鸣三路
	for nm in ["Wind", "LampBuzz", "FireAudio"]:
		_assert(g.get_node_or_null(nm) != null, "manor 环境音 " + nm)
	_assert(g.get_node_or_null("SteamAudio") == null, "manor 没有蒸汽管环境音")
	# 天亮窗口同样是最后 20%（manor 夜长 120 分钟）
	g.in_campaign = true
	g.night_max = 120.0
	g.night_left = 120.0
	_assert(g.dawn_progress() == 0.0, "manor 夜刚开始 dawn=0")
	g.night_left = 12.0
	_assert(is_equal_approx(g.dawn_progress(), 0.5), "manor 最后 20% 的一半 dawn=0.5",
			str(g.dawn_progress()))
	_shared(g, "manor")

# ---------------------------------------------------------------------------
func _mine() -> void:
	var g: Node = _scene("res://scenes/night_mine.tscn")
	_assert(g.level_id == "mine", "mine metadata.level_id", g.level_id)
	_assert(g.level_zh == "3 号矿坑 · 温压爆破作业面", "mine metadata.level_zh", g.level_zh)
	_assert(g.level_en == "Mine Shaft No.3 · Blast Face", "mine metadata.level_en", g.level_en)
	_assert(g.prize == "intel", "mine prize = intel（孢子岩芯与爆破台账）", g.prize)
	_assert(g.objective_zh.contains("起爆器"), "mine objective 元数据", g.objective_zh)
	_assert(g.extract_zh.contains("豁口"), "mine extract 元数据（南侧运矸专线豁口）", g.extract_zh)
	_assert(g.rail_y.size() == 1, "mine 一条运矸专线", str(g.rail_y))
	# 装配：2 组清杀队换岗 / 2 只感染掘进工（1 壮硕）/ 1 个回退半人 / 10 个容器 / 4 块冻雪泥
	_assert(g.soldiers.size() == 2, "mine 2 组清杀队换岗", str(g.soldiers.size()))
	_assert(g.rabids.size() == 2, "mine 2 只感染掘进工", str(g.rabids.size()))
	var brutes := 0
	for r in g.rabids:
		if r.brute:
			brutes += 1
	_assert(brutes == 1, "其中 1 只壮硕（守断面的 Rabid_Cut）", str(brutes))
	_assert(g.halfs.size() == 1, "mine 1 个回退半人（博伊科 0417）", str(g.halfs.size()))
	_assert(g.containers.size() == 10, "mine 10 个可搜刮容器", str(g.containers.size()))
	_assert(g.slush.size() == 4, "mine 4 块冻雪泥", str(g.slush.size()))
	# 两个回温点（240s 长夜）；无探照灯——黑暗是这张图的第一属性
	_assert(g.warm_lights.size() == 2, "mine 两个回温点（火堆×2）", str(g.warm_lights.size()))
	_assert(g.get_node_or_null("Lights/Brazier") != null, "mine 装药队火堆")
	_assert(g.get_node_or_null("Lights/BrazierCut") != null, "mine 看守断面火堆")
	_assert(g.get_node_or_null("Lights/Signal") != null, "mine 信号机灯")
	_assert(g.get_node_or_null("Searchlight") == null, "mine 没有探照灯（假人哨塔是空壳）")
	# 资产指向本关的大图
	_assert(String(g.get_node("Ground").texture.resource_path).ends_with(
			"TIL_Ground_NightMine_Baked.png"), "mine 地面大图",
			g.get_node("Ground").texture.resource_path)
	_assert(String(g.get_node("World/Facade/Sprite").texture.resource_path).ends_with(
			"TIL_Facade_Mine_A.png"), "mine 矿山岩壁立面",
			g.get_node("World/Facade/Sprite").texture.resource_path)
	# 剧本锚点：起爆器旁的爆破台账（必出 intel）/ 铝热剂装药 / 木箱堆阿司匹林 / 假人哨塔
	var rig: Node = g.get_node_or_null("World/Props/DetonatorRig")
	_assert(rig != null and String(rig.get_meta("guaranteed", "")) == "intel",
			"起爆器必出 intel（孢子岩芯与爆破台账）")
	var th: Node = g.get_node_or_null("World/Props/Thermite01")
	_assert(th != null and String(th.get_meta("container", "")) == "crate",
			"铝热剂装药堆在断面根上")
	var crates: Node = g.get_node_or_null("World/Props/CrateStack")
	_assert(crates != null and String(crates.get_meta("guaranteed", "")) == "asp",
			"木箱堆必出阿司匹林（喂博伊科退烧）")
	_assert(g.get_node_or_null("World/Props/DummyTower") != null, "假人哨塔第二座（无灯）")
	# 地表 → 脚步材质：运矸专线是铁轨，装卸台外是雪地
	_assert(g.step_sound(_m(20.0, 15.5), false) == "step_rail", "踩在运矸专线中心 = 铁轨脚步",
			g.step_sound(_m(20.0, 15.5), false))
	_assert(g.step_sound(_m(20.0, 8.0), false) == "step_snow", "装卸台外 = 雪地脚步",
			g.step_sound(_m(20.0, 8.0), false))
	# 镜头边界 = 本关 W/H + 立面顶
	_assert(g.cam.limit_right == int(46.0 * PPM), "mine limit_right", str(g.cam.limit_right))
	_assert(g.cam.limit_bottom - g.CAM_PAD_BOTTOM == int(34.0 * GY), "mine limit_bottom", str(g.cam.limit_bottom))
	_assert(g.cam.limit_top == int(3.0 * GY - 600), "mine limit_top（岩壁顶）", str(g.cam.limit_top))
	# 环境音：风 + 火 + 压风管蒸汽 + 钠灯嗡鸣四路
	for nm in ["Wind", "LampBuzz", "FireAudio", "SteamAudio"]:
		_assert(g.get_node_or_null(nm) != null, "mine 环境音 " + nm)
	# 天亮窗口同样是最后 20%（mine 夜长 100 分钟）
	g.in_campaign = true
	g.night_max = 100.0
	g.night_left = 100.0
	_assert(g.dawn_progress() == 0.0, "mine 夜刚开始 dawn=0")
	g.night_left = 10.0
	_assert(is_equal_approx(g.dawn_progress(), 0.5), "mine 最后 20% 的一半 dawn=0.5",
			str(g.dawn_progress()))
	_shared(g, "mine")

# ---------------------------------------------------------------------------
func _market() -> void:
	var g: Node = _scene("res://scenes/night_market.tscn")
	_assert(g.level_id == "market", "market metadata.level_id", g.level_id)
	_assert(g.level_zh == "铁路黑市（废弃工人镇）", "market metadata.level_zh", g.level_zh)
	_assert(g.level_en == "Rail Black Market", "market metadata.level_en", g.level_en)
	_assert(g.prize == "intel", "market prize = intel（6.66 电台棚的专列调度记录）", g.prize)
	_assert(g.objective_zh.contains("6.66"), "market objective 元数据", g.objective_zh)
	_assert(g.extract_zh.contains("豁口"), "market extract 元数据（铁路侧豁口）", g.extract_zh)
	_assert(g.rail_y.size() == 1, "market 铁路 1 道", str(g.rail_y))
	# 装配：2 组清杀队（棚户巷 + 铁路哨兵）/ 2 只感染者 / 无半人（老谢苗是幸存者）/ 10 个容器 / 4 块冻雪泥
	_assert(g.soldiers.size() == 2, "market 2 组清杀队", str(g.soldiers.size()))
	_assert(g.rabids.size() == 2, "market 2 只感染者", str(g.rabids.size()))
	var brutes := 0
	for r in g.rabids:
		if r.brute:
			brutes += 1
	_assert(brutes == 0, "market 没有壮硕感染者（低危交易关）", str(brutes))
	_assert(g.halfs.size() == 0, "market 没有回退半人", str(g.halfs.size()))
	_assert(g.containers.size() == 10, "market 10 个可搜刮容器", str(g.containers.size()))
	_assert(g.slush.size() == 4, "market 4 块冻雪泥", str(g.slush.size()))
	# 两个回温点（市集篝火 + 烫鳞炭炉）；无探照灯——这里是人和人互相看着的地方
	_assert(g.warm_lights.size() == 2, "market 两个回温点（篝火 + 炭炉）", str(g.warm_lights.size()))
	_assert(g.get_node_or_null("Lights/BrazierBazaar") != null, "market 市集篝火")
	_assert(g.get_node_or_null("Lights/BrazierForge") != null, "market 烫鳞炭炉")
	_assert(g.get_node_or_null("Lights/LampNw") != null and g.get_node_or_null("Lights/LampSe") != null,
			"market 两盏钠灯")
	_assert(g.get_node_or_null("Searchlight") == null, "market 没有探照灯")
	# 黑市摊区在黑区（夜潜区划烟测口径：黑市只在黑区）
	var mk: Node = g.get_node_or_null("World/Market")
	_assert(mk != null and mk.position.y >= 21.0 * GY, "market 摊区在黑区",
			str(mk.position.y if mk else -1.0))
	_assert(mk != null and String(mk.get_meta("zh", "")) != "", "market 摊区元数据在")
	# 资产指向本关的大图
	_assert(String(g.get_node("Ground").texture.resource_path).ends_with(
			"TIL_Ground_NightMarket_Baked.png"), "market 地面大图",
			g.get_node("Ground").texture.resource_path)
	_assert(String(g.get_node("World/Facade/Sprite").texture.resource_path).ends_with(
			"TIL_Facade_Town_A.png"), "market 工人镇立面",
			g.get_node("World/Facade/Sprite").texture.resource_path)
	# 剧本锚点：6.66 电台棚（必出 intel）/ 盘尼西林冷柜（必出 abx）/ 真假药对照 / 烫鳞炭炉 / 药棚铁门
	var radio: Node = g.get_node_or_null("World/Props/Radio666")
	_assert(radio != null and String(radio.get_meta("guaranteed", "")) == "intel",
			"6.66 电台棚必出 intel（专列调度记录）")
	var fridge: Node = g.get_node_or_null("World/Props/MedFridge")
	_assert(fridge != null and String(fridge.get_meta("guaranteed", "")) == "abx",
			"药棚冷柜必出盘尼西林（abx）")
	_assert(g.get_node_or_null("World/Props/MedCache") != null
			and g.get_node_or_null("World/Props/FakeMeds") != null, "真药与假药摆在同一个摊区")
	_assert(g.get_node_or_null("World/Props/QuackForge") != null, "烫鳞炭炉（只有工具和痕迹）")
	_assert(g.get_node_or_null("World/Props/MedShed") != null, "药棚铁门（C2 的锁点）")
	# 地表 → 脚步材质：铁路是铁轨，市集是雪地
	_assert(g.step_sound(_m(23.0, 27.0), false) == "step_rail", "踩在铁路 1 道 = 铁轨脚步",
			g.step_sound(_m(23.0, 27.0), false))
	_assert(g.step_sound(_m(24.5, 24.4), false) == "step_snow", "市集摊区 = 雪地脚步",
			g.step_sound(_m(24.5, 24.4), false))
	# 镜头边界 = 本关 W/H + 立面顶
	_assert(g.cam.limit_right == int(46.0 * PPM), "market limit_right", str(g.cam.limit_right))
	_assert(g.cam.limit_bottom - g.CAM_PAD_BOTTOM == int(34.0 * GY), "market limit_bottom", str(g.cam.limit_bottom))
	_assert(g.cam.limit_top == int(3.0 * GY - 600), "market limit_top（工人镇屋顶）", str(g.cam.limit_top))
	# 环境音：风 + 火 + 蒸汽 + 钠灯嗡鸣四路
	for nm in ["Wind", "LampBuzz", "FireAudio", "SteamAudio"]:
		_assert(g.get_node_or_null(nm) != null, "market 环境音 " + nm)
	# 天亮窗口同样是最后 20%（market 夜长 80 分钟）
	g.in_campaign = true
	g.night_max = 80.0
	g.night_left = 80.0
	_assert(g.dawn_progress() == 0.0, "market 夜刚开始 dawn=0")
	g.night_left = 8.0
	_assert(is_equal_approx(g.dawn_progress(), 0.5), "market 最后 20% 的一半 dawn=0.5",
			str(g.dawn_progress()))
	_shared(g, "market")


func _sanitarium() -> void:
	var g: Node = _scene("res://scenes/night_sanitarium.tscn")
	_assert(g.level_id == "sanitarium", "sanitarium metadata.level_id", g.level_id)
	_assert(g.level_zh == "旧传染病疗养院 · 地下室", "sanitarium metadata.level_zh", g.level_zh)
	_assert(g.level_en == "Old Sanatorium · Basement", "sanitarium metadata.level_en", g.level_en)
	_assert(g.prize == "asp", "sanitarium prize = asp（半片阿司匹林的回声）", g.prize)
	_assert(g.objective_zh.contains("第四天"), "sanitarium objective 元数据", g.objective_zh)
	_assert(g.extract_zh.contains("楼梯"), "sanitarium extract 元数据（南侧楼梯间）", g.extract_zh)
	_assert(g.rail_y.size() == 0, "sanitarium 没有铁轨（室内关——铁壳号只在换气铁窗外）", str(g.rail_y))
	# 室内地面 → 脚步材质：地下室湿混凝土 / 地坪漆是闷硬的硬地声，不再是踩雪
	_assert(g.step_sound(_m(22.0, 16.0), false) == "step_concrete", "sanitarium 地下室地面 = 硬地脚步（不再是踩雪）",
			g.step_sound(_m(22.0, 16.0), false))
	# 装配：2 组清杀队 / 3 只感染者（1 壮硕）/ 1 回退半人 / 12 个容器 / 2 块冻雪泥
	_assert(g.soldiers.size() == 2, "sanitarium 2 组清杀队（收集班）", str(g.soldiers.size()))
	_assert(g.rabids.size() == 3, "sanitarium 3 只感染者", str(g.rabids.size()))
	var brutes := 0
	for r in g.rabids:
		if r.brute:
			brutes += 1
	_assert(brutes == 1, "sanitarium 笼4 那只壮硕感染者（一直撞栏杆）", str(brutes))
	_assert(g.halfs.size() == 1, "sanitarium 1 个回退半人（笼3 · 0442）", str(g.halfs.size()))
	_assert(g.containers.size() == 12, "sanitarium 12 个可搜刮容器", str(g.containers.size()))
	_assert(g.slush.size() == 2, "sanitarium 2 块冻雪泥", str(g.slush.size()))
	# 两个回温点（火炉 + 火桶）；两盏灯（笼区冷白吊灯 + 工作区灯）；无探照灯
	_assert(g.warm_lights.size() == 2, "sanitarium 两个回温点（医生的火炉 + 火桶）", str(g.warm_lights.size()))
	_assert(g.get_node_or_null("Lights/BrazierClinic") != null, "sanitarium 火炉")
	_assert(g.get_node_or_null("Lights/BrazierHeater") != null, "sanitarium 火桶")
	_assert(g.get_node_or_null("Lights/LampCage") != null and g.get_node_or_null("Lights/LampOffice") != null,
			"sanitarium 两盏灯（笼区冷白 + 工作区）")
	_assert(g.get_node_or_null("Searchlight") == null, "sanitarium 没有探照灯")
	# 剧本锚点（3-2「地底铁笼」）：铁架床+皮带 / 回退半人 / 药柜（必出 asp）/ 换气铁窗 / 铁栅门
	_assert(g.get_node_or_null("World/Props/CageBed") != null, "sanitarium 安娜的铁架床 + 两根皮带")
	_assert(g.get_node_or_null("World/Half_Cage0442") != null, "sanitarium 笼3 回退半人（掉鳞屑、瞳孔回色）")
	var meds: Node = g.get_node_or_null("World/Props/MedCabinet")
	_assert(meds != null and String(meds.get_meta("guaranteed", "")) == "asp",
			"sanitarium 药柜必出 asp")
	_assert(g.get_node_or_null("World/Props/CageGate") != null, "sanitarium 笼区铁栅门（wedge 机关载体）")
	_assert(g.get_node_or_null("World/Props/XrayBoard") != null, "sanitarium 读片灯箱 + 病历")
	_assert(g.get_node_or_null("World/Survivor_0") != null and g.get_node_or_null("World/Survivor_1") != null
			and g.get_node_or_null("World/Survivor_2") != null,
			"sanitarium 安娜（0419）+ 梁诺夫 + 古丽娅在场")
	# 资产指向本关的大图
	_assert(String(g.get_node("Ground").texture.resource_path).ends_with(
			"TIL_Ground_NightSanitarium_Baked.png"), "sanitarium 地面大图",
			g.get_node("Ground").texture.resource_path)
	_assert(String(g.get_node("World/Facade/Sprite").texture.resource_path).ends_with(
			"TIL_Facade_Sanitarium_A.png"), "sanitarium 地下室北墙立面（换气铁窗）",
			g.get_node("World/Facade/Sprite").texture.resource_path)
	# 镜头边界 = 本关 W/H + 立面顶
	_assert(g.cam.limit_right == int(44.0 * PPM), "sanitarium limit_right", str(g.cam.limit_right))
	_assert(g.cam.limit_bottom - g.CAM_PAD_BOTTOM == int(30.0 * GY), "sanitarium limit_bottom", str(g.cam.limit_bottom))
	_assert(g.cam.limit_top == int(3.0 * GY - 600), "sanitarium limit_top（疗养院楼顶）", str(g.cam.limit_top))
	# 环境音：风 + 火 + 蒸汽 + 嗡鸣四路
	for nm in ["Wind", "LampBuzz", "FireAudio", "SteamAudio"]:
		_assert(g.get_node_or_null(nm) != null, "sanitarium 环境音 " + nm)
	# 天亮窗口同样是最后 20%（sanitarium 夜长 110 分钟）
	g.in_campaign = true
	g.night_max = 110.0
	g.night_left = 110.0
	_assert(g.dawn_progress() == 0.0, "sanitarium 夜刚开始 dawn=0")
	g.night_left = 11.0
	_assert(g.dawn_progress() == 0.5, "sanitarium 夜最后 10% = 亮一半", str(g.dawn_progress()))
	g.night_left = 0.0
	_assert(g.dawn_progress() == 1.0, "sanitarium 天亮 dawn=1", str(g.dawn_progress()))
	g.queue_free()


func _canteen() -> void:
	var g: Node = _scene("res://scenes/night_canteen.tscn")
	_assert(g.level_id == "canteen", "canteen metadata.level_id", g.level_id)
	_assert(g.level_zh == "东街工人食堂 · 后厨", "canteen metadata.level_zh", g.level_zh)
	_assert(g.level_en == "East Street Canteen · Kitchen", "canteen metadata.level_en", g.level_en)
	_assert(g.prize == "blade", "canteen prize = blade（砧板上的宽背砍骨刀）", g.prize)
	_assert(g.objective_zh.contains("十九只碗"), "canteen objective 元数据", g.objective_zh)
	_assert(g.extract_zh.contains("南门"), "canteen extract 元数据（南门礼堂入口）", g.extract_zh)
	_assert(g.rail_y.size() == 0, "canteen 没有铁轨（室内关）", str(g.rail_y))
	# 装配：2 组清杀队 / 2 只感染者（1 壮硕）/ 无半人 / 10 个容器 / 2 块冻雪泥
	_assert(g.soldiers.size() == 2, "canteen 2 组清杀队", str(g.soldiers.size()))
	_assert(g.rabids.size() == 2, "canteen 2 只感染者", str(g.rabids.size()))
	var brutes := 0
	for r in g.rabids:
		if r.brute:
			brutes += 1
	_assert(brutes == 1, "canteen 瓦西里是壮硕感染者（锁骨也能被撞断的那块头）", str(brutes))
	_assert(g.halfs.size() == 0, "canteen 没有回退半人", str(g.halfs.size()))
	_assert(g.containers.size() == 11, "canteen 11 个可搜刮容器", str(g.containers.size()))
	_assert(g.slush.size() == 2, "canteen 2 块冻雪泥", str(g.slush.size()))
	# 两个回温点（灶火 + 礼堂火炉）；两盏灯（后厨吊灯 + 餐厅吊灯）；无探照灯
	_assert(g.warm_lights.size() == 2, "canteen 两个回温点（灶 + 礼堂火炉）", str(g.warm_lights.size()))
	_assert(g.get_node_or_null("Lights/BrazierStove") != null, "canteen 灶火")
	_assert(g.get_node_or_null("Lights/BrazierHall") != null, "canteen 礼堂火炉")
	_assert(g.get_node_or_null("Lights/LampKitchen") != null and g.get_node_or_null("Lights/LampDining") != null,
			"canteen 两盏灯（后厨 + 餐厅）")
	_assert(g.get_node_or_null("Searchlight") == null, "canteen 没有探照灯")
	# 剧本锚点（2-1「锁骨」）：砧板砍骨刀（必出 blade）/ 十九只碗 / 窄门（wedge 机关载体）/ 黑麦糊桶 / 灶
	var board: Node = g.get_node_or_null("World/Props/PrepBoard")
	_assert(board != null and String(board.get_meta("guaranteed", "")) == "blade",
			"canteen 砧板必出 blade（宽背生锈砍骨刀）")
	_assert(g.get_node_or_null("World/Props/Table2") != null, "canteen 十九只碗的长条桌")
	_assert(g.get_node_or_null("World/Props/NarrowDoor") != null, "canteen 杂物间窄门（wedge 机关载体）")
	_assert(g.get_node_or_null("World/Props/RyeVat") != null, "canteen 黑麦糊桶")
	_assert(g.get_node_or_null("World/Props/Stove") != null, "canteen 独眼老炊事员的灶")
	_assert(g.get_node_or_null("World/Survivor_0") != null and g.get_node_or_null("World/Survivor_1") != null,
			"canteen 独眼老炊事员费奥多尔 + 老铁路工在场（十九只碗 = 十九个人）")
	# 资产指向本关的大图
	_assert(String(g.get_node("Ground").texture.resource_path).ends_with(
			"TIL_Ground_NightCanteen_Baked.png"), "canteen 地面大图",
			g.get_node("Ground").texture.resource_path)
	_assert(String(g.get_node("World/Facade/Sprite").texture.resource_path).ends_with(
			"TIL_Facade_Canteen_A.png"), "canteen 瓷砖后厨立面",
			g.get_node("World/Facade/Sprite").texture.resource_path)
	# 地表 → 脚步材质：室内关没有铁轨——冻雪泥上是冰壳声，瓷砖 / 水磨石是硬地声（不再是踩雪）
	_assert(g.step_sound(_m(22.0, 28.2), true) == "step_ice", "canteen 冻雪泥 = 冰壳脚步",
			g.step_sound(_m(22.0, 28.2), true))
	_assert(g.step_sound(_m(22.0, 25.0), false) == "step_tile", "canteen 后厨瓷砖地面 = 硬地脚步（不再是踩雪）",
			g.step_sound(_m(22.0, 25.0), false))
	# 镜头边界 = 本关 W/H + 立面顶
	_assert(g.cam.limit_right == int(44.0 * PPM), "canteen limit_right", str(g.cam.limit_right))
	_assert(g.cam.limit_bottom - g.CAM_PAD_BOTTOM == int(32.0 * GY), "canteen limit_bottom", str(g.cam.limit_bottom))
	_assert(g.cam.limit_top == int(3.0 * GY - 600), "canteen limit_top（食堂楼顶）", str(g.cam.limit_top))
	# 环境音：风 + 火 + 蒸汽 + 嗡鸣四路
	for nm in ["Wind", "LampBuzz", "FireAudio", "SteamAudio"]:
		_assert(g.get_node_or_null(nm) != null, "canteen 环境音 " + nm)
	# 天亮窗口同样是最后 20%（canteen 夜长 90 分钟）
	g.in_campaign = true
	g.night_max = 90.0
	g.night_left = 90.0
	_assert(g.dawn_progress() == 0.0, "canteen 夜刚开始 dawn=0")
	g.night_left = 9.0
	_assert(g.dawn_progress() == 0.5, "canteen 夜最后 10% = 亮一半", str(g.dawn_progress()))
	g.night_left = 0.0
	_assert(g.dawn_progress() == 1.0, "canteen 天亮 dawn=1", str(g.dawn_progress()))
	g.queue_free()


func _coldstore() -> void:
	var g: Node = _scene("res://scenes/night_coldstore.tscn")
	_assert(g.level_id == "coldstore", "coldstore metadata.level_id", g.level_id)
	_assert(g.level_zh == "城北四号铁路冷库", "coldstore metadata.level_zh", g.level_zh)
	_assert(g.level_en == "Rail Cold Storage No.4", "coldstore metadata.level_en", g.level_en)
	_assert(g.prize == "abx", "coldstore prize = abx（封存医疗耗材——真药的另一半答案）", g.prize)
	_assert(g.objective_zh.contains("0892"), "coldstore objective 元数据", g.objective_zh)
	_assert(g.extract_zh.contains("豁口"), "coldstore extract 元数据（铁路专用线侧豁口）", g.extract_zh)
	_assert(g.rail_y.size() == 1, "coldstore 铁路专用线 1 道", str(g.rail_y))
	# 装配：2 组清杀队 / 2 只感染者 / 无半人（半人在 yard）/ 9 个容器 / 4 块冻雪泥
	_assert(g.soldiers.size() == 2, "coldstore 2 组清杀队", str(g.soldiers.size()))
	_assert(g.rabids.size() == 2, "coldstore 2 只感染者", str(g.rabids.size()))
	var brutes := 0
	for r in g.rabids:
		if r.brute:
			brutes += 1
	_assert(brutes == 0, "coldstore 没有壮硕感染者（低危账目关）", str(brutes))
	_assert(g.halfs.size() == 0, "coldstore 没有回退半人", str(g.halfs.size()))
	_assert(g.containers.size() == 9, "coldstore 9 个可搜刮容器", str(g.containers.size()))
	_assert(g.slush.size() == 4, "coldstore 4 块冻雪泥", str(g.slush.size()))
	# 两个回温点（值班炉 + 幸存者火桶）；两盏灯（月台钠灯 + 南库冷白吊灯）；无探照灯
	_assert(g.warm_lights.size() == 2, "coldstore 两个回温点（值班炉 + 火桶）", str(g.warm_lights.size()))
	_assert(g.get_node_or_null("Lights/BrazierDuty") != null, "coldstore 值班炉")
	_assert(g.get_node_or_null("Lights/BrazierWorker") != null, "coldstore 幸存者火桶")
	_assert(g.get_node_or_null("Lights/LampDock") != null and g.get_node_or_null("Lights/LampHall") != null,
			"coldstore 两盏灯（月台灯 + 南库吊灯）")
	_assert(g.get_node_or_null("Searchlight") == null, "coldstore 没有探照灯")
	# 剧本锚点（1-3「账面死人」）：磁卡终端 / 排水窄缝 / 封存耗材（必出 abx）/ 冷库铁门 / 3 号柱母子
	_assert(g.get_node_or_null("World/Props/CardTerminal") != null, "coldstore 磁卡终端（红字：在册人数 0）")
	_assert(g.get_node_or_null("World/Props/DrainSlit") != null, "coldstore 12cm 排水窄缝（只有痕迹）")
	var meds: Node = g.get_node_or_null("World/Props/SealedMeds")
	_assert(meds != null and String(meds.get_meta("guaranteed", "")) == "abx",
			"coldstore 封存医疗耗材必出 abx")
	_assert(g.get_node_or_null("World/Props/ColdVaultDoor") != null, "coldstore 冷库铁门（wedge 机关载体）")
	_assert(g.get_node_or_null("World/Props/Column03") != null, "coldstore 3 号立柱在场")
	_assert(g.get_node_or_null("World/Survivor_0") != null and g.get_node_or_null("World/Survivor_1") != null,
			"coldstore 3 号柱后的母子在场（账面在册 0 人，实际 2 人）")
	# 资产指向本关的大图
	_assert(String(g.get_node("Ground").texture.resource_path).ends_with(
			"TIL_Ground_NightColdstore_Baked.png"), "coldstore 地面大图",
			g.get_node("Ground").texture.resource_path)
	_assert(String(g.get_node("World/Facade/Sprite").texture.resource_path).ends_with(
			"TIL_Facade_ColdStore_A.png"), "coldstore 冷库立面",
			g.get_node("World/Facade/Sprite").texture.resource_path)
	# 地表 → 脚步材质：专用线是铁轨，南库空地是雪地
	_assert(g.step_sound(_m(23.0, 27.0), false) == "step_rail", "踩在专用线 = 铁轨脚步",
			g.step_sound(_m(23.0, 27.0), false))
	_assert(g.step_sound(_m(2.0, 30.0), false) == "step_snow", "南库空地 = 雪地脚步",
			g.step_sound(_m(2.0, 30.0), false))
	# 镜头边界 = 本关 W/H + 立面顶
	_assert(g.cam.limit_right == int(46.0 * PPM), "coldstore limit_right", str(g.cam.limit_right))
	_assert(g.cam.limit_bottom - g.CAM_PAD_BOTTOM == int(34.0 * GY), "coldstore limit_bottom", str(g.cam.limit_bottom))
	_assert(g.cam.limit_top == int(3.0 * GY - 600), "coldstore limit_top（冷库主楼顶）", str(g.cam.limit_top))
	# 环境音：风 + 火 + 蒸汽 + 嗡鸣四路
	for nm in ["Wind", "LampBuzz", "FireAudio", "SteamAudio"]:
		_assert(g.get_node_or_null(nm) != null, "coldstore 环境音 " + nm)
	# 天亮窗口同样是最后 20%（coldstore 夜长 80 分钟）
	g.in_campaign = true
	g.night_max = 80.0
	g.night_left = 80.0
	_assert(g.dawn_progress() == 0.0, "coldstore 夜刚开始 dawn=0")
	g.night_left = 8.0
	_assert(is_equal_approx(g.dawn_progress(), 0.5), "coldstore 最后 20% 的一半 dawn=0.5",
			str(g.dawn_progress()))
	_shared(g, "coldstore")

# ---------------------------------------------------------------------------
func _shared(s: Node, tag: String) -> void:
	_assert(s.sfx != null and s.sfx.stream_count() >= 25, tag + " 音效库 ≥25 种",
			str(s.sfx.stream_count() if s.sfx else -1))
	_assert(s.sfx.has_stream("step_rail") and s.sfx.has_stream("mask_breath")
			and s.sfx.has_stream("dawn_horn"), tag + " 关键音色在库")
	_assert(s.sfx.has_stream("step_tile") and s.sfx.has_stream("step_concrete")
			and s.sfx.has_stream("room_tone"), tag + " 室内音色在库（瓷砖 / 混凝土 / 房间低鸣）")
	_assert(s.shake == 0.0 and s.cam.offset == Vector2.ZERO, tag + " 静止时镜头不抖")
	var mat: ShaderMaterial = s.post.material
	_assert(mat.get_shader_parameter("dawn") == 0.0, tag + " 后处理 dawn 参数在且为 0")
	_assert(is_equal_approx(float(mat.get_shader_parameter("frost")),
			clampf((35.0 - s.warmth) / 35.0, 0.0, 1.0)), tag + " frost 口径不变")
	_assert(s.cans == 3 and s.bag_max == 8, tag + " 独立跑法默认值（罐头 3 / 背包 8）")
