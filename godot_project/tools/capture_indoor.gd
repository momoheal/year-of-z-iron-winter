"""室内地面实机验收截图：带窗口（非 headless）加载夜食堂 / 疗养院关卡，渲染后保存 PNG。

用法（在 godot_project 下，用带窗口的 Godot，不要 --headless）：
    Godot_v4.7.2-stable_win64_console.exe --path godot_project --script res://tools/capture_indoor.gd
输出到 godot_project/screenshots/ 下的 capture_night_canteen.png / capture_night_sanitarium.png。
"""

extends SceneTree

const OUT := "res://screenshots/"
const FRAMES := 70

func _initialize() -> void:
	call_deferred("_run")

func _shoot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := OUT + name + ".png"
	img.save_png(path)
	print("[capture] ", path, "  ", img.get_width(), "x", img.get_height())

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shoot_level(name: String, scene: String) -> void:
	await process_frame
	var s: Node = load(scene).instantiate()
	root.add_child(s)
	await _frames(FRAMES)
	await _shoot(name)
	s.queue_free()
	await _frames(3)

func _run() -> void:
	await process_frame
	await _shoot_level("capture_night_canteen", "res://scenes/night_canteen.tscn")
	await _shoot_level("capture_night_sanitarium", "res://scenes/night_sanitarium.tscn")
	print("[capture] done")
	quit()
