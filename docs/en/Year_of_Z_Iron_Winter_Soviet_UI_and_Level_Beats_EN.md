# Soviet UI System & Level Beats (v4.1 Front-end / Map-Feel Pass)

> A pass that touches **only the front-end and the way the maps breathe**. Three node-based night maps
> (yard / marshalling / manor) now share one «Iron Winter» interface, and "how this map kills you"
> lives in a data table. No gameplay-number changes, no new art assets, no `.tscn` edits.

---

## 1. Why "heavy" and not "fancy"

Soviet heavy industry is material and bureaucracy, not decoration:

* **Material** — steel plate, rivets, pig iron, asphalt. No rounded corners, no glossy gradients,
  no frosted glass. Panels are one plate bolted on another, separated by **1–2 px double rules + whitespace**.
* **Bureaucracy** — file numbers, red stamps, interrogation forms, teletypes, secrecy grades.
  Very little on screen is actually "bright": one red stamp band, one brass gauge, one line of
  teletype green; everything else is bone white on iron grey.
* **Climate** — −30 ℃. Gauges lose segments, blink, frost over; the screen edge darkens and,
  when things go wrong, the whole plate glows red.

---

## 2. Design tokens (`scripts/ui/SovietUI.gd` — the single source of truth)

| Token | Value | Role |
| :--- | :--- | :--- |
| `INK` | `#070809` | asphalt black: deepest layer, gauge trough |
| `IRON` / `IRON_LIT` / `PLATE` | `#121618` / `#1b2023` / `#22282b` | panel / hover / sub-plate |
| `STEEL` / `STEEL_LIT` / `RIVET` | `#343c3f` / `#4a5457` / `#565f62` | rules / lit edge / rivet heads |
| `BONE` / `BONE_DIM` | `#d8d1bf` / `#928c7c` | body / annotation |
| `OCHRE` / `OCHRE_DIM` | `#c8a257` / `#8c7139` | key readings / objective / oxidised brass |
| `BLOOD` / `BLOOD_LIT` | `#8c1c14` / `#b8281c` | red stamp / alarm / the 卌 tally |
| `SIGNAL` | `#d9a326` | sodium lamp: suspicion / ambient alarm |
| `FROST` | `#8fb4c4` | hypothermia, cold readings |
| `CRT` | `#63d18a` | teletype green — only the teletype uses it |

Three font stacks via `SystemFont` (always degrade to a CJK fallback):
`display_font()` (Oswald → Bebas Neue → Bahnschrift → Impact → Noto Sans CJK SC),
`mono_font()` (JetBrains Mono → Cascadia → Consolas → DejaVu Sans Mono → CJK),
`body_font()` (Noto Sans CJK SC → Microsoft YaHei → PingFang SC).

Text helpers: `bearing_line()` (8-way + metres), `clock()` (mm:ss), `danger_pips()` (▲▲▲△△),
`tally_glyphs()` (卌), `night_zh()`, `pct()`.

---

## 3. Components

| Component | File | Notes |
| :--- | :--- | :--- |
| **Full-screen plate** | `ui/SovietChrome.gd` | L-shaped corner brackets, edge rivets, 10-band exponential vignette, 3 px scanlines, red star + works mark. `danger > 0` bleeds red from the edges. Static art only redraws on resize; the "old tube" breathing is `modulate.a`, **no redraw** |
| **Segmented meter** | `ui/SovietMeter.gd` | 16 steps, drops one notch at a time; below 35 % the remainder blinks; pure `_draw()`, no textures |
| **Plate StyleBoxes** | `SovietUI.plate/inset/stamp/brass` | `corner_radius = 0`, 1–2 px borders, shared margins |
| **Buttons** | `SovietUI.dress_button()` | primary = blood red, secondary = iron, hover turns brass |

---

## 4. HUD skeleton (`NightExplore.gd`)

* Top-left **night dossier**: red stamp band (`ДЕЛО № … │ dawn clock`) → level name in stencil type →
  `ТЕПЛО` / `ЗДОРОВЬЕ` segmented gauges → stance/conscience line → pack.
* Top-right **mission card**: objective sentence, **objective bearing**, **extraction bearing**,
  live threat lines ("nearest ОСК 12 m south-west", "frozen slush ×2 noise", "ambient alarm"),
  and landmark progress with the nearest unlogged landmark's bearing.
* Bottom **teletype bar**: every "hold E" prompt is printed by this machine.
* Opening **dossier card** (7 s): works mark, two lines of "what this place is", danger pips,
  night length, extraction phrase.
* Moral choice panel is an `ОПРОСНЫЙ ЛИСТ` (interrogation form).
* `CampaignHUD.gd` / `GymHUD.gd` / `HUD.gd` now use the same factories; the old slate palette was
  remapped table-wide; the campaign title screen is a case-file cover (`ЖЕЛЕЗНАЯ ЗИМА` + a tilted
  `СЕКРЕТНО` stamp); map node cards gained a "site dossier" block.

---

## 5. Level beats (`scripts/night/LevelBeats.gd`)

Director state machine: `""` → `warn` (reaction window) → `live` (per-frame checks) → cleanup → `period`.

| Map | Beat | Warn | Live | Rule | Counter-play |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **marshalling** | Hump shunting `hump` | 2.6 s klaxon + teletype + threat line | 3.0 s: a boxcar rolls track 2, 43 m → 1 m (dark silhouette, lamp, rail clank every 0.34 s) | Within 2.2 m of the car and ±1.15 m of that lane → shoved: −9 HP, −6 warmth, 12 m noise | Leave the lane, or **throw the switch (E)** to send it down track 3 |
| **manor** | Furnace flare `flare` | 2.4 s (furnace whitens + thud) | 1.6 s: fill light to 3.4 energy, post `alarm` raised, small camera shake | Inside 22 m with line of sight (no layer-1 cover: pines / cars / pipes / walls) → "your shadow is nailed to the snow": ОСК within 34 m `alert_to()`, 10 m silent ripple; crouching behind layer-2 low cover also saves you | Crouch into the pine line / behind a boxcar, or stay out of the furnace half |

**Mechanisms (press `E`)**: marshalling — switch stands 01/02 flip the hump lane (and clank 7 m);
manor — start the parked forklift once (16 m "giant tin can" that pulls everything towards it).

**Landmarks**: walking within radius logs a teletype line + an archival annotation and updates
`勘踏 n/m`; they grant no loot — they reward *reading the place* (which carriage is Lana's,
which lamp is the dispatch tower's).

---

## 6. Verification

```bash
Godot_v4.7.2-stable_win64 --headless --path godot_project -s tests/night_beats_smoke.gd   # new
Godot_v4.7.2-stable_win64 --headless --path godot_project -s tests/night_explore_smoke.gd # regression
Godot_v4.7.2-stable_win64 --headless --path godot_project -s tests/night_level_smoke.gd   # regression
```

All `.gd` files parse under gdtoolkit; **the pass has not yet been first-run on a machine with Godot**.
On the first run also eyeball: dossier not squeezed by the mission card, mission card inside the right
edge, teletype bar not covering world-space readouts, opening dossier fading out after 7 s.
