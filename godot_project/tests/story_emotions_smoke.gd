extends SceneTree
## 剧情逐句推进 + 角色/情绪头像自动化冒烟测试。

const Data := preload("res://scripts/CampaignData.gd")

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
	for role in ["aleksei", "chernov", "fyodor", "ivan", "anna", "pasha", "gulya", "lana", "pavel", "ash", "leonov"]:
		for mood in ["calm", "sad", "intense"]:
			var tex: Texture2D = portraits[role][mood]
			_assert(tex != null and tex.get_width() >= 512 and tex.get_width() == tex.get_height(),
				"asset %s/%s" % [role, mood])

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

	# 每一句：游标正确、头像角色与情绪正确、末句前无选项、末句后有选项。
	for sid in Data.STORY:
		var beat: Dictionary = Data.STORY[sid]
		var lines: Array = beat["lines"]
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
			_assert(tex == portraits[role][mood], "%s line %d portrait %s/%s" % [sid, i + 1, role, mood])
			_assert(_has_label(sc.hud.modal, String(line["zh"])), "%s line %d full text visible" % [sid, i + 1])
			if i > 0:
				_assert(not _has_label(sc.hud.modal, String(lines[i - 1]["zh"])), "%s line %d previous text cleared" % [sid, i + 1])
			var panel := _find_named(sc.hud.modal, "GalgameStoryPanel")
			_assert(panel != null and panel.get_global_rect().position.y >= 0.0 \
				and panel.get_global_rect().end.y <= panel.get_viewport_rect().size.y + 1.0, "%s line %d panel inside viewport" % [sid, i + 1],
				"viewport=%s panel=%s" % [str(panel.get_viewport_rect()) if panel != null else "null", str(panel.get_global_rect()) if panel != null else "null"])
			var choice: Dictionary = beat["choices"][0]
			var choice_text := String(choice["zh"])
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
	sc._unhandled_input(key)
	_assert(sc.hud._story_line == 1, "Space advances story")
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	sc._unhandled_input(enter)
	_assert(sc.hud._story_line == 2, "Enter advances story")
	await _frames(3)
	_assert(_has_button(sc.hud.modal, String(Data.STORY["sanitarium"]["choices"][0]["zh"])),
		"keyboard final choices visible")

	# 文学重塑的关键锚点：背景原罪链、受难者控诉与道德抉择语气。
	_assert(String(Data.TEXT["zh"]["tagline"]).contains("从未活过"), "literary background tagline")
	_assert(String(Data.TEXT["zh"]["a1"]).contains("等他醒来"), "literary A1 choice")
	_assert(String(Data.TEXT["zh"]["a3"]).contains("让他安静"), "literary A3 choice")
	_assert(String(Data.STORY["sanitarium"]["lines"][2]["zh"]).contains("半片阿司匹林"), "Anna suffering testimony")
	_assert(String(Data.STORY["market"]["choices"][2]["toast_zh"]).contains("灵魂"), "betrayal moral consequence")
	_assert(String(Data.STORY["canteen"]["choices"][0]["toast_zh"]).contains("耳膜"), "Vasily lasting guilt")
	_assert(Data.STORY["manor"]["lines"].size() == 5, "manor adds two Grand Inquisitor lines")
	_assert(String(Data.STORY["manor"]["lines"][3]["zh"]).contains("下地狱的十字架"), "Zhukov carries the city's sin")
	_assert(String(Data.STORY["canteen"]["choices"][0]["toast_zh"]).contains("费奥多尔大叔"), "Aleksei returns to confess")
	_assert(Data.PASHA_EPILOGUE_ZH.contains("不能光着身子见上帝"), "Pasha gives his coat to the nameless dead")

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
	var choice_button := _find_button(sc.hud.modal, String(Data.STORY["sanitarium"]["choices"][0]["zh"]))
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
