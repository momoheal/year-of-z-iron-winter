# 新增大场景地图资产（2026-11-16）

三张俯视油画地图均为 1672×941 PNG，并打包为 `generate2dmap.map_bundle.v2`：包含出生点、互动标记、路线、碰撞阻挡、导航报告、HTML 预览和 Godot 4 场景导出。

| 地图 ID | 主题 | 导出场景 | 校验 |
| --- | --- | --- | --- |
| `broadcast_tower_302` | 302 Broadcast Tower · siege grounds | `godot_project/art/80_maps/BroadcastTower302/godot_export/BroadcastTower302.tscn` | bundle pass；导航 pass，4 个目标全可达；Godot 文本场景导出 QA pass |
| `eagle_beak_cliff` | Eagle Beak Cliff · Car 004 derailment | `godot_project/art/80_maps/EagleBeakCliff/godot_export/EagleBeakCliff.tscn` | bundle pass；导航 pass，3 个目标全可达；Godot 文本场景导出 QA pass |
| `station_buran_yard` | West Station · Buran rail yard | `godot_project/art/80_maps/StationBuranYard/godot_export/StationBuranYard.tscn` | bundle pass；导航 pass，4 个目标全可达；Godot 文本场景导出 QA pass |

这些是独立可审阅的地图包，尚未接入 `CampaignData` 的关卡解锁或故事触发。碰撞轮廓依据绘制地图人工设定，导航数据已通过寻路校验；进入正式战役前仍需在 Godot 编辑器里检查实际尺度、遮挡和玩家手感。三个地图包的浏览器截图验证均因未安装 Playwright 而跳过；bundle、可达性和 Godot 文本资源解析均通过，详情见每张地图的 `qa/` 与 `godot_export/godot-export.json`。

现有战役地图里的旋转探照灯仍由 `NightSearchlight.gd` 驱动。其贴图光锥会按关卡角度缩放；照明、OSK 视线和低掩体遮挡共用 `NightExplore.gd` 的视线射线判定。上述三张新地图包目前是独立场景资源，没有接入战役敌人、伙伴和移动探照灯逻辑。
