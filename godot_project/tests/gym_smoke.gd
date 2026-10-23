extends SceneTree
## Headless smoke test — 5 合 1 灰盒测试场（Gym）
##
## Run:
##   Godot_v4.7.2-stable_win64 --headless --path godot_project -s tests/gym_smoke.gd
##
## 覆盖：工程装配 / 5 个房间 / 传送 / 姿态与蒸汽管隐匿 / 冻雪泥减速 /
##       投罐诱敌与借刀杀人 / 探照灯暴露扣血 / 撬棍卡门 15s / 12cm 推饭盒 /
##       电传真名与抉择 A（A1/A2/A3）/ 卌 划痕上限 / 安娜 0419 /
##       砍骨刀拾取 / 瓦西里破门 / 锁骨卡刀 6 连按 QTE / PTSD 干渴幻听 /
##       灰烬三态嗅觉 / 语言、眼镜、日志开关 / reset 归零 / Room A 切片回归。
##
## 成功输出：GYM_SMOKE_PASS

const SimScript := preload("res://scripts/GymSim.gd")
const FRAME := 1.0 / 60.0

var passes: int = 0
var failures: Array[String] = []
var scene: Node
var sim
var hud

func _init() -> void:
	_run_tests.call_deferred()

func _assert(cond: bool, name: String, detail: String = "") -> void:
	if cond:
		passes += 1
		print("  PASS  ", name)
	else:
		failures.append(name + ((" — " + detail) if detail != "" else ""))
		print("  FAIL  ", name, "  ", detail)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _step(n: int, move: Vector2 = Vector2.ZERO, sprint: bool = false,
		mouse: Vector2 = Vector2(550, 340)) -> void:
	for i in n:
		sim.update(FRAME, move, sprint, mouse)

func _place(x: float, y: float) -> void:
	sim.player.x = x
	sim.player.y = y
	sim.dog.x = x - 20.0
	sim.dog.y = y + 8.0

func _close_modals() -> void:
	sim.logbook_open = false
	sim.choice_modal_open = false

func _run_tests() -> void:
	print("==== Greybox Gym headless smoke test (5-in-1) ====")

	# --- 1. 工程装配 -------------------------------------------------------
	_assert(ProjectSettings.get_setting("application/run/main_scene", "") == "res://scenes/gym.tscn",
		"1. main scene = res://scenes/gym.tscn")

	var required := ["move_up", "move_down", "move_left", "move_right", "sprint", "crouch",
		"attack_primary", "interact", "throw_can", "drink", "bandage", "reload",
		"toggle_logbook", "restart",
		"gym_room_1", "gym_room_2", "gym_room_3", "gym_room_4", "gym_room_5",
		"gym_toggle_lang", "gym_toggle_glasses", "gym_toggle_mute", "gym_reset", "gym_switch_scene"]
	var missing: Array[String] = []
	for a in required:
		if not InputMap.has_action(a):
			missing.append(a)
	_assert(missing.is_empty(), "2. Input map has all 24 actions", "missing: " + ", ".join(missing))

	# --- 2. 场景装配（含渲染帧，覆盖 _draw 路径） --------------------------
	var packed: PackedScene = load("res://scenes/gym.tscn")
	_assert(packed != null, "3. gym.tscn loads")
	scene = packed.instantiate()
	root.add_child(scene)
	await _frames(6)
	sim = scene.get("sim")
	hud = scene.get("hud")
	_assert(sim != null and hud != null, "4. Gym scene owns Sim + HUD")
	_assert(hud.get("sim") == sim, "5. HUD bound to the same Sim instance")
	scene.set_process(false)

	# --- 3. 初始状态 -------------------------------------------------------
	var p = sim.player
	_assert(p.x == 85.0 and p.y == 145.0, "6. Spawn at Room A (85,145)",
		"got (%s,%s)" % [p.x, p.y])
	_assert(p.hp == 100.0 and p.bpm == 76.0 and p.cans == 5 and p.weapon == "crowbar",
		"7. HP 100 / BPM 76 / 5 cans / crowbar")
	_assert(sim.tally_strokes == 0 and not sim.ptsd_unlocked and sim.tasks_done_count() == 0,
		"8. 0 tally strokes, no PTSD, 0/5 tasks")
	_assert(sim.verified_names.size() == 1, "9. Logbook starts with Mama Katya only")
	_assert(sim.dog.state == "follow", "10. Ash starts trailing")

	# --- 4. 5 个房间 + 传送 ------------------------------------------------
	_assert(SimScript.ROOM_ZONES.size() == 5, "11. 5 room zones (A–E)")
	var all_rooms_ok := true
	for room_id in ["A", "B", "C", "D", "E"]:
		sim.teleport(room_id)
		var spawn: Vector2 = SimScript.ROOM_SPAWNS[room_id]
		_step(1)
		if sim.current_room()["id"] != room_id or sim.player.x != spawn.x or sim.player.y != spawn.y:
			all_rooms_ok = false
	_assert(all_rooms_ok, "12. Teleport 1–5 lands in the correct room")

	# --- 5. 姿态 / 蒸汽管隐匿 / 冻雪泥 ------------------------------------
	sim.reset()
	_place(200.0, 140.0)
	_assert(not sim.player.crouching, "13. Starts standing")
	sim.toggle_crouch()
	_step(1)
	_assert(sim.player.crouching and sim.player.in_pipe_shadow,
		"14. Crouch inside steam-pipe shadow => hidden")
	# 探照灯免疫：士兵在正上方朝下，玩家在阴影内
	sim.soldier.x = 200.0
	sim.soldier.y = 60.0
	sim.soldier.angle = PI / 2.0
	sim.soldier.target_angle = PI / 2.0
	sim.soldier.patrol_min_x = 200.0
	sim.soldier.patrol_max_x = 200.0
	sim.soldier.fire_cd = 0.0
	_step(10)
	_assert(sim.player.hp == 100.0, "15. Pipe shadow => 100% searchlight immunity",
		"hp=%s" % sim.player.hp)
	# 站出阴影立刻被点射（下限 15 HP）
	sim.toggle_crouch()
	sim.soldier.fire_cd = 0.0
	_step(2)
	_assert(sim.player.hp < 100.0 and sim.player.hp >= 15.0,
		"16. Exposed in the beam => suppressed AKM burst",
		"hp=%s" % sim.player.hp)

	# 冻雪泥减速 ×0.65
	sim.reset()
	_place(300.0, 600.0)
	var x0: float = sim.player.x
	_step(10, Vector2(1, 0))
	var dx_floor: float = sim.player.x - x0
	_place(70.0, 250.0)
	_step(1)
	_assert(sim.player.in_slush, "17. Frozen slush rect detected")
	var x1: float = sim.player.x
	_step(10, Vector2(1, 0))
	var dx_slush: float = sim.player.x - x1
	var ratio: float = dx_slush / maxf(dx_floor, 0.001)
	_assert(ratio > 0.55 and ratio < 0.75, "18. Slush slows movement to ~0.65×",
		"ratio=%.3f" % ratio)

	# --- 6. 投罐 → 清杀兵调查 → 借刀杀人 ----------------------------------
	sim.reset()
	sim.mouse = Vector2(300, 200)
	sim.throw_can()
	_assert(sim.player.cans == 4 and sim.thrown_cans.size() == 1,
		"19. Throw tin can consumes 1 can")
	_step(20, Vector2.ZERO, false, Vector2(300, 200))
	_assert(sim.thrown_cans.is_empty(), "20. Tin can lands within 20 frames")
	_assert(sim.soldier.alert_frames > 0.0, "21. Landing noise makes O.S.K. investigate")

	sim.reset()
	sim.soldier.x = 355.0
	sim.soldier.y = 180.0
	sim.soldier.angle = PI / 2.0
	sim.soldier.target_angle = PI / 2.0
	sim.soldier.patrol_min_x = 355.0
	sim.soldier.patrol_max_x = 355.0
	sim.rabids[1].alive = false
	sim.rabids[0].x = 355.0
	sim.rabids[0].y = 225.0
	_place(80.0, 145.0)
	_step(50)
	_assert(not sim.rabids[0].alive, "22. O.S.K. fires on the Rabid inside the beam")
	_assert(bool(sim.tasks_done["A"]), "23. Task A (Borrowing the Knife) verified")
	_assert(sim.shots_fired >= 1, "24. Suppressed bursts recorded")

	# --- 7. Room B：卡门 15s + 12cm 推饭盒 --------------------------------
	sim.reset()
	sim.teleport("B")
	_place(sim.door_b.x + sim.door_b.w * 0.5, sim.door_b.y + 40.0)
	sim.interact()
	_assert(is_equal_approx(sim.door_b.wedge_frames, 900.0) and sim.door_b.ever_wedged,
		"25. Crowbar wedges the steel door for 15 s")
	_assert(not bool(sim.tasks_done["B"]), "26. Door wedge alone does not finish Task B")
	_step(60)
	_assert(is_equal_approx(sim.wedge_seconds(), 14.0), "27. Wedge timer counts down",
		"seconds=%.2f" % sim.wedge_seconds())
	_place(sim.fence_box.x, sim.fence_box.y + 30.0)
	sim.interact()
	_assert(sim.fence_box.delivered and bool(sim.tasks_done["B"]),
		"28. Lunchbox pushed under the 12cm gap => Task B done")

	# --- 8. Room C：账面死人 + 抉择 A ------------------------------------
	sim.reset()
	sim.teleport("C")
	_place(sim.terminal.x, sim.terminal.y + 30.0)
	sim.interact()
	_assert(sim.terminal.recorded, "29. Teletype real names recorded")
	_assert(not bool(sim.tasks_done["C"]), "30. Recording names alone does not finish Task C")
	_place(sim.half_human.x, sim.half_human.y + 30.0)
	sim.interact()
	_assert(sim.choice_modal_open, "31. Choice A modal opens at the half-human")
	sim.choose_a("A2")
	_assert(not sim.choice_modal_open and sim.half_human.status == "unresolved",
		"32. A2 steps back without resolving")
	sim.interact()
	sim.choose_a("A1")
	_assert(sim.half_human.status == "saved_A1" and sim.tally_strokes == 0,
		"33. A1 saves the youth with 0 tally strokes")
	_assert(bool(sim.tasks_done["C"]), "34. Task C verified (names + Choice A)")

	sim.reset()
	sim.teleport("C")
	_place(sim.half_human.x, sim.half_human.y + 30.0)
	sim.interact()
	sim.choose_a("A3")
	_assert(sim.half_human.status == "killed_A3" and sim.tally_strokes == 2,
		"35. A3 execution carves 2 tally strokes (卌)")
	_assert(sim.player.cans == 7, "36. A3 loot adds 2 tin cans")

	# --- 9. 卌 划痕边界 ----------------------------------------------------
	sim.add_tally(9, "test", "test")
	_assert(sim.tally_strokes == 5, "37. Tally clamps at 5 strokes")
	sim.add_tally(-99, "test", "test")
	_assert(sim.tally_strokes == 0, "38. Tally clamps at 0 strokes")

	# --- 10. Room D：灰烬三态 + 安娜 0419 ---------------------------------
	sim.reset()
	sim.teleport("D")
	_place(115.0, 495.0)
	_step(1)
	_assert(sim.dog.state == "bark", "39. Ash barks near Cage I (rabid)",
		"state=" + sim.dog.state)
	_place(275.0, 495.0)
	_step(1)
	_assert(sim.dog.state == "whimper", "40. Ash whimpers near Cage II (Anna)",
		"state=" + sim.dog.state)
	_place(435.0, 495.0)
	_step(1)
	_assert(sim.dog.state == "wag", "41. Ash wags near Cage III (father)",
		"state=" + sim.dog.state)
	_place(275.0, 490.0)
	sim.interact()
	_assert(sim.cages[1].inspected and bool(sim.tasks_done["D"]),
		"42. Anna 0419 dialogue verifies Task D")

	# --- 11. Room E：砍骨刀 → 破门 → 6 连按 QTE → PTSD -------------------
	sim.reset()
	sim.teleport("E")
	_place(sim.cleaver.x, sim.cleaver.y + 30.0)
	sim.interact()
	_assert(sim.cleaver.taken and sim.player.weapon == "cleaver",
		"43. Butcher cleaver equipped")
	_place(sim.vasily.x - 120.0, sim.vasily.y)
	_step(1)
	_assert(sim.vasily.state == "charging", "44. Vasily breaches the pantry on approach")
	_step(110)
	var vd: float = sim.player_dist(sim.vasily.x, sim.vasily.y)
	_assert(vd < 80.0, "45. Vasily charges the player", "dist=%.1f" % vd)
	if not sim.qte_active:
		sim.swing()
	_assert(sim.qte_active and sim.vasily.state == "jammed",
		"46. Cleaver swing triggers the collarbone blade jam QTE")
	# 瓦西里近身时会自动触发一次挥刀（HTML 同规则），因此这里补齐到 5/6
	while sim.qte_count < 5:
		sim.qte_hit()
	_assert(sim.qte_active and sim.qte_count == 5, "47. QTE reaches 5/6 without resolving")
	sim.qte_hit()
	_assert(not sim.qte_active and sim.vasily.state == "resolved",
		"48. 6th press wrenches the blade free")
	_assert(sim.ptsd_unlocked and sim.player.bpm == 168.0,
		"49. PTSD thirst unlocked, BPM spikes to 168")
	_assert(bool(sim.tasks_done["E"]), "50. Task E verified")
	sim.drink()
	_assert(sim.ptsd_flash > 0.0 and sim.player.bpm == 152.0,
		"51. Drinking triggers PTSD thirst flash (152 BPM)")

	# --- 12. 全局开关：语言 / 眼镜 / 日志 / 重置 --------------------------
	sim.toggle_lang()
	_assert(sim.lang == "en", "52. Language toggles to EN")
	sim.toggle_lang()
	_assert(sim.lang == "zh", "53. Language toggles back to ZH")
	_assert(is_equal_approx(sim.vision_radius(), 275.0), "54. Vision radius 275 px intact")
	sim.toggle_glasses()
	_assert(sim.glasses_cracked and is_equal_approx(sim.vision_radius(), 165.0),
		"55. Cracked glasses cut vision to 165 px")
	sim.toggle_logbook()
	_assert(sim.logbook_open, "56. Logbook modal toggles")
	hud.refresh()
	sim.toggle_logbook()
	sim.reset()
	_assert(sim.tally_strokes == 0 and not sim.ptsd_unlocked and sim.tasks_done_count() == 0,
		"57. Reset clears tally / PTSD / tasks")
	_assert(sim.verified_names.size() == 1 and sim.player.x == 85.0 and sim.player.cans == 5,
		"58. Reset restores logbook, spawn and supplies")
	_assert(sim.feed.size() >= 1, "59. Reset re-seeds the teletype feed")

	# HUD 在三种模态框下都能刷新而不报错
	sim.choice_modal_open = true
	hud.refresh()
	sim.choice_modal_open = false
	sim.qte_active = true
	hud.refresh()
	sim.qte_active = false
	hud.refresh()
	_assert(true, "60. HUD refresh survives every modal state")

	# --- 13. Room A 夜潜切片回归 ------------------------------------------
	scene.queue_free()
	await _frames(2)
	var room_a: PackedScene = load("res://scenes/main.tscn")
	var room_a_scene: Node = room_a.instantiate()
	root.add_child(room_a_scene)
	await _frames(4)
	var room_a_sim = room_a_scene.get("sim")
	var rabids := 0
	var osks := 0
	for e in room_a_sim.ents:
		if e.kind == "rabid" and not e.dead:
			rabids += 1
		elif e.kind == "osk":
			osks += 1
	_assert(rabids == 2 and osks == 1, "61. Room A night-stalk slice still assembles")

	print("")
	print("==== RESULT: %d passed, %d failed ====" % [passes, failures.size()])
	if failures.is_empty():
		print("GYM_SMOKE_PASS")
	else:
		for f in failures:
			print("  FAILED: ", f)
		print("GYM_SMOKE_FAIL")
	quit(0 if failures.is_empty() else 1)
