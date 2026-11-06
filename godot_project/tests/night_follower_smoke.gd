extends SceneTree
## 伙伴跟随 + 实时特性 smoke（headless）。
## 覆盖：跟随实体生成 / 行走帧加载 / 跟随移动 / 灰烬嗅觉标记 / 安娜半人标注 /
##       伊万撤离点常亮 / 古丽娅每夜一次急救。
## Run: Godot --headless --path godot_project -s tests/night_follower_smoke.gd

var passes: int = 0
var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _assert(cond: bool, n: String, detail: String = "") -> void:
	if cond:
		passes += 1
		print("  PASS  ", n)
	else:
		failures.append(n + ((" — " + detail) if detail != "" else ""))
		print("  FAIL  ", n, "  ", detail)


func _scene() -> Node:
	for c in root.get_children():
		if c.name == "NightExplore":
			root.remove_child(c)
			c.free()
	var s: Node = (load("res://scenes/night_explore.tscn") as PackedScene).instantiate()
	root.add_child(s)
	return s


func _physics(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame


func _follower(s: Node) -> Node:
	var script = load("res://scripts/night/NightFollower.gd")
	for c in s.get_node("World").get_children():
		if c.get_script() == script:
			return c
	return null


func _run() -> void:
	print("== night_follower smoke ==")
	var s := _scene()
	await _physics(3)
	var f = _follower(s)

	# 1. F2 独立跑默认生成灰烬跟随实体
	_assert(f != null, "F2 spawns an ash follower")
	if f == null:
		_finish()
		return
	_assert(f.mate_id == "ash", "default mate is ash", f.mate_id)
	_assert(f.player_target == s.player, "follower targets the player")
	_assert(f._tex_walk.size() == 2, "ash has Walk0/Walk1 frames", str(f._tex_walk.size()))

	# 2. 跟随移动：玩家移远，跟随者追上（与移动后的距离比，不是移动前）
	s.player.global_position += Vector2(400, 0)
	var d_after: float = f.global_position.distance_to(s.player.global_position)
	await _physics(80)
	var d1: float = f.global_position.distance_to(s.player.global_position)
	_assert(d1 < d_after * 0.5, "follower closes distance when player moves away", "%.1f -> %.1f" % [d_after, d1])

	# 3. 灰烬嗅觉：6m 内容器被标记
	var c0 = s.containers[0]
	c0.global_position = f.global_position + Vector2(30, 0)
	await _physics(30)
	_assert(f._marked.has(c0), "ash marks a container within 6m")

	# 4. 安娜：标注半人
	f.mate_id = "anna"
	if s.halfs.size() > 0:
		var h = s.halfs[0]
		h.global_position = f.global_position + Vector2(30, 0)
		await _physics(30)
		_assert(f._marked.has(h), "anna marks a half-human within 8m")
	else:
		_assert(true, "anna half-human mark (yard has no half, skipped)")

	# 5. 伊万：撤离点常亮
	f.mate_id = "ivan"
	f._exit_beacon = false
	f._sense_ivan()
	var exit: Node = s.get_node("Markers/Exit")
	_assert(f._exit_beacon and exit.get_child_count() > 0, "ivan lights up the exit beacon")

	# 6. 古丽娅：每夜一次急救，第二次倒下才致命
	s.mate_id = "gulya"
	s.hp = 0.0
	s._check_downed()
	_assert(s.hp == 40.0 and s._gulya_used, "gulya rescues once from 0 hp", str(s.hp))
	s.hp = 0.0
	s._check_downed()
	_assert(s.state == "downed", "second down is fatal (rescue already used)", s.state)

	# 7. 上锁 / 隐藏容器机制
	var locked_c: Node2D = null
	var hidden_c: Node2D = null
	for c in s.containers:
		if bool(c.get_meta("locked", false)):
			locked_c = c
		if bool(c.get_meta("hidden", false)):
			hidden_c = c
	_assert(locked_c != null, "a welded (locked) container exists")
	_assert(hidden_c != null and hidden_c.modulate.a < 0.1, "a hidden container starts invisible")
	if hidden_c != null:
		# 未显形前不可被搜刮
		s.player.global_position = hidden_c.global_position
		_assert(s.nearest_container() != hidden_c, "hidden container is not searchable before reveal")
		# 伊万显形
		hidden_c.global_position = f.global_position + Vector2(30, 0)
		f._sense_ivan()
		_assert(bool(hidden_c.get_meta("revealed", false)) and hidden_c.modulate.a > 0.5, "ivan reveals the hidden container")
	if locked_c != null:
		# 帕维尔搜刮完成即撬开焊死箱
		s._finish_search(locked_c)
		_assert(not bool(locked_c.get_meta("locked", false)), "pavel's finish_search unwelds the locked box")

	_finish()


func _finish() -> void:
	print("==== RESULT: %d passed, %d failed ====" % [passes, failures.size()])
	if failures.is_empty():
		print("NIGHT_FOLLOWER_SMOKE_PASS")
		quit(0)
	else:
		for f in failures:
			print("  FAILED:", f)
		print("NIGHT_FOLLOWER_SMOKE_FAIL")
		quit(1)
