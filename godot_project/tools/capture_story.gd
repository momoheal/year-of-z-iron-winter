extends SceneTree
## capture_story.gd — 截剧情对话框右下角表情头像。带窗口运行，勿 --headless。

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sc = load("res://scenes/campaign.tscn").instantiate()
	root.add_child(sc)
	for i in 4:
		await process_frame
	var sim = sc.sim
	for sid in ["sanitarium", "coldstore", "market"]:
		sim.story_id = sid
		sim.story_open = true
		for i in 16:
			await process_frame
		_snap("capture_story_" + sid)
		sim.story_open = false
		await process_frame
	quit()


func _snap(nm: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("res://screenshots/" + nm + ".png")
	print("[capture] ", nm, " ", img.get_size())
