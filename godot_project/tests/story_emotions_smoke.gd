extends SceneTree
## 剧情逐句推进 + 角色/情绪头像自动化冒烟测试。

const Data := preload("res://scripts/CampaignData.gd")
const CutsceneData := preload("res://scripts/data/CutsceneData.gd")

var passes := 0
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _assert(cond: bool, name: String, detail: String = "") -> void:
	if cond:
		passes += 1
	else:
		failures.append(name + ((" — " + detail) if detail != "" else ""))
		print("FAIL ", name, " ", detail)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _press_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)

func _has_button(node: Node, text: String) -> bool:
	if node is Button and String(node.text) == text:
		return true
	for child in node.get_children():
		if _has_button(child, text):
			return true
	return false

func _has_label(node: Node, text: String) -> bool:
	if node is Label and String(node.text) == text:
		return true
	for child in node.get_children():
		if _has_label(child, text):
			return true
	return false

func _find_button(node: Node, text: String) -> Button:
	if node is Button and String(node.text) == text:
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null

func _find_named(node: Node, wanted: String) -> Control:
	if String(node.name) == wanted and node is Control:
		return node as Control
	for child in node.get_children():
		var found := _find_named(child, wanted)
		if found != null:
			return found
	return null

func _run() -> void:
	var sc = load("res://scenes/campaign.tscn").instantiate()
	root.add_child(sc)
	await _frames(4)
	sc.sim.new_game()
	await _frames(3)
	var portraits: Dictionary = sc.hud.STORY_PORTRAITS
	var speakers: Dictionary = sc.hud.STORY_SPEAKERS

	# 新概念头像可以高于原来的 512px，但必须是可用的方形图。
	for role in ["aleksei", "chernov", "fyodor", "ivan", "anna", "pasha", "gulya", "lana", "pavel", "ash", "leonov",
		"katya", "lyudmila", "vikina"]:
		for mood in ["calm", "sad", "intense"]:
			var tex: Texture2D = portraits[role][mood]
			_assert(tex != null and tex.get_width() >= 512 and tex.get_width() == tex.get_height(),
				"asset %s/%s" % [role, mood])
	var placeholder: Texture2D = sc.hud.STORY_PORTRAIT_PLACEHOLDER
	_assert(placeholder != null and placeholder.get_width() >= 512
		and placeholder.get_width() == placeholder.get_height(),
		"neutral archive placeholder is a usable square portrait")

	# 设定文档角色的常用说话者别名必须落到同一身份。
	var aliases := {
		"帕沙": "pasha", "清杀队新兵帕沙": "pasha",
		"古丽娅": "gulya", "古丽娅医生": "gulya",
		"拉娜": "lana", "拉娜（妹妹）": "lana", "拉娜（0420）": "lana",
		"帕维尔老爹": "pavel", "七级钳工帕维尔": "pavel",
		"灰烬": "ash", "灰狼犬灰烬": "ash",
		"梁诺夫": "leonov", "梁诺夫医生": "leonov",
	}
	for speaker_name in aliases:
		_assert(speakers.get(speaker_name, "") == aliases[speaker_name], "speaker alias %s" % speaker_name)

	# 全量剧本的每个场次均进入 Godot 对话数据，且每句都有明确说话者映射与受支持情绪。
	var scripted = JSON.parse_string(FileAccess.get_file_as_string("res://data/story_dialogue.json"))
	_assert(scripted is Dictionary, "canonical dialogue JSON loads")
	if scripted is Dictionary:
		var scenes: Dictionary = scripted.get("scenes", {})
		var expected_scene_ids := ["0-1", "1-1", "1-2", "1-3", "1-4", "1-4A", "2-1", "2-2", "2-3", "2-4",
			"3-1", "3-2", "3-2A", "3-3", "4-1", "4-2", "5-1", "5-2", "6-1", "6-2"]
		var actual_scene_ids: Array = scenes.keys()
		actual_scene_ids.sort()
		expected_scene_ids.sort()
		_assert(actual_scene_ids == expected_scene_ids, "all 20 canonical scene IDs are present")
		for sid in scenes:
			var source_lines: Array = scenes[sid].get("lines", [])
			_assert(not source_lines.is_empty(), "source scene %s has dialogue" % String(sid))
			for i in source_lines.size():
				var source_line: Dictionary = source_lines[i]
				var source_speaker := String(source_line.get("w", ""))
				var source_mood := String(source_line.get("mood", ""))
				_assert(speakers.has(source_speaker), "%s line %d has speaker mapping" % [String(sid), i + 1])
				_assert(source_mood in ["calm", "sad", "intense"], "%s line %d has allowed mood" % [String(sid), i + 1])
				_assert(not String(source_line.get("zh", "")).strip_edges().is_empty(),
					"%s line %d is not empty" % [String(sid), i + 1])
		for story_id in Data.STORY_SOURCE_SCENES:
			_assert(scenes.has(String(Data.STORY_SOURCE_SCENES[story_id])),
				"playable story %s references an existing canonical scene" % String(story_id))
		_assert(sc.sim.story_lines("coldstore").size() > Data.STORY["coldstore"]["lines"].size(),
			"Cold Storage uses the complete literary scene")
		_assert(sc.sim.story_lines("broadcast").size() > Data.STORY["broadcast"]["lines"].size(),
			"Yelena broadcast uses the complete literary scene")
	var yelena_unlock: Dictionary = Data.MATE_UNLOCKS["yelena"]
	_assert(String(yelena_unlock.get("trigger", "")) == "landmark:6.66 电台棚"
		and String(Data.loc("manor").get("req_flag", "")) == "manor_tip",
		"Yelena is found at the broadcast landmark and unlocks Pine Manor")
	var broadcast_sim = load("res://scripts/CampaignSim.gd").new()
	broadcast_sim.phase = "map"
	broadcast_sim.flags["first_act_pending"] = false
	broadcast_sim.flags["broadcast_signal"] = true
	broadcast_sim.story_done["market"] = true
	_assert(broadcast_sim.depart(Data.loc("market")), "market raid can carry the broadcast discovery home")
	broadcast_sim.raid.market_signal_found = true
	broadcast_sim.finish_raid("extracted")
	_assert(broadcast_sim.story_open and broadcast_sim.story_id == "broadcast"
		and not bool(broadcast_sim.flags.get("broadcast_pending", false)),
		"extracting after finding the landmark opens Yelena's scene")

	# 晚期队伍台词与扎哈尔举报由道德路线驱动，举报后清杀队警戒标志留存。
	var route_sim = load("res://scripts/CampaignSim.gd").new()
	route_sim.phase = "map"
	route_sim.flags["first_act_pending"] = false
	route_sim.flags["lana_car3"] = true
	route_sim.mates["anna"] = true
	route_sim.mates["zakhar"] = true
	route_sim.tally = 2
	route_sim.conscience = 20.0
	route_sim.select_mate("anna")
	var anna_line: Dictionary = route_sim.story_lines("marshalling").back()
	_assert(anna_line["w"] == "安娜" and String(anna_line["zh"]).contains("你自己说"),
		"Anna voices distrust when she accompanies a ruthless player")
	route_sim.select_mate("zakhar")
	var zakhar_line: Dictionary = route_sim.story_lines("marshalling").back()
	_assert(zakhar_line["w"] == "核算员扎哈尔" and String(zakhar_line["zh"]).contains("一冬的煤和面粉"),
		"Zakhar discloses the offer when he accompanies a ruthless player")
	route_sim.story_id = "marshalling"
	route_sim.story_open = true
	route_sim.resolve_story(0)
	_assert(bool(route_sim.flags.get("zakhar_betrayal_pending", false)), "ruthless route schedules Zakhar's betrayal")
	_assert(route_sim.depart(Data.loc("marshalling")), "dispatch scene can launch after its choice")
	route_sim.finish_raid("extracted")
	_assert(not bool(route_sim.mates.get("zakhar", false)) and bool(route_sim.flags.get("osk_alert", false))
		and route_sim.mate == "none", "Zakhar reports for quota and leaves the crew")

	# 每一句：游标正确、头像角色与情绪正确、末句前无选项、末句后有选项。
	for sid in Data.STORY:
		print("Checking dialogue scene: ", sid)
		var beat: Dictionary = Data.STORY[sid]
		var lines: Array = sc.sim.story_lines(String(sid))
		sc.sim.add_item("band", 1)
		if sid == "pasha_watchtower":
			sc.sim.add_item("asp", 1)
		sc.sim.story_id = sid
		sc.sim.story_open = true
		sc.hud._story_beat = ""
		sc.hud._story_line = 0
		sc.hud._sig = ""
		await _frames(3)
		for i in lines.size():
			if i > 0:
				_assert(sc.hud.advance_story(), "%s line %d advances" % [sid, i + 1])
				await _frames(3)
			_assert(sc.hud._story_line == i, "%s cursor %d" % [sid, i + 1])
			var line: Dictionary = lines[i]
			var role := String(speakers.get(String(line.get("w", "")), "aleksei"))
			var mood := String(line.get("mood", "calm"))
			var tex: Texture2D = sc.hud._story_texture(line)
			_assert(mood in ["calm", "sad", "intense", "wry", "fear", "determined", "hurt"],
				"%s line %d uses supported mood" % [sid, i + 1])
			# 校验解析后的肖像实际可用：具名角色用专属图，其余统一走中性档案占位。
			_assert(tex != null, "%s line %d resolves a usable portrait" % [sid, i + 1])
			if role == "":
				_assert(tex == placeholder, "%s line %d uses the neutral archive placeholder" % [sid, i + 1])
			else:
				var states: Dictionary = portraits.get(role, {})
				var expected: Texture2D = states.get(mood, states.get("calm", placeholder))
				if mood in ["fear", "determined", "hurt"] and sc.hud.STORY_PORTRAIT_NAMES.has(role):
					var path := "res://art/10_characters/portraits/PRT_%s_%s.png" % [
						sc.hud.STORY_PORTRAIT_NAMES[role], mood.capitalize()]
					if ResourceLoader.exists(path):
						expected = load(path)
				_assert(tex == expected, "%s line %d portrait %s/%s" % [sid, i + 1, role, mood])
			_assert(_has_label(sc.hud.modal, String(line["zh"])), "%s line %d full text visible" % [sid, i + 1])
			if i > 0:
				_assert(not _has_label(sc.hud.modal, String(lines[i - 1]["zh"])), "%s line %d previous text cleared" % [sid, i + 1])
			var panel := _find_named(sc.hud.modal, "GalgameStoryPanel")
			_assert(panel != null and panel.get_global_rect().position.y >= 0.0 \
				and panel.get_global_rect().end.y <= panel.get_viewport_rect().size.y + 1.0, "%s line %d panel inside viewport" % [sid, i + 1],
				"viewport=%s panel=%s" % [str(panel.get_viewport_rect()) if panel != null else "null", str(panel.get_global_rect()) if panel != null else "null"])
			var choice: Dictionary = beat["choices"][0]
			var choice_text := String(choice["zh"])
			if sid == "sanitarium":
				choice_text = "撬开铁笼，带她们走（交出 %s ×1）" % sc.sim.item_name("band")
			if i < lines.size() - 1:
				_assert(not _has_button(sc.hud.modal, choice_text), "%s line %d choices hidden" % [sid, i + 1])
			else:
				_assert(_has_button(sc.hud.modal, choice_text), "%s final choices visible" % sid)
		var last: int = sc.hud._story_line
		_assert(not sc.hud.advance_story() and sc.hud._story_line == last, "%s does not advance past final" % sid)
		sc.sim.story_open = false
		sc.hud._sig = ""
		await _frames(3)
		_assert(sc.hud._story_line == 0 and sc.hud._story_beat == "", "%s close resets cursor" % sid)

	# 键盘空格 / 回车与按钮共用推进逻辑。
	sc.sim.story_id = "sanitarium"
	sc.sim.story_open = true
	sc.hud._story_beat = ""
	sc.hud._story_line = 0
	sc.hud._sig = ""
	await _frames(3)
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	root.push_input(key, true)
	await _frames(2)
	_assert(sc.hud._story_line == 1, "Space advances story")
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	root.push_input(enter, true)
	await _frames(2)
	_assert(sc.hud._story_line == 2, "Enter advances story")
	for i in range(sc.hud._story_line, sc.sim.story_lines("sanitarium").size() - 1):
		_press_key(KEY_SPACE)
		await process_frame
	await _frames(3)
	_assert(_has_button(sc.hud.modal, "撬开铁笼，带她们走（交出 %s ×1）" % sc.sim.item_name("band")),
		"keyboard final choices visible")

	# 文学重塑的关键锚点：背景原罪链、受难者控诉与道德抉择语气。
	_assert(String(Data.TEXT["zh"]["tagline"]).contains("从未活过"), "literary background tagline")
	_assert(String(Data.TEXT["zh"]["a1"]).contains("等他醒来"), "literary A1 choice")
	_assert(String(Data.TEXT["zh"]["a3"]).contains("让他安静"), "literary A3 choice")
	_assert(String(Data.STORY["sanitarium"]["lines"][2]["zh"]).contains("半片阿司匹林"), "Anna suffering testimony")
	_assert(String(Data.STORY["market"]["choices"][2]["toast_zh"]).contains("灵魂"), "betrayal moral consequence")
	var canteen: Array = CutsceneData.story_event_slides("canteen_aftermath")
	_assert(String(canteen.back()["zh"]).contains("名字"), "the canteen return preserves Vasily's name")
	_assert(Data.STORY["manor"]["lines"].size() == 5, "manor adds two Grand Inquisitor lines")
	_assert(String(Data.STORY["manor"]["lines"][3]["zh"]).contains("下地狱的十字架"), "Zhukov carries the city's sin")
	_assert(String(canteen[1]["zh"]).contains("费奥多尔"), "Aleksei returns to Fyodor after the fight")

	# 工业档案 UI：十格五角星与铆接指令牌必须有真实组件和样式，而非只换文案。
	var star = load("res://scripts/ui/SovietStarMeter.gd").new()
	root.add_child(star)
	await _frames(2)
	_assert(star.segments == 10, "star meter has ten half-point segments")
	star.set_value(0.55)
	_assert(star.lit_segments() == 6, "star meter partial half-point at 55 percent")
	star.set_value(0.10)
	_assert(star.lit_segments() == 1, "star meter one half-point at 10 percent")
	star.set_value(0.0)
	_assert(star.lit_segments() == 0, "star meter empty at zero")
	star.queue_free()
	var choice_button := _find_button(sc.hud.modal, "撬开铁笼，带她们走（交出 %s ×1）" % sc.sim.item_name("band"))
	_assert(choice_button != null, "art audit finds story choice button")
	if choice_button != null:
		var normal := choice_button.get_theme_stylebox("normal") as StyleBoxFlat
		_assert(normal != null and normal.border_width_left == 6 and normal.corner_radius_top_left == 0,
			"choice button uses square riveted command plate")
		_assert(normal != null and normal.shadow_size >= 3, "choice button has steel plate depth")
		_assert(choice_button.get_node_or_null("CommandChrome") != null,
			"choice button carries rivets and machined cut corners")
	var archive := _find_named(sc.hud.modal, "GalgameStoryPanel")
	_assert(archive != null and (archive.get_theme_stylebox("panel") as StyleBoxFlat).border_width_left == 6,
		"story uses archive panel rather than generic card")

	print("==== RESULT: %d passed, %d failed ====" % [passes, failures.size()])
	quit(0 if failures.is_empty() else 1)
