# Year of Z: Iron Winter — Game Design Document (GDD v4.0 · Russian Winter Edition)

> **Project Codename**: *Year of Z: Iron Winter* (`Хроники Года Z: Железная Зима` / 《Z年纪事：凛冬铁轨》)
> **Setting**: Fictional Post-Soviet / Siberian Railway Industrial City **"Novorsk-17 (`Новорск-17`)"** at `-30°C`.
> **Genre**: 2.5D (`75°` Oblique Top-Down) Three-Way Stealth Survival & Bureaucratic Realism Narrative RPG
> **Core Benchmarks**:
> * *Metro Exodus* × *Kabaneri of the Iron Fortress* — Broad-gauge armored train *"Buran"* ("The Iron Shell"), Khrushchyovka apartments, GP-5 gas masks, and blizzard rail yards.
> * *Papers, Please* × *Chernobyl* — Pass stamps (`Пропуск`), teletype ration terminals, and the lethal absurdity of forcing physical reality to match bureaucratic ledgers.
> * *Darkwood* × *This War of Mine* — `90°` vision cone, searchlight shadow stealth, and the dual anchor of protecting a uremic mother by day while searching for a vanished sister by night.

---

## I. Core Design Pillars

### 1. Dual-Anchor Day/Night Loop (Day: Protect Mother / Night: Find Sister)
* **Daytime (Conscript Laborer Inside the Wall)**: Play as former freight dispatcher **Aleksei Morozov**. To preserve medical power and peritoneal dialysis fluid for **Mama Katya** in Room 602, you accept the indelible violet-blue observation stamp on your frostbitten hand and haul supplies across cold storages and condemned dormitories with a cast-iron railway crowbar.
* **Nighttime (Curfew Stalker Along the Broad-Gauge Tracks)**: Your 22-year-old sister **Lana (`File 0420`)** was swept into Carriage No. 3 of the armored train *"Buran"* during a spore screening. Every night after the gates are welded shut, you pry open the boiler-room vent and stalk the blizzard tracks to uncover her train's liquidation route.

### 2. Three-Way Stealth & "Borrowing the Knife" (`ОСК` vs. Infected vs. Stalker)
The frozen night is governed by three hostile/neutral forces: **Grey-Scale Infected / Regressing Half-Humans**, **MVD Special Sanitary Purge Squads (`ОСК`)**, and **Black-Market Survivors**.
* **The O.S.K. Purge Squad is the Ultimate Night Threat**: Equipped with `45°` high-lumen searchlights and suppressed AKM rifles, they shoot both infected and curfew-breakers without hesitation. By pressing `G` to throw an empty sardine tin toward rabid infected, players can **lure O.S.K. patrols into clearing out infected packs ("Borrowing the Knife" / 借刀杀人)**.
* **Life-or-Death Tri-State Identification**: Patients who survive four days of `40°C` fever naturally shed their grey scales and regain human consciousness. Is the figure reaching toward you in the blizzard a rabid attacker, or a waking "Half-Human" like your sister Lana?

### 3. Diegetic Dual Logbook & Russian 5-Stroke Tally (`卌`)
* **Front Page (Official District Teletype Form)**: Check `[0 Persons at Coordinate]` to appease the system, or refuse to falsify the count.
* **Back Page (Left: Real Names / Right: Russian 5-Stroke Tally `卌`)**: Left page records verified living names in fountain pen for the Hill 302 broadcast. Right page tracks moral compromises using Russian prisoner tally marks (`卌` — 4 verticals + 1 diagonal slash). Killing regressing half-humans (`A3`), surrendering Guliya's manuscript (`B1`), or betraying black-market allies (`C2`) carves permanent strokes that determine whether Lana survives the finale.

---

## II. 3C Combat, Stealth & Tri-State Identification

### 1. Vision Cone, Blizzard Hypothermia & Cracked Glasses
* **`90°` Directional Vision Cone + `1.8m` Close Awareness Circle**: Areas outside line-of-sight render as high-grain monochrome Soviet newsprint static, revealing hidden entities only through **Tri-Color Audio Ripples**:
  * **Crimson Jagged Ripple**: Rabid infected scraping or lunging.
  * **Ash-White Trembling Ripple**: Regressing half-human weeping in Russian (*"…Воды (Water)… my son is on the third floor…"*).
  * **Cold-Blue Metallic Ripple**: O.S.K. heavy boots crunching snow, gas-mask respiration, and teletype scanner beeps.
* **Cracked Glasses Debuff**: Taking a hit cracks Aleksei's right lens, reducing sight range by `40%` (`12m → 7.2m`) until repaired with black electrical tape.

### 2. Tri-State Identification Matrix

| State Category | Visual & Behavioral Cues | Audio Ripple Signature | Wolfdog "Ash" (`Пепел`) Reaction | Moral & Logbook Consequence |
| :--- | :--- | :--- | :--- | :--- |
| **I. Febrile Rabid**<br>*(Active Rabid)* | `>40°C` encephalitic delirium, blackened sclera, quadruped lunge | Crimson jagged ripple | **Bristles & barks fiercely**, bites ankle to interrupt charge | Self-defense kill adds `0` strokes; heavy frontal cleaver strike triggers **Collarbone Blade Jam**. |
| **II. Regressing Half-Human**<br>**[Choice A]** | Grey scales flaking off hands, pupils clearing, holding head or self-bound with belts | Ash-white trembling ripple | **Flattens ears & whimpers**, refuses to bite | • **A1 Feed Aspirin/Food**: Conscience ▲ (`+0` strokes)<br>• **A2 Bypass**: Neutral (`+0` strokes)<br>• **A3 Crowbar Kill**: Conscience ▼ (**`+2 Strokes`** on `卌` tally). |
| **III. Recovered / Desperate Kin** | Normal `36.6°C` temperature, or father waving red plastic strip & insulin syringe | Clear white human voice ripple | **Wags tail**, touches boot tip with wet nose | Blind-firing in panic causes severe PTSD and adds **`+2 Strokes`**. |

### 3. Anti-Power-Fantasy Weapon Mechanics
* **Cast-Iron Railway Crowbar (`Лом`)**: Hold `E` for `1.2s` to **Wedge (`卡门`)** deformed steel doors or electric shutters for `15.0s`, or use the curved claw to push ration tins through `12cm` bottom gaps.
* **East Street Rusty Butcher Cleaver (`Секач`)**: Heavy frontal strikes against rabid targets **100% jam in the collarbone**, requiring a `6-hit rapid press QTE` within `1.5s` to wrench free. Killing Vasily in Chapter 7 permanently unlocks **PTSD Thirst Tinnitus** (every sip of water ends with a faint *"…Пить (Thirsty)…"*).
* **Sawed-Off Double-Barrel Shotgun (`Обрез`)**: Aim spread expands with heart rate (`BPM`), and firing emits a `25m` acoustic shockwave that alerts all O.S.K. patrols on the map.

---

## III. Complete 10-Level Campaign Blueprint (Novorsk-17)

| Level ID & Name | Act / Cycle | Core Topology & Objectives | Key Moral Gate & Logbook Check |
| :--- | :--- | :--- | :--- |
| **L01. Green Light at Midnight** | Act I · Night | Apt 602 → Stairwell → Ground Unloading Bay | Discover Lana's (`0420`) transfer notice; guard 2 cups of buckwheat; witness driver Dubrov's heart attack and the 24:00 `[100% Received]` beeper chorus. |
| **L02. The Paper Dead & First Stalk** | Act I · Day+Night | Cold Storage No. 4 → Broad-Gauge Siding | **[Day]** Recruit wolfdog "Ash"; scanner reads `0 Persons` for Sergey & Maria (write real names in logbook); push lunchbox under fence. **[Night]** Witness O.S.K. execute a recovered mother; first **Choice A**. |
| **L03. The 4 PM Welded Hatch** | Act II · Day | Construction Alley → Birch Grove East Hatch | 8-minute sprint (`15:52–16:00`) with hypoallergenic formula; stop clerk pouring Lysol over Error 404; jam electric shutter at `15:59` with crowbar. |
| **L04. Underpass & Regression Report** | Act II · Day+Night | Flooded Underpass → Dispensary Back Alley | **[Day]** Co-op handcart push through black ice. **[Night]** Dr. Guliya hands over her 3-page *Clinical Regression Manuscript* & Lana's dispatch slip as inspectors breach (**Choice B: B1 / B2 / B3**). |
| **L05. Cleaver in the Collarbone** | Act II · Dusk | East Street Canteen Hall (19 Bowls) → Kitchen | Verify 19 unrecorded retirees; Vasily breaches pantry door in `40°C` delirium; **Collarbone Blade Jam QTE**; Vasily whispers *"…Пить…"* before dying. |
| **[Mid-Game Watershed]** | Act III · Open | Apt 602 → Welded Side Gate → Birch Outland | Check dialysis reserves: **Home Tethered Route** vs. **Motherless Outland Route** (carry 72-lb mother's body through pried gate). |
| **L06. Blind Fire & Prisoner 0419** | Act III · Night | Blizzard Highway → Sanatorium Basement Cage | Accidental blind-fire tragedy; rescue self-bound **Anna (`0419`)**, who confirms **Lana (`0420`)** is awake inside **Carriage No. 3** of *"Buran"*. |
| **L07. Black Market & Tar-Black Snow** | Act III · Night | Rail Black Market → Pine Manor Depot No. 2 | Encounter wounded survivor Semyon (**Choice C: C1 / C2 / C3**); infiltrate `26°C` Pine Manor with Yelena to photograph Batch-409 dialysis fluid & beef burning in the `2000°C` furnace; Old Ivan reveals the **Eagle's Crag** liquidation run. |
| **L08. The Welded Fire Exit** | Act IV · Eve | Smoke-Filled Stairwell → Welded Ground Exit | Defend Old Pavel for 90s while his oxy-acetylene torch cuts the welded I-beam across the fire door; witness Auntie Klara's fall. |
| **L09. Carriage No. 3 at Eagle's Crag** | Act IV · Night | Ural Cliff Trail → Derailed Boxcar Ravine | Enter overturned Carriage No. 3 full of waking humans; reunite with sister **Lana**; confront O.S.K. thermite liquidation squad (**Endgame Gate D: D1 / D2 / D3**). |
| **L10. The Flesh Switch & Polar Dawn** | Act V · Dawn | Hill 302 Radio Tower → Sector 1 Main Gate | *(D1 only)* 180s last stand; Old Pavel holds the 10,000V switch closed with his body; broadcast real names; branch into **Ending B**, **True Ending α**, or **True Ending β** based on the `卌` Conscience Tally. |
