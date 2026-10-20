# Year of Z: Iron Winter — Phase 1: Greybox Prototype Specification & Asset List (v4.0)

> **Document Version**: Phase 1 — Greybox Spec & Vertical Slice Asset List (v4.0 · Post-Soviet Industrial Winter)
> **Target Milestone**: Playable 5-in-1 Greybox Gym → Vertical Slice
> **Aesthetic Target**: Fictional Siberian railway hub **"Novorsk-17 (`Новорск-17`)"** — prefabricated Khrushchyovka concrete panels, rusted overhead steam pipes, lead-grey GP-5 gas masks, polar blizzards, and the broad-gauge armored train *"Buran"* ("The Iron Shell").

---

## I. World Metrics, Camera & Collision Spec

### 1. Camera & Scale
* **Projection**: **2D `75°` Top-Down Oblique** — combines *Darkwood*'s `90°` directional line-of-sight fog with *Metro / Project Zomboid*'s Soviet industrial decay.
* **Base Scale**: `1 World Meter = 64 Pixels` (`30m × 18m` standard single-screen arena).

### 2. Geometry & Line-of-Sight Metrics

| Entity / Geometry | Logical Size (`m`) | Pixel Size (`@64px/m`) | Collision & Searchlight Occlusion Rules |
| :--- | :--- | :--- | :--- |
| **Aleksei (Player / Stalker)** | Radius `0.35m` | `45 × 45 px` | Blocks movement; does not occlude player's own `90°` vision cone. |
| **"Ash" (`Пепел`, Wolfdog)** | Radius `0.25m` | `38 × 32 px` | Ignores player collision (prevents hallway body-blocking); trails `1.5m` behind player. |
| **Narrow Canteen/Boiler Door** | `1.0m × 0.2m` | `64 × 13 px` | Single-file passage; **supports Crowbar Wedge (`Hold E 1.2s` → locked for `15s`)**; blocks searchlights when closed. |
| **Overhead Steam Pipe / Low Wall** | `0.8m × 2.0m` | `51 × 128 px` | Does not block standing sight; **holding `Ctrl` (Crouch) in its shadow grants 100% immunity to O.S.K. searchlight cones**. |
| **Wire-Mesh Quarantine Fence** | `1.5m` wide, `0.12m` bottom gap | `96 px` wide | Blocks movement; **transparent to sightcones & searchlights**; supports pushing aluminum lunchboxes through the `12cm` bottom gap. |

---

## II. 3C Movement, Stealth & Anti-Power-Fantasy Combat Metrics

### 1. Movement & Acoustic Ripple Radii

| Movement State | Speed (`m/s`) | Stamina (`/s`) | Acoustic Ripple Radius (`m`) | Siberian Environmental Modifier |
| :--- | :--- | :--- | :--- | :--- |
| **Crouch Stealth (`Hold Ctrl`)** | `1.6 m/s` | `0` | `0.8m` (inaudible) | Full concealment inside steam-pipe shadows; stepping on black ice expands ripple to `4.5m`. |
| **Normal Walk (`WASD`)** | `3.2 m/s` | `0` | `2.5m` | Wolfdog "Ash" automatically follows `1.5m` behind. |
| **Panic Sprint (`Hold Shift`)** | `5.0 m/s` | `-18 /s` | `7.5m` | Alerts any O.S.K. soldier or rabid infected within half a screen. |
| **Frozen Slush Wading** | `× 0.65` | `-5 /s` | `× 2.0` (slush splash) | Leaves wet bootprints for `4.0s` after exiting the puddle. |
| **Throw Empty Tin Can (`Press G`)** | `8.0m` throw | `-5` | `9.0m` impact clang | **[Core "Borrowing the Knife" Mechanic]**: Lures O.S.K. searchlights toward rabid infected so the Purge Squad eliminates them for you. |

### 2. Weapons & Special Mechanics

| Weapon / Tool | Windup | Active | Recovery | Range | Special Programmatic Mechanic |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Railway Spike Crowbar (`Лом`)** | `0.35s` | `0.15s` | `0.45s` | `1.3m` (`60°`) | **[Door Wedge]**: Hold `E` near a door for `1.2s` to lock it shut for `15s`. Executing a non-hostile Regressing Half-Human (`Choice A3`) carves **`+2 Strokes`** on the logbook's `卌` tally. |
| **East Street Butcher Cleaver (`Секач`)** | `0.25s` | `0.10s` | `0.35s` | `1.0m` (`45°`) | **[Collarbone Blade Jam]**: Frontal hits on rabid targets jam the blade in the collarbone. Requires **`6 rapid presses` within `1.5s`** to pull free. Unlocks **PTSD Thirst Tinnitus** after Room E. |

---

## III. Phase 1: Playable 5-in-1 Greybox Gym Specification (`Rooms A–E`)

Before building the full 10-level campaign, all core mechanics are validated inside a single connected `30m × 20m` **5-in-1 Greybox Test Gym**:

1. **Room A — 3C, Frozen Slush & O.S.K. Searchlight "Borrowing the Knife"**:
   * Contains a `6m × 4m` frozen slush pit, an overhead steam-pipe shadow cover, 1 patrolling **O.S.K. Purge Soldier** (`45°` yellow-white searchlight + suppressed AKM), and 2 **Rabid Infected**. Validates crouching (`Ctrl`) in pipe shadows and pressing `G` to throw an empty sardine tin so the O.S.K. soldier shoots the rabid infected.
2. **Room B — Crowbar Door Wedge & Under-Fence Lunchbox Delivery**:
   * Features a deformed cold-storage steel door (press `E` to wedge shut for `15s` with the crowbar) and a wire-mesh quarantine fence with a `12cm` bottom drainage gap (press `E` to push the warm buckwheat lunchbox through to the starving loader).
3. **Room C — The Paper Dead, Regressing Half-Human & Dual Logbook (`卌`)**:
   * Contains **Sergey & Maria** beside a Soviet teletype terminal reading `ERROR: 0 PERSONS AT COORDINATE` (press `E` to write their real names on the Logbook Back Left Page) and a **Regressing Half-Human** trembling in a culvert (press `1` for **Choice A1: Feed Aspirin Water** [`+0` strokes, gain Old Ivan's cipher] or press `3` for **Choice A3: Crowbar Execution** [`+2` blood strokes on the `卌` tally]).
4. **Room D — Siberian Wolfdog "Ash" (`Пепел`) Tri-State Olfactory AI**:
   * Three side-by-side cages holding **I. Febrile Rabid** (Ash bristles & barks), **II. Self-Bound Anna `0419`** (Ash flattens ears & whimpers, unlocking Lana's Carriage No. 3 clue), and **III. Desperate Father with Red Plastic Strip & Insulin** (Ash wags tail & touches boot).
5. **Room E — East Street Canteen Kitchen (Collarbone Blade Jam QTE & PTSD Thirst)**:
   * Replicates the `8m × 6m` kitchen arena. Approaching the pantry triggers **Vasily** bursting through the door in `40°C` delirium. Swinging the Butcher Cleaver (`Space / Click`) triggers the **Collarbone Blade Jam (`6x Rapid Press QTE`)**. Upon extraction, Vasily's pupils clear to blue as he whispers *"…Пить (Thirsty)…"*, unlocking the permanent PTSD audio hallucination whenever the player drinks water (`Press Q`).
