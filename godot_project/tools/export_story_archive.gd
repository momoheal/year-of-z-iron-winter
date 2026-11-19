extends SceneTree
## Export the same page arrays that the game sends to StorySlides.

const Slides := preload("res://scripts/data/CutsceneData.gd")
const Data := preload("res://scripts/CampaignData.gd")
const Sim := preload("res://scripts/CampaignSim.gd")

var decks: Array = []


func _initialize() -> void:
	_export.call_deferred()


func _deck(group: String, id: String, pages: Array, variant := "") -> void:
	if not pages.is_empty():
		decks.append({"group": group, "id": id, "pages": pages, "variant": variant})


func _event(id: String, variant := "", context := {}) -> void:
	_deck("现场与余波", id, Slides.story_event_slides(id, context), variant)


func _battle_dialogue(sim, id: String, story: Dictionary, mate_id: String, label: String,
		mother_alive := true, tally := 0, conscience := 50.0) -> void:
	sim.mate = mate_id
	sim.mother_alive = mother_alive
	sim.tally = tally
	sim.conscience = conscience
	sim.last_report = {"mate": mate_id, "mate_present": mate_id != ""}
	if mate_id != "":
		sim.mates[mate_id] = true
	var context := {"mate": mate_id, "ash_present": mate_id == "ash"}
	sim.lang = "zh"
	var zh: Array = sim.story_lines(id)
	sim.lang = "en"
	var en: Array = sim.story_lines(id)
	var opening := {"img": Slides.scene_image(id, context), "lines_zh": zh, "lines_en": en,
		"choices": story.get("choices", [])}
	_deck("战役对白", id, [opening], label)


func _export() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		printerr("Expected one output JSON path after --")
		quit(2)
		return
	var sim := Sim.new()
	_deck("开场", "prologue", Slides.PROLOGUE)
	for id in Slides.ROOM_DIALOGUE:
		_deck("602 室", id, Slides.room_dialogue(id))
	for key in Slides.AFTERMATH:
		var parts: PackedStringArray = key.split(":")
		_deck("抉择余波表", parts[0], Slides.aftermath(parts[0], int(parts[1])), "选项 %d" % (int(parts[1]) + 1))
	for id in ["redzone_mother", "canteen_vasily_qte", "canteen_aftermath",
		"mine_inscriptions", "crag_reveal", "archive_copy", "station_route",
		"evidence_handover", "market_refuge", "zakhar_betrayed", "mother_lost"]:
		_event(id)
	_event("fire_rescue", "居民破门")
	_event("fire_rescue", "帕维尔同行", {"pavel_present": true})
	_event("fire_rescue", "灰烬同行", {"ash_present": true})
	_event("crag_reveal", "伊万同行", {"ivan_present": true})
	for plan in ["evidence", "trade", "release"]:
		for present in [false, true]:
			var label: String = {"evidence": "拍照", "trade": "交换", "release": "开门"}[plan]
			label += "／叶莲娜同行" if present else "／叶莲娜缺席"
			var context := {"manor_plan": plan, "yelena_present": present}
			_event("manor_confrontation", label, context)
			_event("manor_outcome", label, context)
	for scope in ["", "all", "lana"]:
		var label: String = {"": "旧档未记录", "all": "带能走的人", "lana": "带拉娜和底单"}[scope]
		_event("eagle_escape", label, {"crag_rescue_scope": scope})
	for mate_id in ["", "pavel", "yelena"]:
		for names in [false, true]:
			var operator: String = {"": "阿列克谢", "pavel": "帕维尔", "yelena": "叶莲娜"}[mate_id]
			var label := operator + ("／播姓名" if names else "／只播档案号")
			_event("broadcast_complete", label, {"broadcast_mate": mate_id, "broadcast_names_aired": names})
	for key in Slides.ENDING_SCENES:
		var alive: bool = key in ["ENDING_A_RETURN_HOME", "TRUE_ALPHA_HELLO_LANA"]
		_deck("结局", key, Slides.ending_slides(key, alive), "旧档未记录撤离范围" if key == "ENDING_B_FLAWED_LIBERATION" else "")
		if key == "ENDING_B_FLAWED_LIBERATION":
			_deck("结局", key, Slides.ending_slides(key, true, {"crag_rescue_all": true}), "带能走的人")
			_deck("结局", key, Slides.ending_slides(key, true, {"crag_rescue_lana": true}), "带拉娜和底单")
		if key == "TRUE_BETA_OUTLAND_FIRE":
			_deck("结局", key, Slides.ending_slides(key, true), "母亲存活")
	var pasha_pages := Slides.ending_slides("TRUE_ALPHA_HELLO_LANA", true,
		{"pasha_witness_seen": true, "pasha_survived_to_crag": true})
	_deck("结局", "pasha_epilogue", pasha_pages.slice(-1), "满足帕沙余波条件时附加")

	for id in Data.STORY:
		var story: Dictionary = Data.STORY[id]
		_battle_dialogue(sim, id, story, "", "")
		match id:
			"manor":
				_battle_dialogue(sim, id, story, "yelena", "叶莲娜同行")
			"sanitarium":
				_battle_dialogue(sim, id, story, "ash", "灰烬同行")
			"station_buran_yard", "market_refuge":
				_battle_dialogue(sim, id, story, "ivan", "伊万同行")
			"market":
				_battle_dialogue(sim, id, story, "", "失母／暂住线索", false)
				_battle_dialogue(sim, id, story, "ivan", "失母／伊万同行", false)
			"broadcast_tower_302":
				_battle_dialogue(sim, id, story, "yelena", "叶莲娜同行")
				_battle_dialogue(sim, id, story, "pavel", "帕维尔同行")
			"marshalling":
				for entry in Data.MATES:
					var mate_id: String = entry["id"]
					if mate_id == "none":
						continue
					var name_zh: String = entry["zh"]
					_battle_dialogue(sim, id, story, mate_id, name_zh + "／常态")
					if mate_id != "ash":
						_battle_dialogue(sim, id, story, mate_id, name_zh + "／疏离", true, 2)
					if mate_id not in ["ash", "zakhar"]:
						_battle_dialogue(sim, id, story, mate_id, name_zh + "／支持", true, 0, 70.0)

	var events: Array = []
	for filename in DirAccess.get_files_at("res://data/events"):
		if not filename.ends_with(".tres"):
			continue
		var event = load("res://data/events/" + filename)
		var choices: Array = []
		for option in event.get("options"):
			choices.append({"zh": option.get("label_zh"), "en": option.get("label_en"),
				"toast_zh": option.get("result_text_zh"), "toast_en": option.get("result_text_en")})
		events.append({"id": filename.get_basename(), "title": event.get("title_zh"),
			"zh": event.get("desc_zh"), "en": event.get("desc_en"), "choices": choices})
	var output := FileAccess.open(args[0], FileAccess.WRITE)
	if output == null:
		printerr("Cannot write export to ", args[0])
		quit(1)
		return
	output.store_string(JSON.stringify({"decks": decks, "locations": Data.LOCS, "mates": Data.MATES,
		"events": events, "barks": Data.OSK_BARKS}))
	output.close()
	quit()
