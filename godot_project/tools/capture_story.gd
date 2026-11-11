extends SceneTree
## capture_story.gd — 逐句截图，验证角色 × 情绪头像随当前台词切换。带窗口运行，勿 --headless。

const Data = preload("res://scripts/CampaignData.gd")

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sc = load("res://scenes/campaign.tscn").instantiate()
	root.add_child(sc)
	for i in 4:
		await process_frame
	var sim = sc.sim
	var story_ids: Array = ["sanitarium", "coldstore", "market", "yard"]
	var only := OS.get_environment("STORY_ONLY")
	if not only.is_empty() and Data.STORY.has(only):
		story_ids = [only]
	for sid in story_ids:
		sim.story_id = sid
		sim.story_open = true
		sc.hud._story_beat = ""
		sc.hud._story_line = 0
		sc.hud._sig = ""
		for i in 12:
			await process_frame
		var lines: Array = Data.STORY[sid]["lines"]
		for i in lines.size():
			if i > 0:
				sc.hud.advance_story()
				for j in 6:
					await process_frame
			await RenderingServer.frame_post_draw
			_snap("capture_story_%s_%02d" % [sid, i + 1])
		sim.story_open = false
		sc.hud._sig = ""
		await process_frame
	print("CAPTURE_DONE")
	quit()


func _snap(nm: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("res://screenshots/" + nm + ".png")
	print("[capture] ", nm, " ", img.get_size())
