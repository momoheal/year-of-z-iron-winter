# 《Z年纪事：凛冬铁轨（Year of Z: Iron Winter）》美术资源生成 Prompt 规格书（v1.0）

> **文档定位**：面向 AI 出图（Midjourney v6 / Stable Diffusion XL / Flux.1 / ComfyUI 工作流）的**通用生产规格**。
> **配套文件**：`prototypes/Year_of_Z_Iron_Winter_Exploration_Demo.html`（探索循环灰盒 DEMO，当前所有画面均为 Canvas 几何体，**零美术资源**）。
> **一句话原则**：**先锁死"视觉宪法"，再用可复用宏拼装每条 Prompt，最后用统一后处理把 AI 图压回引擎可用的网格里。**
> **Prompt 语言**：正文全部给**英文**（模型对英文的理解与稳定性显著更好），中文仅作意图说明。中文说明不应进入 Prompt。

---

## 0. 三分钟上手：一条 Prompt 是怎么拼出来的

```
┌─ §SUBJECT ─┐┌─ §COSTUME ─┐┌─ §STATE ─┐┌─ §PROPS ─┐
        ↓
   [资产主体描述，尽量"名词 + 材质 + 磨损 + 具体数字"]
        ↓
┌─ §CAM_75 ─┐┌─ §LIGHT_* ─┐┌─ §STYLE ─┐┌─ §PAL ─┐┌─ §BG ─┐┌─ §TECH ─┐
        ↓
                    最终 Prompt（英文，逗号分隔）
        ↓
           工具参数（见 §4 参数适配表）+ 负向提示词（见 §5）
        ↓
      后处理（去背 / Trim / Pivot / 切片 / 命名，见 §8）
```

**示例（完整成品）**：

```
A Soviet railway dispatch worker's cast-iron crowbar, 1.2 meters long, hexagonal
shaft, curved claw, chipped black enamel, orange surface rust at the claw, worn
bright steel at the grip, snow crust in the socket, §CAM_75, §LIGHT_COLD, §STYLE,
§PAL, isolated on a transparent background, centered, full object in frame,
sharp edges, game item sprite, 1024x1024
```
（实际使用时把 `§XXX` 宏替换成 §2 里的完整文本，**宏名本身不要写进 Prompt**。）

---

## 1. 视觉宪法（Visual Constitution）——所有 Prompt 的地基

### 1.1 世界观关键词（每个 Prompt 至少出现 2 个）

| 类别 | 必须出现的关键词（EN） |
| :--- | :--- |
| 地域 | `post-Soviet Siberian railway industrial city`, `Novorsk-17`, `broad-gauge rail yard`, `Khrushchyovka prefab apartment block` |
| 气候 | `polar winter at -30°C`, `blizzard`, `tar-black snow`, `black ice`, `frozen slush` |
| 体制 | `Soviet bureaucratic rationing`, `teletype terminal`, `Пропуск pass stamp`, `red-header form`, `welded steel gate` |
| 威胁 | `MVD sanitary purge squad`, `GP-5 pig-snout gas mask`, `lead-grey rubber hazmat suit`, `suppressed AKM`, `45-degree searchlight` |
| 病症 | `grey-scale (чешуя) skin flakes peeling off`, `blackened sclera`, `40°C fever delirium`, `recovering, pupils clearing` |

### 1.2 色彩脚本（三套氛围靶心 · 直接写进 Prompt 的 hex）

| 氛围 | 主色 | 辅色 | 唯一高饱和色（点睛） | 用于 |
| :--- | :--- | :--- | :--- | :--- |
| **A. 暴风雪青灰**（夜潜主色调） | `#0b0f14` 焦油黑 / `#1b222c` 冻土 | `#232c38` 混凝土 / `#3c4859` 阴影边 | `#7dd3fc` 冰蓝反光 · `#fde68a` 探照灯 | 全部夜潜关卡、广轨、下穿道 |
| **B. 苏制惨绿 / 煤油暖**（室内） | `#0d1218` / `#2a2015` | `#6b4a2a` 锈 / `#3a2a18` 木 | `#4ade80` 电传机 CRT 绿 · `#f59e0b` 煤油灯 | 602 室、区管委、食堂后厨、黑市 |
| **C. 特权区暖黄 + 焦油黑雪**（讽刺对比） | `#2b2418` 恒温库 | `#8a6a3c` 木箱 / `#c9b48a` 奶油 | `#ef4444` 焚化炉红 · `#e2e8f0` 不锈钢 | 松林庄园二号库、焚化炉 |

**硬规则**：
1. 单张图 **除点睛色外，饱和度一律压到 25% 以下**（Prompt 里写 `desaturated, muted saturation, no neon, no vivid colors except the amber CRT glow`）。
2. **禁止**出现：现代智能手机、LED 屏幕、运动鞋、冲锋衣、英文商标、赛博朋克霓虹、日式动漫五官、Q 版比例。
3. **文字**：默认 `no text, no letters, no signage`；确需西里尔字母（如 `ВЫДАНО`、`ОСК 03`）时，必须**单独出一张无字底图 + 用矢量软件手写字**，AI 生成的西里尔字母 99% 是乱码。

### 1.3 统一光照规则（2.5D 的灵魂）

```
§LIGHT_COLD  : flat overcast blizzard top-light, no sun, soft ambient bounce from
               snow, shadow cast straight down and slightly to the lower-right,
               low-key, 70% of the frame in shadow
§LIGHT_WARM  : single warm practical light source (kerosene lamp / CRT screen) from
               the upper-left, deep falloff into cold blue shadow, strong chiaroscuro
§LIGHT_SPOT  : hard 45-degree conical searchlight cutting through falling snow,
               volumetric, high contrast, everything outside the cone nearly black
§LIGHT_UI    : flat even lighting, no cast shadow, orthographic, for clean UI icons
```
> **关键**：所有 2.5D 资产的**投影方向必须一致**（统一右下偏 15°），否则拼进场景会"浮起来"。

---

## 2. 可复用宏（把这段文本原样粘进每条 Prompt）

```
§CAM_75  : orthographic 75-degree oblique top-down view (camera pitched 75 degrees
           from horizontal, ground plane vertically compressed to 0.62, wall side
           faces visible), no perspective distortion, no vanishing point, top-down
           game camera
§STYLE   : gritty painterly semi-realistic game art, Soviet constructivist
           propaganda-print texture, heavy snow accumulation on top surfaces,
           rust and chipped enamel, worn steel, film grain, muted contrast,
           Metro Exodus x Darkwood x Papers Please mood, hand-painted normal-map
           friendly detail, no cel-shading, no anime
§PAL     : desaturated cold palette (#0b0f14, #1b222c, #232c38, #3c4859) with rust
           (#6a4a2a) and a single amber/CRT-green accent, no neon, no vivid colors
§BG_ITEM : isolated on a transparent background, centered, entire object visible,
           crisp silhouette, no shadow baked in, no ground plane
§BG_TILE : seamless tileable texture, no border, no vignette, edges must match
           perfectly, top-down flat, no directional shadow across the seam
§BG_SCENE: full scene illustration, wide establishing shot, no characters in the
           foreground, cinematic composition
§TECH    : sharp focus, high detail, 4k, game-ready asset, clean readable silhouette
```

---

## 3. 2.5D 技术约束（出图前必须知道的硬指标）

### 3.1 相机与投影（与 DEMO 的 `CFG` 一一对应）

| 项 | 数值 | 说明 |
| :--- | :--- | :--- |
| 相机俯角 | **75°**（相对水平面） | 地面沿视线方向压缩 **0.62**（DEMO：`CFG.SQUASH`） |
| 投影 | **正交 / Orthographic**，无消失点 | 禁止透视变形，否则无法与瓦片对齐 |
| 基准比例尺 | **1 逻辑米 = 64 px**（1080p） | DEMO 为看更大范围用 44，正式资产按 64 出 |
| 单屏可视 | 约 **30m × 16.8m** | 与 GDD 一致 |
| 墙体侧立面高度 | **0.62 × 64 ≈ 40 px**（0.62 逻辑米） | 墙面必须画出"混凝土预制板厚度" |
| 角色画法 | **直立不压缩**（脚底为 pivot） | 只有地面被压缩，人物/立柜保持竖直 |
| 遮挡排序 | **Y-sort**（按脚底世界 y 排序） | 出图时角色脚底留 4px 空白便于排序 |

### 3.2 资产尺寸表（出图按 2×，落库降采样）

| 类型 | 逻辑尺寸 | 出图分辨率 | Canvas 预留 | Pivot |
| :--- | :--- | :--- | :--- | :--- |
| 地砖 / 雪地 / 冰面 | 1m×1m | **1024×1024**（平铺测试后降 128） | 64×64 | 中心 |
| 墙体（含顶面+侧立面） | 1m×1m×0.62m | 1024×1024 | 64×104 | **底部中心** |
| 门 / 铁丝网 / 管道掩体 | 1m×1m | 1024×1024 | 64×104 | 底部中心 |
| 角色（成人 1.75m） | — | **896×1536**（竖） | 72×112 | **脚底中心** |
| 灰狼犬（0.6m 长） | — | 1024×768 | 38×32 footprint | 脚底中心 |
| 手持道具（撬棍/刀/枪） | 1.0–1.3m | 1024×1024 | 64–96 | 握点（右下 1/3） |
| 容器（箱/柜/冰箱） | 0.7–1.5m | 1024×1024 | 64×96 | 底部中心 |
| 大型（车厢/煤水塔/BTR） | — | 1536×1024 | 按需 | 底部中心 |
| UI 图标 | — | 1024×1024 | 128×128 → 64 | 中心 |
| 概念稿 / 场景插图 | — | **16:9 或 3:2** | 1920×1080 | — |

### 3.3 命名与目录（出图即用，避免返工）

```
assets/
├── 00_concept/       CON_01_Novorsk17_ColorScript.png
├── 10_characters/    CHR_01_Aleksei/{body_S.png, body_SE.png, ... body_NW.png, portrait.png, crackedGlasses_mask.png}
├── 20_tileset/       TIL_Floor_Concrete_A.png  TIL_Wall_Prefab_Side.png  TIL_Snow_Drift.png
├── 30_props/         PRP_Crate_Wood.png  PRP_Locker_Steel.png  PRP_Teletype_Terminal.png
├── 40_vehicles/      PRP_Buran_Boxcar03.png  PRP_WaterTower.png
├── 50_vfx/           VFX_Searchlight_Cone.png  VFX_Snow_Particle.png  VFX_Ripple_Crimson.png
├── 60_ui/            ICO_Item_Rye.png  UI_Logbook_BackTally.png  UI_MapCard_Frame.png
└── 70_audio_ref/     （音效参考，非图像）
```
命名规则：`类别_编号_名称_朝向/状态.png`，**全英文 + 下划线，禁止中文与空格**。

---

## 4. 参数适配表（同一条 Prompt 在不同工具里的落法）

| 工具 | 分辨率 | 关键参数 | 备注 |
| :--- | :--- | :--- | :--- |
| **Midjourney v6.1** | `--ar 1:1`（角色 `--ar 9:16`） | `--style raw --s 250 --v 6.1`；平铺图加 `--tile` | 角色一致性：`--cref <角色图URL> --cw 100`；风格统一：`--sref <氛围图URL> --sw 300` |
| **SDXL 1.0** | 1024×1024 / 896×1152 | `steps 34, cfg 6.5, sampler DPM++ 2M Karras, denoise 1.0` | 风格用 LoRA（`soviet_brutalist_v1`, 权重 0.6–0.8）；结构用 ControlNet Canny 0.5 或 Depth 0.6 |
| **Flux.1 [dev]** | 1024×1024 | `guidance 3.5, steps 28, sampler euler, shift 3` | 对**自然语言长句**响应最好，少用标签堆砌；负面提示词基本不需要 |
| **ComfyUI** | 同上 | 推荐链路：`Load Checkpoint → LoRA → ControlNet(Canny/Depth) → KSampler → 放大(4x-UltraSharp) → rembg 去背` | 批量出图用 `XY Plot` 网格先挑种子，再定稿放大 |
| **统一后处理** | — | 去背 `rembg` / PS 对象选择 → Trim 透明边 → 按 §3.2 缩放 → 导出 **PNG-32 带 alpha** | 禁止 JPG；禁止烘焙投影（投影由引擎实时绘制） |

---

## 5. 负向提示词库（Negative Prompt）

### 5.1 通用底噪（SDXL / MJ `--no`，Flux 可省略）

```
text, letters, words, signage, watermark, logo, signature, UI frame,
anime, cartoon, chibi, cel shading, toy-like, plastic sheen,
neon, cyberpunk, vivid saturated colors, rainbow, purple glow,
modern smartphone, LED screen, sneakers, tactical gear, molle,
medieval, fantasy, sci-fi armor, elves, orcs,
perspective distortion, vanishing point, fisheye, lens flare (except searchlight),
tilted horizon, ground shadow baked in, pedestal, floating object,
blurry, lowres, jpeg artifacts, oversharpen halos, duplicated limbs, extra heads,
mutated hands, too many fingers
```

### 5.2 分类追加

| 场景 | 追加负向 |
| :--- | :--- |
| 平铺地砖 | `seam, border, frame, vignette, directional light gradient, large unique detail` |
| 角色立绘 | `weapon, backpack（除非指定）, cape, symmetry, front-facing symmetry, multiple characters` |
| UI 图标 | `background, scene, character, text, 3D render, photorealism, heavy shading` |
| 场景插图 | `character close-up, portrait, UI, split panel, collage, grid of images` |

---

## 6. 一致性方案（角色 / 场景如何"每次都长一个样"）

1. **角色一致性（推荐主方案）**：先出 `CHR_xx_portrait.png` 与 `CHR_xx_body_S.png` 各一张定妆图 →
   * MJ：后续所有该角色的 Prompt 末尾加 `--cref <定妆图URL> --cw 100`；
   * SDXL：用定妆图跑 **IP-Adapter**（权重 0.65）+ **InstantID**（面部 0.5）；
   * 换装/换状态（`cracked glasses` / `peeling scales`）时保持 `--cw 80`，让细节可变、脸不可变。
2. **风格一致性**：全局 `--sref <CON_01 色彩脚本 URL> --sw 250–400`；SDXL 侧用同一 LoRA + 同一 VAE + 固定种子族（seed ± 20）。
3. **结构一致性**：场景/道具统一过 **ControlNet Depth 或 Canny**（权重 0.5–0.7），保证俯角、比例、透视每批一致。
4. **状态变体**：用 **图生图（denoise 0.35–0.5）** 在定妆图上叠加状态描述（如"灰鳞正在剥落"），比文生图稳定得多。
5. **验收**：所有角色资产并排放在同一张 1080p 灰底图上比对，比例/视线高度/描边粗细必须一致，否则打回。

---

## 7. 资产清单与逐条 Prompt

> **格式约定**：`【Prompt】`可直接复制（记得替换 `§` 宏）；`【意图】`给美术/外包看的中文说明；`【参数】`为推荐值；`【后处理】`为入库前必做项。
> 优先级：**P0 = 垂直切片必需**（约 22 张）→ **P1 = 第一幕完整** → **P2 = 全章节填充**。

### 7.1 P0 · 概念设定（3 张，先定靶心，再批量生产）

#### `CON_01` 色彩脚本与光照靶心 　★P0
```
【Prompt】A triptych color script sheet for a post-Soviet Siberian survival game,
three horizontal panels side by side: (left) a Khrushchyovka apartment gatehouse at
night in blizzard, cold blue-grey snow, a Soviet teletype terminal glowing sickly
CRT green through frosted glass, blue-white arc-welding sparks; (middle) a canteen
kitchen interior lit by one kerosene lamp, steam off a cabbage soup cauldron, deep
amber and rust; (right) a heated 26°C elite depot with warm yellow ceiling lamps,
stacks of beef and imported milk powder, and through the window black tarry snow
falling over a frozen workers' district, a red furnace glow. §CAM_75 (applied to
each panel's ground), §STYLE, §PAL, §BG_SCENE, color-script layout, three distinct
moods, no characters in foreground, §TECH
【意图】三幅并置的氛围靶心，是后面所有 `--sref` 的锚点。
【参数】MJ `--ar 3:2 --style raw --s 350 --v 6.1` / SDXL 1536×1024
【后处理】切成三张独立 PNG，分别命名 `CON_01_A_Blizzard` / `CON_01_B_Kerosene` / `CON_01_C_TarSnow`
```

#### `CON_02` 核心角色与三态辨识设定图 　★P0
```
【Prompt】A character design sheet, four full-body figures standing in a row on a
neutral grey backdrop, orthographic front view: (1) Aleksei, 31, former railway
dispatcher, faded dark-blue Soviet railway greatcoat, ushanka fur hat, round
wire-frame glasses with black electrical tape on the right temple, chilblains and
violet-blue indelible stamp ink on the back of his right hand, holding a cast-iron
railway crowbar; (2) Lana, 22, railway hospital nurse trainee, washed-out white
nurse uniform, a small patch of pale grey scale flakes still on her wrist; (3) an
MVD purge trooper in full lead-grey rubber hazmat suit with a GP-5 pig-snout
respirator, chest-mounted high-lumen searchlight, suppressed AKM; (4) a Siberian
grey wolfdog with a scarred wire collar. §CAM_75 (slight), §LIGHT_UI, §STYLE, §PAL,
character sheet layout, consistent scale, clear silhouettes, §TECH
【意图】四人并排设定图，比例与剪影必须一眼可辨（这是潜行游戏的玩法底线）。
【参数】MJ `--ar 16:9 --style raw --s 200 --v 6.1`；角色 `--cref` 从这张开始
【后处理】切出单人图，分别存为各角色 portrait 定妆图
```

#### `CON_03` 《双面工作日志》UI 视觉稿 　★P0
```
【Prompt】A worn Soviet hardcover work logbook opened flat, top-down view: the left
page is a printed red-header ration reconciliation form with checkboxes and a
teletype-printed table; the right page is the back of the book — left side covered
in fountain-pen handwriting of real people's names, right side scored with heavy
Russian five-stroke prison tally marks in dried dark red ink, a small black-and-white
ID photo of a young woman paper-clipped at the corner, three folded manuscript pages
tucked inside, coffee rings, frost damage. §LIGHT_WARM, §STYLE, §PAL, top-down flat
lay, no characters, §TECH
【意图】日志本 UI 的视觉母题：正面官样台账 / 背面真名与血痕。
【参数】MJ `--ar 3:2 --style raw --s 200`
【后处理】分层：本子底图 / 手写层 / 划痕层 分三个 PSD 图层，供 UI 动态替换
【注】西里尔字母与手写内容**后期用矢量补写**，不要指望 AI 出可读文字。
```

---

### 7.2 P0/P1 · 角色资产

#### `CHR_01` 阿列克谢（主角） 　★P0
```
【Prompt】Full-body game character sprite of a weary 31-year-old Soviet railway
dispatcher standing upright, faded dark-blue railway worker's greatcoat with sheepskin
collar, grey ushanka with ear flaps down, round wire-frame glasses, black electrical
tape wrapped around the right temple, frostbitten red hands with violet-blue stamp
ink on the back of the right hand, worn insulated trousers, felt boots, a cast-iron
railway crowbar held low in his right hand, slight forward hunch, exhausted. §CAM_75,
§LIGHT_COLD, §STYLE, §PAL, §BG_ITEM, single character, neutral T-pose-adjacent idle,
§TECH
【变体 A】same character, right lens shattered with a spiderweb crack and taped over
with black electrical tape, small cuts on the cheek
【变体 B（8 向序列）】same character, walk cycle / run cycle / crowbar overhead swing /
crouch-walk — 每个动作 8 方向（N, NE, E, SE, S, SW, W, NW）。建议先出 S / SE / E 三个方向，
其余用镜像 + 手修（省 40% 预算）。
【意图】主角的定妆图是所有 `--cref` / IP-Adapter 的源头，必须一次定死。
【参数】MJ `--ar 9:16 --style raw --s 200 --v 6.1`；SDXL 896×1536，IP-Adapter 0.65
【后处理】去背 → Trim → 缩放至 72×112 → pivot 脚底中心 → 存 `CHR_01_Aleksei_{动作}_{朝向}.png`
```

#### `CHR_02` 灰烬（西伯利亚灰狼犬） 　★P0
```
【Prompt】Full-body game sprite of a Siberian grey wolfdog, thick snow-crusted fur,
pale grey and charcoal coat, a healed scar and a broken wire collar around its neck,
alert ears, low stance, seen from a 75-degree oblique top-down game camera,
four-legged, compact readable silhouette. §CAM_75, §LIGHT_COLD, §STYLE, §PAL,
§BG_ITEM, single animal, §TECH
【变体】荒原线：左耳缺一角 + 前爪缠脏绷带
【参数】MJ `--ar 4:3 --style raw --s 200`；8 方向行走 + 吠叫/低鸣/摇尾 三态
【后处理】38×32 footprint，pivot 脚底中心
```

#### `CHR_03` 灰鳞高热狂暴者（瓦西里 / 通用感染者） 　★P0
```
【Prompt】Full-body game sprite of a man in a 40-degree fever delirium, early
twenties, wearing a torn navy striped sailorshirt (тельняшка) and a split padded
cotton jacket, skin covered in grey scale-like flakes, blackened purple sclera,
mouth open in a snarl, hunched forward on the balls of his feet with arms hanging
low, fingers bloodied from scratching at doors, frostbitten bare hands. §CAM_75,
§LIGHT_COLD, §STYLE, §PAL, §BG_ITEM, single character, menacing but human, no
zombie rot, no exposed bone, §TECH
【关键变体（三态辨识的核心）】
  · 状态 Ⅰ 狂暴：as above, quadrupedal lunge, full black sclera
  · 状态 Ⅱ 回退半人：the grey scales flaking off in patches, pupils returning to
    clear human brown, hugging his own head, one hand raised palm-out, weeping
  · 状态 Ⅲ 退烧清醒：scales gone, 36.6°C, exhausted and terrified, clear blue eyes,
    lips cracked and bleeding, whispering
【意图】三态必须"远看是三个剪影，近看是同一个人"——这是玩法的道德压力来源。
【参数】同上；三态共用同一 `--cref` 保证是"同一个人"
【后处理】命名 `CHR_03_Rabid / CHR_03_Regressing / CHR_03_Recovered`
```

#### `CHR_04` 拉娜（0420）与安娜（0419） 　★P1
```
【Prompt A · 拉娜】Full-body game sprite of a 22-year-old railway hospital nurse
trainee, washed-out white nurse uniform with a faded red cross armband, thin wool
cardigan, hospital ID tag 0420 on a string, a small patch of pale grey scale flakes
still clinging to her right wrist, barefoot in the boxcar, emaciated, terrified but
conscious, §CAM_75, §LIGHT_COLD, §STYLE, §PAL, §BG_ITEM, §TECH
【Prompt B · 安娜】Full-body game sprite of a 24-year-old woman, prison-grey
patient gown, both wrists bound raw by an old leather belt, short matted hair,
eyes bloodshot but clear, defiant exhausted expression, ID tag 0419, §CAM_75,
§LIGHT_COLD, §STYLE, §PAL, §BG_ITEM, §TECH
【意图】妹妹是"黑夜之钩"，安娜是"活体吹哨人"，两人的脸必须有记忆点（会用于过场特写）。
```

#### `CHR_05` 内务清杀兵（ОСК） 　★P0
```
【Prompt】Full-body game sprite of an MVD Special Sanitary Purge Squad trooper in a
sealed lead-grey heavy rubber hazmat suit, GP-5 pig-snout respirator with two round
eye lenses, canvas harness, chest-mounted high-lumen yellow-white searchlight,
suppressed AKM with a long cylindrical silencer slung across the chest, thick
insulated boots, faceless and anonymous, heavy deliberate posture. §CAM_75,
§LIGHT_COLD, §STYLE, §PAL, §BG_ITEM, single character, no face visible, §TECH
【意图】"猪嘴面具底下没有眼睛"——反派要像一堵会走路的墙，绝对不能帅。
【参数】8 方向巡逻 + 举枪、拉栓、开火 三动作
```

#### `CHR_06` 支援角色（P2）：帕维尔老爹（七级钳工，皮围裙 + 管钳）、"老轨"伊万（列车长制服 + 蓝毛线帽）、古丽娅（血迹斑斑的白大褂 + 听诊器）、梁诺夫（老眼科主任，圆框镜 + 检眼镜）、卡佳妈妈（病号服 + 腹透管，轮椅/行军床两版）、杜布罗夫（卡车司机，翻毛领大衣）。
```
【通用模板】Full-body game sprite of {年龄+职业描述+服装+道具+状态}, §CAM_75,
§LIGHT_COLD, §STYLE, §PAL, §BG_ITEM, single character, §TECH
```

---

### 7.3 P0 · 地形瓦片（Tileset，全部 `--tile` / 无缝）

> **通用规则**：地砖统一 `--tile`；**禁止**大块独特细节、方向性阴影、边框；出图后必须在引擎里 3×3 平铺检查接缝。

#### `TIL_01` 混凝土预制板地面 　★P0
```
【Prompt】Seamless top-down tileable texture of a worn Soviet precast concrete floor
slab, grey aggregate, hairline cracks, chipped corners, a thin film of grey dust,
scuffed by boots, cold desaturated tone. §LIGHT_UI, §STYLE, §PAL, §BG_TILE, 64x64
game tile, orthographic, no directional shadow across the seam, §TECH
【参数】MJ `--tile --ar 1:1 --style raw --s 100`；SDXL `seamless tiling` LoRA + Tiling 节点
【后处理】3×3 平铺测试 → 修缝 → 降 128px → 入库 64px
```

#### `TIL_02` 冻雪泥 / 黑冰 　★P0
```
【Prompt】Seamless top-down tileable texture of frozen slush and black ice in a rail
yard, translucent grey-brown ice over packed snow, tyre and boot tracks frozen in,
small shards of clear ice, dark meltwater at the edges, wet specular sheen.
§LIGHT_UI, §STYLE, §PAL, §BG_TILE, §TECH
【玩法注】踩上去 速度 ×0.65、噪声 ×2.0 —— 视觉上必须一眼看出"这里会响"。
```

#### `TIL_03` 积雪 / 雪堆 　★P0
```
【Prompt】Seamless top-down tileable texture of deep drifted snow, wind-scoured
ridges, granular sparkle, faint blue shadow in the troughs, clean cold white-grey.
§LIGHT_UI, §STYLE, §PAL, §BG_TILE, §TECH
```

#### `TIL_04` 赫鲁晓夫楼预制板墙（含侧立面） 　★P0
```
【Prompt】A modular orthographic wall block for a 75-degree oblique top-down game,
Soviet Khrushchyovka precast concrete panel wall, top face and front side face both
visible, chipped grey concrete with exposed rust-coloured rebar at one corner,
graffiti-free, a frozen drainage stain running down the side, snow cap on the top
edge, modular block that connects seamlessly left and right. §CAM_75, §LIGHT_COLD,
§STYLE, §PAL, §BG_ITEM, §TECH
【尺寸】顶 64×64 + 侧立面 40px → 64×104，pivot 底部中心
```

#### `TIL_05` 变形铁门（可撬棍卡死）/ `TIL_06` 铁丝网门（12cm 底缝）/ `TIL_07` 高架供暖蒸汽管掩体 / `TIL_08` 冷库铁网门 / `TIL_09` 冰面下穿道 / `TIL_10` 木地板与地毯（602 室）
```
【门】A rusted deformed steel door in a concrete frame, orthographic 75-degree
oblique top-down view, hatch-open state, heavy hinges, a 12 cm gap under the bottom
edge, frozen to the frame, §CAM_75, §LIGHT_COLD, §STYLE, §PAL, §BG_ITEM, §TECH
【蒸汽管】A thick insulated district-heating steam pipe running horizontally, rust
and mineral streaks, banded clamps, a patch of melted snow beneath it, low enough to
crouch behind, §CAM_75, §LIGHT_COLD, §STYLE, §PAL, §BG_ITEM, §TECH
【铁丝网】A chain-link fence gate panel, galvanised steel, torn at one corner, ice
in the mesh, a 12 cm gap at the bottom, see-through mesh, §CAM_75, §LIGHT_COLD,
§STYLE, §PAL, §BG_ITEM, §TECH
```

---

### 7.4 P0/P1 · 道具与容器（搜刮的对象）

| 编号 | 资产 | Prompt 主体（其余宏照抄） |
| :--- | :--- | :--- |
| `PRP_01` | 木条箱 | `a weathered wooden crate, stencilled Cyrillic-free plain slats, frost on the top board, nail heads rusted` |
| `PRP_02` | 钢制储物柜 | `a dented Soviet steel locker, chipped grey-green enamel, a bent ventilation louvre, one door slightly ajar` |
| `PRP_03` | 药品柜 | `a wall-mounted medical cabinet, chipped white enamel, a faded red cross decal, frosted glass door, half-empty shelves` |
| `PRP_04` | 工业冰柜 | `a chest freezer in a cold store, heavy white lid crusted with frost, a rusted hasp for a padlock, condensation ice` |
| `PRP_05` | 公文包 | `a scuffed brown Soviet leather briefcase, brass catches, a red-header form sticking out, snow on the lid` |
| `PRP_06` | 保险柜 | `a squat Soviet floor safe, dark olive enamel, a heavy dial, chipped paint around the hinge, dust and cobwebs` |
| `PRP_07` | 苏制电传终端 | `a bulky Soviet teletype ration terminal, thick physical keys, a CRT screen glowing sickly green, red vacuum-tube error lamp, riveted steel housing, a paper tape slot` |
| `PRP_08` | 备餐台与砍骨刀 | `a greasy thick wooden prep table in a workers' canteen kitchen, a heavy-backed Russian butcher cleaver stuck into the chopping block, half a frozen beet and rye dough beside it` |
| `PRP_09` | 铝饭盒 / 空罐头 | `a dented aluminium Soviet mess tin with a warm buckwheat portion, steam rising` / `an empty sardine tin, peeled label, frozen to the ground` |
| `PRP_10` | 火堆（油桶） | `a makeshift brazier made from a cut steel oil drum, orange flame, scorched paint, a ring of melted snow, warm amber light spill` |
| `PRP_11` | 高压蒸汽阀 | `a district-heating steam valve with a rusted handwheel, jet of white vapour, ice built up around the pipe` |
| `PRP_12` | 搪瓷碗 / 搪瓷杯 | `a chipped white enamel bowl with a blue rim, half a portion of grey buckwheat` |
| `PRP_13` | 腹膜透析液袋 | `a transparent medical peritoneal dialysis fluid bag, 2 litres, Cyrillic-free plain label, a coiled tube, a manual drainage bulb` |
| `PRP_14` | 老式腹膜透析机 | `an ageing Soviet peritoneal dialysis machine on a metal stand, beige metal housing, analogue gauges, a low-voltage alarm lamp, coiled tubing` |
| `PRP_15` | 通行证与蓝印油 | `a Soviet Пропуск pass card with a violet-blue indelible stamp, a fingerprint in stamp ink, worn paper` |

**通用尾缀（道具）**：`, §CAM_75, §LIGHT_COLD, §STYLE, §PAL, §BG_ITEM, single object, centred, §TECH`

#### 武器（收集度决定火力，务必成套出）
```
【PRP_W_Crowbar】A Soviet railway cast-iron crowbar, 1.2 m, hexagonal shaft, curved
claw, chipped black enamel, orange rust bloom at the claw, polished steel at the
grip from decades of hands, snow crust in the socket, §CAM_75, §LIGHT_COLD, §STYLE,
§PAL, §BG_ITEM, horizontal orientation, §TECH
【PRP_W_Cleaver】A heavy-backed Russian butcher cleaver (секач), rusty carbon steel
blade with pitting, a worn wooden handle bound with electrical tape, a chip in the
edge, dried dark residue near the bolster, §CAM_75, §LIGHT_COLD, §STYLE, §PAL,
§BG_ITEM, §TECH
【PRP_W_Shotgun】A crudely sawed-off double-barrelled 12-gauge shotgun (обрез),
shortened barrels with a file-cut muzzle, a splintered wooden stock wrapped in
tape, bluing worn to grey, a leather sling, §CAM_75, §LIGHT_COLD, §STYLE, §PAL,
§BG_ITEM, §TECH
【PRP_W_Mosin】A Mosin-Nagant bolt-action rifle with a laminated stock, worn
arsenal bluing, a bent bolt handle, a cracked leather sling, frost on the metal,
§CAM_75, §LIGHT_COLD, §STYLE, §PAL, §BG_ITEM, §TECH
【零件（收集度用，必须能一眼认出是"还差一件"）】a sawn-off shotgun barrel / a wooden
gun stock / a small steel firing pin — each isolated, heavily worn, on transparent
background, same lighting and scale as the assembled weapon
```

#### `PRP_Buran_Boxcar03` 铁壳号第三节闷罐车厢 　★P1（L09 的核心舞台）
```
【Prompt】A Soviet broad-gauge heavy armoured boxcar, riveted steel plate armour,
patchy chemical-protection green paint over red oxide primer, a large white stencil
number 03 on the side, ventilation windows welded shut with double layers of chain
link, sliding door ajar, heavy snow on the roof and ice on the bogies, seen from a
75-degree oblique top-down game camera, side view with the roof visible, no
characters. §CAM_75, §LIGHT_COLD, §STYLE, §PAL, §BG_ITEM, §TECH
【变体】鹰嘴崖脱轨侧翻状态：same boxcar, derailed and lying on its side in a snowy
ravine, the sliding door buckled open, twisted rails, spilled snow
```

#### `PRP_WaterTower` 煤水塔 / `PRP_BTR` 破障装甲车 / `PRP_UralTruck` 乌拉尔卡车（P2）
```
【煤水塔】A Soviet railway water tower, riveted steel tank on a brick base, a frozen
downpipe, a ladder with ice on the rungs, snow cap, §CAM_75, §LIGHT_COLD, §STYLE,
§PAL, §BG_ITEM, §TECH
```

---

### 7.5 UI 与图标（UI_ / ICO_）

```
【ICO 物品图标（统一模板）】A clean game inventory icon of {物品}, three-quarter
top-down view, thick readable silhouette, flat even lighting, subtle hand-painted
shading, desaturated cold palette with one warm accent, centered on transparent
background, 1024x1024, no text, no frame, no background scene
【物品清单】黑麦碎粒袋 rye / 铁皮罐头 tin / 热水壶 flask / 阿司匹林 aspirin /
绷带 bandage / 抗生素 antibiotics / 腹膜透析液 dialysis bag / 废钢件 scrap /
铁丝 wire / 电子元件 electronics / 木柴 firewood / 煤油 kerosene /
调度单 dispatch slip / 焚化炉照片 photos / 枪管 barrel / 枪托 stock /
击针 firing pin / 莫辛枪机 bolt / 步枪弹 ammo / 砍骨刀 cleaver /
伏特加 vodka / 旧手表 watch / 黑绝缘胶布 tape / 空玻璃瓶 bottle
```

```
【UI_Logbook_BackTally】A diegetic UI panel: the open back cover of a Soviet work
logbook, left column of fountain-pen handwritten names, right column of Russian
five-stroke tally marks in dark red ink, paper texture, torn edge, coffee stain,
flat even lighting, transparent background around the book, no readable words,
UI-ready, 16:9
【UI_MapCard_Frame】A diegetic UI card frame for a scavenging map: aged Soviet
cardboard with a red-header strip, a stamp box, a torn corner, punch holes,
transparent center area for text, flat even lighting, no text, 3:2
【UI_HUD_Meters】A minimal diegetic HUD strip: health / core temperature / stamina
as three analogue gauges with Soviet instrument styling, chipped enamel bezels,
frosted glass, flat lighting, transparent background, no text, 16:9
【ICO_Status】status icon set: cracked-glasses debuff, PTSD thirst tinnitus,
hypothermia, frostbite, conscience-up, conscience-down, tally stroke — flat icon,
single accent colour each, transparent background, consistent 8px stroke weight
```

---

### 7.6 VFX 与 Shader 参考（交给 TA，不是最终贴图）

```
【VFX_Searchlight】A volumetric 45-degree conical searchlight beam cutting through
heavy falling snow at night, yellow-white hot core, soft edges, dust and ice motes
in the beam, high contrast, dark surroundings, additive-blend friendly, alpha
gradient, square 1024
【VFX_SnowParticle】Soft round snow particle sprites, subtle motion blur streaks,
varying opacity, white-blue, transparent background, tiling sprite sheet 8 frames
【VFX_Ripple】Three circular sound-ripple rings on transparent background:
(a) crimson jagged — rabid scraping, (b) ash-white trembling — half-human weeping,
(c) cold-blue metallic — purge squad boots, thin glowing stroke, alpha gradient
【VFX_BloodTally】A fresh dark-red ink stroke being scratched into paper, a fountain
pen nib, paper fibre tearing, extreme close-up, transparent background
【SHD 参考】请把 CON_01_A 与 VFX_Searchlight 一起交给 TA，作为
`SHD_VisionFog_90Deg` / `SHD_Searchlight_Blizzard` / `SHD_TerminalGlare_CRT` 的
色彩与衰减参考（三个 Shader 的需求见《灰盒规格书》第三章）。
```

---

## 8. 后处理与验收清单（每张图入库前逐条打勾）

- [ ] 去背干净（rembg 之后放大到 400% 检查边缘毛边与半透明雪花残留）
- [ ] **未烘焙投影**（投影由引擎按统一方向实时绘制；带投影的图必须修掉）
- [ ] Trim 到最小外接框，再按 §3.2 缩放到目标尺寸
- [ ] Pivot 位置正确（角色/立柜 = **脚底中心**；手持道具 = 握点）
- [ ] 平铺贴图 3×3 无缝测试通过
- [ ] 光照方向与全局一致（右下 15°），饱和度 ≤ 25%（点睛色除外）
- [ ] 无 AI 乱码文字（有文字需求 → 矢量后期补写）
- [ ] 命名与目录符合 §3.3；导出 **PNG-32 带 alpha**，禁止 JPG
- [ ] 角色资产与同屏其他角色比例一致（放同一张灰底对比图核对）
- [ ] 三态感染者并排时，**能被一眼认出"这是同一个人"**

---

## 9. 生产工作流（建议 5 个批次，可并行）

| 批次 | 内容 | 产出 | 依赖 |
| :--- | :--- | :--- | :--- |
| **B1 · 定靶心** | `CON_01~03` | 3 张 | 无 |
| **B2 · 定妆** | `CHR_01~05` 定妆图 + 三态变体 | 约 12 张 | CON_01/02 |
| **B3 · 场景基座** | `TIL_01~10` + `PRP_01~15` | 约 25 张 | CON_01 |
| **B4 · 铺量** | 角色 8 向序列、武器套件、容器变体、UI 图标 | 约 90 张 | B2/B3 |
| **B5 · 章节专属** | 铁壳号车厢、煤水塔、松林庄园内景、302 广播塔、鹰嘴崖雪谷 | 约 20 张 | B3 |

**替换 DEMO 的顺序**（从灰盒走向可玩切片）：
1. 地砖 `TIL_01~03` 替换 `drawScene()` 里的 `floorColor()` 纯色填充 → 立刻提升 50% 观感；
2. 墙块 `TIL_04` + `drawBox()` 的 top/front 贴图 → 2.5D 成立；
3. 容器 `PRP_01~06` 替换 `drawBox` 的彩色方块；
4. 角色 `CHR_01~05` 替换 `drawEnt()` / `drawPlayer()` 的圆形与方块；
5. 最后上 VFX 与 Shader（`SHD_Searchlight_Blizzard` 是氛围的最大杠杆）。

---

## 10. 常见坑（踩过的都在这）

1. **俯角不一致**：不同批次出图的俯角差 5° 就足以让角色"陷进地里"。**所有资产必须共用 `§CAM_75` 与同一 ControlNet 结构参考。**
2. **透视**：MJ 默认带强透视。务必加 `orthographic, no perspective distortion, no vanishing point`；必要时用 Canny 锁结构。
3. **平铺地砖的方向光**：一旦出现渐变，平铺立刻露馅。`§BG_TILE` 里那句 `no directional shadow across the seam` 不能删。
4. **西里尔字母**：AI 写不出可读俄文。**出无字底图 + 矢量补字**是唯一可靠路径。
5. **"怪物化"过度**：本作不是丧尸题材。感染者必须保持"正在生病的人"的观感（负向里写死 `no zombie rot, no exposed bone`），否则核心道德机制失效。
6. **饱和度漂移**：连续出图 20 张后，模型会自动"提鲜"。每 10 张回看一次 `CON_01`，必要时加 `--sref` 拉回。
7. **一致性成本**：角色 8 向 × 4 动作 = 32 张/角色，是最大的预算黑洞。**先出 S/SE/E 三向，其余镜像 + 手修**，可省约 40%。

---

## 11. 与 DEMO 的对照表（出了什么图，能替换哪里）

| DEMO 中的灰盒元素 | 代码位置 | 对应资产 |
| :--- | :--- | :--- |
| 地面纯色方块 | `drawScene()` / `floorColor()` | `TIL_01~03` |
| 墙体挤出盒子 | `drawBox()` | `TIL_04`（+ `TIL_05~08` 门/网/管） |
| 容器彩色方盒 | `drawScene()` 的 `contAt` 分支 | `PRP_01~07` |
| 玩家胶囊 + 朝向线 | `drawPlayer()` | `CHR_01` |
| 敌人椭圆 + 探照灯 | `drawEnt()` | `CHR_03` / `CHR_05` |
| 灰狼犬 | `drawEnt()` mate 分支 | `CHR_02` |
| 火堆光晕 | `drawScene()` fires | `PRP_10` + `VFX_Searchlight` |
| 三色声音波纹 | `drawRipples()` | `VFX_Ripple` |
| 暴风雪粒子 | `drawFlakes()` | `VFX_SnowParticle` |
| 物品图标 emoji | `ITEMS[].ic` | `ICO 物品图标`（24 个） |
| 地图卡片 | `#mapPanel` | `UI_MapCard_Frame` |
| 日志本弹窗 | `openLogbook()` | `UI_Logbook_BackTally` |

---

> **最后一句**：美术不是"把 DEMO 变好看"，而是"让 90° 视野、45° 探照灯与三态辨识这三个玩法机制**一眼可读**"。
> 任何一张让"这是狂暴者还是正在醒来的人"变得更难判断的图，都是废图——哪怕它很好看。
