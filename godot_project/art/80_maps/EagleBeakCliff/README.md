# Eagle Beak Cliff · Car 004 derailment

- 美术底图：`map.png`，1672×941，原地图包资源。
- 夜色变体：`map_night.png`，1672×941；保留原构图，仅改为夜间冷蓝照明，暖光限于原有灯具。
- 道具抠图源：`cutout-source.png`，1536×1024 RGBA 真透明。
- 提示词：`generation-prompt-night.txt`、`cutout-prompt.txt`；完整原图与切图验收记录位于 `godot_project/art/generation_runs/2026-11-18/asset_completion/EagleBeakCliff/`。
- 地图包：`map-bundle.json`（`generate2dmap.map_bundle.v2`）；几何与玩法数据以该文件为准。

## 六件透明道具

| 文件 | 用途 | 尺寸 | pivot（落地点） |
| --- | --- | ---: | ---: |
| `PRP_EagleBeakCliff_SwitchLever.png` | SwitchLever | 323×404 | `(159, 393)` |
| `PRP_EagleBeakCliff_BogieWheels.png` | BogieWheels | 438×327 | `(206, 316)` |
| `PRP_EagleBeakCliff_SignalLamp.png` | SignalLamp | 256×397 | `(138, 386)` |
| `PRP_EagleBeakCliff_FreightCrates.png` | FreightCrates | 423×346 | `(203, 336)` |
| `PRP_EagleBeakCliff_CableSpool.png` | CableSpool | 428×329 | `(206, 319)` |
| `PRP_EagleBeakCliff_TracksideMarker.png` | TracksideMarker | 265×380 | `(133, 369)` |

道具以 `PRP_EagleBeakCliff_<物件名>.png` 存入 `godot_project/art/30_props/`。pivot 是按道具底部支撑带测得的像素注册点，已写入本目录 `artwork-manifest.json`、地图级 registry 和全局 `asset_manifest.json`。所有道具为 RGBA 真透明。
