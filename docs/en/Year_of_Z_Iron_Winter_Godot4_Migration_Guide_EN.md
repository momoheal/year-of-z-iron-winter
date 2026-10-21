# Year of Z: Iron Winter (v4.0) — Godot 4.x Engine Migration & Technical Architecture Guide

> **Target Engine**: Godot Engine `4.3+` (2D Compatibility or Forward+ renderer)
> **Base Resolution & Scale**: `1920 × 1080` viewport, `1 World Meter = 64 Pixels` (`30m × 16.875m` visible arena per screen)
> **Camera Projection**: **2D `75°` Top-Down Oblique** — south-facing walls retain `48px–64px` prefabricated Khrushchyovka concrete panel thickness, paired with `PointLight2D` searchlights and `LightOccluder2D` steam-pipe shadow stealth.
> **Ready-to-Import Starter Project**: The `godot_project/` directory in this repository includes a pre-configured `project.godot`, Autoload singletons (`LogbookManager.gd`, `AcousticRippleBus.gd`), core gameplay GDScript controllers, a `.gdshader` vision fog shader, and bilingual JSON campaign data.

---

## I. Godot 4 Project Settings & Physics Layer Specification

### 1. Display & 2D Lighting Setup
* **Viewport**: `1920 × 1080`, Stretch Mode = `canvas_items`, Aspect = `expand`.
* **2D Shadows & Searchlights**: Enable `PointLight2D` shadows (`Shadow Filter = PCF5`) on all **O.S.K. Purge Squad** `45°` helmet searchlights and Aleksei's `90°` directional vision cone.

### 2. 2D Physics Collision Layers (`Layers 1–6`)
Configure `Project Settings -> Layer Names -> 2D Physics` exactly as follows to guarantee zero hallway body-blocking with Wolfdog "Ash" and accurate `12cm` under-fence interactions:

| Layer # | Layer Name | Assigned Entities | Collision & Occlusion Rules |
| :--- | :--- | :--- | :--- |
| **Layer 1** | `World_SolidWall` | Khrushchyovka walls, Cold Storage pillars, closed steel doors | Blocks all movement; carries `LightOccluder2D` to block both player sight and O.S.K. searchlights. |
| **Layer 2** | `World_WireFence_12cmGap` | Quarantine wire-mesh fences, *"Buran"* Carriage No. 3 vents | **Blocks movement (Layers 3, 4)**, but carries **NO `LightOccluder2D`** (transparent to searchlights/sight) and permits `12cm` bottom-gap item delivery. |
| **Layer 3** | `Player_Aleksei` | Aleksei Morozov (`CharacterBody2D`, radius `22px / 0.35m`) | Collides with Layers 1, 2, 5, 6; **ignores Layer 4 (Wolfdog "Ash" never blocks narrow doorways)**. |
| **Layer 4** | `Companion_WolfdogAsh` | Siberian Wolfdog "Ash" (`CharacterBody2D`, radius `16px / 0.25m`) | Collides only with Layers 1, 2; carries a `220px` `Area2D` olfactory sensor scanning Layer 5. |
| **Layer 5** | `NPC_And_Infected` | Febrile Rabids, Regressing Half-Humans, O.S.K. Soldiers, Civilians | Carries `TriStateIdentity` enum (`RABID_FEVER`, `REGRESSING_HALF_HUMAN`, `SAFE_CIVILIAN`, `OSK_SOLDIER`). |
| **Layer 6** | `Interactable_And_Cover` | Overhead steam-pipe shadows, frozen slush pits, teletype terminals | `Area2D` triggers: holding `Ctrl` inside a steam-pipe shadow sets `player.is_hidden_in_pipe_shadow = true`. |

### 3. Input Map (`project.godot`)
| Action Name | Default Key | v4.0 Mechanic |
| :--- | :--- | :--- |
| `move_up` / `down` / `left` / `right` | `W` / `S` / `A` / `D` | 8-way movement (`3.2 m/s = 204.8 px/s` normal walk) |
| `stance_sprint` | `Shift` (Hold) | Panic Sprint (`5.0 m/s = 320 px/s`, emits `7.5m = 480px` acoustic ripple) |
| `stance_crouch` | `Ctrl` (Toggle/Hold) | Crouch Stealth (`1.6 m/s = 102.4 px/s`; 100% searchlight immunity inside steam-pipe shadow) |
| `action_throw_can` | `G` | Throw empty sardine tin (`9.0m = 576px` impact clang — lures O.S.K. patrols to shoot rabids) |
| `action_interact_wedge` | `E` (Tap / Hold 1.2s) | Tap: record real name / push lunchbox / talk; Hold 1.2s: **Wedge door shut for 15.0s with crowbar** |
| `action_melee_swing` | `Space` / `LMB` | Swing crowbar or butcher cleaver; rapid-press `6x` within `1.5s` during **Collarbone Blade Jam QTE** |
| `action_drink_water` | `Q` | Drink water to lower BPM (triggers **PTSD Thirst Tinnitus** *"…Пить…"* after Room E / Chapter 7) |
| `ui_toggle_logbook` | `Tab` | Open/close Diegetic Dual-Sided Work Logbook (`Рабочий Журнал`) |

---

## II. Godot 4 Repository Directory & Script Architecture

```text
res:// (godot_project/)
├── project.godot                                  # Pre-configured Godot 4.3+ project file
├── autoload/
│   ├── LogbookManager.gd                          # [Autoload] Dual Logbook, Real Names, '卌' Tally & 5-Ending Evaluator
│   └── AcousticRippleBus.gd                       # [Autoload] Global acoustic wave bus for footsteps, tin cans & gunfire
├── shaders/
│   ├── vision_fog_90deg.gdshader                  # 90° vision cone + cracked-lens aberration + Soviet newsprint fog
│   └── soviet_crt_terminal.gdshader               # Green/Red CRT scanline & phosphor bloom shader
├── scripts/
│   ├── PlayerAleksei.gd                           # 3C controller, pipe stealth, Collarbone Jam QTE & PTSD Thirst
│   ├── WolfdogAsh.gd                              # 1.5m follow steering & Tri-State Olfactory AI (Bark/Whimper/Wag)
│   ├── OSKPurgeSoldier.gd                         # Patrol, 45° searchlight raycast & unconditional fire ('Borrowing Knife')
│   └── DoorWedgeInteractable.gd                   # 1.2s hold-E Crowbar Door Wedge (15s lock) & 12cm under-fence push
└── data/
    └── novorsk17_campaign_data.json               # Bilingual ZH/EN data for Greybox Rooms A–E & Campaign Levels L01–L10
```
