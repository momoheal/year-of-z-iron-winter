extends SceneTree
## capture_mates.gd — 带窗口截战役基地「队伍页伙伴行」与「地图出发栏伙伴 chip」，
## 验证伙伴立绘替换 emoji 的效果。临时全解锁伙伴 + 选中灰烬。
## 用法：Godot --path godot_project --script res://tools/capture_mates.gd（带窗口，勿 --headless）

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sc = load("res://scenes/campaign.tscn").instantiate()
	root.add_child(sc)
	for i in 4:
		await process_frame
	var sim = sc.sim
	var Data = load("res://scripts/CampaignData.gd")
	for m in Data.MATES:
		sim.mates[String(m["id"])] = true
	sim.select_mate("ash")
	sim.phase = "base"                      # 基地队伍页 → _mate_row 立绘
	for i in 8:
		await process_frame
	_snap("capture_mates_base")
	sim.selected_loc = "yard"
	sim.phase = "map"                       # 地图出发栏 → _mate_chip 立绘 icon
	for i in 8:
		await process_frame
	_snap("capture_mates_map")
	quit()


func _snap(nm: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("res://screenshots/" + nm + ".png")
	print("[capture] ", nm, " ", img.get_size())
