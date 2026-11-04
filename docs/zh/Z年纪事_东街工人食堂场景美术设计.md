# Z年纪事 · 第二幕《东街工人食堂 · 后厨（2-1 白昼的溃烂）》场景美术设计与接入（canteen）

> 对应总剧本 v4.2 场次 **2-1**（东街锁骨里的砍骨刀）与本幕设计 **L05 狭窄空间肉搏【锁骨卡刀】**。
> 关卡规格（出图权威）：`godot_project/tools/art_gen/levels/canteen.py`。
> 交付形态与 mine / market / coldstore 一致：本文件 = 色彩脚本 + 摆位表 + 接入清单 + 验收标准。

## 一、场景定位（设计锚点）

**「账面已清空」的恐怖。** 冷库的对照是「账面 0 人 vs 柱后 2 人」；食堂的对照是
**「账面已清空 vs 十九只碗」**——长条桌上十九只搪瓷碗缺口朝外摆成一圈，账说这楼没人了。

剧本锚点（场次 2-1 第七章）必须全部落景：

| 锚点 | 落点 |
|---|---|
| 十九只碗（19 名留守老铁路工） | `Table2`（十九只碗的主桌）+ `Table1/3`（光板桌）+ `Survivor_1` |
| 备餐台砧板上的**宽背生锈砍骨刀** | `PrepBoard`（guaranteed **blade** = 关键物资/武器） |
| 杂物间**单向窄门**会被冲开 | `NarrowDoor` + `wedge` 机关（LOCS hint2「窄门会被冲开」） |
| 40 度高烧谵妄的**瓦西里** | `Rabid_Vasily`（brute，home 就在窄门后） |
| 独眼老炊事员**费奥多尔** | `Survivor_0`（守着灶） |
| 送来的**黑麦糊** | `RyeVat`（还温着的晚饭） |
| 「清空」了的后库 | `BackCorpse` 尸袋（账面 vs 事实的反证） |

**室内关（管线第一次）**：`FENCE_Y = None`（build_scene 对无围栏关卡有护栏）；
整层混凝土地面（`SLAB_BAND = (3, 32)`），雪只从破门/破窗飘进来（入口冻雪泥）。

## 二、色彩脚本与光照设计

| 元素 | 色温 | 理由 |
|---|---|---|
| 礼堂两盏吊灯 + 火桶 | 暖琥珀（默认） | 有人给自己烧火：十九个人的体温 |
| 后厨灶火 | 暖橙 | 费奥多尔守着的灶——全楼最后一口气 |
| 后厨吊灯 | 暖琥珀偏暗 | 工作灯，不救后库的黑 |
| 后库 | 无光 | 「账面清空」——不给一点光 |

夜读验收一句话：**礼堂暖、后厨暗、后库黑；砧板上的刀是灰里唯一的冷铁高光。**

## 三、平面图与三带（44 × 32 米）

见 `levels/canteen.py` 文件头的 ASCII 平面图。三带轴 = **离十九只碗越远越黑**：

| 带 | y 范围 | 内容 |
|---|---|---|
| 白 | 22 ~ 32 | 礼堂：长桌×3（19 只碗）、火桶、老工友、南门入口 |
| 红 | 12 ~ 22 | 备餐间：配给箱、货架、铁柜 |
| 黑 | 0 ~ 12 | 后厨与后库：灶、砧板、黑麦糊桶、窄门、尸袋 |

## 四、摆位表（PROPS / 演员 / 容器 / 机关）

### 4.1 道具（id, 资产, 位置(米), 容器, 说明）

| id | 资产 | 位置 | 容器 | 说明 |
|---|---|---|---|---|
| `Stove` | `PRP_Canteen_Stove`（**新**） | (12.0, 5.0) | fire | 铸铁食堂灶（回温点 1） |
| `SteamPipe` | `PRP_SteamPipe_Long`（复用） | (22.0, 4.6) | — | 厨房蒸汽管（steam 声源） |
| `PrepBoard` | `PRP_CleaverBoard`（**新**） | (24.0, 8.2) | hidden，**guaranteed `blade`** | ★ 砧板 + 砍骨刀 |
| `RyeVat` | `PRP_RyeVat`（**新**） | (18.0, 9.8) | supply | ★ 黑麦糊大桶 |
| `NarrowDoor` | `PRP_NarrowDoor`（**新**） | (32.0, 4.6) | — | ★ 杂物间窄门（wedge 载体） |
| `BackLocker` | `PRP_Locker_ElectricCabinet`（复用） | (40.0, 7.5) | locker | 后库铁柜 |
| `BackCorpse` | `PRP_Corpse_Tarp`（复用） | (39.0, 10.6) | corpse | 尸袋——「账面已清空」的反证 |
| `SupplyCrates` | `PRP_SupplyCrates_Military`（复用） | (10.0, 15.5) | supply | 备餐间配给箱 |
| `PrepShelf` | `PRP_Crate_Wood_Stack`（复用） | (30.0, 16.5) | crate | 货架 |
| `LineLocker` | `PRP_Locker_ElectricCabinet`（复用） | (38.0, 19.0) | locker | 备餐线铁柜 |
| `Table2` | `PRP_Canteen_Table`（**新**） | (22.0, 25.0) | crate | 长条桌 + 长凳 + **十九只搪瓷碗**（缺口朝外一排） |
| `Table1/3` | `PRP_Canteen_BenchTable`（**新**） | (11/33, 25.0) | crate | 光板长条桌 + 长凳（碗都端在主桌） |
| `HallStove` | `PRP_Brazier_OilDrum`（复用） | (39.5, 27.5) | fire | 礼堂火桶（回温点 2） |
| `Stash` | `PRP_Crate_Wood_Stack`（复用） | (5.5, 28.5) | crate | 老工友的私货 |

### 4.2 演员（survivors = 2 人）

| 角色 | 位置 | 说明 |
|---|---|---|
| Fyodor（Survivor_0） | (13.5, 8.8) | 独眼老炊事员，守着灶；儿子在窄门后面烧到 40 度 |
| OldRailman（Survivor_1） | (15.0, 25.8) | 十九只碗的主人之一 |

### 4.3 巡逻 / 感染者 / 半人

| 类 | id | 位置/路径 | 说明 |
|---|---|---|---|
| 清杀队 | `OSK_Hall` | loop (6,26)→(38,26)→(38,18)→(6,18) | 清楼小队（清的是账） |
| 清杀队 | `OSK_Line` | pingpong (8,15)→(36,15) | 备餐线巡一遍 |
| 感染者 | `Rabid_Vasily` | home (32.5, 6.5) r2.0 **brute** | 40 度高烧的瓦西里 |
| 感染者 | `Rabid_Back` | home (40.5, 5.5) r1.8 | 后库先变的一只 |
| 半人 | — | 无 | 瓦西里的回退发生在剧情里（锁骨卡刀 QTE） |

### 4.4 机关（LevelBeats `mechanisms` → NightExplore `use_mechanism`）

```python
{"kind": "wedge", "node": "World/Props/NarrowDoor", "label": "杂物间窄门",
 "prompt": "用撬棍卡住窄门（别让他冲出来）", "radius": 2.4}
```

### 4.5 地表（bake_ground 配方）

混凝土整层（`SLAB_BAND = (3, 32)`）+ 砧板/尸袋周油污 GRAVEL + 灶与入口冻雪泥 SLUSH ×2
+ 踩出的路径 PATHS ×4（南门→各桌→备餐台→灶）+ 煤渣黑渍 TAR ×4。

## 五、资产清单（美术成果）

### 5.1 新增（本关专属）

| 资产 | 尺寸（约） | 生成器 | Prompt 规格书 |
|---|---|---|---|
| `TIL_Facade_Canteen_A` | 2944×600 | `gen_env._facade_canteen()` | §7.11 |
| `VFX_Facade_WindowGlow_Canteen` | 2944×770 | `_facade_glow()`（共用） | — |
| `TIL_Ground_NightCanteen_Baked` | 2944×1123 | `bake_ground()`（共用配方） | — |
| `PRP_CleaverBoard` | ~170×120 | `gen_props.cleaver_board()` | §7.11 |
| `PRP_Canteen_Stove` | ~220×180 | `gen_props.canteen_stove()` | §7.11 |
| `PRP_Canteen_Table` | ~340×130 | `gen_props.canteen_table()` | §7.11 |
| `PRP_Canteen_BenchTable` | ~340×130 | `gen_props.canteen_bench_table()` | §7.11 |
| `PRP_NarrowDoor` | ~180×190 | `gen_props.narrow_door()` | §7.11 |
| `PRP_RyeVat` | ~140×140 | `gen_props.rye_vat()` | §7.11 |

### 5.2 复用（manifest 条目从旧关 manifest 复制 JSON，不重出图）

CHR_01/03/04/05 · `PRP_Brazier_OilDrum` · `PRP_SteamPipe_Long` · `PRP_Locker_ElectricCabinet` ·
`PRP_Crate_Wood_Stack` · `PRP_SupplyCrates_Military` · `PRP_Corpse_Tarp` · `PRP_Survivor_Stand`（market）·
全部 VFX / AMB_*。

## 六、接入与验收

### 6.0 接入文件（一次性清单）

1. `levels/canteen.py` + `levels/__init__.py` 注册；
2. `gen_props.py` 5 件新道具 + `ALL` 注册；
3. `gen_env.py` `_facade_canteen()` + `facade_keys`/`bake_facade` 分派 + `check_levels.py` 立面白名单；
4. `build_scene.py`：`FENCE_Y = None` 护栏（室内关通用）；
5. `CampaignData.gd` LOCS 加 `scene` 字段；`LevelBeats.gd` 加 `LEVELS.canteen`（ДЕЛО № 0019）；
6. smoke：`night_level_smoke / night_zones_smoke / night_beats_smoke / campaign_smoke` 补 `_canteen()` 段；
7. `render_preview.py` SCENES/CROPS + `build_acceptance_page.py` SHEETS；文档同步（README / 三区与黑市 / Prompt 规格书 §7.11 / verify README）。

### 6.1 管线命令（`godot_project/tools/art_gen` 下）

```bash
python3 gen_assets.py --level canteen ground facade
python3 gen_assets.py --level canteen props --only PRP_CleaverBoard,PRP_Canteen_Stove,PRP_Canteen_Table,PRP_NarrowDoor,PRP_RyeVat
python3 build_scene.py --level canteen
python3 check_levels.py
```

### 6.2 验收标准（check_levels + 目测）

1. `check_levels.py` 六关之后第七关 PASS；
2. **「账面已清空 vs 十九只碗」一眼可读**：三张长桌的搪瓷碗圈 + 后库尸袋同框；
3. 砧板砍骨刀是灰里唯一的冷铁高光（`blade` 只在 `PrepBoard`）；
4. 窄门挂 `wedge` 机关；瓦西里的 brute 剪影堵在门后；
5. 暖色=有人给自己烧火（灶 / 火桶 / 吊灯）；后库不给光；
6. 道具画布无裁切（顶边检查 `np.flatnonzero(alpha.any(1))[0]`）；
7. 室内关无围栏、无轨道（`FENCE_Y = None`、`TRACKS = []`）不报错；
8. grey/night 一眼读「礼堂暖、后厨暗、后库黑」。

### 6.3 与概念图的对照

美术落点（剧本 2-1）：**06 号图**（撬棍卡门）；**05 号图**（梁诺夫/古丽娅/黑市商贩）为后续场次。
砍骨刀入骨的慢镜头与「……Пить……」属剧情演出，不在关卡静态资产里。
