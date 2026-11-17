extends SceneTree
## Safe visual preview of the Room 602 zone panel; it does not read or write player saves.
## Run with: Godot --path godot_project -s tests/room602_ui_preview.gd

const SimScript := preload("res://scripts/CampaignSim.gd")


func _initialize() -> void:
	call_deferred("_open_preview")


func _open_preview() -> void:
	await process_frame
	var hud_script: Script = load("res://scripts/CampaignHUD.gd")
	var stage := Node2D.new()
	stage.name = "Room602PreviewStage"
	root.add_child(stage)

	var sim = SimScript.new()
	sim.phase = "base"
	sim.day = 4
	sim.mother_alive = false
	sim.flags["first_act_pending"] = false
	sim.flags["mother_lost"] = true
	sim.flags["market_refuge_found"] = true
	sim.flags["archive_lead"] = true
	sim.story_done[SimScript.FIRST_ACT_LOC] = true
	sim.seen["base"] = true

	var hud = hud_script.new()
	stage.add_child(hud)
	hud.bind_campaign(sim, stage)
	await process_frame
	hud.call("_open_room_zones", "mother")
	hud.refresh()
	var refresher := Timer.new()
	refresher.wait_time = 0.1
	refresher.timeout.connect(hud.refresh)
	stage.add_child(refresher)
	refresher.start()
