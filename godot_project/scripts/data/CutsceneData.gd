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
		"img": CG + "cg_ending_closed_car_firelight_alt.jpg",
		"focus": Vector2(0.69, 0.54),
		"zh": "阿列克谢决定停止追查，回到 602 室陪母亲。",
		"en": "Aleksei ends his search and returns to Room 602 to stay with Mother.",
		"aftermath": [
			{"img": CG + "cg_aftermath_a_602.jpg", "focus": Vector2(0.52, 0.56),
				"zh": "夜深时，阿列克谢仍坐在母亲床边。窗外雪压住封存车厢的方向，屋里的灯没有熄。",
				"en": "Well past midnight, Aleksei remains at his mother's bedside. Snow closes the view toward the sealed car, but the room's lamp stays lit."},
		],
	},
	"ENDING_B_FLAWED_LIBERATION": {
		"img": CG + "cg_ending_broadcast_breach_302_alt.jpg",
		"focus": Vector2(0.46, 0.52),
		"zh": "第三节车门被打开，幸存者冲向 302 高地。拉娜活了下来，却没能认出留下满页划痕的哥哥。",
		"en": "Boxcar Three opens and the survivors press toward Hill 302. Lana lives, but cannot recognize the brother marked by his strokes.",
		"aftermath": [
			{"img": CG + "cg_aftermath_b_release.jpg", "focus": Vector2(0.62, 0.52),
				"zh": "302 高地的破晓里，获释者继续向前。拉娜望向人群，没认出站在身旁的阿列克谢；他没有追问。",
				"en": "At dawn on Hill 302, the freed survivors keep moving. Lana looks through the crowd, unable to recognize Aleksei beside her; he does not press her."},
		],
	},
	"ENDING_C_NUMBNESS": {
		"img": CG + "cg_ending_crawl_back_cellar_alt.jpg",
		"focus": Vector2(0.28, 0.55),
		"zh": "他独自从排污涵洞爬回空地窖。雪盖住名字，也盖住了最后一点反抗。",
		"en": "He crawls alone from the drain into an empty cellar. Snow covers the names and the last trace of resistance.",
		"aftermath": [
			{"img": CG + "cg_aftermath_c_numb.jpg", "focus": Vector2(0.56, 0.52),
				"zh": "地窖里只剩滴水声和一盏空灯。阿列克谢没有点炉火，也没有再翻那本名单。",
				"en": "Only dripping water and a bare bulb fill the cellar. Aleksei does not light the stove or open the list again."},
		],
	},
	"TRUE_ALPHA_HELLO_LANA": {
		"img": CG + "cg_ending_true_alpha_hello_lana.jpg",
		"focus": Vector2(0.47, 0.5),
		"zh": "拉娜回到了 602。母亲还在床边等他们，三个人终于重新站在同一盏灯下。",
		"en": "Lana returns to Room 602. Mother is waiting beside the bed, and all three are together beneath the same lamp again.",
		"aftermath": [
			{"img": CG + "cg_aftermath_true_alpha.jpg", "focus": Vector2(0.58, 0.54),
				"zh": "晨光照进 602 室。拉娜替母亲捧起热水，阿列克谢守在窗边；三个人暂时不必再分开。",
				"en": "Morning reaches Room 602. Lana lifts a warm cup to their mother while Aleksei keeps watch at the window; for now, the three need not be apart."},
		],
	},
	"TRUE_BETA_OUTLAND_FIRE": {
		"img": CG + "cg_ending_true_beta_outland_fire.jpg",
		"focus": Vector2(0.35, 0.5),
		"zh": "真相和拉娜都带出了城，母亲却没能等到他们。荒原的火烧过漫长一夜。",
		"en": "The truth and Lana make it out of the city, but Mother does not live to see them. The outland fire burns through the long night.",
		"aftermath": [
			{"img": CG + "cg_aftermath_true_beta.jpg", "focus": Vector2(0.36, 0.5),
				"zh": "城外铁轨消失在雪原。拉娜与阿列克谢带着档案继续向前，远处的火光留在身后，母亲没有走出那座城。",
				"en": "Beyond the city, the tracks vanish into the snow. Lana and Aleksei carry the records onward while the last firelight fades behind them; their mother never left the city."},
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
		{"img": CG + "cg_canteen_scene.jpg", "focus": Vector2(0.3, 0.5),
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
static func scene_image(story_id: String) -> String:
	if story_id == "market_refuge":
		return "res://art/40_interiors/BG_Market_Hideout.png"
	var story_cg := {
		"broadcast": "cg_broadcast_scene_alt_yelena.jpg",
		"pasha_watchtower": "cg_pasha_watchtower_scene.jpg",
		"apartment_exchange": "cg_apartment_exchange_scene.jpg",
		"mine_sporeface": "cg_mine_sporeface_scene_alt.jpg",
		"mine_detonator": "cg_mine_detonator_scene.jpg",
		"fire_rescue": "cg_fire_rescue_scene_alt.jpg",
		"eaglecliff_derailment": "cg_eaglecliff_derailment_scene.jpg",
		"station_buran": "cg_station_buran_scene.jpg",
		"broadcast_siege": "cg_broadcast_siege_scene.jpg",
		"broadcast_testimony": "cg_broadcast_testimony_scene.jpg",
	}
	if story_cg.has(story_id):
		return CG + String(story_cg[story_id])
	return CG + "cg_%s_scene.jpg" % story_id


## 结局主图（与 CampaignSim.ending_key() 的五个键一一对应）。
static func ending_scene(ending_key: String) -> String:
	var entry: Dictionary = ENDING_SCENES.get(ending_key, {})
	return String(entry.get("img", ""))


## 结局后的插画页。无余波的结局返回空数组。
static func ending_aftermath(ending_key: String) -> Array:
	var entry: Dictionary = ENDING_SCENES.get(ending_key, {})
	return (entry.get("aftermath", []) as Array).duplicate(true)


## 用于“回看结局与余波”按钮的完整幻灯顺序。
static func ending_slides(ending_key: String, mother_alive := false) -> Array:
	var entry: Dictionary = ENDING_SCENES.get(ending_key, {})
	if entry.is_empty():
		return []
	var slides: Array = [{
		"img": String(entry["img"]), "focus": entry.get("focus", Vector2(0.5, 0.5)),
		"zh": String(entry.get("zh", "")), "en": String(entry.get("en", "")),
	}]
	slides.append_array(ending_aftermath(ending_key))
	if ending_key == "TRUE_BETA_OUTLAND_FIRE" and mother_alive:
		slides[0]["zh"] = "母亲还活着。真相已经传开，出卖他们的人也把消息送到了清杀队。"
		slides[0]["en"] = "Mother is alive. The truth is out, and someone has passed word to the OSK."
		slides[1]["zh"] = "城外火光下，拉娜和阿列克谢分着守夜。他们等天亮，再找路回去。"
		slides[1]["en"] = "Outside the city, Lana and Aleksei take turns watching the fire. At dawn they will look for a way back."
	return slides


## 抉择余波的幻灯页（深拷贝）。没配的抉择返回空数组 = 不播。
static func aftermath(story_id: String, choice_index: int) -> Array:
	var key := "%s:%d" % [story_id, choice_index]
	if not AFTERMATH.has(key):
		return []
	var out: Array = (AFTERMATH[key] as Array).duplicate(true)
	return out


## A deep copy keeps UI playback from mutating the source dialogue table.
static func room_dialogue(dialogue_id: String) -> Array:
	if not ROOM_DIALOGUE.has(dialogue_id):
		return []
	return (ROOM_DIALOGUE[dialogue_id] as Array).duplicate(true)
