extends RefCounted
## NavGrid.gd — 夜潜关卡的共享寻路网格（AStarGrid2D）。
##
## 为什么：狂暴者 / 半人 / 清杀兵原来的 _move_to() 都是朝目标直线走 + move_and_slide，
## 在铁丝网、车厢、长桌、铁笼这类障碍后面会一直贴墙撞。
##
## 做法：
##   · 关卡加载时把所有会挡人的 StaticBody2D（collision_layer & BLOCK_MASK）的矩形 / 圆形
##     碰撞体向外扩一个角色半径，栅格化成 0.5 米一格的可走 / 不可走网格。
##   · 网格建在**像素空间**：x 方向 1 格 = 0.5m × 64px，y 方向 = 0.5m × 64px × 0.62（斜俯视压缩），
##     碰撞判定也在像素空间做，和 move_and_slide 用的是同一套几何，不会出现「米坐标对了、像素撞墙」。
##   · 静态关卡只烘一次，所有角色共享；每个角色用 NavGrid.Agent 存自己的路径。
##   · 目标点在障碍里 / 不可达时用 partial path 走到最近的可达点，不会原地撞墙。
##
## 用法（NightExplore._ready 里建好，角色通过 ctl.nav 拿到）：
##     var wp: Vector2 = _agent.next(ctl.nav, global_position, target, delta)
##     # 然后照旧朝 wp 直线移动

const PPM := 64.0
const SQ := 0.62
const CELL_M := 0.5
const CELL := Vector2(CELL_M * PPM, CELL_M * PPM * SQ)
## 会挡住角色移动的物理层：1 墙 / 2 低矮掩体 / 3 铁丝网（角色的 collision_mask = 7）
const BLOCK_MASK := 7

var astar := AStarGrid2D.new()
var size := Vector2i.ZERO
var solid_count := 0


## root：关卡根节点；bounds_px：地面大图的像素尺寸；agent_r：角色碰撞圆半径（像素）。
func build(root: Node, bounds_px: Vector2, agent_r: float = 13.0) -> void:
	size = Vector2i(int(ceil(bounds_px.x / CELL.x)), int(ceil(bounds_px.y / CELL.y)))
	astar.region = Rect2i(Vector2i.ZERO, size)
	astar.cell_size = CELL
	astar.offset = CELL * 0.5                      # get_point_path 直接返回格心像素坐标
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	solid_count = 0
	for body in _blocking_bodies(root):
		for cs in body.get_children():
			if cs is CollisionShape2D and not (cs as CollisionShape2D).disabled and (cs as CollisionShape2D).shape != null:
				_stamp(cs as CollisionShape2D, agent_r)


func _blocking_bodies(root: Node) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is StaticBody2D and ((n as StaticBody2D).collision_layer & BLOCK_MASK) != 0:
			out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out


## 把一个碰撞体（扩 agent_r）盖到网格上：只遍历它包围盒覆盖的格子。
func _stamp(cs: CollisionShape2D, agent_r: float) -> void:
	var xf := cs.global_transform
	var inv := xf.affine_inverse()
	var sc := xf.get_scale().abs()
	var rx := agent_r / maxf(sc.x, 0.001)
	var ry := agent_r / maxf(sc.y, 0.001)
	var shape := cs.shape
	var local_box: Rect2
	if shape is RectangleShape2D:
		var ext := (shape as RectangleShape2D).size * 0.5
		local_box = Rect2(-ext - Vector2(rx, ry), (ext + Vector2(rx, ry)) * 2.0)
	elif shape is CircleShape2D:
		var rr := (shape as CircleShape2D).radius
		local_box = Rect2(-Vector2(rr + rx, rr + ry), Vector2(rr + rx, rr + ry) * 2.0)
	else:
		return
	# 局部包围盒 → 世界包围盒 → 格子范围
	var pts := [local_box.position, Vector2(local_box.end.x, local_box.position.y),
		local_box.end, Vector2(local_box.position.x, local_box.end.y)]
	var wmin := Vector2(INF, INF)
	var wmax := Vector2(-INF, -INF)
	for p in pts:
		var wp: Vector2 = xf * (p as Vector2)
		wmin = wmin.min(wp)
		wmax = wmax.max(wp)
	var c0 := cell_of(wmin)
	var c1 := cell_of(wmax)
	for cy in range(maxi(c0.y, 0), mini(c1.y, size.y - 1) + 1):
		for cx in range(maxi(c0.x, 0), mini(c1.x, size.x - 1) + 1):
			var c := Vector2i(cx, cy)
			if astar.is_point_solid(c):
				continue
			var lp: Vector2 = inv * center_px(c)
			var hit := false
			if shape is RectangleShape2D:
				var ext2 := (shape as RectangleShape2D).size * 0.5
				hit = absf(lp.x) <= ext2.x + rx and absf(lp.y) <= ext2.y + ry
			else:
				var r2 := (shape as CircleShape2D).radius
				# 椭圆扩张（局部缩放不等时 rx≠ry）
				var q := Vector2(lp.x / (r2 + rx), lp.y / (r2 + ry))
				hit = q.length_squared() <= 1.0
			if hit:
				astar.set_point_solid(c, true)
				solid_count += 1


func cell_of(px: Vector2) -> Vector2i:
	return Vector2i(int(floor(px.x / CELL.x)), int(floor(px.y / CELL.y)))


func center_px(c: Vector2i) -> Vector2:
	return Vector2((float(c.x) + 0.5) * CELL.x, (float(c.y) + 0.5) * CELL.y)


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y


func walkable(c: Vector2i) -> bool:
	return in_bounds(c) and not astar.is_point_solid(c)


func walkable_px(px: Vector2) -> bool:
	return walkable(cell_of(px))


## 最近的可走格（角色贴墙站着时自己所在的格可能被扩张盖住）。找不到返回 (-1,-1)。
func nearest_walkable(c: Vector2i, max_r: int = 6) -> Vector2i:
	if walkable(c):
		return c
	for r in range(1, max_r + 1):
		var best := Vector2i(-1, -1)
		var bd := INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n := c + Vector2i(dx, dy)
				if walkable(n):
					var d := Vector2(dx * CELL.x, dy * CELL.y).length_squared()
					if d < bd:
						bd = d
						best = n
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


## 两点之间是否一路可走（按 1/3 格步长采样网格）。
func line_clear(a: Vector2, b: Vector2) -> bool:
	var d := b - a
	var steps := int(ceil(maxf(absf(d.x) / CELL.x, absf(d.y) / CELL.y) * 3.0))
	if steps <= 0:
		return walkable_px(a)
	for i in steps + 1:
		if not walkable_px(a + d * (float(i) / float(steps))):
			return false
	return true


## 像素坐标路径（不含起点格心）。目标不可达时走到离它最近的可达点。
func path_px(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := nearest_walkable(cell_of(from))
	var b := nearest_walkable(cell_of(to), 10)
	if a.x < 0 or b.x < 0:
		return PackedVector2Array()
	var pts := astar.get_point_path(a, b, true)
	if pts.size() > 0 and cell_of(pts[0]) == cell_of(from):
		pts.remove_at(0)
	return pts


## ============================================================================
## 每个角色一份：路径缓存 + 错开的重算节奏 + 卡住检测
## ============================================================================
class Agent:
	const REPATH := 0.35          ## 正常重算间隔（秒）
	const WP_REACH := 9.0         ## 到达路点的像素半径
	const GOAL_SLACK := 32.0      ## 目标挪动超过一格（x 向 0.5m）才提前重算
	var path := PackedVector2Array()
	var goal := Vector2.INF
	var direct := false           ## 上次判定：目标直线可达
	var _t := 0.0
	var _stuck_t := 0.0
	var _last_pos := Vector2.INF

	func _init() -> void:
		_t = randf() * REPATH       # 错开：别让十只狂暴者在同一帧一起算路

	## 给出这一帧应该朝哪个点直线移动。nav 为 null（老场景 / 测试替身）时直接返回目标。
	func next(nav, pos: Vector2, target: Vector2, delta: float) -> Vector2:
		if nav == null:
			return target
		_t -= delta
		# 卡住检测：0.6 秒几乎没动 → 立刻重算（被推挤 / 路点在扩张边缘）
		if _last_pos != Vector2.INF and pos.distance_squared_to(_last_pos) < 0.25:
			_stuck_t += delta
		else:
			_stuck_t = 0.0
		_last_pos = pos
		var moved_goal := goal == Vector2.INF or goal.distance_to(target) > GOAL_SLACK
		if _t <= 0.0 or (moved_goal and _t <= REPATH * 0.5) or _stuck_t > 0.6:
			_t = REPATH
			_stuck_t = 0.0
			goal = target
			direct = nav.line_clear(pos, target)
			path = PackedVector2Array() if direct else nav.path_px(pos, target)
		if direct or path.is_empty():
			return target
		# 到了就弹出路点；能直接看到下一个路点就跳过当前的（拉直）
		while path.size() > 0 and pos.distance_to(path[0]) <= WP_REACH:
			path.remove_at(0)
		if path.size() >= 2 and nav.line_clear(pos, path[1]):
			path.remove_at(0)
		if path.is_empty():
			return target
		return path[0]

	func clear() -> void:
		path = PackedVector2Array()
		goal = Vector2.INF
		_t = 0.0
