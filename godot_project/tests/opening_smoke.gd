extends SceneTree

var passes := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1
		print("FAIL ", what)

func _run() -> void:
	var opening = load("res://scripts/ui/Opening.gd").new()
	root.add_child(opening)
	await process_frame
	check(opening.page == 0 and not opening.actors.visible, "first slide")
	check(opening.backdrop.texture != null, "first slide image loaded")
	opening.advance()
	check(opening.page == 1 and not opening.actors.visible, "second slide")
	check(opening.backdrop.texture != null, "second slide image loaded")
	opening.advance()
	check(opening.page == 2 and opening.actors.visible, "live actors")
	opening._process(0.5)
	check(opening.hero.offset_left > -72 and opening.soldier.offset_left < -72, "actors move")
	opening.advance()
	await process_frame
	check(not is_instance_valid(opening), "opening closes")
	var campaign = load("res://scenes/campaign.tscn").instantiate()
	root.add_child(campaign)
	await process_frame
	var phase: String = campaign.sim.phase
	var day: int = campaign.sim.day
	campaign.hud.show_opening()
	await process_frame
	check(campaign.sim.phase == phase and campaign.sim.day == day, "replay leaves campaign unchanged")
	var replay = campaign.hud.get_child(campaign.hud.get_child_count() - 1)
	var skip := InputEventKey.new()
	skip.pressed = true
	skip.keycode = KEY_ESCAPE
	replay._input(skip)
	await process_frame
	check(not is_instance_valid(replay), "escape skips replay")
	campaign.queue_free()
	await process_frame
	print("==== RESULT: %d passed, %d failed ====" % [passes, failures])
	quit(0 if failures == 0 else 1)
