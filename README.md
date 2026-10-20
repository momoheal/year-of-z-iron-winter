# Year of Z: Iron Winter (`Хроники Года Z: Железная Зима` / 《Z年纪事：凛冬铁轨》) — v4.0 Master Repository

[![Version](https://img.shields.io/badge/Version-v4.0_Russian_Winter-f59e0b?style=flat-square)](#)
[![Genre](https://img.shields.io/badge/Genre-2.5D_Stealth_Survival_RPG-3b82f6?style=flat-square)](#)
[![Language](https://img.shields.io/badge/Docs_&_Prototypes-Bilingual_(ZH_%2F_EN)-10b981?style=flat-square)](#)

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
├── push_to_github.sh                                             # One-click GitHub repository creation & push script
├── docs/
│   ├── zh/                                                       # 中文核心设定与剧本 (Chinese Documentation)
│   │   ├── Z年纪事_魔幻现实主义游戏剧本.md                       # v4.0 俄式冷峻写实叙事总剧本 (Master Script ZH)
│   │   ├── Z年纪事_游戏总策划案_GDD.md                           # v4.0 游戏总策划案 (GDD ZH)
│   │   └── Z年纪事_第一阶段灰盒原型规格书与美术资产清单.md       # v4.0 第一阶段灰盒规格书与资产清单 (Greybox Spec ZH)
│   └── en/                                                       # English Documentation (v4.0 Russian Winter)
│       ├── Year_of_Z_Iron_Winter_Master_Script_EN.md             # Full 5-Act Master Screenplay (EN)
│       ├── Year_of_Z_Iron_Winter_GDD_EN.md                       # Game Design Document v4.0 (EN)
│       └── Year_of_Z_Iron_Winter_Greybox_Spec_EN.md              # Phase 1 Greybox Spec & Asset List (EN)
└── prototypes/                                                   # Interactive HTML5 Prototypes & Sandboxes
    ├── Year_of_Z_Iron_Winter_Playable_Greybox_Gym.html           # ★ Single-File HTML5 Playable 5-in-1 Greybox Gym (Bilingual ZH/EN)
    ├── Z年纪事_结局分支与双线汇聚流程图.html                     # 俄式“卌”字划痕与五结局交互模拟器 (ZH)
    ├── Year_of_Z_Iron_Winter_Ending_Simulator_EN.html            # Dual-Anchor & 5-Ending Tally Simulator (EN)
    └── Z年纪事_核心关卡俯视角平面动线图.html                     # 核心关卡俯视角平面动线与战术沙盘 (Tactical Blueprints)
```

---

## 🎮 Playable HTML5 5-in-1 Greybox Prototype (`Year_of_Z_Iron_Winter_Playable_Greybox_Gym.html`)

Open `prototypes/Year_of_Z_Iron_Winter_Playable_Greybox_Gym.html` directly in any modern browser (no local server or build step required). Features instant **中文 / EN** switching and procedural Web Audio API sound effects:

* **Room A (Searchlight "Borrowing the Knife" & Frozen Slush)**: Hold `Ctrl` to hide in the high-pressure steam pipe's shadow from the patrolling **O.S.K. Purge Soldier** (`45°` searchlight cone), and press `G` to throw an empty sardine tin toward the Rabid Infected so the soldier eliminates them for you.
* **Room B (Railway Crowbar Door Wedge & `12cm` Fence Gap)**: Press `E` to wedge a deformed steel door shut for `15s` with your railway crowbar, and push a warm buckwheat lunchbox through a `12cm` drainage gap.
* **Room C (The Paper Dead & Choice A `卌` Tally)**: Record **Sergey & Maria**'s real names on the back of your Work Logbook when the Soviet teletype terminal reads `0 PERSONS AT COORDINATE`, and resolve **Choice A** with the Regressing Half-Human in the culvert.
* **Room D (Siberian Wolfdog "Ash / Пепел" Tri-State Olfactory AI)**: Walk past 3 quarantine cages to test Ash's automatic olfactory detection (`Bark` vs. `Whimper` vs. `Tail Wag`) and speak with self-bound **Anna (`0419`)** about Sister **Lana (`0420`)** in Carriage No. 3.
* **Room E (East Street Canteen Kitchen — Collarbone Blade Jam QTE & PTSD Thirst)**: Equip the rusty Butcher Cleaver, confront **Vasily** in `40°C` delirium, complete the **6-hit Collarbone Blade Jam QTE**, witness his eyes clear to blue as he whispers *"…Пить (Thirsty)…"*, and experience the permanent **PTSD Thirst Tinnitus** when drinking water (`Press Q`).

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
