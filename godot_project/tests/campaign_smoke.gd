extends SceneTree
## Headless smoke test — 「一夜」探索循环（Campaign）
##
## Run:
##   Godot_v4.7.2-stable_win64 --headless --path godot_project -s tests/campaign_smoke.gd
##
## 覆盖：工程装配（main_scene = campaign.tscn）/ 数据表与 HTML 原型一致 /
##       新游戏初始状态 / 地点解锁门槛 / 携带物上限 / 出发 → 夜潜 /
##       程序化城市生成可复现 + 连通性 / 搜刮与背包上限 / 卡门 15s / 破门 /
##       撤离 / 四种收场（extracted / dawn / downed / abort）/
##       次日透析与母亲死亡 / 剧情节拍 ops / 结局判定 / 战利品尺寸 /
##       HUD 六个界面重建。
##
## 成功输出：CAMPAIGN_SMOKE_PASS

const Data := preload("res://scripts/CampaignData.gd")
const SimScript := preload("res://scripts/CampaignSim.gd")
const Gen := preload("res://scripts/RaidGen.gd")

const FRAME := 1.0 / 60.0

var passes: int = 0
var failures: Array[String] = []
var scene: Node

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

func _hold(sim, seconds: float, at: Vector2 = Vector2(-1, -1)) -> void:
	var R = sim.raid
	if at.x >= 0.0:
		R.player.x = at.x
		R.player.y = at.y
	var steps := int(seconds / FRAME)
	for i in steps:
		R.update(FRAME, Vector2.ZERO, false, false, Vector2(R.player.x + 2.0, R.player.y), true)

func _fresh_raid(sim, loc_id: String = "boiler") -> void:
	var L: Dictionary = Data.loc(loc_id)
	sim.selected_loc = loc_id
	sim.load = {"can": 0, "water": 1, "asp": 1, "band": 2}
	sim.depart(L)

func _clear_hostiles(R) -> void:
	# 机械性测试期间清空所有活体，避免半人抢先触发抉择 A、狂暴者打断搜刮
	for e in R.ents:
		e.dead = true

func _reachable(R) -> Dictionary:
	var seen := {}
	var q: Array[Vector2i] = [Vector2i(int(floor(R.entry.x)), int(floor(R.entry.y)))]
	seen[q[0]] = true
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if n.x < 0 or n.y < 0 or n.x >= R.W or n.y >= R.H:
				continue
			if seen.has(n):
				continue
			if not Gen.walkable(R.at(n.x, n.y)):
				continue
			seen[n] = true
			q.append(n)
	return seen

func _run_tests() -> void:
	print("==== Exploration-loop (Campaign) headless smoke test ====")

	# --- 1. 工程装配 -------------------------------------------------------
	_assert(ProjectSettings.get_setting("application/run/main_scene", "") == "res://scenes/campaign.tscn",
		"1. main scene = res://scenes/campaign.tscn")
	var packed: PackedScene = load("res://scenes/campaign.tscn")
	_assert(packed != null, "2. campaign.tscn loads")
	scene = packed.instantiate()
	root.add_child(scene)
	await _frames(4)
	var sim = scene.get("sim")
	var hud = scene.get("hud")
	_assert(sim != null and hud != null, "3. campaign scene wires sim + hud")
	_assert(sim.phase == "title", "4. boots into the title screen")

	# --- 2. 数据表与 HTML 原型一致 ----------------------------------------
	_assert(Data.MAP_W == 64 and Data.MAP_H == 48, "5. map is 64×48 tiles")
	_assert(is_equal_approx(Data.PPM, 26.0) and is_equal_approx(Data.SQUASH, 0.62),
		"6. projection 26 px/m, y-squash 0.62")
	_assert(Data.BAG == 12 and Data.SIGHT == 12.0 and is_equal_approx(Data.SIGHT_CRACKED, 7.2),
		"7. bag 12, sight 12m / 7.2m cracked")
	_assert(Data.ITEMS.size() == 24, "8. 24 item types", str(Data.ITEMS.size()))
	_assert(Data.WEAPONS.size() == 5 and Data.MATES.size() == 5 and Data.LOCS.size() == 13,
		"9. 5 weapons / 5 mates / 13 locations")
	_assert(Data.STORY.size() >= 5, "10. story beats present", str(Data.STORY.size()))
	_assert(Data.weapon("cleaver")["dmg"] == 46.0 and Data.weapon("shotgun")["dmg"] == 95.0 \
		and Data.weapon("mosin")["dmg"] == 150.0, "11. weapon damage 46 / 95 / 150")
	_assert(Data.loc("coldstore")["cold"] == 0.9 and Data.loc("manor")["dg"] == 5,
		"12. location stats match the prototype")

	# --- 3. 新游戏初始状态 -------------------------------------------------
	sim.new_game()
	_assert(sim.day == 1 and sim.mother_alive and is_equal_approx(sim.dial, 2.0),
		"13. new game: day 1, mother alive, 2 bags")
	_assert(int(sim.conscience) == 50 and sim.tally == 0 and sim.names.is_empty(),
		"14. new game: conscience 50, no strokes, no names")
	_assert(int(sim.stash.get("rye", 0)) == 3 and int(sim.stash.get("band", 0)) == 1,
		"15. starting stash rye 3 / bandage 1")
	_assert(sim.nodes.size() == 13, "16. 13 node states")
	_assert(sim.unlocked_count() == 10, "17. 10 locations unlocked at start",
		str(sim.unlocked_count()))

	# --- 4. 解锁门槛 -------------------------------------------------------
	var sanitarium: Dictionary = Data.loc("sanitarium")
	_assert(not sim.loc_unlocked(sanitarium), "18. sanatorium gated at start")
	sim.add_item("intel", 2)
	_assert(sim.loc_unlocked(sanitarium), "19. sanatorium unlocks with 2 intel + 1 med")
	_assert(not sim.loc_unlocked(Data.loc("manor")), "20. manor gated behind the pine-manor flag")
	sim.flags["manor_tip"] = true
	_assert(sim.loc_unlocked(Data.loc("manor")), "21. manor unlocks with manor_tip")
	_assert(not sim.loc_unlocked(Data.loc("marshalling")), "22. marshalling gated behind lana_car3")
	sim.flags["lana_car3"] = true
	_assert(sim.loc_unlocked(Data.loc("marshalling")), "23. marshalling unlocks with lana_car3")

	# --- 5. 队伍 / 携带物 ---------------------------------------------------
	sim.select_mate("ash")
	_assert(sim.mate == "none", "24. locked companion cannot be selected")
	sim.mates["ash"] = true
	sim.select_mate("ash")
	_assert(sim.mate == "ash", "25. unlocked companion selects")
	sim.select_mate("none")
	sim.adjust_load("water", 5)
	_assert(int(sim.load["water"]) == int(sim.stash.get("water", 0)),
		"26. loadout clamped by stash", "%d / %d" % [int(sim.load["water"]), int(sim.stash.get("water", 0))])
	_assert(int(sim.load["can"]) == 0, "27. can stays at 0 when the stash has none")

	# --- 6. 出发 → 夜潜 -----------------------------------------------------
	sim.add_item("can", 2)
	sim.load = {"can": 1, "water": 1, "asp": 1, "band": 1}
	var before_water := int(sim.stash.get("water", 0))
	_fresh_raid(sim, "coldstore")
	_assert(sim.phase == "raid" and sim.raid != null, "28. depart enters the raid phase")
	_assert(int(sim.stash.get("water", 0)) == before_water - 1, "29. loadout deducted from stash")
	var R = sim.raid
	_assert(R.total_cont > 0, "30. raid spawns containers", str(R.total_cont))
	_assert(int(round(R.night_max)) == int(round(maxf(90.0, 80.0 * 2.4))),
		"31. night budget = max(90, travel×2.4)", "%.1f" % R.night_max)
	_assert(R.pack_max == 12, "32. pack capacity 12 without Anna")

	# --- 7. 程序化生成：可复现 + 连通性 -----------------------------------
	var g1: Dictionary = Gen.generate(Data.loc("coldstore"), 1, 1.0)
	var g2: Dictionary = Gen.generate(Data.loc("coldstore"), 1, 1.0)
	_assert(g1["grid"] == g2["grid"], "33. generator is reproducible for the same seed")
	var g3: Dictionary = Gen.generate(Data.loc("coldstore"), 2, 1.0)
	_assert(g1["grid"] != g3["grid"], "34. generator differs across days")
	var reach := _reachable(R)
	var cont_ok := true
	for c in R.conts:
		if not reach.has(Vector2i(int(floor(float(c["x"]))), int(floor(float(c["y"]))))) \
				and not reach.has(Vector2i(int(floor(float(c["x"]) - 0.5)), int(floor(float(c["y"]) - 0.5)))):
			cont_ok = false
	_assert(cont_ok, "35. every container is reachable from the entry")
	_assert(reach.size() > 400, "36. the streets form a connected district", str(reach.size()))

	# --- 8. 移动 / 搜刮 / 背包上限 -----------------------------------------
	_clear_hostiles(R)
	var p = R.player
	var spawn := Vector2(p.x, p.y)
	var best_moved := 0.0
	for dir in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		p.x = spawn.x
		p.y = spawn.y
		for i in 24:
			R.update(FRAME, dir, false, false, Vector2(p.x + dir.x * 3.0, p.y + dir.y * 3.0), false)
		best_moved = maxf(best_moved, spawn.distance_to(Vector2(p.x, p.y)))
	_assert(best_moved > 0.3, "37. WASD moves the player", "%.2f m" % best_moved)
	p.x = spawn.x
	p.y = spawn.y

	var c0: Dictionary = R.conts[0]
	for c in R.conts:
		if Vector2(float(c["x"]), float(c["y"])).distance_to(R.entry) > 3.0:
			c0 = c
			break
	_hold(sim, 2.0, Vector2(float(c0["x"]), float(c0["y"]) + 0.4))
	_assert(bool(c0["searched"]), "38. holding E searches a container")
	_assert(R.looted >= 1 and R.pack.size() >= 1, "39. search yields loot into the pack")
	if R.pack.size() > 0:
		_assert(Data.ITEMS.has(String(R.pack[0])), "40. looted id is a real item")

	R.pack.clear()
	for i in 12:
		R.pack.append("scrap")
	var idx2 := -1
	for i in R.conts.size():
		var cc: Dictionary = R.conts[i]
		if bool(cc["searched"]):
			continue
		if Vector2(float(cc["x"]), float(cc["y"])).distance_to(R.entry) <= 3.0:
			continue
		idx2 = i
		break
	if idx2 >= 0:
		var c2: Dictionary = R.conts[idx2]
		var looted_before := R.looted
		_hold(sim, 2.0, Vector2(float(c2["x"]), float(c2["y"]) + 0.4))
		_assert(R.pack.size() == 12, "41. pack hard-caps at 12", str(R.pack.size()))
		_assert(R.looted > looted_before, "42. overflowing container is still marked searched")

	# 后面的门 / 撤离用例要求「交互目标唯一」：先把所有容器标记为已搜刮
	for c in R.conts:
		c["searched"] = true

	# --- 9. 卡门 15s / 破门 -------------------------------------------------
	var door_tile := Vector2i(-1, -1)
	for j in range(1, R.H - 1):
		for i in range(1, R.W - 1):
			if R.at(i, j) == Data.TT_DOOR \
					and Vector2(i + 0.5, j + 0.5).distance_to(R.entry) > 6.0:
				door_tile = Vector2i(i, j)
				break
		if door_tile.x >= 0:
			break
	if door_tile.x >= 0:
		_hold(sim, 1.6, Vector2(door_tile.x + 0.5, door_tile.y + 0.5))
		_assert(R.at(door_tile.x, door_tile.y) == Data.TT_WEDGED, "43. holding E wedges a door")
		_assert(R.wedged_timers.has(door_tile), "44. wedged door keeps a 15s timer")
		R.wedged_timers[door_tile] = 0.2
		for i in 20:
			R.update(FRAME, Vector2.ZERO, false, false, Vector2(R.player.x + 2.0, R.player.y), false)
		_assert(R.at(door_tile.x, door_tile.y) == Data.TT_DOOR, "45. wedged door springs back after 15s")

	var bdoor_tile := Vector2i(-1, -1)
	for j in range(1, R.H - 1):
		for i in range(1, R.W - 1):
			if R.at(i, j) == Data.TT_BDOOR \
					and Vector2(i + 0.5, j + 0.5).distance_to(R.entry) > 6.0:
				bdoor_tile = Vector2i(i, j)
				break
		if bdoor_tile.x >= 0:
			break
	if bdoor_tile.x >= 0:
		_hold(sim, 1.2, Vector2(bdoor_tile.x + 0.5, bdoor_tile.y + 0.5))
		_assert(R.at(bdoor_tile.x, bdoor_tile.y) == Data.TT_DOOR, "46. holding E pries a building door")

	# --- 10. 撤离 / 结算 ----------------------------------------------------
	R.pack.clear()
	for i in 5:
		R.pack.append("scrap")
	var stash_before := int(sim.stash.get("scrap", 0))
	var band_before := int(sim.stash.get("band", 1))
	_hold(sim, 1.8, R.entry)
	_assert(R.over and R.phase == "extracted", "47. holding E at the entry extracts",
		str(R.phase))
	sim.finish_raid(sim.raid.phase if sim.raid != null else "extracted")
	_assert(sim.phase == "report", "48. extraction lands on the report screen")
	var R2: Dictionary = sim.last_report
	_assert(String(R2["reason"]) == "extracted", "49. report reason is extracted")
	_assert(int(sim.stash.get("scrap", 0)) == stash_before + 5, "50. haul is added to the stash")
	_assert(int(R2["gained"]["scrap"]) == 5, "51. report lists 5 scrap")
	_assert(int(sim.stash.get("band", 0)) >= band_before, "52. unused loadout is returned")
	_assert(int(sim.node_state("boiler")["visits"]) == 0, "53. only the visited node increments")
	_assert(int(sim.node_state("coldstore")["visits"]) == 1, "54. coldstore records one visit")
	var left_after: float = float(sim.node_state("coldstore")["left"])
	_assert(left_after <= 0.5 and left_after >= 0.05,
		"55. node containers drop after a visit", "%.2f" % left_after)

	# --- 11. 天亮了：只带一半物 -------------------------------------------------
	sim.phase = "base"
	sim.raid = null
	sim.last_report = {}
	_fresh_raid(sim, "boiler")
	var R3 = sim.raid
	R3.pack.clear()
	for i in 5:
		R3.pack.append("wire")
	R3.player.hp = 100.0
	sim.finish_raid("dawn")
	_assert(int(sim.last_report["gained"].get("wire", 0)) == 3,
		"56. dawn keeps every other item (3 of 5)", str(sim.last_report["gained"]))
	_assert(int(sim.last_report["hp"]) == 78, "57. dawn costs 22 HP", str(sim.last_report["hp"]))

	# --- 12. 倒地 / 放弃：什么都带不回 ------------------------------------------
	sim.phase = "base"
	_fresh_raid(sim, "boiler")
	sim.raid.pack.clear()
	for i in 4:
		sim.raid.pack.append("vodka")
	var vodka0 := int(sim.stash.get("vodka", 0))
	sim.finish_raid("downed")
	_assert(int(sim.stash.get("vodka", 0)) == vodka0, "58. downed keeps nothing")
	_assert(int(sim.last_report["gained"].size()) == 0, "59. downed report is empty")

	sim.phase = "base"
	_fresh_raid(sim, "boiler")
	sim.raid.pack.clear()
	sim.raid.pack.append("vodka")
	sim.finish_raid("abort")
	_assert(int(sim.stash.get("vodka", 0)) == vodka0, "60. abort keeps nothing")

	# --- 13. 次日：透析与母亲死亡 ---------------------------------------------
	sim.new_game()
	sim.add_item("dial", 1)
	sim.advance_day()
	_assert(sim.day == 2 and is_equal_approx(sim.dial, 3.0), "61. a bag of fluid refills dial to 3")
	_assert(int(sim.stash.get("dial", 0)) == 0, "62. the bag is consumed")
	sim.advance_day()
	_assert(is_equal_approx(sim.dial, 2.0), "63. without fluid dial drops by 1")
	sim.advance_day()
	sim.advance_day()
	_assert(not sim.mother_alive, "64. mother dies when dial runs out")
	_assert(bool(sim.flags.get("mother_lost", false)), "65. mother_lost flag set")
	_assert(int(sim.conscience) == 40, "66. losing mother costs 10 conscience", str(sim.conscience))

	# --- 14. 剧情节拍 ops -----------------------------------------------------
	sim.new_game()
	sim.story_id = "coldstore"
	sim.story_open = true
	var res: Dictionary = sim.resolve_story(0)
	_assert(not res.is_empty() and not sim.story_open, "67. resolving a story closes the modal")
	_assert(sim.names.size() == 1, "68. choice A1 writes one real name")
	_assert(int(sim.conscience) == 58, "69. A1 grants +8 conscience", str(sim.conscience))
	_assert(bool(sim.mates.get("ash", false)), "70. A1 grants Ash via after_mate")
	_assert(bool(sim.story_done.get("coldstore", false)), "71. the beat is marked done")
	_assert(sim.objective()["zh"].find("疗养院") >= 0, "72. objective advances after a name is written")
	var res2: Dictionary = sim.resolve_story(1)
	_assert(res2.is_empty(), "73. replaying a finished beat is a no-op")

	# --- 15. 结局判定 ---------------------------------------------------------
	sim.new_game()
	_assert(sim.ending_key() == "ENDING_C_NUMBNESS", "74. no truth → ending C")
	sim.flags["truth"] = true
	_assert(sim.ending_key() == "TRUE_BETA_OUTLAND_FIRE", "75. truth without mother → TRUE β")
	sim.flags["betrayed"] = true
	_assert(sim.ending_key() == "TRUE_BETA_OUTLAND_FIRE", "76. betrayal alone keeps β")
	sim.flags.erase("betrayed")
	_assert(sim.ending_key() == "TRUE_ALPHA_HELLO_LANA", "77. truth + clean hands → TRUE α")
	sim.tally = 1
	_assert(sim.ending_key() == "ENDING_B_FLAWED_LIBERATION", "78. strokes → ending B")
	sim.mother_alive = false
	_assert(sim.ending_key() == "ENDING_B_FLAWED_LIBERATION", "79. motherless + strokes still B")
	_assert(String(sim.ending_preview()["key"]) == "ENDING_B_FLAWED_LIBERATION",
		"80. ending preview matches the key")

	# --- 16. 武器拼装 / 战利品尺寸 ----------------------------------------------
	sim.new_game()
	var cleaver: Dictionary = Data.weapon("cleaver")
	_assert(not sim.weapon_owned(cleaver), "81. cleaver locked without its blade")
	sim.add_item("blade", 1)
	_assert(sim.weapon_owned(cleaver), "82. cleaver assembles from the blade part")
	_assert(String(sim.best_weapon()["id"]) == "cleaver", "83. best weapon upgrades to the cleaver")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var sample_ok := true
	var ids_ok := true
	for i in 40:
		var c := {"type": "crate"}
		var loot: Array = Gen.gen_loot(Data.loc("boiler"), c, rng, false)
		if loot.size() < 1 or loot.size() > 4:
			sample_ok = false
		for id in loot:
			if not Data.ITEMS.has(String(id)):
				ids_ok = false
	_assert(sample_ok, "84. gen_loot yields 1–4 items per container")
	_assert(ids_ok, "85. gen_loot only yields real item ids")
	var safe_loot: Array = Gen.gen_loot(Data.loc("boiler"), {"type": "safe"}, rng, false)
	_assert(safe_loot.size() >= 3, "86. safes yield at least 3 items", str(safe_loot.size()))

	# --- 17. HUD 各界面重建 ----------------------------------------------------
	sim.new_game()
	sim.phase = "base"
	hud.refresh()
	await _frames(2)
	_assert(hud.body.get_child_count() > 0, "87. base screen builds")
	sim.selected_loc = "coldstore"
	sim.phase = "map"
	hud.refresh()
	await _frames(2)
	_assert(hud.body.get_child_count() > 0, "88. map screen builds")
	sim.phase = "title"
	hud.refresh()
	await _frames(2)
	_assert(hud.body.get_child_count() > 0, "89. title screen builds")
	sim.phase = "ending"
	hud.refresh()
	await _frames(2)
	_assert(hud.body.get_child_count() > 0, "90. ending screen builds")
	sim.logbook_open = true
	hud.refresh()
	await _frames(2)
	_assert(hud.modal.get_child_count() > 0, "91. logbook modal builds")
	sim.logbook_open = false
	sim.help_open = true
	hud.refresh()
	await _frames(2)
	_assert(hud.modal.get_child_count() > 0, "92. help modal builds")
	sim.help_open = false
	sim.story_id = "coldstore"
	sim.story_open = true
	hud.refresh()
	await _frames(2)
	_assert(hud.modal.get_child_count() > 0, "93. story modal builds")
	sim.story_open = false

	# --- 18. 夜潜 HUD + 场景绘制 ------------------------------------------------
	sim.new_game()
	sim.phase = "base"
	_fresh_raid(sim, "boiler")
	hud.refresh()
	await _frames(3)
	_assert(hud.body.get_child_count() > 0, "94. raid HUD builds")
	_assert(scene.get("sim") != null and scene.get("hud") != null,
		"95. campaign scene still holds sim + hud after phase switching")
	sim.raid.abort_confirm = false
	if sim.raid != null:
		sim.raid.finish("abort")
		sim.finish_raid("abort")
	_assert(sim.phase == "report", "96. abort lands on the report screen")

	# --- 19. 灰盒场回归 --------------------------------------------------------
	scene.queue_free()
	await _frames(2)
	var gym_scene: PackedScene = load("res://scenes/gym.tscn")
	var gym: Node = gym_scene.instantiate()
	root.add_child(gym)
	await _frames(3)
	_assert(gym.get("sim") != null, "97. the greybox gym still assembles")
	gym.queue_free()
	await _frames(2)

	print("")
	print("==== RESULT: %d passed, %d failed ====" % [passes, failures.size()])
	if failures.is_empty():
		print("CAMPAIGN_SMOKE_PASS")
	else:
		for f in failures:
			print("  FAILED: ", f)
		print("CAMPAIGN_SMOKE_FAIL")
	quit(0 if failures.is_empty() else 1)
