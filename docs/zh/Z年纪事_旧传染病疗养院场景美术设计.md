# 《Z年纪事 · 凛冬铁轨》旧传染病疗养院 · 地下室（L06）场景美术设计

> **L 码**：**L06**（剧本 v4.2 舞台设计「L06 暴雪公路盲射误杀 + 地底铁笼安娜救人」）。
> **对应剧本**：**3-2「灰鳞病回退」**——地底铁笼、安娜（0419）的两根皮带、铁壳号抛病历单。
> **场景**：`res://scenes/night_sanitarium.tscn`（由 `build_scene.py --level sanitarium` 生成，163 节点）。
> **出图**：`levels/sanitarium.py`（44×30 m 室内关，出过图的权威版本）→ `gen_assets.py`。
> **危险度 4 / 夜长 110 分钟 / 寒冷 0.8**；**prize = `asp`**（半片阿司匹林的回声）。

---

## 1. 这一关在讲什么

> 暴雪夜，「铁壳号」贴路基驶过旧传染病疗养院。地下室里，退烧的人开始**掉鳞屑**——
> 灰鳞病在回退，账本不许它回退。**档案号 0419 的姑娘安娜**用两根旧皮带把自己的双手
> 死死捆在铁架床栏杆上，硬生生熬过了退烧前最后一次神经风暴。梁诺夫医生和古丽娅守着
> 最后一点药——药柜里还有**半片阿司匹林的同类**。

| 剧本锚点 | 落到场景里 | 场景资产 |
|---|---|---|
| **0419 安娜**：两根旧皮带自捆铁架床熬过神经风暴 | ★`CageBed` (23, 5)：铁架床 + **两根磨亮的旧皮带**缠在栏杆上 | `PRP_CageBed`（钱道具） |
| **灰鳞病回退**：掉鳞屑、瞳孔回色 | ★`Half_Cage0442` (31, 6.2)：笼3 的回退半人（CHR_04 半人表） | 半人角色 |
| **梁诺夫 & 古丽娅**（师徒双医） | `Survivor_1/2` (13.5/17.5, 23.8/24.2)：读片灯箱旁 | `PRP_Survivor_Stand` |
| **半片阿司匹林的回声** | ★`MedCabinet` (10, 23.5)：钢药柜 **guaranteed=`asp`** | `PRP_MedCabinet` |
| **铁笼区**（地底铁笼） | `Cage01-04` (8/15/31/38, 5)：钢筋铁笼列，笼里关着没熬过的人 | `PRP_IronCage`×4 |
| **换气铁窗 + 铁壳号广轨弯道** | 立面 `vent_x=22`：一排**带栏换气高窗**（窗外冷蓝 = 外界的唯一联系） | `TIL_Facade_Sanitarium_A` |
| **第三车闷罐抛病历单** | `XrayBoard` (16, 23)：读片灯箱 + 病历单（intel 容器 briefcase 类） | `PRP_XrayLightbox` |
| **LOCS hint「有人被皮带捆在铁架床上」** | 铁架床锚点 + wedge 机关：`CageGate` (22, 11) **撬棍卡死笼区铁栅门** | `PRP_CageGate` |

## 2. 三带与色彩脚本

**轴 = 离医生的工作区越远越黑**（室内反向轴：白区在南、黑区在北）：

| 色带 | y（米） | 是什么 | 夜里读法 |
|---|---|---|---|
| **白区 · 安全区** | 21 – 30 | 医生工作区：药柜 / 读片灯箱 / 火炉 / 楼梯间 | 暖灯 + 火橙：活着的人在照顾人，可以站定了搜包 |
| **红区 · 管制带** | 12 – 21 | 走廊：收集班走的路 + 蒸汽管 | 微暖过道光：禁止停留 |
| **黑区 · 沉降带** | 0 – 12 | 铁笼区：笼列 / 铁架床 / 回退半人 / 窄门深处 | **笼区冷白吊灯**（LIGHT_COLORS）：掉鳞屑的地方 |

色彩脚本（夜间）：
- **冷白**：笼区吊灯（`lamp_cage`，LIGHT_COLORS 覆盖 `(0.72, 0.85, 1.0)`）——临床的、无情的；
- **暖黄**：医生工作区灯（`lamp_office`）+ 火炉 / 火桶橙——「照顾」的两种暖；
- **冷雾蓝**：换气铁窗透进来的暴风雪光——与外界（铁壳号）的唯一联系；
- **暖缝**：铁架床上皮带的那点反光——冷白深处唯一一点暖（「有人熬过了第四天」的证词）。

## 3. 立面与地面

- **立面** `TIL_Facade_Sanitarium_A`（2816×600，`gen_env._facade_sanitarium()`）：
  深灰混凝土墙 + 霉斑剥落 + **一排带栏换气高窗**（`vent_x=22` 簇，窗外冷蓝）+
  重型铁门（`door_x=8`，门上暗红观察窗）+ 竖管束（`pipe_x=36`）+ 墙脚漂白粉消毒带。
- **地面** `TIL_Ground_NightSanitarium_Baked`：**`INTERIOR=True` 室内混凝土地面**打底
  （板缝 + 发丝裂 + 漆线）+ 石灰渍（`TAR_STAINS`）+ 霉斑 + 冻雪泥（`SLUSH`：楼梯间飘雪 + 火边融水）+ 踩出的路径。

## 4. 道具与摆位（`levels/sanitarium.py` 的 PROPS / LIGHTS / PATROLS 为准）

| 节点 | 资产 | 位置（米） | 容器 | 说明 |
|---|---|---|---|---|
| `Cage01/02/04` | `PRP_IronCage`（**新**） | (8/15/38, 5) | hidden | 钢筋铁笼：竖栏 + 挂链锁；1/2/4 号笼关着感染者（4 号壮硕） |
| ★`CageBed` | `PRP_CageBed`（**新**） | (23, 5) | hidden | **安娜的铁架床 + 两根磨亮的旧皮带**（钱道具） |
| `Cage03` | `PRP_IronCage`（**新**） | (31, 5) | hidden | 回退半人 0442 关在这一笼 |
| `ChemDrum` | `PRP_ChemDrum`（**新**） | (5, 9.5) | crate | 石灰 / 消毒桶 |
| ★`CageGate` | `PRP_CageGate`（**新**） | (22, 11) | — | **笼区铁栅门**（wedge 机关载体） |
| `SteamPipe` | `PRP_SteamPipe_Long` | (22, 13.5) | — | 走廊暖气管（steam 声源） |
| `CorridorCorpse` | `PRP_Corpse_Tarp` | (12, 16.5) | corpse | 盖着的——没熬过第四天的 |
| `CorridorCrate` | `PRP_Crate_Wood_Stack` | (34, 17.5) | crate | 走廊堆箱 |
| ★`MedCabinet` | `PRP_MedCabinet`（**新**） | (10, 23.5) | medcab | **guaranteed=`asp`**（半片阿司匹林的回声） |
| `XrayBoard` | `PRP_XrayLightbox`（**新**） | (16, 23) | briefcase | 读片灯箱 + 病历单（intel） |
| `SampleFridge` | `PRP_ColdStore_Chest` | (28, 24) | fridge | 标本冷柜 |
| `ClinicStove/ClinicBrazier` | `PRP_Brazier_OilDrum` | (35, 22.5)/(39.5, 25.5) | — | 火炉 + 火桶（**双回温点**） |
| `Locker` | `PRP_Locker_ElectricCabinet` | (6, 26.5) | locker | 铁柜 |

- **幸存者 3**：安娜 (22.3, 5.8)（床边）+ 梁诺夫 (13.5, 23.8) + 古丽娅 (17.5, 24.2)。
- **清杀队 2**：`OSK_Cages`（笼列 loop）+ `OSK_Corridor`（走廊 pingpong）——收集班。
- **回温**：need=1（264 秒 × 0.8 = 211），实给 2（火炉 + 火桶）。
- **AMBIENCE**：`wind / fire / steam / buzz` 四路。
- **无探照灯、无黑市、无轨道**（铁壳号只在换气铁窗外——景观，不做轨）。

## 5. wedge 机关（LOCS hint 的落点）

```json
{"kind": "wedge", "node": "World/Props/CageGate", "label": "笼区铁栅门",
 "prompt": "用撬棍卡死笼区铁栅门（把它们关在里面）", "radius": 2.4}
```
与冷库铁门 / 食堂窄门同一机制链路（LevelBeats.gd `LEVELS.sanitarium.mechanisms`）。

## 6. 管线命令（复现）

```bash
cd godot_project/tools/art_gen
python3 gen_assets.py --level sanitarium ground facade
python3 gen_assets.py --level sanitarium props --only PRP_IronCage,PRP_CageBed,PRP_CageGate,PRP_MedCabinet,PRP_XrayLightbox,PRP_ChemDrum
# 共享道具只拷 manifest 条目（SteamPipe_Long / Corpse_Tarp / Crate_Wood_Stack /
# ColdStore_Chest / Brazier_OilDrum / Locker_ElectricCabinet / Survivor_Stand）
python3 build_scene.py --level sanitarium
python3 check_levels.py        # 必须 8 关全 PASS
python3 render_preview.py --scene sanitarium --mode grey
python3 render_preview.py --scene sanitarium --mode night
```

## 7. 验收标准（合并前逐条对）

1. `check_levels.py` **8 关全 PASS**（含 `LOCS["sanitarium"].scene == META.scene`）。
2. 锚点一眼可读：铁架床上的两根皮带（钱）/ 药柜红十字（prize=asp）/ 笼区铁栅门（wedge）/
   回退半人在笼里 / 换气铁窗带栏。
3. smoke 4 套的 `_sanitarium()` 段全绿（Godot 无二进制，合并前本地跑全量）。
4. 道具画布无裁切（`top > 0`）；大美术件不埋关键道具。
5. grey / night 双渲染 + 哨位特写 3 锚；夜景三团色（笼区冷白 / 工作区暖 / 火炉橙）一眼分得开。
