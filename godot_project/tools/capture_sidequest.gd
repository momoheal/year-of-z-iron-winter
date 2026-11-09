extends SceneTree
## capture_sidequest.gd — 截支线地点（无 scene → 原地 _draw_raid）材质化效果。
## 绕过 can_depart 直接构造 raid。用法：带窗口，勿 --headless。

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sc = load("res://scenes/campaign.tscn").instantiate()
	root.add_child(sc)
	for i in 4:
		await process_frame
	var sim = sc.sim
	var Data = load("res://scripts/CampaignData.gd")
	var L: Dictionary = Data.loc("underpass")
	sim.selected_loc = "underpass"
	var cfg := {
		"loc": L, "day": 1, "seed": int(L["seed"]) + 7, "left": 1.0, "mate": "",
		"pack_max": Data.BAG, "weapon": Data.weapon("fist"), "load": {}, "cold": float(L["cold"]),
		"danger": int(L["dg"]), "time": 60.0, "glasses": false, "night": 120.0, "sound_on": false,
	}
	sim.raid = load("res://scripts/RaidSim.gd").new(sim, cfg)
	sim.phase = "raid"
	for i in 10:
		await process_frame
	# 验证用：全图 explored/visible + 镜头居中，看整体材质化
	sim.raid.explored.fill(1)
	sim.raid.vis.fill(1)
	sim.raid.cam = Vector2(sim.raid.W * 0.5, sim.raid.H * 0.5)
	for i in 20:
		await process_frame
	_snap("capture_side_underpass")
	quit()


func _snap(nm: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("res://screenshots/" + nm + ".png")
	print("[capture] ", nm, " ", img.get_size())
