extends SceneTree
## 六张由旧灰盒切换到实体贴图管线的夜潜地图实机验收。
const LEVELS := [
	["boiler", "res://scenes/night_boiler.tscn"],
	["underpass", "res://scenes/night_underpass.tscn"],
	["birch", "res://scenes/night_birch.tscn"],
	["workshop", "res://scenes/night_workshop.tscn"],
	["greenhouse", "res://scenes/night_greenhouse.tscn"],
	["archive", "res://scenes/night_archive.tscn"],
]

func _initialize() -> void:
	call_deferred("_run")

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shoot(id: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := "res://screenshots/capture_night_%s.png" % id
	img.save_png(path)
	print("[capture] ", path, " ", img.get_width(), "x", img.get_height())

func _run() -> void:
	await process_frame
	for entry in LEVELS:
		var scene: Node = load(entry[1]).instantiate()
		root.add_child(scene)
		await _frames(70)
		await _shoot(entry[0])
		scene.queue_free()
		await _frames(3)
	print("[capture] promoted scenes done")
	quit()
