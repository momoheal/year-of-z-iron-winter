# Year of Z · Iron Winter — Weapons, Combat Slice & Greybox Art Extension

> P5 slice notes. Code: `godot_project/scripts/night/Arsenal.gd`, `NightExplore.gd` (combat section),
> `NightSoldier.gd` (now killable), `NightOverlay.gd` (combat readouts),
> `tools/art_gen/gen_weapons.py`. Test: `godot_project/tests/night_combat_smoke.gd`.
>
> ⚠️ There is no Godot engine in this sandbox: **none of this has been run on a machine with Godot yet**.
> Stats and data shapes are asserted headlessly, but feel (rate of fire, spread, noise radii) still
> needs the checklist in §8 on a real build.

---

## 1. The two problems this round

1. **Aleksei could only sneak.** Rabids had to be outrun, patrols avoided. The crowbar existed only as
   a cutscene choice ("silence him"), never as something the player could swing.
2. **The other greyboxes were empty.** The yard had art; the marshalling yard and manor had geometry
   and props but nothing to fight with, and no reason to take a risk.

So: one combat feel (crowbar + three guns), one batch of procedural art (weapons / ammo / outpost props /
combat VFX), and both new maps dressed with it.

---

## 2. Art: new assets and how they are produced

`tools/art_gen/gen_weapons.py` (new, 13 assets, same `artlib` pipeline):

| Asset | Use | Size / anchor |
|---|---|---|
| `PRP_Crowbar_Rail` | Railway crowbar (held / world) | 108×82, bottom-centre pivot |
| `PRP_Pistol_TT` | TT-33 pistol | 104×68, grip pivot |
| `PRP_Rifle_Mosin` | Mosin–Nagant | 208×48, trigger pivot |
| `PRP_Shotgun_Sawn` | Sawn-off double | 132×58, grip pivot |
| `PRP_Ammo_Box_Open` | Opened ammo crate (lootable) | **58×47 (≈0.9 m)** |
| `PRP_Sandbag_Line` | Sandbag emplacement (layer 2 low cover) | 208×118 (≈3.2 m) |
| `PRP_WeaponRack` | Weapon rack | **96×94 (≈1.5 m)** |
| `PRP_Target_Silhouette` | Plywood target dummy | **77×127 (≈1.2 m)** |
| `VFX_MuzzleFlash_Sheet` | 4-frame muzzle flash (hframes=4) | 384×96 |
| `VFX_Bullet_Tracer` | Tracer streak | 128×16 |
| `VFX_Impact_Spark` | Impact spark | 64×64 |
| `VFX_Shell_Casing` | Spent casing | 22×12 |
| `VFX_Blood_Mist` | Blood mist | 72×72 |

**Scale rule.** 1 world metre = 64 px. World props must be drawn at true scale (ammo box 0.9 m, rack
1.5 m, target 1.2 m), so those four generators end with `_fit()`, which resizes the finished sprite and
scales the pivot with it. Held weapons are deliberately drawn 2–3× oversized so they read at 64 px/m;
`Arsenal`'s `scale` brings them back in-engine.

**Only the new stuff is written.** A separate `weapons` step exists instead of re-running `props`/`vfx`:
PIL version drift would rewrite the old assets with invisible but non-identical bytes, and the repo
requires the yard's ground and facade to stay pixel-identical.

```bash
cd godot_project/tools/art_gen
python gen_assets.py --level yard weapons
python gen_assets.py --level marshalling weapons
python gen_assets.py --level manor weapons
python build_scene.py --level marshalling
python build_scene.py --level manor
python check_levels.py        # must PASS
```

---

## 3. The arsenal: four weapons

`scripts/night/Arsenal.gd` is the single source of truth (damage / rate / noise / spread live here; the
runtime never keeps a second copy).

| id | Name | Type | Damage | Rate | Mag | Reserve | Noise | Range | Spread |
|---|---|---|---|---|---|---|---|---|---|
| `crowbar` | Railway crowbar | melee | 34 | 1.45/s | — | — | 4.5 m | 1.9 m (±0.85 rad) | — |
| `pistol` | TT-33 | semi | 42 | 3.6/s | 8 | 16 (cap 32) | 26 m | 16 m | 2.6° |
| `rifle` | Mosin–Nagant | single | 96 | 1.05/s | 5 | 10 (cap 25) | 44 m | 28 m | 1.1° |
| `shotgun` | Sawn-off double | single | 15 × 6 pellets | 1.15/s | 2 | 8 (cap 20) | 38 m | 9.5 m | 7.5° |

Crowbar damage matches `CampaignData.WEAPONS` (34) so the campaign layer and the raid layer never
disagree about the same object.

**Starting loadout**

* The crowbar is always in slot 1.
* In a campaign raid the gun comes from `cfg.weapon` (`best_weapon()`): `mosin → rifle`,
  `shotgun → shotgun`, `cleaver / crowbar / fist → crowbar`; a TT-33 is always added as the sidearm.
* Running the scene standalone (F2) gives crowbar + TT + Mosin so the slice can be verified directly.

**Where ammo comes from**: looting `ammo` / `bolt` / `part` converts into reserve rounds
(`Arsenal.AMMO_FROM_ITEM`); both new maps place a `PRP_Ammo_Box_Open` with `guaranteed="ammo"`.
Leftover rounds are written back into `RaidSim.ammo` on extraction so the campaign report shows
"mag / reserve".

---

## 4. How it feels

**Aim and hit detection**

* Aiming reuses the player's mouse facing (`facing`, already y-compensated for the 0.62 ground squash).
  Bullets leave at chest height (`player.global_position + (0,-40)`) and targets are measured at chest
  height too, so the offset never turns into a constant vertical bias.
* Hits are analytic: project each living target onto the shot, reject `perp > HIT_R`
  (OSK 0.46 m / rabid 0.52 m / half-human 0.40 m) and require `los_clear(mask=1)`.
* Bullets stop on physics layer 1 (walls, boxcars, heavy props). Sandbags are layer 2 (low cover): they
  block sight, not bullets.
* Every pellet is resolved separately (6 per shotgun shot), each with its own tracer / mist / spark.

**Noise: guns are how you buy passage**

* A shot calls `emit_noise(pos, noise, "gun", true)`: ripples only, no default gunshot sound (the
  weapon's own voice is played), and every OSK within 80 % of the radius goes `alert_to(player)`.
  Fire once and the patrols collapse on you.
* Rifle 44 m is effectively a map-wide broadcast; the double 38 m; the pistol 26 m is a gamble.
* The crowbar is 4.5 m and rides the `step` ripple: quiet, but you must be within 1.9 m.

**Enemy health and death**

* `NightSoldier` gained `hp = 100`, `dead`, `hit()`, `die()`, `is_alive()`: a hit flips it to `alert`
  (it knows where you are), and at zero it becomes a body — no more arrests, no more shots, sprite
  fading out.
* Killing one costs `conscience -= 0.5` and pulls every comrade within 34 m toward the corpse.
* Rabids: 3 crowbar hits / 3 pistol rounds / 1 rifle round. Player kills count as `rabid_kills`,
  tracked separately from knife-borrowing.
* Half-humans: killing one with a weapon is still a mercy kill — `tally += 1`, `conscience -= 10`,
  and it never double-counts when the same death came from the choice panel.

**Empty / reload / swap**

* Pulling the trigger on an empty mag clicks and auto-reloads. `R` (the `reload` action) reloads at any
  time; reloading blocks firing; swapping interrupts a reload.
* `1`–`4` select weapons, only slots you actually own.

---

## 5. Map changes ("the other greyboxes")

Data only, never hand-edited `.tscn` (the scene is rebuilt by `build_scene.py`):

* **Marshalling yard** — `Sandbags` on the hump shoulder (33.0, 9.2): cover to shoot down track 1, crouch
  to break line of sight. `AmmoBox` under the dispatch tower (24.2, 5.6, `guaranteed="ammo"`) so you can
  top up after grabbing the departure order. `WeaponRack` by the depot door (12.4, 4.1) — empty hooks,
  the people here already took their rifles.
* **Manor** — `Sandbags` in front of the incinerator yard (27.0, 12.6), pairing with the parked forklift
  as the two pieces of hard cover. `AmmoBox` at the guard post (21.0, 6.2); `WeaponRack` beside the
  Batch-409 pallet (9.2, 4.2).
* **Yard** — untouched: it is the pixel reference build, and not one old asset was redrawn.

---

## 6. HUD and world readouts

* The dossier plate gains a weapon line: `TT-33 · 6 / 16` plus the slot strip `1·Crowbar [2·TT-33] 3·Mosin`;
  an empty mag turns the line amber with `空仓 · R 装填`, and reloading shows `装填中…`.
* The teletype bar's idle text now lists `LMB attack / R reload / 1-4 swap`.
* `NightOverlay` draws: a four-tick crosshair (spread-scaled) plus a reload arc; a swing arc for the
  crowbar; tracers (0.07 s), spark/blood mist, tumbling casings, and hit markers (white-amber = hit,
  red = kill). Dead soldiers no longer show `!` / `?`.

---

## 7. Controls

| Key | Action |
|---|---|
| LMB / `Space` | Attack: crowbar swing (hold to keep swinging) / single shot |
| `R` | Reload (an empty trigger pull reloads automatically) |
| `1` `2` `3` `4` | Crowbar / TT-33 / Mosin / sawn-off (owned slots only) |
| `F5` | Restart when running the scene standalone (**`R` restart was moved off `R`**) |

---

## 8. Verification

`tests/night_combat_smoke.gd` (headless):

```bash
Godot_v4.7.2-stable_win64 --headless --path godot_project -s tests/night_combat_smoke.gd
```

It asserts: arsenal table + asset existence, starting loadout (crowbar always, gun drawn by default),
slot swapping, reload consuming reserve, crowbar cone hits (and misses behind you), three hits dropping a
rabid, shooting consuming ammo + tracer + ripple + alerting a patrol, cooldown and empty-mag behaviour,
soldier damage/death (comrades converge, corpse no longer catches), and ammo pickups with caps.

**Eyeball on the first real build**

1. Held weapon orientation and left/right flip; muzzle flash at the muzzle, not at the feet.
2. Sandbags block sight but not bullets: shoot the man behind them, and stay unseen while crouched.
3. After killing an OSK, do nearby comrades actually move toward the body?
4. All three maps' ammo boxes yield rifle rounds and the HUD reserve count rises.

---

## 9. Not done yet

* No new character frames for "holding a gun" or "swinging"; the weapon is a sprite rotated next to the
  player. `CHR_01` needs two extra rows.
* Reload/bolt animations and casing audio are still "one sound + one sprite".
* No hit-confirm sound and no recoil-driven crosshair bloom (spread is fixed per weapon).
* `gym.tscn` (the 5-in-1 greybox) is pure `_draw()`, so the new props were not added there; shooting
  practice in the gym would need a sprite layer or `PRP_Target_Silhouette` drawn inside `Gym.gd`.
