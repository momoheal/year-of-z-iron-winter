extends SceneTree
## capture_readability.gd — 可读性验收截图：夜潜 HUD + 地标标签、暂停菜单。
## 非 headless 运行（需要真实渲染）；不写存档。
##   Godot_v4.7.2-stable_win64_console.exe --path godot_project -s tools/capture_readability.gd -- --tag=after
## 输出：res://screenshots/readability_<tag>_hud.png / _pause.png

var tag := "now"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
	call_deferred("_run")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := "res://screenshots/readability_%s_%s.png" % [tag, name]
	img.save_png(path)
	print("[capture] ", path, " ", img.get_size())


func _run() -> void:
	var rb := root.get_node_or_null("RaidBridge")
	if rb != null:
		rb.clear()
	var scene = load("res://scenes/night_explore.tscn").instantiate()
	root.add_child(scene)
	await _frames(40)
	scene.state = "play"
	await _frames(10)
	await _shot("hud")
	scene.open_pause()
	await _frames(10)
	await _shot("pause")
	quit()
