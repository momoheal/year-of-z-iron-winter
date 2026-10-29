extends CharacterBody2D
## NightRabid.gd — 灰鳞高热狂暴者（CHR_03）：游荡 → 循声调查 → 追击 → 0.45s 起跳预警 → 扑咬。
##
## 三方关系（与 RaidSim 一致）：
##   * 狂暴者靠「声音」和近距离视线找人：脚步、搜刮、罐头、枪声都会把它引过去。
##   * 清杀兵光锥里出现狂暴者就会开枪（NightSoldier._engage_rabids）→ 借刀杀人。
##   * 枪声半径 10m，会再引来别的狂暴者 —— 连锁可以利用，也可能失控。
## 视线：360°，7m（玩家开手电 ×1.3，蹲下 ×0.7）；墙 / 车厢挡视线，蹲在低矮掩体后面也看不见。

const PPM := 64.0
const SQ := 0.62
const SIGHT := 7.0
const LUNGE_RANGE := 1.15
const WINDUP := 0.45

@export var brute := false
@export var home_radius := 2.5

var ctl
var state := "idle"          # idle | wander | investigate | chase | windup | lunge | dead
var hp := 100.0
var facing := PI / 2.0
var target := Vector2.ZERO
var home := Vector2.ZERO
var windup := 0.0            # 起跳预警进度（0..WINDUP），Overlay 画红圈
var cooldown := 0.0
var killed_by := ""

var _timer := 0.0
var _lost := 0.0
var _growl := 0.0
var _lunge_dir := Vector2.ZERO
var _anim := 0.0
var _rng := RandomNumberGenerator.new()

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	_rng.randomize()
	home = global_position
	hp = 180.0 if brute else 100.0
	_timer = _rng.randf() * 2.0
	_growl = 1.0 + _rng.randf() * 3.0
	if brute:
		sprite.scale = Vector2(1.14, 1.14)
		sprite.self_modulate = Color(0.82, 0.8, 0.8)

func _physics_process(delta: float) -> void:
	if state == "dead":
		return
	if ctl == null or ctl.state != "play":
		velocity = Vector2.ZERO
		_animate(delta, false)
		return
	cooldown = maxf(0.0, cooldown - delta)
	var p: Vector2 = ctl.player.global_position
	var sees: bool = ctl.rabid_sees_player(self)
	var d := _dist_m(p)
	var spd := 0.0
	match state:
		"idle":
			_timer -= delta
			if _timer <= 0.0:
				target = home + _m2px(Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * home_radius)
				state = "wander"
		"wander":
			spd = 0.9
			if _move_to(target, spd) or _timer < -6.0:
				state = "idle"
				_timer = 1.5 + _rng.randf() * 3.0
			_timer -= delta
		"investigate":
			spd = 2.1
			_timer -= delta
			if _move_to(target, spd, 18.0) or _timer <= 0.0:
				state = "idle"
				_timer = 2.0 + _rng.randf() * 2.0
				home = global_position.lerp(home, 0.5)   # 被引走后就在附近游荡
		"chase":
			spd = 3.3 * (0.72 if brute else 1.0)
			target = p
			_move_to(p, spd, 4.0)
			if d <= LUNGE_RANGE and cooldown <= 0.0:
				state = "windup"
				windup = 0.0
			if not sees:
				_lost += delta
				if _lost > 5.0 or d > 13.0:
					state = "investigate"
					_timer = 6.0
					_lost = 0.0
			else:
				_lost = 0.0
		"windup":
			velocity = Vector2.ZERO
			windup += delta
			_face_to(p)
			if windup >= WINDUP:
				state = "lunge"
				_timer = 0.2
				_lunge_dir = _px2m(p - global_position).normalized()
				ctl.on_rabid_lunge(self)      # 嘶吼（定位）+ 近距离的一震
		"lunge":
			_timer -= delta
			velocity = Vector2(_lunge_dir.x * PPM, _lunge_dir.y * PPM * SQ) * 7.0
			move_and_slide()
			if _dist_m(ctl.player.global_position) <= 1.0 and cooldown <= 0.0:
				cooldown = 1.6
				ctl.damage_player(15.0 if brute else 9.0, self)
			if _timer <= 0.0:
				state = "chase"
				windup = 0.0
				cooldown = maxf(cooldown, 0.6)
	if sees and state in ["idle", "wander", "investigate"]:
		state = "chase"
		ctl.on_rabid_spotted(self)
	# 低吼：暗红声纹（只是给玩家的提示，不惊动别人）
	_growl -= delta
	if _growl <= 0.0:
		_growl = (1.2 if state == "chase" else 2.6) + _rng.randf() * 2.0
		ctl.emit_noise(global_position, 3.2 if state != "chase" else 4.5, "rabid")
	_animate(delta, velocity.length() > 4.0)

func hear(pos: Vector2, kind: String) -> void:
	if state in ["dead", "chase", "windup", "lunge"] or kind == "rabid":
		return
	target = pos
	state = "investigate"
	_timer = 9.0

func hit(dmg: float, by: String) -> void:
	if state == "dead":
		return
	hp -= dmg
	if hp <= 0.0:
		die(by)
	else:
		state = "chase"

func die(by: String) -> void:
	state = "dead"
	killed_by = by
	windup = 0.0
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	sprite.frame = sprite.frame - sprite.frame % 8 + 6
	sprite.self_modulate = Color(0.75, 0.75, 0.78)
	ctl.on_rabid_killed(self, by)

func is_alive() -> bool:
	return state != "dead"

func _move_to(p: Vector2, spd_m: float, arrive_px: float = 6.0) -> bool:
	var d := p - global_position
	if d.length() <= arrive_px:
		velocity = Vector2.ZERO
		return true
	var dm := _px2m(d).normalized()
	velocity = Vector2(dm.x * PPM, dm.y * PPM * SQ) * spd_m
	move_and_slide()
	facing = lerp_angle(facing, atan2(dm.y, dm.x), 0.2)
	return false

func _face_to(p: Vector2) -> void:
	var dm := _px2m(p - global_position)
	facing = atan2(dm.y, dm.x)

func _dist_m(p: Vector2) -> float:
	return _px2m(p - global_position).length()

static func _px2m(v: Vector2) -> Vector2:
	return Vector2(v.x / PPM, v.y / (PPM * SQ))

static func _m2px(v: Vector2) -> Vector2:
	return Vector2(v.x * PPM, v.y * PPM * SQ)

func _animate(delta: float, moving: bool) -> void:
	var deg := rad_to_deg(facing)
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
	var col := 0
	if state in ["windup", "lunge"]:
		col = 5
	elif moving:
		_anim += delta * (1.6 if state == "chase" else 0.8)
		col = 1 + int(_anim * 7.0) % 4
	else:
		_anim += delta
		col = 7 if fmod(_anim, 2.4) < 0.25 else 0
	sprite.frame = row * 8 + col
