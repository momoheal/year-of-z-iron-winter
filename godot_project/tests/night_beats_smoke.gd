extends SceneTree
## Headless smoke test for the "dossier layer" (界面苏联化 + 关卡节拍).
## Run:  Godot_v4.7.2-stable_win64 --headless --path godot_project -s tests/night_beats_smoke.gd
##
## 覆盖两层：
##   1) 界面：SovietUI 的排版/方位/时钟工具、SovietChrome 的整屏金属框、
##      NightExplore 新的档案牌 + 任务卡 + 分段仪表是否都建出来了。
##   2) 关卡：LevelBeats 的三张图数据是否落在场景里（关键物资点 / 地标在边界内 /
##      节拍股道是真实股道 / 机关节点存在），以及导演状态机
##      （warn → live → 结束、驼峰车皮生成与回收、炉口爆燃、扳道岔、叉车一次性）。
##
## 这个套件只读数据 + 直接调用方法，不依赖真实帧循环，所以 headless 里是确定的。

var passes: int = 0
var failures: Array[String] = []

const PPM := 64.0
const GY := 39.68

const Beats := preload("res://scripts/night/LevelBeats.gd")
const SovietUI := preload("res://scripts/ui/SovietUI.gd")
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


func _scene(path: String) -> Node:
	for c in root.get_children():
		if c.name == "NightExplore":
			root.remove_child(c)
			c.free()
	var s: Node = (load(path) as PackedScene).instantiate()
	root.add_child(s)
	return s


func _run() -> void:
	print("== night_beats_smoke ==")
	_tools()
	_levels()
	_yard()
	_marshalling()
	_manor()
	print("== RESULT: %d passed, %d failed ==" % [passes, failures.size()])
	for f in failures:
		print("   FAILED: ", f)
	if failures.size() > 0:
		quit(1)
	quit(0)


# ---------------------------------------------------------------------------
func _tools() -> void:
	# 方位：x 向东、y 向南；(-1,-1) 是西北
	_assert(SovietUI.bearing_zh(Vector2(-1, -1)) == "西北", "方位：西北", SovietUI.bearing_zh(Vector2(-1, -1)))
	_assert(SovietUI.bearing_zh(Vector2(1, 0)) == "东", "方位：东")
	_assert(SovietUI.bearing_arrow(Vector2(0, 1)) == "↓", "方位箭头：南")
	_assert(SovietUI.bearing_line(Vector2(0, -12.4)) == "↑ 北 12m", "方位读数一行",
		SovietUI.bearing_line(Vector2(0, -12.4)))
	# 时钟 / 百分比 / 危险度 / 卌
	_assert(SovietUI.clock(90.0) == "01:30", "mm:ss", SovietUI.clock(90.0))
	_assert(SovietUI.clock(-5.0) == "00:00", "负数时钟归零")
	_assert(SovietUI.pct(0.5) == " 50%", "百分比读数", SovietUI.pct(0.5))
	_assert(SovietUI.danger_pips(4) == "▲▲▲▲△", "危险度 pips", SovietUI.danger_pips(4))
	_assert(SovietUI.tally_glyphs(0) == "—", "没有卌的时候是破折号")
	_assert(SovietUI.tally_glyphs(3) == "卌卌卌", "卌 划痕计数")
	_assert(SovietUI.night_zh(3) == "三", "夜数用汉字")
	# 字体工厂是缓存的同一份
	_assert(SovietUI.body_font() == SovietUI.body_font(), "字体工厂有缓存")
	_assert(SovietUI.display_font() != null and SovietUI.mono_font() != null, "三档字体都在")


# ---------------------------------------------------------------------------
func _levels() -> void:
	_assert(Beats.id_for_scene("res://scenes/night_manor.tscn") == "manor", "场景 → manor")
	_assert(Beats.id_for_scene("res://scenes/night_marshalling.tscn") == "marshalling", "场景 → marshalling")
	_assert(Beats.id_for_scene("res://scenes/nope.tscn") == "", "未知场景不映射")
	var with_scene := 0
	for L in Data.LOCS:
		var sc := String(L.get("scene", ""))
		if sc == "":
			continue
		with_scene += 1
		var lid := Beats.id_for_scene(sc)
		_assert(lid != "", "战役地图 %s 有档案层" % L["id"], sc)
		if lid != "":
			var b := Beats.for_level(lid)
			_assert(String(b.get("zone", "")).contains("НОВОРСК"), "%s 有厂标" % lid, String(b.get("zone", "")))
			_assert((b.get("brief", []) as Array).size() >= 2, "%s 档案卡至少两行" % lid)
			_assert((b.get("landmarks", []) as Array).size() >= 3, "%s 至少三处地标" % lid)
			_assert(Beats.environment_zh(b) != "", "%s 环境节拍有说法" % lid)
	_assert(with_scene >= 3, "至少三关接进档案层", str(with_scene))


# ---------------------------------------------------------------------------
func _common(s: Node, tag: String) -> void:
	# 界面的三层都建出来了
	_assert(s.get_node_or_null("HUD/Root/Chrome") != null, tag + " 有整屏金属框")
	_assert(s.get_node_or_null("HUD/Root/Dossier") != null, tag + " 有左上档案牌")
	_assert(s.get_node_or_null("HUD/Root/Mission") != null, tag + " 有右上任务卡")
	_assert(s.get_node_or_null("HUD/Root/Teletype") != null, tag + " 有底部电传条")
	_assert(s._m_warm != null and s._m_hp != null, tag + " 两条分段仪表")
	_assert(s._chrome != null and s._chrome.danger >= 0.0, tag + " 金属框读得到危险度")
	# 关键物资点必须落在「必出 prize」的容器上（HUD 的方位读数不能指错）
	var found := false
	var target := Vector2.ZERO
	for c in s.containers:
		if String(c.get_meta("guaranteed", "")) == s.prize:
			found = true
			target = s.interact_point(c)
	_assert(found, tag + " 场景里有必出 prize 的容器", s.prize)
	if found:
		_assert(s.objective_px.distance_to(target) < 1.0, tag + " objective_px 指的就是它",
			"%s vs %s" % [s.objective_px, target])
	# 地标：坐标必须在镜头边界内（米）
	var max_x: float = float(s.cam.limit_right) / PPM
	var max_y: float = float(s.cam.limit_bottom) / GY
	var outside := 0
	for l in s.landmarks:
		var p: Array = l["pos"]
		if float(p[0]) < 0.0 or float(p[0]) > max_x or float(p[1]) < 0.0 or float(p[1]) > max_y:
			outside += 1
	_assert(outside == 0, tag + " 地标全在图内", str(outside))
	# 刷新一帧界面不报错，并且读数有内容
	s._refresh_hud()
	_assert(s._lbl_bearing.text.contains("方位"), tag + " 任务卡有方位读数", s._lbl_bearing.text)
	_assert(s._lbl_landmarks.text.contains("勘踏"), tag + " 任务卡有勘踏进度", s._lbl_landmarks.text)
	s._update_brief_text()
	_assert(s._brief_lbl.text.contains("危险度"), tag + " 档案卡写了危险度")
	# 走近第一处地标 → 记一笔
	var first: Dictionary = s.landmarks[0]
	var fp := s._m_px(first["pos"])
	s.player.global_position = fp
	s._update_landmarks()
	_assert(s.landmark_seen.size() >= 1, tag + " 走近地标会记一笔", str(s.landmark_seen))


# ---------------------------------------------------------------------------
func _yard() -> void:
	var y: Node = _scene("res://scenes/night_explore.tscn")
	_assert(y.beats.get("events", []).is_empty(), "yard 没有环境节拍（回归基准别动它）")
	_common(y, "yard")


# ---------------------------------------------------------------------------
func _marshalling() -> void:
	var m: Node = _scene("res://scenes/night_marshalling.tscn")
	var ev: Dictionary = m.beat_events[0]
	_assert(String(ev["kind"]) == "hump", "marshalling 的节拍是驼峰溜放")
	# 节拍股道必须是真实股道
	_assert(float(ev["lane"]) in m.rail_y, "溜放主股道在 rail_y 里", str(ev["lane"]))
	_assert(float(ev["lane_alt"]) in m.rail_y, "备用股道也在 rail_y 里", str(ev["lane_alt"]))
	_common(m, "marshalling")

	# ---- 导演状态机：warn → live → 收尾 ----
	m.beat_timer = 0.0
	m._update_beats(0.016)
	_assert(m.beat_phase == "warn", "到点先预警", m.beat_phase)
	m.beat_t = float(ev["warn"]) + 0.01
	m._update_beats(0.016)
	_assert(m.beat_phase == "live", "预警结束进入 live", m.beat_phase)
	_assert(m.beat_rake != null, "live 时股道上有车皮")
	# 站在那股道上会被刮倒
	m.player.global_position = m._m_px([float(ev["from"]) - 1.0, float(ev["lane"])])
	var hp0: float = m.hp
	m._tick_hump(ev, 0.02, 0.016)
	_assert(m.beat_shoved and m.hp < hp0, "站在股道上被车皮刮倒", str(m.hp))
	# 收尾：车皮回收
	m.beat_t = float(ev["warn"]) + float(ev["live"]) + 0.01
	m._update_beats(0.016)
	_assert(m.beat_phase == "" and m.beat_rake == null, "节拍结束后车皮回收")
	_assert(is_equal_approx(m.beat_timer, float(ev["period"])), "下一拍按 period 排队", str(m.beat_timer))

	# ---- 扳道岔 ----
	var stand: Node2D = m.get_node("World/Props/SwitchStand01")
	m.player.global_position = stand.global_position
	var mech: Dictionary = m.nearest_mechanism()
	_assert(not mech.is_empty() and String(mech["kind"]) == "switch", "靠近转辙器能交互")
	m.use_mechanism(mech)
	_assert(m.switch_thrown, "扳过道岔后 switch_thrown")
	m._spawn_rake(ev)
	_assert(is_equal_approx(m.beat_rake_lane, float(ev["lane_alt"])), "扳过道岔后溜放改走备用股",
		str(m.beat_rake_lane))
	if m.beat_rake != null:
		m.beat_rake.queue_free()
		m.beat_rake = null


# ---------------------------------------------------------------------------
func _manor() -> void:
	var g: Node = _scene("res://scenes/night_manor.tscn")
	var ev: Dictionary = g.beat_events[0]
	_assert(String(ev["kind"]) == "flare", "manor 的节拍是炉口爆燃")
	_common(g, "manor")

	# ---- 爆燃：站在炉口视野里 = 被照亮 ----
	g.beat_timer = 0.0
	g._update_beats(0.016)
	_assert(g.beat_phase == "warn", "炉口爆燃先预警")
	g.beat_t = float(ev["warn"]) + 0.01
	g._update_beats(0.016)
	_assert(g.beat_phase == "live", "预警结束进入 live")
	g.player.global_position = g._m_px([32.0, 8.0])      # 炉口前的空地
	g._tick_flare(ev, 0.35)
	_assert(g.beat_flare > 0.0, "爆燃时后处理 flare > 0", str(g.beat_flare))
	_assert(g.beat_shoved, "站在明处会被照亮（附近清杀队被叫过来）")
	var lit := 0
	for s in g.soldiers:
		if s.state == "alert":
			lit += 1
	_assert(lit >= 1, "至少一组特勤转入警戒", str(lit))
	g.beat_t = float(ev["warn"]) + float(ev["live"]) + 0.01
	g._update_beats(0.016)
	_assert(g.beat_phase == "" and is_zero_approx(g.beat_flare), "爆燃结束，flare 归零")

	# ---- 叉车：一次性的大罐头 ----
	var fork: Node2D = g.get_node("World/Props/Forklift")
	g.player.global_position = fork.global_position
	var mech: Dictionary = g.nearest_mechanism()
	_assert(not mech.is_empty() and String(mech["kind"]) == "forklift", "靠近叉车能交互")
	g.use_mechanism(mech)
	_assert(g.forklift_used, "叉车发动过一次")
	_assert(g.nearest_mechanism().is_empty(), "叉车之后不再提示（一次性）")
	_assert(g.ripples.size() >= 1, "叉车制造了一声巨响", str(g.ripples.size()))
