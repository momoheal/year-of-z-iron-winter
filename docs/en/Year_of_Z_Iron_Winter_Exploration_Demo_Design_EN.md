# Year of Z: Iron Winter — Exploration Demo Design Document

- **Version**: 2026-10-22 (district-sketch generator build)
- **File**: `prototypes/Year_of_Z_Iron_Winter_Exploration_Demo.html` (single file, zero build step, Canvas 2D)
- **Play online**: https://momoheal.github.io/year-of-z-iron-winter/prototypes/Year_of_Z_Iron_Winter_Exploration_Demo.html
- **Role**: Godot is the main line; this HTML demo is a design sketch — ideas are played through and verified here first, then landed in the Godot Novorsk-17 first level.

## 1. Positioning and Core Loop

The player spends one night (250 real seconds, 22:00–05:00) in a ruined city district:

**Enter the district → find cover → loot containers and corpses → evade purge squads / kill rabid → stay warm → finish commissions → survive until dawn.**

Three tensions drive the loop: vision (you only see a small patch ahead), warmth (cold forces you to light fires, and fires give you away), and identity (half-humans must not be killed by mistake, purge squads cannot be fought head-on).

## 2. Map Generation: Art First

The old pipeline was backwards: BSP randomly cut a wall maze first, then decorated each wall tile — buildings could only ever be wall boxes, and walls always covered half the map. This build flips it: **draw a district sketch first, then grow playable tiles from it.**

### 2.1 Street Grid

- One main horizontal avenue + one main vertical avenue (4–5 tiles wide) + full-span branches (3 tiles wide, 2–3 of them), all inset ≥2 tiles from the border so the border ring is never cut.
- Branches must be full-span: a horizontal branch runs the whole width, a vertical branch the whole height. Lesson learned: a half-span branch still counts as a full band when computing sectors, leaving a "shadow wall strip" that severs sectors.
- Same-orientation street bands keep ≥4 tiles of clearance between them so sectors can form.

### 2.2 Sectors

The rectangular gaps between street bands (≥4 tiles) are sectors; each sector is one open yard room (the room rect is the whole sector).

- Yard rooms get a random mechanic: storage / freezer / dark / kitchen / clinic / patrol / workshop / none.
- The room center is not fixed to the sector center: after buildings and blocks are placed, a spiral search from the sector center finds a clean floor tile (not inside a building) as the room center — spawn and respawn points always stand on clean floor.

### 2.3 Buildings

- **Solid blocks**: 1–2 per sector, 5–9 × 4–6 tiles. Interior tiles render as full roofs, edge tiles as facades with windows (some lit, some dark). A building is now one coherent block, not a wall box.
- **Enterable buildings**: 1–3 per map. Interior 5–7 × 4–5 tiles, one ring of wall around it, one locked door (BDOOR).
  - Doors face streets only: the tile outside the door must lie on a street. The street network is connected by construction, so a door approach is always reachable — and it matches real buildings opening onto streets.
  - Interior + wall ring + door all go into the protection set: the connectivity repair may neither carve through a building wall nor seal a building interior.
  - Roofs stay on: an undiscovered building shows only a faint silhouette (0.5 alpha), a discovered one a full roof; the roof lifts when the player enters or stands at the door.
- Purge squads, patrol waypoints, half-humans and NPCs never spawn inside buildings; rabid may hide inside.

### 2.4 Border

The outer ring is split into 6–13 tile segments, about 55% building segments (wall, rendered as whole buildings with lit windows) / 45% fence segments (dense posts + two rails + slanted barbed wire on top). The border ring is known from the start: the minimap shows the full perimeter immediately (building segments dark grey, fence segments light grey).

### 2.5 Environment and Containers

- Slush / cover / barbed wire / corridor doors all follow guards: never on a room-center tile (spawn points), never on a street-adjacent tile (sector exits), never on a door-approach tile, never inside buildings.
- Container types: crate, locker, medcab, fridge, briefcase, safe, hidden, abandoned car, dumpster, supply box, corpse.
  - Bias: interiors use fridge / locker / medcab / briefcase; outdoors use car / dumpster / supply; kitchen, clinic, workshop and storage rooms each have their own bias; fridges appear only inside buildings.
- Corpse loot (generated on search, by who died): rabid drop scrap / food / warmth; purge troopers drop parts / weapons / meds / valuables; half-humans drop food / valuables / meds.

### 2.6 Connectivity Guarantees

- **Check on placement**: every time a building or block is placed, sectorConnected verifies the sector's open floor still reaches a street; if it does not, the placement is reverted and retried elsewhere.
- **Post-generation repair**: ensureConnected flood-fills from the entry, connects isolated islands with L-shaped corridors (skipping protected tiles), seals remaining dead zones to wall and removes their containers.
- **Measured data** (20 random seeds): wall share 17.5–24.8% (mean 21.7%, the old BSP build was ~50%); reachable area 68–76% (mean 72.1%); 2–3 enterable buildings per map; 154–302 roof tiles; yard room centers, building door approaches and yard containers all reachable; fridges only inside buildings; purge squads / NPCs / half-humans never inside buildings.

## 3. Tiles and Rendering

Tile types: FLOOR, WALL, SLUSH, COVER, FENCE, DOOR (corridor door), WEDGED (wedged-shut door), BDOOR (locked building door).

Rendering rules:

- Block interior tiles (wall on all four sides) render as full roofs; edge tiles as facades with windows; border buildings and fences likewise.
- Enterable building roofs are drawn after the fog by drawRoofs: 0.5-alpha silhouette when the door is undiscovered, full when discovered, hidden when the player is inside or standing at the door.
- Oblique top-down view: 38 px per meter (zoom 26–72 with -/=), y-axis squash 0.62 (75-degree approximation), wall extrusion height 0.62.
- Fully procedural art (no external images, all embedded in the HTML): per-tile hashed detail (ground cracks / ruts / snow spots, snow on wall tops, cracks, pipes), blood decals (cap 40), characters (player hooded parka + backpack, rabid in rags with red eyes and outstretched arms, purge trooper in tactical vest, helmet and rifle, hunched pale half-human, NPC wide-brim hat / armband).

## 4. Vision and Fog

- Main vision cone 90 degrees, sight range 12 m; 7.2 m with cracked glasses; dark rooms ×0.65.
- Near sense 1.8 m: anything that close is perceived regardless of facing.
- Ring vision: a 5×5 ring (2 tiles) around the player is visible regardless of facing, but still blocked by walls; outside the ring the cone still applies.
- Line-of-sight (losClear): the target tile itself does not block; open doorways see through; wedged doors still block; walls block as intermediate tiles.
- Fog: explored tiles stay as dim memory, unexplored tiles are black; the border ring is known from the start.
- Minimap: explored tiles only, colored by wall / fence / door / slush.

## 5. Characters, Enemies and Combat

Player: HP 100, stamina 100, warmth 100. Speed: walk 3.2 / sneak 1.6 / sprint 5.0 m/s. Noise radii: walk 2.5 / sneak 0.8 / sprint 7.5 / slash 1.6 / search 3.2 / thrown can 9 / gunshot 25 m.

Weapons:

| Weapon | Damage | Range | Notes |
| --- | --- | --- | --- |
| Bare fists | 8 | 0.9 | Cannot stop a rabid, only shoves |
| Railway crowbar | 34 | 1.3 | Wedges doors for 15 s; claw pushes tins through 12 cm gaps |
| Rusty butcher cleaver | 46 | 1.0 | Frontal heavy strikes jam 100% into the collarbone gap; 6 presses in 1.5 s to pull free |
| Sawed-off shotgun | 95 | 9 | Spread widens with heart rate; the blast wakes every patrol on the map |
| Mosin–Nagant | 150 | 18 | One shot, one body; slow bolt, sound carries farther than the blizzard |

Enemies:

- Rabid (60 HP): bites; brute variant (150 HP, slow heavy hits).
- Purge troopers (120 HP): patrol in pairs on shared waypoints; suspect / lock two-stage AI; firearms.
- Half-humans (40 HP): crouched; killing one by mistake has a cost; Anna can mark their state directly.
- Corpses: kills leave a fallen body; press E nearby to search (loot by who died).

Game feel: knockback (rabid 0.6 / trooper 0.35 / brute 0.25 m) + hit-stop (0.045 s, 0.09 s on kill) + screen shake + floating damage numbers. Separation collision between player and hostiles (0.75 m) and between hostiles (0.7 m); bite range 1.15 m is unaffected.

Companions: Ash (wolfdog, 6 m olfactory warning marking containers and creatures, tri-state bark telling rabid / half-human / pleading kin apart); Anna (identifies half-humans, +4 backpack slots).

## 6. Survival and Night

- One night lasts 250 real seconds; location cold factors 0.4–1.3.
- Slush: speed ×0.65, noise ×2.0.
- Braziers restore warmth; kitchens come with a fire; freezer rooms drain warmth ×1.6; clinics heal +25 HP on first entry.

## 7. NPCs and Commissions

- Black-market Zhou: 1-for-1 trades from the pack. He wants vodka / watch / tape / glass and offers bandages / aspirin / rye bread / canned food / water.
- Shelter liaison: fetch / hunt / rescue commissions; baselines (kills / rescues) are recorded on acceptance, rewards go to the pack.

## 8. Controls

Desktop: WASD move, mouse aim, click to attack, hold E to interact (locked doors 0.8 s, crowbar wedge 15 s), G throw can, Q drink, F bandage, R reload, Shift sprint, Ctrl sneak, -/= zoom.

Touch: bottom-left virtual joystick, drag to aim, right-side buttons (attack / hold-E interact / throw can / drink / bandage / reload / sprint and crouch toggles / zoom +/-); facing follows movement (finger aim takes priority within 0.4 s); pinch zoom disabled on the canvas.

## 9. Location System

13 nodes (e.g. Block 3 boiler-room back alley, Rail Cold Storage No.4, Broad-Gauge Freight Yard, Icy Rail Underpass), each with difficulty, seed, cold factor, loot bias, time limit and story. Seed = node seed ×3 + day count; a node's remaining loot persists across nights.

## 10. Engineering and Verification

- Single file, zero build step; seeded RNG (mulberry32), same seed means same map.
- Node harness (DOM proxy stubs, stubbed sound effects) runs startScene / update / draw smoke tests and assertions: structure, connectivity, wall share, building seals, border, container bias, spawn placement, corpse tables, roof visibility, ring vision, melee through doors.
- Relationship to the Godot line: HTML is only a design sketch; ideas verified here (vision, building mechanics, game feel, commissions) are then landed on the Godot main line.

## 11. TODO and Known Limits

- TODO: replace procedural art with formal assets per the art prompt spec; dialogue / save / chapter / log systems; Novorsk-17 first level in full.
- Known limits: procedural art only, no saves, single-night flow, balance not yet tuned.
