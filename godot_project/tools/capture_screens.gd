"""实机截图 + 可玩性验证：带窗口（非 headless）加载场景，渲染后保存 PNG。

流程：
  1. 战役主场景：先拍标题，再模拟按 Enter 进入游戏，拍进入后的画面（证明能玩）。
  2. 夜潜货场：拍渲染画面（验证灯光羽化后不再有硬边矩形光带）。

用法（在 godot_project 下，用带窗口的 Godot，不要 --headless）：
    Godot_v4.7.2-stable_win64.exe --path godot_project --script res://tools/capture_screens.gd
输出到 godot_project/screenshots/ 下的 capture_*.png。
"""
extends SceneTree

const OUT := "res://screenshots/"
const FRAMES := 45


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


func _press_enter() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ENTER
	ev.keycode = KEY_ENTER
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	var up := InputEventKey.new()
	up.physical_keycode = KEY_ENTER
	up.keycode = KEY_ENTER
	up.pressed = false
	Input.parse_input_event(up)


func _run() -> void:
	await process_frame

	# 1) 战役：标题 → Enter 进入
	var camp: Node = load("res://scenes/campaign.tscn").instantiate()
	root.add_child(camp)
	await _frames(FRAMES)
	await _shoot("capture_campaign")
	await _press_enter()
	await _frames(50)
	await _shoot("capture_campaign_ingame")
	camp.queue_free()
	await _frames(2)

	# 2) 夜潜货场
	var yard: Node = load("res://scenes/night_explore.tscn").instantiate()
	root.add_child(yard)
	await _frames(FRAMES)
	await _shoot("capture_night_yard")
	yard.queue_free()

	print("[capture] done")
	quit()
