extends SceneTree
## Headless smoke test for Room A vertical slice (1:1 HTML architecture).
## Run:  Godot_v4.7.2-stable_win64.exe --headless --path godot_project -s tests/room_a_smoke.gd
##
## 1:1 版特性：单 Node2D + RefCounted 数据对象（Sim），无物理节点。
## 因此 -s 模式下同样禁止全局类名类型注解，全部用无类型 var + scene.get("sim")。
##
## 17 项：
##   输入映射 / 场景与 Sim 装配 / 实体与初始物资 / 地图布局 / 移动与碰撞 /
##   扔罐头声波 / 噪声调查 / 蒸汽管隐匿 / 借刀杀人完整闭环 / 暴露被射 /
##   撤离胜利 / 被咬死亡。

var passes: int = 0
var failures: Array[String] = []

func _init() -> void:
	_run_tests.call_deferred()

func _assert(cond: bool, n: String, detail: String = "") -> void:
	if cond:
		passes += 1
		print("  PASS  ", n)
	else:
		failures.append(n + ((" — " + detail) if detail != "" else ""))
		print("  FAIL  ", n, "  ", detail)

func _new_scene() -> Node:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	return scene

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _release_all() -> void:
	for action in InputMap.get_actions():
		if action.begins_with("move_") or action in ["crouch", "sprint", "interact", "attack_primary"]:
			Input.action_release(action)

func _run_tests() -> void:
	print("==== Room A headless smoke test (1:1 HTML) ====")

	# --- 1. Input map ------------------------------------------------------
	var required := ["move_up", "move_down", "move_left", "move_right", "sprint",
		"crouch", "attack_primary", "interact", "throw_can", "drink",
		"bandage", "reload", "toggle_logbook", "restart"]
	var missing: Array[String] = []
	for a in required:
		if not InputMap.has_action(a):
			missing.append(a)
	_assert(missing.is_empty(), "1. Input map has all 14 actions", "missing: " + ", ".join(missing))

	# --- 2. 场景装配 -------------------------------------------------------
	var scene: Node = _new_scene()
	await _frames(5)
	var sim = scene.get("sim")
	var hud = scene.get("hud")
	_assert(sim != null and hud != null, "2. Main scene owns Sim + HUD")

	# --- 3. 实体构成 -------------------------------------------------------
	var rabids: Array = []
	var osks: Array = []
	for e in sim.ents:
		if e.dead:
			continue
		if e.kind == "rabid":
			rabids.append(e)
		elif e.kind == "osk":
			osks.append(e)
	_assert(rabids.size() == 2 and osks.size() == 1,
		"3. 2 rabids + 1 O.S.K. soldier", "rabids=%d osks=%d" % [rabids.size(), osks.size()])

	# --- 4. 初始物资 -------------------------------------------------------
	var p = sim.player
	_assert(sim.cans == 5 and sim.water == 2 and p.hp == 100.0 and p.stam == 100.0 and p.warmth == 100.0,
		"4. Start: 5 tins, 2 water, HP/STA/TEMP 100", "cans=%d water=%d hp=%d" % [sim.cans, sim.water, p.hp])

	# --- 5. 巡逻路径 -------------------------------------------------------
	var soldier = osks[0]
	_assert(soldier.wp.size() == 4, "5. Soldier has 4 patrol waypoints", str(soldier.wp.size()))

	# --- 6a-d. 地图布局 ----------------------------------------------------
	var walls_ok: bool = true
	for x in range(0, 30):
		if sim.at(x, 0) != sim.TT_WALL or sim.at(x, 19) != sim.TT_WALL:
			walls_ok = false
	for y in range(0, 20):
		if sim.at(0, y) != sim.TT_WALL or sim.at(29, y) != sim.TT_WALL:
			walls_ok = false
	_assert(walls_ok, "6a. Perimeter walls enclose the 30x20 room")
	var pipe_ok: bool = true
	for x in range(4, 11):
		if sim.at(x, 6) != sim.TT_COVER:
			pipe_ok = false
	_assert(pipe_ok, "6b. Steam pipe = 7 COVER tiles at y=6")
	var slush_count: int = 0
	for y in range(10, 14):
		for x in range(8, 14):
			if sim.at(x, y) == sim.TT_SLUSH:
				slush_count += 1
	_assert(slush_count == 24, "6c. Frozen slush 6x4 = 24 tiles", str(slush_count))
	var crates_ok: bool = true
	for t in [Vector2i(17, 6), Vector2i(22, 3), Vector2i(15, 4), Vector2i(16, 4), Vector2i(26, 12)]:
		if sim.at(t.x, t.y) != sim.TT_COVER:
			crates_ok = false
	_assert(crates_ok, "6d. Five scattered cover crates placed")

	# --- 7. WASD 移动 ------------------------------------------------------
	var x0: float = p.x
	Input.action_press("move_right")
	await _frames(40)
	Input.action_release("move_right")
	_assert(p.x > x0 + 0.8, "7. WASD moves player right (%.2fm)" % (p.x - x0), "moved %.3fm" % (p.x - x0))

	# --- 8. 碰撞辅助 -------------------------------------------------------
	_assert(sim.can_stand(3.0, 17.0, 0.35) and not sim.can_stand(0.5, 10.0, 0.35)
		and not sim.can_stand(7.0, 6.0, 0.35),
		"8. canStand: floor pass, wall / pipe cover block")

	# --- 9. 扔罐头：消耗 + 9m 声波（超 8m 截断） ---------------------------
	p.x = 3.0
	p.y = 17.0
	var ripples_before: int = sim.ripples.size()
	sim.throw_can(Vector2(17.5, 4.0))
	var can_r = null
	for r in sim.ripples:
		if r.kind == "can":
			can_r = r
	var landing_in_range: bool = can_r != null and SimScript_hypot(can_r, p) <= 8.01
	_assert(sim.cans == 4 and can_r != null and can_r.max == 9.0 and landing_in_range,
		"9. Throw consumes tin, emits 9m ripple clamped to 8m",
		"cans=%d ripple=%s" % [sim.cans, str(can_r != null)])

	# --- 10. 噪声让狂暴者进入调查 ------------------------------------------
	sim.emit_noise(17.0, 3.2, 9.0, Color("e2e8f0"), "can")
	var investigate_count: int = 0
	for e in sim.ents:
		if e.kind == "rabid" and e.state == "investigate":
			investigate_count += 1
	_assert(investigate_count == 2, "10. Noise within 9m sends both rabids to investigate",
		str(investigate_count))
	scene.queue_free()
	await _frames(3)

	# --- 11. 蒸汽管阴影隐匿 ------------------------------------------------
	scene = _new_scene()
	await _frames(5)
	sim = scene.get("sim")
	p = sim.player
	soldier = sim.ents[2]
	# 把狂暴者清到角落，避免干扰
	for e in sim.ents:
		if e.kind == "rabid":
			e.x = 28.0
			e.y = 1.0
			e.home_x = 28.0
			e.home_y = 1.0
	# 玩家蹲伏在管道南侧阴影带（距掩体 1.3m）；士兵在管道北侧原地面朝南，
	# 巡逻点全部钉在原地，确定性推进 2s，玩家必须 0 伤害、0 锁定。
	p.x = 10.5
	p.y = 8.3
	soldier.x = 10.0
	soldier.y = 3.0
	soldier.state = "investigate"
	soldier.tx = 10.0
	soldier.ty = 3.0
	var wp11: Array[Vector2] = [Vector2(10.0, 3.0), Vector2(10.0, 3.001)]
	soldier.wp = wp11
	soldier.wpi = 0
	soldier.face = PI / 2.0
	soldier.suspect = 0.0
	soldier.lock = 0.0
	var aim11 := Vector2(p.x, p.y - 5.0)
	for _i in range(120):
		sim.update(1.0 / 60.0, Vector2.ZERO, true, false, aim11, false)
	_assert(p.sneak and sim.cover_hides(p.x, p.y, soldier.x, soldier.y)
		and p.hp == 100.0 and soldier.lock == 0.0,
		"11. Crouched behind pipe (enemy still north of it): coverHides=true, never shot (hp=%d lock=%.2f)" % [int(p.hp), soldier.lock],
		"hp=%d lock=%.2f suspect=%.2f" % [p.hp, soldier.lock, soldier.suspect])
	scene.queue_free()
	await _frames(3)

	# --- 12-13. 借刀杀人完整闭环 -------------------------------------------
	# 白盒几何（严格对应 HTML 的 45° 锥 / 0.5s 锁定 / 0.9s 射击间隔 / 共享 lock）：
	# 士兵 (10,10) 面朝南，玩家在 (10,18) 光锥尽头，两只狂暴者 (10,13)/(10,14)
	# 都在士兵与玩家之间的光锥内；罐头扔到 (10,14)（距玩家 4m，可投），
	# 狂暴者扑向罐头/玩家方向，在锥内先被士兵锁定射杀：
	#   双目标 2dt 累计 → 0.25s 射杀第 1 只；
	#   单目标 1dt + 玩家共享 lock → 1.1s 射杀第 2 只（早于玩家被射击）；
	# 玩家在双杀完成时保持满血（锥内锁定先击杀狂暴者，玩家射击条件未触发）。
	scene = _new_scene()
	await _frames(5)
	sim = scene.get("sim")
	p = sim.player
	soldier = sim.ents[2]
	p.x = 10.0
	p.y = 18.0
	soldier.x = 10.0
	soldier.y = 10.0
	soldier.state = "patrol"
	soldier.tx = 10.0
	soldier.ty = 10.0
	var wp12: Array[Vector2] = [Vector2(10.0, 10.0)]
	soldier.wp = wp12
	soldier.wpi = 0
	soldier.face = PI / 2.0
	soldier.lock = 0.0
	sim.ents[0].x = 10.0
	sim.ents[0].y = 13.0
	sim.ents[0].home_x = 10.0
	sim.ents[0].home_y = 13.0
	sim.ents[1].x = 10.0
	sim.ents[1].y = 14.0
	sim.ents[1].home_x = 10.0
	sim.ents[1].home_y = 14.0
	sim.throw_can(Vector2(10.0, 14.0))
	_assert(sim.cans == 4, "12b. Throw consumed one tin in closure", str(sim.cans))
	# 确定性步进：固定 dt=1/60；双杀应在 1.2s 内完成，立即结束。
	var mouse_aim := Vector2(p.x, p.y - 5.0)
	for _i in range(150):
		sim.update(1.0 / 60.0, Vector2.ZERO, false, false, mouse_aim, false)
		if sim.killed_rabids == 2:
			break
	var dead_count: int = 0
	for e in sim.ents:
		if e.kind == "rabid" and e.dead:
			dead_count += 1
	_assert(dead_count == 2 and sim.killed_rabids == 2,
		"12. Both rabids killed by the O.S.K. after lure (borrowed knife)",
		"dead=%d killed=%d" % [dead_count, sim.killed_rabids])
	_assert(p.hp == 100.0,
		"13. Player took zero damage during borrowed-knife (HP %d)" % int(p.hp),
		"hp=%d" % p.hp)
	scene.queue_free()
	await _frames(3)

	# --- 14. 暴露在光锥里会被射击 ------------------------------------------
	# 纯确定性：直接构造 Sim（固定 seed + 固定 dt），避免场景实帧前缀的 RNG 漂移。
	var sim14 = load("res://scripts/Sim.gd").new()
	var p14 = sim14.player
	var s14 = sim14.ents[2]
	for e in sim14.ents:
		if e.kind == "rabid":
			e.x = 28.0
			e.y = 1.0
			e.home_x = 28.0
			e.home_y = 1.0
	# 玩家站在开阔地（不蹲伏），士兵在南面 4m 朝北；确定性推进 4.5s
	# （锁 1.0s 即开火；命中概率 0.75，固定 seed 下首次命中在 3.4s）
	p14.x = 10.5
	p14.y = 12.0
	s14.x = 10.5
	s14.y = 16.0
	var wp7: Array[Vector2] = [Vector2(10.5, 12.0)]
	s14.wp = wp7
	s14.wpi = 0
	s14.state = "patrol"
	s14.face = -PI / 2.0
	var aim14 := Vector2(p14.x, p14.y - 5.0)
	for _i in range(270):
		sim14.update(1.0 / 60.0, Vector2.ZERO, false, false, aim14, false)
	_assert(p14.hp < 100.0,
		"14. Exposed player in beam gets shot (HP %d)" % int(p14.hp),
		"hp stayed 100; suspect %.2f lock %.2f" % [s14.suspect, s14.lock])

	# --- 15. 撤离胜利 ------------------------------------------------------
	scene = _new_scene()
	await _frames(5)
	sim = scene.get("sim")
	p = sim.player
	# 士兵和狂暴者都远离撤离点
	for e in sim.ents:
		e.x = 28.0
		e.y = 17.0
		if e.kind == "rabid":
			e.home_x = 28.0
			e.home_y = 17.0
	p.x = 1.5
	p.y = 15.5
	# 确定性步进：撤离点 1.6m 内按住 E 1.5s（90 步）=> WIN
	var mouse_aim2 := Vector2(p.x, p.y - 5.0)
	for _i in range(120):
		sim.update(1.0 / 60.0, Vector2.ZERO, false, false, mouse_aim2, true)
	_assert(sim.phase == 1 and sim.extract_prog >= 1.0,
		"15. Hold E at EXIT for 1.5s => WIN", "phase=%d prog=%.2f" % [sim.phase, sim.extract_prog])
	scene.queue_free()
	await _frames(3)

	# --- 16. 被狂暴者咬到死亡 ----------------------------------------------
	scene = _new_scene()
	await _frames(5)
	sim = scene.get("sim")
	p = sim.player
	soldier = sim.ents[2]
	# 士兵调离；一只狂暴者贴脸，玩家只剩 1 血
	soldier.x = 28.0
	soldier.y = 17.0
	var wp9: Array[Vector2] = [Vector2(28.0, 17.0)]
	soldier.wp = wp9
	soldier.wpi = 0
	var rabid0 = sim.ents[0]
	rabid0.x = 17.0
	rabid0.y = 3.2
	rabid0.home_x = 17.0
	rabid0.home_y = 3.2
	var rabid1 = sim.ents[1]
	rabid1.x = 28.0
	rabid1.y = 17.0
	rabid1.home_x = 28.0
	rabid1.home_y = 17.0
	p.x = 17.0
	p.y = 4.5
	p.hp = 1.0
	var aim16 := Vector2(p.x, p.y - 5.0)
	for _i in range(120):
		sim.update(1.0 / 60.0, Vector2.ZERO, false, false, aim16, false)
		if sim.phase == 2:
			break
	_assert(sim.phase == 2 and p.hp == 0.0,
		"16. Rabid bite kills the player at 1 HP => LOSE", "phase=%d hp=%d" % [sim.phase, int(p.hp)])
	scene.queue_free()
	await _frames(3)

	# --- 报告 --------------------------------------------------------------
	print("==== RESULT: %d passed, %d failed ====" % [passes, failures.size()])
	if failures.is_empty():
		print("ROOM_A_SMOKE_PASS")
		quit(0)
	else:
		for f in failures:
			print("  FAILED:", f)
		print("ROOM_A_SMOKE_FAIL")
		quit(1)

# 测试脚本里不能直接依赖 SimScript 常量（-s 早期编译），用动态方法
func SimScript_hypot(r, p) -> float:
	return sqrt((r.x - p.x) ** 2 + (r.y - p.y) ** 2)
