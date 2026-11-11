extends SceneTree
## 文学扩展实机验收：新随机事件长文、按钮布局与帕沙终局余响。
## 带窗口运行，勿 --headless。

const Data := preload("res://scripts/CampaignData.gd")
const EventPopupScene := preload("res://scripts/data/EventPopup.gd")

func _initialize() -> void:
	call_deferred("_run")

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	for event_id in ["drunk_father", "mirror_double"]:
		var popup := EventPopupScene.new()
		root.add_child(popup)
		await _frames(3)
		popup.set_lang("zh")
		popup.show_event(load("res://data/events/%s.tres" % event_id))
		await _frames(6)
		await RenderingServer.frame_post_draw
		_snap("capture_event_%s" % event_id)
		popup.queue_free()
		await _frames(2)

	var sc = load("res://scenes/campaign.tscn").instantiate()
	root.add_child(sc)
	await _frames(4)
	sc.sim.flags["truth"] = true
	sc.sim.mother_alive = true
	sc.sim.tally = 0
	sc.sim.phase = "ending"
	sc.hud._sig = ""
	await _frames(6)
	await RenderingServer.frame_post_draw
	_snap("capture_ending_pasha")
	sc.sim.phase = "base"
	sc.sim.add_log(Data.STORY["canteen"]["choices"][0]["toast_zh"], Data.STORY["canteen"]["choices"][0]["toast_en"])
	sc.sim.logbook_open = true
	sc.hud._sig = ""
	await _frames(6)
	await RenderingServer.frame_post_draw
	_snap("capture_logbook_confession")
	print("CAPTURE_LITERARY_EXPANSION_DONE")
	quit()

func _snap(nm: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("res://screenshots/" + nm + ".png")
	print("[capture] ", nm, " ", img.get_size())
