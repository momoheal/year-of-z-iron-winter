"""build_acceptance_page.py — 把 docs/ui/verify/ 里的验收图做成可以点开看的网页。

做两件事：
1. 生成网页用的缩图（JPEG，长边 1600，`docs/ui/verify/web/`），原 PNG 保持不动；
2. 生成两个页面：
   - `docs/ui/acceptance.html`：图片走相对路径，给静态服务器（8080 预览）用；
   - `docs/ui/acceptance_standalone.html`：图片内嵌成 base64，单文件，离线双击也能看。

用法（在仓库根目录或任意目录）：
    python3 godot_project/tools/art_gen/build_acceptance_page.py
"""
from __future__ import annotations

import base64
import io
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
VERIFY = os.path.join(REPO, "docs", "ui", "verify")
WEB = os.path.join(VERIFY, "web")
OUT = os.path.join(REPO, "docs", "ui")

# file, 关卡标签, 场景文件, 区域, 尺寸标签, 中文验收点[], 英文验收点[], 分组
SHEETS = [
    dict(file="zones_market.png", level="L03–L05 · 三区分野 / THREE ZONES",
         scene="NightZones.gd + NightZoneField.gd · levels/*.py 的 ZONES",
         area="三关各一格黑市 2× · 加三区色标",
         zh=["白 / 红 / 黑三条带的分界（米）写在同一张图上：货场 12 / 21.5 · 调车场 9 / 20 · 庄园 10 / 22",
             "每格都能看到「摊位 + 摊主 + 2 名幸存者」：黑市只在黑区，且紧着自己的光源（火堆 / 马灯）",
             "白区没有丧尸；红区 0~3 只 + 清杀队巡逻（白区居民禁止进入：3.5 s 警告、7 s 盘问）；黑区 7~8 只、每箱多翻一件",
             "黑市的老家（market 关）摊区就是黑区的中心——见 market_grey / market_night 两张全图"],
         en=["Band boundaries (m) are printed on the sheet: yard 12 / 21.5 · park 9 / 20 · manor 10 / 22",
             "Every panel shows the stall + trader + 2 survivors: the market only exists in the black zone, always by its own light",
             "White: no infected. Red: 0-3 + OSK patrols (residents forbidden: 3.5 s warn, 7 s challenge). Black: 7-8, +1 loot roll",
             "In the market's home level the bazaar IS the center of the black zone — see market_grey / market_night"],
         group="zone"),
    dict(file="yard_grey.png", level="L03 · ШИРОКАЯ КОЛЕЯ · 宽轨货场",
         scene="res://scenes/night_explore.tscn", area="整关 48×40 m · 中性光",
         zh=["五层赫鲁晓夫楼立面 + 亮窗、配电箱、告示板、钠路灯、铁网、扳道房、水塔是否连成一条街",
             "角色是否踩在雪地上、比例对不对（1 m = 64 px）",
             "警戒线 / 铁网 / 轨道三层纵深有没有把画面压平",
             "三条色带读不读得出来：白 0–12 / 红 12–21.5（红虚线）/ 黑 21.5–40（青虚线）"],
         en=["Does the block facade + lit windows + fuse box + notice board + sodium lamps + fence read as one street?",
             "Are actors standing on snow at the right scale (1 m = 64 px)?",
             "Do fence / tracks / yard keep three layers of depth?",
             "Can you read the three bands: white 0-12 / red 12-21.5 (red dashes) / black 21.5-40 (cyan dashes)?"],
         group="level"),
    dict(file="yard_night.png", level="L03 · ШИРОКАЯ КОЛЕЯ · 宽轨货场",
         scene="res://scenes/night_explore.tscn", area="整关 · 夜色",
         zh=["CanvasModulate 冷调是否压得住，暗部有没有糊死",
             "钠灯黄色光斑半径是否合理，两处油桶火有没有烧掉细节",
             "雪面高光是否过曝"],
         en=["Does the CanvasModulate night grade hold, or do shadows crush?",
             "Are sodium lamp pools a believable radius, and do braziers blow out detail?",
             "Is snow highlight clipping?"],
         group="level"),
    dict(file="marshalling_grey.png", level="L04 · ЗАПАДНЫЙ СОРТИРОВОЧНЫЙ ПАРК · 西调车场",
         scene="res://scenes/night_marshalling.tscn", area="整关 44×36 m · 中性光",
         zh=["砖砌调度楼、站台雨棚、驼峰线、四节车皮、水塔的空间关系",
             "三件新道具（沙袋 33.0, 9.2 / 弹药箱 24.2, 5.6 / 枪架 12.4, 4.1 m）是否落在车站逻辑位置上",
             "站台边缘与轨道是否有可走的通道",
             "色带：白 0–9 / 红 9–20 / 黑 20–36；出生点在黑区（涵洞）"],
         en=["Brick dispatch hall, canopy, hump tracks, boxcars, water tower — do they read in the right order?",
             "Do the three new props sit where a station would actually keep them?",
             "Is there a walkable lane along the platform edge?",
             "Bands: white 0-9 / red 9-20 / black 20-36; spawn is in the black zone (culvert)"],
         group="level"),
    dict(file="marshalling_night.png", level="L04 · ЗАПАДНЫЙ СОРТИРОВОЧНЫЙ ПАРК · 西调车场",
         scene="res://scenes/night_marshalling.tscn", area="整关 · 夜色",
         zh=["站台灯 / 调度楼窗光 / 油桶火三套光源是否互相打架",
             "车皮侧面在夜色里还能不能看出体积",
             "雪被灯照到的边缘是否过曝"],
         en=["Do platform lamps, window light and braziers fight each other?",
             "Can you still read boxcar volume in the dark?",
             "Do lit snow edges clip?"],
         group="level"),
    dict(file="manor_grey.png", level="L05 · СОСНОВАЯ УСАДЬА · 松林庄园",
         scene="res://scenes/night_manor.tscn", area="整关 46×38 m · 中性光",
         zh=["庄园主楼立面、车库卷帘门（黄黑警示条）、松林、长蒸汽管、庄园铁门",
             "这关要比货场「有钱」：砖石 / 铁艺 / 涂装的级差够不够",
             "庄园车道那条深色沥青带边缘是否生硬",
             "色带：白 0–10 / 红 10–22 / 黑 22–38；黑市在西门内西松林（11.8, 27.4）"],
         en=["Manor facade, garage roller door (hazard stripes), pine belt, steam pipe, iron gate",
             "This level must read richer than the freight yard — is the material tiering enough?",
             "Is the dark driveway edge too hard?",
             "Bands: white 0-10 / red 10-22 / black 22-38; market sits in the western pines (11.8, 27.4)"],
         group="level"),
    dict(file="manor_night.png", level="L05 · СОСНОВАЯ УСАДЬА · 松林庄园",
         scene="res://scenes/night_manor.tscn", area="整关 · 夜色",
         zh=["最暗的一关：松林会不会把玩家整个吃掉",
             "两处火盆是否给出可用的导航锚点",
             "瞭望塔探照灯位置与地面光斑"],
         en=["Darkest level: do the pines swallow the player?",
             "Do the two braziers work as navigation anchors?",
             "Watchtower searchlight position vs its ground pool"],
         group="level"),
    dict(file="outpost_marshalling.png", level="L04 · 哨位特写",
         scene="res://scenes/night_marshalling.tscn", area="三个新哨位 2× · 沙袋 / 弹药箱 / 枪架",
         zh=["虚线框 = 精灵本体外框；十字 = 落地锚点（碰撞、遮蔽都按锚点算）",
             "沙袋 (33.0, 9.2 m)：低掩体，只挡视线不挡子弹",
             "弹药箱 (24.2, 5.6 m)：必出步枪弹；枪架 (12.4, 4.1 m)：只剩一把撬棍"],
         en=["Dashed box = sprite bounds; crosshair = ground anchor (collision & occlusion use it)",
             "Sandbags (33.0, 9.2 m): low cover, hides you but does not stop bullets",
             "Ammo box (24.2, 5.6 m): guaranteed rifle rounds; rack (12.4, 4.1 m): one crowbar left"],
         group="crop"),
    dict(file="outpost_manor.png", level="L05 · 哨位特写",
         scene="res://scenes/night_manor.tscn", area="三个新哨位 2× · 沙袋 / 弹药箱 / 枪架",
         zh=["沙袋 (27.0, 12.6 m)：与停着的叉车互为掩体",
             "弹药箱 (21.0, 6.2 m)：卫兵哨位；枪架 (9.2, 4.2 m)：409 批托盘旁",
             "有没有穿帮：压在雪脊上、堵死必经路线、和托盘挤在一起"],
         en=["Sandbags (27.0, 12.6 m): pairs with the parked forklift",
             "Ammo box (21.0, 6.2 m): guard post; rack (9.2, 4.2 m): beside the Batch-409 pallet",
             "Clipping: sunk into snow ridges, blocking the only route, jammed against the pallet"],
         group="crop"),
    dict(file="mine_grey.png", level="L07M · ШАХТА №3 · 3 号矿坑",
         scene="res://scenes/night_mine.tscn", area="整关 46×34 m · 中性光",
         zh=["矿山岩壁立面：斜井坑木门脸 / 工棚 / 矿仓 / 井架 / 爆破断面的次序读不读得出来",
             "假人哨塔（38.5, 13.4 m）：远看是哨位、近看是塑料模特 + 猪嘴面具——轮廓必须骗得到人",
             "铝热剂堆（33.5 / 37.2 m）与起爆器（29.5, 26.8 m）：作案工具一眼可辨；起爆器旁斜靠爆破台账木夹板",
             "色带：白 0–11 / 红 11–21 / 黑 21–34；出生点与目标物都在黑区（本关无探照灯）"],
         en=["Does the rock facade read in order: timber portal / shack / ore bin / headframe / blast cut?",
             "Dummy tower (38.5, 13.4): from afar an outpost, up close a mannequin — does the silhouette fool you?",
             "Thermite (33.5 / 37.2) and detonator (29.5, 26.8): legible tools; the blast ledger leans on the rig",
             "Bands: white 0-11 / red 11-21 / black 21-34; spawn and objective both sit in the black (no searchlight)"],
         group="level"),
    dict(file="mine_night.png", level="L07M · ШАХТА №3 · 3 号矿坑",
         scene="res://scenes/night_mine.tscn", area="整关 · 夜色",
         zh=["没有探照灯的一关：两盏钠灯 + 两处火堆够不够把黑区照出「可走」的边界",
             "孢子断面的暗哑微光（灰绿）：要看得见、又不能像魔法——它是地质微光",
             "井架绞车房小窗与斜井洞口暖光是不是全场唯一的「活气」"],
         en=["The no-searchlight level: two lamps + two fires — is the black zone still navigable?",
             "The spore face's dull grey-green sheen: visible, but geological — not magical",
             "Are the headframe cabin window and portal glow the only signs of life?"],
         group="level"),
    dict(file="outpost_mine.png", level="L07M · 哨位特写",
         scene="res://scenes/night_mine.tscn", area="三件新道具 2× · 假人哨塔 / 孢子断面 / 起爆器",
         zh=["假人哨塔 (38.5, 13.4 m)：脚手架 + 防化服模特 + 猪嘴面具 + 扩音器——不许有一盏灯",
             "孢子断面 (36.5, 28.4 m)：千层糕层理里那条灰黑孢子带的「暗哑微光」对不对",
             "起爆器 (29.5, 26.8 m)：仪表 + 手摇柄 + 电缆盘 + 斜靠的台账夹板；必出 intel"],
         en=["Dummy tower (38.5, 13.4): scaffold + hazmat mannequin + pig-snout respirator — no light allowed",
             "Spore face (36.5, 28.4): is the dull sheen on the grey-black spore band right?",
             "Detonator (29.5, 26.8): dial + crank + cable reel + leaning ledger; guarantees intel"],
         group="crop"),
    dict(file="market_grey.png", level="L07 · БАРАХОЛКА · 铁路黑市",
         scene="res://scenes/night_market.tscn", area="整关 46×34 m · 中性光",
         zh=["工人镇板房立面 + 镇口街灯 + 破损供暖管 + 棚户巷板房：一条「人住的街」读不读得出来",
             "市集摊区（24.5, 24.4 m）与 6.66 电台棚（36.5, 25.0 m）：摊位 / 摊主 / 幸存者的社会距离对不对",
             "辨药对照：真药（10.6, 24.6）朴素白瓶、假药（19.2, 24.0）花哨商标，摆在同一个摊区里",
             "色带：白 0–11 / 红 11–21 / 黑 21–34；摊区、烫鳞后巷、药棚铁门全在黑区；铁路 1 道（27.0 m）离围栏 6 m，不能糊成黑带"],
         en=["Do the plank-shack facade + street lamp + steam pipe + shanty row read as one inhabited street?",
             "Bazaar (24.5, 24.4) and Radio-666 stall (36.5, 25.0): is the social spacing of stall/trader/survivors right?",
             "Medicine contrast: plain white vials (10.6, 24.6) vs flashy labels (19.2, 24.0), same bazaar",
             "Bands: white 0-11 / red 11-21 / black 21-34; bazaar, quack alley and iron door all in the black; rail 1 (27.0) keeps 6 m from the fence — it must not smear into a black band"],
         group="level"),
    dict(file="market_night.png", level="L07 · БАРАХОЛКА · 铁路黑市",
         scene="res://scenes/night_market.tscn", area="整关 · 夜色",
         zh=["三团光要一眼分得开：摊区最暖（马灯 / 篝火）、6.66 棚最病（电子管微绿）、后巷最恶（炭炉橙红）",
             "药棚铁门那片是不是暗得刚好——C2 的戏发生在暗里",
             "铁路 1 道的雪面与铁轨反光：不能糊成一条黑带"],
         en=["Three glows must separate at a glance: warmest bazaar (lanterns/fire), sickliest 6.66 (tube green), evilest alley (forge orange-red)",
             "Is the med-shed iron door just dark enough — C2's drama happens in the dark",
             "Rail 1: snow and rail sheen must not fuse into one black band"],
         group="level"),
    dict(file="outpost_market.png", level="L07 · 哨位特写",
         scene="res://scenes/night_market.tscn", area="三件新道具 2× · 6.66 电台棚 / 烫鳞炭炉 / 药棚铁门",
         zh=["6.66 电台棚 (36.5, 25.0 m)：指针钉死在 6.66；电子管微绿不是魔法绿光；柜台摆花哨假药瓶",
             "烫鳞炭炉 (7.0, 24.9 m)：炭炉 + 烧红马蹄铁 + 折叠凳 + 烫焦绷带——只有工具和痕迹，不画行刑现场",
             "药棚铁门 (12.0, 23.2 m)：磁卡读头 + 可锁挂环（C2 的锁点）；门里的冷柜必出 abx"],
         en=["Radio-666 (36.5, 25.0): dial pinned at 6.66; tube-green is not magic green; flashy fake bottles on the counter",
             "Quack forge (7.0, 24.9): charcoal + red-hot horseshoe + stool + scorched bandages — tools and traces only",
             "Med-shed iron door (12.0, 23.2): card reader + lockable hasp (C2's lock point); the fridge inside guarantees abx"],
         group="crop"),
    dict(file="coldstore_grey.png", level="L02 · ХОЛОДИЛЬНИК №4 · 城北四号铁路冷库",
         scene="res://scenes/night_coldstore.tscn", area="整关 46×34 m · 中性光",
         zh=["冷库主楼立面：保温板 + 冷风机 + 值班暖窗 + 铁路大门（26 m）读不读得出「冷链设施」",
             "账面 vs 活人一眼可读：磁卡终端红字块（14.5, 5.2）+ 封存药箱冷光 vs 3 号柱后的人形（24.2 / 25.8, 24.8 / 25.0）",
             "排水窄缝 (33.5, 3.9)：只有痕迹（刮烂的铝饭盒 + 抓痕），不画胳膊",
             "色带：白 0–11 / 红 11–21 / 黑 21–34；铁路专用线 1 道（27.0）离围栏 6.2 m，不许糊成黑带"],
         en=["Does the cold-store facade read as a cold-chain facility: panels + condensers + warm duty window + rail door (26 m)?",
             "Books vs the living at a glance: red terminal block (14.5, 5.2) + cold-lit med crate vs the two figures behind column 3",
             "Drain slit (33.5, 3.9): traces only (mangled lunchbox + scratches) — no arms drawn",
             "Bands: white 0-11 / red 11-21 / black 21-34; the rail spur (27.0) keeps 6.2 m from the fence — no black smear"],
         group="level"),
    dict(file="coldstore_night.png", level="L02 · ХОЛОДИЛЬНИК №4 · 城北四号铁路冷库",
         scene="res://scenes/night_coldstore.tscn", area="整关 · 夜色",
         zh=["「月台暖、南库冷白、终端血红」三团色要一眼分得开",
             "南库吊灯是冷白（LIGHT_COLORS），照着 3 号柱后的母子——账面死人 vs 活人的唯一对证",
             "两处火桶（值班炉 9.2 / 幸存者火桶 41.0）=「有人给自己烧火」的暖色注脚；无探照灯"],
         en=["Three colors must separate at a glance: warm platform, cold-white south hall, blood-red terminal",
             "The hall lamp is cold white (LIGHT_COLORS) over the mother and child behind column 3 — the only witness against the ledger",
             "Two braziers (duty 9.2 / worker 41.0) are the warm footnotes of people burning fire; no searchlight"],
         group="level"),
    dict(file="outpost_coldstore.png", level="L02 · 哨位特写",
         scene="res://scenes/night_coldstore.tscn", area="三件新道具 2× · 磁卡终端 / 封存药箱 / 冷库铁门",
         zh=["磁卡终端 (14.5, 5.2)：红字屏是全图唯一的红——【当前南库坐标在册人数：0】",
             "封存药箱 (11.5, 25.2)：钢印封条 + 红十字 + 霜挂；必出 abx（真药的另一半答案）",
             "冷库铁门 (37.5, 23.6)：滑轨双扇门 + 撬棍卡口——wedge 机关的载体（把它们引过去）"],
         en=["Card terminal (14.5, 5.2): the red display is the only red on the map — roster headcount: 0",
             "Sealed med crate (11.5, 25.2): steel seals + red cross + frost; guarantees abx (the other half of the real drugs)",
             "Cold vault door (37.5, 23.6): sliding double door + crowbar notch — the wedge mechanism (lead them there)"],
         group="crop"),
    dict(file="canteen_grey.png", level="L05 · ВОСТОЧНАЯ СТОЛОВАЯ · 东街工人食堂 · 后厨",
         scene="res://scenes/night_canteen.tscn", area="整关 44×32 m · 中性光",
         zh=["瓷砖后厨立面：炉罩（12 m）+ 出餐口（22 m）+ 一排磨砂高窗（33 m）读不读得出「工人食堂后厨」",
             "十九只碗 (22, 25)：长条桌一圈搪瓷碗、缺口朝外——账面清空 vs 十九个老铁路工一眼可读",
             "砧板上的宽背砍骨刀 (24, 8.2)：2-1 锁骨的起点（必出 blade）；窄门 (32, 4.6) 是 wedge 机关载体",
             "色带：白 22–32 / 红 12–22 / 黑 0–12；室内关无铁丝网、无铁轨——地面是混凝土预制板 + 油毡补丁 + 漆线"],
         en=["Does the tile-wall kitchen facade read as a workers' canteen kitchen: hood (12 m) + hatch (22 m) + frosted windows (33 m)?",
             "Nineteen bowls (22, 25): enamel bowls in a circle, chips outward — the books say empty, the bowls disagree",
             "Wide-backed cleaver on the block (24, 8.2): the 2-1 collarbone starts here (guaranteed blade); the narrow door (32, 4.6) is the wedge point",
             "Bands: white 22-32 / red 12-22 / black 0-12; interior level — no fence, no rails: concrete slab + lino patches + paint lines"],
         group="level"),
    dict(file="canteen_night.png", level="L05 · ВОСТОЧНАЯ СТОЛОВАЯ · 东街工人食堂 · 后厨",
         scene="res://scenes/night_canteen.tscn", area="整关 · 夜色",
         zh=["灶火橙（炉罩下）+ 磨砂窗冷蓝 + 两盏吊灯下暖黄 + 黑区深灰，四团色要一眼分得开",
             "礼堂火炉 (39.5, 27.5) =「十九个人的余温」的暖色注脚；无探照灯",
             "窄门缝的那点暖光 = 危险提示（门后 40 度高烧的瓦西里）——它必须是最勾眼又最让人不敢靠近的一点"],
         en=["Four colors must separate: hood-fire orange, frosted-window blue, warm lamp pools, dark black zone",
             "The hall stove (39.5, 27.5) is the warm footnote of nineteen people's last warmth; no searchlight",
             "The warm seam under the narrow door is the danger cue (40°C delirium behind it) — eye-catching, but you don't want to approach"],
         group="level"),
    dict(file="outpost_canteen.png", level="L05 · 哨位特写",
         scene="res://scenes/night_canteen.tscn", area="三件新道具 2× · 砧板砍骨刀 / 十九只碗长条桌 / 杂物间窄门",
         zh=["砧板砍骨刀 (24, 8.2)：宽背生锈、刃有豁口、柄上是黑麦糊和血的干渍——「东街锁骨」的凶器",
             "十九只碗长条桌 (22, 25)：桌面油亮包浆，搪瓷碗一圈缺口朝外；黑麦糊桶 (18, 9.8) 还温着",
             "杂物间窄门 (32, 4.6)：门框新裂、单向门 + 撬棍卡口——wedge 机关的载体（别让他冲出来）"],
         en=["Cleaver on the block (24, 8.2): wide back, rust, a chipped edge, rye-and-blood grime on the handle — the weapon of the collarbone",
             "Nineteen-bowl table (22, 25): worn tabletop, enamel bowls chipped outward; the rye vat (18, 9.8) is still warm",
             "Narrow door (32, 4.6): fresh-split frame, one-way door + crowbar notch — the wedge mechanism (don't let him out)"],
         group="crop"),
    dict(file="sanitarium_grey.png", level="L06 · САНАТОРИЙ · 旧传染病疗养院 · 地下室",
         scene="res://scenes/night_sanitarium.tscn", area="整关 44×30 m · 中性光",
         zh=["地下室北墙立面：一排带栏换气铁窗（22 m 簇）+ 重型铁门（8 m）+ 管道束（36 m）读不读得出「贴近路基的地下科室」",
             "铁架床 + 两根皮带 (23, 5)：安娜（0419）把自己捆在这里熬过第四天——皮带磨亮的痕迹是钱道具",
             "药柜 (10, 23.5) 必出 asp（半片阿司匹林的回声）；笼3 回退半人 (31, 6.2) 掉鳞屑、瞳孔回色",
             "色带：白 21–30（医生工作区）/ 红 12–21（走廊）/ 黑 0–12（铁笼区）；室内关无铁丝网、无铁轨"],
         en=["Does the basement north wall read as a sanatorium undercroft: barred vent windows (22 m cluster) + heavy iron door (8 m) + pipe run (36 m)?",
             "Iron bed + two straps (23, 5): Anna (0419) tied herself here through the fourth day — the polished strap wear is the money detail",
             "Med cabinet (10, 23.5) guarantees asp (the echo of the last half-tablet); the regressing half in cage 3 (31, 6.2) sheds scale, pupils clearing",
             "Bands: white 21-30 (doctors' area) / red 12-21 (corridor) / black 0-12 (cage rows); interior level — no fence, no rails"],
         group="level"),
    dict(file="sanitarium_night.png", level="L06 · САНАТОРИЙ · 旧传染病疗养院 · 地下室",
         scene="res://scenes/night_sanitarium.tscn", area="整关 · 夜色",
         zh=["笼区冷白吊灯（LIGHT_COLORS）vs 医生工作区暖灯 vs 火炉橙——三团色要一眼分得开",
             "铁架床那一格是冷白最深处的一点暖（皮带反光）——「有人熬过了第四天」的唯一证词",
             "换气铁窗透进来的冷蓝是与外界（铁壳号）的唯一联系；无探照灯"],
         en=["Three colors must separate: cold-white cage lamp (LIGHT_COLORS), warm office lamp, fire-orange braziers",
             "The bed cell holds one warm glint deep in the cold white (strap shine) — the only testimony that someone survived the fourth day",
             "Cold blue through the vents is the only contact with the outside (the Iron Shell on the curve); no searchlight"],
         group="level"),
    dict(file="outpost_sanitarium.png", level="L06 · 哨位特写",
         scene="res://scenes/night_sanitarium.tscn", area="三件新道具 2× · 铁架床皮带 / 药柜 / 笼区铁栅门",
         zh=["铁架床 + 两根皮带 (23, 5)：铁架床栏杆 + 破毯 + 两根磨亮的旧皮带（缠绕带头）——安娜的刑具与救生索",
             "药柜 (10, 23.5)：钢柜 + 开着的柜门 + 药瓶层板 + 红十字；必出 asp（半片阿司匹林的回声）",
             "笼区铁栅门 (22, 11)：对开栅扇 + 插销 + 底梁撬棍卡口——wedge 机关的载体（把它们关在里面）"],
         en=["Iron bed + two straps (23, 5): barred frame, torn blanket, two polished old straps — Anna's instrument and lifeline",
             "Med cabinet (10, 23.5): steel cabinet, open door, vial shelves, red cross; guarantees asp (the echo of the last half-tablet)",
             "Cage gate (22, 11): twin barred leaves + latch + crowbar notch on the bottom rail — the wedge mechanism (keep them inside)"],
         group="crop"),
    dict(file="combat_readout.png", level="战斗读数 · L03–L07M 通用",
         scene="godot_project/scripts/night/Arsenal.gd", area="俯视 1 m = 14 px",
         zh=["撬棍扇形 ±49° / 1.9 m：够不够「贴身才有用」",
             "噪声圈 ТТ-33 26 m / 锯短 38 m / 莫辛 44 m：一枪就把 80% 半径内的巡逻拽过来，是不是太狠",
             "命中半径 0.40 / 0.46 / 0.52 m 与左下数值表是否和 Arsenal.gd 对得上"],
         en=["Crowbar cone ±49° at 1.9 m — is it intimate enough?",
             "Noise rings 26 / 38 / 44 m pull every patrol inside 80% — too punishing?",
             "Hit radii 0.40 / 0.46 / 0.52 m and the stat table must match Arsenal.gd"],
         group="read"),
]

GROUPS = [("zone", "00 · 三区分野与黑市 / Three zones & black market"),
          ("level", "01 · 六关整图 / Full levels"),
          ("crop", "02 · 哨位特写 / Outpost close-ups"),
          ("read", "03 · 战斗读数 / Combat readout")]


def thumb(path: str, long_edge: int = 1600) -> bytes:
    im = Image.open(path).convert("RGB")
    w, h = im.size
    k = min(1.0, long_edge / max(w, h))
    if k < 1.0:
        im = im.resize((int(w * k), int(h * k)), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=84, optimize=True, progressive=True)
    return buf.getvalue()


def b64(data: bytes) -> str:
    return "data:image/jpeg;base64," + base64.b64encode(data).decode("ascii")


def build(standalone: bool) -> str:
    cards = []
    for gid, gtitle in GROUPS:
        items = [s for s in SHEETS if s["group"] == gid]
        cards.append(f'<h2 id="{gid}">{gtitle}</h2>\n<section class="grid">')
        for s in items:
            src_png = os.path.join(VERIFY, s["file"])
            src_jpg = os.path.join(WEB, s["file"].replace(".png", ".jpg"))
            if standalone:
                src = b64(thumb(src_png))
            else:
                src = "verify/web/" + os.path.basename(src_jpg)
            w, h = Image.open(src_png).size
            checks = "".join(f"<li>{c}</li>" for c in s["zh"])
            checks_en = "".join(f"<li>{c}</li>" for c in s["en"])
            cards.append(f'''  <article class="card">
    <header>
      <span class="chip">{s['level']}</span>
      <span class="meta mono">{w}×{h}</span>
    </header>
    <a class="shot" href="verify/{s['file']}" target="_blank" rel="noopener">
      <img loading="lazy" src="{src}" alt="{s['file']}">
    </a>
    <div class="sub mono">{s['scene']}</div>
    <div class="sub dim">{s['area']} · {s['file']}</div>
    <div class="checks">
      <ul>{checks}</ul>
      <ul class="en">{checks_en}</ul>
    </div>
  </article>''')
        cards.append("</section>")

    nav = "".join(f'<a href="#{g}">{t}</a>' for g, t in GROUPS)
    note = ("单文件离线版 / standalone: 图片已内嵌 base64，可以直接把这个 HTML 发给别人或双击打开。"
            if standalone else
            "在线版 / served: 图片走相对路径，原尺寸 PNG 点图可看。")
    return f'''<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>YEAR OF Z · 验收图 / Acceptance Sheets</title>
<style>
  :root{{--ink:#070809;--iron:#121618;--plate:#1b2023;--steel:#343c3f;--steel-lit:#4a5457;
        --bone:#d8d1bf;--bone-dim:#8c8578;--ash:#6b6560;--ochre:#c8a257;--blood:#8c1c14;
        --signal:#d9a326;--frost:#8fb4c4;--crt:#63d18a}}
  *{{box-sizing:border-box}}
  body{{margin:0;background:var(--ink);color:var(--bone);
       font:15px/1.65 -apple-system,"Segoe UI","Noto Sans SC","PingFang SC",sans-serif}}
  a{{color:var(--ochre)}}
  .mono{{font-family:"Cascadia Mono",Consolas,"DejaVu Sans Mono",monospace}}
  .wrap{{max-width:1180px;margin:0 auto;padding:0 20px 80px}}
  .mast{{border-bottom:2px solid var(--steel);padding:26px 0 14px;margin-bottom:6px}}
  .kicker{{font:11px/1.6 "Cascadia Mono",Consolas,monospace;letter-spacing:.16em;color:var(--bone-dim)}}
  h1{{font-size:26px;margin:6px 0 6px;letter-spacing:.02em}}
  .lede{{color:var(--bone-dim);font-size:13px;max-width:78ch;margin:0 0 12px}}
  .warn{{border-left:3px solid var(--signal);padding:8px 12px;background:#15181a;
        color:#c9c2b0;font-size:12.5px;margin:12px 0 0}}
  nav{{position:sticky;top:0;z-index:5;background:rgba(7,8,9,.94);backdrop-filter:blur(6px);
       border-bottom:1px solid var(--steel);display:flex;gap:8px;flex-wrap:wrap;padding:10px 0;margin-bottom:8px}}
  nav a{{font:12px/1 "Cascadia Mono",Consolas,monospace;text-decoration:none;color:var(--bone-dim);
        border:1px solid var(--steel);padding:7px 10px}}
  nav a:hover{{color:var(--bone);border-color:var(--ochre)}}
  h2{{font-size:15px;letter-spacing:.1em;color:var(--ochre);text-transform:uppercase;
      margin:38px 0 12px;border-bottom:1px solid var(--steel);padding-bottom:8px}}
  .grid{{display:grid;gap:18px}}
  .card{{background:var(--plate);border:1px solid var(--steel);padding:14px 14px 12px}}
  .card header{{display:flex;align-items:baseline;justify-content:space-between;gap:12px;margin-bottom:10px}}
  .chip{{font:12px/1 "Cascadia Mono",Consolas,monospace;color:#0b0d0e;background:var(--ochre);
        padding:6px 9px;letter-spacing:.04em}}
  .meta{{font-size:11px;color:var(--ash)}}
  .shot{{display:block;line-height:0;border:1px solid var(--steel-lit);margin-bottom:10px;background:#0b0d0e}}
  .shot img{{width:100%;display:block}}
  .sub{{font-size:11.5px;color:var(--frost);margin-top:-2px}}
  .sub.dim{{color:var(--ash)}}
  .checks{{display:grid;grid-template-columns:1fr;gap:2px;margin-top:10px;
          border-top:1px dashed var(--steel);padding-top:9px}}
  @media(min-width:900px){{.checks{{grid-template-columns:1fr 1fr;gap:0 22px}}}}
  .checks ul{{margin:0;padding-left:16px;font-size:12.5px;color:#c0b9a7}}
  .checks ul.en{{color:var(--bone-dim);font-size:12px}}
  .checks li{{margin:2px 0}}
  footer{{margin-top:46px;border-top:2px solid var(--steel);padding-top:16px;
         font-size:12px;color:var(--bone-dim)}}
  .zones{{display:grid;gap:8px;margin:16px 0 0}}
  @media(min-width:820px){{.zones{{grid-template-columns:repeat(3,1fr)}}}}
  .z{{background:#141819;border:1px solid var(--steel);border-left:7px solid var(--steel);padding:9px 11px}}
  .z b{{font-size:13px;color:var(--bone);display:block;letter-spacing:.02em}}
  .z em{{font:10.5px/1.4 "Cascadia Mono",Consolas,monospace;color:var(--ash);font-style:normal;
        letter-spacing:.12em;display:block;margin:1px 0 4px}}
  .z small{{font-size:11.5px;color:#b6ae9d;line-height:1.5;display:block}}
  .z.a{{border-left-color:#9fc6e0}} .z.b{{border-left-color:#c8483a}} .z.c{{border-left-color:#3aa0b4}}
  .pill{{display:inline-block;border:1px solid var(--steel-lit);padding:3px 8px;margin:3px 6px 3px 0;
        font:11px/1.4 "Cascadia Mono",Consolas,monospace;color:var(--bone-dim)}}
</style>
</head>
<body>
<div class="wrap">
  <div class="mast">
    <div class="kicker">YEAR OF Z · IRON WINTER — ACCEPTANCE SHEETS</div>
    <h1>验收图 / Acceptance Sheets</h1>
    <p class="lede">
      10 张图，每张都标了它属于哪个场景。第一张看三区分野与黑市，整关图看美术与摆位，
      特写看三件新哨位道具，读数图看战斗手感是否成立。
      逐张说明也写在 <span class="mono">docs/ui/verify/README.md</span>。
    </p>
    <div class="zones">
      <div class="z a"><b>白区 · 安全区</b><em>ZONE A · WHITE · SAFE</em>
        <small>0 丧尸 · 清杀队不进 · 唯一能站定了搜包的地方</small></div>
      <div class="z b"><b>红区 · 管制带</b><em>ZONE B · RED · CURFEW</em>
        <small>0~3 丧尸 · 巡逻主力 · <b>白区居民禁止进入</b>：3.5 s 警告、7 s 盘问</small></div>
      <div class="z c"><b>黑区 · 沉降带</b><em>ZONE C · BLACK · SUNKEN</em>
        <small>7~8 丧尸 · 每箱多翻一件 · 黑市与幸存者只在这里</small></div>
    </div>
    <div class="warn">
      ⚠️ 这些不是引擎截图：沙箱里没有 Godot，图片由
      <span class="mono">tools/art_gen/render_preview.py</span> 直接读 <span class="mono">.tscn</span>
      复合成画面 —— 位置、层级、夜色、补光、分区色带与游戏一致；shader、粒子、HUD、动画中间帧不在图上。
      战斗手感（后坐、命中反馈、音效）与红区警告的实际触发仍然只是静态验证。
    </div>
    <div style="margin-top:12px">{note}</div>
  </div>
  <nav>{nav}<a href="soviet_ui_board.html">04 · 界面板 / UI board</a>
    <a href="verify/README.md">README.md</a></nav>
  {''.join(cards)}
  <footer>
    <div class="pill">1 m = 64 px</div><div class="pill">地面纵向 ×0.62</div>
    <div class="pill">1080p 目标</div><div class="pill">Godot 4.7.2</div>
    <p>重新生成：<span class="mono">python3 godot_project/tools/art_gen/render_preview.py</span>
       出图 · <span class="mono">python3 godot_project/tools/art_gen/build_acceptance_page.py</span>
       出页面。</p>
    <p>仍然没美术化的场景：<span class="mono">main.tscn / campaign.tscn / event_demo.tscn</span>
       —— 还是 <span class="mono">_draw()</span> 灰盒，下一批处理。</p>
  </footer>
</div>
</body>
</html>
'''


def main() -> None:
    os.makedirs(WEB, exist_ok=True)
    for s in SHEETS:
        src = os.path.join(VERIFY, s["file"])
        dst = os.path.join(WEB, s["file"].replace(".png", ".jpg"))
        data = thumb(src)
        with open(dst, "wb") as f:
            f.write(data)
        print(f"  web {os.path.basename(dst):28s} {len(data)/1024:7.0f} KB")

    page = build(standalone=False)
    with open(os.path.join(OUT, "acceptance.html"), "w", encoding="utf-8") as f:
        f.write(page)
    print("  ->", os.path.join(OUT, "acceptance.html"), f"{len(page)/1024:.0f} KB")

    solo = build(standalone=True)
    with open(os.path.join(OUT, "acceptance_standalone.html"), "w", encoding="utf-8") as f:
        f.write(solo)
    print("  ->", os.path.join(OUT, "acceptance_standalone.html"), f"{len(solo)/1024/1024:.1f} MB")


if __name__ == "__main__":
    main()
