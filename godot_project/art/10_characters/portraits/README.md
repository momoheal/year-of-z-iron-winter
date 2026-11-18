# 角色胸像表情资源

项目胸像按 `PRT_<Character>_<State>.png` 命名，状态为 `Calm`、`Sad`、`Intense`、`Wry`；每张导出为 512×512 RGBA。无状态后缀的 `PRT_<Character>.png` 使用 Calm 图作为默认胸像。

柳德米拉本批新增：

- `PRT_Lyudmila.png`
- `PRT_Lyudmila_Calm.png`
- `PRT_Lyudmila_Sad.png`
- `PRT_Lyudmila_Intense.png`
- `PRT_Lyudmila_Wry.png`

原始四格图、提示词、身份/风格参考和裁切 provenance 保存在 `../generation_runs/2026-11-17/Lyudmila/`；批次切图说明见 `../generation_runs/2026-11-17/Lyudmila/portrait_tiles/portrait-atlas.json`。文件已登记到 `../../asset_manifest.json`。这批只加入胸像图，不改对白说话者映射。

## 2026-11-17 新表情变体

恐惧、坚定、受伤三态均为 512×512 RGBA；按角色批次写入全局资源清单。不改对白情绪标记；新表情可在游戏内美术档案浏览，剧情头像读取器也支持 fear / determined / hurt 标记。

- **Aleksei**：`PRT_Aleksei_Fear.png`、`PRT_Aleksei_Determined.png`、`PRT_Aleksei_Hurt.png`。
- **Anna**：`PRT_Anna_Fear.png`、`PRT_Anna_Determined.png`、`PRT_Anna_Hurt.png`。
- **Ash（犬类）**：`PRT_Ash_Fear.png`、`PRT_Ash_Determined.png`、`PRT_Ash_Hurt.png`。
- **Chernov**：`PRT_Chernov_Fear.png`、`PRT_Chernov_Determined.png`、`PRT_Chernov_Hurt.png`。
- **Fyodor**：`PRT_Fyodor_Fear.png`、`PRT_Fyodor_Determined.png`、`PRT_Fyodor_Hurt.png`。
- **Gulya**：`PRT_Gulya_Fear.png`、`PRT_Gulya_Determined.png`、`PRT_Gulya_Hurt.png`。
- **Ivan**：`PRT_Ivan_Fear.png`、`PRT_Ivan_Determined.png`、`PRT_Ivan_Hurt.png`。
- **Katya**：`PRT_Katya_Fear.png`、`PRT_Katya_Determined.png`、`PRT_Katya_Hurt.png`（2026-11-18 补齐，并用于 602 室母亲对白）。
- **Lana**：`PRT_Lana_Fear.png`、`PRT_Lana_Determined.png`、`PRT_Lana_Hurt.png`。
- **Leonov**：`PRT_Leonov_Fear.png`、`PRT_Leonov_Determined.png`、`PRT_Leonov_Hurt.png`。
- **OSK**：`PRT_OSK_Fear.png`、`PRT_OSK_Determined.png`、`PRT_OSK_Hurt.png`。
- **Pasha**：`PRT_Pasha_Fear.png`、`PRT_Pasha_Determined.png`、`PRT_Pasha_Hurt.png`。
- **Pavel**：`PRT_Pavel_Fear.png`、`PRT_Pavel_Determined.png`、`PRT_Pavel_Hurt.png`。
- **Yelena**：`PRT_Yelena_Fear.png`、`PRT_Yelena_Determined.png`、`PRT_Yelena_Hurt.png`。
- **Zakhar**：`PRT_Zakhar_Fear.png`、`PRT_Zakhar_Determined.png`、`PRT_Zakhar_Hurt.png`。

2026-11-18 追加的 Katya 三态与既有四态保持同一身份、衣着、构图和冬季油画质感。维京娜线索对白也显示角色肖像；在最后一句下方可选择追问或暂不惊动她，选择会写入存档标记并改变后续目标文字。
