extends RefCounted
## RaidGen.gd — 夜潜关卡的“先画街区草图、再长格子”程序化生成。
##
## 1:1 对应 Year_of_Z_Iron_Winter_Exploration_Demo.html 的 genMap / ensureConnected / genLoot：
##   · 64 × 48 网格，1 格 = 1 逻辑米
##   · 先切主横街 / 主竖街 / 支路，街道之间剩下“扇区”，扇区里再长实心楼与可进建筑
##   · 环境：冻雪泥 / 掩体 / 铁丝网 / 门（窄口 30%）
##   · 容器数量 = (8 + 危险度×3) × 随机(0.85~1.25) × 节点余量
##   · 后处理 ensureConnected：洪水填充找孤岛 → L 形走廊接回入口 → 封死残余死区并剔除容器
##
## 所有随机数走显式 seed（节点 seed + 天数×7），因此同一夜同一节点的地图可复现。

const Data := preload("res://scripts/CampaignData.gd")

const W := 64
const H := 48

const MECH_POOL := ["storage", "freezer", "dark", "kitchen", "clinic", "patrol", "workshop", ""]
const CONTAINER_TYPES := ["crate", "locker", "medcab", "briefcase", "safe", "hidden",
	"car", "dumpster", "supply"]

# ============================================================================
# 入口
# ============================================================================
static func generate(L: Dictionary, day: int, left: float, seed_offset: int = 0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(L.get("seed", 1101)) + day * 7 + seed_offset
	var grid := PackedByteArray()
	grid.resize(W * H)
	grid.fill(Data.TT_WALL)

	# ---------------- 1. 街道网 ----------------
	var street_rects: Array[Rect2] = []
	var h_bands: Array[Vector2i] = []   # (y0, y1) 闭区间
	var v_bands: Array[Vector2i] = []

	var h_main := 10 + rng.randi_range(0, H - 20)
	var h_th := 4 + rng.randi_range(0, 1)
	var v_main := 10 + rng.randi_range(0, W - 20)
	var v_th := 4 + rng.randi_range(0, 1)
	_carve_h(grid, street_rects, h_main, h_th, 2, W - 3)
	_carve_v(grid, street_rects, v_main, v_th, 2, H - 3)
	h_bands.append(Vector2i(h_main, h_main + h_th - 1))
	v_bands.append(Vector2i(v_main, v_main + v_th - 1))

	var branches := 1 + rng.randi_range(0, 1)
	for k in branches:
		if rng.randf() < 0.5:
			var y := 6 + rng.randi_range(0, H - 15)
			var th := 3
			if not _clear_of(h_bands, y, y + th - 1, 4):
				continue
			_carve_h(grid, street_rects, y, th, 2, W - 3)
			h_bands.append(Vector2i(y, y + th - 1))
		else:
			var x := 6 + rng.randi_range(0, W - 15)
			var th2 := 3
			if not _clear_of(v_bands, x, x + th2 - 1, 4):
				continue
			_carve_v(grid, street_rects, x, th2, 2, H - 3)
			v_bands.append(Vector2i(x, x + th2 - 1))
	h_bands.sort_custom(func(a, b): return a.x < b.x)
	v_bands.sort_custom(func(a, b): return a.x < b.x)

	# ---------------- 2. 扇区（街道带之间的空地） ----------------
	var x_gaps := _gaps(v_bands, 2, W - 3, 4)
	var y_gaps := _gaps(h_bands, 2, H - 3, 4)
	var sectors: Array[Rect2i] = []
	for yg in y_gaps:
		for xg in x_gaps:
			sectors.append(Rect2i(xg.x, yg.x, xg.y - xg.x + 1, yg.y - yg.x + 1))

	var rooms: Array[Dictionary] = []
	var buildings: Array[Dictionary] = []     # {x,y,w,h,cx,cy,door:Vector2i}
	for si in sectors.size():
		var s: Rect2i = sectors[si]
		for j in range(s.position.y, s.position.y + s.size.y):
			for i in range(s.position.x, s.position.x + s.size.x):
				set_tile(grid, i, j, Data.TT_FLOOR)
		var blocks: Array[Rect2i] = []

		# 可进建筑：出生扇区之外、够大、70% 概率，最多 3 栋
		if si > 0 and buildings.size() < 3 and s.size.x >= 7 and s.size.y >= 6 and rng.randf() < 0.7:
			for attempt in 40:
				var iw := 5 + rng.randi_range(0, 2)
				var ih := 4 + rng.randi_range(0, 1)
				if iw + 2 > s.size.x or ih + 2 > s.size.y:
					continue
				var ix := s.position.x + 1 + rng.randi_range(0, maxi(0, s.size.x - 2 - iw))
				var iy := s.position.y + 1 + rng.randi_range(0, maxi(0, s.size.y - 2 - ih))
				var walls := _rect_blob(ix - 1, iy - 1, iw + 2, ih + 2)
				for t in walls:
					set_tile(grid, t.x, t.y, Data.TT_WALL)
				var spots: Array[Vector2i] = []
				for i in range(ix, ix + iw):
					if _on_street(street_rects, i, iy - 2):
						spots.append(Vector2i(i, iy - 1))
					if _on_street(street_rects, i, iy + ih + 1):
						spots.append(Vector2i(i, iy + ih))
				for j in range(iy, iy + ih):
					if _on_street(street_rects, ix - 2, j):
						spots.append(Vector2i(ix - 1, j))
					if _on_street(street_rects, ix + iw + 1, j):
						spots.append(Vector2i(ix + iw, j))
				if spots.is_empty():
					for t in walls:
						set_tile(grid, t.x, t.y, Data.TT_FLOOR)
					continue
				var door: Vector2i = spots[rng.randi_range(0, spots.size() - 1)]
				set_tile(grid, door.x, door.y, Data.TT_BDOOR)
				var b := {
					"x": ix, "y": iy, "w": iw, "h": ih,
					"cx": ix + iw / 2, "cy": iy + ih / 2,
					"door": door, "building": true, "mech": "",
				}
				if not _sector_connected(grid, s, buildings):
					for t in walls:
						set_tile(grid, t.x, t.y, Data.TT_FLOOR)
					continue
				buildings.append(b)
				blocks.append(Rect2i(ix - 1, iy - 1, iw + 2, ih + 2))
				break

		# 实心楼：1-2 栋
		var n_block := 2 if (s.size.x >= 14 and s.size.y >= 12) else 1
		for nb in n_block:
			for attempt in 30:
				var bw := 5 + rng.randi_range(0, 4)
				var bh := 4 + rng.randi_range(0, 2)
				if bw > s.size.x - 2 or bh > s.size.y - 2:
					continue
				var bx := s.position.x + 1 + rng.randi_range(0, maxi(0, s.size.x - 2 - bw))
				var by := s.position.y + 1 + rng.randi_range(0, maxi(0, s.size.y - 2 - bh))
				var overlaps := false
				for o in blocks:
					if bx < o.position.x + o.size.x + 1 and bx + bw + 1 > o.position.x \
							and by < o.position.y + o.size.y + 1 and by + bh + 1 > o.position.y:
						overlaps = true
				if overlaps:
					continue
				var cells := _rect_blob(bx, by, bw, bh)
				for t in cells:
					set_tile(grid, t.x, t.y, Data.TT_WALL)
				if not _sector_connected(grid, s, buildings):
					for t in cells:
						set_tile(grid, t.x, t.y, Data.TT_FLOOR)
					continue
				blocks.append(Rect2i(bx, by, bw, bh))
				break

		# 扇区中心：从中心螺旋找一块干净空地
		var cc := Vector2i(s.position.x + s.size.x / 2, s.position.y + s.size.y / 2)
		if at(grid, cc.x, cc.y) != Data.TT_FLOOR or _in_any_building(buildings, cc.x, cc.y):
			var found := false
			var max_rad := maxi(s.size.x, s.size.y)
			for rad in range(1, max_rad + 1):
				if found:
					break
				for j in range(cc.y - rad, cc.y + rad + 1):
					if found:
						break
					for i in range(cc.x - rad, cc.x + rad + 1):
						if i < s.position.x or i >= s.position.x + s.size.x:
							continue
						if j < s.position.y or j >= s.position.y + s.size.y:
							continue
						if at(grid, i, j) != Data.TT_FLOOR:
							continue
						if _in_any_building(buildings, i, j):
							continue
						cc = Vector2i(i, j)
						found = true
						break
		var mech: String = MECH_POOL[rng.randi_range(0, MECH_POOL.size() - 1)]
		rooms.append({
			"x": s.position.x, "y": s.position.y, "w": s.size.x, "h": s.size.y,
			"cx": cc.x, "cy": cc.y, "mech": mech, "building": false,
		})

	# 建筑插到出生房之后（房间里先认到楼）
	for b in buildings:
		rooms.insert(1, b)

	# ---------------- 3. 环境：雪泥 / 掩体 / 铁丝网 / 门 ----------------
	var door_approach := {}
	for b in buildings:
		var d: Vector2i = b["door"]
		var approach := d
		if d.y == int(b["y"]) - 1:
			approach = Vector2i(d.x, d.y - 1)
		elif d.y == int(b["y"]) + int(b["h"]):
			approach = Vector2i(d.x, d.y + 1)
		elif d.x == int(b["x"]) - 1:
			approach = Vector2i(d.x - 1, d.y)
		else:
			approach = Vector2i(d.x + 1, d.y)
		door_approach[approach] = true

	# 雪泥
	for k in 18 + rng.randi_range(0, 13):
		if rooms.is_empty():
			break
		var r: Dictionary = rooms[rng.randi_range(0, rooms.size() - 1)]
		var cx := int(r["x"]) + 1 + rng.randi_range(0, maxi(0, int(r["w"]) - 2))
		var cy := int(r["y"]) + 1 + rng.randi_range(0, maxi(0, int(r["h"]) - 2))
		if _in_any_building(buildings, cx, cy):
			continue
		var rad := 1 + rng.randi_range(0, 1)
		for j in range(-rad, rad + 1):
			for i in range(-rad, rad + 1):
				var x := cx + i
				var y := cy + j
				if x < int(r["x"]) or x >= int(r["x"]) + int(r["w"]):
					continue
				if y < int(r["y"]) or y >= int(r["y"]) + int(r["h"]):
					continue
				if x == int(r["cx"]) and y == int(r["cy"]):
					continue
				if _in_any_building(buildings, x, y):
					continue
				if at(grid, x, y) == Data.TT_FLOOR and rng.randf() < 0.62:
					set_tile(grid, x, y, Data.TT_SLUSH)

	# 掩体
	for k in 10 + rng.randi_range(0, 9):
		if rooms.is_empty():
			break
		var r2: Dictionary = rooms[rng.randi_range(0, rooms.size() - 1)]
		var length := 1 + rng.randi_range(0, 2)
		var horiz := rng.randf() < 0.5
		var x2 := int(r2["x"]) + 1 + rng.randi_range(0, maxi(0, int(r2["w"]) - 3))
		var y2 := int(r2["y"]) + 1 + rng.randi_range(0, maxi(0, int(r2["h"]) - 3))
		for i in length:
			var px := x2 + (i if horiz else 0)
			var py := y2 + (0 if horiz else i)
			if _env_blocked(street_rects, door_approach, buildings, r2, px, py):
				continue
			if at(grid, px, py) == Data.TT_FLOOR:
				set_tile(grid, px, py, Data.TT_COVER)

	# 铁丝网
	for k in 6 + rng.randi_range(0, 5):
		if rooms.is_empty():
			break
		var r3: Dictionary = rooms[rng.randi_range(0, rooms.size() - 1)]
		var length2 := 2 + rng.randi_range(0, 3)
		var horiz2 := rng.randf() < 0.5
		var x3 := int(r3["x"]) + 1 + rng.randi_range(0, maxi(0, int(r3["w"]) - 3))
		var y3 := int(r3["y"]) + 1 + rng.randi_range(0, maxi(0, int(r3["h"]) - 3))
		for i in length2:
			var px2 := x3 + (i if horiz2 else 0)
			var py2 := y3 + (0 if horiz2 else i)
			if _env_blocked(street_rects, door_approach, buildings, r3, px2, py2):
				continue
			if at(grid, px2, py2) == Data.TT_FLOOR:
				set_tile(grid, px2, py2, Data.TT_FENCE)

	# 窄口门
	var center_tiles := {}
	for r4 in rooms:
		center_tiles[Vector2i(int(r4["cx"]), int(r4["cy"]))] = true
	for y4 in range(1, H - 1):
		for x4 in range(1, W - 1):
			if at(grid, x4, y4) != Data.TT_FLOOR:
				continue
			if center_tiles.has(Vector2i(x4, y4)):
				continue
			var h_open := at(grid, x4 - 1, y4) == Data.TT_FLOOR and at(grid, x4 + 1, y4) == Data.TT_FLOOR
			var v_open := at(grid, x4, y4 - 1) == Data.TT_FLOOR and at(grid, x4, y4 + 1) == Data.TT_FLOOR
			if (h_open and not v_open) or (not h_open and v_open):
				var solid_n := 0
				if at(grid, x4 - 1, y4) == Data.TT_WALL:
					solid_n += 1
				if at(grid, x4 + 1, y4) == Data.TT_WALL:
					solid_n += 1
				if at(grid, x4, y4 - 1) == Data.TT_WALL:
					solid_n += 1
				if at(grid, x4, y4 + 1) == Data.TT_WALL:
					solid_n += 1
				if solid_n >= 2 and rng.randf() < 0.30:
					set_tile(grid, x4, y4, Data.TT_DOOR)

	# ---------------- 4. 容器 ----------------
	var conts: Array[Dictionary] = []
	var n_cont := int(round((8.0 + float(L.get("dg", 1)) * 3.0) * (0.85 + rng.randf() * 0.4) * clampf(left, 0.05, 1.0)))
	for k in n_cont:
		if rooms.is_empty():
			break
		var r5: Dictionary = rooms[rng.randi_range(0, rooms.size() - 1)]
		for attempt in 24:
			var x5 := int(r5["x"]) + rng.randi_range(0, maxi(0, int(r5["w"]) - 1))
			var y5 := int(r5["y"]) + rng.randi_range(0, maxi(0, int(r5["h"]) - 1))
			if at(grid, x5, y5) != Data.TT_FLOOR and at(grid, x5, y5) != Data.TT_SLUSH:
				continue
			if not bool(r5.get("building", false)) and _in_any_building(buildings, x5, y5):
				continue
			var too_close := false
			for c in conts:
				if _dist(float(c["x"]), float(c["y"]), x5 + 0.5, y5 + 0.5) < 2.0:
					too_close = true
					break
			if too_close:
				continue
			var ctype: String = CONTAINER_TYPES[rng.randi_range(0, CONTAINER_TYPES.size() - 1)]
			var mech: String = String(r5.get("mech", ""))
			if mech == "kitchen":
				ctype = (["fridge", "fridge", "crate"] if bool(r5.get("building", false)) else ["supply", "supply", "dumpster"])[rng.randi_range(0, 2)]
			elif mech == "clinic":
				ctype = ["medcab", "medcab", "briefcase"][rng.randi_range(0, 2)]
			elif mech == "workshop":
				ctype = ["briefcase", "safe", "locker"][rng.randi_range(0, 2)]
			elif bool(r5.get("building", false)):
				ctype = ["fridge", "locker", "medcab", "briefcase"][rng.randi_range(0, 3)]
			if ctype == "safe" and rng.randf() < 0.6:
				ctype = "locker"
			if ctype == "hidden" and rng.randf() < 0.75:
				ctype = "crate"
			conts.append({"x": x5 + 0.5, "y": y5 + 0.5, "type": ctype,
				"searched": false, "prog": 0.0})
			break

	# 储藏室机制：额外 2 个容器；厨房机制：自带火堆
	var fires: Array[Vector2] = []
	for r6 in rooms:
		var mech2: String = String(r6.get("mech", ""))
		if mech2 == "storage":
			for k in 2:
				var x6 := int(r6["x"]) + rng.randi_range(0, maxi(0, int(r6["w"]) - 1))
				var y6 := int(r6["y"]) + rng.randi_range(0, maxi(0, int(r6["h"]) - 1))
				if at(grid, x6, y6) != Data.TT_FLOOR and at(grid, x6, y6) != Data.TT_SLUSH:
					continue
				if _in_any_building(buildings, x6, y6):
					continue
				conts.append({"x": x6 + 0.5, "y": y6 + 0.5,
					"type": "crate" if rng.randf() < 0.5 else "locker",
					"searched": false, "prog": 0.0})
		if mech2 == "kitchen":
			fires.append(Vector2(float(r6["cx"]) + 0.5, float(r6["cy"]) + 0.5))

	# 火堆（回温）
	var n_fire := 2 if float(L.get("cold", 1.0)) > 1.0 else 1
	for k in n_fire:
		if rooms.is_empty():
			break
		var r7: Dictionary = rooms[rng.randi_range(0, rooms.size() - 1)]
		for attempt in 10:
			var fx := int(r7["x"]) + 1 + rng.randi_range(0, maxi(0, int(r7["w"]) - 2))
			var fy := int(r7["y"]) + 1 + rng.randi_range(0, maxi(0, int(r7["h"]) - 2))
			if at(grid, fx, fy) != Data.TT_FLOOR:
				continue
			fires.append(Vector2(fx + 0.5, fy + 0.5))
			break

	# ---------------- 5. 出入口与连通性 ----------------
	var start_room: Dictionary = rooms[0] if not rooms.is_empty() else {"cx": 4, "cy": 4}
	var entry := Vector2(float(start_room["cx"]) + 0.5, float(start_room["cy"]) + 0.5)
	var protected := {}
	for b2 in buildings:
		for j in range(int(b2["y"]), int(b2["y"]) + int(b2["h"])):
			for i in range(int(b2["x"]), int(b2["x"]) + int(b2["w"])):
				protected[Vector2i(i, j)] = true
	ensure_connected(grid, conts, entry, protected)

	# ---------------- 6. 边界：建筑段 + 围墙段 ----------------
	var bx := 0
	while bx < W:
		var seg := 6 + rng.randi_range(0, 7)
		var bld := rng.randf() < 0.55
		for i in range(bx, mini(W, bx + seg)):
			var v: int = Data.TT_WALL if bld else Data.TT_FENCE
			grid[i] = v
			grid[(H - 1) * W + i] = v
		bx += seg
	var by := 1
	while by < H - 1:
		var seg2 := 6 + rng.randi_range(0, 7)
		var bld2 := rng.randf() < 0.55
		for j in range(by, mini(H - 1, by + seg2)):
			var v2: int = Data.TT_WALL if bld2 else Data.TT_FENCE
			grid[j * W] = v2
			grid[j * W + (W - 1)] = v2
		by += seg2

	return {
		"W": W, "H": H, "grid": grid, "rooms": rooms, "conts": conts,
		"fires": fires, "entry": entry, "buildings": buildings,
	}

# ============================================================================
# 瓦片工具
# ============================================================================
static func at(grid: PackedByteArray, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= W or y >= H:
		return Data.TT_WALL
	return grid[y * W + x]

static func set_tile(grid: PackedByteArray, x: int, y: int, v: int) -> void:
	if x > 0 and y > 0 and x < W - 1 and y < H - 1:
		grid[y * W + x] = v

static func walkable(v: int) -> bool:
	return v == Data.TT_FLOOR or v == Data.TT_SLUSH or v == Data.TT_DOOR

static func blocks_move(v: int) -> bool:
	return v == Data.TT_WALL or v == Data.TT_COVER or v == Data.TT_FENCE \
		or v == Data.TT_WEDGED or v == Data.TT_BDOOR

static func blocks_sight(v: int) -> bool:
	return v == Data.TT_WALL or v == Data.TT_WEDGED or v == Data.TT_COVER or v == Data.TT_BDOOR

static func _dist(ax: float, ay: float, bx: float, by: float) -> float:
	var dx := ax - bx
	var dy := ay - by
	return sqrt(dx * dx + dy * dy)

static func _clear_of(bands: Array[Vector2i], a: int, b: int, pad: int) -> bool:
	for band in bands:
		if not (b < band.x - pad or a > band.y + pad):
			return false
	return true

static func _gaps(bands: Array[Vector2i], lo: int, hi: int, min_size: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var prev := lo
	for band in bands:
		if band.x - prev >= min_size:
			out.append(Vector2i(prev, band.x - 1))
		prev = band.y + 1
	if hi - prev + 1 >= min_size:
		out.append(Vector2i(prev, hi))
	return out

static func _carve_h(grid: PackedByteArray, rects: Array[Rect2], y0: int, th: int, x0: int, x1: int) -> void:
	for j in range(y0, y0 + th):
		for i in range(x0, x1 + 1):
			set_tile(grid, i, j, Data.TT_FLOOR)
	rects.append(Rect2(x0, y0, x1 - x0 + 1, th))

static func _carve_v(grid: PackedByteArray, rects: Array[Rect2], x0: int, th: int, y0: int, y1: int) -> void:
	for i in range(x0, x0 + th):
		for j in range(y0, y1 + 1):
			set_tile(grid, i, j, Data.TT_FLOOR)
	rects.append(Rect2(x0, y0, th, y1 - y0 + 1))

static func _on_street(rects: Array[Rect2], x: int, y: int) -> bool:
	for r in rects:
		if x >= int(r.position.x) and x <= int(r.position.x + r.size.x) \
				and y >= int(r.position.y) and y <= int(r.position.y + r.size.y):
			return true
	return false

static func _rect_blob(x: int, y: int, w: int, h: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for j in range(y, y + h):
		for i in range(x, x + w):
			out.append(Vector2i(i, j))
	return out

static func _in_any_building(buildings: Array[Dictionary], x: int, y: int) -> bool:
	for b in buildings:
		if x >= int(b["x"]) and x < int(b["x"]) + int(b["w"]) \
				and y >= int(b["y"]) and y < int(b["y"]) + int(b["h"]):
			return true
	return false

static func _env_blocked(street_rects: Array[Rect2], door_approach: Dictionary,
		buildings: Array[Dictionary], r: Dictionary, x: int, y: int) -> bool:
	if x < int(r["x"]) or x >= int(r["x"]) + int(r["w"]):
		return true
	if y < int(r["y"]) or y >= int(r["y"]) + int(r["h"]):
		return true
	if x == int(r["cx"]) and y == int(r["cy"]):
		return true
	if _on_street(street_rects, x - 1, y) or _on_street(street_rects, x + 1, y) \
			or _on_street(street_rects, x, y - 1) or _on_street(street_rects, x, y + 1):
		return true
	if door_approach.has(Vector2i(x, y)):
		return true
	if _in_any_building(buildings, x, y):
		return true
	return false

# 扇区连通性：从贴街的可走格洪水填充，检查扇区内所有非建筑可走格是否都被访问
static func _sector_connected(grid: PackedByteArray, s: Rect2i,
		buildings: Array[Dictionary]) -> bool:
	var seen := {}
	var queue: Array[Vector2i] = []
	for j in range(s.position.y, s.position.y + s.size.y):
		for i in range(s.position.x, s.position.x + s.size.x):
			if at(grid, i, j) != Data.TT_FLOOR:
				continue
			if _in_any_building(buildings, i, j):
				continue
			var near_street := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if at(grid, i + d.x, j + d.y) == Data.TT_FLOOR:
					var outside := i + d.x < s.position.x or i + d.x >= s.position.x + s.size.x \
						or j + d.y < s.position.y or j + d.y >= s.position.y + s.size.y
					if outside:
						near_street = true
			if near_street:
				var key := Vector2i(i, j)
				if not seen.has(key):
					seen[key] = true
					queue.append(key)
	if queue.is_empty():
		return false
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for d2 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := cur.x + d2.x
			var ny := cur.y + d2.y
			if nx < s.position.x or nx >= s.position.x + s.size.x:
				continue
			if ny < s.position.y or ny >= s.position.y + s.size.y:
				continue
			var key2 := Vector2i(nx, ny)
			if seen.has(key2):
				continue
			if at(grid, nx, ny) != Data.TT_FLOOR:
				continue
			if _in_any_building(buildings, nx, ny):
				continue
			seen[key2] = true
			queue.append(key2)
	# 复核：扇区内还有没被访问的非建筑可走格 → 不连通
	for j2 in range(s.position.y, s.position.y + s.size.y):
		for i2 in range(s.position.x, s.position.x + s.size.x):
			if at(grid, i2, j2) != Data.TT_FLOOR:
				continue
			if _in_any_building(buildings, i2, j2):
				continue
			if not seen.has(Vector2i(i2, j2)):
				return false
	return true

# ============================================================================
# 后处理：保证整张图全连通（对应 HTML ensureConnected）
# ============================================================================
static func ensure_connected(grid: PackedByteArray, conts: Array[Dictionary],
		entry: Vector2, protected_tiles: Dictionary) -> void:
	var ex := int(floor(entry.x))
	var ey := int(floor(entry.y))
	# 入口若落在墙上，就近挪到可走瓦片
	if not walkable(at(grid, ex, ey)):
		var ok := false
		for r in range(1, 7):
			if ok:
				break
			for j in range(-r, r + 1):
				if ok:
					break
				for i in range(-r, r + 1):
					if walkable(at(grid, ex + i, ey + j)):
						ex += i
						ey += j
						ok = true
						break
		if ok:
			entry.x = ex + 0.5
			entry.y = ey + 0.5

	var comps := _components(grid, protected_tiles)
	if comps.is_empty():
		return
	var main_id := _component_of(grid, ex, ey, protected_tiles)
	# 孤岛 → L 形走廊接回入口
	for c in comps:
		if int(c["id"]) == main_id:
			continue
		var best: Vector2i = c["cells"][0]
		var best_d := 1e18
		for cell in c["cells"]:
			var d := float((cell.x - ex) * (cell.x - ex) + (cell.y - ey) * (cell.y - ey))
			if d < best_d:
				best_d = d
				best = cell
		var x := best.x
		var y := best.y
		while x != ex:
			if not protected_tiles.has(Vector2i(x, y)):
				set_tile(grid, x, y, Data.TT_FLOOR)
			x += 1 if ex > x else -1
		while y != ey:
			if not protected_tiles.has(Vector2i(x, y)):
				set_tile(grid, x, y, Data.TT_FLOOR)
			y += 1 if ey > y else -1
		set_tile(grid, ex, ey, Data.TT_FLOOR)

	# 复核：封死残余死区，剔除其中的容器
	var ok_map := {}
	var queue: Array[Vector2i] = [Vector2i(ex, ey)]
	ok_map[Vector2i(ex, ey)] = true
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for d2 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := cur.x + d2.x
			var ny := cur.y + d2.y
			if nx < 0 or ny < 0 or nx >= W or ny >= H:
				continue
			var key := Vector2i(nx, ny)
			if ok_map.has(key) or protected_tiles.has(key):
				continue
			if not walkable(at(grid, nx, ny)):
				continue
			ok_map[key] = true
			queue.append(key)
	for j2 in range(H):
		for i2 in range(W):
			var key2 := Vector2i(i2, j2)
			if ok_map.has(key2) or protected_tiles.has(key2):
				continue
			var v := at(grid, i2, j2)
			if v == Data.TT_FLOOR or v == Data.TT_SLUSH:
				set_tile(grid, i2, j2, Data.TT_WALL)
	for idx in range(conts.size() - 1, -1, -1):
		var c2: Dictionary = conts[idx]
		var cx := int(floor(float(c2["x"])))
		var cy := int(floor(float(c2["y"])))
		if not ok_map.has(Vector2i(cx, cy)) and not protected_tiles.has(Vector2i(cx, cy)):
			conts.remove_at(idx)

static func _components(grid: PackedByteArray, protected_tiles: Dictionary) -> Array[Dictionary]:
	var seen := {}
	var comps: Array[Dictionary] = []
	for j in range(H):
		for i in range(W):
			var key := Vector2i(i, j)
			if seen.has(key) or protected_tiles.has(key):
				continue
			if not walkable(at(grid, i, j)):
				continue
			var id := comps.size()
			var cells: Array[Vector2i] = []
			var queue: Array[Vector2i] = [key]
			seen[key] = true
			var head := 0
			while head < queue.size():
				var cur: Vector2i = queue[head]
				head += 1
				cells.append(cur)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx := cur.x + d.x
					var ny := cur.y + d.y
					if nx < 0 or ny < 0 or nx >= W or ny >= H:
						continue
					var k2 := Vector2i(nx, ny)
					if seen.has(k2) or protected_tiles.has(k2):
						continue
					if not walkable(at(grid, nx, ny)):
						continue
					seen[k2] = true
					queue.append(k2)
			comps.append({"id": id, "cells": cells})
	return comps

static func _component_of(grid: PackedByteArray, x: int, y: int, protected_tiles: Dictionary) -> int:
	var comps := _components(grid, protected_tiles)
	for c in comps:
		for cell in c["cells"]:
			if cell.x == x and cell.y == y:
				return int(c["id"])
	return -1

# ============================================================================
# 战利品（对应 HTML genLoot）
# ============================================================================
static func gen_loot(L: Dictionary, cont: Dictionary, rng: RandomNumberGenerator,
		med_bonus: bool = false) -> Array[String]:
	var out: Array[String] = []
	var ctype := String(cont.get("type", "crate"))
	var n := 1
	if ctype == "safe":
		n = 3
	elif ctype == "hidden":
		n = 2
	elif ctype == "corpse":
		n = 2
	if rng.randf() < 0.42:
		n += 1
	if med_bonus and (ctype == "medcab" or ctype == "fridge"):
		n = int(ceil(float(n) * 1.5))   # 古丽娅：医疗类容器 +50%
	var node_loot: Array = L.get("loot", ["scrap"])
	for i in n:
		var cat := ""
		if ctype == "corpse":
			var from := String(cont.get("from", "rabid"))
			var by_from := {"rabid": ["scrap", "food", "warm"],
				"osk": ["part", "weapon", "med", "val"],
				"half": ["food", "val", "med"]}
			var pool_f: Array = by_from.get(from, by_from["rabid"])
			cat = String(pool_f[rng.randi_range(0, pool_f.size() - 1)])
		elif rng.randf() < 0.62 and Data.CONTAINER_CATS.has(ctype):
			var pool: Array = Data.CONTAINER_CATS[ctype]
			cat = String(pool[rng.randi_range(0, pool.size() - 1)])
		else:
			cat = String(node_loot[rng.randi_range(0, node_loot.size() - 1)])
		if (cat == "part" or cat == "weapon") and rng.randf() < 0.62:
			cat = "scrap"
		if cat == "med" and rng.randf() < 0.55:
			# HTML 里写 cat='band'，但 CAT 没有 band 池 → 实际退化成 scrap。
			# 这里按设计意图修正：直接给一卷绷带。
			out.append("band")
			continue
		var items: Array = Data.LOOT_CATS.get(cat, Data.LOOT_CATS["scrap"])
		out.append(String(items[rng.randi_range(0, items.size() - 1)]))
	if ctype == "hidden" and rng.randf() < 0.5:
		out.append("dial")
	return out
