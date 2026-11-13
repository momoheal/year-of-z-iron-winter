extends SceneTree
## 故事开场 / 图片幻灯 / 抉择余波 的冒烟测试。

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
	var CutsceneData = load("res://scripts/data/CutsceneData.gd")
	var Slides = load("res://scripts/ui/StorySlides.gd")
	var opening = load("res://scripts/ui/Opening.gd").new()
	root.add_child(opening)
	await process_frame
	var n: int = opening.slides.size()
	check(n == CutsceneData.PROLOGUE.size() and n >= 5, "prologue has its pages")
	check(opening.page == 0 and not opening.actors.visible, "first slide")
	# 每一页都要有图有字
	var actor_page := -1
	for i in n:
		check(opening.backdrop.texture != null, "slide %d image loaded" % i)
		check(opening.caption.text != "", "slide %d has a caption" % i)
		if opening.actors.visible:
			actor_page = i
			opening._process(0.5)
			check(opening.hero.offset_left > -72 and opening.soldier.offset_left < -72, "actors move")
		if i < n - 1:
			opening.advance()
			check(opening.page == i + 1, "advance to slide %d" % (i + 1))
	check(actor_page >= 0, "one slide plays the live actors")
	# 打字机：第一次按键只补全文字，第二次才翻页
	var typed = Slides.new()
	typed.slides = [{"zh": "一二三四五六七八九十", "en": "x"}, {"zh": "完", "en": "y"}]
	root.add_child(typed)
	await process_frame
	check(not typed.text_done(), "caption starts typing")
	typed.press()
	check(typed.text_done() and typed.page == 0, "first press completes the text")
	typed.press()
	check(typed.page == 1, "second press turns the page")
	typed.close()
	var done := [false]
	opening.finished.connect(func(): done[0] = true)
	opening.advance()
	await process_frame
	check(done[0], "finished signal fires")
	check(not is_instance_valid(opening), "opening closes")
	# 没有插图的页退回胸像；结果卡能填出来
	var fb = Slides.new()
	fb.slides = [
		{"img": ["res://art/60_ui/cg/__missing__.jpg"], "portrait": "res://art/10_characters/portraits/PRT_Ivan_Calm.png", "zh": "a"},
		{"zh": "b", "card": {"title": "t", "lines": ["x", "y"]}},
	]
	root.add_child(fb)
	await process_frame
	check(fb.backdrop.texture == null and fb.portrait_frame.visible, "missing art falls back to the portrait")
	fb.advance()
	check(fb.card_panel.visible and fb.card_box.get_child_count() >= 4, "result card is filled")
	fb.close()
	await process_frame
	# 余波数据：每个主线抉择都配了幻灯
	var Data = load("res://scripts/CampaignData.gd")
	for sid in Data.STORY.keys():
		var choices: Array = Data.STORY[sid].get("choices", [])
		for ci in choices.size():
			var pages: Array = CutsceneData.aftermath(String(sid), ci)
			check(pages.size() >= 2, "aftermath slides for %s:%d" % [sid, ci])
			for pg in pages:
				var has_art: bool = Slides.tex_of(pg.get("img", "")) != null \
					or Slides.tex_of(pg.get("portrait", "")) != null
				check(has_art, "aftermath %s:%d page has art or a portrait" % [sid, ci])
				check(String(pg.get("zh", "")) != "" and String(pg.get("en", "")) != "",
					"aftermath %s:%d page is bilingual" % [sid, ci])
	# 战役里回看序章不改战役状态
	var campaign = load("res://scenes/campaign.tscn").instantiate()
	root.add_child(campaign)
	await process_frame
	var phase: String = campaign.sim.phase
	var day: int = campaign.sim.day
	campaign.hud.show_opening()
	await process_frame
	check(campaign.sim.phase == phase and campaign.sim.day == day, "replay leaves campaign unchanged")
	check(campaign.hud.cutscene_active(), "hud knows a cutscene is playing")
	var replay = campaign.hud.cutscene
	var skip := InputEventKey.new()
	skip.pressed = true
	skip.keycode = KEY_ESCAPE
	replay._input(skip)
	await process_frame
	check(not is_instance_valid(replay), "escape skips replay")
	check(not campaign.hud.cutscene_active(), "cutscene flag clears")
	campaign.queue_free()
	await process_frame
	# 走实际场景树切换路径，验证序章、冷库选择、余波、伙伴与返回结算。
	change_scene_to_file("res://scenes/campaign.tscn")
	await scene_changed
	campaign = current_scene
	campaign.hud.start_new_game()
	campaign.hud.cutscene.close()
	campaign.sim.seen = {"base": true, "map": true, "night": true}
	press_key(KEY_ENTER)
	await process_frame
	check(campaign.sim.phase == "map" and campaign.sim.selected_loc == "coldstore", "Enter opens the map at the first act")
	press_key(KEY_ENTER)
	await process_frame
	check(campaign.sim.story_open and campaign.sim.story_id == "coldstore", "Enter starts the Cold Storage story")
	press_key(KEY_ESCAPE)
	press_key(KEY_2)
	await process_frame
	check(campaign.sim.story_open and not campaign.sim.mates.get("ash", false), "opening story cannot be skipped before the choice")
	for i in Data.STORY["coldstore"]["lines"].size() - 1:
		press_key(KEY_SPACE)
		await process_frame
	press_key(KEY_2)
	await process_frame
	check(campaign.sim.mate == "ash" and campaign.sim.names.is_empty(), "neutral choice also selects Ash")
	check(campaign.hud.cutscene_active() and current_scene == campaign, "aftermath plays before the scene changes")
	campaign.hud.cutscene.close()
	for i in 4:
		await process_frame
	var night := current_scene
	if night == null or night == campaign:
		check(false, "the first playable scene loads")
		quit(1)
		return
	check(night.level_id == "coldstore" and night.in_campaign and night.mate_id == "ash", "Ash follows in the first playable scene")
	night._end("extracted")
	press_key(KEY_ENTER)
	for i in 4:
		await process_frame
	check(current_scene != null and current_scene != night and current_scene.sim.phase == "report"
		and current_scene.sim.mate == "ash", "returns to campaign report with Ash")
	print("==== RESULT: %d passed, %d failed ====" % [passes, failures])
	quit(0 if failures == 0 else 1)


func press_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
