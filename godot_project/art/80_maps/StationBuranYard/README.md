# West Station · Buran rail yard

- 美术底图：`map.png`，1672×941，原地图包资源。
- 夜色变体：`map_night.png`，1672×941；保留原构图，仅改为夜间冷蓝照明，暖光限于原有灯具。
- 道具抠图源：`cutout-source.png`，1536×1024 RGBA 真透明。
- 提示词：`generation-prompt-night.txt`、`cutout-prompt.txt`；完整原图与切图验收记录位于 `godot_project/art/generation_runs/2026-11-18/asset_completion/StationBuranYard/`。
- 地图包：`map-bundle.json`（`generate2dmap.map_bundle.v2`）；几何与玩法数据以该文件为准。

## 六件透明道具

| 文件 | 用途 | 尺寸 | pivot（落地点） |
| --- | --- | ---: | ---: |
| `PRP_StationBuranYard_SignalSwitch.png` | SignalSwitch | 332×367 | `(166, 357)` |
| `PRP_StationBuranYard_FreightCrates.png` | FreightCrates | 396×353 | `(188, 342)` |
| `PRP_StationBuranYard_PlatformSignal.png` | PlatformSignal | 231×429 | `(115, 418)` |
| `PRP_StationBuranYard_BogieBrake.png` | BogieBrake | 371×304 | `(175, 294)` |
| `PRP_StationBuranYard_MaintenanceTrolley.png` | MaintenanceTrolley | 423×378 | `(210, 368)` |
| `PRP_StationBuranYard_BrazierDrums.png` | BrazierDrums | 360×377 | `(180, 367)` |

道具以 `PRP_StationBuranYard_<物件名>.png` 存入 `godot_project/art/30_props/`。pivot 是按道具底部支撑带测得的像素注册点，已写入本目录 `artwork-manifest.json`、地图级 registry 和全局 `asset_manifest.json`。所有道具为 RGBA 真透明。
