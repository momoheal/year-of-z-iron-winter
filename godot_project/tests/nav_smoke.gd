extends SceneTree
## Headless smoke test — 夜潜寻路网格（NavGrid）
##
## Run:
##   Godot_v4.7.2-stable_win64 --headless --path godot_project -s tests/nav_smoke.gd
##
## 覆盖：全部 14 张夜潜地图的网格都能建、出生点可走、出生点 → 撤离点连通 /
##       货场铁丝网：直线判定被网挡住、路径从豁口穿过 /
##       行为对照：同一只狂暴者去网对面调查 —— 关掉网格会卡在网北侧，开着网格会绕豁口走到 /
##       追踪中的路径会跟着移动目标重算 / 目标在障碍里时走到最近可达点。
##
## 成功输出：NAV_SMOKE_PASS

const PPM := 64.0
const SQ := 0.62
const LEVELS := ["night_explore", "night_marshalling", "night_manor", "night_mine", "night_market",
	"night_coldstore", "night_canteen", "night_sanitarium", "night_boiler", "night_underpass",
	"night_birch", "night_workshop", "night_greenhouse", "night_archive"]
## 货场（levels/yard.py）：铁丝网 y = 21.5m，豁口 x ∈ (20, 23.5)
const FENCE_Y := 21.5
const GAP := Vector2(20.0, 23.5)

var passes := 0
var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _assert(cond: bool, name: String, detail: String = "") -> void:
	if cond:
		passes += 1
		print("  PASS  ", name)
	else:
		failures.append(name + ((" — " + detail) if detail != "" else ""))
		print("  FAIL  ", name, "  ", detail)


func _m(x: float, y: float) -> Vector2:
	return Vector2(x * PPM, y * PPM * SQ)


func _to_m(p: Vector2) -> Vector2:
	return Vector2(p.x / PPM, p.y / (PPM * SQ))


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame


func _load(name: String) -> Node:
	var s: Node = (load("res://scenes/%s.tscn" % name) as PackedScene).instantiate()
	root.add_child(s)
	return s


func _drop(s: Node) -> void:
	root.remove_child(s)
	s.free()


func _run() -> void:
	print("==== Nav grid smoke ====")
	await _frames(1)

	# --- 1. 每张地图：能建网格、出生点可走、出生点 → 撤离点连通 ---------------
	for lv in LEVELS:
		var t0 := Time.get_ticks_usec()
		var s := _load(lv)
		await _frames(1)
		var nav = s.get("nav")
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		if nav == null:
			_assert(false, "%s: nav grid built" % lv)
			_drop(s)
			continue
		var spawn: Vector2 = (s.get_node("Markers/Spawn") as Node2D).global_position
		var exit: Vector2 = (s.get_node("Markers/Exit") as Node2D).global_position
		var sc: Vector2i = nav.nearest_walkable(nav.cell_of(spawn))
		_assert(nav.solid_count > 0 and sc.x >= 0,
			"%s: grid %dx%d, %d blocked cells, spawn walkable (load %.0f ms)" % [lv, nav.size.x, nav.size.y, nav.solid_count, ms])
		var path: PackedVector2Array = nav.path_px(spawn, exit)
		var end: Vector2 = path[path.size() - 1] if path.size() > 0 else spawn
		var reach: bool = nav.line_clear(spawn, exit) or _to_m(end - exit).length() <= 1.2
		_assert(reach, "%s: exit reachable from spawn" % lv, "path end %.1fm from exit" % _to_m(end - exit).length())
		_drop(s)
		await _frames(1)

	# --- 2. 货场铁丝网：直线被挡、路径走豁口 ------------------------------------
	var y := _load("night_explore")
	await _frames(2)
	var nav = y.get("nav")
	var north := _m(10.0, FENCE_Y - 3.0)
	var south := _m(10.0, FENCE_Y + 3.5)
	_assert(not nav.line_clear(north, south), "yard: the fence blocks the straight line at x=10m")
	var p: PackedVector2Array = nav.path_px(north, south)
	var through_gap := false
	for q in p:
		var qm := _to_m(q)
		if absf(qm.y - FENCE_Y) < 0.6 and qm.x > GAP.x - 0.3 and qm.x < GAP.y + 0.3:
			through_gap = true
	_assert(p.size() > 0 and through_gap, "yard: the path crosses the fence through the cut gap",
		"%d points" % p.size())
	var blocked_target := _m(10.0, FENCE_Y)          # 正好在铁丝网上
	var pb: PackedVector2Array = nav.path_px(north, blocked_target)
	_assert(pb.size() > 0 and _to_m(pb[pb.size() - 1] - blocked_target).length() < 1.5,
		"yard: a target inside the fence resolves to the nearest reachable cell")

	# --- 3. 行为对照：去网对面调查 -----------------------------------------------
	for o in y.soldiers:
		o.process_mode = Node.PROCESS_MODE_DISABLED
	for n in y.get_tree().get_nodes_in_group("night_searchlight"):
		n.process_mode = Node.PROCESS_MODE_DISABLED
	for h in y.halfs:
		h.process_mode = Node.PROCESS_MODE_DISABLED
	var r = y.rabids[0]
	for other in y.rabids:
		if other != r:
			other.process_mode = Node.PROCESS_MODE_DISABLED
	y.player.global_position = _m(44.0, 6.0)          # 远离：别让它改成追玩家
	y.player.process_mode = Node.PROCESS_MODE_DISABLED

	var saved_nav = y.nav
	y.nav = null                                      # 对照组：老的直线走法
	r.global_position = north
	r._nav.clear()
	r.state = "investigate"
	r.target = south
	r._timer = 60.0
	await _frames(600)
	var stuck_y: float = _to_m(r.global_position).y
	_assert(stuck_y < FENCE_Y, "control: without the grid the rabid stays stuck north of the fence",
		"ended at y=%.1fm" % stuck_y)

	y.nav = saved_nav
	r.global_position = north
	r._nav.clear()
	r.state = "investigate"
	r.target = south
	r._timer = 60.0
	var arrived_at := -1
	for f in 1500:
		await physics_frame
		if r.state != "investigate":
			arrived_at = f
			break
	var end_m: Vector2 = _to_m(r.global_position)
	_assert(end_m.y > FENCE_Y and _to_m(r.global_position - south).length() < 1.5,
		"with the grid the rabid walks around through the gap and arrives",
		"ended at (%.1f, %.1f)m after %d frames" % [end_m.x, end_m.y, arrived_at])

	# --- 4. 追踪中目标在动：路径跟着重算 ----------------------------------------
	var ag = load("res://scripts/night/NavGrid.gd").Agent.new()
	var wp1: Vector2 = ag.next(nav, north, south, 0.016)
	var moved := _m(30.0, FENCE_Y + 3.5)
	var wp2 := wp1
	for i in 40:
		wp2 = ag.next(nav, north, moved, 0.016)
	_assert(ag.goal.distance_to(moved) < 1.0 and wp2 != Vector2.INF,
		"agent re-plans when the chased target moves")

	_drop(y)
	print("")
	print("==== RESULT: %d passed, %d failed ====" % [passes, failures.size()])
	if failures.is_empty():
		print("NAV_SMOKE_PASS")
	else:
		for fl in failures:
			print("  FAILED: ", fl)
		print("NAV_SMOKE_FAIL")
	quit(0 if failures.is_empty() else 1)
