extends "res://tests/smoke_kit.gd"
const Arsenal := preload("res://scripts/night/Arsenal.gd")
## 伙伴跟随 + 实时特性 smoke（headless）。
## 覆盖：跟随实体生成 / 行走帧加载 / 跟随移动 / 灰烬嗅觉标记 / 安娜半人标注 /
##       伊万撤离点常亮 / 古丽娅每夜一次急救。
## Run: Godot --headless --path godot_project -s tests/night_follower_smoke.gd



func _init() -> void:
	_run.call_deferred()


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
	_assert(f._tex_walk.size() == 8, "ash has Walk0..Walk7 frames", str(f._tex_walk.size()))
	_assert(f._walk_by_direction.get("N", []).size() == 8, "ash has a rear-facing walk cycle")
	_assert(f._walk_by_direction.get("S", []).size() == 8, "ash has a front-facing walk cycle")
	f._update_facing(Vector2.RIGHT)
	_assert(not f._sprite.flip_h, "ash faces right while moving right")
	_assert(f._facing == "E" and f._active_walk == f._walk_by_direction["E"], "ash selects side frames while moving right")
	f._update_facing(Vector2.LEFT)
	_assert(f._sprite.flip_h, "ash faces left while moving left")
	_assert(f._facing == "W" and f._active_walk == f._walk_by_direction["E"], "ash mirrors side frames while moving left")
	f._update_facing(Vector2.UP)
	_assert(not f._sprite.flip_h and f._facing == "N", "ash uses rear frames while moving up")
	_assert(f._active_walk == f._walk_by_direction["N"], "ash selects rear-facing frames")
	f._update_facing(Vector2.DOWN)
	_assert(not f._sprite.flip_h and f._facing == "S", "ash uses front frames while moving down")
	_assert(f._active_walk == f._walk_by_direction["S"], "ash selects front-facing frames")
	var human = load("res://scripts/night/NightFollower.gd").new()
	human.mate_id = "anna"
	human.player_target = s.player
	human.ctl = s
	human.process_mode = Node.PROCESS_MODE_DISABLED
	s.get_node("World").add_child(human)
	human.global_position = s.player.global_position + Vector2(24, 0)
	_assert(human._weapon_id == "pistol" and human._weapon_sprite != null
		and human._weapon_sprite.texture == load(String(Arsenal.spec("pistol")["tex"])),
		"human companion visibly equips its assigned pistol")
	var attack_target = s.soldiers[0]
	human.play_attack(attack_target)
	_assert(human._attack_anim_t > 0.0 and human._muzzle_flash.visible,
		"human companion attack triggers recoil animation and muzzle flash")
	human.queue_free()

	# Every partner has actual frames for the unique views; left reuses mirrored east.
	var directional_mates := ["Ash", "Anna", "Gulya", "Pavel", "Ivan", "Yelena", "Zakhar"]
	var all_direction_frames_exist := true
	for mate in directional_mates:
		var directions := ["N", "S"] if mate == "Ash" else ["N", "E"]
		for direction in directions:
			for i in range(8):
				var path := "res://art/30_props/PRP_%s_Walk%s%d.png" % [mate, direction, i]
				all_direction_frames_exist = all_direction_frames_exist and ResourceLoader.exists(path)
	_assert(all_direction_frames_exist, "all companions have eight frames for each added view")

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

	# 8. 清杀兵进入交战后，伙伴会主动贴近并攻击
	s = _scene()
	await _physics(3)
	f = _follower(s)
	for enemy in s.soldiers + s.rabids:
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.global_position = Vector2(-5000, -5000)
	s.player.global_position = Vector2(3000, 2000)
	var support_enemy = s.soldiers[0]
	support_enemy.global_position = s.player.global_position + Vector2(52, 0)
	support_enemy.state = "alert"
	support_enemy.hp = 20.0
	f.global_position = support_enemy.global_position + Vector2(-24, 0)
	var chosen = f._find_support_target()
	_assert(chosen == support_enemy, "follower selects a nearby alerted soldier as its target")
	f._update_combat_support(chosen, 0.016)
	_assert(not support_enemy.is_alive() and s.companion_kills == 1,
		"follower attack can kill an enemy and records the assist", str(s.companion_kills))
	var ranged_mate = load("res://scripts/night/NightFollower.gd").new()
	ranged_mate.mate_id = "anna"
	ranged_mate.player_target = s.player
	ranged_mate.ctl = s
	ranged_mate.process_mode = Node.PROCESS_MODE_DISABLED
	s.get_node("World").add_child(ranged_mate)
	ranged_mate.global_position = s.player.global_position + Vector2(-20, 0)
	var ranged_target = s.soldiers[1]
	ranged_target.global_position = s.player.global_position + Vector2(100, 0)
	ranged_target.state = "alert"
	ranged_target.hp = 100.0
	s.companion_attack(ranged_mate, ranged_target, 22.0)
	_assert(is_equal_approx(ranged_target.hp, 78.0),
		"armed partner can damage a target beyond melee range", str(ranged_target.hp))
	ranged_mate.queue_free()

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
