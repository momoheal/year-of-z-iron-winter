# 剧情插图（CG）

由 `scripts/ui/StorySlides.gd` 播放，页面数据在 `scripts/data/CutsceneData.gd`。

命名约定（16:9，建议 1376×768 JPG）：

| 文件 | 用途 |
| --- | --- |
| `cg_intro_*.jpg` | 故事开场 |
| `cg_<剧情id>_scene.jpg` | 剧情对白框背后的场景图 |
| `cg_<剧情id>_c<选项序号>.jpg`（及 `…b` / `…c`） | 该抉择之后的余波幻灯 |

缺图的页会自动退回人物胸像，所以**往本目录补图即可生效，不用改代码**。

## 结局与余波 CG（五种结局）

结局只按 CampaignSim 的五个键显示：A、B、C、True Ending α、True Ending β。结局页直接显示主图；“回看结局与余波”按钮播放对应幻灯。图像与余波页都由 scripts/data/CutsceneData.gd 的 ENDING_SCENES 显式登记。

| 结局 | 主图 | 余波图 | 接入状态 |
| --- | --- | --- | --- |
| A · 留在 602 | cg_ending_closed_car_firelight_alt.jpg | cg_aftermath_a_602.jpg | 已接入 ENDING_A_RETURN_HOME |
| B · 荒诞解放 | cg_ending_broadcast_breach_302_alt.jpg | cg_aftermath_b_release.jpg | 已接入 ENDING_B_FLAWED_LIBERATION |
| C · 麻木 | cg_ending_crawl_back_cellar_alt.jpg | cg_aftermath_c_numb.jpg | 已接入 ENDING_C_NUMBNESS |
| True Ending α · 你好，拉娜 | cg_ending_true_alpha_hello_lana.jpg | cg_aftermath_true_alpha.jpg | 已接入 TRUE_ALPHA_HELLO_LANA |
| True Ending β · 荒原之火 | cg_ending_true_beta_outland_fire.jpg | cg_aftermath_true_beta.jpg | 已接入 TRUE_BETA_OUTLAND_FIRE |

2026-11-18 新增五张结局专属余波图，均为 **1376×768 JPG**；每张均配有同名 `.prompt.txt`。五个结局的 `ENDING_SCENES.aftermath` 已改为一对一图片，不再共用 `cg_aftermath_pasha_crag_mercy.jpg`；C 结局也已补上余波。原始 PNG、实际提示词和导出校验保存在 `art/generation_runs/2026-11-18/aftermath/`。

当前五个结局主图分别是 closed_car_firelight、broadcast_breach_302、crawl_back_cellar、true_alpha_hello_lana、true_beta_outland_fire，均由 `ENDING_SCENES` 接入。`cg_ending_sealed_004_car_alt.jpg` 仍保留在候选表，未被五个结局引用。此前新增的 1376×768 CG（α 重逢、β 荒原火光、帕沙的最后施予）原始 PNG 与提示词保存在 `art/generation_runs/2026-11-18/ending_cg/`。其余 64 项美术变体仍作为候选，逐项列在下方。

## 早期核心页（原 22 张清单）

- 开场：`cg_intro_city` · `cg_intro_mother` · `cg_intro_lana` · `cg_intro_vent`
- 冷库：`cg_coldstore_scene` · `cg_coldstore_c0` · `cg_coldstore_c1`
- 调车场：`cg_yard_scene` · `cg_yard_c0`
- 食堂：`cg_canteen_scene` · `cg_canteen_c0` · `cg_canteen_c0b`
- 黑市：`cg_market_scene` · `cg_market_c0` · `cg_market_c1` · `cg_market_c2`
- 疗养院：`cg_sanitarium_scene` · `cg_sanitarium_c0`
- 庄园：`cg_manor_scene` · `cg_manor_c0`
- 西站：`cg_marshalling_scene` · `cg_marshalling_c0b`

## 余波页补图状态

市场与疗养院的可选余波图已在目录中；本次补齐最后两张空缺：`cg_marshalling_c0.jpg` 与 `cg_manor_c0b.jpg`。新增文件为 1376×768 JPG，提示词和哈希见 `asset_batch_manifest_2026-11-17.json`。

新图第一次用编辑器打开工程（或跑 `godot --headless --import`）时会自动生成 `.import`。


## 新增分支余波（2026-11-17）

| 文件 | 画面 | 提示词 |
| --- | --- | --- |
| `cg_marshalling_c0.jpg` | 23:00 调车场死令、工具箱和雪夜货场 | `CG_Marshalling_C0.prompt.txt` |
| `cg_manor_c0b.jpg` | 庄园焚毁台账、腹透液、胶卷与焦黑雪 | `CG_Manor_C0b.prompt.txt` |

两张图按剧情页数据的文件名约定放入本目录，缺图回退规则保持不变。

## 新增主线画面（2026-11-16）

下列场景图统一导出为 **1376×768 JPG**；原始生成 PNG 保留在 `art/generation_runs/2026-11-16-assets/`。广播点旧图已归档到 `art/generation_runs/2026-11-16-assets/CG_Broadcast_Location/generated.png`，剧情运行时统一读取 `cg_broadcast_scene.jpg`。

| 文件 | 场景 |
| --- | --- |
| `cg_pasha_watchtower_scene.jpg` | 帕沙哨塔与假人哨塔事件 |
| `cg_apartment_exchange_scene.jpg` | 公寓配给交接 |
| `cg_mine_sporeface_scene.jpg` | 矿坑孢子层发现 |
| `cg_mine_detonator_scene.jpg` | 起爆室与铝热剂抉择 |
| `cg_fire_rescue_scene.jpg` | 火场托孤 |
| `cg_eaglecliff_derailment_scene.jpg` | 004 号车厢在鹰嘴崖脱轨 |
| `cg_station_buran_scene.jpg` | 站场中的布拉风号装甲列车 |
| `cg_broadcast_siege_scene.jpg` | 302 号广播塔围攻 |
| `cg_broadcast_testimony_scene.jpg` | 终局播报与证词 |

`CutsceneData.scene_image()` 为这些场景 ID 提供了显式映射；鹰嘴崖脱轨图也已接入 `marshalling:0` 的最后一页。其余图片目前作为可调用场景背景资产保留，尚无对应的剧情触发器。

## 事实与剧情复核（2026-11-17）

- `pasha_watchtower` 使用 `cg_pasha_watchtower_scene_v2.jpg`：修正旧候选提示词把时代误写为 1930 年代的问题；按架空后苏联西伯利亚铁路工业城设定重做，并将帕沙校正为设定中的 18 岁男性新兵，保留假人哨塔与检查站情节。
- `mine_sporeface` 使用 `cg_mine_sporeface_scene_alt.jpg`：突出爆破后冻土断面、灰黑矿物尘层与封存样本；旧图留作档案备选。
- `fire_rescue` 使用 `cg_fire_rescue_scene_alt.jpg`：把祖母将孩子交给阿列克谢、同时递出配给券的动作拍清楚；旧图留作档案备选。
- 其他候选图继续保留在美术档案，未因“文件存在”就自动替换剧情主图。
- 已逐张目视复核 `80_maps` 中 17 张正式地图底图；未发现明显违背剧情地点或后苏联铁路工业设定的作图。

## 一致性约定（重画或补图时照此写提示词，并把参考图一起喂进去）

- 阿列克谢：灰色毛皮护耳帽（无帽徽）、圆框眼镜、深炭灰棉袄配灰毛领。参考 `PRT_Aleksei_Concept.png`、`../opening_dispatch.png`
- 伊万：白色络腮胡、深蓝铁路大檐帽（红帽墙）、深蓝制服配红金肩章。参考 `PRT_Ivan_Calm.png`
- 费奥多尔 / 安娜 / 古丽娅 / 灰烬：以 `art/10_characters/portraits/` 里的胸像为准
- 列车：墨绿色铆接装甲机车，斜面装甲、车头雪犁、侧面红星。参考 `cg_yard_scene.jpg`、`../opening_dispatch.png`
- 画面里不出现任何文字、型号、商标


## 新增候选 CG 变体（2026-11-17）

| 文件 | 画面 | 提示词 |
| --- | --- | --- |
| `cg_marshalling_c0c.jpg` | 调车场余波备选：雪夜守车旁的维修工具箱与抽象账目（候选美术变体，尚未接入剧情数据） | `cg_marshalling_c0c.prompt.txt` |
| `cg_manor_c0c.jpg` | 庄园证据余波备选：胶卷、腹透液、焦黑雪窗与焚毁账本（候选美术变体，尚未接入剧情数据） | `cg_manor_c0c.prompt.txt` |
| `cg_canteen_c0c.jpg` | 食堂余波备选：老厨师把亡子的旧袄披到阿列克谢肩上（候选美术变体，尚未接入剧情数据） | `cg_canteen_c0c.prompt.txt` |
| `cg_market_c1d.jpg` | 黑市余波备选：伊万留下的帆布手套、路线纸与雪中脚印（候选美术变体，尚未接入剧情数据） | `cg_market_c1d.prompt.txt` |
| `cg_sanitarium_c0c.jpg` | 疗养院余波备选：开启的笼门、被松开的束带与雪夜出口（候选美术变体，尚未接入剧情数据） | `cg_sanitarium_c0c.prompt.txt` |
| `cg_coldstore_c0b.jpg` | 冷库救灰犬余波备选：解下断铁丝项圈后喂灰犬黑麦面包（候选美术变体，尚未接入剧情数据） | `cg_coldstore_c0b.prompt.txt` |
| `cg_coldstore_c1b.jpg` | 冷库弃犬余波备选：未被递出的黑麦面包与留在收发亭旁的灰犬（候选美术变体，尚未接入剧情数据） | `cg_coldstore_c1b.prompt.txt` |
| `cg_yard_c0b.jpg` | 第一关货场余波备选：阿列克谢护住编组单，探照灯扫过第三节装甲车厢（候选美术变体，尚未接入剧情数据） | `cg_yard_c0b.prompt.txt` |
| `cg_broadcast_scene_alt_yelena.jpg` | 叶莲娜广播点默认过场图：金发辫、合身冬衣、手部与电报机关系清楚 | `cg_broadcast_scene_alt_yelena.prompt.txt` |
| `cg_eaglecliff_derailment_alt.jpg` | 鹰嘴崖脱轨救援备选：阿列克谢从装甲车厢扶下拉娜（候选美术变体，尚未接入剧情数据） | `cg_eaglecliff_derailment_alt.prompt.txt` |
| `cg_fire_rescue_scene_alt.jpg` | 火场托孤备选：阿列克谢接住女孩，柳德米拉递出熏黑配给券（候选美术变体，尚未接入剧情数据） | `cg_fire_rescue_scene_alt.prompt.txt` |
| `cg_broadcast_testimony_scene_alt.jpg` | 终局播报备选：金发辫播报者、阿列克谢与听众同场（候选美术变体，尚未接入剧情数据） | `cg_broadcast_testimony_scene_alt.prompt.txt` |
| `cg_apartment_exchange_scene_alt.jpg` | 公寓交接备选：阿列克谢安慰母亲，姐姐正在外勤医疗支援（候选美术变体，尚未接入剧情数据） | `cg_apartment_exchange_scene_alt.prompt.txt` |
| `cg_mine_sporeface_scene_alt.jpg` | 3号矿坑孢子层发现备选：记录样本、显出灰黑矿物层（候选美术变体，尚未接入剧情数据） | `cg_mine_sporeface_scene_alt.prompt.txt` |
| `cg_station_buran_scene_alt.jpg` | 布拉风号进站备选：更宽的站台视角、装甲列车与冬夜信号灯（候选美术变体，尚未接入剧情数据） | `cg_station_buran_scene_alt.prompt.txt` |
| `cg_broadcast_siege_scene_alt.jpg` | 广播塔围攻备选：雪夜信号塔、金发辫电报员和山脊搜索灯（候选美术变体，尚未接入剧情数据） | `cg_broadcast_siege_scene_alt.prompt.txt` |
| `cg_pasha_watchtower_scene_alt.jpg` | 帕沙哨塔备选：雪地检查站、帕沙与临时搭成的假哨兵（候选美术变体，尚未接入剧情数据） | `cg_pasha_watchtower_scene_alt.prompt.txt` |
| `cg_mine_detonator_scene_alt.jpg` | 矿坑起爆室备选：关闭的工业控制箱、矿工与作出决断的阿列克谢（候选美术变体，尚未接入剧情数据） | `cg_mine_detonator_scene_alt.prompt.txt` |
| `cg_market_zakhar_ledger_alt.jpg` | 扎哈尔黑市账簿备选：蓝袖章核算员查看账本与搜刮袋，巡逻灯逼近（候选美术变体，尚未接入剧情数据） | `cg_market_zakhar_ledger_alt.prompt.txt` |
| `cg_eaglecliff_004_plaque_recovery_alt.jpg` | 鹰嘴崖 004 号铭牌发现备选：阿列克谢与列车长伊万检查雪中脱轨车厢（候选美术变体，尚未接入剧情数据） | `cg_eaglecliff_004_plaque_recovery_alt.prompt.txt` |
| `cg_zakhar_quota_betrayal_alt.jpg` | 扎哈尔配额背叛备选：账簿、蓝袖章、配额窗口与等待中的 OSK 官员（候选美术变体，尚未接入剧情数据） | `cg_zakhar_quota_betrayal_alt.prompt.txt` |
| `cg_broadcast_yelena_goldbraid_alt2.jpg` | 广播点叶莲娜构图备选：金发辫、较体面的冬衣、手与电报机关系清楚（候选美术变体，尚未接入剧情数据） | `cg_broadcast_yelena_goldbraid_alt2.prompt.txt` |
| `cg_sanitarium_anna_calm_patients_alt.jpg` | 疗养院安娜能力候选：她平静安抚门后的发热者，阿列克谢与灰烬在后景（候选美术变体，尚未接入剧情数据） | `cg_sanitarium_anna_calm_patients_alt.prompt.txt` |
| `cg_marshalling_yelena_patrol_pause_alt.jpg` | 调车场叶莲娜能力候选：她通过隐蔽电台让 OSK 巡逻短暂停在信号柱旁（候选美术变体，尚未接入剧情数据） | `cg_marshalling_yelena_patrol_pause_alt.prompt.txt` |
| `cg_coldstore_ash_recruitment_alt.jpg` | 冷库灰犬加入备选：喂食、断开的铁丝项圈与犬只靠近（候选美术变体，尚未接入剧情数据） | `cg_coldstore_ash_recruitment_alt.prompt.txt` |
| `cg_broadcast_yelena_manor_route_alt.jpg` | 叶莲娜广播点发现备选：她指向窗外松林庄园与通路（候选美术变体，尚未接入剧情数据） | `cg_broadcast_yelena_manor_route_alt.prompt.txt` |
| `cg_manor_yelena_arrival_alt.jpg` | 松林庄园入口备选：叶莲娜在广播点后与阿列克谢、安娜汇合（候选美术变体，尚未接入剧情数据） | `cg_manor_yelena_arrival_alt.prompt.txt` |
| `cg_apartment_mother_reassurance_alt.jpg` | 公寓母子过场备选：阿列克谢向母亲隐瞒妹妹被捕，解释她在外支援医疗（候选美术变体，尚未接入剧情数据） | `cg_apartment_mother_reassurance_alt.prompt.txt` |
| `cg_greenhouse_seed_cache_discovery_alt.jpg` | 温室种子储藏发现备选：黑麦种子罐、仅存的嫩芽与抉择现场（候选美术变体，尚未接入剧情数据） | `cg_greenhouse_seed_cache_discovery_alt.prompt.txt` |
| `cg_marshalling_ivan_dispatch_alt.jpg` | 调车场伊万调度备选：列车长制服、路线时刻表、信号牌与站场（候选美术变体，尚未接入剧情数据） | `cg_marshalling_ivan_dispatch_alt.prompt.txt` |
| `cg_yard_searchlight_cover_route_alt.jpg` | 第一关货场潜行候选：阿列克谢躲在低矮雪掩体后，探照灯扫过开放轨道（候选美术变体，尚未接入剧情数据） | `cg_yard_searchlight_cover_route_alt.prompt.txt` |
| `cg_birch_ash_tracking_scene_alt.jpg` | Birch 松林追踪备选：阿列克谢和无项圈灰犬沿足迹接近猎人小屋与补给箱（候选美术变体，尚未接入剧情数据） | `cg_birch_ash_tracking_scene_alt.prompt.txt` |
| `cg_boiler_steamline_discovery_alt.jpg` | 锅炉房蒸汽管线发现备选：维修人员、管线冷凝气与热源修复抉择（候选美术变体，尚未接入剧情数据） | `cg_boiler_steamline_discovery_alt.prompt.txt` |
| `cg_archive_record_discovery_alt.jpg` | 档案室线索发现备选：阿列克谢与帕维尔在铁柜中找到霜封档案（候选美术变体，尚未接入剧情数据） | `cg_archive_record_discovery_alt.prompt.txt` |
| `cg_underpass_shelter_meeting_alt.jpg` | 地下通道临时避难点备选：居民围着暖炉桶短暂休息，隧道仍在远处延伸（候选美术变体，尚未接入剧情数据） | `cg_underpass_shelter_meeting_alt.prompt.txt` |
| `cg_workshop_mechanic_repair_alt.jpg` | 机修车间备选：老维修工与阿列克谢合力疏通工具车（候选美术变体，尚未接入剧情数据） | `cg_workshop_mechanic_repair_alt.prompt.txt` |
| `cg_canteen_last_ration_scene_alt.jpg` | 食堂最后一份口粮备选：排队居民、老厨师与留给孩子的一碗热汤（候选美术变体，尚未接入剧情数据） | `cg_canteen_last_ration_scene_alt.prompt.txt` |
| `cg_market_distant_trade_point_alt.jpg` | 黑市远离巡逻点备选：雪堤后交易棚与远处巡逻探照灯（候选美术变体，尚未接入剧情数据） | `cg_market_distant_trade_point_alt.prompt.txt` |
| `cg_yard_chernov_father_son_intro_alt.jpg` | 货场父子事件开场备选：阿列克谢、明确登场的切尔诺夫中士与父子（候选美术变体，尚未接入剧情数据） | `cg_yard_chernov_father_son_intro_alt.prompt.txt` |
| `cg_broadcast_final_dawn_gathering_alt.jpg` | 302 广播塔终局破晓备选：广播者、拉娜、安娜和铁路居民听完证词（候选美术变体，尚未接入剧情数据） | `cg_broadcast_final_dawn_gathering_alt.prompt.txt` |
| `cg_market_halfwolf_trader_alt.jpg` | 黑市半狼交易者备选：远离巡逻灯的偏僻摊位与谨慎交涉（候选美术变体，尚未接入剧情数据） | `cg_market_halfwolf_trader_alt.prompt.txt` |
| `cg_sanitarium_escape_corridor_alt.jpg` | 疗养院逃离备选：安娜、阿列克谢与灰烬穿过敞开的牢门向侧廊撤离（候选美术变体，尚未接入剧情数据） | `cg_sanitarium_escape_corridor_alt.prompt.txt` |
| `cg_mine_no3_evacuation_alt.jpg` | 3 号矿坑撤离备选：矿工从木撑巷道带出封存证据箱（候选美术变体，尚未接入剧情数据） | `cg_mine_no3_evacuation_alt.prompt.txt` |
| `cg_station_buran_arrival_alt2.jpg` | 布拉风号进站备选：墨绿铆接装甲列车、雪犁车头与伊万手提信号灯（候选美术变体，尚未接入剧情数据） | `cg_station_buran_arrival_alt2.prompt.txt` |
| `cg_eaglecliff_lana_004_rescue_alt2.jpg` | 鹰嘴崖 004 车厢救援备选：阿列克谢打开车门，拉娜平安坐在车厢内（候选美术变体，尚未接入剧情数据） | `cg_eaglecliff_lana_004_rescue_alt2.prompt.txt` |
| `cg_intro_city_winter_dusk_alt.jpg` | 开场城市雪夜备选：窗前阿列克谢眺望铁路、烟囱和无线电塔（候选美术变体，尚未接入剧情数据） | `cg_intro_city_winter_dusk_alt.prompt.txt` |
| `cg_ending_sealed_004_car_alt.jpg` | 结局 A 场景备选：阿列克谢在雪地离开封存车厢（候选，未接入剧情数据） | `cg_ending_sealed_004_car_alt.prompt.txt` |
| `cg_ending_crawl_back_cellar_alt.jpg` | 结局 C 主图：阿列克谢独自从排污涵洞爬回空地窖（已接入 ENDING_C_NUMBNESS） | `cg_ending_crawl_back_cellar_alt.prompt.txt` |
| `cg_ending_closed_car_firelight_alt.jpg` | 结局 A 主图远景：雪谷中封闭的 004 车厢被火光照亮，不展示伤害（已接入 ENDING_A_RETURN_HOME） | `cg_ending_closed_car_firelight_alt.prompt.txt` |
| `cg_zakhar_salvage_spotted_alt.jpg` | 扎哈尔搜刮被发现备选：蓝袖章搜刮员装袋时被远处巡逻灯照到（候选美术变体，尚未接入剧情数据） | `cg_zakhar_salvage_spotted_alt.prompt.txt` |
| `cg_ending_broadcast_breach_302_alt.jpg` | 结局 B 主图：阿列克谢背着拉娜与切尔诺夫中士带领铁路工人冲向 302 高地（已接入 ENDING_B_FLAWED_LIBERATION） | `cg_ending_broadcast_breach_302_alt.prompt.txt` |
| `cg_broadcast_pavel_switch_repair_alt.jpg` | 302 广播塔帕维尔抢修备选：绝缘管钳暂时接回发射机，拉娜与安娜守在麦克风旁（候选美术变体，尚未接入剧情数据） | `cg_broadcast_pavel_switch_repair_alt.prompt.txt` |
| `cg_marshalling_last_train_departure_alt.jpg` | 雪夜末班列车离站备选：调车场信号灯与逐渐远去的车尾（候选美术变体，尚未接入剧情数据） | `cg_marshalling_last_train_departure_alt.prompt.txt` |
| `cg_lana_external_medical_support_memory_alt.jpg` | 拉娜外部医疗支援回忆候选：她在城外救助点送去干净布料（候选美术变体，尚未接入剧情数据） | `cg_lana_external_medical_support_memory_alt.prompt.txt` |
| `cg_companion_estrangement_harsh_route_alt.jpg` | 灭绝路线伙伴观感备选：安娜、金发辫广播员、伊万与灰烬和阿列克谢保持距离（候选美术变体，尚未接入剧情数据） | `cg_companion_estrangement_harsh_route_alt.prompt.txt` |
| `cg_apartment_mother_waiting_window_alt.jpg` | 公寓等待母亲备选：她望着窗外，阿列克谢带着空白便条停在门边（候选美术变体，尚未接入剧情数据） | `cg_apartment_mother_waiting_window_alt.prompt.txt` |
| `cg_broadcast_lana_anna_testimony_close_alt.jpg` | 广播塔证词近景备选：拉娜发言，安娜守在碳精麦克风旁（候选美术变体，尚未接入剧情数据） | `cg_broadcast_lana_anna_testimony_close_alt.prompt.txt` |
| `cg_broadcast_city_listeners_dawn_alt.jpg` | 终局播报备选：破晓前，居民与工人停下手中事聆听电台证词（候选美术变体，尚未接入剧情数据） | `cg_broadcast_city_listeners_dawn_alt.prompt.txt` |
| `cg_broadcast_siege_exterior_alt2.jpg` | 302 广播塔围攻远景备选：塔身、低矮木质防线与远处探照灯（候选美术变体，尚未接入剧情数据） | `cg_broadcast_siege_exterior_alt2.prompt.txt` |
| `cg_mine_boiko_rescue_alt.jpg` | 3 号矿坑博伊科救助备选：阿列克谢扶起矿工，安娜准备医疗包（候选美术变体，尚未接入剧情数据） | `cg_mine_boiko_rescue_alt.prompt.txt` |
| `cg_fire_rescue_lyudmila_handoff_close_alt.jpg` | 火场托孤近景备选：柳德米拉把平安裹好的外孙女交给阿列克谢（候选美术变体，尚未接入剧情数据） | `cg_fire_rescue_lyudmila_handoff_close_alt.prompt.txt` |
| `cg_underpass_dawn_evacuation_alt.jpg` | 地下通道破晓撤离备选：居民走出隧道，安娜与灰烬随行（候选美术变体，尚未接入剧情数据） | `cg_underpass_dawn_evacuation_alt.prompt.txt` |
| `cg_boiler_heat_returns_residents_alt.jpg` | 锅炉恢复供热备选：维修工检查阀门，居民在安全的暖管旁缓过来（候选美术变体，尚未接入剧情数据） | `cg_boiler_heat_returns_residents_alt.prompt.txt` |
| `cg_workshop_lights_return_alt.jpg` | 车间恢复灯火备选：维修工检查车床传动，工人围在暖炉旁（候选美术变体，尚未接入剧情数据） | `cg_workshop_lights_return_alt.prompt.txt` |
| `cg_market_zakhar_osk_visual_contrast_alt.jpg` | 黑市扎哈尔与 OSK 对照备选：蓝袖章核算员、深色无徽巡逻帽与账簿（候选美术变体，尚未接入剧情数据） | `cg_market_zakhar_osk_visual_contrast_alt.prompt.txt` |
| `cg_station_workers_listen_broadcast_alt.jpg` | 车站收听证词备选：列车长伊万和站台工人听到凌晨播报（候选美术变体，尚未接入剧情数据） | `cg_station_workers_listen_broadcast_alt.prompt.txt` |
| `cg_companions_trust_compassionate_route_alt.jpg` | 仁慈路线伙伴信任备选：安娜、叶莲娜、铁路工人、维修工与灰烬仍靠近阿列克谢（候选美术变体，尚未接入剧情数据） | `cg_companions_trust_compassionate_route_alt.prompt.txt` |
| `cg_manor_vault_evidence_yelena_alt.jpg` | 松林庄园保险库备选：阿列克谢与金发辫叶莲娜发现底片和焦黑账本（候选美术变体，尚未接入剧情数据） | `cg_manor_vault_evidence_yelena_alt.prompt.txt` |

## 2026-11-19 新增过场资产（已接入）

| 文件 | 用途与触发 |
| --- | --- |
| `cg_canteen_vasily_qte_fyodor_v2.png` | 食堂卡刀 QTE 与回访；右侧人物为瓦西里的父亲费奥多尔，非女性人物。 |
| `cg_manor_yelena_zhukov_confront_v1.png` | 叶莲娜同行时的父女对峙与庄园结果页；她缺席时切回通用庄园 CG。 |
| `cg_mine_no3_wall_inscription_v1.png` | 靠近 3 号矿坑爆破断面时播放刻字幻灯。 |
| `cg_fire_stairwell_neighbors_breach_v1.png` | 帕维尔不同行时，住户合力破门的火场分支。 |
| `cg_fire_pavel_cutting_torch_v1.png` | 帕维尔同行时，由他切开焊死横梁的火场分支。 |
| `cg_boxcar03_survivors_reveal_v1.png` | 鹰嘴崖打开第三节车厢后的幸存者与拉娜揭示页。 |
| `cg_fire_ash_guides_jana_v1.png` | 灰烬同行时，灰犬把佳娜带向避风处的专属火场页。 |
| `cg_redzone_mother_gate_v1.png` | 首次靠近货场锅炉房通风口时的红区目击：退烧母亲隔门呼救；同图变焦承接对白。 |
| `cg_redzone_mother_osk_v1.png` | 清杀队在探照灯下逼近母亲。 |
| `cg_redzone_mother_aftermath_v1.png` | 枪击后的雪地余波，母亲倒地、铜钥匙落在沟边。 |
| `cg_redzone_mother_scales_v1.png` | 末页只呈现钥匙、雪水和脱落鳞屑，不出现人形，避免产生死者复活的错觉。 |


## 游戏内查看

战役界面顶栏的「美术档案」按分页展示本目录的全部 CG 与备选图。叶莲娜广播点剧情已改用金发辫清晰、手部与电报机关系明确的 `cg_broadcast_scene_alt_yelena.jpg`；其他候选图仍可在档案内查看，未被擅自插入对白页。
