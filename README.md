# Year of Z: Iron Winter (`Хроники Года Z: Железная Зима` / 《Z年纪事：凛冬铁轨》) — v4.0 Master Repository

[![Version](https://img.shields.io/badge/Version-v4.0_Russian_Winter-f59e0b?style=flat-square)](#)
[![Genre](https://img.shields.io/badge/Genre-2.5D_Stealth_Survival_RPG-3b82f6?style=flat-square)](#)
[![Language](https://img.shields.io/badge/Docs_&_Prototypes-Bilingual_(ZH_%2F_EN)-10b981?style=flat-square)](#)
[![Prototype](https://img.shields.io/badge/Prototype-Exploration_Demo_v0.1_(Greybox%2C_Zero_Art)-8b5cf6?style=flat-square)](#)

> **"In Novorsk-17, when the teletype terminal lights up green, everyone is fed; when a file number is crossed out, the person is zeroed."**
>
> **“在诺沃斯克-17，电传机亮绿灯即为温饱，档案号划掉即为清零。”**

---

## 📖 Overview | 项目概览

**Year of Z: Iron Winter (《Z年纪事：凛冬铁轨》)** is a 2.5D (`75°` oblique top-down) stealth survival and bureaucratic realism narrative RPG set in the fictional post-Soviet Siberian railway hub **Novorsk-17 (`Новорск-17`)** during a `-30°C` polar winter.

By day, you play as former freight dispatcher **Aleksei "Alyosha" Morozov**, accepting an indelible violet-blue observation stamp on your frostbitten hand to haul supplies for the District Rationing Committee in exchange for peritoneal dialysis fluid to keep your uremic mother (**Mama Katya**) alive in Khrushchyovka Apartment 602. By night, after welders seal the building gates, you pry open the boiler-room vent and stalk the broad-gauge tracks searching for your 22-year-old sister **Lana (`File 0420`)**, who was swept into **Carriage No. 3** of the heavy armored train *"Buran"* (`Бронепоезд «Буран»` / "The Iron Shell").

---

## 📂 Repository Structure | 仓库文件目录

```text
year-of-z-iron-winter/
├── README.md                                                     # Bilingual Project Overview & Push Guide
├── index.html                                                    # ★ Soviet Teletype Terminal GitHub Pages Portal (Bilingual ZH/EN)
├── push_to_github.sh                                             # One-click GitHub repository creation & push script
├── assets/
│   └── concept_art/                                              # Phase 0 Concept Art Visual Targets (CON_01 ~ CON_03)
│       ├── CON_01_Novorsk17_Lighting_Script.jpg
│       ├── CON_02_Character_TriState_Sheet.jpg
│       └── CON_03_Diegetic_Work_Logbook.jpg
├── docs/
│   ├── zh/                                                       # 中文核心设定与剧本 (Chinese Documentation)
│   │   ├── Z年纪事_魔幻现实主义游戏剧本.md                       # v4.0 俄式冷峻写实叙事总剧本 (Master Script ZH)
│   │   ├── Z年纪事_游戏总策划案_GDD.md                           # v4.0 游戏总策划案 (GDD ZH)
│   │   ├── Z年纪事_第一阶段灰盒原型规格书与美术资产清单.md       # v4.0 第一阶段灰盒规格书与资产清单 (Greybox Spec ZH)
│   │   ├── Z年纪事_美术资源生成Prompt规格书.md                   # ★ AI 出图生产规格：视觉宪法 / 宏 / 逐资产 Prompt (Art Prompt Spec ZH)
│   │   └── Z年纪事_Godot4引擎迁移技术规范与架构指南.md           # ★ Godot 4.7+ 引擎迁移技术规范与架构指南 (ZH)
│   └── en/                                                       # English Documentation (v4.0 Russian Winter)
│       ├── Year_of_Z_Iron_Winter_Master_Script_EN.md             # Full 5-Act Master Screenplay (EN)
│       ├── Year_of_Z_Iron_Winter_GDD_EN.md                       # Game Design Document v4.0 (EN)
│       ├── Year_of_Z_Iron_Winter_Greybox_Spec_EN.md              # Phase 1 Greybox Spec & Asset List (EN)
│       └── Year_of_Z_Iron_Winter_Godot4_Migration_Guide_EN.md    # ★ Godot 4.7+ Engine Migration & Architecture Guide (EN)
├── prototypes/                                                   # Interactive HTML5 Prototypes & Sandboxes
│   ├── Year_of_Z_Iron_Winter_Exploration_Demo.html               # ★★ 探索循环 DEMO：据点→地图选点→夜潜→搜刮→撤离→结算 (Bilingual ZH/EN)
│   ├── Year_of_Z_Iron_Winter_Playable_Greybox_Gym.html           # ★ Single-File HTML5 Playable 5-in-1 Greybox Gym (Bilingual ZH/EN)
│   ├── Z年纪事_结局分支与双线汇聚流程图.html                     # 俄式“卌”字划痕与五结局交互模拟器 (ZH)
│   ├── Year_of_Z_Iron_Winter_Ending_Simulator_EN.html            # Dual-Anchor & 5-Ending Tally Simulator (EN)
│   └── Z年纪事_核心关卡俯视角平面动线图.html                     # v4.0 核心关卡俯视角平面动线与战术沙盘，中英双语切换 (Tactical Blueprints)
└── godot_project/                                                # ★ Ready-to-Import Godot 4.7+ Starter Project (scripts + shader + data, no scenes yet)
    ├── project.godot                                             # 8 Physics Layers (1m = 64px, 1920x1080)
    ├── autoload/                                                 # LogbookManager, AcousticRippleBus
    ├── scripts/                                                  # PlayerAleksei, WolfdogAsh, OSKPurgeSoldier, DoorWedgeInteractable
    ├── shaders/                                                  # vision_fog_90deg.gdshader
    └── data/                                                     # novorsk17_campaign_data.json (L01–L10)
```

---

---

## 🗺 Exploration Loop Demo (探索循环 DEMO · `Year_of_Z_Iron_Winter_Exploration_Demo.html`)

**Single-file HTML5 · Canvas · zero art assets · zero build step.** Open it directly in any modern browser (or serve the `prototypes/` folder). Instant **中文 / EN** switching, procedurally synthesized Web Audio SFX, and a full one-day loop:

> **据点 602 室 → 地图选点 → 夜潜探索 → 搜刮 → 撤离 → 结算推进剧情 → 第二天**
> *Base (Apt 602) → Map target selection → Night infiltration → Scavenge → Extract → Report & story advance → Next day*

| 系统 | 实现要点 |
| :--- | :--- |
| **TWoM 式地图选点** | 10 个诺沃斯克-17 节点；危险度 ▲、物资提示、容器余量 %、耗时、寒冷度、解锁条件；未踏足时只给"听说"，踏足后才显示验证过的情报 |
| **75° 斜俯视 2.5D** | 正交投影 + y 轴压缩 0.62，墙体带侧立面挤出，Y-sort 排序；`1 逻辑米 = 44px`（正式资产按 64px/m 出） |
| **程序化关卡** | BSP 房间 + 走廊生成（seed 按节点与天数），门/蒸汽管掩体/铁丝网/冻雪泥/火堆；连通率 100%（已自动化验证） |
| **视野与噪声** | 90° 扇形视野 + 1.8m 近身圈；视野外仅显示三色声音波纹（暗红=狂暴者 / 灰白=回退半人 / 冷蓝=清杀队）；潜行 0.8m、步行 2.5m、冲刺 7.5m、雪泥 ×2 |
| **三方潜行** | 清杀队 45° 探照灯（1s 红外锁定后开火）、狂暴者 0.45s 起跳预警、投掷空罐头 9m 声波**借刀杀人** |
| **伙伴系统** | 灰烬（嗅觉预警/三态标记）、安娜（辨识半人 +4 格）、古丽娅（每夜救一次）、帕维尔（撬焊死门）、伊万（隐藏容器 + 省时 20%）；每夜只能带 1 名 |
| **武器 = 收集度** | 赤手 → 道钉撬棍（可长按 E 卡门 15s）→ 砍骨刀（**锁骨卡刀 1.5s 内连按 6 次**）→ 双管猎枪（3 零件 / 心率散射 / 25m 引警）→ 莫辛纳甘（2 零件）；武器架实时显示收集进度 |
| **生存压力** | 核心体温、体力、心率（影响散射）、雪泥减速、火堆与热水回温、天亮强制撤离（只保住一半背包） |
| **主线推进** | 冷库（灰烬 + 账面死人）→ 货场（编组单）→ 东街食堂（瓦西里 / PTSD 干渴幻听）→ 疗养院（安娜 0419 → 妹妹在第三节车厢）→ 黑市（抉择 C）→ 松林庄园（焦油黑雪）→ 西站（23:00 发车令）；集齐后进入 **DEMO 边界（第四幕）** |
| **《双面工作日志》** | 正面官样台账（`0 人 / 已签收`），背面真名 + 俄式五道划痕「卌」；A3 灭口 +1、误杀 +2、背叛 +1，直接影响终局能否救活拉娜 |

**Controls 操作**：`WASD` 移动（鼠标定朝向与视野）· `Ctrl` 潜行 · `Shift` 冲刺 · `E` 长按搜刮/卡门/撤离 · `G` 投掷罐头 · `左键` 攻击/开枪/连打拔刀 · `Q` 喝热水 · `F` 用绷带 · `R` 装填 · `1-5` 切换武器 · `滚轮` 缩放 · `Tab` 日志 · `Esc` 放弃

> ⚠️ **DEMO 内不含任何美术资源**——全部图形都是 Canvas 绘制的几何体，音效为 Web Audio 程序合成。
> 美术生产规格（视觉宪法、可复用 Prompt 宏、尺寸/命名/后处理规范、逐资产英文 Prompt、MJ/SDXL/Flux/ComfyUI 参数表、负向词库、一致性方案）见：
> **`docs/zh/Z年纪事_美术资源生成Prompt规格书.md`**

---

## 🎮 Playable HTML5 5-in-1 Greybox Prototype (`Year_of_Z_Iron_Winter_Playable_Greybox_Gym.html`)

Open `prototypes/Year_of_Z_Iron_Winter_Playable_Greybox_Gym.html` directly in any modern browser (no local server or build step required). Features instant **中文 / EN** switching and procedural Web Audio API sound effects:

* **Room A (Searchlight "Borrowing the Knife" & Frozen Slush)**: Hold `Ctrl` to hide in the high-pressure steam pipe's shadow from the patrolling **O.S.K. Purge Soldier** (`45°` searchlight cone), and press `G` to throw an empty sardine tin toward the Rabid Infected so the soldier eliminates them for you.
* **Room B (Railway Crowbar Door Wedge & `12cm` Fence Gap)**: Press `E` to wedge a deformed steel door shut for `15s` with your railway crowbar, and push a warm buckwheat lunchbox through a `12cm` drainage gap.
* **Room C (The Paper Dead & Choice A `卌` Tally)**: Record **Sergey & Maria**'s real names on the back of your Work Logbook when the Soviet teletype terminal reads `0 PERSONS AT COORDINATE`, and resolve **Choice A** with the Regressing Half-Human in the culvert.
* **Room D (Siberian Wolfdog "Ash / Пепел" Tri-State Olfactory AI)**: Walk past 3 quarantine cages to test Ash's automatic olfactory detection (`Bark` vs. `Whimper` vs. `Tail Wag`) and speak with self-bound **Anna (`0419`)** about Sister **Lana (`0420`)** in Carriage No. 3.
* **Room E (East Street Canteen Kitchen — Collarbone Blade Jam QTE & PTSD Thirst)**: Equip the rusty Butcher Cleaver, confront **Vasily** in `40°C` delirium, complete the **6-hit Collarbone Blade Jam QTE**, witness his eyes clear to blue as he whispers *"…Пить (Thirsty)…"*, and experience the permanent **PTSD Thirst Tinnitus** when drinking water (`Press Q`).

---

## 🖥️ GitHub Pages Portal | `index.html`

Open `index.html` (or enable GitHub Pages on branch `main`, root `/`) for the Soviet Teletype Terminal portal: it links all prototypes including the Exploration Demo, plus the Phase 0 concept art gallery below. Note: on `file://` the portal buttons only show the target path; serve over HTTP or use GitHub Pages to navigate.

## 🎨 Phase 0 Visual Target Concept Art (`assets/concept_art/`)

| `CON_01` · Color & Lighting Script | `CON_02` · Character & Tri-State Sheet | `CON_03` · Diegetic Work Logbook (`卌`) |
| :---: | :---: | :---: |
| ![CON_01](assets/concept_art/CON_01_Novorsk17_Lighting_Script.jpg) | ![CON_02](assets/concept_art/CON_02_Character_TriState_Sheet.jpg) | ![CON_03](assets/concept_art/CON_03_Diegetic_Work_Logbook.jpg) |
| **Khrushchyovka Blizzard / East St. Kitchen / Pine Manor** | **Aleksei / Sister Lana (`0420`) / O.S.K. Purge Squad / Wolfdog "Ash"** | **Left: Verified Real Names / Right: `卌` Tally** |

## 🎮 Godot 4.7+ Starter (`godot_project/`)

Import `godot_project/project.godot` in Godot 4.7+ (created and verified with Godot 4.7.2-stable, Forward+). It already contains the 8 physics layers, the `LogbookManager` / `AcousticRippleBus` autoloads, the four core GDScripts, the 90° vision-fog shader, and the L01–L10 campaign JSON. Full spec: `docs/zh/Z年纪事_Godot4引擎迁移技术规范与架构指南.md` / `docs/en/Year_of_Z_Iron_Winter_Godot4_Migration_Guide_EN.md`.

> ⚠️ Current limit, stated plainly: this is a **code starter, not yet a runnable game**. There is no main scene, no `.tscn` files, and no input map in `project.godot` yet, so importing it opens the project but has nothing to play. The next Godot step is to add the input map + a Room A test scene wiring `PlayerAleksei` / `WolfdogAsh` / `OSKPurgeSoldier`.

---

## 🚀 Quick Push to a New Public GitHub Repository | 一键推送至 GitHub 指南

Unzip `year-of-z-iron-winter-github-repo.zip` on your machine and run either the included `./push_to_github.sh` script or the following commands:

```bash
# Option 1: Using GitHub CLI (gh) — creates a new public repo and pushes in one command
gh repo create year-of-z-iron-winter --public --source=. --remote=origin --push

# Option 2: Standard Git Remote Push
git remote add origin https://github.com/<YOUR_GITHUB_USERNAME>/year-of-z-iron-winter.git
git branch -M main
git push -u origin main
```
