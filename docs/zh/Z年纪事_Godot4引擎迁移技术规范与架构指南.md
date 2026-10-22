# 《Z年纪事：凛冬铁轨（Year of Z: Iron Winter v4.0）》Godot 4.x 引擎迁移技术规范与工程架构指南

> **适用引擎版本**：Godot Engine `4.7+`（工程已由 Godot 4.7.2-stable 升级并保存；Forward+ 或 Compatibility 渲染管线，推荐 2D Compatibility / Mobile 以获得最佳 2D 光影与 Shader 跨平台兼容性）
> **基准分辨率与比例尺**：`1920 × 1080` 视口，`1 逻辑米 (World Meter) = 64 Pixels`（单屏可视范围 `30m × 16.875m`）
> **相机视角**：**2D `75°` 斜俯视（Top-Down Oblique）**，墙体南立面保留 `48px~64px` 预制混凝土板立面厚度，配合 `PointLight2D` 探照灯与 `LightOccluder2D` 实现蒸汽管道阴影潜行。
> **工程脚手架位置**：仓库内 `godot_project/` 目录已预置可直接导入 Godot 4 的 `project.godot`、Autoload 全局单例、核心角色/AI GDScript 脚本、`.gdshader` 视野迷雾着色器及双语 JSON 数据表。

---

## 一、Godot 4 项目基础配置要求（`project.godot` 核心参数）

### 1. 渲染与窗口设置（Display & Rendering）
* **视口尺寸（Viewport）**：`viewport_width = 1920`, `viewport_height = 1080`
* **拉伸模式（Stretch）**：`mode = "canvas_items"`, `aspect = "expand"`（确保双面工作日志 UI 与 2D 像素/手绘混合贴图在不同分辨率下保持锐利）
* **2D 光影与阴影滤镜**：开启 `rendering/2d/sdf/oversize` 与柔和阴影滤波（`filter = 1 (PCF5)`），用于渲染内务清杀兵（ОСК）的 `45°` 高压探照灯光锥与暴风雪粒子遮挡。

### 2. 2D 物理碰撞层规划（Physics Layers 1–8）
在 Godot 4 `Project Settings -> Layer Names -> 2D Physics` 中严格按以下 8 层配置（与 `project.godot` 实际配置一致），这是实现**“灰烬不卡走廊”、“铁丝网门底 12cm 窄缝推饭盒不挡探照灯”、“蒸汽管阴影可藏人但不挡视线”**的核心保证：

| 物理层编号 | 层名称 (`Layer Name`) | 碰撞体归属 | 遮挡与交互法则 (`Collision Mask`) |
| :--- | :--- | :--- | :--- |
| **Layer 1** | `World_Wall_Full` | 赫鲁晓夫楼墙体、冷库立柱、关死的变形铁门 | 阻挡所有角色移动；100% 阻挡玩家视野与清杀队探照灯（视线判定唯一硬阻挡）。 |
| **Layer 2** | `Low_Cover_SteamPipe` | 高架供暖蒸汽管、低矮掩体箱 | 阻挡角色移动（可绕行/贴靠），但**不阻挡视线**；玩家蹲伏且距掩体 ≤1.9m 时判定为隐藏（`coverHides`），敌人视线穿过但不发现玩家。 |
| **Layer 3** | `Wire_Mesh_Fence_12cm` | 冷库铁丝网隔离门、铁壳号第三节闷罐车透气窗 | **阻挡角色移动**，但**视线/探照灯 100% 穿透**；允许底部 `12cm` 投递判定区穿过。 |
| **Layer 4** | `Player_Aleksei` | 主角阿列克谢（碰撞半径 `0.35m`） | 与 Layer 1, 2, 3, 6, 7 交互；**忽略 Layer 5（防止灰狼犬“灰烬”在 1m 宽狭窄后厨/走廊把玩家堵死）**。 |
| **Layer 5** | `Companion_Ash` | 西伯利亚灰狼犬“灰烬”（碰撞半径 `0.25m`） | 仅与 Layer 1, 2, 3 发生物理阻挡；自带嗅觉感知圈扫描 Layer 6。 |
| **Layer 6** | `Infected_TriState` | 灰鳞狂暴者、回退期半人（抉择A） | 挂载独立 `TriStateIdentity` 枚举（`RABID_FEVER`, `REGRESSING_HALF_HUMAN`, `SAFE_CIVILIAN`）。 |
| **Layer 7** | `OSK_Purge_Squad` | 内务清杀兵（ОСК） | 与 Layer 1, 2, 3, 4, 6 分离碰撞；黄锥探照 + 红外锁定开火逻辑独立于第 6 层。 |
| **Layer 8** | `Interactable_Wedge_Door` | 冻雪泥坑、电传终端、砍骨刀砧板、撤离点、撬棍卡门 | 纯 `Area2D` 触发层：检测玩家进入蒸汽管阴影并按住 `Ctrl` 时设置隐藏状态，长按 `E` 触发撤离/卡门。 |

> 注：当前 Room A 垂直切片为 1:1 HTML 架构（单 Node2D + 手动碰撞/分离 + `_draw()` 立即模式），上述物理层为后续房间接入原生 `CharacterBody2D` / `Area2D` 时保留，`project.godot` 中已全部预配。

### 3. 输入映射表（Input Map）
| Action 名称 | 绑定按键 | 对应《凛冬铁轨 v4.0》核心动作 |
| :--- | :--- | :--- |
| `move_up` / `down` / `left` / `right` | `W` / `S` / `A` / `D` | 八向移动（默认速度 `3.2 m/s = 204.8 px/s`） |
| `stance_sprint` | `Shift` (按住) | 恐慌冲刺（`5.0 m/s = 320 px/s`，产生 `7.5m = 480px` 强声波纹） |
| `stance_crouch` | `Ctrl` (切换/按住) | 蹲伏潜行（`1.6 m/s = 102.4 px/s`，在蒸汽管 `Area2D` 内获得 100% 探照灯免疫） |
| `action_throw_can` | `G` | 向鼠标准星方向投掷空沙丁鱼铁罐（落点产生 `9.0m = 576px` 声波，触发清杀队**【借刀杀人】**） |
| `action_interact_wedge` | `E` (点按/长按 1.2s) | 点按：电传机写真名、门底推饭盒、对话安娜；长按 1.2s：**道钉撬棍物理卡门 15 秒** |
| `action_melee_swing` | `Space` / `Mouse Left` | 挥击撬棍或砍骨刀；锁骨卡刀状态下为 **QTE 连按拔刀键（1.5s 内连按 6 次）** |
| `action_drink_water` | `Q` | 喝水平复心率（东街瓦西里事件后，每次喝水末尾播放 `SFX_Vasily_Thirst` *“……Пить……”* 幻听） |
| `ui_toggle_logbook` | `Tab` | 展开/收起叙事内嵌 UI《双面工作日志（Рабочий Журнал）》 |

---

## 二、Godot 4 场景树与节点架构（Scene Tree Architecture）

```text
res:// (godot_project/)
├── project.godot                                  # Godot 4.7+ 工程配置文件（含 .gd/.gdshader 对应的 .uid 文件）
├── autoload/
│   ├── LogbookManager.gd                          # [Autoload 单例] 双面工作日志、真名录、“卌”字划痕与五结局判定机
│   └── AcousticRippleBus.gd                       # [Autoload 单例] 全局声音波纹事件总线（足音/空罐头/消音AKM）
├── shaders/
│   ├── vision_fog_90deg.gdshader                  # 90°扇形视野 + 破眼镜色散折光 + 视锥外苏联旧报纸颗粒迷雾
│   └── soviet_crt_terminal.gdshader               # 区管委苏制电传终端显像管扫描线与红绿辉光 Shader
├── scripts/
│   ├── PlayerAleksei.gd                           # 主角阿列克谢 3C、蒸汽管隐匿、锁骨卡刀 QTE、PTSD 喝水幻听
│   ├── WolfdogAsh.gd                              # 灰狼犬“灰烬” 1.5m 跟随与三态嗅觉 AI（狂吠/压耳低鸣/摇尾）
│   ├── OSKPurgeSoldier.gd                         # 内务清杀兵巡逻、45°探照灯射线检测与无条件开火（借刀杀人）
│   └── DoorWedgeInteractable.gd                   # 道钉撬棍 1.2s 卡门（锁死 15s）与 12cm 门底推铝饭盒组件
└── data/
    └── novorsk17_campaign_data.json               # 5合1灰盒测试场、抉择A/B/C/D与L01~L10中英双语配置表
```

### 核心预制体节点树（Prefab Hierarchies）

#### 1. 主角阿列克谢 (`PlayerAleksei.tscn`)
* `PlayerAleksei` (`CharacterBody2D` — Script: `PlayerAleksei.gd`)
  * `CollisionShape2D` (`CircleShape2D`, `radius = 22.0`)
  * `Sprite2D_Body` (苏联铁路冬装大衣与圆框眼镜序列帧)
  * `VisionConeLight` (`PointLight2D` — 绑定 `90°` 扇形遮罩贴图 + `1.8m` 近身感知圆，启用 `shadow_enabled = true`)
  * `MeleeHitbox` (`Area2D` — 撬棍 `1.3m / 60°` 或砍骨刀 `1.0m / 45°` 扇形判定区)
  * `AudioPlayer_Footstep` & `AudioPlayer_PTSD_Thirst` (`AudioStreamPlayer2D`)

#### 2. 内务清杀兵 (`OSKPurgeSoldier.tscn`)
* `OSKPurgeSoldier` (`CharacterBody2D` — Script: `OSKPurgeSoldier.gd`)
  * `SearchlightCone` (`PointLight2D` — `45°` 黄白高对比光束，射程 `14m = 896px`，开启 `shadow_enabled = true`)
  * `SearchlightRayCast` (`RayCast2D` — 实时检测光锥内目标是否被 `LightOccluder2D` 或蒸汽管阴影遮挡)
  * `SuppressedAKM_Muzzle` (`Marker2D` — 发现狂暴感染者或暴露的夜潜者时，0.5s 后发射三连发消音射线)

---

## 三、核心特种机制在 Godot 4 中的实现要点

1. **【借刀杀人（Borrowing the Knife）】声波诱敌闭环**：
   * 当阿列克谢按 `G` 投掷空沙丁鱼罐头落地时，调用 `AcousticRippleBus.emit_sound(drop_pos, 576.0, "TIN_CAN_LURE")`。
   * 半径内的 `OSKPurgeSoldier` 接收到信号后，状态机切入 `ALERT_INVESTIGATE`，将 `SearchlightCone` 转向罐头落点。
   * 一旦光锥扫中附近的 `RABID_FEVER`（灰鳞狂暴者），清杀兵触发**无条件开火法则**，用消音 AKM 替玩家射杀狂暴者，玩家全程蹲在蒸汽管阴影 (`is_hidden_in_pipe_shadow = true`) 中毫发无伤。
2. **【东街食堂：锁骨卡刀 6连按 QTE 与瞳孔回色】**：
   * 当 `PlayerAleksei` 装备 `CLEAVER` 正面命中狂暴态瓦西里时，不直接扣血致死，而是将双方锁入 `STATE_BLADE_JAMMED`（时间缩放 `Engine.time_scale = 0.85`）。
   * UI 弹出 1.5 秒环形进度条，监听 `action_melee_swing` 连按 `6 次`。
   * 第 6 次达成拔刀瞬间：瓦西里面部 `Sprite2D` 的 Shader 参数 `fever_haze_alpha` 从 `1.0` 平滑插值至 `0.0`（露出清澈的蓝眼睛），播放语音气泡 *“……Пить（渴）……”*，并将 `LogbookManager.ptsd_thirst_unlocked` 置为 `true`。
3. **【《双面工作日志》俄式“卌”字划痕与五结局状态机】**：
   * `LogbookManager.gd` 维护 `tally_strokes: int`（0~5）。
   * 每次划痕增加时，UI 上对应的 `Line2D`（第1~4笔为竖线 `|`，第5笔为贯穿斜杠 `/`）播放钢笔划破纸张的 Tween 动画与 `SFX_Tally_Scratch`。
   * 终章 L10 广播结束后，直接调用 `LogbookManager.evaluate_final_ending()` 返回五结局枚举（`ENDING_A_COMPLIANCE`, `ENDING_B_FLAWED_LIBERATION`, `ENDING_C_NUMBNESS`, `TRUE_ALPHA_HELLO_LANA`, `TRUE_BETA_OUTLAND_FIRE`）。
