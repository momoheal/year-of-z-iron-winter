extends SceneTree
## Smoke test for the three completed map packages and their campaign gates.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --path godot_project -s tests/map_campaign_smoke.gd

const Data := preload("res://scripts/CampaignData.gd")
const SimScript := preload("res://scripts/CampaignSim.gd")

var passes := 0
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _assert(ok: bool, label: String, detail: String = "") -> void:
	if ok:
		passes += 1
		print("  PASS  ", label)
	else:
		failures.append(label + ((" — " + detail) if detail != "" else ""))
		print("  FAIL  ", label, "  ", detail)

func _frames(n: int = 2) -> void:
	for _i in n:
		await process_frame
		await physics_frame

func _clear_scene() -> void:
	for child in root.get_children():
		if child.name == "NightExplore":
			root.remove_child(child)
			child.free()

func _run() -> void:
	print("== map_campaign_smoke ==")
	var bridge := root.get_node_or_null("RaidBridge")
	var gates := SimScript.new()
	gates.flags["first_act_pending"] = false
	gates.story_done[SimScript.FIRST_ACT_LOC] = true
	gates.flags["endgame_known"] = false
	_assert(not gates.loc_unlocked(Data.loc("station_buran_yard")), "Buran yard stays locked before the dispatch order")
	gates.flags["endgame_known"] = true
	_assert(gates.loc_unlocked(Data.loc("station_buran_yard")), "dispatch order unlocks Buran yard")
	_assert(not gates.loc_unlocked(Data.loc("eagle_beak_cliff")), "Crag stays locked before the handover copy")
	gates.flags["station_route"] = true
	gates.flags["lana_car3"] = true
	_assert(gates.loc_unlocked(Data.loc("eagle_beak_cliff")), "Buran handover unlocks Eagle's Crag")
	_assert(not gates.loc_unlocked(Data.loc("broadcast_tower_302")), "tower stays locked without Crag route and Manor evidence")
	gates.flags["eagle_escape"] = true
	_assert(not gates.loc_unlocked(Data.loc("broadcast_tower_302")), "tower still requires Manor evidence")
	gates.flags["truth"] = true
	_assert(gates.loc_unlocked(Data.loc("broadcast_tower_302")), "Crag route plus Manor evidence unlocks tower 302")
	_assert(String(gates.objective()["zh"]).contains("302 高地"), "campaign objective points to the broadcast finale")

	var map_rows := [
		["station_buran_yard", "res://scenes/night_station_buran_yard.tscn", "StationBuranYard", "DispatchLocker"],
		["eagle_beak_cliff", "res://scenes/night_eagle_beak_cliff.tscn", "EagleBeakCliff", "BrakeVan"],
		["broadcast_tower_302", "res://scenes/night_broadcast_tower_302.tscn", "BroadcastTower302", "RadioDesk"],
	]
	for row in map_rows:
		var sim = SimScript.new()
		sim.flags["first_act_pending"] = false
		sim.flags["endgame_known"] = true
		sim.flags["station_route"] = true
		sim.flags["eagle_escape"] = true
		sim.flags["truth"] = true
		sim.mates["anna"] = true
		sim.select_mate("anna")
		sim.story_done[String(row[0])] = true
		var loc: Dictionary = Data.loc(String(row[0]))
		_assert(sim.depart(loc), "%s can depart through CampaignSim" % row[0])
		_assert(String(sim.pending_scene) == String(row[1]), "%s sets its dedicated scene path" % row[0], sim.pending_scene)
		var scene: Node = (load(String(row[1])) as PackedScene).instantiate()
		root.add_child(scene)
		await _frames(2)
		_assert(scene.level_id == String(row[0]), "%s keeps scene metadata" % row[0], String(scene.level_id))
		var ground := scene.get_node("Ground") as Sprite2D
		_assert(ground.texture != null and ground.texture.resource_path == "res://art/80_maps/%s/map.png" % row[2],
			"%s installs its day plate in the live map" % row[0], ground.texture.resource_path if ground.texture else "missing")
		_assert(scene.map_art_night != null, "%s loads its night plate" % row[0])
		_assert(scene.soldiers.size() >= 2 and scene.rabids.size() >= 3, "%s installs OSK and rabid enemies" % row[0],
			"OSK %d / rabids %d" % [scene.soldiers.size(), scene.rabids.size()])
		_assert(scene.searchlights.size() >= 1, "%s installs a moving searchlight" % row[0])
		_assert(scene.follower != null and scene.mate_id == "anna", "%s spawns the campaign-selected companion" % row[0], scene.mate_id)
		_assert(scene.get_node_or_null("World/Props/%s" % row[3]) != null, "%s places a package cutout prop in the world" % row[0])
		var beats = load("res://scripts/night/LevelBeats.gd")
		var beat: Dictionary = beats.for_level(String(row[0]))
		_assert(beats.id_for_scene(String(row[1])) == String(row[0]) and beat.landmarks.size() >= 3,
			"%s has a registered dossier and landmarks" % row[0])
		bridge.clear()
		root.remove_child(scene)
		scene.free()
		await _frames(1)

	var trigger_sim = SimScript.new()
	trigger_sim.flags["first_act_pending"] = false
	trigger_sim.flags["endgame_known"] = true
	var station: Dictionary = Data.loc("station_buran_yard")
	_assert(trigger_sim.depart(station) and trigger_sim.story_open and trigger_sim.story_id == "station_buran_yard",
		"first departure triggers the Buran handover story")
	trigger_sim.resolve_story(0)
	_assert(bool(trigger_sim.flags.get("station_route", false)), "handover choice records the Crag route")
	trigger_sim.cancel_departure()
	bridge.clear()

	var crag_sim = SimScript.new()
	crag_sim.flags["first_act_pending"] = false
	crag_sim.flags["station_route"] = true
	var crag: Dictionary = Data.loc("eagle_beak_cliff")
	_assert(crag_sim.depart(crag) and crag_sim.story_open and crag_sim.story_id == "eagle_beak_cliff",
		"first departure triggers the Eagle's Crag story")
	crag_sim.resolve_story(0)
	_assert(bool(crag_sim.flags.get("eagle_escape", false)), "Crag choice unlocks the broadcast route")
	crag_sim.cancel_departure()
	bridge.clear()

	var tower_sim = SimScript.new()
	tower_sim.flags["first_act_pending"] = false
	tower_sim.flags["eagle_escape"] = true
	tower_sim.flags["truth"] = true
	var tower: Dictionary = Data.loc("broadcast_tower_302")
	_assert(tower_sim.depart(tower) and tower_sim.story_open and tower_sim.story_id == "broadcast_tower_302",
		"first departure triggers the 302 broadcast story")
	tower_sim.resolve_story(0)
	_assert(bool(tower_sim.flags.get("broadcast_plan", false)) and not bool(tower_sim.flags.get("broadcast_complete", false)),
		"broadcast choice records the plan without completing the raid")
	tower_sim.cancel_departure()
	bridge.clear()

	var finish_sim = SimScript.new()
	finish_sim.flags["first_act_pending"] = false
	finish_sim.flags["eagle_escape"] = true
	finish_sim.flags["truth"] = true
	finish_sim.story_done["broadcast_tower_302"] = true
	_assert(finish_sim.depart(tower), "tower finale can be departed for a smoke completion")
	finish_sim.finish_raid("extracted")
	finish_sim.to_base()
	_assert(bool(finish_sim.flags.get("broadcast_complete", false)) and finish_sim.finished_demo,
		"successful tower extraction completes the campaign finale")
	bridge.clear()

	print("== RESULT: %d passed, %d failed ==" % [passes, failures.size()])
	for f in failures:
		print("   FAILED: ", f)
	quit(0 if failures.is_empty() else 1)
