extends SceneTree
## 夜潜场景截图工具（需要 GPU，不能 --headless）：
##   Godot_v4.7.2-stable_win64.exe --path godot_project -s tools/screenshot_night.gd -- <out_dir>
## 依次把阿列克谢放到几个机位，等灯光 / 粒子稳定后保存 PNG。

const SHOTS := [
	{"name": "night_yard_courtyard", "pos": Vector2(20.5, 11.0), "face": -0.4, "flash": true},
	{"name": "night_yard_railyard", "pos": Vector2(29.0, 29.2), "face": 0.2, "flash": true},
	{"name": "night_yard_vent_dark", "pos": Vector2(9.0, 5.2), "face": 2.6, "flash": false},
	{"name": "night_yard_rabid_boxcar", "pos": Vector2(31.2, 37.4), "face": 0.05, "flash": true},
]

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://"
	var s: Node = (load("res://scenes/night_explore.tscn") as PackedScene).instantiate()
	root.add_child(s)
	for i in 5:
		await process_frame
	for shot in SHOTS:
		var p = s.player
		p.global_position = Vector2(shot.pos.x * 64.0, shot.pos.y * 39.68)
		p.flashlight_on = shot.flash
		p.set_physics_process(false)
		p.get_node("Flashlight").visible = shot.flash
		s.cam.global_position = p.global_position
		s.cam.reset_smoothing()
		for so in s.soldiers:
			so.ctl = null          # 截图时让清杀兵 / 狂暴者停在原地
		for r in s.rabids:
			r.ctl = null
		for i in 50:
			p.facing = shot.face
			p.get_node("Flashlight/Pivot").rotation = shot.face
			await process_frame
		var img := root.get_viewport().get_texture().get_image()
		var path := out.path_join(String(shot.name) + ".png")
		img.save_png(path)
		print("saved ", path)
	quit(0)
