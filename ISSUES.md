# 问题清单（ISSUES）

分级口径：

- **P0**：崩溃、存档 / 进度丢失、结算逻辑错误、严重性能瓶颈。
- **P1**：功能缺陷、明显卡顿、UI 错误。
- **P2**：体验或维护性问题，不影响正确性。

状态：✅ 已修复并有测试 / 运行验证 · 🟡 部分处理 · ⏳ 未修（附理由）

每一项都写明复现方式、修复位置与验证手段。排查方式：逐条阅读战役 ↔ 夜潜交接链路、存档、夜潜主循环与玩家移动代码，
外加 `tools/bench_night.gd` 实测帧耗时；没有跑通真机（GPU）渲染，渲染相关结论只基于代码与 headless 计时。

---

## P0

### P0-1 ✅ 夜潜结算可被重复执行（结算无幂等保护）
- **现象**：任何路径第二次调用结算（`finish_raid` / 夜潜回写）都会再做一次道德账写入；节点化夜潜在 `finish_raid` 之前直接
  `raid_add_conscience` / `raid_add_tally`，重复触发会重复记良知与卌。
- **修复**：`CampaignSim.submit_raid_result()` 唯一入口 + `raid_id`；第二次提交返回 `{}`，`last_rejection = "already_settled"`。
- **验证**：`tests/raid_contract_smoke.gd`「second submit changes nothing」（5 种收场 + 灰盒 4 种 + 场景往返）。

### P0-2 ✅ 「回 602 室」同帧触发两次会丢掉整局战役状态
- **现象**：夜潜结束画面上按钮与 Enter / Esc 同帧触发时，第二次 `_return_to_campaign` 看到 `sim.raid == null`，
  执行 `RaidBridge.clear()`；`campaign.tscn` 的 `_ready` 拿不到原 sim，新开一局 —— 这一夜的收获、剧情进度都丢失（只剩出发前的自动存档）。
- **修复**：`NightExplore._return_to_campaign()`：`sim.raid == null` 时只切场景，不清桥。
- **验证**：`raid_contract_smoke`「a second return does not settle again」+「campaign.tscn takes the same sim back」。

### P0-3 ✅ 非结束状态下的 Enter / Esc 会按「撤离」结算
- **现象**：`_unhandled_input` 对 `state != "play"` 的 Enter / Esc 一律 `_return_to_campaign(state)`；
  `cutscene` / `interaction` / `modding` 状态没有被消费的按键会以这些字符串作为 reason 进入结算，
  旧 `finish_raid` 的 `match` 默认分支把它们当成撤离：背包全额入库、这一夜直接结束。
- **修复**：`NightExplore.END_STATES` 白名单，非结束状态直接忽略；结算入口对非法 reason 返回 `bad_reason`。
- **验证**：`raid_contract_smoke`「a non-end state does not settle the raid」「an illegal end reason is rejected」。

### P0-4 ✅ 场景切换失败后迟到的结果仍可能入账
- **现象**：`Campaign._process` 切夜潜场景失败会 `cancel_departure()` 归还携带物；旧逻辑没有「这一局已作废」的概念。
- **修复**：`cancel_departure()` 关闭当前局；之后的结果因 `no_open_raid` 被拒。
- **验证**：`raid_contract_smoke`「cancel_departure closes the raid so a late result cannot settle」。

## P1

### P1-1 ✅ 从夜潜回战役时桥上 sim 为空会崩溃
- **现象**：`Campaign._ready` 在 `RaidBridge.active` 时直接 `sim = RaidBridge.take_sim()`；桥上 sim 为 null（`begin(null, …)` 的测试 / 异常路径）时，
  随后 `sim.sound_on` 空引用崩溃。
- **修复**：`Campaign._ready` 取不到 sim 就开新档。
- **验证**：`raid_contract_smoke`「bridge without a sim: campaign opens a fresh game instead of crashing」。

### P1-2 ✅ 节点化夜潜没交结果就回到战役，会在 602 界面里跑起灰盒夜潜
- **现象**：sim 仍是 `phase = "raid"` 且带着 RaidSim 容器时，`Campaign._process` 会把本该是节点化地点的夜晚当成旧灰盒原地运行。
- **修复**：`Campaign._unsettled_node_raid()` 识别这种情况，`cancel_departure()` 作废这一局、退回携带物、回到地图，并打一条 warning。
- **验证**：`raid_contract_smoke`「an unsettled node raid is cancelled, not run as a greybox raid」「cancelling refunds the carried items once」
  「a cancelled night does not count as a visit」。

### P1-3 ✅ 夜潜 HUD 每帧无条件刷新（≈0.31 ms / 帧，占夜潜逻辑一半）
- **现象**：`_refresh_hud()` 每帧对十几个 Label `add_theme_color_override`，即使颜色没变也会发主题变更通知、触发重排。
- **修复**：`NightExplore._hud_color()` 只在颜色变化时写覆盖（17 处）。
- **数据**（`tools/bench_night.gd`）：HUD 刷新 298–363 µs → 104–114 µs（约 −64%）；`NightExplore._process` 平均 0.60–0.70 ms → 0.46–0.56 ms。
- **剩余**：HUD 仍是最大单项（字符串拼接、方位 / 威胁扫描）；进一步优化要把 HUD 拆成按事件刷新（T06 HUD 抽离时一起做）。

### P1-4 🟡 高刷新率屏幕上人物 / 镜头抖动
- **现象**：玩家在 `_physics_process`（60 Hz）里移动，镜头在 `_process` 里跟随物理位置；144 Hz 屏上每 2–3 帧才前进一步。
- **修复**：`NightPlayer` 记录上一 / 这一物理 tick 的位置，按 `Engine.get_physics_interpolation_fraction()` 把可见子节点（精灵、影子、手电、光晕）
  平移到插值位置；镜头跟随 `visual_position()`；出生点等传送立即生效（不滑行）。碰撞体与逻辑位置不变，不影响判定。
  没有打开全局 `physics_interpolation`：那会让 Overlay 里按逻辑坐标画的光锥 / 波纹与插值后的精灵错位，且无法在 headless 下验证。
- **验证**：`raid_contract_smoke`「visual position stays between the last two physics ticks」「a teleport shows up immediately」「collision shape is never offset」。
- **剩余**：敌人仍按 60 Hz 步进（镜头不跟它们，观感影响小）；真机高刷屏观感未实测。

## P2 / 未修（按优先级）

- ✅ P2 night_explore 首帧约 12 ms 尖峰（首次独白现场加载头像）—— 已改为缓存 + 预读，最坏帧降到 1.7 ms（OPTIMIZATION_LOG R2-5）。
- ✅ P2 HUD 每帧整页刷新 → 按签名变化刷新，600 帧整页刷新 600 → ≈100 次，`_process` 再降约 30%（OPTIMIZATION_LOG R3-2）。
- ✅ P2「对象堆积」核实为贴花池填充期，约 60 秒后稳定在 ≈2930，无泄漏、无孤儿节点（OPTIMIZATION_LOG R3-1）。
- ⏳ P2 敌人仍按 60 Hz 步进（只给玩家与镜头做了插值）。

## T04（已处理）

- ✅ 灰盒 RaidSim 夜里实时写战役（抉择良知 / 卌 / 旗标、搜刮余量）→ 攒成增量，结算入口一次性入账（OPTIMIZATION_LOG R3-3）。
- ✅ NightExplore 直接写 `flags.*_seen` / `vasily_killed` / `seen.night` → 随 RaidResult 提交。
- ✅ 节点化地点出发时构建整张灰盒 RaidSim → 轻量 `RaidAttempt`，出发 11.6 ms → 0.03 ms。
- ✅ P2 节点化夜潜出发前那几帧战役界面为空 → 城区地图 + 出发简报（OPTIMIZATION_LOG R3-5）。
- ✅ P2 `CampaignSim` 通过 SceneTree 找 RaidBridge → 流程层注入（OPTIMIZATION_LOG R3-4）。

---

## P1-5 ✅ 结算页「睡到明天」没有阶段保护（加固）

- **现象**：`CampaignHUD._report_sleep()` 不检查当前阶段；若在离开结算页后被再次触发（按键连发、按钮重复回调），会再执行一次 `advance_day()`，
  多扣一袋透析液 / 多推进一天（最坏情况提前触发母亲死亡）。实际操作中两次点击很难落在同一帧，没有复现到真实玩家路径，按加固处理。
- **修复**：`_report_sleep()` 开头 `if sim.phase != "report": return`。
- **验证**：`raid_contract_smoke`「sleeping from the report twice never advances more than one day」。

## P0 复核结论（2026-11-26）

逐条复核了以下模块，结论：**没有发现新的 P0**（唯一新问题按 P1 加固处理，见 P1-5）。

| 模块 | 看了什么 | 判定依据 |
|---|---|---|
| 战役 ↔ 夜潜交接 | `CampaignSim.depart / cancel_departure / submit_raid_result / finish_raid`、`RaidBridge`、`Campaign._ready / _process` 切场景与失败回退、`NightExplore._ready / _return_to_campaign / build_raid_result`、`RaidAttempt` | 唯一结算入口 + `raid_id` 拒收重复与过期结果；切场景失败与「没交结果就回来」都会作废本局并退回携带物；桥上空 sim 不再崩溃；夜里不再直接写战役状态。`raid_contract_smoke` 200 项覆盖四种收场、重复提交、拒收、恢复路径与真实场景往返。 |
| 存档 | `SaveGame.save`（.tmp → 校验 → .bak → .prev 原子替换）、`read_raw` 回退顺序、`_parse_file` 结构校验、`apply`（report 档补 `to_base`、`night_complete` 缺省推断）、`can_save`（夜潜中途拒存） | 任一步失败都至少保留一份可读旧档；结算页存档读回后同一天、不能再出发、旧结果拒收（`raid_contract_smoke`「save boundaries」11 项、`save_pause_smoke` 83 项）。新增的 `lost` 键对旧档向后兼容。 |
| 夜潜主循环 | `NightExplore._process` 各段、`_end` 触发条件（天亮 / 冻倒 / 倒下只在 `play` 状态）、`damage_player` / `_check_downed`、全部 `RaidBridge.sim` 读取 | 所有桥上读取都有空值保护；结束只在 `play` 状态触发一次；非结束状态不会提交结算（END_STATES）。 |
| 玩家移动与渲染 | `NightPlayer._physics_process / _process`（渲染插值）、镜头跟随、出生点传送 | 碰撞体与逻辑坐标不受插值影响；传送立即生效；有单元断言。 |
| 性能 | `tools/bench_night.gd` | 本轮复测时机器负载高（CPU 36%，换用 Temp 目录下的 Godot 副本），所有指标同比例变慢 1.5–3 倍，包括本轮没改过的玩家移动与 HUD 直调微基准，判定为环境因素；`_process` 平均仍 ≤ 0.66 ms / 帧，远低于 16.7 ms 帧预算，没有严重性能瓶颈。 |

剩余的已知风险都不是 P0：敌人仍按 60 Hz 步进、真机高刷屏观感未实测、灰盒 RaidSim 路径的去留待定（见上方 P2 / 遗留）。
