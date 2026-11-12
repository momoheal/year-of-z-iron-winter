extends RefCounted
## NightMonuments.gd — 旧时代的纪念物：列宁像、马克思胸像、破红旗、积雪红星、墙上的宣传画……
##
## 做什么：
##   · 关卡加载时按 PLACES 表把纪念物摆进 World/Props（参与 y 排序、挡人、挡视线，可以当掩体）。
##     必须在 NightExplore._build_nav() 之前 spawn，寻路网格才会把它们算进去。
##   · 给场景里原有的旧物（告示栏、岗楼、铁笼、闷罐车厢……见 PROPS）也配上话，不新摆东西。
##   · 玩家第一次走近时：左下角弹出对白框 —— 先是阿列克谢的一句心里话，带了伙伴的话
##     伙伴接一句（灰烬是动作）。每句台词自带表情（平静 / 激愤 / 黯然 / 冷嘲），头像跟着换。
##     不暂停、不吃输入；同一句在一局里只说一遍。
##
## 为什么是运行时摆而不是写进 .tscn：十四张图由 tools/art_gen/build_scene.py 生成，
## 手改会在下次重建时被冲掉；这里一张表就能增删改，贴图缺了（还没导入）就安静跳过。
##
## 坐标是关卡米制（x 东 / y 南），和 LevelBeats 的 landmarks 同一套。落点是用脚本在各场景的
## 碰撞体上筛出来的：整块落脚处加 1 米净空都可走、不堵任何通路、离出生点 / 撤离点 / 容器 /
## 敌人 / 巡逻线 / 铁轨都有距离。要挪位置请保持这些条件。

const DIR := "res://art/30_props/"
const PPM := 64.0
const SQ := 0.62
const NEAR_M := 3.4            # 走到多近开口
const COL_TITLE := Color("c8a257")
const COL_SELF := Color("d8d1bf")
const COL_MATE := Color("fde68a")

## size：挡人的占地（米，宽 × 进深）。layer：1 = 墙（挡视线挡子弹），2 = 低矮掩体。
## lines：self = 阿列克谢；其余按伙伴 id。每句是 [表情, 台词]，表情见 MOOD_ZH。没写的伙伴就不接话。
const KINDS := {
	"lenin": {
		"tex": "PRP_Statue_Lenin.png", "zh": "列宁立像", "size": Vector2(1.5, 0.8), "layer": 1,
		"lines": {
			"self": ["wry", "他的手还指着前面。前面是铁丝网、探照灯，和一列不往回开的车。"],
			"ash": ["calm", "灰烬绕着底座嗅了一圈，抬起后腿，在花岗岩上留了个记号。"],
			"anna": ["sad", "「课本上说他最爱孩子。可给我们编号的人，办公室里挂的都是他。」"],
			"gulya": ["wry", "「一座像用掉的铜，够全城的诊所换一遍针头。他们选了铜。」"],
			"pavel": ["wry", "「这底座是我们车间焊的。验收那天人人有奖状，没人有煤。」"],
			"ivan": ["sad", "「我向他敬过四十年礼。他一次也没替哪个扳道工挡过风。」"],
		},
	},
	"toppled": {
		"tex": "PRP_Statue_Lenin_Toppled.png", "zh": "倒下的列宁像", "size": Vector2(4.6, 1.0), "layer": 2,
		"lines": {
			"self": ["sad", "只剩一双靴子还站在底座上。推倒他的人，后来也没活得更好。"],
			"ash": ["calm", "灰烬跳上铜像的后背，居高临下地望了望风，又跳下来。"],
			"anna": ["wry", "「倒了也好。躺着的时候，他总算跟我们一样高了。」"],
			"gulya": ["sad", "「推倒一座像只要一根钢缆。可治好跪了一辈子的膝盖，没有药。」"],
			"pavel": ["wry", "「立的时候叫我们鼓掌，倒的时候也叫我们鼓掌。巴掌都是同一双。」"],
			"ivan": ["sad", "「我看着它立起来，又看着它倒下去。两回都有人说：从此就好了。」"],
		},
	},
	"head": {
		"tex": "PRP_Lenin_Head.png", "zh": "铜像的头", "size": Vector2(2.8, 1.0), "layer": 2,
		"lines": {
			"self": ["wry", "眼窝里积着雪。原来他看了我们这么多年，里面是空的。"],
			"ash": ["intense", "灰烬对着那只空眼窝低吼了一声，没等到回答。"],
			"anna": ["calm", "「好大的头。里面一定装过很多别人的日子。」"],
			"gulya": ["wry", "「我解剖过很多脑袋。只有这一颗，从来不用为自己的主意负责。」"],
			"pavel": ["intense", "「空心的。当年报的是实心的料 —— 差的那几吨铜，喂肥了谁？」"],
			"ivan": ["wry", "「身子早拉去化了炮弹壳。头没人敢动，就这么搁着，搁到没人怕。」"],
		},
	},
	"marx": {
		"tex": "PRP_Bust_Marx_Ruined.png", "zh": "残破的马克思胸像", "size": Vector2(1.6, 0.8), "layer": 1,
		"lines": {
			"self": ["sad", "他写过，人不该被当成物。在这里，我们连物都不是，是账上的数字。"],
			"ash": ["calm", "灰烬舔了舔胸像胡子上的冰碴，嫌没味道，打了个喷嚏。"],
			"anna": ["calm", "「这个大胡子是谁？……算了。反正不是来救我们的。」"],
			"gulya": ["intense", "「书我读过。书里没写要把病人关进笼子 —— 那是读书的人自己添的。」"],
			"pavel": ["wry", "「他说工人没有祖国。说对了一半：我们有祖国，是祖国没有我们。」"],
			"ivan": ["wry", "「一个没摸过扳手的德国人，替全世界的工人想好了一辈子。」"],
		},
	},
	"flag": {
		# 飘动：8 帧横排图集（单帧 214×436，旗杆在帧内 x=56）；图集没导入时退回静态图
		"tex": "PRP_Flag_Soviet_Tattered.png", "sheet": "PRP_Flag_Soviet_Tattered_Sheet.png", "frames": 8,
		"pivot_x": 56.0,
		"zh": "破败的红旗", "size": Vector2(0.5, 0.4), "layer": 2,
		"lines": {
			"self": ["wry", "旗子烂成了布条，旗杆还是每年有人刷漆。刷漆的拨款，账上年年走得通。"],
			"ash": ["intense", "灰烬盯着哗啦作响的布条，耳朵压平，绕开了它的影子。"],
			"anna": ["sad", "「红得跟他们盖在我手背上的章一个颜色。」"],
			"gulya": ["intense", "「这么大一块布，够裁四十条绷带。它在上面飘了三十年，一条也没裁。」"],
			"pavel": ["wry", "「镰刀和锤子。拿镰刀的饿死了，拿锤子的在这儿 —— 你看看我。」"],
			"ivan": ["sad", "「升旗要脱帽。降旗那天没人通知，它是自己一条一条烂下来的。」"],
		},
	},
	"star": {
		"tex": "PRP_RedStar_Snowy.png", "zh": "积雪的红星", "size": Vector2(3.2, 1.0), "layer": 1,
		"lines": {
			"self": ["sad", "长明火早灭了。气是先停的这里，然后才轮到居民楼。"],
			"ash": ["sad", "灰烬把鼻子探进熄灭的火盆，只嗅到铁锈和陈年的雪。"],
			"anna": ["calm", "「星星应该在天上。钉在水泥上的那个，只是个铁皮。」"],
			"gulya": ["wry", "「纪念死人的火，烧的是活人的煤气。现在两样都没了，倒也公平。」"],
			"pavel": ["wry", "「铁皮是我敲的。五个角，上头说一个都不能歪。日子歪成什么样没人管。」"],
			"ivan": ["sad", "「我儿子的名字本该刻在这下面。他们说名额满了。」"],
		},
	},
	"stele": {
		"tex": "PRP_Stele_HammerSickle.png", "zh": "镰锤界碑", "size": Vector2(2.0, 0.7), "layer": 1,
		"lines": {
			"self": ["wry", "徽章只剩一颗螺栓挂着。城门口的东西都这样：往里是荣誉，往外是封锁线。"],
			"ash": ["intense", "灰烬仰头看那块晃悠的铁徽，往后退了两步 —— 它信不过头顶的东西。"],
			"anna": ["wry", "「进城的人看见它，会以为这里面有人管事。」"],
			"gulya": ["sad", "「麦穗围了一圈。城里上一次见到真麦子，是在配给证取消以前。」"],
			"pavel": ["intense", "「一颗螺栓吊着几十斤铁。偷工的人早升走了，砸下来砸的是过路的。」"],
			"ivan": ["sad", "「每趟车进站我都从它底下过。它欢迎过所有人，没送走过一个。」"],
		},
	},
	"mosaic": {
		"tex": "PRP_Mosaic_Wall.png", "zh": "剥落的马赛克墙", "size": Vector2(5.0, 0.5), "layer": 1,
		"lines": {
			"self": ["sad", "工人的脸掉了一半瓷片。画上的人都仰着头 —— 画外的人，早学会了低头走路。"],
			"ash": ["sad", "灰烬扒拉了一下地上的碎瓷片，被划了爪子，委屈地甩了甩。"],
			"anna": ["sad", "「他们笑得真好看。我没见过哪个真的工人这样笑。」"],
			"gulya": ["intense", "「画里人人胳膊粗壮。我门诊里的工人，三十岁就咳出黑痰。」"],
			"pavel": ["sad", "「画的是我们。可没人来问过我们：想被画成什么样，想过成什么样。」"],
			"ivan": ["wry", "「太阳画得那么大。这地方一年有五个月，天是不亮的。」"],
		},
	},
	"pioneer": {
		"tex": "PRP_Statue_Pioneer.png", "zh": "断臂的少先队员像", "size": Vector2(1.1, 0.7), "layer": 2,
		"lines": {
			"self": ["wry", "吹号的那只手断了，露着钢筋。「时刻准备着」—— 准备着什么，从没人说清。"],
			"ash": ["sad", "灰烬闻了闻石膏孩子的鞋，轻轻呜了一声，像是认错了人。"],
			"anna": ["sad", "「我也戴过那条红领巾。他们教我们举手敬礼，没教我们怎么说不。」"],
			"gulya": ["intense", "「石膏的孩子有人年年刷白。真的孩子发烧，药房说要等指标。」"],
			"pavel": ["sad", "「我孙子照着它站过队。号声一响，孩子们就学会了别掉队、别多问。」"],
			"ivan": ["sad", "「夏令营的专列是我开的。一车一车的孩子，唱着歌，去学怎么听话。」"],
		},
	},
	"honor": {
		"tex": "PRP_HonorBoard.png", "zh": "空了的光荣榜", "size": Vector2(3.8, 0.5), "layer": 1,
		"lines": {
			"self": ["sad", "相框大半空了。被摘下来的人不叫落选，叫「从未存在」—— 这种账，我也改过。"],
			"ash": ["intense", "灰烬对着晃荡的空相框歪了歪头，那东西吱呀一声，它立刻龇牙。"],
			"anna": ["sad", "「上了榜的有照片。我们这样的，只有编号。」"],
			"gulya": ["intense", "「超额完成的人挂在这儿。累垮的那些，挂在我的病历柜里。」"],
			"pavel": ["wry", "「我上过榜，第二排左三。奖品是一条毛巾，和下个月翻倍的定额。」"],
			"ivan": ["wry", "「先进工作者。先进到最后，连名字都被人从框里抠走了。」"],
		},
	},
}

## 墙上的宣传画：贴在北侧外立面上，不挡人。lines 的写法同上。
const POSTERS := {
	"worker": {
		"tex": "PRP_Poster_Worker.png", "zh": "宣传画 ·《劳动光荣》",
		"lines": {
			"self": ["wry", "画上的锤子永远举着，永远不落下来。落下来的那些，砸的是定额和工伤表。"],
			"ash": ["intense", "灰烬对着画里高举的锤子缩了缩脖子，贴着你的腿绕了过去。"],
			"anna": ["wry", "「他的胳膊比我的腰还粗。画他的人，一定没见过发配给证那天的队伍。」"],
			"gulya": ["intense", "「光荣的劳动我见过：矽肺、冻疮、断指。没有一样上得了画。」"],
			"pavel": ["wry", "「画里干活不出汗。我干了四十年，汗都出给了别人的奖章。」"],
			"ivan": ["wry", "「劳动光荣。那不劳动的那些人，怎么反倒坐在主席台上？」"],
		},
	},
	"harvest": {
		"tex": "PRP_Poster_Harvest.png", "zh": "宣传画 ·《丰收》",
		"lines": {
			"self": ["wry", "麦子画得比人还高。那几年的统计表我见过 —— 产量是先画好，再去地里凑的。"],
			"ash": ["sad", "灰烬凑近闻了闻画上的麦穗，只有浆糊和霉味，失望地打了个响鼻。"],
			"anna": ["sad", "「她抱着那么多麦子，笑得那么开心。那些麦子后来都去哪儿了？」"],
			"gulya": ["intense", "「丰收那年，我的病房里收的是浮肿病人。粮食在画上，不在锅里。」"],
			"pavel": ["sad", "「我娘就是抱着这样一捆麦子被带走的。那叫『偷窃集体财产』。」"],
			"ivan": ["sad", "「粮车是我拉的。一列一列往外运，站台上的人就那么看着。」"],
		},
	},
	"cosmos": {
		"tex": "PRP_Poster_Cosmos.png", "zh": "宣传画 ·《飞向群星》",
		"lines": {
			"self": ["sad", "他们把人送上了天。可从这里到城外四公里，三十年了，没有一个人走得出去。"],
			"ash": ["calm", "灰烬仰头看了看画上的星星，又看了看真的天 —— 天上只有探照灯。"],
			"anna": ["sad", "「小时候我也想当宇航员。后来才知道，我们连出这道铁丝网都要批条。」"],
			"gulya": ["wry", "「造得出火箭的国家，造不出够用的青霉素。不是不能，是没排上。」"],
			"pavel": ["wry", "「火箭上有我们厂的零件。上了天的是它，留在地上挨冻的是我们。」"],
			"ivan": ["sad", "「飞向群星。我这辈子只求一件事：有一趟车，能让我自己选在哪站下。」"],
		},
	},
	"silence": {
		"tex": "PRP_Poster_Silence.png", "zh": "宣传画 ·《不要多嘴》",
		"lines": {
			"self": ["wry", "只有这一张，他们是当真的。别的口号都落了空，唯独「闭嘴」，人人都学会了。"],
			"ash": ["intense", "灰烬盯着画里那根竖起的手指，喉咙里的低吼自己咽了回去。"],
			"anna": ["sad", "「在疗养院，她们也这样对我比手指。然后门就锁上了。」"],
			"gulya": ["sad", "「我签过保密书：不许说病人怎么死的。这张画，就贴在我签字的那面墙上。」"],
			"pavel": ["intense", "「隔墙有耳。我们车间少了三个人，都是因为在澡堂里多说了一句。」"],
			"ivan": ["sad", "「一辈子没多嘴。到头来才明白，不说话的人，账也一样记在他头上。」"],
		},
	},
	"rail": {
		"tex": "PRP_Poster_Rail.png", "zh": "宣传画 ·《钢铁动脉》",
		"lines": {
			"self": ["intense", "画上的车头朝着人冲过来，那是当年的好意。现在的「暴风雪」号也这么冲，只是不再画下来。"],
			"ash": ["intense", "灰烬听见远处真的汽笛，再看看画，毛竖了起来。"],
			"anna": ["sad", "「我就是被这样一列车运来的。车皮上没有红星，只有粉笔写的数。」"],
			"gulya": ["wry", "「铁路把药运走，把病人运来。动脉是通的，血往哪边流，不由我们说。」"],
			"pavel": ["wry", "「道钉是我们打的。车通了以后，坐车的从来不是打道钉的人。」"],
			"ivan": ["sad", "「这画上的人是照着我师傅画的。他后来冻死在道岔上，抚恤是半袋土豆。」"],
		},
	},
	"leader": {
		"tex": "PRP_Poster_Leader.png", "zh": "宣传画 ·《领袖与人民》",
		"lines": {
			"self": ["wry", "他占了大半张纸，人民挤在最底下一指宽的地方，没有脸。比例是对的。"],
			"ash": ["wry", "灰烬对着画上那张巨大的侧脸看了一会儿，转过身，用后腿刨了两下雪。"],
			"anna": ["sad", "「下面那些小人儿，哪一个是我们？……看不出来。他们本来就不打算让人看出来。」"],
			"gulya": ["intense", "「人不该比别人大这么多。大到这个地步，底下的人病了死了，他是看不见的。」"],
			"pavel": ["sad", "「他往哪儿看，我们就得往哪儿走。可他是侧着脸的，从来不看我们。」"],
			"ivan": ["sad", "「我年轻时真信过。信到把儿子的名字也照着他起了。」"],
		},
	},
}

## 关卡 id → [[宣传画种类, x 像素（沿北墙）], …]。位置对着各外立面贴图挑的：避开门窗、
## 墙上的旧标语，以及靠墙摆着的道具。
const WALLS := {
	"yard": [["leader", 768], ["cosmos", 2112], ["harvest", 2496]],
	"birch": [["worker", 1152], ["silence", 2496]],
	"coldstore": [["harvest", 496], ["worker", 1280], ["silence", 2396]],
	"boiler": [["worker", 496], ["leader", 2316]],
	"canteen": [["harvest", 520], ["worker", 2192], ["leader", 2496]],
	"workshop": [["worker", 520], ["cosmos", 2192], ["silence", 2496]],
	"marshalling": [["rail", 696], ["silence", 1812], ["leader", 2114]],
	"manor": [["leader", 312], ["silence", 1490]],
	"mine": [["worker", 308], ["cosmos", 1410], ["rail", 1714]],
	"sanitarium": [["silence", 372], ["harvest", 1324], ["cosmos", 2292]],
	"underpass": [["rail", 732], ["leader", 2180]],
	"archive": [["silence", 372], ["leader", 1324], ["worker", 2292]],
	"market": [["rail", 1529], ["harvest", 2125], ["cosmos", 2589]],
	"greenhouse": [["harvest", 1665], ["worker", 2485]],
}
const WALL_Y := 119.04         # 外立面墙根的像素 y（场景里没有 World/Facade 时的兜底）
const POSTER_LIFT := 34.0      # 宣传画下沿离墙根多高（像素）
const FLAG_FPS := 9.0

## 关卡 id（场景根节点的 metadata/level_id）→ [[种类, x 米, y 米], …]
const PLACES := {
	"yard": [["lenin", 7.75, 9.25], ["flag", 16.75, 8.75]],
	"coldstore": [["stele", 8.75, 30.25], ["honor", 25.75, 5.25]],
	"canteen": [["mosaic", 7.75, 8.75], ["marx", 27.25, 29.25]],
	"market": [["head", 40.25, 19.25], ["star", 39.75, 8.75]],
	"sanitarium": [["pioneer", 26.75, 27.25], ["marx", 19.75, 21.25]],
	"manor": [["head", 8.75, 21.75], ["flag", 22.75, 31.25]],
	"marshalling": [["flag", 8.75, 7.75]],
	"mine": [["honor", 11.25, 26.25], ["lenin", 4.25, 20.25]],
	"boiler": [["marx", 4.25, 11.75]],
	"underpass": [["mosaic", 32.75, 27.25]],
	"workshop": [["honor", 8.75, 9.75]],
	"greenhouse": [["pioneer", 4.25, 11.25]],
	"archive": [["head", 22.25, 21.75], ["marx", 29.75, 27.25]],
	"birch": [["toppled", 11.75, 9.25], ["flag", 20.75, 8.75]],
}

## 场景里原本就有的旧物：不新摆东西，只给它们配上话。match 是贴图文件名里的一段。
const PROPS := {
	"board": {
		"match": "PRP_DispatchBoard_Tin", "zh": "告示栏",
		"lines": {
			"self": ["wry", "告示一张压一张，最底下那张还在祝大家新年快乐。上面的每一张，都在收回点什么。"],
			"ash": ["calm", "灰烬嗅了嗅告示上的红章，认得那个味道 —— 和清杀队手套上的一样。"],
			"anna": ["sad", "「我的名字上过这种栏。不是表扬，是『收治通知』。」"],
			"gulya": ["wry", "「字越大的通知越不用看。真要命的那几条，永远印在最小的那行。」"],
			"pavel": ["wry", "「以前贴的是定额，现在贴的是宵禁。纸换了，图钉还是那几颗。」"],
			"ivan": ["sad", "「晚点的车次贴在这儿，取消的车次也贴在这儿。只有不回来的那些，从来不贴。」"],
		},
	},
	"tower": {
		"match": "PRP_Watchtower_Searchlight", "zh": "岗楼",
		"lines": {
			"self": ["intense", "探照灯朝里照。修它的时候说是防外面的人 —— 灯从来没往外转过。"],
			"ash": ["intense", "灰烬压低身子，盯着光柱扫过的雪地，喉咙里滚着一声没放出来的吼。"],
			"anna": ["sad", "「上面的人看我们，像看格子里的数。可他下了岗，也要排队领同一种面包。」"],
			"gulya": ["wry", "「站得高的人不一定看得远。他只看得见灯照到的地方 —— 那正是他们要的。」"],
			"pavel": ["wry", "「这塔的角钢是我下的料。早知道是拿来看我的，我该把焊缝留松一点。」"],
			"ivan": ["sad", "「站岗的那孩子我认识，是车站锅炉工的小儿子。枪发给他那天，他哭了。」"],
		},
	},
	"dome": {
		"match": "PRP_Playground_Dome", "zh": "游乐穹顶",
		"lines": {
			"self": ["sad", "攀爬架漆成彩色的那年，院里还有孩子。后来孩子有了编号，架子就空了。"],
			"ash": ["sad", "灰烬钻进铁架底下转了一圈，叼出半只冻硬的手套，放在你脚边。"],
			"anna": ["sad", "「我在这上面摔断过一颗牙。那时候我以为，疼就是世界上最坏的事。」"],
			"gulya": ["sad", "「孩子最先发病。不是他们弱，是他们的口粮最先被『调剂』。」"],
			"pavel": ["calm", "「这种架子我给孙子焊过一个。他说爷爷焊的比院里的结实。就这一句，我记到现在。」"],
			"ivan": ["wry", "「地球仪的样子。让孩子们从小就爬在全世界上头 —— 结果谁也没出过这个院子。」"],
		},
	},
	"car": {
		"match": "PRP_Car_Moskvich_Wreck", "zh": "莫斯科人轿车",
		"lines": {
			"self": ["wry", "排了十一年队才轮到的车。到手那天，汽油开始凭票。"],
			"ash": ["calm", "灰烬跳上引擎盖，在积雪上踩出一串梅花印，神气地环顾四周。"],
			"anna": ["calm", "「我爸爸说，有了车就带我们去看海。车到了，路封了。」"],
			"gulya": ["wry", "「全楼就这一辆。救护车不来的那些夜里，人人都来敲他的门 —— 后来他索性把轮子卸了。」"],
			"pavel": ["wry", "「化油器是我修的，修了九回。这车一辈子跑的路，还没有它排队等的日子长。」"],
			"ivan": ["sad", "「人人都想要四个轮子。可这地方真正能把人带走的，从来只有铁轨。」"],
		},
	},
	"water": {
		"match": "PRP_WaterTower", "zh": "水塔",
		"lines": {
			"self": ["sad", "水塔还是满的。阀门归指挥部管 —— 渴不渴，是要批的。"],
			"ash": ["calm", "灰烬舔了舔塔根渗出来又冻住的冰，舔得很仔细。"],
			"anna": ["sad", "「疗养院的水是限时的。她们说是省水。其实是让我们记住：连水都是给的。」"],
			"gulya": ["intense", "「一半的痢疾，烧开水就能防。可煤是配给的，水也是。病不是天灾，是报表。」"],
			"pavel": ["wry", "「砖是沙皇时候砌的，到现在不漏。后来修的那截管子，三年换了四回。」"],
			"ivan": ["calm", "「蒸汽机车在这儿上过水。那时候车要喝饱了才肯走 —— 比现在的人有脾气。」"],
		},
	},
	"terminal": {
		"match": "PRP_CardTerminal", "zh": "配给终端",
		"lines": {
			"self": ["intense", "刷一下，机器就知道你这周还配不配活着。我管过它的后台：那只是一个可以改的数。"],
			"ash": ["intense", "终端「嘀」了一声，灰烬猛地后跳，对着那点绿光龇出牙。"],
			"anna": ["sad", "「我的卡三个月前就刷不出来了。机器没坏，是我被划掉了。」"],
			"gulya": ["intense", "「它连诊断都管。屏幕上跳红字，我就不许开药 —— 哪怕人就躺在我面前。」"],
			"pavel": ["wry", "「从前管我们的是人，还能骂两句、塞包烟。现在是个铁盒子，它不抽烟。」"],
			"ivan": ["wry", "「我检了四十年票。头一回见到，票反过来检人。」"],
		},
	},
	"table": {
		"match": "PRP_Canteen_BenchTable", "zh": "食堂长桌",
		"lines": {
			"self": ["sad", "长凳是连着桌子焊死的。吃饭的时候，谁也不能把座位往后挪一挪。"],
			"ash": ["calm", "灰烬把桌底嗅了个遍，舔到一点陈年的油星，尾巴摇了半下。"],
			"anna": ["calm", "「一桌坐十二个人，汤只打十份。大家都很有礼貌，谁也不说破。」"],
			"gulya": ["wry", "「办集体食堂，说是为了解放妇女。解放出来的妇女，被安排去了食堂。」"],
			"pavel": ["sad", "「我在这种桌上吃了半辈子。同桌的人换了一茬又一茬，没人问前一茬去了哪儿。」"],
			"ivan": ["wry", "「墙上写过『不劳动者不得食』。后来不写了 —— 劳动了，也不一定有。」"],
		},
	},
	"cage": {
		"match": "PRP_IronCage", "zh": "铁笼",
		"lines": {
			"self": ["intense", "笼子是按牲口的规格订的货。采购单上写的品名，是「隔离设施」。"],
			"ash": ["intense", "灰烬一步也不肯靠近，背毛全竖了起来，冲着铁栏低声呜咽。"],
			"anna": ["sad", "「我在里面数过栏杆。四十一根。数到后来，我开始觉得外面才是笼子。」"],
			"gulya": ["sad", "「他们叫它『保护性约束』。我在同意书上签过字。那是我这辈子最不该写的两个字。」"],
			"pavel": ["intense", "「这焊缝是熟手干的。有一个跟我一样的钳工，干完这个活，下班回家，照样亲了他的孩子。」"],
			"ivan": ["sad", "「运牲口的车皮装过人，装人的笼子原先装牲口。他们从来分不大清。」"],
		},
	},
	"brazier": {
		"match": "PRP_Brazier_OilDrum", "zh": "油桶火堆",
		"lines": {
			"self": ["calm", "没人管这堆火，它反倒一直烧着。这城里凡是有人负责的东西，都灭了。"],
			"ash": ["calm", "灰烬在火边趴下，眯起眼，头一回像一条普通的狗。"],
			"anna": ["calm", "「围着火的时候，没人问你的编号。」"],
			"gulya": ["calm", "「这是全城唯一不用处方的药。」"],
			"pavel": ["wry", "「烧的是光荣榜的木框。总算派上了用场。」"],
			"ivan": ["calm", "「道班的人从前就这么过夜。一只桶，一把煤，谁路过都能伸手。那才叫公有。」"],
		},
	},
	"boxcar": {
		"match": "PRP_Buran_Boxcar03", "zh": "闷罐车厢",
		"lines": {
			"self": ["sad", "车厢外面刷着载重：四十人，或八匹马。一个「或」字，就是他们的全部想法。"],
			"ash": ["sad", "灰烬把鼻子贴在车门缝上，久久不动，然后仰起头，长长地嗥了一声。"],
			"anna": ["sad", "「里面没有窗。我们靠车轮的声音猜走到了哪儿 —— 后来不猜了。」"],
			"gulya": ["intense", "「我被叫去做『随车医疗保障』。发给我的只有一沓死亡证明，名字那栏是空的。」"],
			"pavel": ["sad", "「门闩是从外面插的。造车的人知道。我们都知道。」"],
			"ivan": ["sad", "「我开了一辈子车，从不回头看拉的是什么。这是规矩。也是我的罪。」"],
		},
	},
}

## 说话人：头像文件名里的名字 + 对白框上显示的称呼
const PRT_DIR := "res://art/10_characters/portraits/"
const SPEAKERS := {
	"self": {"prt": "Aleksei", "zh": "阿列克谢"},
	"ash": {"prt": "Ash", "zh": "灰烬"},
	"anna": {"prt": "Anna", "zh": "安娜"},
	"gulya": {"prt": "Gulya", "zh": "古丽娅"},
	"pavel": {"prt": "Pavel", "zh": "帕维尔老爹"},
	"ivan": {"prt": "Ivan", "zh": "老轨伊万"},
}
## 表情：calm 平静 / intense 激愤 / sad 黯然 / wry 冷嘲。每句台词自带一个，头像跟着换。
const MOOD_ZH := {"calm": "平静", "intense": "激愤", "sad": "黯然", "wry": "冷嘲"}
const MEMORY_KEY := "iron_winter_relic_lines"

var ctl: Node = null
var items: Array[Dictionary] = []      # {kind, node, pos(px), reach(m), seen, id}
var seen: Array[String] = []           # 本夜触发过的条目 id（测试 / 调试用）
var said: Array[Dictionary] = []       # 本夜实际说出口的台词 {who, mood, text}（测试 / 调试用）
var _queue: Array[Dictionary] = []     # 排队等着说的台词 {who, mood, text, title}
var _say_t := 0.0                      # 当前这句还要显示多久
var _anim: Array[Dictionary] = []      # 会动的贴图 {spr, frames, phase}
var _clock := 0.0
var _panel: PanelContainer = null
var _portrait: TextureRect = null
var _speaker: Label = null
var _label: Label = null


static func info(kind: String) -> Dictionary:
	if KINDS.has(kind):
		return KINDS[kind]
	if POSTERS.has(kind):
		return POSTERS[kind]
	return PROPS.get(kind, {})


## 一句台词：{"mood": 表情, "text": 文本}；没有这句时返回空字典。
static func line_for(kind: String, who: String) -> Dictionary:
	var lines: Dictionary = info(kind).get("lines", {})
	var row: Array = lines.get(who, [])
	if row.size() < 2:
		return {}
	return {"mood": String(row[0]), "text": String(row[1])}


## 头像路径：PRT_<人>_<表情>.png；这个表情的图还没有（或没导入）就退回平静。
static func portrait_path(who: String, mood: String) -> String:
	var who_name := String(SPEAKERS.get(who, SPEAKERS["self"])["prt"])
	var p := PRT_DIR + "PRT_%s_%s.png" % [who_name, mood.capitalize()]
	if ResourceLoader.exists(p):
		return p
	return PRT_DIR + "PRT_%s_Calm.png" % who_name


## 这一局里已经说过的台词（种类:说话人）。同一句不说第二遍 —— 马克思胸像在四张图里都有，
## 每晚都重复就成了噪音。换个伙伴再来，伙伴的那句还是新的。
static func _memory() -> Dictionary:
	if not Engine.has_meta(MEMORY_KEY):
		Engine.set_meta(MEMORY_KEY, {})
	return Engine.get_meta(MEMORY_KEY)


static func forget_all() -> void:
	Engine.set_meta(MEMORY_KEY, {})


## 把这一关的纪念物摆进场景，并登记场景里原有的旧物。返回会开口的条目数。
func spawn(host: Node) -> int:
	ctl = host
	var parent := host.get_node_or_null("World/Props") as Node2D
	if parent == null:
		parent = host.get_node_or_null("World") as Node2D
	if parent == null:
		return 0
	_scan_props(parent)                 # 先登记场景原有的，再摆新的（新摆的不会被重复登记）
	var idx := 0
	for row in PLACES.get(String(host.level_id), []):
		var kind := String(row[0])
		var k: Dictionary = KINDS.get(kind, {})
		if k.is_empty():
			continue
		var frames := int(k.get("frames", 1))
		var path := DIR + String(k.get("sheet", ""))
		if frames <= 1 or not ResourceLoader.exists(path):
			frames = 1
			path = DIR + String(k.get("tex", ""))
		if not ResourceLoader.exists(path):
			continue
		var tex := load(path) as Texture2D
		if tex == null:
			continue
		var px := Vector2(float(row[1]) * PPM, float(row[2]) * PPM * SQ)
		var foot: Vector2 = k["size"]
		var foot_px := Vector2(foot.x * PPM, foot.y * PPM * SQ)
		var body := StaticBody2D.new()
		body.name = "Monument_%s_%d" % [kind, idx]
		body.position = px
		body.collision_layer = int(k.get("layer", 1))
		body.collision_mask = 0
		body.set_meta("monument", kind)
		var spr := Sprite2D.new()
		spr.name = "Sprite"
		spr.texture = tex
		spr.centered = false
		var ts := tex.get_size()
		if frames > 1:
			spr.hframes = frames
			ts.x /= float(frames)
			_anim.append({"spr": spr, "frames": frames, "phase": float(idx) * 2.7})
		var pivot_x := float(k.get("pivot_x", ts.x * 0.5))     # 没写就以贴图中线落地
		spr.offset = Vector2(-pivot_x, -ts.y + 8.0)             # 底边的雪堆压住脚下
		body.add_child(spr)
		var shape := RectangleShape2D.new()
		shape.size = foot_px
		var cs := CollisionShape2D.new()
		cs.name = "Shape"
		cs.shape = shape
		cs.position = Vector2(0, -foot_px.y * 0.5)
		body.add_child(cs)
		parent.add_child(body)
		items.append({"kind": kind, "node": body, "pos": px, "id": "%s@%d" % [kind, idx],
			"reach": NEAR_M + foot.x * 0.5, "seen": false})
		idx += 1
	_spawn_posters(host, parent)
	return items.size()


## 场景里原本就有的旧物（告示栏、岗楼、铁笼……）：按贴图名认，每种每关只认第一件。
func _scan_props(parent: Node2D) -> void:
	var found := {}
	for n in parent.get_children():
		if not (n is Node2D):
			continue
		var spr := n.get_node_or_null("Sprite") as Sprite2D
		if spr == null or spr.texture == null:
			continue
		var res := spr.texture.resource_path
		for kind in PROPS.keys():
			if found.has(kind) or not res.contains(String(PROPS[kind]["match"])):
				continue
			found[kind] = true
			var half_m := minf(spr.texture.get_size().x / PPM * 0.5, 2.5)
			items.append({"kind": kind, "node": n, "pos": (n as Node2D).global_position,
				"id": "prop_%s" % kind, "reach": NEAR_M - 0.6 + half_m, "seen": false})
			break


func _spawn_posters(host: Node, parent: Node2D) -> void:
	var wall_y := WALL_Y
	var facade := host.get_node_or_null("World/Facade") as Node2D
	if facade != null:
		wall_y = facade.position.y
	var idx := 0
	for row in WALLS.get(String(host.level_id), []):
		var kind := String(row[0])
		var k: Dictionary = POSTERS.get(kind, {})
		var path := DIR + String(k.get("tex", ""))
		if k.is_empty() or not ResourceLoader.exists(path):
			continue
		var tex := load(path) as Texture2D
		if tex == null:
			continue
		var spr := Sprite2D.new()
		spr.name = "Poster_%s_%d" % [kind, idx]
		spr.texture = tex
		spr.centered = false
		var ts := tex.get_size()
		spr.offset = Vector2(-ts.x * 0.5, -ts.y - POSTER_LIFT)
		spr.position = Vector2(float(row[1]), wall_y + 0.5)    # 比墙根靠前半个像素：排在墙面之上、其它东西之后
		spr.set_meta("poster", kind)
		parent.add_child(spr)
		items.append({"kind": kind, "node": spr, "pos": spr.position, "id": "poster_%s@%d" % [kind, idx],
			"reach": NEAR_M + 0.4, "seen": false})
		idx += 1


func update(delta: float) -> void:
	_clock += delta
	for a in _anim:
		var spr := a["spr"] as Sprite2D
		if is_instance_valid(spr):
			spr.frame = int(_clock * FLAG_FPS + float(a["phase"])) % int(a["frames"])
	if ctl == null or ctl.player == null:
		return
	_tick_dialogue(delta)
	var pp: Vector2 = ctl.player.global_position
	for it in items:
		if it["seen"]:
			continue
		var d: Vector2 = pp - (it["pos"] as Vector2)
		if Vector2(d.x / PPM, d.y / (PPM * SQ)).length() > float(it["reach"]):
			continue
		_remark(it)


func _remark(it: Dictionary) -> void:
	it["seen"] = true
	seen.append(String(it["id"]))
	var kind := String(it["kind"])
	var title := String(info(kind).get("zh", kind))
	var memory := _memory()
	var queued := 0
	var speakers: Array[String] = ["self"]
	if String(ctl.mate_id) != "":
		speakers.append(String(ctl.mate_id))
	for who in speakers:
		var line := line_for(kind, who)
		var key := kind + ":" + who
		if line.is_empty() or memory.has(key):
			continue
		memory[key] = true
		_queue.append({"who": who, "mood": line["mood"], "text": line["text"], "title": title})
		queued += 1
	if queued > 0:
		ctl.spawn_float(ctl.player.global_position + Vector2(0, -150), title, COL_TITLE)


# ---------------------------------------------------------------------------
# 对白框：左下角，头像表情跟着台词走；不暂停、不吃输入
# ---------------------------------------------------------------------------
func _tick_dialogue(delta: float) -> void:
	if _say_t > 0.0:
		_say_t -= delta
		if _say_t > 0.0:
			return
		if _panel != null:
			_panel.visible = false
	if _queue.is_empty():
		return
	_show(_queue.pop_front())


func _show(q: Dictionary) -> void:
	var who := String(q["who"])
	var mood := String(q["mood"])
	var text := String(q["text"])
	said.append({"who": who, "mood": mood, "text": text})
	_say_t = clampf(2.4 + text.length() * 0.085, 3.6, 7.5)
	_ensure_panel()
	if _panel == null:
		# 没有 HUD（极简测试场景）时退回头顶浮字
		ctl.spawn_float(ctl.player.global_position + Vector2(0, -126), text, COL_SELF if who == "self" else COL_MATE)
		return
	var sp: Dictionary = SPEAKERS.get(who, SPEAKERS["self"])
	var path := portrait_path(who, mood)
	_portrait.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_speaker.text = "%s · %s　｜　%s" % [String(sp["zh"]), String(MOOD_ZH.get(mood, "")), String(q["title"])]
	_label.text = text
	_label.add_theme_color_override("font_color", COL_SELF if who == "self" else COL_MATE)
	_panel.visible = true


func _ensure_panel() -> void:
	if _panel != null or ctl == null:
		return
	var root := ctl.get_node_or_null("HUD/Root") as Control
	if root == null:
		return
	_panel = PanelContainer.new()
	_panel.name = "RelicTalk"
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_panel.offset_left = 26
	_panel.offset_right = 650
	_panel.offset_top = -288
	_panel.offset_bottom = -102
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.04, 0.042, 0.94)
	sb.border_color = COL_TITLE
	sb.set_border_width_all(2)
	sb.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	root.add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(150, 150)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_portrait)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", 13)
	_speaker.add_theme_color_override("font_color", COL_TITLE)
	_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_speaker)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 17)
	_label.custom_minimum_size = Vector2(420, 0)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_label)
	if ctl.get("font") != null:
		_speaker.add_theme_font_override("font", ctl.font)
		_label.add_theme_font_override("font", ctl.font)
