extends SceneTree

const Sim := preload("res://scripts/CampaignSim.gd")
const Data := preload("res://scripts/CampaignData.gd")
var failures := 0
var passes := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1
		print("FAIL ", label)

func _run() -> void:
	_check_ash_intro()
	for reason in ["extracted", "abort", "frozen", "dawn"]:
		var sim := Sim.new()
		var loc := Data.loc("coldstore")
		check(sim.depart(loc), "depart from 602")
		sim.resolve_story(0)
		var raid: Node = load(sim.pending_scene).instantiate()
		root.add_child(raid)
		check(raid.first_coldstore_visit, "first visit detected through campaign bridge")
		var sealed_meds := raid.get_node("World/Props/SealedMeds") as Node2D
		if reason == "extracted":
			var navigation := raid.get_node("HUD/Root/Navigation") as Control
			check(navigation.anchor_right == 1.0 and navigation.anchor_top == 0.0
				and navigation.get_child(0).name == &"NightMiniMapPanel", "minimap leads the top-right navigation")
			check(raid.mission_marker == raid.interact_point(sealed_meds) and not raid.mission_marker_optional,
				"first guidance marks sealed medicine")
			check(raid._coach != null and raid._coach.visible, "first sortie shows a field lesson")
			var soldier: Node2D = raid.soldiers[0]
			soldier.set("state", "alert")
			raid._coach._process(0.1)
			check(raid._coach._heading.text.contains("OSK"), "first OSK contact interrupts the current lesson")
		raid.pack.clear()
		raid._finish_search(sealed_meds)
		raid._refresh_hud()
		check(raid.mission_marker_optional and raid.mission_marker == raid._m_px([33.9, 10.65]),
			"packing fluid reveals the optional north-awning marker")
		var checked: bool = reason != "extracted"
		if checked:
			raid.player.global_position = raid._m_px([33.9, 10.65])
			raid._update_landmarks()
			raid._refresh_hud()
			check(raid.mission_marker == null and raid._lbl_bearing.text.contains("残号 04"),
				"reading the clue clears its marker and updates the mission")
		else:
			raid.player.global_position = raid.exit_px
			raid._refresh_hud()
			check(raid._lbl_exit.text.contains("已抵达") and raid._lbl_hint.text.contains("长按 E 撤离"),
				"arrival advertises the real extraction interaction")
			Input.action_press("interact")
			raid._update_interact(0.2)
			raid._refresh_hud()
			check(raid.extract_prog > 0.0 and raid._lbl_hint.text.contains("撤离中"),
				"hold progress appears in the action bar")
			raid._update_interact(5.0)
			Input.action_release("interact")
			check(raid.state == "extracted", "holding interact inside the marker completes extraction")
		raid._return_to_campaign(reason)
		await scene_changed
		check(current_scene.sim == sim and sim.phase == "report", "same campaign receives the night report")
		check(bool(sim.seen.get("night", false)) == (reason == "extracted"),
			"successful extraction completes the field tutorial for this save")
		check(sim.last_report.get("checked_north_awning") == checked, "report records detour or direct return")
		check((int(sim.last_report.gained.get("dial", 0)) > 0) == (reason in ["extracted", "dawn"]), "only retained fluid reaches home")
		current_scene.hud._report_to_base()
		current_scene.hud.refresh()
		var note_found := false
		var expected_fluid := "这趟带回腹透液" if reason in ["extracted", "dawn"] else "这趟没带回腹透液"
		var expected_trace := "残号 04" if checked else "北雨棚那一栏还是空的"
		for label in current_scene.hud.find_children("*", "Label", true, false):
			if label.is_visible_in_tree() and label.text.contains(expected_fluid) and label.text.contains(expected_trace):
				note_found = true
		check(note_found, "visible home note matches the medicine and detour outcomes")
		check(int(sim.node_state("coldstore").visits) == 1 and sim.phase == "base", "returns to 602")
		root.remove_child(raid)
		raid.free()
	print("==== RESULT: %d passed, %d failed ====" % [passes, failures])
	quit(1 if failures else 0)


func _check_ash_intro() -> void:
	for choice in [0, 1]:
		var campaign: Node = load("res://scenes/campaign.tscn").instantiate()
		root.add_child(campaign)
		var sim = campaign.sim
		check(sim.depart(Data.loc("coldstore")), "coldstore story opens before the raid")
		campaign.hud._resolve_story(choice)
		var intro_shown := false
		if campaign.hud.cutscene_active():
			for page in campaign.hud.cutscene.slides:
				var card: Dictionary = page.get("card", {})
				if String(card.get("title", "")).contains("灰烬") and card.get("lines", []).size() == 2:
					intro_shown = true
		check(intro_shown == (choice == 0), "companion lesson appears only when Ash actually joins")
		sim.cancel_departure()
		root.get_node("RaidBridge").clear()
		campaign.free()
