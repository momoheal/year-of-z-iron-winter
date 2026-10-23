# 《Z年纪事：凛冬铁轨》Godot 4 灰盒测试场（5 合 1）移植对照表

> **目标原型**：`prototypes/Year_of_Z_Iron_Winter_Playable_Greybox_Gym.html`（1100 × 680 逻辑竞技场，Room A–E）
> **Godot 工程**：`godot_project/`（Godot 4.7.2-stable，Forward+ / Compatibility 均可）
> **不依赖外部美术与音频资产**：画面全部 `_draw()` 立即模式几何绘制；音效为启动时离线烘焙的 `AudioStreamWAV`（对应 HTML 的 Web Audio 合成）。
> **入口场景**：`res://scenes/gym.tscn`（`project.godot` 的 `run/main_scene`）。Room A 夜潜垂直切片仍保留在 `res://scenes/main.tscn`，按 `F1` 两地互切。

---

## 一、为什么先移植「灰盒测试场」而不是继续做房间

HTML 原型里有两个层次的验证：

1. `Year_of_Z_Iron_Winter_Playable_Greybox_Gym.html` —— **机制验证**：把 A–E 五个关键玩法（借刀杀人 / 卡门推饭盒 / 抉择 A 与卌 / 狼犬三态 / 锁骨卡刀 QTE）压在同一个可自由走动的方形场里，每项都有独立的验证清单。
2. `Year_of_Z_Iron_Winter_Exploration_Demo.html` —— **循环验证**：据点 → 地图选点 → 夜潜 → 搜刮 → 撤离 → 结算。

仓库此前只有「Room A 夜潜切片」的部分循环实现。本次把 **(1) 五个机制** 完整搬进 Godot，并保持 **(2) 的 Room A 切片** 可回切，形成「机制场 ↔ 夜潜切片」双场景结构；这也是后续接入真实美术、`CharacterBody2D` 与 `PointLight2D` 之前的最后一块灰盒地基。

---

## 二、文件与职责

| 文件 | 职责 | 对应 HTML |
| :--- | :--- | :--- |
| `godot_project/scenes/gym.tscn` | 单 `Node2D` 场景（新主场景） | 整个 gym 页面 |
| `godot_project/scripts/GymSim.gd` | 纯逻辑层：5 房间、玩家/狼犬/清杀兵/狂暴者、投罐、卡门、推饭盒、电传、抉择 A、三态嗅觉、QTE、PTSD、卌 划痕、清单、事件流 | `game` 状态对象 + `updateGame()` + `actionThrowCan/actionInteract/actionSwingWeapon/advanceBladeJamQte/actionDrinkWater` |
| `godot_project/scripts/Gym.gd` | 输入 + 等比视口变换 + `_draw()` 全画面立即模式渲染 | `renderGame()` + `window.keydown/mouse*` |
| `godot_project/scripts/GymHUD.gd` | CanvasLayer HUD：顶栏/侧栏/清单/简报/事件流 + 《工作日志》/抉择 A/QTE 三个模态框 | HTML 的顶栏、右侧面板、`logbookModal`、`choiceAModal`、`qteOverlay` |
| `godot_project/scripts/Sfx.gd` | 6 种程序化音效（beep / can / wedge / akm / bonejam / thirst），启动时烘焙 `AudioStreamWAV` | `playSfx()` + Web Audio 合成 |
| `godot_project/tests/gym_smoke.gd` | 61 项 headless 机制冒烟测试（本文件第四节） | 无（新增） |
| `godot_project/scripts/Main.gd` | Room A 夜潜切片（保留），新增 `F1` 返回灰盒测试场 | `Exploration_Demo.html` |
| `godot_project/scripts/Sim.gd` / `HUD.gd` | Room A 纯逻辑 / HUD（未改动） | 同上 |

---

## 三、逐机制对照

### 1. 世界、房间与相机

| HTML | Godot | 说明 |
| :--- | :--- | :--- |
| `WORLD_W = 1100`, `WORLD_H = 680` | `GymSim.WORLD_W/H` | 单位完全一致（逻辑像素） |
| `ROOM_ZONES`（A/B/C/D/E 五个 `x,y,w,h`） | `GymSim.ROOM_ZONES`（`Rect2` + 双语名） | 坐标逐值一致 |
| `ROOM_SPAWNS` | `GymSim.ROOM_SPAWNS` | 按 `1~5` 传送，替代顶部按钮 |
| `renderGame()` 里 `ctx.scale(cw/WORLD_W, ch/WORLD_H)` | `Gym._recalc_view()` 等比缩放 + 居中到 `VIEW_AREA = (10,74,1540,992)` | Godot 用等比缩放（留黑边）而非拉伸；右侧 350px 留给 HUD 侧栏 |
| 鼠标坐标换算 | `Gym.screen_to_world()` | |

### 2. Room A：探照灯「借刀杀人」+ 冻雪泥 + 蒸汽管

| HTML | Godot | 数值 |
| :--- | :--- | :--- |
| `SLUSH_RECT {65,210,155,90}` | `GymSim.SLUSH_RECT` | 逐值一致 |
| `STEAM_PIPE_RECT {155,105,140,24}` + 阴影外扩 `-10/-12/+20/+34` | `GymSim.STEAM_PIPE_RECT` + `PIPE_SHADOW_PAD(18,28,18,38)` | 注意：HTML 的**蹲伏隐匿判定**用 `-18/-28/+18/+38`，绘制阴影带用 `-10/-12/+20/+34`；Godot 两套都保留 |
| `speed 2.6 / 1.4 / 4.3`，`inSlush * 0.65` | `SPEED_WALK/CROUCH/SPRINT`、`SLUSH_FACTOR` | 逐帧常量，Godot 用 `f = dt*60` 归一化 |
| 清杀兵巡逻 `165~380`、`0.85 px/帧`、`targetAngle = π/2 ± 0.25` | `Soldier.patrol_min_x/max_x`、`update()` 第 4 段 | 一致 |
| 45° 探照灯：`arc(±0.39)`、半径 `245` | `Gym._draw_searchlight()`（贴图渐变改为逐顶点颜色渐变） | 判定角 `0.48`（狂暴者）/ `0.38`（玩家）一致 |
| 狂暴者距离 `<260` 即开火，`-55 HP`，`fireCooldown 35` 帧 | 同 | 一致 |
| 玩家暴露：`<215`、`±0.38`、未隐匿 → `max(15, hp-12)`、`bpm+25`、`fireCooldown 50` | 同 | 一致（`fire_cd` 单位：帧） |
| 空罐头：`progress += 0.06`，落地半径 `145` 声波，`<380` 引警 | `throw_can()` + `update()` 第 3 段 | 一致 |
| `p.inPipeShadow` 蹲伏才成立 | 同 | 一致 |
| 雪泥靴印 `life 240`、足音波纹 `18/48/115`、雪泥 ×1.85 | 同 | 一致 |

### 3. Room B：撬棍卡门 + 12cm 门底推饭盒

| HTML | Godot | 偏差 |
| :--- | :--- | :--- |
| 距离 `<65` 按 E → `wedgedTimer = 15*60` 帧 | `interact()` → `door_b.wedge_frames = 900` | 一致；HUD/场景显示秒数倒计时 |
| 距离 `<70` 按 E → `delivered = true`，写入真名 | 同 | 一致 |
| `taskB` 只在推饭盒时置位 | Godot 要求**卡门 + 推饭盒都完成**才置位 | **刻意修正**：单测「卡门 → 不完成；推饭盒 → 完成」 |

### 4. Room C：账面死人 + 抉择 A + 卌 划痕

| HTML | Godot | 说明 |
| :--- | :--- | :--- |
| 电传终端 `recorded`，写入谢尔盖/玛丽亚真名 | `terminal.recorded` + `add_verified("sergey_maria", …)` | 同时写入 `LogbookManager` autoload |
| 半人 `status: unresolved / saved_A1 / killed_A3` | `HalfHuman.status` 同名三态 | 一致 |
| 抉择框三个按钮 A1/A2/A3 | `choose_a("A1"/"A2"/"A3")` + 侧栏模态框 | A2 = 退开，不处置 |
| A3：`tally += 2`（上限 5）、`cans += 2` | 同 | 一致 |
| `taskC` 需「电传真名 + 半人已处置」 | 同 | 一致 |
| 卌 字形划痕 UI（`logSt1..5` 透明度） | 日志模态框 5 根笔划 Label（第 5 笔为 `╱`） | 视觉等价 |

### 5. Room D：灰烬三态嗅觉 + 安娜 0419

| HTML | Godot | 数值 |
| :--- | :--- | :--- |
| 狼犬跟随：`target = 玩家 - 朝向×28`，`lerp 0.09` | 同（`0.09 * f`） | 一致 |
| 狂吠：狂暴者 `<130` / Ⅰ号笼 `<95` / 瓦西里冲锋 `<150` | 同 | 一致 |
| 低鸣：半人 `<115` / Ⅱ号笼 `<95` | 同 | 一致 |
| 摇尾：Ⅲ号笼 `<95` / 电传终端 `<95` | 同 | 一致 |
| 距离 Ⅱ 号笼 `<80` 按 E → 安娜证言 + `taskD` | 同 | 一致 |
| 三座铁笼 96×68 框 + 标签 | `Gym._draw_room_d()` | 一致 |

### 6. Room E：砍骨刀 → 破门 → 锁骨卡刀 6 连按 → PTSD

| HTML | Godot | 说明 |
| :--- | :--- | :--- |
| 砧板 `<70` 按 E 拾取 → `weapon = cleaver` | 同 | 一致 |
| 已拾刀且 `<155` → `state = charging`，追速 `1.35 px/帧` | 同 | 一致 |
| 距离 `<34` 自动挥刀 | 同 | 一致 |
| 挥刀命中 → `state = jammed`、`qte.active`、6 次 | `swing()` / `qte_hit()` | 一致 |
| 第 6 次：`resolved`、`ptsdUnlocked = true`、`bpm = 168`、真名 + `taskE` | 同 | 一致 |
| `Q` 喝水：PTSD 时闪屏 90 帧、`bpm = 152`；否则 `bpm = max(72, bpm-15)` | 同 | 一致 |
| `time_scale` / 环形 1.5s 限时（迁移文档描述） | **未实现限时**：与 HTML gym 一致，6 次连按无超时 | 刻意保持与原型一致；1.5s 限时留待正式关卡 |

### 7. 全局系统

| HTML | Godot |
| :--- | :--- |
| `I18N.zh / I18N.en` 即时切换（按钮） | `GymSim.toggle_lang()`（`L` 键 / 侧栏按钮），HUD 全量重取文本 |
| `glassesCracked` → 视野 `275 → 165` | 同（`F` 键 / 侧栏按钮），并叠加红色裂痕透镜遮罩 |
| `soundEnabled` | `muted`（`M` 键 / 侧栏按钮） |
| `logbookModal`（真名 + 卌 + 描述） | `GymHUD` 日志模态框（`Tab`） |
| `eventFeed`（最多 40 条，显示最新几条） | `GymSim.feed`（上限 40）+ 侧栏显示最新 3 条 |
| `checklist` 5 项 + 进度 | 侧栏清单 + 进度（`5/5` 时世界内出现通过横幅） |
| `Reset Gym` | `sim.reset()`（`F5` / 侧栏按钮），保留语言与眼镜状态 |
| Room A–E 传送按钮 | `1~5` 键 |

---

## 四、headless 测试清单（`tests/gym_smoke.gd`，61 项）

```bash
Godot_v4.7.2-stable_win64 --headless --path godot_project -s tests/gym_smoke.gd
# 成功输出 GYM_SMOKE_PASS；失败逐条打印 FAILED 并以退出码 1 结束
```

| # | 断言 | # | 断言 |
| :--- | :--- | :--- | :--- |
| 1 | 主场景 = `gym.tscn` | 32 | A2 退开不处置 |
| 2 | 24 个输入 action 全部存在 | 33 | A1 救人且 0 划痕 |
| 3 | `gym.tscn` 可加载 | 34 | `taskC` 通过（真名 + 抉择） |
| 4 | 场景持有 Sim + HUD | 35 | A3 灭口 +2 划痕 |
| 5 | HUD 绑定同一 Sim | 36 | A3 搜刮 +2 罐头 |
| 6 | Room A 出生点 (85,145) | 37 | 卌 上限 5 |
| 7 | HP/BPM/罐头/初始武器 | 38 | 卌 下限 0 |
| 8 | 0 划痕 / 无 PTSD / 0 任务 | 39 | Ⅰ号笼 → 狂吠 |
| 9 | 日志初始只有卡佳妈妈 | 40 | Ⅱ号笼 → 低鸣 |
| 10 | 灰烬初始跟随 | 41 | Ⅲ号笼 → 摇尾 |
| 11 | 5 个房间区域 | 42 | 安娜证言 → `taskD` |
| 12 | 1–5 传送落点正确 | 43 | 砍骨刀拾取 |
| 13 | 初始站立 | 44 | 瓦西里破门 |
| 14 | 蹲伏进入蒸汽管阴影 | 45 | 瓦西里近身扑击 |
| 15 | 阴影内探照灯 100% 免疫 | 46 | 挥刀触发锁骨卡刀 QTE |
| 16 | 暴露后被点射（HP ≥ 15） | 47 | 5/6 未完成 |
| 17 | 冻雪泥区域判定 | 48 | 第 6 次拔刀成功 |
| 18 | 雪泥减速 ≈ 0.65× | 49 | PTSD 解锁 + BPM 168 |
| 19 | 投罐消耗 1 个 | 50 | `taskE` 通过 |
| 20 | 罐头 20 帧内落地 | 51 | 喝水 PTSD 闪屏 + BPM 152 |
| 21 | 落地声波引警 | 52 | 语言切 EN |
| 22 | 光锥内狂暴者被射杀 | 53 | 语言切回 ZH |
| 23 | `taskA` 借刀验证 | 54 | 视野半径 275 |
| 24 | 射击计数增加 | 55 | 破眼镜 → 视野 165 |
| 25 | 卡门 15 秒 | 56 | 日志开关 |
| 26 | 仅卡门不完成任务 B | 57 | 重置清空划痕/PTSD/任务 |
| 27 | 卡门倒计时递减 | 58 | 重置恢复日志/出生点/罐头 |
| 28 | 推饭盒 → `taskB` | 59 | 重置重新播报电传 |
| 29 | 电传记录真名 | 60 | HUD 在三种模态框下刷新不崩 |
| 30 | 仅记录真名不完成任务 C | 61 | Room A 夜潜切片仍可装配 |
| 31 | 半人处打开抉择框 | | |

---

## 五、刻意偏差（与 HTML 不完全一致之处）

1. **等比缩放而非拉伸**：HTML 的 canvas 按父容器拉伸（可能变形）；Godot 用等比缩放 + 居中，避免 16:9 外的画面变形。
2. **`taskB` 判定更严格**：卡门与推饭盒**都**完成才置位（HTML 只要求推饭盒）。
3. **QTE 无 1.5s 限时**：与 HTML gym 一致（6 连按即可）；迁移文档中的 1.5s 环形限时留给正式关卡。
4. **HUD 布局重排**：HTML 是「左侧画布 + 右侧面板」的网页布局；Godot 把清单/简报/电传/按钮放在右侧 350px 侧栏，世界等比缩放到左侧，模态框居中。
5. **音效实现方式**：HTML 用 Web Audio 实时合成；Godot 在 `Sfx._ready()` 里离线烘焙成 `AudioStreamWAV`，播放 8 声部轮转。听感近似但非逐采样一致。
6. **鼠标点击门禁**：世界区域外的点击不再触发挥刀（HTML 里点在面板上也不会，因为事件绑定在 canvas 上）。
7. **`F1` 双场景互切**：`gym.tscn ↔ main.tscn`（HTML 原型中两者是两个独立页面）。
8. **键位调整**：为给灰盒场的「破眼镜」让出 `F`，Godot 输入映射中预留的 `bandage` 从 `F` 改为 `H`（Room A 切片尚未实现绷带，无功能影响；HTML 原型仍为 `F`）。
9. **动作按钮**：HTML 底部操作栏（蹲伏/投罐/交互/挥刀/喝水）改为右侧栏 5 个按钮，支持纯鼠标游玩。

---

## 六、运行

```bash
# 灰盒测试场（新主场景）
Godot_v4.7.2-stable_win64 --path godot_project

# Room A 夜潜垂直切片（旧主场景，或游戏内按 F1）
Godot_v4.7.2-stable_win64 --path godot_project res://scenes/main.tscn

# 灰盒场 61 项 headless 测试
Godot_v4.7.2-stable_win64 --headless --path godot_project -s tests/gym_smoke.gd

# Room A 夜潜切片 20 项 headless 测试（回归）
Godot_v4.7.2-stable_win64 --headless --path godot_project -s tests/room_a_smoke.gd
```

**操作**：`WASD` 移动 · 鼠标定向 · `Ctrl` 蹲伏（蒸汽管阴影）· `Shift` 冲刺 · `G` 投掷空罐头 · `E` 交互/卡门/推饭盒 · `Space`/左键 挥刀（QTE 连按）· `Q` 喝水 · `Tab` 工作日志 · `1~5` 传送 Room A–E · `L` 中英切换 · `F` 眼镜 · `M` 音效 · `F5` 重置 · `F1` Room A 夜潜切片 · `Esc` 关闭模态框。

---

## 七、下一步（按优先级）

1. **本机首跑验收**：截图 Room A–E 各一张，替换 `godot_project/screenshots/` 并写入 README（本次改动只做了语法静态校验与 headless 测试脚本，未在本环境运行 Godot 渲染）。
2. **从 `_draw()` 灰盒迁移到节点化**：按 `docs/zh/Z年纪事_Godot4引擎迁移技术规范与架构指南.md` 的 8 层物理层，把玩家/清杀兵换成 `CharacterBody2D`，探照灯换成 `PointLight2D + LightOccluder2D`，保留 `GymSim` 作为纯逻辑参考实现做 A/B 对照。
3. **接入 `novorsk17_campaign_data.json`**：把 L01–L10 的节点/容器/文本替换掉 gym 里的硬编码常量。
4. **《双面工作日志》深化**：接入 `LogbookManager.resolve_ending()`，在 5/5 验证通过后显示五结局预演（`docs/en/...Ending_Simulator`）。
5. **存档**：`LogbookManager` 落盘（真名、卌、PTSD、母亲透析剩余夜数），支撑「据点 → 夜潜 → 结算 → 次日」的完整循环。
