extends RefCounted
## RaidSim.gd — 一夜夜潜的纯逻辑层（对应 HTML Exploration Demo 的「探索场景运行时」）。
##
## 与 Sim.gd / GymSim.gd 同一套架构：实体是 RefCounted 数据对象，手动移动 / 碰撞 / 视线 / AI，
## 渲染层 RaidView 只读取本对象并在 _draw() 里画。
## 覆盖：
##   · 90° 视野 + 1.8m 近身感知 + CPU 探索雾
##   · 潜行 / 冲刺 / 冻雪泥（速度×0.65、噪声×2）
##   · 体温与火堆回温、诊所一次性包扎
##   · 容器搜刮（1.7s 长按）、撬棍卡门 15s、建筑破门 0.8s、撤离点 1.5s
##   · 狂暴者（含 brute）/ 清杀兵巡逻与借刀杀人 / 半人（抉择 A）/ 伙伴
##   · 砍骨刀 6 连按锁骨卡刀 QTE
##   · 四个收场：extracted / dawn / downed / abort

const Data := preload("res://scripts/CampaignData.gd")
const Gen := preload("res://scripts/RaidGen.gd")

class Player extends RefCounted:
	var x: float = 0.0
	var y: float = 0.0
	var face: float = -PI / 2.0
	var hp: float = 100.0
	var stam: float = 100.0
	var warmth: float = 100.0
	var bpm: float = 70.0
	var sneak := false
	var sprint := false
	var hurt: float = 0.0
	var iframe: float = 0.0
	var drink: float = 0.0
	var alive := true

class Ent extends RefCounted:
	var kind: String = ""          # rabid | osk | half | mate
	var id: String = ""
	var x: float = 0.0
	var y: float = 0.0
	var hp: float = 100.0
	var state: String = "idle"
	var dead := false
	var tx: float = 0.0
	var ty: float = 0.0
	var wt: float = 0.0
	var home_x: float = 0.0
	var home_y: float = 0.0
	var cd: float = 0.0
	var bite: float = 0.0
	var lost: float = 0.0
	var hit_flash: float = 0.0
	# osk
	var face: float = 0.0
	var suspect: float = 0.0
	var lock: float = 0.0
	var wp: Array[Vector2] = []
	var wpi: int = 0
	# half / mate
	var used := false
	var ph: float = 0.0
	var bark: float = 0.0
	# rabid
	var brute := false

class Ripple extends RefCounted:
	var x: float = 0.0
	var y: float = 0.0
	var r: float = 0.4
	var max_r: float = 3.0
	var color: String = "#e2e8f0"
	var kind: String = ""
	var life: float = 1.0

class FloatText extends RefCounted:
	var x: float = 0.0
	var y: float = 0.0
	var zh: String = ""
	var en: String = ""
	var color: String = "#fde047"
	var life: float = 1.4

class ThrownCan extends RefCounted:
	var x: float = 0.0
	var y: float = 0.0
	var tx: float = 0.0
	var ty: float = 0.0
	var progress: float = 0.0

# ---------------- 状态 ----------------
var camp                          # CampaignSim
var loc: Dictionary = {}
var map: Dictionary = {}
var W: int = Gen.W
var H: int = Gen.H
var grid: PackedByteArray = PackedByteArray()
var rooms: Array = []
var conts: Array = []
var fires: Array[Vector2] = []
var entry: Vector2 = Vector2.ZERO

var vis: PackedByteArray = PackedByteArray()
var explored: PackedByteArray = PackedByteArray()
var poly: Array[Vector2] = []

var player: Player = Player.new()
var ents: Array[Ent] = []
var ripples: Array[Ripple] = []
var floats: Array[FloatText] = []
var decals: Array[Dictionary] = []
var thrown_cans: Array[ThrownCan] = []

var cam: Vector2 = Vector2.ZERO
var pack: Array[String] = []
var pack_max: int = Data.BAG
var load: Dictionary = {}
var weapon: Dictionary = Data.weapon("crowbar")
var ammo: int = 0

var night_left: float = 200.0
var night_max: float = 200.0
var time: float = 0.0
var tick: int = 0
var phase: String = "raid"       # raid | extracted | dawn | downed | abort
var over := false

var search_cont: int = -1
var search_prog: float = 0.0
var search_noise: float = 0.0
var wedge_tile: Vector2i = Vector2i(-1, -1)
var wedge_prog: float = 0.0
var bdoor_tile: Vector2i = Vector2i(-1, -1)
var bdoor_prog: float = 0.0
var extract_prog: float = 0.0
var wedged_timers: Dictionary = {}   # Vector2i -> 剩余秒（卡住的门 15s 后弹回）

var jam_active := false
var jam_timer: float = 0.0
var jam_hits: int = 0
var atk_phase := "idle"
var atk_timer: float = 0.0
var atk_weapon: Dictionary = {}

var choice_open := false
var choice_ent = null
var choice_result: Dictionary = {}
var choice_denied := false      # A1 失败（没带药）后不再反复弹窗，直到带齐药

var killed: int = 0
var half_saved: int = 0
var looted: int = 0
var total_cont: int = 0
var events: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var sight_range: float = Data.SIGHT
var mate_id: String = ""
var revived := false
var clinic_done := false
var cold_warned := false
var dawn_warned := false

var sfx_events: Array[String] = []

# ============================================================================
# 初始化
# ============================================================================
func _init(campaign, cfg: Dictionary) -> void:
	camp = campaign
	loc = cfg["loc"]
	mate_id = String(cfg.get("mate", ""))
	pack_max = int(cfg.get("pack_max", Data.BAG))
	weapon = cfg.get("weapon", Data.weapon("crowbar"))
	ammo = int(weapon.get("ammo", 0))
	load = cfg.get("load", {}).duplicate()
	rng.seed = int(cfg.get("seed", 1234)) * 31 + 7
	sight_range = Data.SIGHT_CRACKED if bool(cfg.get("glasses", false)) else Data.SIGHT
	night_max = float(cfg.get("night", 200.0))
	night_left = night_max
	map = Gen.generate(loc, int(cfg.get("day", 1)), float(cfg.get("left", 1.0)))
	W = int(map["W"])
	H = int(map["H"])
	grid = map["grid"]
	rooms = map["rooms"]
	conts = map["conts"]
	fires = []
	for f in map["fires"]:
		fires.append(f)
	entry = map["entry"]
	total_cont = conts.size()
	vis.resize(W * H)
	explored.resize(W * H)
	vis.fill(0)
	explored.fill(0)
	# 边界环开局即已知（城市天际线）
	for i in W:
		explored[i] = 1
		explored[(H - 1) * W + i] = 1
	for j in H:
		explored[j * W] = 1
		explored[j * W + W - 1] = 1
	player.x = entry.x
	player.y = entry.y
	cam = entry
	_spawn_entities(cfg)
	compute_vis()

func _sfx(name: String) -> void:
	sfx_events.append(name)

func drain_sfx() -> Array[String]:
	var out: Array[String] = []
	for e in sfx_events:
		out.append(e)
	sfx_events.clear()
	return out

func _tr(zh: String, en: String) -> String:
	return zh if camp != null and camp.lang == "zh" else en

func add_event(kind: String, zh: String, en: String) -> void:
	events.append({"t": kind, "zh": zh, "en": en})

func spawn_ripple(x: float, y: float, max_r: float, color: String, kind: String = "") -> void:
	var r := Ripple.new()
	r.x = x
	r.y = y
	r.max_r = max_r
	r.color = color
	r.kind = kind
	ripples.append(r)

func spawn_float(x: float, y: float, zh: String, en: String, color: String = "#fde047") -> void:
	var f := FloatText.new()
	f.x = x
	f.y = y
	f.zh = zh
	f.en = en
	f.color = color
	floats.append(f)

# ============================================================================
# 实体生成（对应 HTML startScene 的敌人 / NPC 段落）
# ============================================================================
func _spawn_entities(cfg: Dictionary) -> void:
	ents = []
	var gen_rng := RandomNumberGenerator.new()
	gen_rng.seed = int(cfg.get("seed", 1234)) * 3 + int(cfg.get("day", 1))
	var spawn_rooms: Array = []
	for i in range(1, rooms.size()):
		spawn_rooms.append(rooms[i])
	if spawn_rooms.is_empty():
		spawn_rooms = rooms
	var open_rooms: Array = []
	for r in spawn_rooms:
		if not bool(r.get("building", false)):
			open_rooms.append(r)
	if open_rooms.is_empty():
		open_rooms = spawn_rooms

	# 伙伴
	if mate_id != "":
		var m := Ent.new()
		m.kind = "mate"
		m.id = mate_id
		m.x = player.x + 1.2
		m.y = player.y + 1.2
		m.hp = 100.0
		m.state = "follow"
		ents.append(m)

	var dg := int(cfg.get("danger", 1))
	var n_rab := int(round(2.0 + float(dg) * 1.3 + gen_rng.randf() * 1.5))
	for i in n_rab:
		var r: Dictionary = spawn_rooms[gen_rng.randi_range(0, spawn_rooms.size() - 1)]
		var x := float(r["cx"]) + (gen_rng.randf() - 0.5) * maxf(2.0, float(r["w"]) * 0.6)
		var y := float(r["cy"]) + (gen_rng.randf() - 0.5) * maxf(2.0, float(r["h"]) * 0.6)
		if _dist(x, y, entry.x, entry.y) < 12.0:
			x += 12.0
			y += 12.0
		if Gen.at(grid, int(floor(x)), int(floor(y))) != Data.TT_FLOOR:
			x = float(r["cx"]) + 0.5
			y = float(r["cy"]) + 0.5
		var e := Ent.new()
		e.kind = "rabid"
		e.x = x
		e.y = y
		e.hp = 60.0
		e.tx = x
		e.ty = y
		e.home_x = x
		e.home_y = y
		e.wt = gen_rng.randf() * 3.0
		ents.append(e)
	if dg >= 2:
		var br: Dictionary = spawn_rooms[gen_rng.randi_range(0, spawn_rooms.size() - 1)]
		var be := Ent.new()
		be.kind = "rabid"
		be.brute = true
		be.x = float(br["cx"]) + 0.5
		be.y = float(br["cy"]) + 0.5
		be.hp = 150.0
		be.tx = be.x
		be.ty = be.y
		be.home_x = be.x
		be.home_y = be.y
		ents.append(be)

	var n_pairs := maxi(1 if dg >= 2 else 0, int(round(float(dg - 1) * 0.4 + gen_rng.randf() * 0.5)))
	for i in n_pairs:
		var r2: Dictionary = open_rooms[gen_rng.randi_range(0, open_rooms.size() - 1)]
		var wp: Array[Vector2] = [Vector2(float(r2["cx"]) + 0.5, float(r2["cy"]) + 0.5)]
		for k in 3:
			var rr: Dictionary = open_rooms[gen_rng.randi_range(0, open_rooms.size() - 1)]
			wp.append(Vector2(float(rr["cx"]) + 0.5, float(rr["cy"]) + 0.5))
		for j in 2:
			var s := Ent.new()
			s.kind = "osk"
			s.x = float(r2["cx"]) + 0.5 + (0.9 if j == 1 else 0.0)
			s.y = float(r2["cy"]) + 0.5
			s.face = gen_rng.randf() * TAU
			s.hp = 120.0
			s.state = "patrol"
			s.wp = wp
			s.wpi = 0
			s.tx = r2["cx"]
			s.ty = r2["cy"]
			ents.append(s)

	var n_half := (1 if gen_rng.randf() < 0.72 else 0) + (1 if gen_rng.randf() < 0.35 else 0)
	for i in n_half:
		var r3: Dictionary = open_rooms[gen_rng.randi_range(0, open_rooms.size() - 1)]
		var x3 := float(r3["cx"]) + (gen_rng.randf() - 0.5) * 3.0
		var y3 := float(r3["cy"]) + (gen_rng.randf() - 0.5) * 3.0
		if _in_building(x3, y3):
			x3 = float(r3["cx"]) + 0.5
			y3 = float(r3["cy"]) + 0.5
		if Gen.at(grid, int(floor(x3)), int(floor(y3))) != Data.TT_FLOOR:
			continue
		var h := Ent.new()
		h.kind = "half"
		h.x = x3
		h.y = y3
		h.hp = 40.0
		h.state = "crouch"
		h.ph = gen_rng.randf() * TAU
		ents.append(h)

	# 藏在建筑里的战利品：建筑内的容器类型已由生成器决定

# ============================================================================
# 查询工具
# ============================================================================
func _dist(ax: float, ay: float, bx: float, by: float) -> float:
	var dx := ax - bx
	var dy := ay - by
	return sqrt(dx * dx + dy * dy)

func at(x: int, y: int) -> int:
	return Gen.at(grid, x, y)

func _in_building(x: float, y: float) -> bool:
	for b in map.get("buildings", []):
		if x >= float(b["x"]) and x < float(b["x"]) + float(b["w"]) \
				and y >= float(b["y"]) and y < float(b["y"]) + float(b["h"]):
			return true
	return false

func room_mech_at(x: float, y: float) -> String:
	# 建筑优先（HTML 里建筑插在房间表第 2 位之后，自然后覆盖）
	var found := ""
	for r in rooms:
		if x >= float(r["x"]) and x < float(r["x"]) + float(r["w"]) \
				and y >= float(r["y"]) and y < float(r["y"]) + float(r["h"]):
			found = String(r.get("mech", ""))
			if bool(r.get("building", false)):
				return found
	return found

func los_clear(x0: float, y0: float, x1: float, y1: float,
		block_cover: bool = false) -> bool:
	var dx := x1 - x0
	var dy := y1 - y0
	var d := sqrt(dx * dx + dy * dy)
	var steps: int = maxi(1, int(ceil(d / 0.3)))
	for i in range(1, steps):
		var t := float(i) / float(steps)
		var v := at(int(floor(x0 + dx * t)), int(floor(y0 + dy * t)))
		if v == Data.TT_WALL or v == Data.TT_BDOOR or v == Data.TT_WEDGED:
			return false
		if block_cover and v == Data.TT_COVER:
			return false
	return true

func cover_hides(px: float, py: float, ex: float, ey: float) -> bool:
	var d := _dist(px, py, ex, ey)
	var steps: int = maxi(1, int(ceil(d / 0.5)))
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var x := px + (ex - px) * t
		var y := py + (ey - py) * t
		if at(int(floor(x)), int(floor(y))) == Data.TT_COVER \
				and _dist(x, y, px, py) < 1.9:
			return true
	return false

func can_stand(x: float, y: float, r: float) -> bool:
	var pts := [
		Vector2(x - r, y - r * 0.6), Vector2(x + r, y - r * 0.6),
		Vector2(x - r, y + r * 0.6), Vector2(x + r, y + r * 0.6),
		Vector2(x, y + r * 0.6), Vector2(x, y - r * 0.6),
	]
	for p in pts:
		if Gen.blocks_move(at(int(floor(p.x)), int(floor(p.y)))):
			return false
	return true

func move_ent(e, nx: float, ny: float, r: float) -> void:
	if can_stand(nx, ny, r):
		e.x = nx
		e.y = ny
		return
	if can_stand(nx, e.y, r):
		e.x = nx
		return
	if can_stand(e.x, ny, r):
		e.y = ny

func emit_noise(x: float, y: float, radius: float, color: String, kind: String) -> void:
	spawn_ripple(x, y, radius, color, kind)
	# 噪声诱使 14m 内的清杀兵转向 / 狂暴者调查
	for e in ents:
		if e.dead or e.kind != "osk":
			continue
		if kind == "self" or kind == "can" or kind == "hit":
			var d := _dist(e.x, e.y, x, y)
			if d < 16.0 and radius >= 2.0:
				e.state = "investigate"
				e.tx = x
				e.ty = y

# ============================================================================
# 交互目标
# ============================================================================
func nearest_interact() -> Dictionary:
	var p := player
	var best: Dictionary = {}
	var bd := 2.0
	for i in conts.size():
		var c: Dictionary = conts[i]
		if bool(c.get("searched", false)):
			continue
		var d := _dist(p.x, p.y, float(c["x"]), float(c["y"]))
		if d < bd:
			bd = d
			best = {"type": "cont", "index": i}
	var ti := int(floor(p.x))
	var tj := int(floor(p.y))
	for j in range(tj - 1, tj + 2):
		for i in range(ti - 1, ti + 2):
			var v := at(i, j)
			if v == Data.TT_DOOR:
				var d2 := _dist(p.x, p.y, i + 0.5, j + 0.5)
				if d2 < bd + 0.4:
					bd = d2
					best = {"type": "door", "tile": Vector2i(i, j)}
			elif v == Data.TT_BDOOR:
				var d3 := _dist(p.x, p.y, i + 0.5, j + 0.5)
				if d3 < bd + 0.4:
					bd = d3
					best = {"type": "bdoor", "tile": Vector2i(i, j)}
	for e in ents:
		if e.dead:
			continue
		if e.kind == "half" and not e.used:
			var d4 := _dist(p.x, p.y, e.x, e.y)
			if d4 < bd + 0.6:
				bd = d4
				best = {"type": "half", "ent": e}
	if _dist(p.x, p.y, entry.x, entry.y) < 1.6:
		best = {"type": "exit"}
	return best

func interact_label() -> String:
	var tgt := nearest_interact()
	match String(tgt.get("type", "")):
		"cont":
			var c: Dictionary = conts[int(tgt["index"])]
			var name: Dictionary = Data.CONTAINER_NAMES.get(String(c["type"]), {"zh": "容器", "en": "Container"})
			return ("搜刮 " if camp.lang == "zh" else "Search ") + String(name["zh" if camp.lang == "zh" else "en"])
		"door":
			return "按住 E 卡住这扇门 15s" if camp.lang == "zh" else "Hold E to wedge this door (15s)"
		"bdoor":
			return "按住 E 撬开这扇门" if camp.lang == "zh" else "Hold E to pry this door"
		"half":
			return "抉择 A · 按住 E 靠近他" if camp.lang == "zh" else "Choice A · Hold E to approach"
		"exit":
			return "按住 E 撤离" if camp.lang == "zh" else "Hold E to extract"
		_:
			return ""

# ============================================================================
# 动作
# ============================================================================
func attack() -> void:
	if over or choice_open:
		return
	if jam_active:
		jam_hits += 1
		_sfx("wedge")
		if jam_hits >= 6:
			jam_active = false
			add_event("note", "你把手从骨缝里抽出来，砍骨刀还在抖。", "You wrench the cleaver free; your hands are shaking.")
			spawn_float(player.x, player.y - 0.6, "拔刀成功 · 6/6", "Blade freed · 6/6", "#34d399")
		return
	if atk_phase != "idle":
		return
	atk_weapon = weapon
	atk_phase = "up"
	atk_timer = 0.0
	_sfx("swing")

func drink() -> void:
	var n := int(load.get("water", 0))
	if n <= 0:
		spawn_float(player.x, player.y - 0.6, "水壶空了", "The flask is empty", "#fca5a5")
		return
	load["water"] = n - 1
	player.warmth = minf(100.0, player.warmth + 22.0)
	player.hp = minf(100.0, player.hp + 6.0)
	player.drink = 1.2
	spawn_float(player.x, player.y - 0.6, "喝下热水 · 体温 +22", "Hot water · warmth +22", "#7dd3fc")
	if bool(camp.flags.get("ptsd", false)):
		spawn_float(player.x, player.y - 1.2, "……Пить（渴）……", "…Пить (Thirsty)…", "#f43f5e")

func use_bandage() -> void:
	var n := int(load.get("band", 0))
	if n <= 0:
		spawn_float(player.x, player.y - 0.6, "没有绷带", "No bandages", "#fca5a5")
		return
	load["band"] = n - 1
	player.hp = minf(100.0, player.hp + 26.0)
	spawn_float(player.x, player.y - 0.6, "包扎 · 生命 +26", "Bandaged · HP +26", "#34d399")

func reload_gun() -> void:
	if weapon.has("ammo"):
		ammo = int(weapon["ammo"])

func throw_can(target: Vector2) -> void:
	var n := int(load.get("can", 0))
	if n <= 0:
		spawn_float(player.x, player.y - 0.6, "没有空罐头", "No tins", "#fca5a5")
		return
	load["can"] = n - 1
	var c := ThrownCan.new()
	c.x = player.x
	c.y = player.y
	c.tx = clampf(target.x, 1.0, float(W - 1))
	c.ty = clampf(target.y, 1.0, float(H - 1))
	thrown_cans.append(c)
	_sfx("can")

func set_choice(choice_index: int) -> void:
	if choice_ent == null:
		return
	var e = choice_ent
	var has_med := int(load.get("asp", 0)) > 0 and int(load.get("water", 0)) > 0
	if choice_index == 0 and not has_med:
		choice_result = {"ok": false,
			"msg_zh": "你没带阿司匹林和热水。",
			"msg_en": "You brought no aspirin or water."}
		choice_denied = true
		choice_open = false
		spawn_float(e.x, e.y - 0.8, "你翻遍口袋：没有阿司匹林，也没有热水。",
			"You search your pockets: no aspirin, no hot water.", "#fca5a5")
		add_event("note", "抉择 A1 失败：没带药。他还在烧。",
			"Choice A1 failed: no medicine. He is still burning.")
		return
	e.used = true
	match choice_index:
		0:
			load["asp"] = int(load.get("asp", 0)) - 1
			load["water"] = int(load.get("water", 0)) - 1
			camp.raid_add_conscience(7.0)
			half_saved += 1
			if pack.size() < pack_max:
				pack.append("intel")
			add_event("good", "A1 喂药退烧：良知 ▲▲，得到「老轨」暗号",
				"A1 Fed & cooled him: Conscience ▲▲, got Old Ivan's signal")
			e.kind = "mate"
			e.id = "survivor"
			e.state = "follow"
			spawn_float(e.x, e.y - 0.8, "他的瞳孔回色了：「……水塔下面，找戴蓝毛线帽的老头……」",
				"His pupils clear: \"…below the water tower, the old man in the blue wool cap…\"", "#34d399")
		1:
			camp.raid_add_conscience(-2.0)
			add_event("note", "A2 绕行：你听见了身后的枪声", "A2 Bypassed: you heard the shots behind you")
			e.dead = true
			emit_noise(e.x, e.y, 9.0, "#7dd3fc", "osk")
			spawn_float(e.x, e.y - 0.8, "身后传来三声微声点射。你没有回头。",
				"Three suppressed shots behind you. You did not look back.", "#fca5a5")
		_:
			e.hp = 0.0
			e.dead = true
			camp.raid_add_tally(1, "抉择 A3：撬棍灭口", "Choice A3: crowbar kill")
			camp.raid_add_conscience(-10.0)
			camp.raid_set_flag("betrayed")
			if pack.size() < pack_max:
				pack.append("can")
			if pack.size() < pack_max:
				pack.append("scrap")
			add_event("bad", "A3 撬棍灭口：卌 +1", "A3 Crowbar kill: 卌 +1")
			emit_noise(e.x, e.y, 6.0, "#ef4444", "hit")
			spawn_float(e.x, e.y - 0.8, "你在日志背面划下一道血痕。",
				"You carve a stroke on the back page.", "#f43f5e")
	choice_open = false
	choice_ent = null

func request_abort() -> void:
	finish("abort")

func finish(reason: String) -> void:
	if over:
		return
	over = true
	phase = reason
	_sfx("extract" if reason == "extracted" else "bad")

# ============================================================================
# 主更新（对应 HTML update）
# ============================================================================
func update(dt: float, move: Vector2, crouch: bool, sprint_held: bool,
		mouse_world: Vector2, hold_e: bool) -> void:
	if over or choice_open:
		return
	dt = clampf(dt, 0.0, 0.05)
	time += dt
	tick += 1
	var p := player

	# ---------------- 瞄准 ----------------
	p.face = atan2(mouse_world.y - p.y, mouse_world.x - p.x)

	# ---------------- 移动 ----------------
	p.sneak = crouch
	p.sprint = sprint_held and not crouch and p.stam > 2.0 and move.length() > 0.1
	var on_slush := at(int(floor(p.x)), int(floor(p.y))) == Data.TT_SLUSH
	var sp := Data.SPEED_SNEAK if p.sneak else (Data.SPEED_SPRINT if p.sprint else Data.SPEED_WALK)
	if jam_active:
		sp = 0.0
	if on_slush:
		sp *= 0.65
	if move.length() > 0.1 and sp > 0.0:
		var n := move.normalized()
		var ox := p.x
		var oy := p.y
		move_ent(p, p.x + n.x * sp * dt, p.y + n.y * sp * dt, 0.35)
		var moved := _dist(ox, oy, p.x, p.y)
		_noise_acc += moved
		var base := Data.NOISE_SNEAK if p.sneak else (Data.NOISE_SPRINT if p.sprint else Data.NOISE_WALK)
		var thresh := 0.9 if p.sneak else 1.4
		if _noise_acc > thresh:
			_noise_acc = 0.0
			emit_noise(p.x, p.y, base * (2.0 if on_slush else 1.0), "#e2e8f0", "self")
	if p.sprint:
		p.stam = clampf(p.stam - 18.0 * dt, 0.0, 100.0)
	else:
		p.stam = clampf(p.stam + 9.0 * dt, 0.0, 100.0)
	if p.drink > 0.0:
		p.drink -= dt
	if p.iframe > 0.0:
		p.iframe -= dt
	if p.hurt > 0.0:
		p.hurt -= dt

	# ---------------- 体温 ----------------
	var near_fire := false
	for f in fires:
		if _dist(f.x, f.y, p.x, p.y) < 2.6:
			near_fire = true
			break
	var coldness := float(loc.get("cold", 1.0)) * 0.55
	if on_slush:
		coldness *= 1.5
	if p.sneak:
		coldness *= 0.85
	if room_mech_at(p.x, p.y) == "freezer":
		coldness *= 1.6
	if near_fire:
		p.warmth = clampf(p.warmth + 30.0 * dt, 0.0, 100.0)
	else:
		p.warmth = clampf(p.warmth - coldness * dt, 0.0, 100.0)
	if p.warmth < 25.0:
		p.hp -= (25.0 - p.warmth) * 0.09 * dt
	if p.warmth < 30.0 and not cold_warned:
		cold_warned = true
		spawn_float(p.x, p.y - 0.8, "手指开始不听使唤——按 Q 喝热水，或去火堆旁站一会儿。",
			"Your fingers are going numb — press Q for hot water, or stand by a fire.", "#7dd3fc")
	if p.warmth > 45.0:
		cold_warned = false
	if room_mech_at(p.x, p.y) == "clinic" and not clinic_done:
		clinic_done = true
		p.hp = clampf(p.hp + 25.0, 0.0, 100.0)
		spawn_float(p.x, p.y - 0.6, "诊所残存的器械还能用：包扎了一下，生命 +25。",
			"The clinic still has supplies: +25 HP.", "#34d399")

	# ---------------- 心率 ----------------
	var fear := 0.0
	for e in ents:
		if not e.dead and (e.kind == "rabid" or e.kind == "osk"):
			fear = maxf(fear, clampf(1.0 - _dist(e.x, e.y, p.x, p.y) / 10.0, 0.0, 1.0))
	var target_bpm := 70.0 + (34.0 if p.sprint else 0.0) + (22.0 if p.hp < 45.0 else 0.0) \
		+ fear * 26.0 + (12.0 if p.warmth < 35.0 else 0.0)
	p.bpm = lerpf(p.bpm, target_bpm, 1.0 - pow(0.02, dt))

	# ---------------- 攻击时序 ----------------
	if atk_phase != "idle":
		atk_timer += dt
		match atk_phase:
			"up":
				if atk_timer >= float(atk_weapon.get("up", 0.2)):
					atk_phase = "act"
					atk_timer = 0.0
					_resolve_swing()
			"act":
				if atk_timer >= float(atk_weapon.get("act", 0.1)):
					atk_phase = "rec"
					atk_timer = 0.0
			"rec":
				if atk_timer >= float(atk_weapon.get("rec", 0.3)):
					atk_phase = "idle"
					atk_timer = 0.0

	if jam_active:
		jam_timer -= dt
		if jam_timer <= 0.0:
			jam_active = false
			p.hp -= 22.0
			p.hurt = 0.4
			spawn_float(p.x, p.y - 0.8, "来不及了——你被带倒在地。", "Too slow — you are dragged down.", "#fca5a5")

	# ---------------- 按住 E ----------------
	if hold_e and not jam_active:
		_handle_hold_e(dt, p)
	else:
		search_cont = -1
		search_prog = 0.0
		wedge_prog = 0.0
		bdoor_prog = 0.0
		extract_prog = 0.0

	# ---------------- 实体 AI ----------------
	for e in ents:
		if e.dead:
			continue
		e.cd -= dt
		if e.hit_flash > 0.0:
			e.hit_flash -= dt
		match e.kind:
			"rabid":
				_update_rabid(e, dt, p)
			"osk":
				_update_osk(e, dt, p)
			"half":
				e.ph += dt
				if rng.randf() < dt * 0.45:
					emit_noise(e.x, e.y, 4.2, "#cbd5e1", "half")
			"mate":
				_update_mate(e, dt, p)

	# ---------------- 卡住的门 15 秒后弹回 ----------------
	for tile in wedged_timers.keys():
		wedged_timers[tile] = float(wedged_timers[tile]) - dt
		if float(wedged_timers[tile]) <= 0.0:
			if at(tile.x, tile.y) == Data.TT_WEDGED:
				Gen.set_tile(grid, tile.x, tile.y, Data.TT_DOOR)
			wedged_timers.erase(tile)

	# ---------------- 波纹 / 浮字 / 飞罐 ----------------
	for i in range(ripples.size() - 1, -1, -1):
		var r := ripples[i]
		r.r += maxf(2.2, r.max_r * 0.55) * dt
		r.life -= dt / 1.5
		if r.life <= 0.0 or r.r >= r.max_r * 1.05:
			ripples.remove_at(i)
	for i in range(floats.size() - 1, -1, -1):
		var f := floats[i]
		f.y -= 0.4 * dt
		f.life -= dt
		if f.life <= 0.0:
			floats.remove_at(i)
	for i in range(thrown_cans.size() - 1, -1, -1):
		var c := thrown_cans[i]
		c.progress += dt / 0.55
		if c.progress >= 1.0:
			emit_noise(c.tx, c.ty, Data.NOISE_CAN, "#f59e0b", "can")
			spawn_float(c.tx, c.ty - 0.4, "哐当！", "CLANG!", "#fbbf24")
			_sfx("can")
			thrown_cans.remove_at(i)

	# ---------------- 相机 ----------------
	cam.x = lerpf(cam.x, p.x, 1.0 - pow(0.0015, dt))
	cam.y = lerpf(cam.y, p.y, 1.0 - pow(0.0015, dt))

	# ---------------- 夜计时 ----------------
	night_left -= dt
	if night_left / night_max < 0.22 and not dawn_warned:
		dawn_warned = true
		spawn_float(p.x, p.y - 1.0, "东边开始发白了——天亮前必须回到撤离点。",
			"The east is going grey — get back to the extraction point before dawn.", "#7dd3fc")
	if night_left <= 0.0:
		finish("dawn")
		return

	# ---------------- 死亡 ----------------
	if p.hp <= 0.0:
		if mate_id == "gulya" and not revived:
			revived = true
			p.hp = 40.0
			spawn_float(p.x, p.y - 0.8, "古丽娅把你从雪里拖起来：一次，仅此一次。",
				"Gulya drags you out of the snow: once, and only once.", "#34d399")
		else:
			finish("downed")
			return

	# ---------------- 分离 ----------------
	for e in ents:
		if e.dead or (e.kind != "rabid" and e.kind != "osk"):
			continue
		_sep(p, e, 0.75)
	var hostiles: Array = []
	for e in ents:
		if not e.dead and (e.kind == "rabid" or e.kind == "osk"):
			hostiles.append(e)
	for a in range(hostiles.size()):
		for b in range(a + 1, hostiles.size()):
			_sep(hostiles[a], hostiles[b], 0.7)

	compute_vis()

var _noise_acc := 0.0

func _sep(a, b, min_d: float) -> void:
	var d := _dist(a.x, a.y, b.x, b.y)
	if d >= min_d:
		return
	var ux: float = 1.0 if d < 0.001 else float((b.x - a.x) / d)
	var uy: float = 0.0 if d < 0.001 else float((b.y - a.y) / d)
	var push := (min_d - d) * 0.5
	move_ent(a, a.x - ux * push, a.y - uy * push, 0.35)
	move_ent(b, b.x + ux * push, b.y + uy * push, 0.32)

func _resolve_swing() -> void:
	var p := player
	var w := atk_weapon
	_sfx("hit")
	for e in ents:
		if e.dead or e.kind == "mate":
			continue
		var d := _dist(p.x, p.y, e.x, e.y)
		if d > float(w.get("range", 1.0)) + 0.4:
			continue
		var ang := atan2(e.y - p.y, e.x - p.x)
		var half_arc := float(w.get("arc", 60.0)) * PI / 360.0 + atan2(0.5, maxf(d, 0.2))
		if absf(wrapf(ang - p.face, -PI, PI)) > half_arc:
			continue
		# 建筑破门挡住
		if _swing_blocked(p.x, p.y, e.x, e.y):
			continue
		if String(w.get("id", "")) == "cleaver" and e.kind == "rabid" and not jam_active \
				and absf(wrapf(ang - p.face, -PI, PI)) < 0.7:
			jam_active = true
			jam_timer = 1.5
			jam_hits = 0
			e.hp -= 8.0
			e.hit_flash = 0.22
			spawn_float(p.x, p.y - 0.9, "刀卡进锁骨缝了！1.5 秒内连按 6 次！",
				"The blade jams! Mash 6 times in 1.5s!", "#f43f5e")
			_sfx("jam")
		else:
			_damage_ent(e, float(w.get("dmg", 8.0)))
	# 枪械：消耗弹药 + 巨大声响
	if String(w.get("id", "")) == "shotgun" or String(w.get("id", "")) == "mosin":
		emit_noise(p.x, p.y, Data.NOISE_GUN, "#f59e0b", "gun")
		ammo -= 1

func _swing_blocked(x0: float, y0: float, x1: float, y1: float) -> bool:
	var d := _dist(x0, y0, x1, y1)
	var steps: int = maxi(1, int(ceil(d / 0.4)))
	for k in range(1, steps):
		var t := float(k) / float(steps)
		if at(int(floor(x0 + (x1 - x0) * t)), int(floor(y0 + (y1 - y0) * t))) == Data.TT_BDOOR:
			return true
	return false

func _damage_ent(e, dmg: float) -> void:
	e.hp -= dmg
	e.hit_flash = 0.18
	spawn_float(e.x, e.y - 0.7, "-%d" % int(dmg), "-%d" % int(dmg), "#fca5a5")
	if e.hp <= 0.0:
		e.dead = true
		decals.append({"x": e.x, "y": e.y, "c": "#991b1b"})
		if decals.size() > 40:
			decals.pop_front()
		if e.kind == "rabid":
			killed += 1
			add_event("kill", "击杀狂暴者 ×1", "Killed a rabid ×1")

func _handle_hold_e(dt: float, p) -> void:
	var tgt := nearest_interact()
	var t := String(tgt.get("type", ""))
	# 搜刮
	if t == "cont":
		var idx := int(tgt["index"])
		if search_cont != idx:
			search_cont = idx
			search_prog = 0.0
			search_noise = 0.0
		search_prog += dt / 1.7
		search_noise += dt
		if search_noise > 0.7:
			search_noise = 0.0
			emit_noise(p.x, p.y, Data.NOISE_SEARCH, "#e2e8f0", "self")
		if search_prog >= 1.0:
			_finish_search(idx)
			search_cont = -1
			search_prog = 0.0
	else:
		search_cont = -1
		search_prog = 0.0

	# 卡门
	if t == "door":
		var tile: Vector2i = tgt["tile"]
		if wedge_tile != tile:
			wedge_tile = tile
			wedge_prog = 0.0
		wedge_prog += dt / 1.2
		if wedge_prog >= 1.0:
			Gen.set_tile(grid, tile.x, tile.y, Data.TT_WEDGED)
			wedged_timers[tile] = 15.0
			wedge_prog = 0.0
			_sfx("wedge")
			emit_noise(p.x, p.y, 3.5, "#e2e8f0", "self")
			spawn_float(p.x, p.y - 0.7, "撬棍卡进门轨：这扇门 15 秒内推不开。",
				"Crowbar wedged: 15 seconds of lock.", "#fbbf24")
	else:
		wedge_prog = 0.0

	# 破门
	if t == "bdoor":
		var tile2: Vector2i = tgt["tile"]
		if bdoor_tile != tile2:
			bdoor_tile = tile2
			bdoor_prog = 0.0
		var speed := 0.4 if mate_id == "pavel" else 0.8
		bdoor_prog += dt / speed
		if bdoor_prog >= 1.0:
			Gen.set_tile(grid, tile2.x, tile2.y, Data.TT_DOOR)
			bdoor_prog = 0.0
			_sfx("wedge")
			emit_noise(p.x, p.y, 3.0, "#e2e8f0", "self")
			spawn_float(p.x, p.y - 0.7, "门开了——里面什么动静都没有。",
				"The door creaks open. Nothing stirs inside.", "#fbbf24")
	else:
		bdoor_prog = 0.0

	# 撤离
	if t == "exit":
		extract_prog += dt / 1.5
		if extract_prog >= 1.0:
			_sfx("extract")
			finish("extracted")
			return
	else:
		extract_prog = 0.0

	# 抉择 A
	if t == "half":
		var e = tgt["ent"]
		var meds_ready: bool = int(load.get("asp", 0)) > 0 and int(load.get("water", 0)) > 0
		if meds_ready:
			choice_denied = false
		if not e.used and not choice_denied:
			choice_open = true
			choice_ent = e

func _finish_search(idx: int) -> void:
	var c: Dictionary = conts[idx]
	c["searched"] = true
	looted += 1
	var med_bonus := mate_id == "gulya"
	var items := Gen.gen_loot(loc, c, rng, med_bonus)
	var got: Array[String] = []
	var full := false
	for id in items:
		if pack.size() >= pack_max:
			full = true
			continue
		pack.append(id)
		got.append(id)
	_sfx("good")
	if full:
		spawn_float(player.x, player.y - 1.0, "背包满了，有东西只能留在原地。",
			"Pack is full; you left something behind.", "#fbbf24")
	if got.is_empty():
		add_event("note", "空的。只有冻硬的包装纸。", "Empty. Only frozen wrapping paper.")
	else:
		var names: Array[String] = []
		for id in got:
			names.append(camp.item_name(id))
		add_event("good", "搜出：" + "、".join(names), "Found: " + ", ".join(names))
		spawn_float(c["x"], float(c["y"]) - 0.6, "搜出：" + "、".join(names),
			"Found: " + ", ".join(names), "#fbbf24")
	# 容器余量刷新
	var st: Dictionary = camp.node_state(String(loc["id"]))
	st["left"] = maxf(0.0, float(st["left"]) - 1.0 / maxf(1.0, float(total_cont)))

# ============================================================================
# AI
# ============================================================================
func _update_rabid(e, dt: float, p) -> void:
	var d := _dist(e.x, e.y, p.x, p.y)
	var sees: bool = d < 8.5 and los_clear(e.x, e.y, p.x, p.y) and not cover_hides(p.x, p.y, e.x, e.y)
	e.wt -= dt
	match e.state:
		"idle":
			if sees:
				e.state = "chase"
			elif e.wt <= 0.0:
				e.wt = 1.6 + rng.randf() * 2.8
				e.tx = e.home_x + (rng.randf() - 0.5) * 6.0
				e.ty = e.home_y + (rng.randf() - 0.5) * 6.0
				e.state = "investigate"
		"investigate":
			var a := atan2(e.ty - e.y, e.tx - e.x)
			move_ent(e, e.x + cos(a) * 1.5 * dt, e.y + sin(a) * 1.5 * dt, 0.32)
			if _dist(e.x, e.y, e.tx, e.ty) < 0.6 or e.wt < -8.0:
				e.state = "idle"
				e.wt = 1.0 + rng.randf() * 3.0
			if sees:
				e.state = "chase"
		"chase":
			var sp := 3.3 * (0.7 if e.brute else 1.0)
			var a2 := atan2(p.y - e.y, p.x - e.x)
			move_ent(e, e.x + cos(a2) * sp * dt, e.y + sin(a2) * sp * dt, 0.32)
			if d < 1.15:
				e.bite = minf(e.bite + dt, 0.45)
				if e.bite >= 0.45 and e.cd <= 0.0 and p.iframe <= 0.0:
					e.cd = 1.7
					e.bite = 0.0
					p.hp -= 15.0 if e.brute else 8.0
					p.iframe = 0.75
					p.hurt = 0.35
					p.bpm += 18.0
					_sfx("hit")
					emit_noise(p.x, p.y, 6.0, "#ef4444", "hit")
					if rng.randf() < 0.30 and not bool(camp.flags.get("glasses", false)):
						camp.raid_set_flag("glasses")
						sight_range = Data.SIGHT_CRACKED
						spawn_float(p.x, p.y - 0.9, "镜片裂了：视距 12m → 7.2m，边缘重影。",
							"Lens cracked: sight 12m → 7.2m, ghosting at the edges.", "#7dd3fc")
			else:
				e.bite = 0.0
			if not sees:
				e.lost += dt
				if e.lost > 5.0 or d > 13.0:
					e.state = "idle"
					e.lost = 0.0
			else:
				e.lost = 0.0
	if rng.randf() < dt * 0.5:
		emit_noise(e.x, e.y, 3.2, "#ef4444", "rabid")

func _update_osk(e, dt: float, p) -> void:
	var ang := atan2(p.y - e.y, p.x - e.x)
	var in_cone := absf(wrapf(e.face - ang, -PI, PI)) < 22.5 * PI / 180.0
	var clear := los_clear(e.x, e.y, p.x, p.y)
	var hidden: bool = bool(p.sneak) and bool(cover_hides(p.x, p.y, e.x, e.y))
	var d := _dist(e.x, e.y, p.x, p.y)
	if in_cone and d < 14.0 and clear and not hidden:
		e.suspect = clampf(e.suspect + dt * 2.4, 0.0, 2.0)
	else:
		e.suspect = clampf(e.suspect - dt * 0.8, 0.0, 2.0)

	# 借刀杀人：光锥里的狂暴者 / 半人
	var npc_in_cone := false
	for o in ents:
		if o.dead or o == e:
			continue
		if o.kind != "rabid" and o.kind != "half":
			continue
		var d2 := _dist(e.x, e.y, o.x, o.y)
		var a2 := atan2(o.y - e.y, o.x - e.x)
		if d2 < 14.0 and absf(wrapf(e.face - a2, -PI, PI)) < 22.5 * PI / 180.0 \
				and los_clear(e.x, e.y, o.x, o.y):
			npc_in_cone = true
			if e.bite > 0.5 and e.cd <= 0.0 and not o.dead:
				e.cd = 0.9
				e.bite = 0.0
				o.hp = 0.0
				o.dead = true
				decals.append({"x": o.x, "y": o.y, "c": "#991b1b"})
				emit_noise(e.x, e.y, 9.0, "#7dd3fc", "osk")
				if o.kind == "rabid":
					killed += 1
					add_event("knife", "借刀杀人：清杀队替你清掉 1 只狂暴者",
						"Borrowed knife: O.S.K. dropped 1 rabid for you")
				else:
					add_event("witness", "你看着清杀队射杀了那个正在退烧的人。",
						"You watched the purge squad gun down a recovering person.")
					camp.raid_add_conscience(-3.0)
	e.bite = clampf(e.bite + (dt if npc_in_cone else -dt), 0.0, 1.0)

	if e.suspect >= 1.0 and d < 14.0 and clear and not hidden:
		e.lock += dt
	elif d >= 14.0 or not in_cone:
		e.lock = maxf(0.0, e.lock - dt)
	if e.lock >= 1.0 and e.cd <= 0.0:
		e.cd = 0.95
		e.lock = 0.0
		var acc := clampf(1.0 - d / 14.0, 0.25, 1.0) * 0.75
		if rng.randf() < acc and p.iframe <= 0.0:
			p.hp -= 18.0
			p.iframe = 0.6
			p.hurt = 0.4
		_sfx("akm")
		emit_noise(e.x, e.y, 10.0, "#7dd3fc", "osk")
		spawn_float(p.x, p.y - 0.9, "红外锁定——AKM 微声点射！",
			"IR lock — suppressed AKM burst!", "#fca5a5")

	# 移动
	var tx: float = float(e.x)
	var ty: float = float(e.y)
	if e.suspect >= 1.2:
		tx = p.x
		ty = p.y
	elif e.state == "investigate":
		tx = e.tx
		ty = e.ty
		if _dist(e.x, e.y, tx, ty) < 1.0:
			e.state = "patrol"
			e.wpi = (e.wpi + 1) % maxi(1, e.wp.size())
	else:
		if e.wp.size() > 0:
			var wpt: Vector2 = e.wp[e.wpi % e.wp.size()]
			tx = wpt.x
			ty = wpt.y
			if _dist(e.x, e.y, tx, ty) < 1.0:
				e.wpi = (e.wpi + 1) % maxi(1, e.wp.size())
	var sp := 3.0 if e.suspect >= 1.2 else 1.7
	var a3 := atan2(ty - e.y, tx - e.x)
	move_ent(e, e.x + cos(a3) * sp * dt, e.y + sin(a3) * sp * dt, 0.35)
	e.face = lerpf(e.face, a3, 1.0 - pow(0.001, dt))
	e.face += sin(time / 0.9) * 0.012
	if rng.randf() < dt * 1.4:
		emit_noise(e.x, e.y, 5.5, "#7dd3fc", "osk")

func _update_mate(e, dt: float, p) -> void:
	var tx: float = float(p.x) - cos(float(p.face)) * 1.4
	var ty: float = float(p.y) - sin(float(p.face)) * 1.4
	var dd := _dist(e.x, e.y, tx, ty)
	if dd > 0.6:
		var a := atan2(ty - e.y, tx - e.x)
		var sp := minf(4.2, dd * 3.0)
		move_ent(e, e.x + cos(a) * sp * dt, e.y + sin(a) * sp * dt, 0.2)
	e.bark = maxf(0.0, e.bark - dt)
	if e.id == "ash" and e.bark <= 0.0:
		for o in ents:
			if not o.dead and o.kind == "rabid" and _dist(o.x, o.y, e.x, e.y) < 7.0:
				e.bark = 2.6
				emit_noise(e.x, e.y, 3.0, "#fde68a", "ash")
				spawn_float(e.x, e.y - 0.6, "灰烬炸毛狂吠！", "Ash bristles and barks!", "#fde68a")
				break

# ============================================================================
# 视野
# ============================================================================
func tile_visible_at(wx: float, wy: float) -> bool:
	var p := player
	var d := _dist(wx, wy, p.x, p.y)
	if d > sight_range:
		return false
	if d <= Data.NEAR_SENSE:
		return true
	if absf(int(floor(wx)) - int(floor(p.x))) <= 2 and absf(int(floor(wy)) - int(floor(p.y))) <= 2:
		return los_clear(p.x, p.y, wx, wy)
	var a := atan2(wy - p.y, wx - p.x)
	if absf(wrapf(a - p.face, -PI, PI)) > Data.FOV_DEG * PI / 360.0:
		return false
	return los_clear(p.x, p.y, wx, wy)

func compute_vis() -> void:
	vis.fill(0)
	var p := player
	var i0 := maxi(0, int(floor(p.x - sight_range - 1)))
	var i1 := mini(W - 1, int(ceil(p.x + sight_range + 1)))
	var j0 := maxi(0, int(floor(p.y - sight_range - 1)))
	var j1 := mini(H - 1, int(ceil(p.y + sight_range + 1)))
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			if tile_visible_at(i + 0.5, j + 0.5):
				vis[j * W + i] = 1
				explored[j * W + i] = 1
	# 视野多边形（用于绘制亮区）
	poly.clear()
	poly.append(Vector2(p.x, p.y))
	var n := 54
	var half := Data.FOV_DEG * PI / 360.0
	var step := 0.35
	for k in range(0, n + 1):
		var a := p.face - half + 2.0 * half * (float(k) / float(n))
		var d := 0.0
		while d < sight_range:
			var nx := p.x + cos(a) * d
			var ny := p.y + sin(a) * d
			if Gen.blocks_sight(at(int(floor(nx)), int(floor(ny)))) and d > 0.2:
				break
			d += step
		poly.append(Vector2(p.x + cos(a) * d, p.y + sin(a) * d))

# ============================================================================
# 摘要（结算 / HUD）
# ============================================================================
func clock_text() -> String:
	var total := Data.NIGHT_FROM + (1.0 - night_left / maxf(1.0, night_max)) * (Data.NIGHT_TO - Data.NIGHT_FROM + 24 * 60)
	var h := int(floor(total / 60.0)) % 24
	var m := int(floor(fmod(total, 60.0)))
	return "%02d:%02d" % [h, m]

func pack_summary() -> Array[String]:
	var out: Array[String] = []
	for id in pack:
		out.append(String(id))
	return out

func objective_hint() -> String:
	if camp == null:
		return ""
	var left := int(ceil(night_left))
	if extract_prog > 0.0:
		return "撤离中…" if camp.lang == "zh" else "Extracting…"
	if search_prog > 0.0:
		return "搜刮中…" if camp.lang == "zh" else "Searching…"
	if wedge_prog > 0.0:
		return "卡门中…" if camp.lang == "zh" else "Wedging…"
	if bdoor_prog > 0.0:
		return "撬门中…" if camp.lang == "zh" else "Prying…"
	if jam_active:
		return "锁骨卡刀！连按 6 次！" if camp.lang == "zh" else "BLADE JAM! Mash 6×!"
	if left < 30:
		return "快到天亮了：%ds" % left if camp.lang == "zh" else "Dawn in %ds" % left
	return interact_label()
