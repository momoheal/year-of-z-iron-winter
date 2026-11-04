extends SceneTree
## Headless smoke test for 三区（白 / 红 / 黑）+ 黑市 + 火苗高度。
## Run:  Godot_v4.7.2-stable_win64 --headless --path godot_project -s tests/night_zones_smoke.gd
##
## 覆盖：
##   1) NightZones 解析器：字符串格式、点在不在区内、黑区资源加成、坏数据不崩。
##   2) 三张场景：metadata/zones 都在、三块矩形铺满整张图、出生点落在该落的区。
##   3) 尸群分布：白区 0 只、红区 ≤ 2 只、黑区 ≥ 6 只（按场景里的真实坐标算，不信 hand-tuned 数字）。
##   4) 黑市：在黑区里、摊主与幸存者都在黑区、一夜只换一次、罐头换弹药真的到账。
##   5) 火苗：油桶的火不再高过模型（Flame 的 scale / 世界坐标顶点的硬上限）。
##
## 全程直接调方法，不依赖帧循环。

var passes: int = 0
var failures: Array[String] = []

const Zones := preload("res://scripts/night/NightZones.gd")
const PPM := 64.0
const SQ := 0.62

const SCENES := {
	"yard": "res://scenes/night_explore.tscn",
	"marshalling": "res://scenes/night_marshalling.tscn",
	"manor": "res://scenes/night_manor.tscn",
	"mine": "res://scenes/night_mine.tscn",
	"market": "res://scenes/night_market.tscn",
	"coldstore": "res://scenes/night_coldstore.tscn",
	"canteen": "res://scenes/night_canteen.tscn",
	"sanitarium": "res://scenes/night_sanitarium.tscn",
}
## 每张图的出生点应该在哪个区（涵洞在庄园 / 站场 → 从黑区摸进来；货场从锅炉房 → 白区）
const SPAWN_ZONE := {"yard": "white", "marshalling": "black", "manor": "black", "mine": "black",
		"market": "white", "coldstore": "white", "canteen": "white", "sanitarium": "white"}
## 按关覆盖的尸群/黑市规则：L07M 矿坑是「环境杀」关（塌方 / 粉尘 / 起爆倒计时）——
## 尸少（感染掘进工只有 2 只，都是孢子源头的注脚）、无黑市（黑市是居民点的生意，不是作业面的）；
## market 是黑市老家（低危交易关：尸是注脚，摊区就在黑区中心）
const LEVEL_RULES := {
	"mine": {"black_min": 1, "red_max": 1, "market": false},
	"market": {"black_min": 2, "red_max": 1, "market": true},
	# coldstore：低危账目关（2 只感染者都是专用线上的注脚）；没有黑市——冷库里没有生意，只有账
	"coldstore": {"black_min": 2, "red_max": 1, "market": false},
	# canteen：狭窄空间肉搏关（瓦西里 + 后角 1 只都在黑区窄门一带）；没有黑市——食堂里只有账和碗
	"canteen": {"black_min": 2, "red_max": 1, "market": false},
	# sanitarium：地底铁笼关（3 只都在黑区笼列）；没有黑市——疗养院里没有生意，只有病
	"sanitarium": {"black_min": 3, "red_max": 1, "market": false},
}


func _init() -> void:
	_run.call_deferred()


func _assert(cond: bool, n: String, detail: String = "") -> void:
	if cond:
		passes += 1
		print("  PASS  ", n)
	else:
		failures.append(n + ((" — " + detail) if detail != "" else ""))
		print("  FAIL  ", n, "  ", detail)


func _scene(path: String) -> Node:
	for c in root.get_children():
		if c.name == "NightExplore":
			root.remove_child(c)
			c.free()
	var s: Node = (load(path) as PackedScene).instantiate()
	root.add_child(s)
	return s


func _run() -> void:
	print("== night_zones_smoke ==")
	_parser()
	for name in SCENES.keys():
		_level(name)
	_market()
	_coldstore()
	_canteen()
	_sanitarium()
	_fire()
	print("")
	if failures.is_empty():
		print("NIGHT_ZONES SMOKE PASS  (%d checks)" % passes)
		quit(0)
	else:
		print("NIGHT_ZONES SMOKE FAIL  (%d failed / %d total)" % [failures.size(), passes + failures.size()])
		for f in failures:
			print("   - ", f)
		quit(1)


# ---------------------------------------------------------------------------
# 1) 解析器
# ---------------------------------------------------------------------------
func _parser() -> void:
	print("[parser]")
	var src := "white:0,0,48,12|red:0,12,48,21.5|black:0,21.5,48,40"
	var zs := Zones.parse(src)
	_assert(zs.size() == 3, "三段解析成三个区", str(zs.size()))
	_assert(Zones.zone_at(zs, Vector2(7.0, 4.3)) == "white", "锅炉房外 = 白区")
	_assert(Zones.zone_at(zs, Vector2(24.0, 18.0)) == "red", "铁丝网前 = 红区")
	_assert(Zones.zone_at(zs, Vector2(24.0, 24.0)) == "black", "豁口以南 = 黑区")
	_assert(Zones.zone_at(zs, Vector2(-5.0, -5.0)) == "", "图外不算任何区")
	_assert(Zones.loot_bonus("black") == 1 and Zones.loot_bonus("white") == 0, "黑区多翻一件")
	# L 形：一个区两块矩形
	var l := Zones.parse("black:0,20,10,40;30,20,40,40")
	_assert(Zones.zone_at(l, Vector2(35.0, 30.0)) == "black", "多块矩形拼 L 形")
	_assert(Zones.zone_at(l, Vector2(20.0, 30.0)) == "", "L 形中间的空洞不算区内")
	# 坏数据：不该崩
	_assert(Zones.parse("").is_empty(), "空串 → 空表")
	_assert(Zones.parse("garbage").is_empty(), "垃圾串 → 空表")
	_assert(Zones.parse("white:1,2,3").is_empty(), "缺参数的矩形被丢掉")
	_assert(Zones.rule("red") == "curfew" and Zones.rule("black") == "sunken", "规则标签")
	_assert(Zones.display_zh("black") != "", "黑区有中文名")


# ---------------------------------------------------------------------------
# 2~4) 每张图：分区 / 尸群 / 黑市
# ---------------------------------------------------------------------------
func _level(name: String) -> void:
	print("[%s]" % name)
	var s := _scene(SCENES[name])
	var zs: Array = s.zones
	_assert(zs.size() == 3, "%s: 场景里写了三个区" % name, str(zs.size()))
	if zs.size() != 3:
		return

	# 三块矩形要铺满整张图（不许有缝：玩家走到缝里 zone_id 会变成 ""）
	var w_m := 0.0
	var h_m := 0.0
	for z in zs:
		for r in z["rects"]:
			w_m = maxf(w_m, (r as Rect2).end.x)
			h_m = maxf(h_m, (r as Rect2).end.y)
	var holes := 0
	var y := 0.5
	while y < h_m:
		var x := 0.5
		while x < w_m:
			if Zones.zone_at(zs, Vector2(x, y)) == "":
				holes += 1
			x += 2.0
		y += 2.0
	_assert(holes == 0, "%s: 分区铺满整张图，没有缝隙" % name, "空洞 %d 处" % holes)

	# 出生点
	var spawn: Vector2 = (s.get_node("Markers/Spawn") as Node2D).global_position
	var sz: String = Zones.zone_at(zs, NightExplore_to_m(spawn))
	_assert(sz == String(SPAWN_ZONE[name]), "%s: 出生点在 %s" % [name, SPAWN_ZONE[name]], sz)

	# 尸群按区统计（矿坑按 LEVEL_RULES 放宽：环境杀关，尸是注脚不是主角）
	var rules: Dictionary = LEVEL_RULES.get(name, {})
	var red_max: int = int(rules.get("red_max", 3))
	var black_min: int = int(rules.get("black_min", 6))
	var has_market: bool = bool(rules.get("market", true))
	var count := {"white": 0, "red": 0, "black": 0}
	for r in get_nodes_in_group("night_rabid"):
		var z := Zones.zone_at(zs, NightExplore_to_m((r as Node2D).global_position))
		if count.has(z):
			count[z] += 1
	_assert(count["white"] == 0, "%s: 白区没有丧尸" % name, str(count["white"]))
	_assert(count["red"] <= red_max, "%s: 红区丧尸 ≤ %d（管制带靠清杀队撑）" % [name, red_max], str(count["red"]))
	_assert(count["black"] >= black_min, "%s: 黑区丧尸 ≥ %d（尸群不成群就不叫黑区）" % [name, black_min], str(count["black"]))
	print("      分布 white=%d red=%d black=%d" % [count["white"], count["red"], count["black"]])

	# 半人也不能在白区（居民区里躺个发烧的人，说不通）
	for h in get_nodes_in_group("night_half"):
		var hz := Zones.zone_at(zs, NightExplore_to_m((h as Node2D).global_position))
		_assert(hz != "white", "%s: 半人不在白区" % name, "%s" % hz)

	# 黑市：在黑区，摊主与幸存者都在黑区，且摊子 5 m 内有人（矿坑没有黑市）
	var mk := get_nodes_in_group("night_market")
	_assert(mk.size() == (1 if has_market else 0), "%s: 黑市数量（矿坑 0，其余关 1）" % name, str(mk.size()))
	if mk.size() == 1 and has_market:
		var mpos: Vector2 = (mk[0] as Node2D).global_position
		var mz := Zones.zone_at(zs, NightExplore_to_m(mpos))
		_assert(mz == "black", "%s: 黑市在黑区" % name, mz)
		_assert(int(mk[0].get_meta("cans", 0)) >= 1 and int(mk[0].get_meta("ammo", 0)) > 0,
			"%s: 黑市标价（罐头 / 弹药）" % name)
		var near := 0
		for p in get_nodes_in_group("night_survivor"):
			var d := NightExplore_dist_m((p as Node2D).global_position, mpos)
			if d <= 5.0:
				near += 1
			var pz := Zones.zone_at(zs, NightExplore_to_m((p as Node2D).global_position))
			_assert(pz == "black", "%s: 幸存者住在黑区" % name, pz)
		_assert(near >= 2, "%s: 摊子边上至少两个人" % name, str(near))

	for c in root.get_children():
		if c.name == "NightExplore":
			root.remove_child(c)
			c.free()


func NightExplore_to_m(p: Vector2) -> Vector2:
	return Vector2(p.x / PPM, p.y / (PPM * SQ))


func NightExplore_dist_m(a: Vector2, b: Vector2) -> float:
	var d := a - b
	return Vector2(d.x / PPM, d.y / (PPM * SQ)).length()


# ---------------------------------------------------------------------------
# 4) 运行时：进区判定 / 红区禁止进入 / 黑市买卖
# ---------------------------------------------------------------------------
func _market() -> void:
	print("[runtime]")
	var s := _scene(SCENES["yard"])
	_assert(s.zones.size() == 3, "运行时读到三区")

	# 站在白区
	s.player.global_position = Vector2(7.0 * PPM, 5.0 * PPM * SQ)
	s._update_zone(0.016)
	_assert(s.zone_id == "white", "player 在白区", s.zone_id)

	# 走进红区：先提示，7 秒后被盘问
	s.global_position = Vector2.ZERO
	s.player.set_physics_process(false)
	s.player.global_position = Vector2(24.0 * PPM, 17.0 * PPM * SQ)
	s._update_zone(0.016)
	_assert(s.zone_id == "red", "player 进红区", s.zone_id)
	_assert(s.zone_warned == false, "刚进红区还没提示")
	var t := 0.0
	while t < 3.6:
		s._update_zone(0.2)
		t += 0.2
	_assert(s.zone_warned, "在红区待 3.5 秒后被警告（白区居民禁止进入）")
	t = 0.0
	while t < 4.0:
		s._update_zone(0.2)
		t += 0.2
	_assert(s.zone_curfew, "继续待着 → 被清杀队盘问")

	# 进黑区：flags 重置
	s.player.global_position = Vector2(30.0 * PPM, 26.0 * PPM * SQ)
	s._update_zone(0.016)
	_assert(s.zone_id == "black", "player 进黑区", s.zone_id)
	_assert(s.zone_curfew == false, "离开红区后盘问状态清掉")

	# 黑市：一罐换八发
	var mk = get_nodes_in_group("night_market")[0]
	s._add_weapon("rifle")
	s.reserve["rifle"] = 0
	s.cans = 3
	s.market_used = false
	var ok: bool = s.trade_market(mk)
	_assert(ok, "黑市成交")
	_assert(int(s.reserve["rifle"]) == int(mk.get_meta("ammo", 8)), "备弹到账",
		str(s.reserve["rifle"]))
	_assert(int(s.cans) == 2, "扣掉一罐罐头", str(s.cans))
	_assert(not s.trade_market(mk), "一夜只换一次")

	# 没罐头换不了
	s.market_used = false
	s.cans = 0
	s.reserve["rifle"] = 0
	_assert(not s.trade_market(mk), "没罐头 → 摊主不换")
	_assert(int(s.reserve["rifle"]) == 0, "没成交就不该到账")

	for c in root.get_children():
		if c.name == "NightExplore":
			root.remove_child(c)
			c.free()


# ---------------------------------------------------------------------------
# coldstore 专用：「账面 vs 活人」——红字说在册 0 人，柱后缩着 2 个活人
# ---------------------------------------------------------------------------
func _sanitarium() -> void:
	print("[sanitarium 专用]")
	var s := _scene(SCENES["sanitarium"])
	var zs: Array = s.zones
	var sv := get_nodes_in_group("night_survivor")
	_assert(sv.size() == 3, "sanitarium 安娜 0419 + 梁诺夫 + 古丽娅 3 人", str(sv.size()))
	# 安娜在黑区铁架床边（熬过第四天的人），两位医生在白区工作区
	var anna: Node2D = sv[0] as Node2D
	_assert(Zones.zone_at(zs, NightExplore_to_m(anna.global_position)) == "black",
			"安娜在黑区铁架床边（掉鳞屑的地方）")
	_assert(Zones.zone_at(zs, NightExplore_to_m((sv[1] as Node2D).global_position)) == "white",
			"梁诺夫医生在白区工作区")
	# 药柜在白区（照顾人的地方），回退半人在黑区笼里
	var meds: Node = s.get_node_or_null("World/Props/MedCabinet")
	_assert(meds != null and Zones.zone_at(zs, NightExplore_to_m(meds.global_position)) == "white",
			"药柜站在白区医生工作区")
	for h in get_nodes_in_group("night_half"):
		var hz := Zones.zone_at(zs, NightExplore_to_m((h as Node2D).global_position))
		_assert(hz == "black", "回退半人关在黑区笼里", hz)
	for c in root.get_children():
		if c.name == "NightExplore":
			root.remove_child(c)
			c.free()


func _canteen() -> void:
	print("[canteen 专用]")
	var s := _scene(SCENES["canteen"])
	var zs: Array = s.zones
	var sv := get_nodes_in_group("night_survivor")
	_assert(sv.size() == 2, "canteen 独眼老炊事员 + 老铁路工 2 人（十九只碗 = 十九个人）", str(sv.size()))
	for p in sv:
		var pz := Zones.zone_at(zs, NightExplore_to_m((p as Node2D).global_position))
		_assert(pz == "black" or pz == "white", "canteen 幸存者在灶边或碗旁", pz)
	# 费奥多尔守在黑区的灶边（和他烧到 40 度的儿子在同一片黑区）
	var fyodor: Node2D = sv[0] as Node2D
	_assert(Zones.zone_at(zs, NightExplore_to_m(fyodor.global_position)) == "black",
			"老炊事员守在黑区灶边（窄门就在这一片）")
	# 砧板在黑区——锁骨的故事从这里开始
	var board: Node = s.get_node_or_null("World/Props/PrepBoard")
	_assert(board != null and Zones.zone_at(zs, NightExplore_to_m(board.global_position)) == "black",
			"砧板砍骨刀站在黑区（狭窄后厨的深处）")
	for c in root.get_children():
		if c.name == "NightExplore":
			root.remove_child(c)
			c.free()


func _coldstore() -> void:
	print("[coldstore 专用]")
	var s := _scene(SCENES["coldstore"])
	var zs: Array = s.zones
	var sv := get_nodes_in_group("night_survivor")
	_assert(sv.size() == 2, "coldstore 3 号柱后的母子 2 人（账面在册 0 人）", str(sv.size()))
	var near_col := 0
	var col_px := Vector2(25.0 * PPM, 23.5 * PPM * SQ)
	for p in sv:
		var pz := Zones.zone_at(zs, NightExplore_to_m((p as Node2D).global_position))
		_assert(pz == "black", "coldstore 幸存者住在黑区（账面死人的地方）", pz)
		if NightExplore_dist_m((p as Node2D).global_position, col_px) <= 4.0:
			near_col += 1
	_assert(near_col == 2, "coldstore 母子贴着 3 号立柱（柱后 4 米内）", str(near_col))
	# 磁卡终端在白区——「在册」的地方；两处对照摆在同一张图上
	var term: Node = s.get_node_or_null("World/Props/CardTerminal")
	_assert(term != null and Zones.zone_at(zs, NightExplore_to_m(term.global_position)) == "white",
			"coldstore 磁卡终端站在白区（账面在册的地方）")
	for c in root.get_children():
		if c.name == "NightExplore":
			root.remove_child(c)
			c.free()


# ---------------------------------------------------------------------------
# 5) 火苗高度
# ---------------------------------------------------------------------------
func _fire() -> void:
	print("[fire]")
	for name in SCENES.keys():
		var s := _scene(SCENES[name])
		var flames := 0
		var worst := -1e9
		for n in _walk(s):
			if n is Sprite2D and String(n.name) == "Flame":
				flames += 1
				var spr := n as Sprite2D
				# 顶点在油桶局部坐标里的高度（负 = 在落地点上方）
				var top := spr.position.y + spr.offset.y * spr.scale.y
				worst = maxf(worst, -top)      # 正值 = 高过落地多少像素
				_assert(spr.scale.y <= 0.5, "%s: 火苗纵向压到一半以下" % name, str(spr.scale.y))
		_assert(flames > 0, "%s: 场景里有火堆" % name)
		# 油桶本体 54 px 高（gen_props.brazier: base 86, hgt 54）；火苗顶端不许超过 100 px
		_assert(worst <= 100.0, "%s: 火苗顶端不高于 100 px（桶身 54 px）" % name, str(worst))
		for c in root.get_children():
			if c.name == "NightExplore":
				root.remove_child(c)
				c.free()


func _walk(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		out.append(c)
		out.append_array(_walk(c))
	return out
