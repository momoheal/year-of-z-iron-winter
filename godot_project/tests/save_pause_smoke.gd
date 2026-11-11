extends SceneTree
## Headless smoke test — 战役存档（SaveGame autoload）+ 夜潜暂停菜单（PauseMenu）
##
## Run:
##   Godot_v4.7.2-stable_win64 --headless --path godot_project -s tests/save_pause_smoke.gd
##
## 覆盖：测试隔离（不碰玩家真实存档）/ 存读往返与类型还原 / 只在安全点存档 /
##       结算页存档读回 = 补走过夜 / 坏档与版本不符 / 战役场景自动存档 /
##       标题页继续 + 新开局二次确认 / 主音量设置 /
##       夜潜 Esc 暂停冻结世界 / 菜单 Esc 继续 / 放弃夜潜二次确认 / 离场自动解除暂停。
##
## 成功输出：SAVE_PAUSE_SMOKE_PASS

const SimScript := preload("res://scripts/CampaignSim.gd")

var passes: int = 0
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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save() -> Node:
	return root.get_node("SaveGame")


func _esc() -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	return ev


func _run() -> void:
	print("==== Save + pause smoke ====")
	await _frames(1)
	var SG := _save()

	# --- 1. 测试隔离 --------------------------------------------------------
	_assert(SG != null, "1. SaveGame autoload is registered")
	_assert(SG._save_file() == "user://campaign_save_test.json" and SG._settings_file() == "user://settings_test.cfg",
		"2. test runs use the *_test save / settings paths", SG._save_file())
	SG.delete_save()
	_assert(not SG.has_save() and SG.summary().is_empty(), "3. delete_save → no save, empty summary")

	# --- 2. 存读往返 --------------------------------------------------------
	var a = SimScript.new()
	a.new_game()
	a.phase = "base"
	a.day = 4
	a.dial = 1.5
	a.conscience = 61.0
	a.tally = 2
	a.stash = {"vodka": 3, "dial": 1, "rye": 2}
	a.names.append("Ivanova L.")
	a.flags["truth"] = true
	a.mates["ash"] = true
	a.mate = "ash"
	a.story_done["yard"] = true
	a.nodes["yard"] = {"visits": 2, "left": 0.5, "hint": 1}
	a.add_log("测试日志", "test log")
	a.lang = "en"
	a.sound_on = false
	for i in 7:
		a.rng.randi()
	_assert(SG.save(a), "4. save() at base succeeds")
	_assert(SG.has_save(), "5. has_save() after saving")
	var sm: Dictionary = SG.summary()
	_assert(int(sm.get("day", 0)) == 4 and int(sm.get("tally", -1)) == 2 and bool(sm.get("mother_alive", false)),
		"6. summary: day 4 / 2 strokes / mother alive", str(sm))

	var b = SimScript.new()
	_assert(SG.load_into(b), "7. load_into() succeeds")
	_assert(b.phase == "base" and b.day == 4 and is_equal_approx(b.dial, 1.5)
		and is_equal_approx(b.conscience, 61.0) and b.tally == 2,
		"8. core state round-trips (phase base, day, dial, conscience, tally)")
	_assert(int(b.stash.get("vodka", 0)) == 3 and typeof(b.stash["vodka"]) == TYPE_INT,
		"9. stash counts come back as int, not JSON float", str(b.stash))
	_assert(b.names.size() == 1 and b.names[0] == "Ivanova L." and bool(b.flags.get("truth", false))
		and bool(b.mates.get("ash", false)) and b.mate == "ash" and bool(b.story_done.get("yard", false)),
		"10. names / flags / mates / story round-trip")
	var ny: Dictionary = b.nodes["yard"]
	_assert(typeof(ny["visits"]) == TYPE_INT and int(ny["visits"]) == 2 and is_equal_approx(float(ny["left"]), 0.5)
		and b.nodes.size() == a.nodes.size(), "11. node states round-trip with int visits", str(ny))
	_assert(b.log.size() == a.log.size() and String(b.log[-1]["zh"]) == "测试日志" and typeof(b.log[-1]["day"]) == TYPE_INT,
		"12. campaign log round-trips")
	_assert(b.lang == "en" and b.sound_on == false, "13. language + sound toggle round-trip")
	_assert(b.rng.randi() == a.rng.randi() and b.rng.randi() == a.rng.randi(),
		"14. RNG continues from the same state (64-bit state survives JSON)")

	# --- 3. 只在安全点存档 ----------------------------------------------------
	var before := FileAccess.get_file_as_string(SG._save_file())
	a.phase = "map"
	_assert(not SG.save(a), "15. save() refuses outside base / report (map)")
	a.phase = "raid"
	_assert(not SG.save(a), "16. save() refuses mid-raid")
	_assert(FileAccess.get_file_as_string(SG._save_file()) == before, "17. refused saves leave the file untouched")

	# --- 4. 结算页的档 = 读回后补走过夜 ----------------------------------------
	a.phase = "report"
	a.day = 3
	a.stash["dial"] = 1
	a.dial = 1.0
	_assert(SG.save(a), "18. save() on the report screen succeeds")
	var c = SimScript.new()
	SG.load_into(c)
	_assert(c.phase == "base" and c.day == 4, "19. report save loads as the next morning (day 3 → 4)",
		"phase=%s day=%d" % [c.phase, c.day])
	_assert(int(c.stash.get("dial", 0)) == 0 and is_equal_approx(c.dial, 2.0),
		"20. the overnight dialysis bag was consumed on load", "dial=%s" % c.dial)

	# --- 5. 坏档 / 版本不符（且没有备份可退）------------------------------------
	SG.delete_save()                     # 清掉上面几次保存留下的 .bak：这里测的是「真的无档可读」
	var f := FileAccess.open(SG._save_file(), FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	var d = SimScript.new()
	_assert(not SG.has_save() and not SG.load_into(d) and d.phase == "title",
		"21. corrupt file → no save, load fails, sim untouched")
	f = FileAccess.open(SG._save_file(), FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 999, "day": 9}))
	f.close()
	_assert(not SG.has_save(), "22. unknown save version is ignored")
	SG.delete_save()

	# --- 6. 战役场景：自动存档 / 继续 / 新开局确认 -------------------------------
	var camp: Node = (load("res://scenes/campaign.tscn") as PackedScene).instantiate()
	root.add_child(camp)
	await _frames(3)
	var sim = camp.get("sim")
	var hud = camp.get("hud")
	_assert(sim.phase == "title" and not SG.has_save(), "23. title screen with no save yet")
	hud.start_new_game()
	await _frames(2)
	_assert(SG.has_save() and int(SG.summary().get("day", 0)) == 1, "24. starting a new game autosaves day 1")
	sim.sleep()
	await _frames(2)
	_assert(int(SG.summary().get("day", 0)) == 2, "25. sleeping autosaves the next day",
		str(SG.summary()))
	sim.phase = "map"
	await _frames(2)
	_assert(int(SG.summary().get("day", 0)) == 2, "26. opening the map does not write a save")
	camp.queue_free()
	await _frames(2)

	camp = (load("res://scenes/campaign.tscn") as PackedScene).instantiate()
	root.add_child(camp)
	await _frames(3)
	sim = camp.get("sim")
	hud = camp.get("hud")
	_assert(sim.phase == "title" and sim.day == 1, "27. a fresh launch still boots to the title")
	hud._on_new_game_pressed()
	await _frames(1)
	_assert(sim.phase == "title" and int(SG.summary().get("day", 0)) == 2,
		"28. 'New Game' with a save asks first (first click does nothing destructive)")
	hud.continue_game()
	await _frames(2)
	_assert(sim.phase == "base" and sim.day == 2, "29. Continue restores the saved day at Room 602",
		"phase=%s day=%d" % [sim.phase, sim.day])
	sim.phase = "title"
	await _frames(1)
	hud._on_new_game_pressed()
	hud._on_new_game_pressed()
	await _frames(2)
	_assert(sim.phase == "base" and sim.day == 1 and int(SG.summary().get("day", 0)) == 1,
		"30. confirming 'New Game' starts day 1 and overwrites the save")
	camp.queue_free()
	await _frames(2)
	SG.delete_save()

	# --- 6b. 备份与恢复（替换失败 / 主档损坏 / 残留临时档）----------------------
	SG.delete_save()
	var bk = SimScript.new()
	bk.new_game()
	bk.phase = "base"
	bk.day = 3
	_assert(SG.save(bk) and SG.last_error == "", "B1. first save succeeds with no error")
	bk.day = 4
	SG.save(bk)
	var main_p: String = SG._save_file()
	var bak_p: String = main_p + ".bak"
	var tmp_p: String = main_p + ".tmp"
	_assert(FileAccess.file_exists(bak_p) and int(SG._parse_file(bak_p).get("day", 0)) == 3
		and int(SG._parse_file(main_p).get("day", 0)) == 4,
		"B2. saving again keeps the previous save as .bak (day 3) and the new one as main (day 4)")
	_assert(not FileAccess.file_exists(tmp_p), "B3. no .tmp is left behind after a good save")
	var fb := FileAccess.open(main_p, FileAccess.WRITE)
	fb.store_string("{ half written")
	fb.close()
	_assert(SG.has_save() and int(SG.summary().get("day", 0)) == 3 and SG.last_load_source == "backup",
		"B4. corrupt main save → falls back to the valid backup")
	_assert(String(SG.summary().get("source", "")) == "backup",
		"B5. summary reports the backup source (title shows 'from backup')")
	bk.day = 5
	_assert(SG.save(bk), "B6. saving over a corrupt main still succeeds")
	_assert(int(SG._parse_file(bak_p).get("day", 0)) == 3,
		"B7. a corrupt main is NOT copied over the good backup", str(SG._parse_file(bak_p).get("day", -1)))
	SG.delete_save()
	_assert(not FileAccess.file_exists(main_p) and not FileAccess.file_exists(bak_p) and not FileAccess.file_exists(tmp_p),
		"B8. delete_save removes main, backup and temp files")
	# 只剩一份写完整的 .tmp（替换中途崩溃）：照样能读回
	var ft := FileAccess.open(tmp_p, FileAccess.WRITE)
	bk.day = 6
	ft.store_string(JSON.stringify(SG.to_dict(bk)))
	ft.close()
	_assert(int(SG.summary().get("day", 0)) == 6 and SG.last_load_source == "tmp",
		"B9. a complete leftover .tmp is recovered when main and backup are missing")
	SG.delete_save()
	# 缺必需字段的档不算存档
	var fm := FileAccess.open(main_p, FileAccess.WRITE)
	fm.store_string(JSON.stringify({"version": 1, "day": 2}))
	fm.close()
	_assert(not SG.has_save(), "B10. a save missing required fields is rejected")
	SG.delete_save()
	# 主档路径被占（一个非空目录）：替换失败要报错、不能假装成功
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(main_p))
	var fd := FileAccess.open(main_p.path_join("lock.txt"), FileAccess.WRITE)
	fd.store_string("x")
	fd.close()
	bk.day = 7
	_assert(not SG.save(bk) and SG.last_error != "", "B11. a failed replace returns false with a reason",
		SG.last_error)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main_p.path_join("lock.txt")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main_p))
	SG.delete_save()

	# --- 7. 主音量设置 ------------------------------------------------------
	SG.set_master_volume(0.5)
	_assert(is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.5)),
		"31. master volume applies to the master bus")
	SG.master_volume = 1.0
	SG.load_settings()
	_assert(is_equal_approx(SG.master_volume, 0.5), "32. master volume persists in settings")
	SG.set_master_volume(1.0)

	# --- 8. 夜潜暂停菜单 ----------------------------------------------------
	var s: Node = (load("res://scenes/night_explore.tscn") as PackedScene).instantiate()
	root.add_child(s)
	await _frames(3)
	_assert(s.state == "play" and not paused, "33. night scene starts unpaused in play")
	s._unhandled_input(_esc())
	await _frames(1)
	_assert(paused and s.is_paused(), "34. Esc in play opens the pause menu and pauses the tree")
	var t0: float = s.t
	await _frames(5)
	_assert(is_equal_approx(s.t, t0), "35. the world clock is frozen while paused")
	s._pause._unhandled_input(_esc())
	await _frames(1)
	_assert(not paused and not s.is_paused(), "36. Esc in the menu resumes")
	await _frames(2)
	_assert(s.t > t0, "37. the world clock runs again after resuming")

	s.in_campaign = true                 # 走战役口径的「放弃这次夜潜」（不触发场景切换）
	s.open_pause()
	_assert(not s._pause.request_abort() and s.state == "play" and paused,
		"38. first 'abandon' click only asks for confirmation")
	_assert(s._pause.request_abort() and s.state == "abort" and not paused,
		"39. second click abandons the raid and unpauses")
	s.open_pause()
	_assert(not paused, "40. pause does nothing once the night has ended")

	s.state = "play"
	s.open_pause()
	_assert(paused, "41. (setup) paused again")
	s.queue_free()
	await _frames(2)
	_assert(not paused, "42. leaving the night scene clears the pause")

	print("")
	print("==== RESULT: %d passed, %d failed ====" % [passes, failures.size()])
	if failures.is_empty():
		print("SAVE_PAUSE_SMOKE_PASS")
	else:
		for fl in failures:
			print("  FAILED: ", fl)
		print("SAVE_PAUSE_SMOKE_FAIL")
	quit(0 if failures.is_empty() else 1)
