extends SceneTree
## 清杀队四类战斗提示与命中反馈实机验收。
const Data := preload("res://scripts/CampaignData.gd")

func _initialize() -> void:
	call_deferred("_run")

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shoot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := "res://screenshots/capture_%s.png" % name
	img.save_png(path)
	print("[capture] ", path, " ", img.get_width(), "x", img.get_height())

func _run() -> void:
	await process_frame
	var scene: Node = load("res://scenes/night_coldstore.tscn").instantiate()
	root.add_child(scene)
	await _frames(65)
	scene.show_osk_bark("warning")
	await _frames(3)
	await _shoot("osk_warning")
	scene.on_soldier_alert(scene.soldiers[0])
	await _frames(3)
	await _shoot("osk_chase")
	var soldier: Node = scene.soldiers[0]
	soldier.global_position = scene.player.global_position + Vector2(90, -20)
	scene._damage_enemy(soldier, 34.0, "player", true)
	await _frames(2)
	await _shoot("combat_hit")
	soldier.hp = 1.0
	scene._damage_enemy(soldier, 34.0, "player", true)
	await _frames(12)
	await _shoot("osk_death")
	scene.floats.clear()
	scene.spawn_float(scene.player.global_position + Vector2(0, -70),
		"你举起撬棍，眼前浮现母亲透析时费力的呼吸，机器里水声不停，仿佛也在替她问你：这么做，究竟是为了谁？",
		Color("#ef4444"))
	await _frames(3)
	await _shoot("literary_float")
	print("[capture] combat feedback done")
	quit()
