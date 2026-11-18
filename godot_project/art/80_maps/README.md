# 新增大场景地图资产（2026-11-16）

三张俯视油画地图均为 1672×941 PNG，并打包为 `generate2dmap.map_bundle.v2`：包含出生点、互动标记、路线、碰撞阻挡、导航报告、HTML 预览和 Godot 4 场景导出。

| 地图 ID | 主题 | 导出场景 | 校验 |
| --- | --- | --- | --- |
| `broadcast_tower_302` | 302 Broadcast Tower · siege grounds | `godot_project/scenes/night_broadcast_tower_302.tscn` | 已接入 CampaignData；bundle 导出保留供审阅 |
| `eagle_beak_cliff` | Eagle Beak Cliff · Car 004 derailment | `godot_project/scenes/night_eagle_beak_cliff.tscn` | 已接入 CampaignData；bundle 导出保留供审阅 |
| `station_buran_yard` | West Station · Buran rail yard | `godot_project/scenes/night_station_buran_yard.tscn` | 已接入 CampaignData；bundle 导出保留供审阅 |
| `workshop` | 机修车间 | —（美术底图） | art-only；底图与 6 个透明道具已登记，无碰撞/导航包 |
| `underpass` | 铁道下穿积冰道 | —（美术底图） | art-only；底图与 6 个透明道具已登记，无碰撞/导航包 |
| `sanitarium` | 旧传染病疗养院地下室 | —（美术底图） | art-only；底图与 6 个透明道具已登记，无碰撞/导航包 |
| `boiler` | 锅炉房后巷 | —（美术底图） | art-only；底图与 6 个透明道具已登记，无碰撞/导航包 |
| `canteen` | 东街工人食堂 · 后厨 | —（美术底图） | art-only；底图与 6 个透明道具已登记，无碰撞/导航包 |
| `archive` | 档案馆电报局 | —（美术底图） | art-only；底图与 6 个透明道具已登记，无碰撞/导航包 |
| `greenhouse` | 温室大棚 | —（美术底图） | art-only；底图与 6 个透明道具已登记，无碰撞/导航包 |
| `birch` | 白桦林废弃板房 | —（美术底图） | art-only；底图与 6 个透明道具已登记，无碰撞/导航包 |
| `manor` | 松林庄园 · 二号恒温库 | —（美术底图） | art-only；底图与 6 个透明道具已登记，无碰撞/导航包 |
| `yard` | 夜间广轨货场（第一关） | —（美术底图） | art-only；底图与 6 个透明道具已登记，无碰撞/导航包 |
| `marshalling` | 西站调车场（五股道） | —（美术底图） | art-only；底图与 6 个透明道具已登记，无碰撞/导航包 |
| `market` | 铁路黑市（废弃工人镇） | —（美术底图） | art-only；底图与 6 个透明道具已登记，无碰撞/导航包 |
| `coldstore` | 城北四号铁路冷库 | —（美术底图） | art-only；底图与 6 个透明道具已登记，无碰撞/导航包 |
| `mine_no3` | 3 号矿坑 · 温压爆破作业面 | —（美术底图） | art-only；底图与 6 个透明道具已登记，无碰撞/导航包 |

三个 bundle 地图包现已分别接入 `CampaignData.LOCS`，并生成使用共享 `NightExplore.gd` 的战役场景；bundle 自带的 Godot 导出仍保留作布局审阅，不是实际战役入口。碰撞、巡逻点、可搜刮目标与撤离点按新场景布局配置，烟测检查地图资源、出生至撤离可达性和关键补给可达性。

三张地图均在场景中装配清杀队、狂暴者、回退半人和动态探照灯；伙伴由战役出发配置生成。探照灯由 `NightSearchlight.gd` 驱动，光锥、OSK 视线与掩体遮挡使用 `NightExplore.gd` 的共享射线判定。

## 战役接入与顺序（2026-11-18）

新增主线段落为“西站调车场 → 布拉风货场 → 鹰嘴崖 → 302 广播塔”。`CampaignSim` 按前置剧情旗标依次解锁地点；三处首访对白登记在 `CampaignData.STORY`。广播塔要求已从庄园带回证据，并从鹰嘴崖取得路线；完成广播场景撤离后战役才标记为终局完成。

## 战役地图美术底图（不含玩法数据）

既有 14 张 1672×941 俯视底图，均附原始切图图集、6 个 RGBA 透明 PNG 道具和 `artwork-manifest.json`：`Archive/`、`Birch/`、`Boiler/`、`Canteen/`、`Coldstore/`、`Greenhouse/`、`Manor/`、`Market/`、`Marshalling/`、`MineNo3/`、`Sanitarium/`、`Underpass/`、`Workshop/`、`Yard/`。对应道具按 `PRP_<地图ID>_<物件名>.png` 命名并登记到各地图 manifest、地图专属 manifest 与全局 `asset_manifest.json`。

上述 14 套历史底图此前仅作为地图美术资源；本次新接入的三套地图已由 `tools/art_gen/levels/` 规格生成可玩的 `.tscn`，包含布局、碰撞、敌人与动态探照灯。探照灯塔另有共享透明冷白/暖黄光锥贴图 `../30_props/PRP_SearchlightCone_Cold.png`、`../30_props/PRP_SearchlightCone_Warm.png`，注册点均在顶端中心，可供后续旋转叠加；本批不增加动态照明、遮挡或 OSK 视线行为。


## 新增地图包美术补齐（2026-11-18）

| 地图 ID | 夜色底图 | 抠图源 | 道具资源 |
| --- | --- | --- | --- |
| `broadcast_tower_302` | `BroadcastTower302/map_night.png` | `BroadcastTower302/cutout-source.png` | 6 件 `PRP_BroadcastTower302_*`，已登记 pivot |
| `eagle_beak_cliff` | `EagleBeakCliff/map_night.png` | `EagleBeakCliff/cutout-source.png` | 6 件 `PRP_EagleBeakCliff_*`，已登记 pivot |
| `station_buran_yard` | `StationBuranYard/map_night.png` | `StationBuranYard/cutout-source.png` | 6 件 `PRP_StationBuranYard_*`，已登记 pivot |

每套含地图级 `artwork-manifest.json`，并由对应的 `night_*_manifest.json` 注册到底层资源核验器。切图验收使用 RGBA 真透明和底部支撑 pivot；提取结果与原始生成源保存在 `art/generation_runs/2026-11-18/asset_completion/`。
## 夜色底图变体（2026-11-17）

| 地图 | 资源 | 色调 | 尺寸 |
| --- | --- | --- | --- |
| Archive | `80_maps/Archive/map_night.png` | 夜色 | 1672×941 |
| Birch | `80_maps/Birch/map_night.png` | 夜色 | 1672×941 |
| Boiler | `80_maps/Boiler/map_night.png` | 夜色 | 1672×941 |
| Canteen | `80_maps/Canteen/map_night.png` | 夜色 | 1672×941 |
| Coldstore | `80_maps/Coldstore/map_night.png` | 夜色 | 1672×941 |
| Greenhouse | `80_maps/Greenhouse/map_night.png` | 夜色 | 1672×941 |
| Manor | `80_maps/Manor/map_night.png` | 夜色 | 1672×941 |
| Market | `80_maps/Market/map_night.png` | 夜色 | 1672×941 |
| Marshalling | `80_maps/Marshalling/map_night.png` | 夜色 | 1672×941 |
| MineNo3 | `80_maps/MineNo3/map_night.png` | 夜色 | 1672×941 |
| Sanitarium | `80_maps/Sanitarium/map_night.png` | 夜色 | 1672×941 |
| Underpass | `80_maps/Underpass/map_night.png` | 夜色 | 1672×941 |
| Workshop | `80_maps/Workshop/map_night.png` | 夜色 | 1672×941 |
| Yard | `80_maps/Yard/map_night.png` | 夜色 | 1672×941 |


## 游戏内美术接入

战役地点选择面板会显示对应地点的夜色俯视图（无夜色版时回退 `map.png`），方便出发前辨认地形；战役中的碰撞、巡逻路线和导航仍由原关卡场景控制。战役顶栏「美术档案」分页包含全局登记的地图、CG、角色、道具、精灵、材质与特效资源，也会扫描本目录中未进入全局清单的地图图像。
