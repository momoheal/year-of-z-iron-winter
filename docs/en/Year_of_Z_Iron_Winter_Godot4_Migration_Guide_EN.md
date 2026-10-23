# Year of Z: Iron Winter (v4.0) — Godot 4.x Engine Migration & Technical Architecture Guide

> **Target Engine**: Godot Engine `4.7+` (project upgraded and saved with Godot 4.7.2-stable; 2D Compatibility or Forward+ renderer)
> **Base Resolution & Scale**: `1920 × 1080` viewport, `1 World Meter = 64 Pixels` (`30m × 16.875m` visible arena per screen)
> **Camera Projection**: **2D `75°` Top-Down Oblique** — south-facing walls retain `48px–64px` prefabricated Khrushchyovka concrete panel thickness, paired with `PointLight2D` searchlights and `LightOccluder2D` steam-pipe shadow stealth.
> **Ready-to-Import Starter Project**: The `godot_project/` directory in this repository includes a pre-configured `project.godot`, Autoload singletons (`LogbookManager.gd`, `AcousticRippleBus.gd`), core gameplay GDScript controllers, a `.gdshader` vision fog shader, and bilingual JSON campaign data.

---

## 0. Current Port Status (October 2026 update)

`godot_project/` is at the **playable greybox** stage: **native art and node-based physics are not wired up yet**, but both HTML prototypes are playable (exploration loop + gym + Room A slice):

| Scene | Status | Notes |
| :--- | :--- | :--- |
| `scenes/campaign.tscn` (**main scene**) | ✅ Done | **The "one night" exploration loop**: Room 602 base (mother's dialysis bags) → 13-node city map → procedural 64×48 block (90° fog-of-war, rabid / O.S.K. / half-human AI, looting, door wedges, extraction, warmth & BPM) → four report outcomes → next-day dialysis → ending resolver. 97 headless assertions. |
| `scenes/gym.tscn` | ✅ Done | **5-in-1 Greybox Gym**: Room A searchlight *Borrowing the Knife* + slush / Room B 15 s crowbar wedge + 12 cm lunchbox / Room C paper-dead teletype + Choice A + 卌 tally / Room D Ash's tri-state olfaction + Anna 0419 / Room E cleaver + Vasily's breach + 6-press collarbone blade-jam QTE + PTSD thirst. 61 headless assertions. |
| `scenes/main.tscn` | ✅ Done | **Room A night-stalk slice**: 30×20 m grid, CPU fog-of-war hole cutting, oblique extruded walls, acoustic ripples, extraction. 20 headless assertions. |
| Native node migration (`CharacterBody2D`, `PointLight2D`, `LightOccluder2D`, `.gdshader`) | ⏳ Planned | Sections II–III below describe the target architecture. Both shipped scenes use `RefCounted` + manual collision + `_draw()` as the behavioural *reference implementation*. |
| `shaders/` | ⏳ Planned | Vision fog and CRT terminal shaders are not shipped yet (CPU-drawn equivalents are used instead). |

**Added / changed files (exploration loop)**: `scripts/CampaignData.gd`, `scripts/CampaignSim.gd`, `scripts/RaidGen.gd`, `scripts/RaidSim.gd`, `scripts/Campaign.gd`, `scripts/CampaignHUD.gd`, `scenes/campaign.tscn`, `tests/campaign_smoke.gd`; `run/main_scene` is now `res://scenes/campaign.tscn`. See `Year_of_Z_Iron_Winter_Godot_Exploration_Loop_EN.md`.

**Added / changed files (gym)**: `scripts/GymSim.gd`, `scripts/Gym.gd`, `scripts/GymHUD.gd`, `scripts/Sfx.gd`, `scenes/gym.tscn`, `tests/gym_smoke.gd`; `scripts/Main.gd` gained `F1` to return to the gym. The input map grew from 14 to 24 actions (`gym_room_1..5`, `gym_toggle_lang/glasses/mute`, `gym_reset`, `gym_switch_scene`). See `Year_of_Z_Iron_Winter_Godot_Greybox_Gym_Port_EN.md` for the mechanic-by-mechanic mapping and the deliberate deviations.

**Scene swapping**: in `campaign.tscn`, `F1` opens `gym.tscn`; in the gym, `F1` returns to the campaign and `F2` opens `main.tscn`; in Room A, `F1` returns to the gym and `F2` to the campaign. All three scenes share the `LogbookManager` and `AcousticRippleBus` autoloads, so real names, the 卌 tally and PTSD persist across scenes.

---

## I. Godot 4 Project Settings & Physics Layer Specification

### 1. Display & 2D Lighting Setup
* **Viewport**: `1920 × 1080`, Stretch Mode = `canvas_items`, Aspect = `expand`.
* **2D Shadows & Searchlights**: Enable `PointLight2D` shadows (`Shadow Filter = PCF5`) on all **O.S.K. Purge Squad** `45°` helmet searchlights and Aleksei's `90°` directional vision cone.

### 2. 2D Physics Collision Layers (`Layers 1–8`)
Configure `Project Settings -> Layer Names -> 2D Physics` exactly as the 8 layers below (matching the shipped `project.godot`) to guarantee zero hallway body-blocking with Wolfdog "Ash", accurate `12cm` under-fence interactions, and hideable-but-not-sight-blocking steam-pipe cover:

| Layer # | Layer Name | Assigned Entities | Collision & Occlusion Rules |
| :--- | :--- | :--- | :--- |
| **Layer 1** | `World_Wall_Full` | Khrushchyovka walls, Cold Storage pillars, closed steel doors | Blocks all movement; the only hard blocker for player sight and O.S.K. searchlights. |
| **Layer 2** | `Low_Cover_SteamPipe` | Overhead steam pipes, low cover crates | Blocks movement (walk around / hug it), but **never blocks sight**; a crouched player within 1.9 m of cover is hidden (`coverHides`) while the enemy line of sight passes through. |
| **Layer 3** | `Wire_Mesh_Fence_12cm` | Quarantine wire-mesh fences, *"Buran"* Carriage No. 3 vents | **Blocks movement**, but is **fully transparent to searchlights/sight** and permits `12cm` bottom-gap item delivery. |
| **Layer 4** | `Player_Aleksei` | Aleksei Morozov (collision radius `0.35m`) | Collides with Layers 1, 2, 3, 6, 7; **ignores Layer 5 (Wolfdog "Ash" never blocks narrow doorways)**. |
| **Layer 5** | `Companion_Ash` | Siberian Wolfdog "Ash" (collision radius `0.25m`) | Collides only with Layers 1, 2, 3; carries an olfactory sensor scanning Layer 6. |
| **Layer 6** | `Infected_TriState` | Febrile Rabids, Regressing Half-Humans | Carries the `TriStateIdentity` enum (`RABID_FEVER`, `REGRESSING_HALF_HUMAN`, `SAFE_CIVILIAN`). |
| **Layer 7** | `OSK_Purge_Squad` | O.S.K. Purge Soldiers | Separation collisions with Layers 1, 2, 3, 4, 6; the yellow cone + lock-and-fire logic is independent of Layer 6. |
| **Layer 8** | `Interactable_Wedge_Door` | Frozen slush pits, teletype terminals, extraction point, door wedges | `Area2D` triggers: holding `Ctrl` inside a steam-pipe shadow sets the hidden state; holding `E` triggers extraction / wedging. |

> Note: the current Room A vertical slice is a 1:1 port of the HTML architecture (single Node2D + hand-rolled collision/separation + immediate-mode `_draw()`). These layers are pre-configured for later rooms that adopt native `CharacterBody2D` / `Area2D` nodes.

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
├── project.godot                                  # Pre-configured Godot 4.7+ project file (with .uid files for .gd/.gdshader)
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
