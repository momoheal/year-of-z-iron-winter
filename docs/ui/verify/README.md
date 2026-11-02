# 验收图 / Acceptance Sheets

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
| 1 | `yard_grey.png` | `res://scenes/night_explore.tscn`<br>L03 · ШИРОКАЯ КОЛЕЯ · 宽轨货场（48×40 m） | 整关、中性光 / full level, neutral light | 街面是否连成一片：五层赫鲁晓夫楼立面 + 亮窗、配电箱、告示板、钠路灯、铁网、扳道房、水塔、雪堆；角色站位是否压在雪地上而不是浮空 |
| 2 | `yard_night.png` | 同上 / same | 整关、夜色 / full level, night grade | `CanvasModulate` 冷调是否压得住；钠灯黄色光斑半径是否合理；两处油桶火的暖光有没有烧掉细节 |
| 3 | `marshalling_grey.png` | `res://scenes/night_marshalling.tscn`<br>L04 · ЗАПАДНЫЙ СОРТИРОВОЧНЫЙ ПАРК · 西调车场（44×36 m） | 整关、中性光 | 砖砌调度楼 + 站台雨棚 + 驼峰线 + 4 节车皮 + 水塔 + 铁网；新加的三件哨位道具（沙袋 / 弹药箱 / 枪架）是否落在车站逻辑位置上 |
| 4 | `marshalling_night.png` | 同上 | 整关、夜色 | 站台灯、调度楼窗光、油桶火三套光源是否互相打架；雪被灯照到的边缘是否过曝 |
| 5 | `manor_grey.png` | `res://scenes/night_manor.tscn`<br>L05 · СОСНОВАЯ УСАДЬА · 松林庄园（46×38 m） | 整关、中性光 | 庄园主楼立面 + 车库卷帘门（黄黑警示条）+ 松林 + 长蒸汽管 + 庄园铁门；庄园这一关比货场"有钱"，检查砖石与铁艺的对比级差 |
| 6 | `manor_night.png` | 同上 | 整关、夜色 | 最暗的一关：庄园车道那条深色沥青带是否太生硬；松林是否把玩家淹没在黑里；瞭望塔探照灯位置 |
| 7 | `outpost_marshalling.png` | `res://scenes/night_marshalling.tscn` | 三个新哨位 2× 特写 / three outpost props, zoomed | 沙袋 (33.0, 9.2 m) · 弹药箱 (24.2, 5.6 m) · 枪架 (12.4, 4.1 m)：虚线框 = 精灵本体外框，十字准星 = 落地锚点（碰撞/遮蔽都以锚点为准）。枪架上只剩一把撬棍，是这一关撬棍的来源 |
| 8 | `outpost_manor.png` | `res://scenes/night_manor.tscn` | 三个新哨位 2× 特写 | 沙袋 (27.0, 12.6 m) · 弹药箱 (21.0, 6.2 m) · 枪架 (9.2, 4.2 m)：看特写里有没有穿帮（道具压在雪脊上、挡住必经路线、和 Batch-409 托盘挤在一起） |
| 9 | `combat_readout.png` | L03–L05 通用 / all night levels | 俯视读数 / top-down readout | 撬棍扇形 ±49°/1.9 m 是否够"贴身才有用"；TT-33 26 m、锯短 38 m、莫辛 44 m 的噪声圈是否真的"一枪就把人拽过来"；右下命中半径（0.40/0.46/0.52 m）与左下数值表 |

> 特写图（7、8）里**故意不画角色**，避免路过的兵挡住道具；整关图（1–6）保留角色，用来看人／环境比例。

---

## 二、怎么复现 / Regenerate

```bash
cd godot_project/tools/art_gen
python3 render_preview.py            # 6 张整关图（3 关 × 中性光 / 夜色）+ 3 张辅助图
python3 render_preview.py --crops    # 只重出特写与战斗读数
python3 render_preview.py --level manor
```

- 比例：1 m = 64 px，地面纵向压扁 ×0.62；整关图默认再缩到 0.62 输出。
- 底层数据：`godot_project/scenes/night_{explore,marshalling,manor}.tscn` 与 `godot_project/art/`。
- 改场景后**必须重跑**，这些图不会自动更新。

---

## 三、已知差异与边界 / Known gaps

1. **没有引擎实机**：战斗手感（后坐、命中反馈、声音）只能静态验证，`tests/night_combat_smoke.gd` 需要带引擎的机器跑
   `Godot_v4.7.2-stable_win64 --headless --path godot_project -s tests/night_combat_smoke.gd`。
2. **光照是近似**：只合成径向 / 光晕贴图，锥形光、遮挡阴影、bloom 都不在图上。
3. **图里没有 UI**：HUD、武器栏、提示条请看 `docs/ui/soviet_ui_board.html`。
4. **这四张场景仍是灰盒，没有出图**：`gym.tscn`、`main.tscn`、`campaign.tscn`、`event_demo.tscn`
   目前还是 `_draw()` 画的占位，属于下一批要美术化的对象。
5. 图上所有文字是拉丁 / 西里尔字母：环境里只有 DejaVu 字体，没有中文字库，写中文会变成方块。
