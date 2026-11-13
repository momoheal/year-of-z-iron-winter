extends RefCounted
## CutsceneData.gd — 图片幻灯演出的数据表（由 scripts/ui/StorySlides.gd 播放）。
##
##   PROLOGUE   新开局的故事开场（世界观 → 母亲 → 签字 → 拉娜被带走 → 瞒下转运消息 → 封楼 → 通风口）
##   AFTERMATH  七段主线剧情每个抉择之后的「余波」：键 = "剧情 id:选项序号"
##   scene_image()  剧情对白框背后的场景插图
##
## 插图约定：res://art/60_ui/cg/cg_<剧情 id>_scene.jpg / cg_<剧情 id>_c<选项序号>.jpg。
## img 可以写成数组，按顺序取第一张存在的；一张都没有时退回 portrait 胸像。
## 所以以后往 cg/ 目录里补图，不用改代码就会自动换上。

const CG := "res://art/60_ui/cg/"
const PRT := "res://art/10_characters/portraits/"

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
	{"img": "res://art/60_ui/opening_courtyard.png", "focus": Vector2(0.62, 0.6), "actors": true,
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
			"zh": "那只灰狼犬在风雪里静静地看着你。你叫它「灰烬」。它踩着你的脚印，跟了上来。",
			"en": "The grey wolfdog watches you through the snow. You call him Ash. He steps into your footprints and follows."},
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
			"focus": Vector2(0.86, 0.32), "zoom": Vector2(1.12, 1.3),
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
			"focus": Vector2(0.84, 0.35), "zoom": Vector2(1.12, 1.3),
			"zh": "「老轨」伊万浑浊的眼底狠狠颤了一下。他没有再提废钢的事。",
			"en": "Something shakes loose behind Old Ivan's clouded eyes. He does not mention the scrap again."},
		{"img": [CG + "cg_market_c1c.jpg", CG + "cg_market_scene.jpg"], "portrait": PRT + "PRT_Ivan_Intense.png",
			"focus": Vector2(0.62, 0.45),
			"zh": "他把一只烤热了的厚帆布手套塞进你怀里，一言不发，跟上了你的脚步。",
			"en": "He shoves a warmed canvas glove against your chest and, without a word, falls in behind you."},
	],
	"market:2": [
		{"img": [CG + "cg_market_c2.jpg"], "portrait": PRT + "PRT_Ivan_Intense.png", "focus": Vector2(0.3, 0.5),
			"zh": "他替你引开了哨兵。\n而你，从外面落下了铁门的锁。",
			"en": "He drew the sentries off for you.\nAnd you dropped the bolt on the iron door from the outside."},
		{"img": [CG + "cg_market_c2b.jpg", CG + "cg_market_c2.jpg"], "portrait": PRT + "PRT_Ivan_Sad.png",
			"focus": Vector2(0.3, 0.85), "zoom": Vector2(1.14, 1.32),
			"zh": "门后先是一声难以置信的闷哼，紧接着是微声步枪的点射——短促得像踩碎了冰碴。",
			"en": "Behind the door: one grunt of disbelief, then a suppressed burst, as short as ice breaking underfoot."},
		{"img": [CG + "cg_market_c2c.jpg", CG + "cg_market_c2.jpg"], "portrait": PRT + "PRT_Aleksei_Sad.png",
			"focus": Vector2(0.72, 0.38), "zoom": Vector2(1.12, 1.28),
			"zh": "背包被抢来的物资撑得满满当当。\n《工作日志》的背面，多了一道洗不掉的划痕。",
			"en": "Your pack is stuffed with what you took.\nOn the back page of the logbook there is one more stroke that will not wash out."},
	],
	"sanitarium:0": [
		{"img": [CG + "cg_sanitarium_scene.jpg"], "portrait": PRT + "PRT_Anna_Sad.png", "focus": Vector2(0.72, 0.7),
			"zh": "撬棍崩开了生锈的笼锁。你替她解开嵌进肉里的皮带——\n那是她怕自己伤人，亲手勒上去的。",
			"en": "The crowbar breaks the rusted lock. You undo the straps sunk into her wrists.\nShe had tied them herself, afraid of what she might do."},
		{"img": [CG + "cg_sanitarium_c0b.jpg", CG + "cg_sanitarium_scene.jpg"], "portrait": PRT + "PRT_Anna_Intense.png",
			"focus": Vector2(0.8, 0.6), "zoom": Vector2(1.16, 1.34),
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
		{"img": CG + "cg_intro_lana.jpg", "focus": Vector2(0.42, 0.42), "zoom": Vector2(1.06, 1.22),
			"zh": "所有的数字终于严丝合缝地扣上了。\n一百七十六条退了烧的性命——其中一个，叫拉娜。",
			"en": "Every number finally locks into place.\nOne hundred seventy-six people whose fever has broken. One of them is called Lana."},
	],
}


## 剧情对白框背后的场景插图路径（文件可能还不存在，调用方用 StorySlides.tex_of 判空）。
static func scene_image(story_id: String) -> String:
	return CG + "cg_%s_scene.jpg" % story_id


## 抉择余波的幻灯页（深拷贝）。没配的抉择返回空数组 = 不播。
static func aftermath(story_id: String, choice_index: int) -> Array:
	var key := "%s:%d" % [story_id, choice_index]
	if not AFTERMATH.has(key):
		return []
	var out: Array = (AFTERMATH[key] as Array).duplicate(true)
	return out
