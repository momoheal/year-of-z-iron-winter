# Year of Z: Iron Winter — Godot 4 Exploration-Loop Port Report

> **Target prototype**: `prototypes/Year_of_Z_Iron_Winter_Exploration_Demo.html` (~2,600 lines, a complete zero-art loop greybox)
> **Godot project**: `godot_project/` (Godot 4.7.2-stable; Forward+ or Compatibility)
> **Entry scene**: `res://scenes/campaign.tscn` (`run/main_scene`)
> **Tests**: `tests/campaign_smoke.gd` — 97 headless assertions, prints `CAMPAIGN_SMOKE_PASS`
> **Previous milestone**: the 5-in-1 greybox gym (`scenes/gym.tscn`, see `Year_of_Z_Iron_Winter_Godot_Greybox_Gym_Port_EN.md`)

---

## 1. What this milestone adds: the loop, not another room

The greybox gym proves that **individual mechanics** are playable (borrowed knife, door wedge + lunchbox, Choice A and the 卌 tally, tri-state dog smell, collarbone blade-jam QTE).
The Exploration Demo proves that **a whole night** is playable:

```
Title → Room 602 (base) → city map → night raid (procedural block + looting + encounters)
      → extracted / dawn / downed / abort → report → next day (mother's dialysis) → back to base
```

This port carries that loop into Godot while keeping:

* **Same numbers** — every constant comes from the prototype's `CFG` / `ITEMS` / `WEAPONS` / `MATES` / `LOCS` / `STORY`;
* **Same state** — strokes, real names, conscience, dialysis bags, weapon collection, 13 map nodes with container residue all live in one `CampaignSim`;
* **Same look** — immediate-mode `_draw()`, 26 px per metre, y-squashed 0.62 for a 75° oblique view, zero art assets;
* **Same cross-scene logbook** — the `LogbookManager` autoload keeps syncing names and strokes into the gym and Room A slices.

---

## 2. Files and responsibilities

| File | Responsibility | Prototype counterpart |
| :--- | :--- | :--- |
| `scenes/campaign.tscn` | Single `Node2D` scene (**new main scene**) | the whole demo page |
| `scripts/CampaignData.gd` | Static tables: 24 items, 5 weapons, 5 companions, 13 locations, 7 story beats, bilingual strings, tile/feel constants | `CFG` / `ITEMS` / `WEAPONS` / `MATES` / `LOCS` / `STORY` / `TEXT` |
| `scripts/CampaignSim.gd` | Campaign state machine (`title / base / map / raid / report / ending`): stash, conscience, tally, names, flags, mates, node residue, loadout, story `ops`, report, next-day dialysis, ending resolution, LogbookManager sync | `G` + `depart / endScene / advanceDay / openStory / resolveStory / objectiveText / endingKey` |
| `scripts/RaidGen.gd` | Static procedural generator: streets → sectors → enterable buildings → solid blocks → clean room anchors → slush/cover/fence/doors → containers → fires → connectivity repair → boundary ring; plus `gen_loot()` and tile helpers | `genMap / ensureConnected / genLoot / CAT / byType` |
| `scripts/RaidSim.gd` | One night of pure logic: movement/collision, noise ripples, 90° vision + explored mask, rabid/O.S.K./half-human/companion AI, searching, wedging, prying, extraction, warmth/BPM/HP, dawn/downed, Choice A, pack, events | `startScene / update / finishSearch / coverHides / endScene` |
| `scripts/Campaign.gd` | Rendering + input: city map (13 nodes), the raid world (ground, facades, containers, fires, entities, fog, cone, ripples, floats), base and report backdrops | `drawCityMap / drawScene / drawFog / drawCones / drawRipples` |
| `scripts/CampaignHUD.gd` | CanvasLayer UI: top bar, three-column base, map node card, raid HUD, report, ending, and five modals (story / Choice A / logbook / help / abort) | `renderBase / renderMap / renderReport / openChoiceA / openNpcTalk` |
| `scripts/Gym.gd` | Changed: `F1` now returns to the campaign loop; `F2` goes to Room A | — |
| `scripts/Main.gd` | Changed: new `F2` returns to the campaign loop (`F1` still returns to the gym) | — |
| `tests/campaign_smoke.gd` | 97 headless assertions | new |

---

## 3. Constants that must match the prototype

| Item | Value | Notes |
| :--- | :--- | :--- |
| Map | `64 × 48` tiles | 1 tile = 1 logical metre |
| Projection | `PPM 26.0`, `SQUASH 0.62`, `WALL_H 0.62` | 75° oblique approximation |
| Vision | `FOV 90°`, `SIGHT 12.0`, `SIGHT_CRACKED 7.2`, `NEAR_SENSE 1.8` | near-sense ignores walls |
| Speeds | walk 3.2 / sneak 1.6 / sprint 5.0 m·s⁻¹ | slush ×0.65 |
| Noise radii | walk 2.5 / sneak 0.8 / sprint 7.5 / search 3.2 / tin 9.0 / gunshot 25.0 | slush ×2 |
| Pack | 12 slots (Anna +4) | overflow stays on the floor |
| Night length | `max(90, travel_minutes × 2.4)` s | 22:00 → 04:00 |
| Containers | `round((8 + danger×3) × (0.85 + rnd×0.4) × residue)` | residue −50% per visit |
| Search | 1.7 s hold | one 3.2 m noise pulse every 0.7 s |
| Wedge | 1.2 s hold → impassable for 15 s | crowbar only |
| Pry | 0.8 s (Pavel 0.4 s) | welded building doors |
| Extract | 1.5 s hold | within 1.6 m of the entry |
| Cleaver jam | 100% on a frontal rabid hit; 6 presses in 1.5 s | timeout −22 HP |
| Dawn penalty | keep even indices only, `HP = max(6, HP − 22)` | downed/abort: lose everything |
| Mother | 1 bag per day; dead after 2 days without | `dial ≤ 0` triggers |

---

## 4. Mechanic-by-mechanic

### 4.1 City map and the 13 nodes

* The prototype's `900 × 520` plane is drawn 1:1 inside `MAP_RECT`; clicks pick the nearest node within 62 px.
* Unlock chain: `req_flag` (`manor_tip` / `lana_car3`) → `req` (`intel ≥ 2` + `med ≥ 1`) → free.
  **10 of 13** nodes are open at the start; the sanatorium, Pine Manor and the West Station yard are gated.
* Each node stores `visits` and `left`: one visit sets `left = clamp(left − 0.5, 0.05, 1.0)`, so the second night there has half the crates.

### 4.2 Procedural block (`RaidGen.generate`)

Same order as the prototype, and the **same seed yields the same block** (`seed = location seed + day × 7`):

1. main streets (4–5 m wide, one horizontal and one vertical) plus 1–2 branches, spaced ≥ 4;
2. sectors between street bands (≥ 4×4), each paved to floor;
3. up to 3 **enterable buildings** per sector — the door sits on a street-facing tile, 40 attempts, otherwise walls are reverted and sector connectivity is re-checked;
4. 1–2 solid blocks (same revert + connectivity check);
5. a spiral search for a clean centre tile = room anchor, plus one mech feature (storage / freezer / dark / kitchen / clinic / patrol / workshop / none);
6. slush blobs (radius 1–2, 62%), cover runs, fence runs, 1-wide doorways (30%);
7. containers (count from danger × residue; buildings favour freezers/crates, streets favour supply crates/dumpsters);
8. fires: 2 for `cold > 1.0`, otherwise 1, plus one extra in a kitchen;
9. `ensure_connected()` floods from the entry and carves isolated floor pockets back in (building interiors protected);
10. boundary ring in 6–13 tile segments, 55% building / 45% fence.

The smoke test pins this behaviour: identical grids for the same seed, different grids across days, every container reachable, > 400 reachable floor tiles.

### 4.3 Vision, fog and cone

* Per-tile visibility: distance ≤ 12 m (7.2 m with a cracked lens), unconditional within 1.8 m, otherwise 90° cone + `los_clear` (walls, welded doors and wedged doors block).
* Three draw states: **unexplored** (black) → **explored but out of sight** (55% dark) → **visible** (full colour plus a soft vision polygon).
* The polygon casts 55 rays at 0.35 m steps and stops on `blocks_sight` (wall / wedged / cover / welded door).

### 4.4 Movement, noise and the borrowed knife

* Manual collision: six sample points against `blocks_move` (wall / cover / fence / wedged / welded door).
* Travel distance accumulates a noise ripple every 0.9 m (sneaking) or 1.4 m (walking/sprinting); slush doubles the radius.
* O.S.K. soldiers hearing a radius ≥ 2 noise within 16 m switch to `investigate` and walk to the source.
* 22.5° half-cone and 14 m range raise `suspect`; `lock` fires after 1 s (hit chance `1 − d/14`, floor 25%, ×0.75, 18 damage).
* **Borrowed knife**: another rabid / half-human in the cone is shot 0.5 s later — a dead rabid counts as your kill, a dead half-human costs 3 conscience and writes a `witness` event.

### 4.5 Warmth, heart rate and health

* Warmth drain = `loc cold × 0.55`; slush ×1.5, sneaking ×0.85, freezer room ×1.6; within 2.6 m of a fire +30/s.
* Below 25 warmth you bleed HP by the shortfall; below 30 you get one warning; above 45 it re-arms.
* Target BPM = `70 + sprint 34 + low HP 22 + fear 26 + cold 12`, smoothed with `lerp(…, 1 − 0.02^dt)` — the prototype's exact formula.
* The clinic room gives a one-time +25 HP.

### 4.6 Looting

* 1.7 s hold, then: container marked, `looted +1`, items enter the pack one by one (full pack = "left behind" toast).
* `gen_loot`: safe 3 / hidden 2 / corpse 2 / else 1, plus 42% for +1; 62% container-type pool, otherwise the location pool;
  `part|weapon` degrades to scrap 62% of the time; `med` gives a bandage 55% of the time (see deviations); hidden stashes add dialysis fluid 50% of the time.
* Gulya: medicine cabinets and freezers roll ×1.5 items.

### 4.7 Wedge, pry and extraction

* Crowbar on `TT_DOOR`: 1.2 s hold → `TT_WEDGED` with a 15 s timer, which springs back to `TT_DOOR` when it expires.
* Welded `TT_BDOOR`: 0.8 s hold (Pavel 0.4 s) → `TT_DOOR`.
* Standing within 1.6 m of the entry and holding E for 1.5 s extracts (extraction outranks any container or door on the same tile).

### 4.8 Four endings of a night

| Outcome | Trigger | Haul | Extra |
| :--- | :--- | :--- | :--- |
| `extracted` | extraction bar full | everything | — |
| `dawn` | night timer hits zero | even indices only (0, 2, 4…) | `HP = max(6, HP − 22)` |
| `downed` | HP ≤ 0 (Gulya can save you once) | nothing | — |
| `abort` | Esc → confirm | nothing | — |

The report screen mirrors the prototype field by field: haul, `looted/total`, kills, half-humans helped, `HP/warmth`, event stream, weapon-rack unlocks, back-page strokes, conscience and name count, and the mother's remaining fluid.

### 4.9 Next day

`advance_day()`: day +1 → if the stash holds `dial`, consume one bag and top `dial` up to 3; otherwise `dial −1`, and at `dial ≤ 0` the mother dies (`mother_lost = true`, conscience −10).

### 4.10 Story beats and Choice A

* Seven beats (coldstore / yard / canteen / sanatorium / market / marshalling / pre-ending) driven by `ops`:
  `["add", id, n]`, `["take", id, n]`, `["conscience", d]`, `["tally", n]`, `["flag", id]`, `["mate", id]`, `["name", str]`, plus `after_mate` (coldstore → Ash, canteen → Pavel, market C3 → Ivan).
* Each beat fires only the first time you enter its location (`story_done` guard, no replays).
* **Choice A** (a half-human in the snow): A1 feed aspirin + hot water (conscience +7, one saved, yields the signal); A2 walk away (conscience −2, shots behind you); A3 crowbar (tally +1, conscience −10, `betrayed`).

### 4.11 Objectives and endings

`objective()` walks `names` → `lana_car3` → `endgame_known` → Pine Manor.
`ending_key()` resolves TRUE α (mother alive + zero strokes + truth + no betrayal) / TRUE β (truth in hand) / ENDING B (strokes > 0) / ENDING C (no truth).

---

## 5. Deliberate deviations (six, all corrections)

| # | Prototype | Godot | Why |
| :--- | :--- | :--- | :--- |
| 1 | `genLoot` sets `cat='band'`, which has no pool, so it degrades to scrap | yields a bandage directly | clearly a typo; the medical pool should give medicine |
| 2 | story beats have no replay guard; calling `resolveStory` twice double-applies | `story_done` short-circuits | prevents UI misclicks from double-granting conscience/names |
| 3 | a half-human killed in the cone only costs conscience | also writes a `witness` event | leaves a trace in the report stream |
| 4 | the blade-jam QTE has no failure outcome | timeout costs 22 HP + a float | the prototype's own comment specifies the consequence |
| 5 | Choice A1 with no medicine re-opens forever | one denial, then `choice_denied` until you carry the meds | stops hold-E from re-triggering constantly |
| 6 | companion abilities exist only as copy | Ash barks within 7 m (3.0 noise), Gulya revives once, Anna +4 slots, Pavel halves pry time, Ivan marks hidden stashes | the `MATES` copy becomes actual rules |

> Everything else — thresholds, radii, durations, damage, probabilities — is line-for-line aligned and pinned by 97 assertions.

---

## 6. Test suite (`tests/campaign_smoke.gd`, 97 assertions)

| Group | # | Coverage |
| :--- | ---: | :--- |
| Assembly | 1–4 | main scene is `campaign.tscn`, scene loads, sim + hud bound, title screen |
| Data tables | 5–12 | 64×48, 26 px / 0.62, pack & sight, 24 items, 5/5/13, story count, weapon damage, location stats |
| Fresh game | 13–17 | day 1, conscience 50, stash, node table, 10/13 unlocked |
| Unlock gates | 18–23 | sanatorium / manor / marshalling |
| Party & loadout | 24–27 | locked companion, clamping, empty stash |
| Depart | 28–32 | enters raid, stash deducted, container count, night formula, pack 12 |
| Generator | 33–36 | reproducible, day-dependent, containers reachable, connected district |
| Movement & looting | 37–42 | WASD displacement, loot yield, hard pack cap |
| Wedge / pry | 43–46 | wedge, 15 s timer, spring-back, pry |
| Extraction & report | 47–55 | extract, reason, stash credit, loadout return, node visits/left |
| Dawn | 56–57 | even indices kept, −22 HP |
| Downed / abort | 58–60 | nothing comes home |
| Next day | 61–66 | dialysis refill, consumption, shortage, death, flag, conscience |
| Story beats | 67–73 | modal closes, real name, +8 conscience, `after_mate`, done flag, objective advance, no replay |
| Endings | 74–80 | C / β / B / α and preview |
| Weapons & loot | 81–86 | cleaver assembly, best weapon, 1–4 items, valid ids, safes ≥ 3 |
| HUD | 87–96 | base / map / title / ending / logbook / help / story / raid / abort |
| Regression | 97 | the greybox gym still assembles |

Run:

```bash
Godot_v4.7.2-stable_win64 --headless --path godot_project -s tests/campaign_smoke.gd
# expect: CAMPAIGN_SMOKE_PASS
```

---

## 7. Controls

| Key | Action |
| :--- | :--- |
| `WASD` | move (raid) |
| mouse | aim; click a node on the map |
| `Ctrl` / `Shift` | sneak / sprint |
| `Space` / LMB | attack (mash 6× when the cleaver jams) |
| hold `E` | search / wedge / pry / extract / trigger Choice A |
| `Q` / `H` / `G` / `R` | hot water (+22 warmth) / bandage (+26 HP) / throw tin / reload |
| `Tab` | the two-sided logbook |
| `L` | switch language (outside a raid) |
| `Enter` | start / sleep from the report / base → map |
| `Esc` | cancel a modal / abort confirmation |
| `F1` | jump to the 5-in-1 greybox gym |

Inside the gym, `F1` now returns to the campaign loop and `F2` goes to Room A; inside Room A, `F1` returns to the gym and `F2` to the campaign.

---

## 8. Verification status

* ✅ All 12 GDScript files parse under `gdtoolkit` (`gdcheck`); `gdlint` reports only line-length/naming style, same as the existing code.
* ✅ Static cross-audit: every `sim.*`, `R.*`, `Data.*` and `Gen.*` access in `Campaign`, `CampaignHUD` and the test resolves to a declared member.
* ⚠️ **Not yet run on a machine with Godot** — the sandbox could not fetch the engine binary. For first acceptance run the headless commands above; `campaign_smoke`, `gym_smoke` and `room_a_smoke` should print `CAMPAIGN_SMOKE_PASS`, `GYM_SMOKE_PASS` and `ROOM_A_SMOKE_PASS`.
* ⚠️ Feel parameters (camera damping 0.0015, 55 vision rays, HUD column widths) follow the prototype but deserve one pass of eyeballing on a real build.
