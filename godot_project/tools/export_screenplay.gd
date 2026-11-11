extends SceneTree
## 导出可交给 Gemini 优化的中文剧本：主线、事件、清杀队战斗短对白和动态人物台词。
const Data := preload("res://scripts/CampaignData.gd")
const Catalog := preload("res://scripts/data/EventCatalog.gd")

func _initialize() -> void:
	var out := PackedStringArray()
	out.append("# 《Z年纪事：凛冬铁轨》全量对话剧本（陀思妥耶夫斯基文学重塑版）")
	out.append("")
	out.append("> 用途：按陀思妥耶夫斯基式人物塑造与复调心理完成全量文学优化。保留场景 ID、说话者、情绪标记、选项编号、人物关系、档案编号、时间与因果结果；不增加新主线或改变抉择后果。")
	out.append("> 情绪口径：calm=克制/警觉，sad=沉痛，intense=激动/决绝，death=濒死。清杀队短对白为战斗状态池，实际播放时从对应状态中抽取一句。")
	out.append("")
	out.append("# 第零卷 · 背景故事")
	out.append("")
	out.append("诺沃斯克-17 并不是在一夜之间变成坟墓的。它先学会把活人写成数字，再让数字比活人的证词更有分量。电传机亮起绿灯，整栋楼便被宣布已经吃饱；档案编号被划去，一个仍会同你一样喊冷的人便被宣布从未存在。")
	out.append("")
	out.append("十天前，阿列克谢·莫罗佐夫还是铁路货运中心的三级调度员。为了让患尿毒症的母亲领到下一袋 409 批腹透液，他在第 004 号车皮调拨单上签下了自己的名字。那只是一张纸、一枚印鉴、一次温顺得近乎可敬的服从。十天后，妹妹拉娜的档案号 0420 出现在同一趟没有车次的铁壳号名单里——第三节车厢，0401—0576。原来一个人为了救至亲而低下的头，也可能恰好落在另一个至亲的枷锁上。")
	out.append("")
	out.append("城外的人被告知，灰鳞病会把人变成不再配被称为人的东西；回退临床手稿却证明，高热退去之后，鳞片会脱落，瞳孔会重新映出灯光。可若承认这一点，焚化炉、闷罐车和清杀队的每一份台账便都成了供词。于是制度宁可消灭证据，也不肯承认被自己处死的人曾经清醒。")
	out.append("")
	out.append("白昼，你是第 4 号铁路冷库的征召工，为母亲的透析液搬运封条与配给；黑夜，你从 602 室楼下的锅炉房气窗翻出去，在探照灯之间寻找拉娜，也寻找那些仍会同你一样喊渴的人。每夜只能去一个地方，每次抉择都要在良知、物资和生存之间偿还代价。真正追问你的并不是能否活到天亮，而是：当天亮以后，你还敢不敢把自己算作一个人。")
	out.append("")
	out.append("> 文学口径：阿列克谢采用地下室式自审与负罪感；切尔诺夫和清杀队采用规章化的机械冷酷；费奥多尔与安娜采用受难者的痉挛式控诉；伊万采用犬儒外壳下的粗粝悲悯。多声部并置，不由旁白替人物作出最终道德裁决。")
	out.append("")
	var line_count := 0
	var choice_count := 0
	out.append("# 第一卷 · 七段主线剧情")
	for story_id in Data.STORY:
		var story: Dictionary = Data.STORY[story_id]
		out.append("")
		out.append("## %s · %s" % [String(story_id), String(story.get("title_zh", ""))])
		out.append("")
		var idx := 0
		for line in story.get("lines", []):
			idx += 1
			line_count += 1
			var speaker := String(line.get("w", ""))
			if speaker.is_empty():
				speaker = "旁白 / 阿列克谢"
			var mood := String(line.get("mood", "calm"))
			out.append("%02d. **%s**（%s）：%s" % [idx, speaker, mood, String(line.get("zh", ""))])
		out.append("")
		out.append("### 抉择与后果")
		var ci := 0
		for choice in story.get("choices", []):
			ci += 1
			choice_count += 1
			out.append("- **%s-%02d**：%s" % [String(story_id), ci, String(choice.get("zh", ""))])
			out.append("  - 说明：%s" % String(choice.get("d_zh", "")))
			out.append("  - 结果：%s" % String(choice.get("toast_zh", "")))
	out.append("")
	out.append("# 第二卷 · 清杀队战斗短对白")
	for kind in Data.OSK_BARKS:
		var bark: Dictionary = Data.OSK_BARKS[kind]
		out.append("")
		out.append("## %s · %s（%s）" % [String(kind), String(bark.get("speaker_zh", "")), String(bark.get("mood", "calm"))])
		var bi := 0
		for line in bark.get("lines", []):
			bi += 1
			line_count += 1
			out.append("%02d. %s" % [bi, String(line.get("zh", ""))])
	out.append("")
	out.append("# 第三卷 · 随机事件与结果文本")
	var catalog := Catalog.new()
	catalog.load_all()
	var events := catalog.all_events()
	events.sort_custom(func(a, b): return a.id < b.id)
	for ev in events:
		out.append("")
		out.append("## %s · %s" % [ev.id, ev.title_zh])
		out.append("")
		out.append("**情境**：%s" % ev.desc_zh)
		var ei := 0
		for op in ev.options:
			ei += 1
			choice_count += 1
			out.append("- **%s-%02d**：%s" % [ev.id, ei, op.label_zh])
			out.append("  - 结果：%s" % op.result_text_zh)
	out.append("")
	out.append("# 第四卷 · 夜潜与测试场动态人物台词")
	out.append("")
	var supplemental := [
		{"source": "NightExplore.gd / 幸存者首次搭话", "speaker": "幸存者", "zh": "不想变成账本上的死数字，就别站在探照灯底下！"},
		{"source": "NightExplore.gd / 黑市幸存者交易", "speaker": "幸存者", "zh": "黑麦罐头换步枪子弹，一物换一物，眼泪和良心在这儿免谈。"},
		{"source": "NightExplore.gd + RaidSim.gd / 喂药成功", "speaker": "退烧的半人", "zh": "他眼底的紫黑血翳一点点退去，瞳孔重新聚起了人的光彩：「……谢谢你没拿撬棍砸死我……去西站水塔底下，找那个戴蓝毛线帽的老列车长……」"},
		{"source": "RaidSim.gd + GymSim.gd / 瓦西里临终", "speaker": "瓦西里", "zh": "……Пить（水/渴）……"},
		{"source": "GymSim.gd / 灰狼犬证言", "speaker": "安娜（0419）", "zh": "阿列克谢！听我说，拉娜的高烧已经退了！她没有变成怪物，可昨晚清杀队还是按着名单，把她锁进了铁壳号的第三节闷罐车厢！"},
		{"source": "GymSim.gd / 门缝里的求救", "speaker": "门后的装卸工", "zh": "……Воды（给口水吧）……求求你……那个叫拉娜的护士姑娘……被他们塞进三号车厢拉走了……"},
		{"source": "CampaignData.gd / 食堂抉择余韵", "speaker": "瓦西里", "zh": "……Пить（水/渴）……"},
		{"source": "NightExplore.gd / 绕行回退半人", "speaker": "旁白 / 阿列克谢", "zh": "你绕开了他。身后的呜咽仍在追你，仿佛那不是他的声音，而是你自己的。"},
		{"source": "RaidSim.gd / 绕行回退半人", "speaker": "旁白 / 阿列克谢", "zh": "身后传来三声微声点射。你没有回头，仿佛只要不回头，那三枪便与你无关。"},
		{"source": "NightExplore.gd / 灭口记账", "speaker": "旁白 / 阿列克谢", "zh": "撬棍落下。日志背面多了一道卌；你忽然不敢确定，这一道究竟记的是他，还是你。"},
		{"source": "RaidSim.gd / 灭口记账", "speaker": "旁白 / 阿列克谢", "zh": "你在日志背面划下一道血痕。罐头很沉，那道划痕却比罐头更沉。"},
	]
	for item in supplemental:
		line_count += 1
		out.append("- **%s**｜%s：%s" % [String(item.source), String(item.speaker), String(item.zh)])
	out.append("")
	out.append("# 第五卷 · 回退半人道德抉择")
	out.append("")
	out.append("**情境**：暖气井里蜷着一个半人。他的瞳孔还映着灯，身体却被高烧烧得发抖；对面楼顶的红外点正慢慢移过来。你若承认他是人，接下来每一个动作都要付出代价。")
	var raid_choice_results := [
		"他眼底的紫黑血翳一点点退去，瞳孔重新聚起了人的光彩：「……谢谢你没拿撬棍砸死我……去西站水塔底下，找那个戴蓝毛线帽的老列车长……」",
		"身后传来三声微声点射。你没有回头，仿佛只要不回头，那三枪便与你无关。",
		"你在日志背面划下一道血痕。罐头很沉，那道划痕却比罐头更沉。",
	]
	var raid_choice_effects := [
		"阿司匹林 −1 · 热水 −1 · 获得老轨线索 · 良知 +7",
		"良知 −2 · 听到身后枪声",
		"良知 −10 · 卌 +1 · 搜走罐头与废钢",
	]
	for ri in 3:
		choice_count += 1
		out.append("- **raid_choice_a-%02d**：%s" % [ri + 1, String(Data.TEXT["zh"]["a%d" % (ri + 1)])])
		out.append("  - 说明：%s" % String(raid_choice_effects[ri]))
		out.append("  - 结果：%s" % String(raid_choice_results[ri]))
	out.append("")
	out.append("# 第六卷 · 终局人物余响")
	out.append("")
	out.append("## pasha_coat · 防化服与无名女尸")
	out.append("")
	line_count += 1
	out.append("01. **帕沙 / 阿列克谢**（death）：%s" % Data.PASHA_EPILOGUE_ZH)
	out.append("")
	out.append("> 该余响附在鹰嘴崖突围结局之后，不改变 α、β、B 的既有判定与结算。")
	out.append("")
	out.append("# 文学重塑与回填约束")
	out.append("")
	out.append("1. 阿列克谢的旁白承担地下室式自审，但不替其他人物裁决；切尔诺夫与清杀队以规章和编号遮蔽暴力，濒死时才露出凡人的虚无。")
	out.append("2. 费奥多尔与安娜保留受难者的痉挛、热泪与高烧般的控诉；伊万保留犬儒外壳下的粗粝悲悯，避免所有角色使用同一种书面腔。")
	out.append("3. 保留苏联工业城市、铁路档案、极寒和物资匮乏的质感，不加入现代网络词、美式超级英雄口号或突兀幽默。")
	out.append("4. 不删除 004、0892、0420、0419、0401—0576、409 批、第三节车厢、22:00、23:00 等因果锚点，不改变任何选项效果、伙伴、旗标或解锁关系。")
	out.append("5. 清杀队警告保持短促可辨识，追杀保持协作感，阵亡保持断续；动态浮字优先使用短句，长句自动换行并按字数延长显示，完整独白保留在剧情框与本剧本中。")
	var text := "\n".join(out) + "\n"
	var path := ProjectSettings.globalize_path("res://../铁冬_全量对话剧本_Gemini.md")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("无法写入剧本：" + path)
		quit(1)
		return
	file.store_string(text)
	file.close()
	print("SCREENPLAY_OK lines=%d choices=%d events=%d path=%s" % [line_count, choice_count, events.size(), path])
	quit()
