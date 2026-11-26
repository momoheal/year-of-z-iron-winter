extends SceneTree
## bench_night.gd — 夜潜场景逐帧耗时基准（移动流畅度优化的前后对比用）。
##
## Run:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path godot_project -s tools/bench_night.gd
##   可选参数（放在 -- 之后）：--frames=600 --scenes=night_explore,night_coldstore
##
## 方法：独立（F2）模式实例化关卡，玩家按固定脚本走位（右 → 下 → 左 → 上，冲刺 / 蹲伏交替），
## 关掉自动 _process / 玩家 _physics_process，改由基准循环手动调用并用 Time.get_ticks_usec 计时
## （-s 模式下 Performance 的 TIME_* 监视器不可信）；敌人等其余节点照常运行。headless 无 GPU 渲染。
## 输出：每个场景 avg / p95 / max（毫秒）与对象数增长，最后一行 BENCH_JSON 便于存档对比。

const DEFAULT_SCENES := ["night_explore", "night_coldstore", "night_market"]

var frames := 600
var scenes: Array = DEFAULT_SCENES.duplicate()


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--frames="):
			frames = maxi(60, int(a.substr(9)))
		elif a.begins_with("--scenes="):
			scenes = Array(a.substr(9).split(",", false))
	_run.call_deferred()


func _pct(arr: Array, p: float) -> float:
	if arr.is_empty():
		return 0.0
	var s := arr.duplicate()
	s.sort()
	return float(s[clampi(int(round(p * (s.size() - 1))), 0, s.size() - 1)])


func _avg(arr: Array) -> float:
	var t := 0.0
	for v in arr:
		t += float(v)
	return t / maxf(1.0, float(arr.size()))


func _release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "sprint", "crouch"]:
		Input.action_release(a)


func _drive(i: int) -> void:
	# 每 90 帧换一个方向；偶数段冲刺，3 的倍数段蹲伏
	var seg := int(i / 90)
	_release_all()
	var dirs := ["move_right", "move_down", "move_left", "move_up"]
	Input.action_press(dirs[seg % 4])
	if seg % 2 == 0:
		Input.action_press("sprint")
	elif seg % 3 == 0:
		Input.action_press("crouch")


func _run() -> void:
	var rb := root.get_node_or_null("RaidBridge")
	if rb != null:
		rb.clear()
	var out := {}
	for name in scenes:
		var path := "res://scenes/%s.tscn" % String(name)
		if not ResourceLoader.exists(path):
			print("skip (missing): ", path)
			continue
		var s: Node = (load(path) as PackedScene).instantiate()
		root.add_child(s)
		for i in 30:
			await process_frame
		# 关掉开场简报 / 过场，直接进入可操作状态
		if s.get("state") != null and String(s.state) != "play":
			s.state = "play"
		if s.get("player") != null and s.player != null:
			s.player.frozen = false
		# 手动驱动两个热点，逐帧计时（微秒）：NightExplore._process（HUD / 导演 / 特效）与玩家移动
		s.set_process(false)
		var pl = s.get("player")
		if pl != null:
			pl.set_physics_process(false)
		var proc: Array = []
		var phys: Array = []
		var wall: Array = []
		var objs0 := int(Performance.get_monitor(Performance.OBJECT_COUNT))
		var hud0: int = int(s.get("hud_full_refreshes")) if s.get("hud_full_refreshes") != null else -1
		var last := Time.get_ticks_usec()
		var dt := 1.0 / 60.0
		for i in frames:
			_drive(i)
			var t0 := Time.get_ticks_usec()
			s._process(dt)
			var t1 := Time.get_ticks_usec()
			if pl != null:
				pl._physics_process(dt)
			var t2 := Time.get_ticks_usec()
			proc.append((t1 - t0) / 1000.0)
			phys.append((t2 - t1) / 1000.0)
			await process_frame
			var now := Time.get_ticks_usec()
			wall.append((now - last) / 1000.0)
			last = now
		_release_all()
		var hud_n: int = (int(s.get("hud_full_refreshes")) - hud0) if hud0 >= 0 else -1
		var objs1 := int(Performance.get_monitor(Performance.OBJECT_COUNT))
		# 微基准：HUD 刷新单次耗时
		var hud_us: Array = []
		if s.has_method("_refresh_hud"):
			for i in 300:
				var t0 := Time.get_ticks_usec()
				s._refresh_hud()
				hud_us.append(float(Time.get_ticks_usec() - t0))
		# 逐函数拆分：同一状态下把 _process 里的各段单独调用 300 次取平均（微秒）
		var breakdown := {}
		for fn in ["_update_zone", "_update_interact", "_update_combat", "_update_warmth", "_update_director",
				"_update_brief", "_update_fx", "_update_fade", "_update_post", "_refresh_hud"]:
			if not s.has_method(fn):
				continue
			var us: Array = []
			for i in 300:
				var t0 := Time.get_ticks_usec()
				if fn in ["_update_fade", "_update_post", "_refresh_hud"]:
					s.call(fn)
				else:
					s.call(fn, dt)
				us.append(float(Time.get_ticks_usec() - t0))
			breakdown[fn] = snappedf(_avg(us), 0.1)
		var row := {
			"process_ms_avg": snappedf(_avg(proc), 0.001),
			"process_ms_p95": snappedf(_pct(proc, 0.95), 0.001),
			"process_ms_max": snappedf(_pct(proc, 1.0), 0.001),
			"player_move_ms_avg": snappedf(_avg(phys), 0.001),
			"player_move_ms_p95": snappedf(_pct(phys, 0.95), 0.001),
			"frame_wall_ms_avg": snappedf(_avg(wall), 0.001),
			"frame_wall_ms_p95": snappedf(_pct(wall, 0.95), 0.001),
			"hud_refresh_us_avg": snappedf(_avg(hud_us), 0.1),
			"object_growth": objs1 - objs0,
			"breakdown_us": breakdown,
			"hud_full_refreshes_per_600": hud_n,
		}
		out[String(name)] = row
		print("%-18s _process avg %.3f p95 %.3f max %.3f ms | player move avg %.3f p95 %.3f | wall p95 %.3f | hud %.1f us | objects %+d" % [
			name, row["process_ms_avg"], row["process_ms_p95"], row["process_ms_max"],
			row["player_move_ms_avg"], row["player_move_ms_p95"], row["frame_wall_ms_p95"],
			row["hud_refresh_us_avg"], row["object_growth"]])
		print("    breakdown µs: ", breakdown, "  hud full refreshes / %d frames: %d" % [frames, row["hud_full_refreshes_per_600"]])
		s.queue_free()
		for i in 5:
			await process_frame
	print("BENCH_JSON ", JSON.stringify(out))
	quit(0)
