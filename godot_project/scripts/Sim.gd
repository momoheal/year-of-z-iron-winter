# Sim.gd — Room A 垂直切片纯逻辑层（RefCounted）
# 1:1 对应 prototypes/Year_of_Z_Iron_Winter_Exploration_Demo.html 的夜潜主循环：
# 实体是普通数据对象（无 Node），每帧手动移动/碰撞/分离；渲染层（Main.gd）在 _draw() 里画。
# 世界坐标 = 逻辑米（1 格 = 1 米，原点左上，x 东 y 南）。
extends RefCounted

# ---------- CFG（与 HTML 的 CFG 一致，DEMO 用 38px/m，y 轴压缩 0.62） ----------
const PPM := 38.0
const SQUASH := 0.62
const WALL_H := 0.62
const FOV_DEG := 90.0
const SIGHT := 12.0
const NEAR_SENSE := 1.8
const SPEED_WALK := 3.2
const SPEED_SNEAK := 1.6
const SPEED_SPRINT := 5.0
const NOISE_WALK := 2.5
const NOISE_SNEAK := 0.8
const NOISE_SPRINT := 7.5
const NOISE_CAN := 9.0

# ---------- 瓦片（对应 HTML TT） ----------
const TT_FLOOR := 0
const TT_WALL := 1
const TT_SLUSH := 2
const TT_COVER := 3
const TT_FENCE := 4

# Room A：30m × 20m
const ROOM_W := 30
const ROOM_H := 20

static func hypotf(x: float, y: float) -> float:
	return sqrt(x * x + y * y)

# ---------- 纯数据实体（字段对应 HTML 的 S.player / S.ents 条目） ----------
class Player extends RefCounted:
	var x: float = 0.0
	var y: float = 0.0
	var face: float = -PI / 2.0
	var hp: float = 100.0
	var stam: float = 100.0
	var warmth: float = 100.0
	var sneak: bool = false
	var sprint: bool = false
	var alive: bool = true
	var hurt: float = 0.0
	var iframe: float = 0.0
	var drink: float = 0.0
	var bpm: float = 70.0

class Ent extends RefCounted:
	var kind: String = ""          # "rabid" / "osk"
	var x: float = 0.0
	var y: float = 0.0
	var hp: float = 100.0
	var state: String = "idle"
	var dead: bool = false
	var cd: float = 0.0
	var hit_flash: float = 0.0
	# rabid
	var tx: float = 0.0
	var ty: float = 0.0
	var alert: float = 0.0
	var wt: float = 0.0
	var home_x: float = 0.0
	var home_y: float = 0.0
	var bite: float = 0.0
	var lost: float = 0.0
	# osk
	var face: float = 0.0
	var suspect: float = 0.0
	var lock: float = 0.0
	var wp: Array[Vector2] = []
	var wpi: int = 0

class Ripple extends RefCounted:
	var x: float = 0.0
	var y: float = 0.0
	var r: float = 0.3
	var max: float = 1.0
	var color: Color = Color.WHITE
	var kind: String = ""
	var life: float = 1.0

class Toast extends RefCounted:
	var text: String = ""
	var t: float = 0.0
	func _init(p_text: String, p_t: float = 2.5) -> void:
		text = p_text
		t = p_t

# ---------- 运行时状态（对应 HTML 的 S） ----------
var W: int = ROOM_W
var H: int = ROOM_H
var grid: PackedByteArray = PackedByteArray()
var vis: PackedByteArray = PackedByteArray()
var explored: PackedByteArray = PackedByteArray()
var poly: Array[Vector2] = []

var player: Player = Player.new()
var ents: Array[Ent] = []
var ripples: Array[Ripple] = []
var toasts: Array[Toast] = []
var decals: Array[Dictionary] = []

var cam: Vector2 = Vector2.ZERO
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var time: float = 0.0

var noise_acc: float = 0.0
var noise_hint: float = 0.0          # 当前姿态噪声半径（给 HUD）
var cans: int = 5
var water: int = 2
var extract_prog: float = 0.0
var killed_rabids: int = 0
var shake: float = 0.0
var phase: int = 0                   # 0 进行中 / 1 撤离成功 / 2 死亡
var exit_pos: Vector2 = Vector2(1.5, 15.5)

# 蒸汽管掩体（COVER 行），供渲染层画管道
var pipe_x0 := 4
var pipe_x1 := 10
var pipe_y := 6

# ============================================================================
# 初始化
# ============================================================================
func _init() -> void:
	rng.seed = 20261022
	grid.resize(W * H)
	vis.resize(W * H)
	explored.resize(W * H)
	# 全是墙，再开内腔
	grid.fill(TT_WALL)
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			grid[y * W + x] = TT_FLOOR
	# 高架蒸汽管（COVER 行，x=4..10, y=6）
	for x in range(pipe_x0, pipe_x1 + 1):
		set_tile(x, pipe_y, TT_COVER)
	# 冻雪泥 6×4（x=8..13, y=10..13）
	for y in range(10, 14):
		for x in range(8, 14):
			set_tile(x, y, TT_SLUSH)
	# 零星掩体箱（与灰盒规格 Room A 布局一致）
	for t in [Vector2i(17, 6), Vector2i(22, 3), Vector2i(15, 4), Vector2i(16, 4), Vector2i(26, 12)]:
		set_tile(t.x, t.y, TT_COVER)
	# 小房间全部“已探索”（灰盒测试房不需要战争迷雾解锁）
	explored.fill(1)
	# 玩家
	player.x = 3.0
	player.y = 17.0
	player.face = -PI / 2.0
	cam = Vector2(player.x, player.y)
	# 2 只狂暴者
	for p in [Vector2(17.0, 3.2), Vector2(22.6, 2.4)]:
		var e := Ent.new()
		e.kind = "rabid"
		e.x = p.x
		e.y = p.y
		e.tx = p.x
		e.ty = p.y
		e.home_x = p.x
		e.home_y = p.y
		e.hp = 60.0
		e.wt = rng.randf() * 3.0
		ents.append(e)
	# 1 名清杀兵（矩形巡逻路径）
	var s := Ent.new()
	s.kind = "osk"
	s.x = 5.0
	s.y = 3.5
	s.hp = 120.0
	s.state = "patrol"
	var patrol: Array[Vector2] = [Vector2(5, 3.5), Vector2(25, 3.5), Vector2(25, 9), Vector2(5, 9)]
	s.wp = patrol
	s.wpi = 1
	s.face = 0.0
	s.tx = 25.0
	s.ty = 3.5
	ents.append(s)
	compute_vis()

# ============================================================================
# 地图查询
# ============================================================================
func set_tile(x: int, y: int, v: int) -> void:
	if x > 0 and y > 0 and x < W - 1 and y < H - 1:
		grid[y * W + x] = v

func at(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= W or y >= H:
		return TT_WALL
	return grid[y * W + x]

func blocks_move(v: int) -> bool:
	return v == TT_WALL or v == TT_COVER or v == TT_FENCE

func blocks_sight(v: int) -> bool:
	return v == TT_WALL or v == TT_COVER

# ============================================================================
# 小工具（对应 clamp / lerp / dist / angDiff）
# ============================================================================
func ang_diff(a: float, b: float) -> float:
	var d: float = fmod(a - b, TAU)
	if d > PI:
		d -= TAU
	if d < -PI:
		d += TAU
	return d

# ============================================================================
# 视线 / 遮挡 / 碰撞（对应 losClear / coverHides / canStand / moveEnt）
# ============================================================================
func los_clear(x0: float, y0: float, x1: float, y1: float) -> bool:
	# 与 HTML 一致：COVER 不挡视线（blockCover:false），仅墙挡；终点格跳过
	var dx: float = x1 - x0
	var dy: float = y1 - y0
	var d: float = hypotf(dx, dy)
	var steps: int = maxi(1, int(ceil(d / 0.28)))
	var tx1: int = int(floor(x1))
	var ty1: int = int(floor(y1))
	for i in range(1, steps + 1):
		var tt: float = float(i) / float(steps)
		var x: float = x0 + dx * tt
		var y: float = y0 + dy * tt
		var fx: int = int(floor(x))
		var fy: int = int(floor(y))
		if fx == tx1 and fy == ty1:
			continue
		if at(fx, fy) == TT_WALL:
			return false
	return true

func cover_hides(px: float, py: float, ex: float, ey: float) -> bool:
	# 玩家与敌人连线上，若玩家 1.9m 内有 COVER 格则视为被遮挡（HTML 同公式）
	var d: float = hypotf(ex - px, ey - py)
	var steps: int = int(ceil(d / 0.5))
	for i in range(0, steps + 1):
		var tt: float = float(i) / float(steps)
		var x: float = px + (ex - px) * tt
		var y: float = py + (ey - py) * tt
		if at(int(floor(x)), int(floor(y))) == TT_COVER and hypotf(x - px, y - py) < 1.9:
			return true
	return false

func can_stand(x: float, y: float, r: float) -> bool:
	var a: int = at(int(floor(x - r)), int(floor(y - r)))
	var b: int = at(int(floor(x + r)), int(floor(y - r)))
	var c: int = at(int(floor(x - r)), int(floor(y + r)))
	var d: int = at(int(floor(x + r)), int(floor(y + r)))
	return not (blocks_move(a) or blocks_move(b) or blocks_move(c) or blocks_move(d))

func move_ent(e, nx: float, ny: float, r: float) -> void:
	if can_stand(nx, e.y, r):
		e.x = nx
	if can_stand(e.x, ny, r):
		e.y = ny

# ============================================================================
# 声音（对应 emitNoise）
# ============================================================================
func emit_noise(x: float, y: float, radius: float, color: Color, kind: String) -> void:
	var rp := Ripple.new()
	rp.x = x
	rp.y = y
	rp.max = radius
	rp.color = color
	rp.kind = kind
	ripples.append(rp)
	for e in ents:
		if e.dead:
			continue
		var d: float = hypotf(e.x - x, e.y - y)
		if d <= radius:
			if e.kind == "rabid":
				e.state = "investigate"
				e.tx = x
				e.ty = y
				e.alert = minf(1.0, e.alert + 0.5)
			elif e.kind == "osk":
				e.state = "investigate"
				e.tx = x
				e.ty = y
				e.suspect = minf(1.4, e.suspect + 0.7)

# ============================================================================
# 动作
# ============================================================================
func throw_can(target_world: Vector2) -> void:
	if phase != 0:
		return
	if cans <= 0:
		add_toast("没有空罐头了。 / No tins left.")
		return
	cans -= 1
	var p := player
	var tx: float = target_world.x
	var ty: float = target_world.y
	var d: float = hypotf(tx - p.x, ty - p.y)
	if d > 8.0:
		tx = p.x + (tx - p.x) / d * 8.0
		ty = p.y + (ty - p.y) / d * 8.0
	emit_noise(tx, ty, NOISE_CAN, Color("e2e8f0"), "can")
	add_toast("空罐头飞进阴影里——叮当。 / The tin arcs into the dark — clatter.", 1.8)

func drink() -> void:
	if phase != 0:
		return
	if water <= 0:
		add_toast("水壶空了。 / The flask is empty.")
		return
	water -= 1
	player.warmth = minf(100.0, player.warmth + 26.0)
	player.drink = 1.2
	add_toast("体温回升了一点。 / A little warmer.", 1.6)

func add_toast(text: String, t: float = 2.5) -> void:
	toasts.append(Toast.new(text, t))

# ============================================================================
# 视野多边形（对应 tileVisibleAt / computeVis）
# ============================================================================
func tile_visible_at(wx: float, wy: float) -> bool:
	var p := player
	var d: float = hypotf(wx - p.x, wy - p.y)
	if d > SIGHT:
		return false
	if d <= NEAR_SENSE:
		return true
	if abs(int(floor(wx)) - int(floor(p.x))) <= 2 and abs(int(floor(wy)) - int(floor(p.y))) <= 2:
		return los_clear(p.x, p.y, wx, wy)
	var a: float = atan2(wy - p.y, wx - p.x)
	if abs(ang_diff(a, p.face)) > FOV_DEG * PI / 360.0:
		return false
	return los_clear(p.x, p.y, wx, wy)

func compute_vis() -> void:
	vis.fill(0)
	var p := player
	var i0: int = maxi(0, int(floor(p.x - SIGHT - 1)))
	var i1: int = mini(W - 1, int(ceil(p.x + SIGHT + 1)))
	var j0: int = maxi(0, int(floor(p.y - SIGHT - 1)))
	var j1: int = mini(H - 1, int(ceil(p.y + SIGHT + 1)))
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			if tile_visible_at(i + 0.5, j + 0.5):
				vis[j * W + i] = 1
				explored[j * W + i] = 1
	poly = [Vector2(p.x, p.y)]
	var n: int = 54
	var half: float = FOV_DEG * PI / 360.0
	var step: float = 0.35
	for k in range(0, n + 1):
		var a: float = p.face - half + (2.0 * half) * (float(k) / float(n))
		var d: float = 0.0
		while d < SIGHT:
			var nx: float = p.x + cos(a) * d
			var ny: float = p.y + sin(a) * d
			if blocks_sight(at(int(floor(nx)), int(floor(ny)))) and d > 0.2:
				break
			d += step
		poly.append(Vector2(p.x + cos(a) * d, p.y + sin(a) * d))

# ============================================================================
# 主更新（对应 HTML update(dt)）
# input_vec：已归一化的移动向量；mouse_world：鼠标的世界坐标；hold_e：按住 E
# ============================================================================
func update(dt: float, input_vec: Vector2, crouch: bool, sprint: bool, mouse_world: Vector2, hold_e: bool) -> void:
	time += dt
	if phase != 0:
		return
	var p := player

	# 瞄准：朝向跟随鼠标
	p.face = atan2(mouse_world.y - p.y, mouse_world.x - p.x)

	# 移动
	p.sneak = crouch
	p.sprint = sprint and not crouch and p.stam > 2.0 and (input_vec.x != 0.0 or input_vec.y != 0.0)
	var on_slush: bool = at(int(floor(p.x)), int(floor(p.y))) == TT_SLUSH
	var sp: float = SPEED_SNEAK if p.sneak else (SPEED_SPRINT if p.sprint else SPEED_WALK)
	if on_slush:
		sp *= 0.65
	if input_vec.x != 0.0 or input_vec.y != 0.0:
		var nx: float = p.x + input_vec.x * sp * dt
		var ny: float = p.y + input_vec.y * sp * dt
		var ox: float = p.x
		var oy: float = p.y
		move_ent(p, nx, ny, 0.35)
		var moved: float = hypotf(p.x - ox, p.y - oy)
		noise_acc += moved
		var base: float = NOISE_SNEAK if p.sneak else (NOISE_SPRINT if p.sprint else NOISE_WALK)
		var thresh: float = 0.9 if p.sneak else 1.4
		noise_hint = base * (2.0 if on_slush else 1.0)
		if noise_acc > thresh:
			noise_acc = 0.0
			emit_noise(p.x, p.y, noise_hint, Color("e2e8f0"), "self")
	if p.sprint:
		p.stam = minf(100.0, p.stam - 18.0 * dt)
	else:
		p.stam = minf(100.0, p.stam + 9.0 * dt)
	if p.drink > 0.0:
		p.drink -= dt
	if p.iframe > 0.0:
		p.iframe -= dt
	if p.hurt > 0.0:
		p.hurt -= dt
	# 体温（Room A 无冷源，保持）
	p.warmth = 100.0

	# 心率
	var fear: float = 0.0
	for e in ents:
		if not e.dead and (e.kind == "rabid" or e.kind == "osk"):
			fear = maxf(fear, clampf(1.0 - hypotf(e.x - p.x, e.y - p.y) / 10.0, 0.0, 1.0))
	var target_bpm: float = 70.0 + (34.0 if p.sprint else 0.0) + (22.0 if p.hp < 45.0 else 0.0) + fear * 26.0
	p.bpm = lerpf(p.bpm, target_bpm, 1.0 - pow(0.02, dt))

	# 撤离（按住 E 1.5s，站在撤离点 1.6m 内）
	if hold_e and hypotf(exit_pos.x - p.x, exit_pos.y - p.y) < 1.6:
		extract_prog += dt / 1.5
		if extract_prog >= 1.0:
			phase = 1
			add_toast("撤离成功。 / Extracted.", 3.0)
	else:
		extract_prog = 0.0

	# ---------------- 实体 AI（与 HTML 逐行对应） ----------------
	for e in ents:
		if e.dead:
			continue
		e.cd -= dt
		if e.hit_flash > 0.0:
			e.hit_flash -= dt
		var d: float = hypotf(e.x - p.x, e.y - p.y)
		if e.kind == "rabid":
			_update_rabid(e, dt, d)
		elif e.kind == "osk":
			_update_osk(e, dt, d)

	# 波纹
	for r in ripples:
		r.r += maxf(2.2, r.max * 0.55) * dt
		r.life -= dt / 1.5
	for i in range(ripples.size() - 1, -1, -1):
		var rr := ripples[i]
		if rr.life <= 0.0 or rr.r >= rr.max * 1.05:
			ripples.remove_at(i)

	# 相机
	cam.x = lerpf(cam.x, p.x, 1.0 - pow(0.0015, dt))
	cam.y = lerpf(cam.y, p.y, 1.0 - pow(0.0015, dt))

	# 玩家死亡
	if p.hp <= 0.0:
		p.hp = 0.0
		phase = 2

	# 实体分离（撞墙停住，互不重叠）
	for e in ents:
		if e.dead or (e.kind != "rabid" and e.kind != "osk"):
			continue
		_sep(p, e, 0.75)
	var hostiles: Array[Ent] = ents.filter(func(e): return not e.dead and (e.kind == "rabid" or e.kind == "osk"))
	for a in range(0, hostiles.size()):
		for b in range(a + 1, hostiles.size()):
			_sep(hostiles[a], hostiles[b], 0.7)

	# Toast 寿命
	for t in toasts:
		t.t -= dt
	for i in range(toasts.size() - 1, -1, -1):
		if toasts[i].t <= 0.0:
			toasts.remove_at(i)

	compute_vis()

func _update_rabid(e: Ent, dt: float, d: float) -> void:
	var p := player
	var sees: bool = d < 8.5 and los_clear(e.x, e.y, p.x, p.y) and not cover_hides(p.x, p.y, e.x, e.y)
	if e.state == "idle":
		e.wt -= dt
		if sees:
			e.state = "chase"
		elif e.wt <= 0.0:
			e.wt = 1.6 + rng.randf() * 2.8
			e.tx = e.home_x + (rng.randf() - 0.5) * 6.0
			e.ty = e.home_y + (rng.randf() - 0.5) * 6.0
			e.state = "investigate"
	elif e.state == "investigate":
		var a: float = atan2(e.ty - e.y, e.tx - e.x)
		move_ent(e, e.x + cos(a) * 1.5 * dt, e.y + sin(a) * 1.5 * dt, 0.32)
		if hypotf(e.x - e.tx, e.y - e.ty) < 0.6 or e.wt < -6.0:
			e.state = "idle"
			e.wt = 1.0 + rng.randf() * 3.0
		if sees:
			e.state = "chase"
	elif e.state == "chase":
		var a2: float = atan2(p.y - e.y, p.x - e.x)
		move_ent(e, e.x + cos(a2) * 3.3 * dt, e.y + sin(a2) * 3.3 * dt, 0.32)
		if d < 1.15:
			e.bite = minf(e.bite + dt, 0.45)
			if e.bite >= 0.45 and e.cd <= 0.0 and not (p.iframe > 0.0):
				e.cd = 1.7
				e.bite = 0.0
				p.hp -= 8.0
				p.iframe = 0.75
				p.hurt = 0.35
				shake = 5.0
				p.bpm += 18.0
				emit_noise(p.x, p.y, 6.0, Color("ef4444"), "hit")
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
		emit_noise(e.x, e.y, 3.2, Color("ef4444"), "rabid")

func _update_osk(e: Ent, dt: float, d: float) -> void:
	var p := player
	var ang: float = atan2(p.y - e.y, p.x - e.x)
	var in_cone: bool = abs(ang_diff(e.face, ang)) < deg_to_rad(22.5)
	var clear: bool = los_clear(e.x, e.y, p.x, p.y)
	var hidden: bool = p.sneak and cover_hides(p.x, p.y, e.x, e.y)
	if in_cone and d < 14.0 and clear and not hidden:
		e.suspect = clampf(e.suspect + dt * 2.4, 0.0, 2.0)
	else:
		e.suspect = clampf(e.suspect - dt * 0.8, 0.0, 2.0)

	# 借刀：光锥里的狂暴者，锁定 0.5s 即射杀
	for o in ents:
		if o.dead or o == e:
			continue
		if o.kind != "rabid":
			continue
		var d2: float = hypotf(o.x - e.x, o.y - e.y)
		var a2: float = atan2(o.y - e.y, o.x - e.x)
		if d2 < 14.0 and abs(ang_diff(e.face, a2)) < deg_to_rad(22.5) and los_clear(e.x, e.y, o.x, o.y):
			e.lock = maxf(e.lock, 0.0) + dt
			if e.lock > 0.5 and e.cd <= 0.0 and not o.dead:
				e.cd = 0.9
				e.lock = 0.0
				o.hp = 0.0
				o.dead = true
				o.bite = 0.0
				decals.append({"x": o.x, "y": o.y, "c": "991b1b"})
				if decals.size() > 40:
					decals.pop_front()
				emit_noise(e.x, e.y, 9.0, Color("7dd3fc"), "osk")
				killed_rabids += 1
				add_toast("借刀杀人：清杀队替你清掉 1 只狂暴者。 / Borrowed knife: O.S.K. dropped a rabid.", 2.5)

	# 对玩家的锁定与射击
	if e.suspect >= 1.0 and d < 14.0 and clear and not hidden:
		e.lock += dt
	elif d >= 14.0 or not in_cone:
		e.lock = maxf(0.0, e.lock - dt)
	if e.lock >= 1.0 and e.cd <= 0.0:
		e.cd = 0.95
		e.lock = 0.0
		var acc: float = clampf(1.0 - d / 14.0, 0.25, 1.0) * 0.75
		if rng.randf() < acc and not (p.iframe > 0.0):
			p.hp -= 18.0
			p.iframe = 0.6
			p.hurt = 0.4
			shake = 5.0
		emit_noise(e.x, e.y, 10.0, Color("7dd3fc"), "osk")
		add_toast("红外锁定——AKM 微声点射！ / IR lock — suppressed AKM burst!", 1.6)

	# 移动：高嫌疑追击 / 调查声源 / 巡逻
	var tx: float = e.x
	var ty: float = e.y
	if e.suspect >= 1.2:
		tx = p.x
		ty = p.y
	elif e.state == "investigate":
		tx = e.tx
		ty = e.ty
		if hypotf(e.x - tx, e.y - ty) < 1.0:
			e.state = "patrol"
			e.wpi = (e.wpi + 1) % maxi(1, e.wp.size())
	else:
		var wpt: Vector2 = e.wp[e.wpi] if e.wpi < e.wp.size() else Vector2(e.x, e.y)
		tx = wpt.x
		ty = wpt.y
		if hypotf(e.x - tx, e.y - ty) < 1.0:
			e.wpi = (e.wpi + 1) % maxi(1, e.wp.size())
	var a: float = atan2(ty - e.y, tx - e.x)
	var sp2: float = 3.0 if e.suspect >= 1.2 else 1.7
	if hypotf(tx - e.x, ty - e.y) > 0.001:
		move_ent(e, e.x + cos(a) * sp2 * dt, e.y + sin(a) * sp2 * dt, 0.35)
		e.face = lerpf(e.face, a, 1.0 - pow(0.001, dt))
	e.face += sin(time / 0.9) * 0.012  # 轻微扫视
	# 呼吸声（HTML 同频率：dt*1.4，半径 5.5m）
	if rng.randf() < dt * 1.4:
		emit_noise(e.x, e.y, 5.5, Color("7dd3fc"), "osk")

func _sep(a, b, min_d: float) -> void:
	var d: float = hypotf(b.x - a.x, b.y - a.y)
	if d >= min_d:
		return
	var ux: float = 1.0 if d < 0.001 else (b.x - a.x) / d
	var uy: float = 0.0 if d < 0.001 else (b.y - a.y) / d
	var push: float = (min_d - d) / 2.0
	move_ent(a, a.x - ux * push, a.y - uy * push, 0.35)
	move_ent(b, b.x + ux * push, b.y + uy * push, 0.32)
