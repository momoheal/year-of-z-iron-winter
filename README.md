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
│   │   ├── Z年纪事_Godot4引擎迁移技术规范与架构指南.md           # ★ Godot 4.7+ 引擎迁移技术规范与架构指南 (ZH)
│   │   ├── Z年纪事_Godot灰盒5合1移植对照表.md                     # ★ 5合1 灰盒测试场移植对照表 + 61 项测试清单 (ZH)
│   │   └── Z年纪事_Godot探索循环移植对照表.md                     # ★ 探索循环（基地→地图→夜潜→结算）移植对照表 + 97 项测试清单 (ZH)
│   └── en/                                                       # English Documentation (v4.0 Russian Winter)
│       ├── Year_of_Z_Iron_Winter_Master_Script_EN.md             # Full 5-Act Master Screenplay (EN)
│       ├── Year_of_Z_Iron_Winter_GDD_EN.md                       # Game Design Document v4.0 (EN)
│       ├── Year_of_Z_Iron_Winter_Greybox_Spec_EN.md              # Phase 1 Greybox Spec & Asset List (EN)
│       ├── Year_of_Z_Iron_Winter_Godot4_Migration_Guide_EN.md    # ★ Godot 4.7+ Engine Migration & Architecture Guide (EN)
│       ├── Year_of_Z_Iron_Winter_Godot_Greybox_Gym_Port_EN.md    # ★ 5-in-1 Greybox Gym Port Report & 61-assertion suite (EN)
│       └── Year_of_Z_Iron_Winter_Godot_Exploration_Loop_EN.md    # ★ Exploration-Loop Port Report & 97-assertion suite (EN)
├── prototypes/                                                   # Interactive HTML5 Prototypes & Sandboxes
│   ├── Year_of_Z_Iron_Winter_Exploration_Demo.html               # ★★ 探索循环 DEMO：据点→地图选点→夜潜→搜刮→撤离→结算 (Bilingual ZH/EN)
│   ├── Year_of_Z_Iron_Winter_Playable_Greybox_Gym.html           # ★ Single-File HTML5 Playable 5-in-1 Greybox Gym (Bilingual ZH/EN)
│   ├── Z年纪事_结局分支与双线汇聚流程图.html                     # 俄式“卌”字划痕与五结局交互模拟器 (ZH)
│   ├── Year_of_Z_Iron_Winter_Ending_Simulator_EN.html            # Dual-Anchor & 5-Ending Tally Simulator (EN)
│   └── Z年纪事_核心关卡俯视角平面动线图.html                     # v4.0 核心关卡俯视角平面动线与战术沙盘，中英双语切换 (Tactical Blueprints)
└── godot_project/                                                # ★ Godot 4.7.2 四场景：探索循环 + 5合1灰盒测试场 + Room A 夜潜切片 + 节点化夜潜货场
    ├── project.godot                                             # 8 Physics Layers, 24 input actions, 1920x1080, main_scene = campaign.tscn
    ├── scenes/
    │   ├── campaign.tscn                                         # ★ 主场景：「一夜」探索循环（基地/地图/夜潜/结算/结局）
    │   ├── night_explore.tscn                                    # ★ L03 夜间广轨货场：节点化 2.5D 场景（管线生成，见 tools/art_gen）
    │   ├── gym.tscn                                              # 5合1 灰盒测试场（Rooms A–E）
    │   └── main.tscn                                             # Room A 夜潜垂直切片
    ├── scripts/
    │   ├── CampaignData.gd                                       # ★ 24 物资 / 5 武器 / 5 伙伴 / 13 地点 / 7 剧情节拍数据表
    │   ├── CampaignSim.gd                                        # ★ 战役状态机：库存/良知/卌/真名/伙伴/节点余量/结算/次日/结局
    │   ├── RaidGen.gd                                            # ★ 程序化街区生成器（街道→扇区→建筑→容器→连通性）
    │   ├── RaidSim.gd                                            # ★ 一夜运行时：视野雾/AI/搜刮/卡门/撤离/体温/抉择A
    │   ├── Campaign.gd                                           # ★ 城市地图 + 夜潜世界 _draw() 渲染与输入
    │   ├── CampaignHUD.gd                                        # ★ 基地三栏 / 地图节点卡 / 夜潜 HUD / 结算 / 5 个模态框
    │   ├── GymSim.gd                                             # ★ 灰盒场纯逻辑（5房间/投罐/卡门/抉择A/三态嗅觉/QTE/卌）
    │   ├── Gym.gd                                                # ★ 灰盒场输入 + 等比视口 + _draw() 全画面渲染
    │   ├── GymHUD.gd                                             # ★ 顶栏/侧栏/清单/电传 + 日志/抉择A/QTE 模态框
    │   ├── Sfx.gd                                                # ★ 6 种程序化音效（启动时烘焙 AudioStreamWAV）
    │   ├── night/                                                # ★ 节点化夜潜场景的脚本
    │   │   ├── NightExplore.gd                                   #   总控：三方潜行 / 搜刮 / 体温 / 天亮渐变 / 抉择 / 战役回写
    │   │   ├── NightSfx.gd                                       #   25 种程序化音色 + 定位声部 + 面具呼吸循环 + 心跳
    │   │   ├── NightPlayer / NightSoldier / NightRabid / NightHalf.gd  # 玩家与三方 AI
    │   │   └── NightOverlay / NightFlicker / NightSearchlight / NightAnim.gd  # 世界空间读数 / 灯光调制 / 探照灯塔 / 帧动画
    │   ├── Sim.gd / Main.gd / HUD.gd                             # Room A 纯逻辑 / 渲染 / HUD（夜潜循环）
    │   ├── WolfdogAsh.gd / DoorWedgeInteractable.gd              # 伙伴与交互（后续房间使用）
    ├── autoload/                                                 # LogbookManager, AcousticRippleBus, SignalBus, RaidBridge（战役 ↔ 夜潜场景的数据桥）
    ├── shaders/night_post.gdshader                               # ★ 后处理：冷调分级 / 雪雾 / 暗角 / 颗粒 / 霜边 / 警报红边 / dawn 天亮
    ├── art/                                                      # ★ 管线生成的程序化资产（10_characters / 20_tileset / 30_props / 50_vfx / 70_audio + manifest）
    ├── tools/art_gen/                                            # ★ Python 美术管线：layout.py → gen_*.py → build_scene.py
    ├── tests/
    │   ├── campaign_smoke.gd                                     # ★ 97 项 headless 探索循环测试
    │   ├── night_explore_smoke.gd                                # ★ 109 项 headless 夜潜货场测试
    │   ├── gym_smoke.gd                                          # ★ 61 项 headless 机制冒烟测试
    │   ├── data_pipeline_smoke.gd                                # 71 项事件 / 数据管线测试
    │   └── room_a_smoke.gd                                       # 20 项 Room A 夜潜切片测试
    ├── screenshots/                                              # 垂直切片实机截图（gym 截图待本机首跑补拍）
    └── data/                                                      # novorsk17_campaign_data.json (L01–L10)
```

---

---

## 🌙 Godot 夜潜美术切片 · 夜间广轨货场（`scenes/night_explore.tscn`）

第一个带美术资产的 Godot 场景：L03「夜间广轨货场」，赫鲁晓夫楼院子 + 铁丝网 + 双线宽轨货场。和其它 `_draw()` 灰盒场景不同，这里是完整的节点化 2.5D 场景，可以直接在编辑器里打开、拖动、调灯。

![courtyard](godot_project/screenshots/night_yard_courtyard.png)

| 层 | 实现 |
| :--- | :--- |
| **地面** | 一张 3072×1587 烘焙大图（雪 / 预制板 / 雪径脚印 / 道砟枕木钢轨 / 冻雪泥黑冰 / 焦油黑雪 / 接触阴影），`light_mask=2` |
| **立面与道具** | 赫鲁晓夫楼立面（窗、阳台、焊死的入口、电传终端、公告栏、锅炉房通风口）+ 17 件道具（三号闷罐车厢、煤水塔、探照灯塔、报废莫斯科人、蒸汽管、油桶火堆…），全部 Y-sort，pivot 在底部中心 |
| **角色** | 按定妆图 v2 重绘：阿列克谢（长大衣 / 羊羔毛领 / ушанка / 裂片眼镜 / 帆布背包 / 撬棍 / 马灯）、ОСК 清杀兵（橡胶防护服 / 双目镜面具 + 滤罐 / 波纹软管接背负气瓶 / 胸灯 / 消音 AKM）、回退半人（新）、灰鳞狂暴者。写实 ≈7 头身、霜粉质感；S/E/N 三朝向 × 待机/走路 4 帧/蹲伏 3 帧（W 用翻转），步态用两段骨 IK（膝盖永远朝前、摆臂与同侧腿反相） |
| **灯光** | `CanvasModulate` 夜色 + 成对 `PointLight2D`：Ground 灯只照地面并投影，Objects 灯只照立起的精灵不投影（避免 2.5D 立面被自己的遮挡体压黑）；手电/探照灯是按 0.62 压缩的锥形灯；窗光是一张整面墙的灯光贴图 |
| **氛围** | GPU 雪粒子（世界层 + 屏幕前景层）、火星、蒸汽、后处理（冷调分级 / 世界锚定的雪雾 / 暗角 / 颗粒 / 失温霜边 / 警报红边 / **天亮渐变**）、4 段环境音循环 |
| **天亮（P1.5）** | 战役里 `cfg.night` 是这一夜的秒数，最后 **20%** 开始天色渐变：`night_post.gdshader` 的 `dawn` 参数抬曝光、退回中性色、化掉霜边、雾与暗角变薄，北侧天际泛暖；`CanvasModulate` 由夜青 `#455273` 抬到黎明清灰，暴风雪粒子变薄，远处一声调车汽笛。到点按 `dawn` 结束（背包保留一半、生命 −22，由 `CampaignSim.finish_raid` 结） |
| **声音（P2.5）** | `scripts/night/NightSfx.gd`：25 种音色在 `_ready()` 里程序化合成成 `AudioStreamWAV`（无新增二进制资产，headless 直接可测），一次性音效走 `AudioStreamPlayer2D` 定位衰减 —— 雪地 / 冰面 / 铁轨三种脚步、狂暴者低吼与嘶吼、扑咬、半人呻吟、撬棍挥击与闷响、翻找、罐头出手与落地、枪声（带楼群回响）、电台呼叫、警报、失温提示、天亮汽笛、心跳。`emit_noise()` 的三色声纹同时就是世界里的真声音；清杀兵的**面具呼吸**循环挂在兵身上（4 米内才听得见 = 潜行提示）；风雪音量跟着战役的 `cfg.cold` 走，天亮时退去 |
| **镜头震动** | trauma 模型：被咬 0.55 + 推镜、枪声按距离 0.06–0.5、狂暴者起跳 0.34、被发现 / 警报 0.9、结局各自一档；位移按 `shake²` 落在 `Camera2D.offset`（不打架 `position_smoothing`），外加 ≤0.8° 的滚转，衰减到底自动归位 |
| **玩法** | 潜行、手电开关（亮=好找路也好被发现）、脚步噪声、`G` 扔罐头引开清杀兵、探照灯扫描锁定（车厢/煤水塔挡光）、长按 E 搜刮（掉落表读 `CampaignData`）、火堆回温、锅炉房通风口撤离；目标是在三号车厢找到透析液 |
| **三方潜行** | 4 只灰鳞狂暴者（含守在三号车厢门口的壮硕变体）：360° 近距视线 + 循声调查（脚步 / 搜刮 / 罐头 / 枪声），0.45s 起跳预警红圈后扑咬；清杀兵光锥里出现狂暴者会瞄准 0.5s 击毙并留下血迹 → **借刀杀人**；枪声 10m 又会引来下一只。声纹三色：灰白=你 / 暗红=狂暴者 / 冷蓝=清杀队（淡琥珀=半人的呻吟） |
| **道德抉择** | 两个回退半人（0388 缩在蒸汽管下、0507 在煤水塔东侧）：还有瞳孔、不咬人，但清杀队分不清 —— 光锥里一律开枪（误杀 良知 −4）。他们会被罐头声吸引，所以借刀杀人可能把他们一起引进光锥。靠近按 `E` 抉择：① 阿司匹林 + 热水退烧（良知 +7，他睡着后清杀队认不出，送你一张调度单）② 绕开（良知 −2）③ 撬棍灭口（良知 −10、卌 +1）。热水壶随身带，阿司匹林在西院木箱（旁边就是狂暴者）。口径与战役抉择 A 一致，结算显示良知 / 救下 / 误杀 / 卌 |

**运行**：`launch_night_scene.bat`，或在战役里按 `F2`（`F2` 是独立灰盒跑法：没有天亮倒计时，`R` 可以重来）。操作：`WASD` 移动 · 鼠标朝向 · `Ctrl` 蹲 · `Shift` 跑 · 长按 `E` 搜刮/撤离（靠近半人按 `E` 抉择，`1/2/3` 选择）· `G` 罐头 · `F` 手电 · `M` 静音 · `R` 重来 · `Esc` 返回战役。测试：`tests/night_explore_smoke.gd`（**109 项**，已加进 `run_smoke_tests.bat`）。

**美术管线**（`godot_project/tools/art_gen/`，Python 3 + numpy + Pillow，无需外部服务）：

```text
layout.py        关卡布局（米）—— 地面烘焙和场景生成共用的唯一数据源
gen_assets.py    生成全部 PNG/WAV 到 godot_project/art/ 并写 night_yard_manifest.json（尺寸 + pivot）
build_scene.py   由布局 + manifest 生成 scenes/night_explore.tscn（会覆盖场景，之后建议直接在编辑器里维护）
```

资产目录与命名遵循 `docs/zh/Z年纪事_美术资源生成Prompt规格书.md` §3（`10_characters / 20_tileset / 30_props / 50_vfx / 70_audio`，64px/m，地面 y×0.62）。现在这批是程序化手绘风占位图；用 AI 出图替换时，**文件名、画布尺寸、pivot 保持不变**，覆盖 PNG 即可，场景不用改。

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

## 🎮 Godot 4.7+ Exploration Loop + Greybox Gym + Room A Slice (`godot_project/`)

`godot_project/` now ships **three playable scenes** sharing one immediate-mode architecture (a single `Node2D`, all entities as plain `RefCounted` data objects updated by hand every frame, and the entire frame rendered in `_draw()`; the HUD is the only `CanvasLayer`):

0. **`scenes/campaign.tscn` — 「一夜」探索循环（新主场景）**: the full loop of `prototypes/Year_of_Z_Iron_Winter_Exploration_Demo.html`. Room 602 with your mother on dialysis (`dial` bags, one per day, two days without her and she dies), a 900×520 city map with 13 nodes gated by intel/medicine/flags, a procedural 64×48 block per node (streets → sectors → enterable buildings → containers → connectivity repair), a 90°-FOV fog-of-war raid with warmth/BPM, rabid packs, O.S.K. purge patrols you can bait with thrown tins, half-humans and Choice A, 1.7 s container searches, crowbar door wedges, welded-door prying, then four outcomes — extracted / dawn (keep every other item, −22 HP) / downed / abort — a report screen, next-day dialysis, and the TRUE-α / TRUE-β / B / C ending resolver. Every number is lifted from the prototype's `CFG`/`LOCS`/`STORY` tables.
1. **`scenes/gym.tscn` — 5 合 1 灰盒测试场**: a 1:1 port of `prototypes/Year_of_Z_Iron_Winter_Playable_Greybox_Gym.html`. One 1100×680 arena with Rooms A–E, free walking plus `1~5` teleport, and all five signature loops live: searchlight *Borrowing the Knife* with tin cans, frozen slush and steam-pipe concealment; crowbar door wedge + 12 cm lunchbox delivery; the paper-dead teletype with Choice A and the 卌 tally; Ash's tri-state olfactory AI at three cages and Anna (0419); the East St. cleaver, Vasily's breach, the 6-press collarbone blade-jam QTE and the permanent PTSD thirst. A sidebar checklist tracks 5/5 verification; `Tab` opens the dual-sided Logbook; `L`/`F`/`M` toggle language, cracked glasses and SFX; `F5` resets.
2. **`scenes/main.tscn` — Room A 夜潜垂直切片**: the original 1:1 port of `Exploration_Demo.html`'s single-room night-stalk loop (fog-of-war hole cutting, extruded walls, steam pipes, snow, extraction). `F1` from the campaign opens the gym; inside the gym `F1` returns to the campaign and `F2` opens Room A; inside Room A `F1` goes back to the gym and `F2` to the campaign.

All three scenes draw **zero art assets** (pure `_draw()` geometry) and synthesize their own audio: `Sfx.gd` bakes six Web-Audio-style tones into `AudioStreamWAV` at startup. The campaign loop is fixed by **97 headless assertions**, the 5-in-1 gym by **61**, and the Room A slice keeps its **20**.

| 文件 | 职责 |
| :--- | :--- |
| `scripts/CampaignData.gd` | 探索循环静态数据：24 物资 / 5 武器（收集度拼装） / 5 伙伴 / 13 地点 / 7 段剧情节拍 / 中英文案 / 瓦片常量 |
| `scripts/CampaignSim.gd` | 战役状态机：库存、良知、卌 划痕、真名、flags、伙伴、节点余量、出战配置、剧情 `ops`、结算、次日透析、结局判定 |
| `scripts/RaidGen.gd` | 程序化城市生成（同 seed 同图）+ 战利品抽取 + 瓦片工具 |
| `scripts/RaidSim.gd` | 一夜运行时：移动碰撞、噪声波纹、90° 视野与探索雾、狂暴者/清杀兵/半人/伙伴 AI、搜刮、卡门、破门、撤离、体温/心率 |
| `scripts/Campaign.gd` | 城市地图与夜潜世界 `_draw()` 渲染（地面/立面/容器/火堆/雾/光锥/波纹） |
| `scripts/CampaignHUD.gd` | 顶栏 + 基地三栏 + 地图节点卡 + 夜潜 HUD + 结算页 + 剧情/抉择A/日志/帮助/放弃 五个模态框 |
| `scripts/GymSim.gd` | 灰盒场纯逻辑：5 个房间区域、玩家/灰烬/清杀兵/狂暴者、投罐声波、撬棍卡门、12cm 推饭盒、电传真名、抉择 A、三态嗅觉、砍骨刀与瓦西里破门、6 连按 QTE、PTSD、卌 划痕、验证清单、电传事件流 |
| `scripts/Gym.gd` | 灰盒场渲染：等比视口变换、`_draw()` 房间底板/网格/蒸汽管阴影/三座铁笼/砧板、探照灯与视野扇形渐变、声波波纹、弹道曳光、浮字、PTSD 闪屏、破镜遮罩 |
| `scripts/GymHUD.gd` | CanvasLayer：顶栏（区域/姿态/灰烬三态/HP/BPM/罐头/卌）+ 侧栏（体征/清单/简报/电传/按钮）+ 日志 / 抉择 A / QTE 模态框 |
| `scripts/Sfx.gd` | 程序化音效：beep / can / wedge / akm / bonejam / thirst，启动时合成 `AudioStreamWAV`（对应 HTML Web Audio） |
| `scripts/night/NightSfx.gd` | 夜潜场景的音效层：25 种音色 + `AudioStreamPlayer2D` 定位声部 + 实体循环声（面具呼吸）+ 环境层混音（`cfg.cold` / 天亮）+ 紧张度心跳 |
| `scripts/Sim.gd` / `Main.gd` / `HUD.gd` | Room A 夜潜切片：纯逻辑 / 75° 斜俯视 `_draw()` 渲染 / HUD |
| `tests/campaign_smoke.gd` | 97 项 headless 探索循环测试（成功打印 `CAMPAIGN_SMOKE_PASS`） |
| `tests/gym_smoke.gd` | 61 项 headless 冒烟测试（见下方命令；成功打印 `GYM_SMOKE_PASS`） |
| `tests/room_a_smoke.gd` | 20 项 Room A 冒烟测试（成功打印 `ROOM_A_SMOKE_PASS`） |

**Run / 运行**（with Godot 4.7.2-stable）:

```bash
# 「一夜」exploration loop (new main scene)
Godot_v4.7.2-stable_win64 --path godot_project

# 5-in-1 greybox gym (or press F1 in-game)
Godot_v4.7.2-stable_win64 --path godot_project res://scenes/gym.tscn

# Room A night-stalk slice (or press F2 in the gym)
Godot_v4.7.2-stable_win64 --path godot_project res://scenes/main.tscn

# Campaign loop: 97 headless assertions (prints CAMPAIGN_SMOKE_PASS on success)
Godot_v4.7.2-stable_win64 --headless --path godot_project -s tests/campaign_smoke.gd

# Greybox gym: 61 headless assertions (prints GYM_SMOKE_PASS on success)
Godot_v4.7.2-stable_win64 --headless --path godot_project -s tests/gym_smoke.gd

# Room A slice: 20 headless assertions (prints ROOM_A_SMOKE_PASS on success)
Godot_v4.7.2-stable_win64 --headless --path godot_project -s tests/room_a_smoke.gd
```

**Controls 操作（「一夜」探索循环）**：`WASD` 移动 · 鼠标瞄准 / 地图点选 · `Ctrl` 潜行 · `Shift` 冲刺 · `Space` / 左键 攻击（砍骨刀卡刀连按 6 次）· 按住 `E` 搜刮 / 卡门 / 破门 / 撤离 / 抉择 A · `Q` 热水（体温 +22）· `H` 绷带（+26 HP）· `G` 扔空罐 · `R` 装弹 · `Tab` 《双面工作日志》· `L` 中英切换（非夜潜）· `Enter` 开始 / 睡到明天 · `Esc` 取消 / 放弃夜潜 · `F1` 灰盒测试场。

**Controls 操作（5 合 1 灰盒场）**：`WASD` 移动 · 鼠标定朝向 · `Ctrl` 蹲伏（蒸汽管阴影 100% 免疫探照灯）· `Shift` 冲刺 · `G` 投掷空罐头（借刀杀人）· `E` 交互 / 撬棍卡门 / 门底推饭盒 · `Space` / 左键 挥刀（锁骨卡刀 6 连按）· `Q` 喝水（PTSD 耳鸣）· `Tab` 《双面工作日志》· `1~5` 传送 Room A–E · `L` 中英切换 · `F` 破眼镜 · `M` 音效 · `F5` 重置 · `F1` 回探索循环 · `F2` Room A 夜潜切片 · `Esc` 关闭模态框。

**Controls 操作（Room A 夜潜切片）**：`WASD` 移动 · 鼠标定朝向 · `Ctrl` 蹲伏隐匿 · `Shift` 冲刺 · `G` 投掷空罐头（借刀杀人）· `Q` 喝水 · `E` 按住 1.5s 在绿色撤离点撤离 · `Enter` 重开 · `F1` 返回灰盒测试场 · `F2` 回探索循环。

| 借刀杀人构图（士兵黄色探照锥 + 玩家 90° 视野锥 + 蒸汽管阴影） | 出生点 HUD 与撤离点 |
| :---: | :---: |
| ![Room A vertical slice](godot_project/screenshots/room_a_vertical_slice.png) | ![Room A spawn HUD](godot_project/screenshots/room_a_spawn_hud.png) |

> 说明：所有数值（速度、噪声半径、视野、锁定/射击间隔、掩体规则、雪泥减速、卡门时长、搜刮时长、夜长、QTE 次数等）均逐行对齐 HTML 原型，由 97 + 61 + 20 项 headless 测试固定行为；本仓库为无美术灰盒，画面全部为 `_draw()` 几何绘制，音效全部程序化合成。
> **探索循环移植细节 / 逐机制对照表 / 刻意偏差 / 测试清单**：`docs/zh/Z年纪事_Godot探索循环移植对照表.md` · `docs/en/Year_of_Z_Iron_Winter_Godot_Exploration_Loop_EN.md`
> **灰盒场移植细节**：`docs/zh/Z年纪事_Godot灰盒5合1移植对照表.md` · `docs/en/Year_of_Z_Iron_Winter_Godot_Greybox_Gym_Port_EN.md`
> **后续节点化架构规范**：`docs/zh/Z年纪事_Godot4引擎迁移技术规范与架构指南.md` · `docs/en/Year_of_Z_Iron_Winter_Godot4_Migration_Guide_EN.md`
>
> ⚠️ 本次新增的探索循环与灰盒场都已通过 gdtoolkit GDScript 解析校验，并分别附 97 / 61 项 headless 测试，但**尚未在装有 Godot 的机器上首跑**（本仓库未附新的 campaign / gym 截图）；请先运行上面的 `campaign_smoke` 与 `gym_smoke` 命令完成首次验收，再补拍截图。

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
