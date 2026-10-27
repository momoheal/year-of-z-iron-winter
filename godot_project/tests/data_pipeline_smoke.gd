extends SceneTree
## data_pipeline_smoke.gd — 第一阶段数据管线验收（headless）。
##
## Run:
##   Godot --headless --path godot_project -s tests/data_pipeline_smoke.gd
##
## 覆盖：catalog 加载 / 事件结构 / resolver 结算 / delta 应用 /
## 通用 EventPopup 渲染 / 「复制 .tres 改字段即出新事件」零代码验收。

var passes: int = 0
var failures: Array[String] = []

func _init() -> void:
	_run_tests.call_deferred()

func check(cond: bool, name: String) -> void:
	if cond:
		passes += 1
		print("  PASS  ", name)
	else:
		failures.append(name)
		print("  FAIL  ", name)

func _make_delta(target: String, key: String, amount: int) -> DeltaData:
	var d := DeltaData.new()
	d.target = target
	d.key = key
	d.amount = amount
	return d

func _run_tests() -> void:
	var catalog := EventCatalog.new()
	catalog.load_all()

	# 1) 加载数量
	check(catalog.count() == 5, "catalog 加载 5 个事件 .tres")

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var resolver := EventResolver.new()
	var state := PlayerState.new()
	state.reset({"scrap": 5, "can": 5, "water": 3, "rye": 3})

	var popup := EventPopup.new()
	root.add_child(popup)
	await process_frame   # 确保 _ready 构建完所有子节点
	popup.set_lang("zh")

	# 2) 每个事件的结构 + 通用 UI 渲染 + 结算
	for ev in catalog.all_events():
		check(ev.id != "", "事件 id 非空 (%s)" % ev.id)
		check(ev.title_zh != "" and ev.title_en != "", "事件有中英标题 (%s)" % ev.id)
		check(ev.desc_zh != "" and ev.desc_en != "", "事件有中英描述 (%s)" % ev.id)
		check(ev.options.size() >= 1, "事件至少 1 个选项 (%s)" % ev.id)

		popup.show_event(ev)
		check(popup._title.text == ev.title_zh, "EventPopup 标题来自数据 (%s)" % ev.id)
		check(popup._buttons.get_child_count() == ev.options.size(),
			"EventPopup 按钮数 == 选项数 (%s)" % ev.id)

		for option in ev.options:
			check(option.label_zh != "" and option.label_en != "",
				"选项有中英标签 (%s/%s)" % [ev.id, option.id])
			var result: Dictionary = resolver.resolve_option(option, rng)
			check(typeof(result["success"]) == TYPE_BOOL,
				"结算返回 success 布尔 (%s/%s)" % [ev.id, option.id])
			var deltas: Array[DeltaData] = result["deltas"]
			for d in deltas:
				var total: int = resolver.apply_delta(d, state)
				if d.target == "item" and d.amount < 0:
					check(total >= 0, "物品消耗后不会为负 (%s)" % d.key)

	# popup 结果态
	popup.show_event(catalog.get_event("steam_pipe_leak"))
	popup.show_result("测试结果", "test result")
	check(popup._continue_btn.visible, "show_result 后继续按钮可见")

	# 3) 阶段过滤
	check(catalog.events_for_phase("night").size() == 5, "night 阶段包含全部事件")
	check(catalog.events_for_phase("base").size() == 0, "base 阶段无事件（正确过滤）")

	# 4) 零代码新事件验收：模拟「复制 .tres、改字段」
	var new_ev := EventData.new()
	new_ev.id = "custom_test_event"
	new_ev.title_zh = "自定义测试事件"
	new_ev.title_en = "Custom Test Event"
	new_ev.desc_zh = "这是仅靠改数据生成的事件。"
	new_ev.desc_en = "An event made by data alone."
	new_ev.phase = "night"
	var new_opt := EventOptionData.new()
	new_opt.id = "say_hi"
	new_opt.label_zh = "打个招呼"
	new_opt.label_en = "Say hi"
	new_opt.success_chance = 1.0
	var succ: Array[DeltaData] = [_make_delta("stat", "sanity", 5)]
	new_opt.on_success = succ
	var opts: Array[EventOptionData] = [new_opt]
	new_ev.options = opts

	var tmp_path := "res://data/events/_custom_tmp.tres"
	check(ResourceSaver.save(new_ev, tmp_path) == OK, "自定义事件可保存为 .tres")
	var loaded = load(tmp_path)
	check(loaded is EventData, "自定义事件可从 .tres 读回")
	check(loaded.id == "custom_test_event", "读回字段正确")

	popup.show_event(loaded)
	check(popup._buttons.get_child_count() == 1, "通用 EventPopup 渲染自定义事件")
	var sanity_before: float = state.stat_value("sanity")
	var custom_res: Dictionary = resolver.resolve_option(loaded.options[0], rng)
	for d in custom_res["deltas"]:
		resolver.apply_delta(d, state)
	check(state.stat_value("sanity") == sanity_before + 5, "自定义事件 delta 正确生效")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))

	# 汇总
	print("")
	print("==== RESULT: ", passes, " passed, ", failures.size(), " failed ====")
	if failures.is_empty():
		print("DATA_PIPELINE_SMOKE_PASS")
		quit(0)
	else:
		for f in failures:
			print("  FAILED: ", f)
		quit(1)
