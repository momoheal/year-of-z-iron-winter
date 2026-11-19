extends RefCounted
## CutsceneData.gd — 图片幻灯演出的数据表（由 scripts/ui/StorySlides.gd 播放）。
##
##   PROLOGUE   新开局的故事开场（世界观 → 母亲 → 签字 → 拉娜被带走 → 瞒下转运消息 → 封楼 → 通风口）
##   AFTERMATH  七段主线剧情每个抉择之后的「余波」：键 = "剧情 id:选项序号"
##   scene_image()  剧情对白框背后的场景插图
##   ENDING_SCENES  五种结局（A/B/C + True Ending α/β）的主图与结局余波
##
## 插图约定：res://art/60_ui/cg/cg_<剧情 id>_scene.jpg / cg_<剧情 id>_c<选项序号>.jpg。
## img 可以写成数组，按顺序取第一张存在的；一张都没有时退回 portrait 胸像。
## 所以以后往 cg/ 目录里补图，不用改代码就会自动换上。

const CG := "res://art/60_ui/cg/"
const PRT := "res://art/10_characters/portraits/"

## 恰好五种结局，每个结局都有独立的余波插图。
## 旧的帕沙鹰嘴崖插图不再由多个结局共用。
const ENDING_SCENES := {
	"ENDING_A_RETURN_HOME": {
		"img": CG + "cg_aftermath_a_602.jpg",
		"focus": Vector2(0.52, 0.56),
		"zh": "你把工作日志合上，坐回母亲床边。她伸手来摸你的手套，问拉娜有没有来信。",
		"en": "You close the logbook and sit beside Mother. She reaches for your glove and asks whether Lana has written.",
		"aftermath": [
			{"img": CG + "cg_aftermath_a_602.jpg", "focus": Vector2(0.52, 0.56),
				"zh": "窗台又积了一层雪。你把收音机拧小，等昨晚那段公报再念一遍。",
				"en": "Another layer of snow settles on the sill. You turn down the radio and wait for last night's bulletin to repeat."},
		],
	},
	"ENDING_B_FLAWED_LIBERATION": {
		"img": CG + "cg_ending_broadcast_breach_302_alt.jpg",
		"focus": Vector2(0.46, 0.52),
		"zh": "广播停了。拉娜把话筒放回桌上，听完最后一阵电流声才走出门。",
		"en": "The broadcast ends. Lana sets the microphone down and waits for the last crackle of static before leaving.",
		"aftermath": [
			{"img": CG + "cg_aftermath_b_release.jpg", "focus": Vector2(0.62, 0.52),
				"zh": "人群沿山路往前走。你追上拉娜，她给你让了半步。你们并肩走了一段，谁也没开口。",
				"en": "The crowd heads down the mountain road. You catch up to Lana and she moves half a step aside. You walk together for a while in silence."},
		],
	},
	"ENDING_C_NUMBNESS": {
		"img": CG + "cg_ending_crawl_back_cellar_alt.jpg",
		"focus": Vector2(0.28, 0.55),
		"zh": "他独自从排污涵洞爬回空地窖。雪盖住名字，也盖住了最后一点反抗。",
		"en": "He crawls alone from the drain into an empty cellar. Snow covers the names and the last trace of resistance.",
		"aftermath": [
			{"img": CG + "cg_aftermath_c_numb.jpg", "focus": Vector2(0.56, 0.52),
				"zh": "地窖里有根水管在滴。你数到第四声，放下水碗，把那本没写完的日志推进床底。",
				"en": "A pipe drips in the cellar. On the fourth drop you set down your bowl and push the unfinished logbook under the bed."},
		],
	},
	"TRUE_ALPHA_HELLO_LANA": {
		"img": CG + "cg_ending_true_alpha_hello_lana.jpg",
		"focus": Vector2(0.47, 0.5),
		"zh": "拉娜回到了 602。母亲还在床边等他们，三个人终于重新站在同一盏灯下。",
		"en": "Lana returns to Room 602. Mother is waiting beside the bed, and all three are together beneath the same lamp again.",
		"aftermath": [
			{"img": CG + "cg_aftermath_true_alpha.jpg", "focus": Vector2(0.58, 0.54),
				"zh": "晨光照进 602。拉娜把热水递给母亲。桌上摊着交接底单，你把那支签过字的钢笔放在纸边。",
				"en": "Morning reaches Room 602. Lana hands Mother a cup of warm water. The handover copy lies open on the table, and you set the pen you signed with beside it."},
		],
	},
	"TRUE_BETA_OUTLAND_FIRE": {
		"img": CG + "cg_ending_true_beta_outland_fire.jpg",
		"focus": Vector2(0.35, 0.5),
		"zh": "真相和拉娜都带出了城，母亲却没能等到他们。荒原的火烧过漫长一夜。",
		"en": "The truth and Lana make it out of the city, but Mother does not live to see them. The outland fire burns through the long night.",
		"aftermath": [
			{"img": CG + "cg_aftermath_true_beta.jpg", "focus": Vector2(0.36, 0.5),
				"zh": "天快亮了。你把母亲留下的围巾递给拉娜。她把档案往怀里收了收，低头系紧围巾。",
				"en": "Dawn is close. You hand Lana Mother's scarf. She pulls the records closer to her chest and knots the scarf tight."},
		],
	},
}

const PROLOGUE := [
	{"img": CG + "cg_intro_city.jpg", "focus": Vector2(0.45, 0.55),
		"zh": "Z 年，凛冬。西伯利亚铁路枢纽诺沃斯克-17，封城的第十个月。\n一种叫「灰鳞病」的高烧在城里蔓延。发病的人被叫作「狂暴者」，装进车皮拉走，再也没有回来。",
		"en": "The Year of Z, deep winter. Novorsk-17, a Siberian rail hub, ten months under quarantine.\nA fever called Grey Scale spreads through the town. The sick are called Rabid, loaded into freight cars, and never come back."},
	{"img": CG + "cg_intro_mother.jpg", "focus": Vector2(0.6, 0.55),
		"zh": "你是阿列克谢·莫罗佐夫，货运调度员。602 室里，母亲卡佳靠腹膜透析活着。\n透析液由区配给委员会发放——每一袋，都要拿「听话」去换。",
		"en": "You are Aleksei Morozov, a freight dispatcher. In Room 602 your mother Katya lives on peritoneal dialysis.\nThe fluid is issued by the District Rationing Committee. Every bag is paid for with obedience."},
	{"img": "res://art/60_ui/opening_dispatch.png", "focus": Vector2(0.38, 0.72),
		"zh": "十天前，你在 004 号车皮的调拨单上签了字。作为奖励，母亲领到了下一批腹透液。\n你没有问，那节车皮里装的是什么。",
		"en": "Ten days ago you signed the transfer order for Car 004. In return, Mother received her next batch of fluid.\nYou did not ask what the car was carrying."},
	{"img": CG + "cg_intro_lana.jpg", "focus": Vector2(0.42, 0.42),
		"zh": "十天后的筛查里，妹妹拉娜被带走了。档案编号 0420。\n她被推上装甲列车「铁壳号」的第三节闷罐车厢——和你签过字的那种车皮，一模一样。",
		"en": "Ten days later, your sister Lana was taken at screening. File 0420.\nShe was pushed into Boxcar 3 of the armoured train Buran. A car exactly like the one you signed for."},
	{"img": CG + "cg_intro_mother.jpg", "focus": Vector2(0.6, 0.55),
		"zh": "卡佳：阿廖沙……拉娜还没回电报吗？\n你把转运单折好，塞进大衣内袋。\n阿列克谢：妈，铁路医院派她去外地支援医疗了。等忙完这阵，她就回来。",
		"en": "Katya: Alyosha... still no telegram from Lana?\nYou fold the transfer notice and slip it into your inside coat pocket.\nAleksei: Mama, the railway hospital sent her out of town to help a medical team. She'll be home when the work is done."},
	{"img": "res://art/60_ui/opening_courtyard.png", "focus": Vector2(0.62, 0.6),
		"zh": "清杀队：封楼！所有人退回室内，天亮之前不许出门！\n焊枪封死了单元门。白天你替台账搬运物资；夜里，整栋楼只剩探照灯还醒着。",
		"en": "OSK: Seal the building! Everyone inside. Nobody leaves before dawn!\nThe welders close the stairwell door. By day you haul for the ledger; by night only the searchlights are awake."},
	{"img": CG + "cg_intro_vent.jpg", "focus": Vector2(0.72, 0.6),
		"zh": "只有锅炉房那扇锈死的通风口，还通向外面。每一夜只够去一个地方，天亮之前必须回来。\n你在心里对自己说：先把药带回家，再找到拉娜。",
		"en": "Only the rusted vent of the boiler room still leads outside. One place per night, and back before dawn.\nYou tell yourself: bring the medicine home first, then find Lana."},
]

const AFTERMATH := {
	"coldstore:0": [
		{"img": CG + "cg_coldstore_c0.jpg", "focus": Vector2(0.78, 0.4),
			"zh": "钢笔尖刺破了纸背：谢尔盖、玛丽亚。\n电传机判了他们「零」。可在这张纸上，他们还在喘气。",
			"en": "The nib bites through the page: Sergey. Maria.\nThe teletype counted them as zero. On this paper they are still breathing."},
		{"img": CG + "cg_coldstore_scene.jpg", "focus": Vector2(0.2, 0.6),
			"zh": "柱子后面，谢尔盖把袄子往玛丽亚肩上又拉了一点。他们还不知道，有人把这两个名字记了下来。",
			"en": "Behind the column, Sergey pulls his coat a little higher over Maria's shoulders. Neither of them knows that someone has written down their names."},
		{"img": CG + "cg_coldstore_c0.jpg", "focus": Vector2(0.18, 0.55), "zoom": Vector2(1.08, 1.2),
			"zh": "那只脖子上嵌着断铁丝的灰狼犬无声地走上前，把冻湿的前爪按在你的靴面上。\n你叫它「灰烬」。",
			"en": "The grey wolfdog with the snapped wire collar walks up without a sound and plants a wet paw on your boot.\nYou call him Ash."},
	],
	"coldstore:1": [
		{"img": CG + "cg_coldstore_c1.jpg", "focus": Vector2(0.3, 0.5),
			"zh": "你低下头，数清了公家的箱子，却唯独不敢去数近在咫尺的活人。",
			"en": "You lower your head and count the Committee's crates. The living people an arm's length away, you do not dare to count."},
		{"img": CG + "cg_coldstore_scene.jpg", "focus": Vector2(0.72, 0.42),
			"zh": "身后，配给箱的电子锁又响了一声。账本上写着「零」，没有人会来纠正它。",
			"en": "Behind you the ration lock snaps shut again. The ledger says zero, and nobody will come to correct it."},
		{"img": CG + "cg_coldstore_c1.jpg", "focus": Vector2(0.7, 0.62), "zoom": Vector2(1.08, 1.2),
			"zh": "收发亭旁，那只灰狼犬仍缩在风雪里。你没有剪断锈铁丝，也没有把黑麦饼递过去；它留在原地，颈上的旧伤仍清晰可见。",
			"en": "The wolfdog remains by the dispatch hut in the snow. You did not cut the wire or offer the bread; it stays where it is, its old neck scar still visible."},
	],
	"yard:0": [
		{"img": CG + "cg_yard_scene.jpg", "focus": Vector2(0.33, 0.62),
			"zh": "铁壳号 · 第 7 次特别运输 · 闷罐车厢 03 · 档案 0401—0576。\n0420 不偏不倚，夹在这串数字的中间。",
			"en": "BURAN · Special Run 7 · Boxcar 03 · Files 0401–0576.\n0420 sits exactly inside that range."},
		{"img": CG + "cg_yard_c0.jpg", "focus": Vector2(0.24, 0.5),
			"zh": "你把编组单折好，贴着肋骨收进内袋。它冰得像铁，又烫得像一块烙铁。",
			"en": "You fold the consist sheet into your inner pocket, against your ribs. It is cold as iron and burns like a brand."},
		{"img": CG + "cg_yard_c0.jpg", "focus": Vector2(0.76, 0.45), "zoom": Vector2(1.08, 1.22),
			"zh": "探照灯扫过第三节车厢。拉娜就在那层铁皮后面。\n终到销账点：乌拉尔，鹰嘴崖。",
			"en": "The searchlight crosses the third car. Lana is behind that sheet of steel.\nTerminus: Eagle's Crag, the Urals."},
	],
	"canteen:0": [
		{"img": CG + "cg_canteen_vasily_qte_fyodor_v2.png", "focus": Vector2(0.54, 0.48),
			"zh": "刀刃卡进骨缝的那一瞬，瓦西里眼里的紫黑褪去了。\n他只说了一个词：「……Пить。」——渴。",
			"en": "As the blade jams, the black-purple drains from Vasily's eyes.\nHe says one word: \"...Пить.\" Thirsty."},
		{"img": [CG + "cg_canteen_c0.jpg"], "portrait": PRT + "PRT_Fyodor_Sad.png", "focus": Vector2(0.48, 0.62),
			"zh": "两天后的深夜，你发着高烧回到东街食堂，跪在费奥多尔面前：\n你选了刀，只是因为恐惧让它最快。",
			"en": "Two nights later, feverish, you go back to the East Street canteen and kneel before Fyodor:\nyou chose the cleaver only because fear made it quickest."},
		{"img": [CG + "cg_canteen_c0b.jpg", CG + "cg_canteen_c0.jpg"], "portrait": PRT + "PRT_Fyodor_Calm.png",
			"zh": "老人没有抬手。他把儿子的旧袄披在你肩上：\n「把他活着时候的名字，写进你的本子里。」",
			"en": "The old man does not raise a hand. He drapes his son's coat over your shoulders:\n\"Write the name he had when he was alive. Put it in your book.\""},
	],
	"market:0": [
		{"img": [CG + "cg_market_c0.jpg"], "portrait": PRT + "PRT_Ivan_Calm.png", "focus": Vector2(0.3, 0.6),
			"zh": "伊万冷冷地收下废钢，用粗黑的指甲在油纸上划出一道线：\n「顺着西站水塔底下的排污检修沟摸过去。」",
			"en": "Ivan takes the scrap without warmth and drags a black thumbnail across the oil paper:\n\"Follow the maintenance trench under the West Yard water tower.\""},
		{"img": [CG + "cg_market_c0b.jpg", CG + "cg_market_c0.jpg"], "portrait": PRT + "PRT_Ivan_Intense.png",
			"focus": Vector2(0.60, 0.45), "zoom": Vector2(1.12, 1.3),
			"zh": "「记住——第三根冻裂的枕木底下埋着雷。不想死，就别往上踩。」",
			"en": "\"And remember: there's a mine under the third cracked sleeper. Step on it if you want to die.\""},
		{"img": CG + "cg_yard_scene.jpg", "focus": Vector2(0.5, 0.25),
			"zh": "一笔公平的买卖，谁也不欠谁。\n松林庄园的方向，在油纸上亮了起来。",
			"en": "A fair trade. Nobody owes anybody.\nOn the oil paper, the way to Pine Manor lights up."},
	],
	"market:1": [
		{"img": [CG + "cg_market_c1.jpg"], "portrait": PRT + "PRT_Ivan_Sad.png", "focus": Vector2(0.3, 0.62),
			"zh": "你把救命的抗生素，塞进那些冻烂了脚趾的苦人手里。\n没有人道谢——他们只是不敢相信。",
			"en": "You press your antibiotics into the hands of people whose toes have gone black with frost.\nNobody thanks you. They simply cannot believe it."},
		{"img": [CG + "cg_market_c1b.jpg", CG + "cg_market_c1.jpg"], "portrait": PRT + "PRT_Ivan_Calm.png",
			"focus": Vector2(0.62, 0.40), "zoom": Vector2(1.12, 1.3),
			"zh": "「老轨」伊万浑浊的眼底狠狠颤了一下。他没有再提废钢的事。",
			"en": "Something shakes loose behind Old Ivan's clouded eyes. He does not mention the scrap again."},
		{"img": [CG + "cg_market_c1c.jpg", CG + "cg_market_scene.jpg"], "portrait": PRT + "PRT_Ivan_Intense.png",
			"focus": Vector2(0.50, 0.52),
			"zh": "他把一只烤热了的厚帆布手套塞进你怀里，一言不发，跟上了你的脚步。",
			"en": "He shoves a warmed canvas glove against your chest and, without a word, falls in behind you."},
	],
	"market:2": [
		{"img": [CG + "cg_market_c2.jpg"], "portrait": PRT + "PRT_Ivan_Intense.png", "focus": Vector2(0.3, 0.5),
			"zh": "他替你引开了哨兵。\n而你，从外面落下了铁门的锁。",
			"en": "He drew the sentries off for you.\nAnd you dropped the bolt on the iron door from the outside."},
		{"img": [CG + "cg_market_c2b.jpg", CG + "cg_market_c2.jpg"], "portrait": PRT + "PRT_Ivan_Sad.png",
			"focus": Vector2(0.37, 0.72), "zoom": Vector2(1.14, 1.32),
			"zh": "门后先是一声难以置信的闷哼，紧接着是微声步枪的点射——短促得像踩碎了冰碴。",
			"en": "Behind the door: one grunt of disbelief, then a suppressed burst, as short as ice breaking underfoot."},
		{"img": [CG + "cg_market_c2c.jpg", CG + "cg_market_c2.jpg"], "portrait": PRT + "PRT_Aleksei_Sad.png",
			"focus": Vector2(0.58, 0.55), "zoom": Vector2(1.12, 1.28),
			"zh": "背包被抢来的物资撑得满满当当。\n《工作日志》的背面，多了一道洗不掉的划痕。",
			"en": "Your pack is stuffed with what you took.\nOn the back page of the logbook there is one more stroke that will not wash out."},
	],
	"broadcast:0": [
		{"img": CG + "cg_broadcast_scene_alt_yelena.jpg", "focus": Vector2(0.5, 0.48),
			"zh": "短波信号的尽头，金发的叶莲娜关掉发射机。厚实、剪裁合身的冬衣让她看起来比棚外的人体面；她摘下耳机，主动把频率表递给你。",
			"en": "At the end of the shortwave signal, blonde Yelena switches off the transmitter. Her well-cut winter coat is better kept than anything outside; she removes her headphones and hands you the frequency sheet."},
		{"img": CG + "cg_broadcast_scene_alt_yelena.jpg", "focus": Vector2(0.62, 0.55), "zoom": Vector2(1.06, 1.12),
			"zh": "你选择带她同行。叶莲娜背起监听设备，交出进入松林庄园的排污路线；她也能用无线电命令一名 OSK 暂停行动。",
			"en": "You invite her along. Yelena shoulders her listening gear and shares the drainage route into Pine Manor; her radio can halt one OSK patrol briefly."},
	],
	"broadcast:1": [
		{"img": CG + "cg_broadcast_scene_alt_yelena.jpg", "focus": Vector2(0.5, 0.48),
			"zh": "叶莲娜把发射机的频率留给你，却没有交出自己的监听设备。你记下排污路线，庄园入口已经找到。",
			"en": "Yelena leaves the transmitter frequency with you but keeps her listening gear. You copy the drainage route; the manor entrance is found."},
		{"img": CG + "cg_broadcast_scene_alt_yelena.jpg", "focus": Vector2(0.26, 0.6), "zoom": Vector2(1.08, 1.1),
			"zh": "她留在秘密广播点继续监听。你独自离开，松林庄园已经解锁，但叶莲娜不会加入队伍。",
			"en": "She stays at the hidden broadcast room to keep listening. You leave alone: Pine Manor is unlocked, but Yelena does not join the crew."},
	],
	"sanitarium:0": [
		{"img": [CG + "cg_sanitarium_scene.jpg"], "portrait": PRT + "PRT_Anna_Sad.png", "focus": Vector2(0.72, 0.7),
			"zh": "撬棍崩开了生锈的笼锁。你替她解开嵌进肉里的皮带——\n那是她怕自己伤人，亲手勒上去的。",
			"en": "The crowbar breaks the rusted lock. You undo the straps sunk into her wrists.\nShe had tied them herself, afraid of what she might do."},
		{"img": [CG + "cg_sanitarium_c0b.jpg", CG + "cg_sanitarium_scene.jpg"], "portrait": PRT + "PRT_Anna_Intense.png",
			"focus": Vector2(0.48, 0.42), "zoom": Vector2(1.16, 1.34),
			"zh": "「拉娜的烧退了，三十六度八！昨晚他们把她锁进了铁壳号——第三节车厢！」",
			"en": "\"Lana's fever broke. Thirty-six point eight! Last night they locked her in the Buran. Boxcar Three!\""},
		{"img": [CG + "cg_sanitarium_c0.jpg"], "portrait": PRT + "PRT_Gulya_Calm.png", "focus": Vector2(0.45, 0.6),
			"zh": "安娜（0419）与古丽娅医师搀扶着跟上了你。\n笼门的轴在极夜的风雪里，发出一声长长的、如释重负的悲鸣。",
			"en": "Anna (0419) and Dr. Gulya lean on each other and follow you out.\nIn the polar wind the cage hinge gives one long, relieved scream."},
	],
	"manor:0": [
		{"img": [CG + "cg_manor_c0.jpg"], "portrait": PRT + "PRT_Aleksei_Intense.png", "focus": Vector2(0.36, 0.3),
			"zh": "快门「咔嚓」一响，在轰鸣的炉口旁清脆得像一发顶上膛的子弹。",
			"en": "The shutter clicks. Beside the roaring furnace it sounds like a round being chambered."},
		{"img": [CG + "cg_manor_c0b.jpg", CG + "cg_manor_scene.jpg"], "focus": Vector2(0.65, 0.18),
			"zh": "焚毁台账、409 批腹透液、落满全城窗台的焦油黑雪——\n现在，它们都在你胸口的那卷胶卷里。",
			"en": "The burn ledger, Batch 409, the tar-black snow on every windowsill in town.\nAll of it is now on the roll of film against your chest."},
		{"img": CG + "cg_intro_mother.jpg", "focus": Vector2(0.55, 0.3), "zoom": Vector2(1.06, 1.2),
			"zh": "你把两袋还烫手的腹透液塞进了背包。\n602 室的那盏灯，可以多亮几天了。",
			"en": "You stuff two bags of fluid, still hot, into your pack.\nThe lamp in Room 602 can stay lit a few days longer."},
	],
	"marshalling:0": [
		{"img": [CG + "cg_marshalling_c0.jpg", CG + "cg_marshalling_scene.jpg"], "focus": Vector2(0.16, 0.55),
			"zh": "23:00。鹰嘴崖死线。第三节车厢，核载 176 人。\n死令：实毁数与账面数必须绝对闭合。",
			"en": "23:00. The Eagle's Crag line. Boxcar 3, 176 persons.\nStanding order: the physical count must equal the ledger."},
		{"img": [CG + "cg_marshalling_c0b.jpg"], "portrait": PRT + "PRT_Aleksei_Intense.png",
			"zh": "报废守车的工具箱底，躺着几块抹了黄油的精钢枪机零件。\n你把它们一件一件拆走。",
			"en": "In the toolbox of a dead brake van lie a few greased steel parts of a gun.\nYou take them out, one piece at a time."},
		{"img": CG + "cg_eaglecliff_derailment_scene.jpg", "focus": Vector2(0.66, 0.52), "zoom": Vector2(1.06, 1.22),
			"zh": "所有的数字终于严丝合缝地扣上了。\n一百七十六条退了烧的性命——其中一个，叫拉娜。",
			"en": "Every number finally locks into place.\nOne hundred seventy-six people whose fever has broken. One of them is called Lana."},
	],
	"market_refuge:0": [
		{"img": "res://art/40_interiors/BG_Market_Hideout.png", "focus": Vector2(0.5, 0.55),
			"zh": "电台里传来一串断续的调度呼号。阿列克谢把频率抄进工作日志，随后关掉发射机——这间废信号室只供暂住一夜。",
			"en": "A broken dispatch call sign crackles over the radio. Aleksei copies the frequency into his logbook, then switches the set off. The abandoned signal room is only a one-night refuge."},
		{"img": "res://art/40_interiors/BG_Market_Hideout.png", "focus": Vector2(0.58, 0.46), "zoom": Vector2(1.08, 1.16),
			"zh": "天亮后，他会回 602 看望母亲留下的东西，再沿着维京娜无心说出的线索寻找拉娜。黑市的门只暂时关上，追查还要继续。",
			"en": "At dawn he will return to Room 602 for what Mother left behind, then follow Vikina's offhand clue to Lana. The market door is only closed for now; the search must continue."},
	],
	"station_buran_yard:0": [
		{"img": CG + "cg_station_buran_scene.jpg", "focus": Vector2(0.42, 0.56),
			"zh": "交接底单上没有销账章。只要那枚红印没有落下，车里的人就还没有被账本判死。",
			"en": "The handover copy carries no closure stamp. Until that red mark falls, the people aboard have not been condemned by the ledger."},
		{"img": CG + "cg_station_buran_arrival_alt2.jpg", "focus": Vector2(0.56, 0.5), "zoom": Vector2(1.06, 1.16),
			"zh": "你把底单折进内袋，在地图上标出通往鹰嘴崖的检修线。数字之外，终于有了一条能走的路。",
			"en": "You fold the copy into your inner pocket and mark the maintenance line to Eagle's Crag. Beyond the numbers, there is finally a road to take."},
	],
	"eagle_beak_cliff:0": [
		{"img": CG + "cg_eaglecliff_derailment_scene.jpg", "focus": Vector2(0.44, 0.54),
			"zh": "撬棍咬住门缝，第三节车厢的锁被顶开。能走的人一个接一个踏上检修路，崖顶的灯追在身后。",
			"en": "The crowbar bites the door seam and Boxcar Three gives way. Everyone who can walk takes the maintenance path, with the ridge lights hunting behind them."},
		{"img": CG + "cg_eaglecliff_lana_004_rescue_alt2.jpg", "focus": Vector2(0.58, 0.48), "zoom": Vector2(1.08, 1.18),
			"zh": "拉娜在人群里认出了你。最后一批人翻过护坡时，302 台的灯在远处亮了起来。",
			"en": "Lana recognizes you in the crowd. As the last of them clear the embankment, the lamp of Tower 302 kindles in the distance."},
	],
	"eagle_beak_cliff:1": [
		{"img": CG + "cg_eaglecliff_derailment_scene.jpg", "focus": Vector2(0.62, 0.5),
			"zh": "你只带走了拉娜和底单。车门在身后重新合拢，车厢里的人没有等到你第二次回来。",
			"en": "You leave with only Lana and the copy. The door closes again behind you; the people in the car never see you return."},
		{"img": CG + "cg_eaglecliff_004_plaque_recovery_alt.jpg", "focus": Vector2(0.5, 0.55), "zoom": Vector2(1.08, 1.16),
			"zh": "底单上的 0420 还在，多出来的姓名却被你留在了崖下。《工作日志》的背面又添了一道划痕。",
			"en": "0420 is still on the copy, but the names you left behind stay under the cliff. One more stroke marks the back of the logbook."},
	],
	"broadcast_tower_302:0": [
		{"img": CG + "cg_broadcast_testimony_scene.jpg", "focus": Vector2(0.48, 0.5),
			"zh": "名单一个名字一个名字地念下去。全城的收音机里，第一次有了他们的姓名，不再只是编号。",
			"en": "The list is read out name by name. For the first time the city's radios carry their names, not just file numbers."},
		{"img": CG + "cg_broadcast_city_listeners_dawn_alt.jpg", "focus": Vector2(0.52, 0.56), "zoom": Vector2(1.06, 1.14),
			"zh": "南门守住了。天亮时 302 台的发射机还在响；有人在信里写下了听到的第一个名字。",
			"en": "The south gate holds. At dawn the transmitter is still alive, and someone writes down the first name they heard."},
	],
	"broadcast_tower_302:1": [
		{"img": CG + "cg_broadcast_pavel_switch_repair_alt.jpg", "focus": Vector2(0.46, 0.54),
			"zh": "照片和编号上了频率，姓名却没有。帕维尔把发射机又撑了一分钟，雪落进了打开的塔门。",
			"en": "The photographs and file numbers go on air, but not the names. Pavel keeps the transmitter alive one more minute as snow drifts through the open tower door."},
		{"img": CG + "cg_broadcast_final_dawn_gathering_alt.jpg", "focus": Vector2(0.5, 0.52), "zoom": Vector2(1.06, 1.16),
			"zh": "城市听见了罪证，却不知道该为谁记下名字。名单留在你口袋里，仍旧只是一张纸。",
			"en": "The city hears the evidence but not whom to mourn by name. The list stays in your pocket, still only paper."},
	],
}


## Room 602 interactions. These are used both in the hub UI and the review deck.
const ROOM_DIALOGUE := {
	"mother": [
		{"img": CG + "cg_intro_mother.jpg", "portrait": PRT + "PRT_Katya_Calm.png", "show_portrait": true,
			"focus": Vector2(0.58, 0.56),
			"zh": "卡佳：阿廖沙，手怎么这么凉？把手套放到炉边吧。\n阿列克谢：我没事，妈。今晚我会把背包里的东西理好。",
			"en": "Katya: Alyosha, your hands are freezing. Leave your gloves by the stove.\nAleksei: I'm all right, Mama. I'll sort what I brought back tonight."},
		{"img": CG + "cg_intro_mother.jpg", "portrait": PRT + "PRT_Katya_Determined.png", "show_portrait": true,
			"focus": Vector2(0.62, 0.52),
			"zh": "卡佳：别总想着替所有人扛事。先坐下喝口热水，让我看看你有没有伤着。\n她说得很轻，像怕惊动透析机。",
			"en": "Katya: You can't carry everyone. Sit down and drink something warm; let me see if you're hurt.\nShe speaks softly, as if not to wake the dialysis machine."},
	],
	"mother_waiting": [
		{"img": CG + "cg_intro_mother.jpg", "portrait": PRT + "PRT_Katya_Fear.png", "show_portrait": true,
			"focus": Vector2(0.6, 0.55),
			"zh": "卡佳：机器还能撑一阵。别为了我一个人，把自己也搭进去。\n阿列克谢看了看透析机旁空着的位置，没有回答。",
			"en": "Katya: The machine can hold for a little while. Don't lose yourself trying to save me.\nAleksei looks at the empty space beside the dialysis machine and says nothing."},
	],
	"mother_memory": [
		{"img": CG + "cg_intro_mother.jpg", "focus": Vector2(0.56, 0.5),
			"zh": "屋里只剩透析机停下后的静默。你把母亲留下的围巾叠好，放在床边。",
			"en": "Only silence remains after the dialysis machine stops. You fold your mother's scarf and set it beside the bed."},
	],
	"fluid_given": [
		{"img": CG + "cg_intro_mother.jpg", "portrait": PRT + "PRT_Katya_Determined.png", "show_portrait": true,
			"focus": Vector2(0.52, 0.58),
			"zh": "阿列克谢把一袋透析液放到机器旁。\n卡佳：这一袋先留着，明早再换。你总算肯让我也替你省着点力气了。",
			"en": "Aleksei sets a bag of dialysis fluid beside the machine.\nKatya: Keep this one for the morning. At last you're letting me help you save a little strength."},
	],
	"vikina_lead": [
		{"img": CG + "cg_intro_mother.jpg", "portrait": PRT + "PRT_Vikina_Calm.png", "show_portrait": true,
			"focus": Vector2(0.42, 0.5),
			"zh": "楼道里，邻居维京娜隔着半掩的门和人说话。她正抱怨电报局把一份旧底单退回了档案馆。",
			"en": "In the hall, neighbor Vikina talks through a half-open door. She complains that the telegraph office returned an old dispatch copy to the archive."},
		{"img": CG + "cg_intro_vent.jpg", "portrait": PRT + "PRT_Vikina_Wry.png", "show_portrait": true,
			"focus": Vector2(0.62, 0.55),
			"zh": "维京娜：封面写着 0420，底下还铅笔记了“第三节”。谁会把这种旧名单当回事？我只想找回配给单。\n她没意识到自己说出了什么。",
			"en": "Vikina: The cover said 0420, with “third car” pencilled underneath. Who cares about an old list? I only want my ration slip back.\nShe doesn't realize what she has just said."},
		{"img": CG + "cg_intro_mother.jpg", "portrait": PRT + "PRT_Aleksei_Determined.png", "show_portrait": true,
			"focus": Vector2(0.5, 0.42),
			"zh": "阿列克谢：0420……拉娜的档案号。\n名单被退回档案馆，底单就在电报局。今晚我去找它。",
			"en": "Aleksei: 0420... Lana's file number.\nThe list went back to the archive; the dispatch copy is at the telegraph office. I'll find it tonight.",
			"choices": [
				{"id": "vikina_ask", "zh": "追问维京娜，确认底单去向", "en": "Ask Vikina where the copy went",
					"followup": {"img": CG + "cg_intro_vent.jpg", "portrait": PRT + "PRT_Vikina_Sad.png", "show_portrait": true,
						"focus": Vector2(0.58, 0.48),
						"zh": "维京娜的笑意淡了下去。她只确认底单已经退回档案馆，随后把门轻轻合上。阿列克谢没有再问，把这句话记进日志。",
						"en": "Vikina's smile fades. She confirms only that the copy went back to the archive, then gently closes the door. Aleksei writes it in his log and asks nothing more."}},
				{"id": "vikina_quiet", "zh": "记下线索，暂不惊动她", "en": "Keep the clue to yourself",
					"followup": {"img": CG + "cg_intro_vent.jpg", "portrait": PRT + "PRT_Aleksei_Determined.png", "show_portrait": true,
						"focus": Vector2(0.62, 0.52),
						"zh": "阿列克谢没有敲门。他把 0420 和“第三节”记在手套内侧，转身朝档案馆电报局走去。维京娜仍不知道自己递出了一条线索。",
						"en": "Aleksei does not knock. He writes 0420 and “third car” inside his glove and heads for the Archive & Telegraph Office. Vikina never learns she gave him the lead."}},
			]},
	],
	"market_refuge": [
		{"img": "res://art/40_interiors/BG_Market_Hideout.png", "focus": Vector2(0.5, 0.5),
			"zh": "废信号室的短波机还活着。阿列克谢把门栓扣上，在炉边留下一盏遮光灯。这里不安全，却能让他在黑市搜捕间隙喘口气。",
			"en": "The shortwave set in the abandoned signal room still works. Aleksei bolts the door and shades a lamp by the stove. It is not safe, but it gives him a place to breathe between market searches."},
		{"img": "res://art/40_interiors/BG_Market_Hideout.png", "focus": Vector2(0.55, 0.52),
			"zh": "这不是家。他还会回 602 看一眼母亲留下的东西，再沿着维京娜无心说出的线索去找拉娜。",
			"en": "This is not home. He will return to 602 for what Mother left behind, then follow Vikina's offhand clue to Lana."},
	],
}


## 剧情对白框背后的场景插图路径（文件可能还不存在，调用方用 StorySlides.tex_of 判空）。
static func scene_image(story_id: String, context: Dictionary = {}) -> String:
	if story_id == "market_refuge":
		return "res://art/40_interiors/BG_Market_Hideout.png"
	if story_id == "manor" and String(context.get("mate", "")) == "yelena":
		return CG + "cg_manor_yelena_zhukov_confront_v1.png"
	if story_id == "sanitarium" and not bool(context.get("ash_present", false)):
		return CG + "cg_sanitarium_anna_cage_no_ash.jpg"
	var story_cg := {
		"broadcast": "cg_broadcast_scene_alt_yelena.jpg",
		"pasha_watchtower": "cg_pasha_watchtower_scene.jpg",
		"apartment_exchange": "cg_apartment_exchange_scene.jpg",
		"mine_sporeface": "cg_mine_sporeface_scene_alt.jpg",
		"mine_detonator": "cg_mine_detonator_scene.jpg",
		"fire_rescue": "cg_fire_rescue_scene_alt.jpg",
		"eaglecliff_derailment": "cg_eaglecliff_derailment_scene.jpg",
		"station_buran": "cg_station_buran_scene.jpg",
		"station_buran_yard": "cg_station_buran_scene.jpg",
		"eagle_beak_cliff": "cg_eaglecliff_derailment_scene.jpg",
		"broadcast_tower_302": "cg_tower302_aleksei_at_transmitter.jpg",
		"broadcast_siege": "cg_broadcast_siege_scene.jpg",
		"broadcast_testimony": "cg_broadcast_testimony_scene.jpg",
	}
	if story_cg.has(story_id):
		return CG + String(story_cg[story_id])
	return CG + "cg_%s_scene.jpg" % story_id


## 结局主图（与 CampaignSim.ending_key() 的五个键一一对应）。
static func ending_scene(ending_key: String, context: Dictionary = {}) -> String:
	if ending_key == "ENDING_B_FLAWED_LIBERATION":
		if bool(context.get("crag_rescue_lana", false)):
			return CG + "cg_tower302_aleksei_at_transmitter.jpg"
		if not bool(context.get("crag_rescue_all", false)):
			# Old saves do not prove how many people left the boxcar.
			return CG + "cg_tower302_aleksei_at_transmitter.jpg"
	var entry: Dictionary = ENDING_SCENES.get(ending_key, {})
	return String(entry.get("img", ""))


## 结局后的插画页。无余波的结局返回空数组。
static func ending_aftermath(ending_key: String) -> Array:
	var entry: Dictionary = ENDING_SCENES.get(ending_key, {})
	return (entry.get("aftermath", []) as Array).duplicate(true)


## 用于“回看结局与余波”按钮的完整幻灯顺序。
static func ending_slides(ending_key: String, mother_alive := false, context: Dictionary = {}) -> Array:
	var entry: Dictionary = ENDING_SCENES.get(ending_key, {})
	if entry.is_empty():
		return []
	var slides: Array = []
	if ending_key == "ENDING_C_NUMBNESS" and not mother_alive:
		slides.append({
			"img": CG + "cg_room602_empty_bed_folded_scarf.jpg",
			"focus": Vector2(0.5, 0.55), "zoom": Vector2(1.02, 1.08),
			"zh": "你把没查完的《工作日志》合上。床边的围巾没有动，透析机也不再发出声音。",
			"en": "You close the unfinished logbook. The scarf by the empty bed has not moved, and the dialysis machine is silent.",
		})
	var main_zh := String(entry.get("zh", ""))
	var main_en := String(entry.get("en", ""))
	if ending_key == "ENDING_B_FLAWED_LIBERATION":
		if bool(context.get("crag_rescue_lana", false)):
			main_zh = "广播塔的红灯熄了。拉娜等到走廊上只剩下你们两个人，才停下脚步。"
			main_en = "The tower's red light goes out. Lana waits until the two of you are alone in the corridor, then stops."
		elif not bool(context.get("crag_rescue_all", false)):
			main_zh = "发射机还在响。拉娜从门口回头看你，手搭在门框上。"
			main_en = "The transmitter is still running. Lana looks back at you from the doorway, her hand on the frame."
	slides.append({
		"img": ending_scene(ending_key, context), "focus": entry.get("focus", Vector2(0.5, 0.5)),
		"zh": main_zh, "en": main_en,
	})
	if ending_key == "ENDING_B_FLAWED_LIBERATION" and bool(context.get("crag_rescue_lana", false)):
		slides.append({
			"img": CG + "cg_tower302_aleksei_at_transmitter.jpg", "focus": Vector2(0.54, 0.52),
			"zh": "拉娜望着窗外的雪。\n「哥，咱们走的时候……第三节车门还开着吗？」\n阿列克谢：「开着。」",
			"en": "Lana: “When we left, was the door to Boxcar Three still open?”\nAleksei: “It was.”",
		})
	elif ending_key == "ENDING_B_FLAWED_LIBERATION" and not bool(context.get("crag_rescue_all", false)):
		slides.append({
			"img": CG + "cg_tower302_aleksei_at_transmitter.jpg", "focus": Vector2(0.48, 0.5),
			"zh": "你关上发射机，拿起大衣。拉娜在门外等你，你们一前一后下了楼。",
			"en": "You switch off the transmitter and pick up your coat. Lana waits outside, and you follow her down the stairs.",
		})
	else:
		slides.append_array(ending_aftermath(ending_key))
	if ending_key == "TRUE_BETA_OUTLAND_FIRE" and mother_alive:
		slides[0]["zh"] = "母亲还活着。真相已经传开，出卖他们的人也把消息送到了清杀队。"
		slides[0]["en"] = "Mother is alive. The truth is out, and someone has passed word to the OSK."
		slides[1]["zh"] = "城外火光下，拉娜和阿列克谢分着守夜。他们等天亮，再找路回去。"
		slides[1]["en"] = "Outside the city, Lana and Aleksei take turns watching the fire. At dawn they will look for a way back."
	if bool(context.get("pasha_witness_seen", false)) and bool(context.get("pasha_survived_to_crag", false)):
		slides.append({
			"img": CG + "cg_aftermath_pasha_crag_mercy.jpg", "focus": Vector2(0.52, 0.55),
			"zh": "帕沙把防化服拉到那个女人肩上。扣子试了两次都没对上。\n帕沙：「大哥……帮我系上。系严实点，外头雪大。」",
			"en": "Pasha pulls his protective coat over the woman's shoulders. Twice he misses the buttonhole.\nPasha: “Brother… help me button it. All the way. It's snowing hard.”",
		})
	return slides


## 抉择余波的幻灯页（深拷贝）。没配的抉择返回空数组 = 不播。
static func aftermath(story_id: String, choice_index: int) -> Array:
	var key := "%s:%d" % [story_id, choice_index]
	if not AFTERMATH.has(key):
		return []
	var out: Array = (AFTERMATH[key] as Array).duplicate(true)
	return out


## Campaign story slides. NightExplore plays in-mission events; CampaignHUD plays queued hub aftermath.
static func story_event_slides(event_id: String, context: Dictionary = {}) -> Array:
	match event_id:
		"canteen_vasily_qte":
			return [{
				"img": CG + "cg_canteen_vasily_qte_fyodor_v2.png", "focus": Vector2(0.52, 0.48),
				"zh": "刀刃卡在锁骨里。瓦西里还压着你，费奥多尔在一旁伸手。把刀拔出来！",
				"en": "The blade is caught in his collarbone. Vasily is still on top of you; Fyodor reaches from beside you. Pull the blade free!",
				"qte": {"required": 6, "seconds": 1.8,
					"prompt_zh": "连按空格 / 左键", "prompt_en": "Mash Space / click"},
			}]
		"canteen_aftermath":
			return [
				{"img": CG + "cg_canteen_vasily_qte_fyodor_v2.png", "focus": Vector2(0.55, 0.48),
					"zh": "瓦西里的眼睛清亮了一瞬。他喉咙里挤出一个词：「……Пить。」——水，渴。",
					"en": "Vasily's eyes clear for one instant. He forces out a word: \"...Пить.\" Water. Thirst."},
				{"img": CG + "cg_canteen_c0.jpg", "portrait": PRT + "PRT_Fyodor_Sad.png", "focus": Vector2(0.48, 0.62),
					"zh": "两天后的深夜，你发着高烧回到食堂，在费奥多尔面前跪下。老人没有举起手，只摸了摸儿子渐渐冷下来的脸。",
					"en": "Two nights later, feverish, you return to the canteen and kneel before Fyodor. He raises no hand; he only touches his son's cooling face."},
				{"img": CG + "cg_canteen_c0b.jpg", "portrait": PRT + "PRT_Fyodor_Calm.png", "focus": Vector2(0.48, 0.62),
					"zh": "费奥多尔把瓦西里的旧坎肩披在你肩上：「别把他当成怪物。把他活着时候的名字写下来。」",
					"en": "Fyodor lays Vasily's old vest over your shoulders. \"Do not call him a monster. Write down the name he had while he was alive.\""},
			]
		"redzone_mother":
			return [
				{"img": CG + "cg_redzone_mother_gate_v1.png", "focus": Vector2(0.62, 0.48),
					"zh": "心声：手背上有灰鳞。往暗处退。……等等，她在叫谁开门？",
					"en": "Inner voice: Gray scales on her hand. Back into shadow. …Wait. Who is she asking to open the door?"},
				{"img": CG + "cg_redzone_mother_gate_v1.png", "focus": Vector2(0.77, 0.5), "zoom": Vector2(1.08, 1.18),
					"zh": "她隔着铁栅栏向楼里喊：「科利亚……给妈开条缝。妈退烧了，你摸摸。妈不进去，只看一眼小安东。」",
					"en": "She calls through the bars: \"Kolya... open the door a little. Mama's fever broke; feel my forehead. I won't come in. I only want to see little Anton.\""},
				{"img": CG + "cg_redzone_mother_osk_v1.png", "focus": Vector2(0.63, 0.46),
					"zh": "探照灯照亮栅栏，清杀队从拐角出来。\n女人：「别开枪……我退烧了。」",
					"en": "A searchlight catches the bars as the purge squad rounds the corner.\nWoman: “Don't shoot… my fever broke.”"},
				{"img": CG + "cg_redzone_mother_aftermath_v1.png", "focus": Vector2(0.48, 0.55),
					"zh": "两声闷响。她倒在门边，再没动过。清杀队走远了，铜钥匙落在沟沿。",
					"en": "Two muffled shots. She falls by the gate and never moves again. The squad walks away. Her brass keys lie by the gutter."},
				{"img": CG + "cg_redzone_mother_scales_v1.png", "focus": Vector2(0.39, 0.58), "zoom": Vector2(1.06, 1.16),
					"zh": "她没有疯。她退烧了。你想起被带走的拉娜：她也可能正在退烧。",
					"en": "She was not mad. Her fever had broken. You think of Lana, taken away in the train: her fever may be breaking too."},
			]
		"fire_rescue":
			var pages: Array = [
				{"img": CG + "cg_fire_rescue_scene_alt.jpg", "focus": Vector2(0.54, 0.52),
					"zh": "楼梯间灌满黑烟。柳德米拉被挤倒，仍把佳娜护在怀里，手里攥着一张熏黑的领粮券。墙上的喇叭还在叫人留在屋里。",
					"en": "Black smoke fills the stairwell. Lyudmila is knocked down but still shields Jana, clutching a soot-blackened ration ticket. The wall speaker keeps telling residents to stay inside."},
				{"img": CG + "cg_fire_rescue_lyudmila_handoff_close_alt.jpg", "focus": Vector2(0.52, 0.54),
					"zh": "柳德米拉把佳娜推到你怀里，把那张熏黑的领粮券也塞过来：「带她走。替我告诉她，姥姥不是坏人。」佳娜抓住你的袖口：「叔叔，咱们的钥匙呢？」",
					"en": "Lyudmila pushes Jana into your arms and presses the soot-blackened ration ticket into your hand. \"Take her. Tell her Grandma wasn't a bad person.\" Jana clutches your sleeve: \"Uncle, where are our keys?\""},
			]
			if bool(context.get("pavel_present", false)):
				pages.append({"img": CG + "cg_fire_pavel_cutting_torch_v1.png", "focus": Vector2(0.55, 0.5),
					"zh": "帕维尔顶着浓烟割开焊死的横梁。火星落在他的袖口，他把最后一处焊点烧断。",
					"en": "Pavel cuts through the welded crossbar in the smoke. Sparks fall on his sleeve as he burns through the last joint."})
			else:
				pages.append({"img": CG + "cg_fire_stairwell_neighbors_breach_v1.png", "focus": Vector2(0.52, 0.52),
					"zh": "几个住户把撬棍和铁管顶进门缝，一起压下去。门轴松开时，后面的人扶住了佳娜。",
					"en": "Residents wedge crowbars and iron pipe into the door seam and lean together. As the hinge gives, someone behind them catches Jana."})
			if bool(context.get("ash_present", false)):
				pages.append({"img": CG + "cg_fire_ash_guides_jana_v1.png", "focus": Vector2(0.43, 0.55),
					"zh": "灰烬咬住佳娜棉袄的后摆，把她从门边带到避风处。住户伸手接过孩子，灰烬退回阿列克谢身侧。",
					"en": "Ash catches the hem of Jana's coat and guides her away from the doorway. A resident takes the child, and Ash returns to Aleksei's side."})
			pages.append({"img": CG + "cg_eaglecliff_derailment_scene.jpg", "focus": Vector2(0.62, 0.5),
				"zh": "雪地尽头传来一声沉闷的金属断响。阿列克谢把鹰嘴崖写进日志，转身朝车站方向走。",
				"en": "A dull metal snap carries from beyond the snow. Aleksei writes Eagle's Crag in his logbook and turns toward the station."})
			return pages
		"mine_inscriptions":
			return [
				{"img": CG + "cg_mine_no3_wall_inscription_v1.png", "focus": Vector2(0.56, 0.48), "zoom": Vector2(1.02, 1.1),
					"zh": "爆破断面的岩壁上留着凿痕。字刻得很深，后半行被剥落的冻土盖住。",
					"en": "Chisel marks cut across the blasted rock face. The words run deep; fallen permafrost covers the ends."},
				{"img": CG + "cg_mine_no3_wall_inscription_v1.png", "focus": Vector2(0.37, 0.53), "zoom": Vector2(1.12, 1.28),
					"zh": "「瓦尼亚，别管我，带你弟跑。」",
					"en": "\"Vanya, leave me. Take your brother and run.\""},
				{"img": CG + "cg_mine_no3_wall_inscription_v1.png", "focus": Vector2(0.60, 0.5), "zoom": Vector2(1.12, 1.28),
					"zh": "「冰打穿了。山里冒灰了。」",
					"en": "\"The ice broke open. The mountain is breathing ash.\""},
				{"img": CG + "cg_mine_no3_wall_inscription_v1.png", "focus": Vector2(0.63, 0.6), "zoom": Vector2(1.16, 1.32),
					"zh": "「不是煤灰……胸口烧得慌。」阿列克谢把这几行字记进日志，断面上的灰黑粉末还需要近处查验。",
					"en": "\"It isn't coal ash... my chest burns.\" Aleksei copies the lines into his log. The dark powder still needs closer examination."},
			]
		"crag_reveal":
			var plaque_img := "cg_eaglecliff_derailment_scene.jpg"
			if bool(context.get("ivan_present", false)):
				plaque_img = "cg_eaglecliff_004_plaque_recovery_alt.jpg"
			return [
				{"img": CG + plaque_img, "focus": Vector2(0.52, 0.52),
					"zh": "手电扫过铭牌：004。调拨底单还贴在你胸口，签发栏里是你自己的笔迹。",
					"en": "Your flashlight catches the plate: 004. The dispatch copy is still against your chest. The signature is in your own hand."},
				{"img": CG + "cg_boxcar03_survivors_reveal_v1.png", "focus": Vector2(0.5, 0.52),
					"zh": "车厢里挤着一群活人。他们的灰鳞已经退去；有人抱着孩子，有人用饭盒接车顶落下的雪水。",
					"en": "A crowd of living people fills the car. Their gray scales have fallen away; one holds a child while another catches snowmelt in a tin cup."},
				{"img": CG + "cg_boxcar03_survivors_reveal_v1.png", "focus": Vector2(0.75, 0.43), "zoom": Vector2(1.08, 1.18),
					"zh": "拉娜攥住你的袖口：「哥，我烧退了。门边这几个还能走，里头还有人。」",
					"en": "Lana grips your sleeve. “My fever broke. The ones by the door can walk. There are still people inside.”",
					"required_choice": true,
					"choices": [
						{"id": "all", "zh": "带能走的人一起沿检修线撤离", "en": "Take everyone who can walk along the service line"},
						{"id": "lana", "zh": "先带拉娜和底单撤离", "en": "Leave first with Lana and the dispatch copy"},
					]},
			]
		"manor_confrontation":
			if not bool(context.get("yelena_present", false)):
				var absent_plan := String(context.get("manor_plan", "evidence"))
				var absent_action_zh := "你把相机对准账本，准备留下焚毁记录。"
				var absent_action_en := "You raise the camera toward the ledger to preserve the burn record."
				if absent_plan == "trade":
					absent_action_zh = "你接过空白配给凭条。老谢苗的名字还没有写上去。"
					absent_action_en = "You take the blank ration slip. Old Semyon's name is not written on it yet."
				elif absent_plan == "release":
					absent_action_zh = "你看了一眼门边的锁盒。地下室的敲门声还没有停。"
					absent_action_en = "You glance at the lock box by the door. The cellar knocking has not stopped."
				return [
					{"img": CG + "cg_manor_scene.jpg", "focus": Vector2(0.55, 0.48),
						"zh": "茹科夫把配给审计账推到你面前。桌后是焚化炉，门外有人在地下室里敲门。",
						"en": "Zhukov pushes the ration ledger toward you. The furnace stands behind him; someone knocks from the cellar beyond the door."},
					{"img": CG + "cg_manor_scene.jpg", "focus": Vector2(0.72, 0.48), "zoom": Vector2(1.08, 1.2),
						"zh": absent_action_zh,
						"en": absent_action_en},
				]
			var plan := String(context.get("manor_plan", "evidence"))
			var outcome_zh := "你把相机对准账本，准备留下焚毁记录。"
			var outcome_en := "You raise the camera toward the ledger to preserve the burn record."
			if plan == "trade":
				outcome_zh = "你接过空白配给凭条。老谢苗的名字还没有写上去。"
				outcome_en = "You take the blank ration slip. Old Semyon's name is not written on it yet."
			elif plan == "release":
				if bool(context.get("yelena_present", false)):
					outcome_zh = "叶莲娜把手按在桌边。你记下门禁锁盒的位置，地下室的敲门声还没有停。"
					outcome_en = "Yelena braces a hand on the desk. You note the lock box; the cellar knocking has not stopped."
				else:
					outcome_zh = "你看了一眼门边的锁盒。地下室的敲门声还没有停。"
					outcome_en = "You glance at the lock box by the door. The cellar knocking has not stopped."
			return [
				{"img": CG + "cg_manor_yelena_zhukov_confront_v1.png", "focus": Vector2(0.52, 0.5),
					"zh": "叶莲娜把通行证压在账本上。茹科夫看着女儿，没有伸手拿走。",
					"en": "Yelena presses the pass against the ledger. Zhukov looks at his daughter and does not take it."},
				{"img": CG + "cg_manor_yelena_zhukov_confront_v1.png", "focus": Vector2(0.73, 0.48), "zoom": Vector2(1.08, 1.2),
					"zh": outcome_zh, "en": outcome_en},
			]
		"manor_outcome":
			var outcome_plan := String(context.get("manor_plan", "evidence"))
			var manor_img := CG + "cg_manor_scene.jpg"
			var outcome_text_zh := "你把焚化记录的底片带回 602 室。"
			var outcome_text_en := "You bring the negative of the burn record back to Room 602."
			if bool(context.get("yelena_present", false)):
				manor_img = CG + "cg_manor_yelena_zhukov_confront_v1.png"
			if outcome_plan == "trade":
				outcome_text_zh = "配给跟你回了 602 室。老谢苗的位置留在茹科夫的账上。"
				outcome_text_en = "The ration reaches Room 602 with you. Old Semyon's location stays in Zhukov's ledger."
			elif outcome_plan == "release":
				if bool(context.get("yelena_present", false)):
					outcome_text_zh = "地下室的工人已沿围墙离开。叶莲娜把通行证收回口袋，没有看父亲。"
					outcome_text_en = "The cellar workers escaped along the wall. Yelena puts away the pass without looking at her father."
				else:
					outcome_text_zh = "地下室的工人已沿围墙离开。锁盒的铁栓垂在原处。"
					outcome_text_en = "The cellar workers escaped along the wall. The lock box bolt hangs where it was."
			return [{"img": manor_img, "focus": Vector2(0.52, 0.5), "zh": outcome_text_zh, "en": outcome_text_en}]
		"archive_copy":
			return [{
				"img": CG + "cg_archive_0420_dispatch_copy.jpg", "focus": Vector2(0.56, 0.53),
				"zh": "你从档案馆带回 0420 号退件底单。纸上没有销账章；第三节车厢仍是一件没有结案的事。",
				"en": "You bring back the returned dispatch copy for File 0420. It has no closure stamp; Boxcar Three remains an unfinished case.",
			}]
		"station_route":
			return [
				{"img": CG + "cg_station_handover_desk_solo.jpg", "focus": Vector2(0.52, 0.54),
					"zh": "检修柜里的底单没有销账章。车里的人还不能被账本判死。",
					"en": "The copy in the maintenance locker carries no closure stamp. The ledger cannot declare the people aboard dead."},
				{"img": CG + "cg_station_handover_desk_solo.jpg", "focus": Vector2(0.52, 0.54), "zoom": Vector2(1.08, 1.14),
					"zh": "底单与西站发车令对上了。你把通往鹰嘴崖的检修线记在地图上。",
					"en": "The copy matches the West Yard dispatch order. You mark the maintenance route to Eagle's Crag on the map."},
			]
		"eagle_escape":
			var pages: Array = [{
				"img": CG + "cg_boxcar03_survivors_reveal_v1.png", "focus": Vector2(0.74, 0.42),
				"zh": "车门外，拉娜攥着你的袖口。她没有松开手；你也没有问她认没认出你。",
				"en": "Outside the car, Lana grips your sleeve. She does not let go, and you do not ask whether she recognized you.",
			}]
			var rescue_scope := String(context.get("crag_rescue_scope", ""))
			if rescue_scope == "lana":
				pages.append({
					"img": CG + "cg_crag_lana_only_looks_back.jpg", "focus": Vector2(0.56, 0.48),
					"zh": "你只带拉娜和底单撤离。她停步回望雪坡下的车门；检修路上只有兄妹两行脚印。",
					"en": "You leave with Lana and the copy alone. She pauses to look back toward the boxcar; only the siblings' footprints mark the service path.",
				})
			elif rescue_scope == "all":
				pages.append({
					"img": CG + "cg_eaglecliff_derailment_scene.jpg", "focus": Vector2(0.63, 0.52),
					"zh": "能走的幸存者分批沿检修线离开。身后的车厢还在风里晃，崖顶的灯光没有停。",
					"en": "The survivors who can walk leave in groups along the service line. The car still rocks in the wind; the ridge light keeps moving.",
				})
			else:
				pages[0]["zh"] = "拉娜跟着你走上检修道，身后的车门还在风里响。"
				pages[0]["en"] = "Lana follows you up the service path. Behind you, the car door rattles in the wind."
			return pages
		"evidence_handover":
			return [{
				"img": CG + "cg_room602_evidence_handover_table.jpg", "focus": Vector2(0.52, 0.52),
				"zh": "你把发车令、未销账的交接底单和焚化台账照片摊在 602 室的桌上。三份证据终于指向同一条路：让全城听见。",
				"en": "You lay the dispatch order, unclosed handover copy, and furnace-ledger photograph on the Room 602 table. The three pieces of evidence point toward one next step: let the whole city hear.",
			}]
		"broadcast_complete":
			var mate_id := String(context.get("broadcast_mate", ""))
			var names_aired := bool(context.get("broadcast_names_aired", false))
			var operator_img := CG + "cg_tower302_aleksei_at_transmitter.jpg"
			var operator_zh := "阿列克谢独自守在话筒前，把证词和照片送进发射机。"
			var operator_en := "Aleksei holds the microphone alone and feeds the testimony and photographs into the transmitter."
			if mate_id == "yelena":
				operator_img = CG + "cg_broadcast_scene_alt_yelena.jpg"
				operator_zh = "叶莲娜守住频率，发射机没有在播报中断线。"
				operator_en = "Yelena holds the frequency steady; the transmitter does not drop the broadcast."
			elif mate_id == "pavel":
				operator_img = CG + "cg_tower302_pavel_aleksei_switch_repair.jpg"
				operator_zh = "帕维尔撑住开关，阿列克谢对着话筒把证词送上频率。"
				operator_en = "Pavel holds the switch while Aleksei sends the testimony over the air."
			if names_aired:
				return [
					{"img": operator_img, "focus": Vector2(0.5, 0.5),
						"zh": operator_zh + " 你选择把幸存者的名字一并念出。",
						"en": operator_en + " You choose to read the survivors' names as well."},
					{"img": CG + "cg_broadcast_city_listeners_dawn_alt.jpg", "focus": Vector2(0.5, 0.56),
						"zh": "城市各处的收音机都传出了姓名。有人把听到的第一个名字写在窗边。",
						"en": "Radios across the city carry the names. Someone writes down the first one by a frosted window."},
				]
			return [
				{"img": operator_img, "focus": Vector2(0.5, 0.5),
					"zh": operator_zh + " 你把个人姓名留在了名单上，只播档案编号与罪证。",
					"en": operator_en + " You keep the personal names off the air and transmit only file numbers and evidence."},
				{"img": CG + "cg_tower302_listener_numbers_only.jpg", "focus": Vector2(0.48, 0.52),
					"zh": "听众知道罪证已经播出，却没有听到可以写下的姓名。铅笔停在空白纸上。",
					"en": "Listeners hear that the evidence is out, but no names to write down. The pencil pauses over the blank page."},
			]
		"market_refuge":
			return [
				{"img": "res://art/40_interiors/BG_Market_Hideout.png", "focus": Vector2(0.5, 0.55),
					"zh": "电台里传来一串断续的调度呼号。阿列克谢把频率抄进工作日志，随后关掉发射机——这间废信号室只供暂住一夜。",
					"en": "A broken dispatch call sign crackles over the radio. Aleksei copies the frequency into his logbook, then switches the set off. The abandoned signal room is only a one-night refuge."},
				{"img": "res://art/40_interiors/BG_Market_Hideout.png", "focus": Vector2(0.58, 0.46), "zoom": Vector2(1.08, 1.16),
					"zh": "炉子没有烧起来，门外仍有巡逻声。天亮后，阿列克谢会回 602 整理母亲留下的东西，再继续追查拉娜的下落。",
					"en": "The stove stays cold, and patrols still pass outside. At dawn Aleksei will return to Room 602 for what Mother left behind, then continue searching for Lana."},
			]
		"zakhar_betrayed":
			return [{
				"img": CG + "cg_zakhar_quota_betrayal_alt.jpg", "focus": Vector2(0.53, 0.5),
				"zh": "扎哈尔不再跟在你身后。岗亭的检查灯还亮着，日志没有记下他后来去了哪边。",
				"en": "Zakhar no longer walks behind you. The checkpoint lamp is still on, and the log does not say which way he went.",
			}]
		"mother_lost":
			return [{
				"img": CG + "cg_room602_empty_bed_folded_scarf.jpg", "focus": Vector2(0.53, 0.53),
				"zh": "你回到 602 室时，床已经空了。围巾叠在床沿，停下来的透析机没有留下回声。",
				"en": "When you return to Room 602, the bed is empty. The scarf rests at its edge; the stopped dialysis machine leaves no echo.",
			}]
	return []


## A deep copy keeps UI playback from mutating the source dialogue table.
static func room_dialogue(dialogue_id: String) -> Array:
	if not ROOM_DIALOGUE.has(dialogue_id):
		return []
	return (ROOM_DIALOGUE[dialogue_id] as Array).duplicate(true)
