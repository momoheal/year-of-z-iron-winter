# 新增大场景地图资产（2026-11-16）

三张俯视油画地图均为 1672×941 PNG，并打包为 `generate2dmap.map_bundle.v2`：包含出生点、互动标记、路线、碰撞阻挡、导航报告、HTML 预览和 Godot 4 场景导出。

| 地图 ID | 主题 | 导出场景 | 校验 |
| --- | --- | --- | --- |
| `broadcast_tower_302` | 302 Broadcast Tower · siege grounds | `godot_project/art/80_maps/BroadcastTower302/godot_export/BroadcastTower302.tscn` | bundle pass；导航 pass，4 个目标全可达；Godot 文本场景导出 QA pass |
| `eagle_beak_cliff` | Eagle Beak Cliff · Car 004 derailment | `godot_project/art/80_maps/EagleBeakCliff/godot_export/EagleBeakCliff.tscn` | bundle pass；导航 pass，3 个目标全可达；Godot 文本场景导出 QA pass |
| `station_buran_yard` | West Station · Buran rail yard | `godot_project/art/80_maps/StationBuranYard/godot_export/StationBuranYard.tscn` | bundle pass；导航 pass，4 个目标全可达；Godot 文本场景导出 QA pass |
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

这些是独立可审阅的地图包，尚未接入 `CampaignData` 的关卡解锁或故事触发。碰撞轮廓依据绘制地图人工设定，导航数据已通过寻路校验；进入正式战役前仍需在 Godot 编辑器里检查实际尺度、遮挡和玩家手感。三个地图包的浏览器截图验证均因未安装 Playwright 而跳过；bundle、可达性和 Godot 文本资源解析均通过，详情见每张地图的 `qa/` 与 `godot_export/godot-export.json`。

现有战役地图里的旋转探照灯仍由 `NightSearchlight.gd` 驱动。其贴图光锥会按关卡角度缩放；照明、OSK 视线和低掩体遮挡共用 `NightExplore.gd` 的视线射线判定。上述三张新地图包目前是独立场景资源，没有接入战役敌人、伙伴和移动探照灯逻辑。

## 战役地图美术底图（不含玩法数据）

本批新增 14 张 1672×941 俯视底图，均附原始切图图集、6 个 RGBA 透明 PNG 道具和 `artwork-manifest.json`：`Archive/`、`Birch/`、`Boiler/`、`Canteen/`、`Coldstore/`、`Greenhouse/`、`Manor/`、`Market/`、`Marshalling/`、`MineNo3/`、`Sanitarium/`、`Underpass/`、`Workshop/`、`Yard/`。对应道具按 `PRP_<地图ID>_<物件名>.png` 命名并登记到各地图 manifest、地图专属 manifest 与全局 `asset_manifest.json`。

这些是可被 Godot 按资源路径导入的美术文件；本批未生成新的碰撞、导航或可玩场景数据。探照灯塔另有共享透明冷白/暖黄光锥贴图 `../30_props/PRP_SearchlightCone_Cold.png`、`../30_props/PRP_SearchlightCone_Warm.png`，注册点均在顶端中心，可供后续旋转叠加；本批不增加动态照明、遮挡或 OSK 视线行为。


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
