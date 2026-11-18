extends CharacterBody2D
## NightSoldier.gd — 内务清杀兵（ОСК）：巡逻 → 起疑 → 调查 → 搜索 → 警戒。
##
## 视野 = 手电锥（45° 全角，11m；玩家开手电时 ×1.3）。感知走 NightExplore.can_see_player()
## （射线检测：墙/车厢/煤水塔挡视线；玩家蹲下时低矮掩体也挡）。
## 警戒状态下持续看到玩家 0.9s 后开火；枪击造成伤害，归零才会击倒玩家。
## 借刀杀人：光锥里（或 2.5m 内）出现狂暴者 → 停步瞄准 0.5s → 点射击毙；枪声 10m 会引来别的狂暴者。

const PPM := 64.0
const SQ := 0.62
const VIEW_RANGE := 11.0
const VIEW_HALF := deg_to_rad(22.5)
const SPEED_PATROL := 1.45
const SPEED_INVESTIGATE := 2.1
const SPEED_ALERT := 3.1
const AIM_TIME := 0.5
const SHOOT_RANGE := 14.0
const MARKET_STANDOFF_M := 20.0 # 仅巡逻路点避让黑市；一旦有调查/警戒目标就改以目标为准，否则会背对近处玩家

@export var route: PackedVector2Array = PackedVector2Array()   # 像素坐标
@export_enum("loop", "pingpong") var mode := "loop"
@export var pause_time := 2.0

const NavGridScript := preload("res://scripts/night/NavGrid.gd")
var _nav = NavGridScript.Agent.new()   # 自己的路径缓存（共享网格在 ctl.nav）

var ctl
var state := "patrol"        # patrol | pause | investigate | search | alert
var facing := 0.0
var suspicion := 0.0
var seen_time := 0.0
var lost_time := 0.0
var target := Vector2.ZERO
var aim := 0.0
var aim_target: Node2D = null
var kills := 0
var hp := 100.0                 # P5：清杀兵也会被打死（撬棍 3 下 / 莫辛 1 枪）
var dead := false
var loot_weapon_id := "rifle"  # 清杀兵尸体可搜缴的武器
var _player_fire_t := 0.7
var _player_engaged := false

var _wp := 0
var _dir := 1
var _timer := 0.0
var _look_base := 0.0
var _anim := 0.0
var _moving := false
var _command_stop_t := 0.0

@onready var sprite: Sprite2D = $Sprite
@onready var flash_pivot: Node2D = $Flashlight/Pivot
@onready var muzzle: PointLight2D = $Muzzle

func _ready() -> void:
	if route.size() > 0:
		global_position = route[0]
		_wp = mini(1, route.size() - 1)
		var d := route[_wp] - route[0]
		facing = atan2(d.y / SQ, d.x)

func _physics_process(delta: float) -> void:
	if ctl == null:
		return
	if dead:
		velocity = Vector2.ZERO
		sprite.modulate.a = maxf(0.42, sprite.modulate.a - delta * 0.22)
		return
	if ctl.state != "play":
		velocity = Vector2.ZERO
		_moving = false
		_animate(delta, 1.0)
		return
	_perceive(delta)
	muzzle.energy = maxf(0.0, muzzle.energy - delta * 30.0)
	if _command_stop_t > 0.0:
		_command_stop_t = maxf(0.0, _command_stop_t - delta)
		velocity = Vector2.ZERO
		_moving = false
		flash_pivot.rotation = facing
		_animate(delta, 1.0)
		return
	if _engage_rabids(delta):
		velocity = Vector2.ZERO
		_moving = false
		flash_pivot.rotation = facing
		_animate(delta, 1.0)
		return
	var spd := 0.0
	match state:
		"patrol":
			spd = SPEED_PATROL
			if _move_to(route[_wp], spd):
				_arrive_waypoint()
		"pause":
			_timer -= delta
			facing = wrapf(_look_base + sin(_timer * 1.7) * 0.9, -PI, PI)
			if _timer <= 0.0:
				_next_waypoint()
				state = "patrol"
		"investigate":
			spd = SPEED_INVESTIGATE
			if _move_to(target, spd):
				state = "search"
				_timer = 3.5
				_look_base = facing
		"search":
			_timer -= delta
			facing = wrapf(_look_base + sin(_timer * 2.3) * 1.3, -PI, PI)
			if _timer <= 0.0:
				_resume_route()
		"alert":
			spd = SPEED_ALERT
			_move_to(target, spd, 26.0)
	if state in ["pause", "search"] or (state == "alert" and velocity.length() < 1.0):
		velocity = Vector2.ZERO
	_moving = velocity.length() > 4.0
	flash_pivot.rotation = facing
	_animate(delta, maxf(spd, 0.1) / SPEED_PATROL)
	if ctl != null and ctl.has_method("ai_step"):
		ctl.ai_step(self, delta)

func _perceive(delta: float) -> void:
	var vis: float = ctl.can_see_player(global_position, VIEW_RANGE, VIEW_HALF, facing, false)
	if vis > 0.0:
		suspicion = minf(1.2, suspicion + vis * 1.25 * delta)
		lost_time = 0.0
		if suspicion > 0.35 and state != "alert":
			if state not in ["investigate", "search"] and ctl.has_method("on_soldier_warning"):
				ctl.on_soldier_warning(self)
			state = "investigate"
			target = ctl.player.global_position
		if suspicion >= 1.0:
			if state != "alert":
				ctl.on_soldier_alert(self)
			state = "alert"
			target = ctl.player.global_position
			seen_time += delta
			var to_p: Vector2 = ctl.player.global_position - global_position
			facing = lerp_angle(facing, atan2(to_p.y / SQ, to_p.x), minf(1.0, 8.0 * delta))
			if seen_time >= 0.9:
				if not _player_engaged:
					_player_engaged = true
					ctl.on_soldier_opened_fire(self)
				_player_fire_t -= delta
				if _player_fire_t <= 0.0:
					_player_fire_t = 1.45
					ctl.soldier_fire_player(self, ctl.player.global_position)
	else:
		seen_time = maxf(0.0, seen_time - delta * 0.5)
		suspicion = maxf(0.0, suspicion - (0.08 if state == "alert" else 0.22) * delta)
		if state == "alert":
			lost_time += delta
			if lost_time > 3.0:
				state = "search"
				_timer = 4.0
				_look_base = facing
				suspicion = 0.6

## 光锥里的狂暴者 / 半人：返回 true 表示本帧在瞄准 / 射击（停止移动）。
func _engage_rabids(delta: float) -> bool:
	var best: Node2D = null
	var bd := INF
	# 清杀队分不清狂暴者和回退半人：光锥里的「感染者」一律开枪（半人喂过药、睡着了就认不出来）
	for r in ctl.rabids + ctl.halfs:
		if not r.is_alive() or (r.has_method("is_target") and not r.is_target()):
			continue
		var dm := Vector2((r.global_position.x - global_position.x) / PPM,
			(r.global_position.y - global_position.y) / (PPM * SQ))
		var dist := dm.length()
		if dist > SHOOT_RANGE:
			continue
		var in_cone := absf(angle_difference(facing, dm.angle())) <= VIEW_HALF or dist < 2.5
		if not in_cone or not ctl.los_clear(global_position, r.global_position, 1):
			continue
		if dist < bd:
			bd = dist
			best = r
	if best == null:
		aim = maxf(0.0, aim - delta * 2.0)
		aim_target = null
		return false
	if best != aim_target:
		aim_target = best
		aim = 0.0 if bd > 1.2 else AIM_TIME      # 贴脸直接开火
	var to_r := best.global_position - global_position
	facing = lerp_angle(facing, atan2(to_r.y / SQ, to_r.x), minf(1.0, 10.0 * delta))
	aim += delta
	if aim >= AIM_TIME:
		aim = 0.0
		aim_target = null
		kills += 1
		muzzle.energy = 3.2
		best.die(String(name))
		ctl.on_soldier_fired(self, best.global_position)
		target = best.global_position
		if state != "alert":
			state = "investigate"
	return true

func hear(pos: Vector2, kind: String) -> void:
	if state == "alert":
		return
	target = pos
	state = "investigate"
	suspicion = maxf(suspicion, 0.3 if kind == "can" else 0.18)

func alert_to(pos: Vector2, report := true) -> void:
	if report and state != "alert" and ctl != null and ctl.has_method("on_soldier_alert"):
		ctl.on_soldier_alert(self)
	target = pos
	state = "alert"
	suspicion = maxf(suspicion, 1.0)
	lost_time = 0.0

func command_stop(seconds: float) -> void:
	_command_stop_t = maxf(_command_stop_t, seconds)
	velocity = Vector2.ZERO
	_moving = false

func _move_to(p: Vector2, spd_m: float, arrive_px: float = 6.0) -> bool:
	# 有调查/警戒目标时，朝向和移动都以目标为准；黑市 standoff 只用于无目标的巡逻路点。
	# 否则 standoff 会把追向玩家的脚步和手电一起拽向黑市反方向，让玩家永远落在视锥外。
	var pursuing := state in ["investigate", "alert"]
	if not pursuing:
		p = _market_standoff_goal(p)
	var d := p - global_position
	if d.length() <= arrive_px:
		velocity = Vector2.ZERO
		return true
	# 绕障：有共享网格就朝下一个路点走，直线可达时路点就是目标本身
	var wp: Vector2 = _nav.next(ctl.get("nav") if ctl != null else null, global_position, p,
		get_physics_process_delta_time())
	if not pursuing:
		wp = _market_standoff_goal(wp)
	var dw := wp - global_position
	var dm := Vector2(dw.x / PPM, dw.y / (PPM * SQ)).normalized()
	velocity = Vector2(dm.x * PPM, dm.y * PPM * SQ) * spd_m
	move_and_slide()
	var face_dir: Vector2 = dm
	if pursuing:
		var to_target := Vector2((p.x - global_position.x) / PPM,
			(p.y - global_position.y) / (PPM * SQ))
		if to_target.length_squared() > 0.0001:
			face_dir = to_target.normalized()
	facing = lerp_angle(facing, atan2(face_dir.y, face_dir.x), 0.18)
	return false


func _market_standoff_goal(destination: Vector2) -> Vector2:
	if ctl == null:
		return destination
	for market in ctl.markets:
		if not is_instance_valid(market):
			continue
		var market_node := market as Node2D
		var from_market := Vector2((global_position.x - market_node.global_position.x) / PPM,
			(global_position.y - market_node.global_position.y) / (PPM * SQ))
		var to_goal := Vector2((destination.x - market_node.global_position.x) / PPM,
			(destination.y - market_node.global_position.y) / (PPM * SQ))
		var closest := to_goal
		var segment := to_goal - from_market
		if segment.length_squared() > 0.0001:
			var along := clampf(-from_market.dot(segment) / segment.length_squared(), 0.0, 1.0)
			closest = from_market + segment * along
		if from_market.length() >= MARKET_STANDOFF_M \
			and to_goal.length() >= MARKET_STANDOFF_M \
			and closest.length() >= MARKET_STANDOFF_M - 0.05:
			continue
		var away := from_market
		if away.length_squared() < 0.01:
			away = -to_goal
		if away.length_squared() < 0.01:
			away = Vector2.RIGHT
		var safe_offset := away.normalized() * MARKET_STANDOFF_M
		destination = market_node.global_position + Vector2(safe_offset.x * PPM, safe_offset.y * PPM * SQ)
	return destination

func _arrive_waypoint() -> void:
	var at_end := mode == "loop" or _wp == 0 or _wp == route.size() - 1
	if at_end:
		state = "pause"
		_timer = pause_time
		_look_base = facing
	else:
		_next_waypoint()

func _next_waypoint() -> void:
	if route.size() < 2:
		return
	if mode == "loop":
		_wp = (_wp + 1) % route.size()
	else:
		if _wp + _dir >= route.size() or _wp + _dir < 0:
			_dir = -_dir
		_wp += _dir

func _resume_route() -> void:
	var best := 0
	var bd := INF
	for i in route.size():
		var dd := global_position.distance_to(route[i])
		if dd < bd:
			bd = dd
			best = i
	_wp = best
	state = "patrol"
	suspicion = minf(suspicion, 0.3)

## 中弹 / 中棍：掉血、立刻转警戒；血打空就是尸体（不会再抓人，也不会再开枪）。
func hit(dmg: float, by: String) -> void:
	if dead:
		return
	hp -= dmg
	if ctl != null:
		ctl.on_soldier_hurt(self, by)
	if hp <= 0.0:
		die(by)
		return
	state = "alert"
	suspicion = 1.0
	lost_time = 0.0
	seen_time = 0.0
	if ctl != null:
		target = ctl.player.global_position


func die(by: String) -> void:
	if dead:
		return
	dead = true
	state = "dead"
	velocity = Vector2.ZERO
	aim_target = null
	collision_layer = 0
	collision_mask = 0
	flash_pivot.rotation = facing
	if muzzle != null:
		muzzle.energy = 0.0
	sprite.frame = sprite.frame - sprite.frame % 12 + 11   # 11 = 倒地尸体
	if ctl != null:
		ctl.on_soldier_killed(self, by)


func is_alive() -> bool:
	return not dead


func _animate(delta: float, k: float) -> void:
	var deg := rad_to_deg(wrapf(facing, -PI, PI))
	var row := 0
	sprite.flip_h = false
	if absf(deg) <= 50.0:
		row = 1
	elif absf(deg) >= 130.0:
		row = 1
		sprite.flip_h = true
	elif deg > 0.0:
		row = 0
	else:
		row = 2
	if _moving:
		_anim += delta * k
	# 12 列：0 待机 / 1-8 行走 / 9 掎枪暗准 / 10 搜索 / 11 倒地
	var col := 0 if not _moving else 1 + int(_anim * 6.0) % 8
	if aim_target != null and not dead:
		col = 9
	sprite.frame = row * 12 + col
