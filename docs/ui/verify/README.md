# 验收图 / Acceptance Sheets

> 新增 **三区分野**（白 / 红 / 黑）与黑市：`zones_market.png` 是这一轮的主图；
> 十六张整关图上都能直接看到分区色带与雪面标签。规则与坐标见 `docs/zh/Z年纪事_三区与黑市.md`。

> 这个目录里的 PNG **不是引擎截图**。本机跑不了 Godot，所以由
> `godot_project/tools/art_gen/render_preview.py` 直接读 `godot_project/scenes/*.tscn`，
> 按节点 `position / offset / z_index / y-sort` 把真实的 PNG 贴回去，再叠 `CanvasModulate`
> 的夜色、`PointLight2D` 的补光、暗角与雪噪点。
> 位置、比例、层级、光色与游戏一致；不含 shader、粒子、UI、动画中间帧。
>
> These PNGs are **not engine captures**. There is no Godot binary in this environment, so
> `render_preview.py` composites the real art directly from the `.tscn` files
> (positions, offsets, z-index, y-sort, `CanvasModulate`, `PointLight2D`, vignette).
> Layout and lighting match the game; shaders, particles, HUD and in-between animation frames do not.

---

## 一、总览表 / Index

| # | 文件 / File | 场景 / Scene | 画面区域 / Area | 看什么 / What to check |
|---|---|---|---|---|
| 0 | `zones_market.png` | `NightZones.gd` + `NightZoneField.gd`<br>L03–L05 通用 / all three night levels | 三关各一格黑市 2× + 三区色标 / market per level + zone legend | 三条带的分界数字（货场 12 / 21.5 · 调车场 9 / 20 · 庄园 10 / 22）；每格都有「摊位 + 摊主 + 2 名幸存者」且就在自己的光源旁边；油桶火只到桶口以上一小截；黑市老家（market 关）的摊区见 market_grey / market_night |
| 1 | `yard_grey.png` | `res://scenes/night_explore.tscn`<br>L03 · ШИРОКАЯ КОЛЕЯ · 宽轨货场（48×40 m） | 整关、中性光 / full level, neutral light | 街面是否连成一片：五层赫鲁晓夫楼立面 + 亮窗、配电箱、告示板、钠路灯、铁网、扳道房、水塔、雪堆；角色站位是否压在雪地上而不是浮空 |
| 2 | `yard_night.png` | 同上 / same | 整关、夜色 / full level, night grade | `CanvasModulate` 冷调是否压得住；钠灯黄色光斑半径是否合理；两处油桶火的暖光有没有烧掉细节；三条色带（白 / 红虚线 / 青虚线）与前一轮比是否更好认 |
| 3 | `marshalling_grey.png` | `res://scenes/night_marshalling.tscn`<br>L04 · ЗАПАДНЫЙ СОРТИРОВОЧНЫЙ ПАРК · 西调车场（44×36 m） | 整关、中性光 | 砖砌调度楼 + 站台雨棚 + 驼峰线 + 4 节车皮 + 水塔 + 铁网；新加的三件哨位道具（沙袋 / 弹药箱 / 枪架）是否落在车站逻辑位置上 |
| 4 | `marshalling_night.png` | 同上 | 整关、夜色 | 站台灯、调度楼窗光、油桶火三套光源是否互相打架；雪被灯照到的边缘是否过曝 |
| 5 | `manor_grey.png` | `res://scenes/night_manor.tscn`<br>L05 · СОСНОВАЯ УСАДЬА · 松林庄园（46×38 m） | 整关、中性光 | 庄园主楼立面 + 车库卷帘门（黄黑警示条）+ 松林 + 长蒸汽管 + 庄园铁门；庄园这一关比货场"有钱"，检查砖石与铁艺的对比级差 |
| 6 | `manor_night.png` | 同上 | 整关、夜色 | 最暗的一关：庄园车道那条深色沥青带是否太生硬；松林是否把玩家淹没在黑里；瞭望塔探照灯位置 |
| 7 | `mine_grey.png` | `res://scenes/night_mine.tscn`<br>L07M · ШАХТА №3 · 3 号矿坑（46×34 m） | 整关、中性光 | 矿山岩壁立面次序：斜井坑木门脸 / 工棚 / 矿仓 / 井架 / 爆破断面；假人哨塔（38.5, 13.4 m）远看是哨位近看是塑料模特；铝热剂堆（33.5 / 37.2 m）与起爆器（29.5, 26.8 m）是否一眼可辨；色带白 0–11 / 红 11–21 / 黑 21–34，出生点与目标物都在黑区 |
| 8 | `mine_night.png` | 同上 | 整关、夜色 | **无探照灯**的一关：两盏钠灯 + 两处火堆够不够把黑区照出可走的边界；孢子断面的暗哑微光（灰绿）要看得见、又不能像魔法 |
| 9 | `market_grey.png` | `res://scenes/night_market.tscn`<br>L07 · БАРАХОЛКА · 铁路黑市（46×34 m） | 整关、中性光 | 工人镇板房立面 + 镇口街灯 + 破损供暖管 + 棚户巷板房是否连成一条「人住的街」；市集摊区（24.5, 24.4 m）与 6.66 电台棚（36.5, 25.0 m）的社会距离；辨药对照（真药 10.6, 24.6 / 假药 19.2, 24.0）；色带白 0–11 / 红 11–21 / 黑 21–34；铁路 1 道（27.0 m）离围栏 6.2 m，轨道完整不糊 |
| 10 | `market_night.png` | 同上 | 整关、夜色 | 三团光一眼分得开：摊区最暖（马灯 / 篝火）、6.66 棚最病（电子管微绿）、后巷最恶（炭炉橙红）；药棚铁门暗得刚好——C2 的戏发生在暗里；铁轨反光不能糊成黑带 |
| 11 | `market_grey.png` | `night_market.tscn` — L07 Rail Black Market (46×34 m) | Whole level, neutral light: workers' plank-shack facade, street lamps, steam pipe, shanty row; bazaar (24.5, 24.4) and Radio-666 stall (36.5, 25.0); medicine contrast (true 10.6, 24.6 / fake 19.2, 24.0); bands white 0-11 / red 11-21 / black 21-34; rail 1 (27.0) keeps 6.2 m from the fence |
| `market_night.png` | same | Three glows must separate: warmest bazaar, sickliest 6.66 (tube green), evilest alley (forge orange-red); the med-shed door sits in the dark |
| `outpost_marshalling.png` | `res://scenes/night_marshalling.tscn` | 三个新哨位 2× 特写 / three outpost props, zoomed | 沙袋 (33.0, 9.2 m) · 弹药箱 (24.2, 5.6 m) · 枪架 (12.4, 4.1 m)：虚线框 = 精灵本体外框，十字准星 = 落地锚点（碰撞/遮蔽都以锚点为准）。枪架上只剩一把撬棍，是这一关撬棍的来源 |
| 12 | `outpost_manor.png` | `res://scenes/night_manor.tscn` | 三个新哨位 2× 特写 | 沙袋 (27.0, 12.6 m) · 弹药箱 (21.0, 6.2 m) · 枪架 (9.2, 4.2 m)：看特写里有没有穿帮（道具压在雪脊上、挡住必经路线、和 Batch-409 托盘挤在一起） |
| 13 | `outpost_mine.png` | `res://scenes/night_mine.tscn` | 三件新道具 2× 特写 | 假人哨塔 (38.5, 13.4 m)（脚手架 + 防化服模特 + 猪嘴面具 + 扩音器，**不许有一盏灯**）· 孢子断面 (36.5, 28.4 m)（千层糕层理 + 灰黑孢子带的暗哑微光）· 起爆器 (29.5, 26.8 m)（仪表 + 手摇柄 + 电缆盘 + 斜靠的台账夹板，必出 intel） |
| 14 | `outpost_market.png` | `res://scenes/night_market.tscn` | 三件新道具 2× 特写 | 6.66 电台棚 (36.5, 25.0 m)（指针钉死 6.66、电子管微绿、柜台花哨假药瓶）· 烫鳞炭炉 (7.0, 24.9 m)（炭炉 + 烧红马蹄铁 + 折叠凳 + 烫焦绷带——只有工具和痕迹）· 药棚铁门 (12.0, 23.2 m)（磁卡读头 + 可锁挂环；门里冷柜必出 abx） |
| 15 | `outpost_market.png` | `night_market.tscn` | 2× close-ups of Radio-666 stall (36.5, 25.0 m, dial pinned at 6.66), quack forge (7.0, 24.9 m, red-hot horseshoe — tools and traces only), med-shed iron door (12.0, 23.2 m, card reader + guaranteed abx) |
| 16 | `coldstore_grey.png` | `res://scenes/night_coldstore.tscn`<br>L02 · ХОЛОДИЛЬНИК №4 · 城北四号铁路冷库（46×34 m） | 整关、中性光 | 冷库主楼立面（保温板 + 冷风机 + 值班暖窗 + 铁路大门 26 m）；**账面 vs 活人**一眼可读：磁卡终端红字块（14.5, 5.2）+ 封存药箱 vs 3 号柱后母子（24.2 / 25.8, 24.8 / 25.0）；排水窄缝（33.5, 3.9）只有痕迹不画胳膊；色带白 0–11 / 红 11–21 / 黑 21–34；铁路专用线（27.0 m）离围栏 6.2 m |
| 17 | `coldstore_night.png` | 同上 | 整关、夜色 | 「月台暖、南库冷白、终端血红」三团色一眼分得开；南库吊灯冷白（LIGHT_COLORS）照着柱后母子；两处火桶（值班炉 9.2 / 幸存者火桶 41.0）= 有人给自己烧火的暖色注脚；无探照灯 |
| 18 | `outpost_coldstore.png` | `res://scenes/night_coldstore.tscn` | 三件新道具 2× 特写 | 磁卡终端 (14.5, 5.2)（红字屏是全图唯一的红：【当前南库坐标在册人数：0】）· 封存药箱 (11.5, 25.2)（钢印封条 + 红十字 + 霜挂，必出 abx）· 冷库铁门 (37.5, 23.6)（滑轨双扇门 + 撬棍卡口——wedge 机关载体） |
| 19 | `canteen_grey.png` | `res://scenes/night_canteen.tscn`<br>L05 · ВОСТОЧНАЯ СТОЛОВАЯ · 东街工人食堂 · 后厨（44×32 m） | 整关、中性光 | 瓷砖后厨立面（炉罩 12 m + 出餐口 22 m + 磨砂高窗 33 m）；**十九只碗**一眼可读：主桌 (22, 25) 一排搪瓷碗缺口朝外 vs 砧板宽背砍骨刀 (24, 8.2)；窄门 (32, 4.6) 是 wedge 机关载体；色带白 22–32 / 红 12–22 / 黑 0–12；室内关无铁丝网、无铁轨——混凝土地面 + 冻雪泥 + 漆线 |
| 20 | `canteen_night.png` | 同上 | 整关、夜色 | 灶火橙（炉罩下）+ 磨砂窗冷蓝 + 两盏吊灯下暖黄 + 黑区深灰四团色一眼分得开；礼堂火炉 (39.5, 27.5) = 十九个人的余温；**窄门缝的那点暖光 = 危险提示**（门后 40 度高烧的瓦西里）；无探照灯 |
| 21 | `outpost_canteen.png` | `res://scenes/night_canteen.tscn` | 三件新道具 2× 特写 | 砧板砍骨刀 (24, 8.2)（宽背生锈、刃有豁口、柄上黑麦糊和血的干渍——「东街锁骨」的凶器，必出 blade）· 十九只碗长条桌 (22, 25)（一排搪瓷碗缺口朝外，黑麦糊桶 (18, 9.8) 还温着）· 杂物间窄门 (32, 4.6)（门框新裂、单向门 + 撬棍卡口——别让他冲出来） |
| 22 | `sanitarium_grey.png` | `res://scenes/night_sanitarium.tscn`<br>L06 · САНАТОРИЙ · 旧传染病疗养院 · 地下室（44×30 m） | 整关、中性光 | 地下室北墙立面（带栏换气铁窗簇 22 m + 重型铁门 8 m + 管道束 36 m）；**铁架床 + 两根皮带** (23, 5) 是钱道具（安娜 0419 熬过第四天）；药柜 (10, 23.5) 必出 asp；笼3 回退半人 (31, 6.2) 掉鳞屑；色带白 21–30 / 红 12–21 / 黑 0–12；室内关混凝土地面，无铁丝网、无铁轨 |
| 23 | `sanitarium_night.png` | 同上 | 整关、夜色 | 三团色一眼分得开：笼区冷白吊灯（LIGHT_COLORS）/ 医生工作区暖灯 + 火炉橙 / 换气铁窗冷蓝（与铁壳号的唯一联系）；铁架床上皮带的那点反光 = 冷白深处唯一一点暖；无探照灯 |
| 24 | `outpost_sanitarium.png` | `res://scenes/night_sanitarium.tscn` | 三件新道具 2× 特写 | 铁架床 + 两根皮带 (23, 5)（铁架床栏杆 + 破毯 + 两根磨亮的旧皮带——安娜的刑具与救生索）· 药柜 (10, 23.5)（钢柜 + 开着的柜门 + 药瓶层板 + 红十字，必出 asp）· 笼区铁栅门 (22, 11)（对开栅扇 + 插销 + 底梁撬棍卡口——把它们关在里面） |
| `combat_readout.png` | L03–L07M 通用 / all night levels | 俯视读数 / top-down readout | 撬棍扇形 ±49°/1.9 m 是否够"贴身才有用"；TT-33 26 m、锯短 38 m、莫辛 44 m 的噪声圈是否真的"一枪就把人拽过来"；右下命中半径（0.40/0.46/0.52 m）与左下数值表 |

> 特写图（11–14）里**故意不画角色**，避免路过的兵挡住道具；整关图（1–10）保留角色，用来看人／环境比例。

### Index (EN, condensed)

| File | Scene | What it shows |
|---|---|---|
| `zones_market.png` | all three night levels | 2× market close-up per level + the three-zone legend with band boundaries (12/21.5, 9/20, 10/22 m) |
| `canteen_grey.png` | `night_canteen.tscn` — L05 East Street Canteen (44×32 m) | Whole level, neutral light: tile-wall kitchen facade (hood 12 m + hatch 22 m + frosted windows 33 m); nineteen bowls on the main table (22, 25) vs the cleaver block (24, 8.2); narrow door (32, 4.6) is the wedge point; interior level — concrete floor, no fence, no rails |
| `canteen_night.png` | same | Four glows: hood-fire orange, frosted-window blue, warm lamp pools, dark black zone; the warm seam under the narrow door is the danger cue (40°C behind it) |
| `sanitarium_grey.png` | `night_sanitarium.tscn` — L06 Old Sanatorium Basement (44×30 m) | Whole level, neutral light: barred vent windows + heavy iron door + pipes; iron bed with two straps (23, 5) — Anna 0419's money prop; med cabinet (10, 23.5) guarantees asp; regressing half in cage 3 (31, 6.2); interior concrete floor, no fence, no rails |
| `sanitarium_night.png` | same | Three colors separate: cold-white cage lamp (LIGHT_COLORS), warm office + fire orange, cold-blue vent light (the only contact with the Iron Shell); the strap glint is the one warm point in the cold |
| `yard_grey.png` | `night_explore.tscn` — L03 Freight Yard (48×40 m) | Whole level, neutral light: block facade, lit windows, fuse box, notice board, sodium lamps, fence, switch cabin, water tower |
| `yard_night.png` | same | Same layout with the `CanvasModulate` night grade + lamp/brazier glow |
| `marshalling_grey.png` | `night_marshalling.tscn` — L04 West Sorting Park (44×36 m) | Brick dispatch hall, platform canopy, hump tracks, boxcars, water tower, the three new outpost props |
| `marshalling_night.png` | same | Night grade; check that platform / window / brazier lights do not fight each other; zone bands white 0-9 / red 9-20 / black 20-36 |
| `manor_grey.png` | `night_manor.tscn` — L05 Pine Manor (46×38 m) | Manor facade, garage roller door, pine belt, steam pipe, iron gate |
| `manor_night.png` | same | Darkest level: driveway asphalt band, pine silhouettes, watchtower searchlight |
| `mine_grey.png` | `night_mine.tscn` — L07M Mine Shaft No.3 (46×34 m) | Rock facade in order: timber portal / shack / ore bin / headframe / blast cut; dummy tower reads as an outpost from afar, a mannequin up close; thermite (33.5 / 37.2) + detonator (29.5, 26.8); bands white 0-11 / red 11-21 / black 21-34, spawn & objective in the black |
| `mine_night.png` | same | The no-searchlight level: two lamps + two fires; the spore face's dull grey-green sheen must read without looking magical |
| `outpost_marshalling.png` | `night_marshalling.tscn` | 2× close-ups of sandbags (33.0, 9.2 m), ammo box (24.2, 5.6 m), weapon rack (12.4, 4.1 m); dashed box = sprite bounds, crosshair = ground anchor |
| `outpost_manor.png` | `night_manor.tscn` | 2× close-ups of sandbags (27.0, 12.6 m), ammo box (21.0, 6.2 m), weapon rack (9.2, 4.2 m) |
| `outpost_mine.png` | `night_mine.tscn` | 2× close-ups of dummy tower (38.5, 13.4 m, mannequin + pig-snout respirator, no light), spore face (36.5, 28.4 m), detonator rig (29.5, 26.8 m, guaranteed intel) |
| `combat_readout.png` | L03–L07M (shared) | Top-down noise radii (TT-33 26 m / sawn-off 38 m / Mosin 44 m), crowbar cone ±49° at 1.9 m, hit radii 0.40 / 0.46 / 0.52 m, arsenal table |

Close-up sheets (11–14) deliberately omit actors so a passing soldier cannot hide the prop;
the full-level sheets (1–10) keep them for scale.

---

## 一·补、网页版 / Web view

不想一张张点开的话，直接看 `docs/ui/acceptance.html`（三组：整关图 / 哨位特写 / 战斗读数，
每张下面写了这一张要看什么）。同目录下还有 `acceptance_standalone.html` —— 图片内嵌成 base64 的单文件，
离线、发给别人、双击都能开。

```bash
python3 -m http.server 8080 --bind 0.0.0.0 --directory docs/ui   # 然后开 http://localhost:8080/
python3 godot_project/tools/art_gen/build_acceptance_page.py      # 改了图之后重出页面
```

---

## 二、怎么复现 / Regenerate

```bash
cd godot_project/tools/art_gen
python3 render_preview.py            # 12 张整关图（6 关 × 中性光 / 夜色）+ 6 张特写与读数（含 zones_market）
python3 render_preview.py --crops    # 只重出特写与战斗读数
python3 render_preview.py --level coldstore
```

- 比例：1 m = 64 px，地面纵向压扁 ×0.62；整关图默认再缩到 0.62 输出。
- 底层数据：`godot_project/scenes/night_{explore,marshalling,manor,mine,market,coldstore}.tscn` 与 `godot_project/art/`。
- 改场景后**必须重跑**，这些图不会自动更新。

---

## 三、已知差异与边界 / Known gaps

1. **没有引擎实机**：战斗手感（后坐、命中反馈、声音）只能静态验证，`tests/night_combat_smoke.gd` 需要带引擎的机器跑
   `Godot_v4.7.2-stable_win64 --headless --path godot_project -s tests/night_combat_smoke.gd`。
2. **光照是近似**：只合成径向 / 光晕贴图，锥形光、遮挡阴影、bloom 都不在图上。
3. **图里没有 UI**：HUD、武器栏、提示条请看 `docs/ui/soviet_ui_board.html`。
4. **这三张场景仍是灰盒，没有出图**：`main.tscn`、`campaign.tscn`、`event_demo.tscn`
   目前还是 `_draw()` 画的占位，属于下一批要美术化的对象。
5. **分区色带是合成出来的**：引擎里由 `NightZoneField.gd` 每帧画（半透明矩形 + 虚线 + 雪面标签），
   预览图用 `render_preview.zone_layer()` 按同一份 `metadata/zones` 画在 `Ground` 之上。
   两边颜色 / 透明度写在两处，**改了一边就要同步另一边**（`NightZones.INFO` 与 `ZONE_STYLE`）。
6. **黑市那格的亮度被压过高光**：`zones_market.png` 里调车场的摊子紧挨油桶火，两个补光叠在合成里会烧成白块，
   所以对这一张做了 highlight rolloff；引擎里是渐变衰减，不会这么白。
7. 图上所有文字是拉丁 / 西里尔字母：环境里只有 DejaVu 字体，没有中文字库，写中文会变成方块。
