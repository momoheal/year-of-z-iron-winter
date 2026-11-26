# 优化日志（OPTIMIZATION_LOG）

每个阶段结束都跑一次完整回归（`python godot_project/tools/run_tests.py`），并在这里记录做了什么、改了哪些文件、验证结果。
按要求 **不做 git commit / push**，全部改动停留在工作区（分支 `fix/campaign-save-release-checks`）。

> 工作区开始时已有他人未提交的改动（`NightExplore.gd`、`CutsceneData.gd`、`first_night_smoke.gd`、`night_zones_smoke.gd` 与两份文档），
> 本轮在其之上继续修改，没有回退、暂存或覆盖它们。

## 基线

- 2026-11-11 任务说明里的基线（13 套 / 1565 项）已过时：仓库之后合入了大量功能。
- 2026-11-24 开工时的现存测试为 **21 套**；在本轮改动之后这 21 套共 **3953 项全部通过**（各套项数与开工时一致，详见阶段 0）。

测试命令：

```bash
GODOT="C:/Users/admin/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" python godot_project/tools/run_tests.py
```

性能基准命令（阶段 3 前后对比用，新增）：

```bash
"C:/Users/admin/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" --headless --path godot_project -s tools/bench_night.gd
```

---

## 阶段 0 · T01–T03 夜潜交接契约（2026-11-24 完成）

**做了什么**

- T01：字段清单 `docs/zh/夜潜交接契约_字段清单_T01.md` 按当前代码复核补齐（新增 weapon_mods、剧情进度槽位、冷库线索、缴获武器、拒收原因）。
- T02：新增类型化 `RaidConfig` / `RaidResult`（RefCounted），提供与旧 Dictionary 的互转；`RaidResult.from_raid_sim()` 是旧灰盒 RaidSim 的适配器。
- T03：每次出发分配 `raid_id`（`d<天>-<地点>-<序号>`，进程内全局递增），cfg / RaidSim / RaidBridge / RaidResult 携带同一标识；
  `CampaignSim.submit_raid_result()` 成为唯一结算入口，只接受当前未结算的一局，拒收原因写入 `last_rejection`；
  `finish_raid(reason)` 保留为旧入口，内部适配后走同一入口。
- NightExplore：`_return_to_campaign()` 只负责 `build_raid_result()` + 一次提交 + 切场景，不再直接写 `sim.raid` / 良知 / 卌 / 音效 / 武器改造 / 报告。

**行为变化（刻意的）**

1. 同一结果第二次提交被拒收，仓库、良知、卌、地点余量、日期、旗标、日志全部不变。
2. 夜潜结束后同帧重复触发「回 602 室」（按钮 + Enter）：以前会 `RaidBridge.clear()`，战役场景拿不到原 sim 而新开一局（这一夜的收获丢失）；现在只切场景、保留 sim。
3. 过场 / 交互 / 改装面板状态下的 Enter / Esc 不再触发结算（以前会以 "cutscene" 等原因结算，并按「撤离」口径全额入库）。
4. `cancel_departure()`（场景切换失败）会关闭当前局，迟到的结果无法再入账。

**未改变**：损失规则（天亮按背包下标隔项保留、hp −22 下限 6）、剧情奖励、数值、存档格式与 `SaveGame.VERSION`（`raid_id` 等只在内存，不写盘）。

**改动文件**

- 新增：`godot_project/scripts/raid/RaidResult.gd`、`godot_project/tests/raid_contract_smoke.gd`、`godot_project/tools/bench_night.gd`
- 修改：`godot_project/scripts/raid/RaidConfig.gd`（weapon_mods）、`godot_project/scripts/CampaignSim.gd`、`godot_project/scripts/RaidSim.gd`（raid_id 字段）、
  `godot_project/scripts/night/NightExplore.gd`（`_return_to_campaign` / `build_raid_result` / END_STATES）、`godot_project/autoload/RaidBridge.gd`、
  `docs/zh/夜潜交接契约_字段清单_T01.md`

**验证**

- 新套件 `raid_contract_smoke.gd`：156 项，覆盖四种收场（+ frozen→downed）、携带物（出发只扣一次 / 节点化不重复归还 / 灰盒剩余原样归还）、弹药只记录不入库、良知与卌一次性入账、卌上限、拒收（错局 / 非法原因 / 无标识 / 未出发 / 取消出发后）、重复提交零变化、次日只推进一次，以及真实场景往返（冷库场景 → `build_raid_result` → `campaign.tscn` 取回同一 sim → 再次触发不重复结算）。
- 全量：**22 套 / 4109 项全部通过，0 脚本错误**。

**遗留风险**

- 灰盒 RaidSim 仍在夜里实时写战役（抉择 A 的良知 / 卌 / 旗标、搜刮时节点余量）；NightExplore 仍直接写 `flags.redzone_mother_seen`、`seen.night`，剧情进度写在 `sim.raid` 当局容器上。属于 T04（流程层接管桥接）范围。
- 节点化地点出发时仍会构建完整 RaidSim（生成灰盒地图），只为承载剧情进度字段；T04 再拆。

**性能基线（阶段 3 之前，`tools/bench_night.gd`，600 帧脚本走位，两次运行取范围）**

| 场景 | NightExplore._process 平均 / p95 | 其中 HUD 刷新 | 玩家移动 平均 / p95 | 600 帧对象增长 |
|---|---|---|---|---|
| night_explore | 0.66–0.70 / 0.88–1.02 ms | 309–322 µs | 0.041–0.044 / 0.08–0.10 ms | +209–214 |
| night_coldstore | 0.60–0.63 / 0.88 ms | 309–319 µs | 0.045–0.048 / 0.10 ms | +166 |
| night_market | 0.65–0.67 / 0.91–1.02 ms | 298–363 µs | 0.048–0.051 / 0.09–0.11 ms | +137–140 |

结论：每帧逻辑里一半时间花在 HUD 刷新（每帧无条件重设文本 / 主题色覆盖、拼字符串）。

---

## 阶段 1 · 项目结构优化（2026-11-25）

**做了什么**（只做低风险、可验证的去重与职责收口；大文件拆分见下方「刻意没做」）

1. `tests/smoke_kit.gd`（新增）：17 套冒烟测试共用的计数 + `_assert` 底座。原来每套各拷一份 6 行 `_assert` 和两行计数变量，参数名还各不相同（n / name / label）。
   这些测试改为 `extends "res://tests/smoke_kit.gd"`。`first_night_smoke` / `night_zones_smoke`（工作区里有他人未提交改动）、`opening_smoke` / `data_pipeline_smoke`（计数口径不同）、`story_emotions_smoke`（断言写法不同）保持原样。
2. `scripts/night/NightLighting.gd`（新增）：玩家与清杀兵手电「Objects 光层遮挡」的同一段设置抽成静态函数，两处调用，避免两份拷贝漂移。
3. `NightExplore._campaign_attempt()`：8 处重复的 `in_campaign and RaidBridge.sim != null and RaidBridge.sim.raid != null` 判空收成一个函数；
   搜刮掉落循环里把当局容器与战役旗标提到循环外各取一次。
4. 夜潜结算链路的职责收口（阶段 0 已完成）：NightExplore 只构建结果，CampaignSim 只在一个入口写状态。

**刻意没做（保守决策）**

- 没有拆 `NightExplore.gd`（4.3k 行）/ `CampaignHUD.gd`（2.4k 行）：计划文档把 HUD / 战斗拆分排在 M1 验收之后（T06/T07），
  且 `NightExplore.gd` 工作区里有他人未提交的改动，大拆分会让对方无法合并。
- 没有统一 GDScript 命名：现有命名已基本一致（snake_case 函数、PascalCase 脚本、`_` 私有前缀），批量改名收益低、冲突面大。

**改动文件**：`godot_project/tests/smoke_kit.gd`（新）、17 个 `tests/*_smoke.gd`、`godot_project/scripts/night/NightLighting.gd`（新）、
`godot_project/scripts/night/NightPlayer.gd`、`godot_project/scripts/night/NightSoldier.gd`、`godot_project/scripts/night/NightExplore.gd`

**验证**：全量 **22 套 / 4109 项全部通过，0 脚本错误**（与阶段 0 结束时逐套项数一致，说明测试底座替换没有吞掉任何断言）。

---

## 阶段 2 · P0 / P1 排查与修复（2026-11-25）

清单与复现方式见根目录 `ISSUES.md`。本阶段修复：

- P0-1 结算无幂等保护、P0-2 重复「回 602 室」丢整局、P0-3 非结束状态按撤离结算、P0-4 取消出发后迟到结果入账（阶段 0 的契约改造一并解决）。
- P1-1 桥上 sim 为空时回战役崩溃：`Campaign._ready` 取不到 sim 就开新档。
- P1-2 节点化夜潜没交结果就回到战役会原地跑灰盒：`Campaign._unsettled_node_raid()` + `cancel_departure()`（退回携带物、不计访问、回地图）。

**改动文件**：`godot_project/scripts/Campaign.gd`、`godot_project/tests/raid_contract_smoke.gd`（新增「recovery」段）、`ISSUES.md`（新）

**验证**：`raid_contract_smoke` 新增 5 项全部通过；全量见阶段 3。

---

## 阶段 3 · 移动流畅度与帧耗时（2026-11-25）

**做了什么**

1. HUD 颜色覆盖去抖：`NightExplore._hud_color()` 只在颜色变化时调用 `add_theme_color_override`（`_refresh_hud` 内 17 处）。
2. 玩家渲染插值：`NightPlayer` 记录上一 / 这一物理 tick 位置，`_process` 里按 `Engine.get_physics_interpolation_fraction()` 平移可见子节点；
   镜头跟随 `visual_position()`；出生点传送后 `snap_visual()`。碰撞体与逻辑坐标不动。
   **没有**打开项目级 `physics/common/physics_interpolation`（保守：Overlay 按逻辑坐标绘制的光锥 / 波纹会与插值精灵错位，且 headless 无法验证画面）。
3. `tools/bench_night.gd` 增加逐函数拆分（µs），便于下一轮找热点。

**数据**（`tools/bench_night.gd`，600 帧脚本走位，headless，两次运行取范围）

| 场景 | `_process` 平均 前 → 后 | p95 前 → 后 | HUD 刷新 前 → 后 | 玩家移动 平均 |
|---|---|---|---|---|
| night_explore | 0.66–0.70 → 0.54–0.56 ms | 0.88–1.02 → 0.69–0.77 ms | 309–322 → 112–114 µs | 0.041–0.044 → 0.041–0.042 ms |
| night_coldstore | 0.60–0.63 → 0.46 ms | 0.88 → 0.64–0.66 ms | 309–319 → 108–140 µs | 0.045–0.048 → 0.042–0.043 ms |
| night_market | 0.65–0.67 → 0.49–0.50 ms | 0.91–1.02 → 0.66–0.69 ms | 298–363 → 104–113 µs | 0.048–0.051 → 0.043–0.044 ms |

逐函数（µs，night_coldstore）：`_refresh_hud` 107 · `_update_interact` 27 · `_update_combat` 15 · `_update_director` 10 · `_update_zone` 6 · `_update_post` 6 · 其余 < 4。
night_explore 首帧有一次约 12 ms 的尖峰（两次运行都在），以及 `_update_director` 64 µs，留给下一轮。

插值的效果是视觉上的（高刷屏不再阶梯抖动），headless 下无法量化；用单元断言保证「显示位置始终落在相邻两个物理 tick 之间、传送立即生效、碰撞体不偏移」。

**改动文件**：`godot_project/scripts/night/NightExplore.gd`、`godot_project/scripts/night/NightPlayer.gd`、`godot_project/tools/bench_night.gd`、`godot_project/tests/raid_contract_smoke.gd`（「render interpolation」段）

**验证**：全量 **22 套 / 4120 项全部通过，0 脚本错误**（`raid_contract_smoke` 167 项）。

---

## 阶段 4 · 美术 / UI 可读性与资源体积（2026-11-25）

**做了什么**

1. 资源体积：`art/generation_runs`、`art/10_characters/generation_runs`、`art/30_props/generation_runs` 加 `.gdignore`。
   这三处是出图过程稿（共 **491 MB / 798 张 PNG**），导出预设早已排除、`tools/check_export.gd` 也断言它们不得进包，
   但编辑器和 `run_tests.py --import` 每次新克隆都要把它们全部导入（`.godot/imported` 约 3.5k 个文件）。现在 Godot 跳过这些目录；
   Python 出图 / 校验脚本按文件系统路径读，不受影响。仓库里已跟踪的 802 个对应 `.import` 文件保持不动（变为惰性，删除与否留给美术负责人）。
2. 可读性（按 1920×1080 实机截图前后对比）：
   - 暂停菜单说明文字 11/12 px → 13 px，颜色 ASH → BONE_DIM（深底上对比度不足）；
   - 夜潜顶部简报卡正文 14 → 16 px（卡片仍整体缩放 0.78，位置不变，不挡视野）；
   - 右侧「勘踏 / 未勘」行 12 → 13 px、ASH → BONE_DIM；世界坐标里的地标小标签 11 → 12 px。
3. 新增 `tools/capture_readability.gd`（非 headless 截图：HUD + 暂停菜单），截图在 `godot_project/screenshots/readability_before_*.png` / `readability_after_*.png`。

**刻意没做**：没有重压缩 / 重生成已跟踪的美术 PNG —— 无损重压只会给 git 历史再加一份同等体积的二进制，反而让仓库更大；
没有改全局 `FONT_SIZES`（602 室界面 47 处引用，无截图回归测试保护，排版溢出风险高）。

**改动文件**：3 个 `.gdignore`（新）、`godot_project/scripts/ui/PauseMenu.gd`、`godot_project/scripts/night/NightExplore.gd`、`godot_project/tools/capture_readability.gd`（新）、4 张截图

**验证**：前后截图人工核对无溢出、无遮挡；全量见阶段 5。

---

## 阶段 5 · 可玩性（2026-11-25）

详见根目录 `GAMEPLAY.md`。三项只加反馈、不改数值：天亮前背包行预告保留项、最后 15 秒天亮催促、结算页「丢在路上」。
结算报告新增 `lost` / `lost_order` 键（展示用，旧档无此键时不显示；`SaveGame.VERSION` 不变）。

**改动文件**：`godot_project/scripts/night/NightExplore.gd`、`godot_project/scripts/CampaignSim.gd`、`godot_project/scripts/CampaignHUD.gd`、`godot_project/tests/raid_contract_smoke.gd`、`GAMEPLAY.md`（新）

**验证**：`raid_contract_smoke` 174 项；全量 **22 套 / 4127 项全部通过，0 脚本错误**。

---

## 第二轮 · 深化（2026-11-25）

### R2-1 最终基准对比（`tools/bench_night.gd`，两次运行取范围）

| 场景 | `_process` 平均：开工 → 现在 | p95：开工 → 现在 | HUD 刷新 |
|---|---|---|---|
| night_explore | 0.66–0.70 → 0.54–0.56 ms（≈ −20%） | 0.88–1.02 → 0.74–0.76 ms | 309–322 → 111–143 µs |
| night_coldstore | 0.60–0.63 → 0.46 ms（≈ −25%） | 0.88 → 0.64–0.67 ms | 309–319 → 110–112 µs |
| night_market | 0.65–0.67 → 0.50–0.52 ms（≈ −23%） | 0.91–1.02 → 0.74–0.77 ms | 298–363 → 114–117 µs |

玩家移动 0.040–0.047 ms，与开工持平（插值只多一次向量插值）。

### R2-2 第二轮热点
- `NightMonuments.update()`：旗帜精灵只在帧号变化时才写 `frame`（每次赋值都会发 `frame_changed` 并重画）。微基准 54 → 40 µs；
  全量基准里 night_explore 的 `_update_director` 仍是 47–63 µs —— 剩余开销来自开场那几秒的独白框（`_show()` 里按需 `load()` 头像、写颜色），属于事件驱动，不是稳态每帧开销，未继续改。
- 结算链路（`submit_raid_result`）只在收场时执行一次，不在每帧热路径上，不做性能重构。
- night_explore 首帧约 12 ms 尖峰：两轮都在，来自首次显示独白时加载头像贴图；可通过预加载头像消除，留作下一项。

### R2-3 边界测试（`raid_contract_smoke` 新增「save boundaries」段，11 项）
空档位读档不改战役；夜潜中途存档被拒；结算页存档 → 读回落在 602、同一天，仓库 / 良知 / 卌一致；「丢在路上」随存档往返；读档后旧结果以 `no_open_raid` 拒收。
连同前面的「recovery」（桥上空 sim、未交结果回战役）与「stale result after the next day」，覆盖空存档、中断的夜潜、跨天结算。

### R2-4 清理
删除临时脚本（`dupes.py`、各补丁脚本、`probe_director.gd`，均在会话暂存目录、未进项目）。项目内新增的 `tools/bench_night.gd`、`tools/capture_readability.gd` 是保留下来的正式工具。

**改动文件**：`godot_project/scripts/night/NightMonuments.gd`、`godot_project/tests/raid_contract_smoke.gd`

**验证**：`raid_contract_smoke` 185 项；全量 **22 套 / 4138 项全部通过，0 脚本错误**。

### R2-5 首帧尖峰
- `NightMonuments`：独白头像加缓存，出生时按本关旧物 × 主角预读，伙伴生成后再预读伙伴的；`_show()` 不再现场 `load()`。
- night_explore 最坏一帧 **12.2–12.6 ms → 1.6–1.7 ms**（两次运行）；全量 22 套 / 4138 项通过。
- 改动文件：`godot_project/scripts/night/NightMonuments.gd`

### 下一轮可推进的工作
1. HUD 改为按事件刷新（T06 抽离 HUD 时一起做），目标再降 60–80 µs / 帧。
2. 600 帧对象数增长 +130–220（浮字 / 波纹 / 脚印）：核对贴花池上限是否生效。
3. T04：流程层接管桥接，去掉节点化地点出发时构建整张灰盒 RaidSim。
4. 真机高刷屏验证玩家插值观感；如效果好，再评估敌人插值。

---

## 第三轮 · Still open 项（2026-11-25）

### R3-1 对象「堆积」排查：不是泄漏，是有上限的贴花池在填满

方法：独立模式走位，每 600 帧记一次对象 / 节点 / 存活 tween / 两个贴花池长度（`night_explore`，共 4800 帧）。

| 区段（600 帧） | 对象数 | 节点数 | 存活 tween | 脚印池 `_tracks` | 记号池 `_marks` |
|---|---|---|---|---|---|
| 0 | 2652 | 395 | 15 | 15 | 4 |
| 2 | 2778 | 433 | 35 | 34 | 10 |
| 4 | 2889 | 474 | 52 | 52 | 19 |
| 6 | 2923 | 486 | 57 | 56 | 22 |
| 7 | 2929 | 488 | 57 | 57 | 22 |

- 增长来自脚印：每步 1 个 Sprite2D + 1 个绑定在它身上的淡出 tween，25 秒（`DECAL_TRACK_FADE`）后释放；步频约 2.2 步 / 秒，稳态约 55 个，上限 `DECAL_TRACKS_CAP = 64`。
  血迹 / 弹孔等记号上限 `DECAL_MARKS_CAP = 48`。站着不动 600 帧对象只 +14（浮字 / 波纹，自带上限 6）。
- 约 60 秒后对象数稳定在 ≈2930，不再增长；没有孤儿节点（`OBJECT_ORPHAN_NODE_COUNT = 0`）。
- **结论：不改代码。** 改成复用精灵只省每秒约 2 次分配，收益可忽略，反而增加池管理复杂度。基准里的「+130–220」是测量窗口（前 10 秒）正好处在池子填充期。

### R3-2 HUD 改为按变化刷新

- `NightExplore._hud_tick()`：每帧只算 `_hud_signature()`（状态、背包内容、武器与弹药、良知 / 卌 / 罐头、整数 hp / 体温、区域、姿态、
  量化到 24 px 的玩家位置、撤离 / 搜刮百分比、时钟秒、节拍、交互类型、剧情目标位…）的哈希；变了才整页刷新文字，
  否则最多 `HUD_MAX_STALE = 0.1 s` 强制刷一次（敌人走动带来的距离 / 方位变化）。仪表和屏幕边框每帧照常更新。
- 直接调用 `_refresh_hud()`（事件、测试）仍是整页刷新，原有测试无需改动。
- 新增计数 `hud_full_refreshes`，基准输出「每 600 帧整页刷新次数」。

| 场景 | `_process` 平均 前 → 后 | p95 前 → 后 | 600 帧整页刷新 |
|---|---|---|---|
| night_explore | 0.54–0.56 → 0.37–0.38 ms | 0.74–0.76 → 0.60 ms | 600 → ≈101 |
| night_coldstore | 0.46 → 0.33–0.34 ms | 0.64–0.67 → 0.54–0.57 ms | 600 → 101 |
| night_market | 0.50–0.52 → 0.35 ms | 0.74–0.77 → 0.55–0.56 ms | 600 → ≈100 |

与开工基线相比，夜潜每帧逻辑合计下降约 **45%**（0.60–0.70 → 0.33–0.38 ms）。

**改动文件**：`godot_project/scripts/night/NightExplore.gd`、`godot_project/tools/bench_night.gd`、`godot_project/tests/raid_contract_smoke.gd`（3 项：不变帧跳过、变化当帧刷新、最长陈旧 0.1 s）

**验证**：`raid_contract_smoke` 188 项；全量 **22 套 / 4141 项全部通过，0 脚本错误**。

### R3-3 T04：流程层接管桥接，夜里不再写战役状态

**做了什么**

1. `scripts/raid/RaidAttempt.gd`（新）：节点化地点的轻量当局容器，字段名与 RaidSim 一致（标识、地点、伙伴、武器、携带物、剧情进度槽位）。
   `CampaignSim.depart()` 对带 `scene` 的地点只建它，不再生成整张灰盒地图；灰盒地点照旧建 RaidSim。
   `CampaignSim.greybox_raid()`：战役场景里的灰盒更新 / 输入 / 绘制 / 夜潜面板 / 抉择框全部经它读取（`Campaign.gd` 22 处、`CampaignHUD.gd` 20 处），节点化当局容器不会被当成灰盒跑。
   `force_greybox` 开关只给需要驱动灰盒机制的测试用（`campaign_smoke` 打开）。
2. NightExplore：`vasily_killed`、`mine_inscriptions_seen`、`redzone_mother_seen` 旗标与 `seen.night` 记在本地（`_set_campaign_flag` / `_campaign_flag` 查询本地 + 战役），随 `RaidResult.flags_set` / `seen_set` 提交。
3. 灰盒 RaidSim：抉择良知按顺序记 `conscience_steps`（原先每笔各自 clamp，按顺序重放才等价）、卌记 `tally_marks`、旗标记 `flags_set`、搜刮余量记 `node_left_delta`；
   读取 `glasses` / `ptsd` 时同时看本局已触发的旗标，避免一夜内重复掉落。
4. `submit_raid_result()` 在开头统一入账这些改动（先于剧情判定，例如食堂的 `vasily_killed` 后续仍能触发），节点余量先扣搜刮量再扣每次到访的 50%。

**行为变化**：最终状态与原先一致（含放弃 / 倒下也入账）；唯一可见差异是灰盒夜潜进行中，战役界面的良知 / 卌读数要到结算后才变（灰盒是旧路径）。

**数据**：出发耗时（5 个地点 × 3 次平均）**11.6 ms → 0.03 ms**（不再生成灰盒地图）。

**改动文件**：`godot_project/scripts/raid/RaidAttempt.gd`（新）、`godot_project/scripts/CampaignSim.gd`、`godot_project/scripts/Campaign.gd`、`godot_project/scripts/CampaignHUD.gd`、
`godot_project/scripts/RaidSim.gd`、`godot_project/scripts/raid/RaidResult.gd`、`godot_project/scripts/night/NightExplore.gd`、`godot_project/autoload/RaidBridge.gd`、
`godot_project/tests/campaign_smoke.gd`（`force_greybox`）、`godot_project/tests/raid_contract_smoke.gd`（「T04 deferred writes」段 + 场景往返新增断言，共 +10 项）、`docs/zh/夜潜交接契约_字段清单_T01.md` §5

**验证**：`raid_contract_smoke` 198 项；全量 **22 套 / 4151 项全部通过，0 脚本错误**。

### R3-4 数据桥由流程层注入（2026-11-26）

- `CampaignSim.raid_bridge` + `_raid_bridge()`：三处「自己去场景树找 RaidBridge」收成一个函数；`Campaign._ready` 注入 autoload，
  sim 在正式流程里不再依赖 `Engine.get_main_loop()`。没注入时（测试 / 工具）仍退回场景树查找，并且主循环不是 SceneTree 时返回 null 而不是崩溃。
- 保留 `bridge.begin()` 在 `depart()` 里调用：直接移到 Campaign 会让 6 套测试的「出发后立即读桥」断言全部失效，收益只是位置更好看。
- **环境变化**：`C:/Users/admin/Downloads/Godot_v4.7.2-stable_win64.exe/` 已不存在，`run_tests.py` 找不到 Godot；本轮改用
  `C:/Users/admin/AppData/Local/Temp/godot_4.7.2_runtime/Godot_v4.7.2-stable_win64_console.exe`（`--version` = 4.7.2.stable.official.ed1daf0bf，同一构建），
  通过环境变量 `GODOT` 传入。该目录在 Temp 下，可能被清理，建议把 Godot 放回固定位置。
- 改动文件：`godot_project/scripts/CampaignSim.gd`、`godot_project/scripts/Campaign.gd`
- 验证：全量 **22 套 / 4151 项全部通过，0 脚本错误**。

### R3-5 节点化夜潜切场景前的出发简报（2026-11-26）

- 以前：出发剧情播放、切进夜潜场景之前的那几帧，战役场景画黑底 + 空的夜潜面板（T04 之前画的是用不到的灰盒地图）。
- 现在：`Campaign._draw()` 只在灰盒夜潜时画灰盒；节点化出发时继续画城区地图与夜景背景，`CampaignHUD._build_departure_card()` 在底部显示「出发 · 地点 · 同行 · 背包格数」。
- 截图：`godot_project/screenshots/departure_card.png`（真实渲染，1920×1080）。
- 改动文件：`godot_project/scripts/Campaign.gd`、`godot_project/scripts/CampaignHUD.gd`
- 验证：全量 **22 套 / 4151 项全部通过，0 脚本错误**。

### 下一轮可推进的工作（更新）
1. ✅ 出发简报（R3-5）。
2. ✅ 数据桥由流程层注入（R3-4）。
3. 真机高刷屏验证玩家插值观感；敌人插值视效果再定。
4. 灰盒 RaidSim 路径的去留：正式地点已全部节点化，可评估把灰盒降级为纯测试夹具。

### R3-6 P0 复核与加固（2026-11-26）

- 按交接链路 → 存档 → 夜潜主循环 → 移动与渲染 → 性能逐项复核，结论与依据写在 `ISSUES.md`「P0 复核结论」：**无新增 P0**。
- 加固 1 项（P1-5）：`CampaignHUD._report_sleep()` 增加阶段保护，重复触发不会多推进一天。测试：`raid_contract_smoke` +2 项（200 项）。
- 改动文件：`godot_project/scripts/CampaignHUD.gd`、`godot_project/tests/raid_contract_smoke.gd`、`ISSUES.md`
- 验证：全量 **22 套 / 4153 项全部通过，0 脚本错误**。
- 基准复测（同一天两次）：night_explore / coldstore / market `_process` 平均 0.62–0.66 / 0.55–0.56 / 0.61–0.62 ms。
  **与 11-25 的数字不可直接比较**：本次机器负载高、Godot 换成 Temp 目录副本，连本轮未改动的玩家移动（0.043 → 0.065 ms）和 HUD 直调微基准（≈110 → ≈330 µs）都同比例变慢，
  wall p95 也从 7.4 ms 升到 15–17 ms。跨天对比请在同一环境下重跑 `tools/bench_night.gd`。
