# 剧情插图（CG）

由 `scripts/ui/StorySlides.gd` 播放，页面数据在 `scripts/data/CutsceneData.gd`。

命名约定（16:9，建议 1376×768 JPG）：

| 文件 | 用途 |
| --- | --- |
| `cg_intro_*.jpg` | 故事开场 |
| `cg_<剧情id>_scene.jpg` | 剧情对白框背后的场景图 |
| `cg_<剧情id>_c<选项序号>.jpg`（及 `…b` / `…c`） | 该抉择之后的余波幻灯 |

缺图的页会自动退回人物胸像，所以**往本目录补图即可生效，不用改代码**。

## 已有（22 张）

- 开场：`cg_intro_city` · `cg_intro_mother` · `cg_intro_lana` · `cg_intro_vent`
- 冷库：`cg_coldstore_scene` · `cg_coldstore_c0` · `cg_coldstore_c1`
- 调车场：`cg_yard_scene` · `cg_yard_c0`
- 食堂：`cg_canteen_scene` · `cg_canteen_c0` · `cg_canteen_c0b`
- 黑市：`cg_market_scene` · `cg_market_c0` · `cg_market_c1` · `cg_market_c2`
- 疗养院：`cg_sanitarium_scene` · `cg_sanitarium_c0`
- 庄园：`cg_manor_scene` · `cg_manor_c0`
- 西站：`cg_marshalling_scene` · `cg_marshalling_c0b`

## 可选补充（现在用同一张图的不同取景 / 胸像顶替）

- `cg_marshalling_c0`、`cg_market_c0b` / `c1b` / `c1c` / `c2b` / `c2c`、`cg_sanitarium_c0b`、`cg_manor_c0b`：
  各余波第 2、3 页的专属画面，目前复用同场景的图并换了镜头焦点

新图第一次用编辑器打开工程（或跑 `godot --headless --import`）时会自动生成 `.import`。

## 一致性约定（重画或补图时照此写提示词，并把参考图一起喂进去）

- 阿列克谢：灰色毛皮护耳帽（无帽徽）、圆框眼镜、深炭灰棉袄配灰毛领。参考 `PRT_Aleksei_Concept.png`、`../opening_dispatch.png`
- 伊万：白色络腮胡、深蓝铁路大檐帽（红帽墙）、深蓝制服配红金肩章。参考 `PRT_Ivan_Calm.png`
- 费奥多尔 / 安娜 / 古丽娅 / 灰烬：以 `art/10_characters/portraits/` 里的胸像为准
- 列车：墨绿色铆接装甲机车，斜面装甲、车头雪犁、侧面红星。参考 `cg_yard_scene.jpg`、`../opening_dispatch.png`
- 画面里不出现任何文字、型号、商标
