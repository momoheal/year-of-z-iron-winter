# Year of Z: Iron Winter — Godot 4 Greybox Gym (5-in-1) Port Report

> **Source prototype**: `prototypes/Year_of_Z_Iron_Winter_Playable_Greybox_Gym.html` (1100 × 680 logical arena, Rooms A–E)
> **Godot project**: `godot_project/` (Godot 4.7.2-stable, Forward+ or Compatibility)
> **Zero external art / audio assets**: everything is drawn immediately in `_draw()`; SFX are baked `AudioStreamWAV`s generated at startup (the Godot equivalent of the HTML Web Audio synthesis).
> **Entry scene**: `res://scenes/gym.tscn` (`application/run/main_scene`). The Room A night-stalk vertical slice remains at `res://scenes/main.tscn`; press `F1` to swap between them.

---

## 1. Why port the gym first

The HTML repo validates two layers:

1. `Playable_Greybox_Gym.html` — **mechanics**: five signature loops (borrowed knife / door wedge + lunchbox / Choice A & the 卌 tally / tri-state wolfdog / collarbone blade jam QTE) in a single walkable arena with a checklist.
2. `Exploration_Demo.html` — **the loop**: base → map selection → night infiltration → scavenging → extraction → report → next day.

The repository previously only had a partial Room A loop in Godot. This update ports **(1)** in full and keeps **(2)** as a second scene, giving the project a “mechanics gym ↔ night-stalk slice” structure — the last greybox foundation before real art, `CharacterBody2D` and `PointLight2D` are introduced.

---

## 2. Files

| File | Responsibility | HTML counterpart |
| :--- | :--- | :--- |
| `scenes/gym.tscn` | Single `Node2D` scene (new main scene) | the whole gym page |
| `scripts/GymSim.gd` | Pure logic: 5 rooms, player/dog/soldier/rabids, tin can, door wedge, lunchbox, teletype, Choice A, tri-state olfaction, QTE, PTSD, 卌 tally, checklist, feed | `game` state + `updateGame()` + `actionThrowCan/actionInteract/actionSwingWeapon/advanceBladeJamQte/actionDrinkWater` |
| `scripts/Gym.gd` | Input, letterboxed viewport transform, immediate-mode `_draw()` | `renderGame()` + input listeners |
| `scripts/GymHUD.gd` | CanvasLayer HUD: top bar / sidebar / checklist / brief / feed + Logbook, Choice A and QTE modals | header, right panels, `logbookModal`, `choiceAModal`, `qteOverlay` |
| `scripts/Sfx.gd` | Six procedural SFX (beep / can / wedge / akm / bonejam / thirst) baked into `AudioStreamWAV` | `playSfx()` + Web Audio |
| `tests/gym_smoke.gd` | 61 headless assertions | new |
| `scripts/Main.gd` | Room A slice (unchanged except `F1` → gym) | `Exploration_Demo.html` |
| `scripts/Sim.gd` / `HUD.gd` | Room A logic / HUD (untouched) | same |

---

## 3. Mechanic-by-mechanic mapping

### World and camera
`WORLD_W/H = 1100/680` and all five `ROOM_ZONES` / `ROOM_SPAWNS` are copied value-for-value. Rendering is uniformly scaled (not stretched) into `VIEW_AREA = (10,74,1540,992)`, with a 350 px HUD sidebar on the right. `1~5` teleports between rooms (the HTML had header buttons).

### Room A — searchlight “Borrowing the Knife”, slush, steam pipe
* `SLUSH_RECT`, `STEAM_PIPE_RECT` identical; the pipe uses the HTML’s *detection* pad (−18/−28/+18/+38) and its narrower *drawn* shadow rect (−10/−12/+20/+34).
* Walk/crouch/sprint `2.6 / 1.4 / 4.3` px per 60 fps frame, slush ×0.65 — the sim normalizes with `f = dt*60`.
* O.S.K. patrol `165–380`, `0.85 px/frame`, aiming `π/2 ± 0.25`; searchlight `±0.39 rad`, 245 px; fire thresholds `<260` rabid / `<215` player with `0.48 / 0.38` angle tests; 35 / 50 frame cooldowns; player damage `max(15, hp-12)`.
* Tin can: `0.06` progress per frame, 145 px landing ripple, alerts the soldier within 380 px.
* Footstep ripples 18/48/115, ×1.85 in slush; bootprints last 240 frames.

### Room B — crowbar wedge and the 12 cm gap
* `<65 px` + `E` → `wedge_frames = 900` (15 s), with countdown HUD; `<70 px` + `E` → lunchbox delivered + verified name.
* **Deliberate fix**: Task B now requires *both* the wedge and the delivery (HTML completed it on delivery alone).

### Room C — the paper dead, Choice A, the 卌 tally
* Teletype records Sergey & Maria (also forwarded to the `LogbookManager` autoload).
* Half-human state machine `unresolved / saved_A1 / killed_A3`; A2 steps back; A3 adds 2 tally strokes (capped at 5) and 2 tins.
* Task C requires the recorded names *and* a resolved Choice A.

### Room D — Ash’s tri-state nose and Anna (0419)
* Dog trails 28 px behind the player’s facing at `0.09`/frame.
* Bark <130 rabid / <95 Cage I / <150 charging Vasily; whimper <115 half-human / <95 Cage II; tail wag <95 Cage III / <95 teletype.
* `<80 px` + `E` at Cage II → Anna’s testimony, Task D.

### Room E — cleaver, breach, collarbone jam, PTSD
* `<70 px` + `E` equips the cleaver; with it equipped, `<155 px` triggers Vasily’s breach (1.35 px/frame charge; auto-swing at <34).
* A hit enters `jammed` + QTE; six presses free the blade (`resolved`, PTSD unlocked, BPM 168, verified name, Task E).
* `Q` after PTSD: 90-frame crimson flash, BPM 152; otherwise BPM `max(72, bpm-15)`.
* **Deviation**: no 1.5 s timer — identical to the HTML gym (the migration guide’s 1.5 s ring is reserved for production levels).

### Global systems
`L` / sidebar toggles EN↔ZH, `F` cracks the glasses (vision 275 → 165 px, red lens overlay), `M` mutes, `Tab` opens the dual-sided Logbook (real names + 卌 strokes + tally description), `F5` resets (keeping language and glasses), `F1` swaps to the Room A slice. The sidebar shows vitals, the 5-item checklist, the current room brief, the last three teletype entries and the action buttons. A 5/5 banner appears in-world when all tasks pass.

---

## 4. Headless test suite (61 assertions)

```bash
Godot_v4.7.2-stable_win64 --headless --path godot_project -s tests/gym_smoke.gd
# prints GYM_SMOKE_PASS on success; each failure is reported with its id and exits 1
```

Coverage: project/scene assembly, HUD binding, spawn state, all five room zones and teleports, crouch/pipe-shadow immunity vs. exposure fire, slush speed ratio, tin-can landing and luring, borrowed-knife kill, wedge timing, lunchbox delivery, teletype + Choice A (A1/A2/A3), tally clamping, Ash’s three states, Anna, cleaver pickup, Vasily’s breach, 6-press QTE resolution, PTSD drink, language/glasses/logbook toggles, reset, HUD refresh under every modal, and a Room A slice regression check.

---

## 5. Deliberate deviations

1. Uniform scaling + letterboxing instead of a stretch-to-fit canvas.
2. Stricter Task B (wedge **and** delivery).
3. No 1.5 s QTE time limit (matches the HTML gym).
4. HUD re-laid-out as a web-style “canvas + right panel” becomes a game-style “viewport + sidebar”.
5. SFX are pre-baked WAVs rather than live Web Audio synthesis (approximate, not sample-identical).
6. Clicks outside the world area never swing the cleaver.
7. Two scenes with `F1` instead of two separate HTML pages.
8. Key remap: the reserved `bandage` action moved from `F` to `H` so the gym can use `F` for cracked glasses (bandage is not implemented in the Room A slice, so there is no functional impact; the HTML prototype keeps `F`).
9. The HTML bottom action bar (crouch / throw / interact / swing / drink) becomes five sidebar buttons, so the gym is fully mouse-playable.

---

## 6. Run

```bash
Godot_v4.7.2-stable_win64 --path godot_project                       # greybox gym
Godot_v4.7.2-stable_win64 --path godot_project res://scenes/main.tscn # Room A slice
Godot_v4.7.2-stable_win64 --headless --path godot_project -s tests/gym_smoke.gd
Godot_v4.7.2-stable_win64 --headless --path godot_project -s tests/room_a_smoke.gd
```

**Controls**: `WASD` move · mouse aim · `Ctrl` crouch · `Shift` sprint · `G` tin can · `E` interact/wedge/push · `Space`/LMB swing (QTE mash) · `Q` drink · `Tab` Logbook · `1–5` rooms · `L` language · `F` glasses · `M` mute · `F5` reset · `F1` Room A slice · `Esc` close modals.

---

## 7. Next steps

1. **First local run + screenshots**: capture Rooms A–E, drop them into `godot_project/screenshots/`, and link them from the README. This change was statically syntax-checked (gdtoolkit) and ships a headless suite, but Godot itself was not available in the authoring environment — no new screenshots are claimed.
2. **Node-ify the greybox**: migrate player/soldier to `CharacterBody2D` across the 8 physics layers, and the searchlight to `PointLight2D + LightOccluder2D`, keeping `GymSim` as the reference implementation for A/B parity tests.
3. **Feed `novorsk17_campaign_data.json`** (L01–L10) into the gym to replace hard-coded constants.
4. **Deepen the Logbook**: hook `LogbookManager.resolve_ending()` to preview the five endings after 5/5.
5. **Persistence**: save real names, tally, PTSD and the mother’s dialysis countdown to disk to support the full base → night → report → next-day loop.
