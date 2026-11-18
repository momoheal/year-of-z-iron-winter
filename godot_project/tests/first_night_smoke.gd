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
	for reason in ["extracted", "abort", "frozen", "dawn"]:
		var sim := Sim.new()
		var loc := Data.loc("coldstore")
		check(sim.depart(loc), "depart from 602")
		sim.resolve_story(0)
		var raid: Node = load(sim.pending_scene).instantiate()
		root.add_child(raid)
		check(raid.first_coldstore_visit, "first visit detected through campaign bridge")
		raid.pack.clear()
		raid._finish_search(raid.get_node("World/Props/SealedMeds"))
		var checked: bool = reason != "extracted"
		if checked:
			raid.player.global_position = raid._m_px([33.9, 10.65])
			raid._update_landmarks()
		raid._return_to_campaign(reason)
		await scene_changed
		check(current_scene.sim == sim and sim.phase == "report", "same campaign receives the night report")
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
