"""八关实机验收截图矩阵：带窗口（非 headless）逐关加载夜潜场景，渲染后保存 PNG。

用途：美术 / 光照 / 材质改动后跑一遍——离屏预览看不出场景级问题（全屏飘雪、后处理、
CanvasModulate 夜色），只有真进引擎才露馅。

用法（在 godot_project 下，用带窗口的 Godot，不要 --headless）：
    Godot_v4.7.2-stable_win64_console.exe --path godot_project --script res://tools/capture_levels.gd
输出到 godot_project/screenshots/ 下的 capture_night_<id>.png（yard 用主场景 night_explore.tscn）。
"""

extends SceneTree

const OUT := "res://screenshots/"
const FRAMES := 70
const LEVELS := [
	["yard", "res://scenes/night_explore.tscn"],
	["marshalling", "res://scenes/night_marshalling.tscn"],
	["manor", "res://scenes/night_manor.tscn"],
	["mine", "res://scenes/night_mine.tscn"],
	["market", "res://scenes/night_market.tscn"],
	["coldstore", "res://scenes/night_coldstore.tscn"],
	["canteen", "res://scenes/night_canteen.tscn"],
	["sanitarium", "res://scenes/night_sanitarium.tscn"],
]

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

func _run() -> void:
	await process_frame
	for entry in LEVELS:
		var id: String = entry[0]
		var s: Node = load(entry[1]).instantiate()
		root.add_child(s)
		await _frames(FRAMES)
		await _shoot("capture_night_" + id)
		s.queue_free()
		await _frames(3)
	print("[capture] done")
	quit()
