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
	_assert(with_scene >= 2, "至少两关有节点化场景", str(with_scene))
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
	_assert(y.cam.limit_right == 3072 and y.cam.limit_bottom == 1587, "yard 镜头边界",
			"%d/%d" % [y.cam.limit_right, y.cam.limit_bottom])
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
	_assert(m.rabids.size() == 5, "marshalling 5 只狂暴者", str(m.rabids.size()))
	var brutes := 0
	for r in m.rabids:
		if r.brute:
			brutes += 1
	_assert(brutes == 2, "其中 2 只壮硕（危险度 4）", str(brutes))
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
	_assert(m.cam.limit_bottom == int(36.0 * GY), "marshalling limit_bottom", str(m.cam.limit_bottom))
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
func _shared(s: Node, tag: String) -> void:
	_assert(s.sfx != null and s.sfx.stream_count() >= 25, tag + " 音效库 ≥25 种",
			str(s.sfx.stream_count() if s.sfx else -1))
	_assert(s.sfx.has_stream("step_rail") and s.sfx.has_stream("mask_breath")
			and s.sfx.has_stream("dawn_horn"), tag + " 关键音色在库")
	_assert(s.shake == 0.0 and s.cam.offset == Vector2.ZERO, tag + " 静止时镜头不抖")
	var mat: ShaderMaterial = s.post.material
	_assert(mat.get_shader_parameter("dawn") == 0.0, tag + " 后处理 dawn 参数在且为 0")
	_assert(is_equal_approx(float(mat.get_shader_parameter("frost")),
			clampf((35.0 - s.warmth) / 35.0, 0.0, 1.0)), tag + " frost 口径不变")
	_assert(s.cans == 3 and s.bag_max == 8, tag + " 独立跑法默认值（罐头 3 / 背包 8）")
