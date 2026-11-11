extends SceneTree
## capture_ui_hud.gd — 新版五角星 HUD 的实机衰减验收。
## 非 headless 运行；只修改截图场景内的临时玩家数值，不写存档。

func _initialize() -> void:
	call_deferred("_run")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var scene = load("res://scenes/night_explore.tscn").instantiate()
	root.add_child(scene)
	await _frames(35)
	scene.hp = 60.0
	scene.warmth = 35.0
	scene._refresh_hud()
	await _frames(20)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := "res://screenshots/capture_ui_star_hud.png"
	img.save_png(path)
	print("[capture] ", path, " ", img.get_size(),
		" HP=", scene.hp, " WARMTH=", scene.warmth)
	quit()
