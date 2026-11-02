# Year of Z · Iron Winter — Three Zones & the Black Market

> 2026-11 · All three night maps (L03 freight yard / L04 sorting park / L05 manor) are now cut into
> **three zones**. One line: **the farther from the white zone, the more infected, the better the loot,
> and the fewer rules.**

---

## 1. The three zones

| Zone | Where | Infected | Loot | ОСК patrols | For the player |
|---|---|---|---|---|---|
| **WHITE** | housing-block yard / depot apron / manor loading apron | 0 | normal | never enter | residential — safe to stop and search |
| **RED** | the ring outside, up to the wire / running lines | ≤ 3 | normal | main patrol area | **white-zone residents are forbidden here** |
| **BLACK** | south of the wire: yard, boxcar sidings, pine belt | 7–8 | **+1 item per container** | only at the edges | black market and survivors live here |

Boundaries in metres (y grows south):

| Level | WHITE | RED | BLACK | Spawn lands in |
|---|---|---|---|---|
| L03 Freight Yard `night_explore.tscn` | 0 ~ 12 | 12 ~ 21.5 (wire) | 21.5 ~ 40 | WHITE (boiler-vent gate) |
| L04 Sorting Park `night_marshalling.tscn` | 0 ~ 9 | 9 ~ 20 | 20 ~ 36 | BLACK (culvert) |
| L05 Manor `night_manor.tscn` | 0 ~ 10 | 10 ~ 22 | 22 ~ 38 | BLACK (outside the fence) |

---

## 2. Rules

**WHITE — safe.** No infected spawn; patrols do not sweep it. The only place you can search while standing still.
Shots still make noise — nobody comes, but the yard hears you.

**RED — curfew.** 3.5 s after you cross the line a warning fires («red zone · white-zone residents forbidden»).
At 7 s the nearest ОСК is called over to challenge you (`alert_to` + radio + screen shake).
The red zone is not impassable — it is a place you **do not stop in**.

**BLACK — the sunken belt.** 7–8 infected in loose packs, big patrol radii, one extra loot roll per container
(`NightZones.loot_bonus`). The black market and the survivors only exist here: the people who cut ties
with the white zone are the only ones who can live in it.

---

## 3. How it reads on screen

A soft wash over the ground, a dashed line on the upper edge, and an English stencil printed on the snow:

- WHITE `#9fc6e0` at 0.075 · `ZONE A · SAFE`
- RED `#c8483a` at 0.115 · `ZONE B · CURFEW`
- BLACK `#3aa0b4` at 0.165 · `ZONE C · SUNKEN`

The wash is drawn **above the baked ground and below every upright sprite** (`z_index = -1`), so props,
actors and lights keep their own colour — the ground is simply telling you which zone you are standing in.
The dossier panel gains one line: `所在区 红区 · 管制带 · 禁止进入（白区户口)`.

---

## 4. Black market

One per level, always in the black zone:

| Level | Position (m) | Anchored by |
|---|---|---|
| Freight Yard | (26.5, 24.2) | 3 m south of the wire gap — you see the lamp as soon as you cross |
| Sorting Park | (33.0, 29.6) | the brazier in the south-east corner |
| Manor | (11.8, 27.4) | the crate stack in the western pines |

- **One can → eight rounds**, only for guns you already own (rifle → sawn-off → pistol), **once per night**.
- Cans are the bait you use to pull infected into a patrol's light cone. The market makes that a real choice:
  bait, or bullets.
- The stall is a plank counter, two ammo boxes, a can and a lantern on a pole (`PRP_Market_Stall`),
  plus a `PointLight2D` at runtime.
- Trader (`PRP_Trader_Stand`, red armband + lantern) and survivors (`PRP_Survivor_Stand`, grey-brown coat +
  **white armband** = white-zone residents) are static sprites with **no collision** — the player walks
  straight through them, so nobody gets stuck at the counter. Walk close and they say one line.

---

## 5. Brazier flame height

The old flame was 84 px tall with its top 130 px above the drum's ground anchor, on a drum only 54 px tall —
it read as if the wall were on fire. The flame is now squashed to 0.42 vertically / 0.58 horizontally;
its top sits at **91 px**, licking 35 px above the rim. Ember particles shrank with it (26 → 20, 1.6 → 1.3 s).

`tests/night_zones_smoke.gd` locks this down: `flame.scale.y ≤ 0.5` and top ≤ 100 px.

---

## 6. Infected distribution

| Level | WHITE | RED | BLACK | Total |
|---|---|---|---|---|
| Freight Yard | 0 | 2 | 8 | 10 |
| Sorting Park | 0 | 3 | 7 | 10 |
| Manor | 0 | 1 | 7 | 8 |

Every infected has a name and a reason in the level file; the red-zone ones are strays pushed out of the
white zone, the black-zone ones come in packs (ballast, signal mast, coal shed, the south-east corner).

---

## 7. How to check it

1. **Look**: the six full-level PNGs in `docs/ui/verify/` show all three bands (red dashes = white/red edge,
   cyan dashes = red/black edge) and the market with its people in the black zone. Web version:
   `docs/ui/acceptance.html`.
2. **Static**: `cd godot_project/tools/art_gen && python3 check_levels.py` → should PASS.
3. **Headless test** (needs an engine):
   ```
   Godot_v4.7.2-stable_win64 --headless --path godot_project -s tests/night_zones_smoke.gd
   ```
   Covers: parser / no gaps between zones / spawn lands in the right zone / infected distribution /
   no half-turned in the white zone / market in the black zone with people beside it / 3.5 s warning and
   7 s challenge in the red zone / one can for eight rounds once per night / flame height.

---

## 8. File map

| Path | Role |
|---|---|
| `godot_project/tools/art_gen/levels/{yard,marshalling,manor}.py` | `ZONES` / `MARKET` / `RABIDS` — single source of truth |
| `godot_project/tools/art_gen/build_scene.py` | writes `metadata/zones`, spawns the market & NPCs, flame params |
| `godot_project/tools/art_gen/gen_market.py` | trader / survivor / stall art |
| `godot_project/scripts/night/NightZones.gd` | parse, zone lookup, colours & copy, loot bonus (pure functions) |
| `godot_project/scripts/night/NightZoneField.gd` | ground bands, dashes, stencils |
| `godot_project/scripts/night/NightExplore.gd` | zone entry, curfew challenge, market trade, HUD line, black-zone loot |
| `godot_project/tests/night_zones_smoke.gd` | headless acceptance |
