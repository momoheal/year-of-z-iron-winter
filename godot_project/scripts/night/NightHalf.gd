extends CharacterBody2D
## NightHalf.gd — 回退半人（CHR_04）：高烧正在退的感染者。还有瞳孔、不咬人，只会发抖和呻吟。
##
## 三态辨识的第三态（狂暴者 / 半人 / 求救者）：
##   * 清杀队分不清他和狂暴者 —— 光锥里一出现就开枪（NightSoldier._engage_rabids），记一次「误杀」。
##   * 他被罐头 / 搜刮的声音吸引，慢慢挪过去；听见枪声就抱头逃开。
##     所以「借刀杀人」引狂暴者进光锥时，也可能顺带把他引过去 —— 这是代价。
##   * 狂暴者把他当同类，不理他。
## 玩家靠近按 E 打开抉择（NightExplore.open_choice）：喂药退烧 / 绕开 / 撬棍灭口。

const PPM := 64.0
const SQ := 0.62
const DRIFT_SPEED := 0.7
const FLEE_SPEED := 1.6

@export var tag := "0388"           # 调度单上的编号（他的名字还没人知道）

var ctl
var state := "huddle"               # huddle | drift | flinch | saved | dead
var resolved := ""                  # "" | saved | left | mercy | osk —— 玩家抉择 / 结局
var hp := 60.0
var facing := PI / 2.0
var target := Vector2.ZERO
var killed_by := ""

var _timer := 0.0
var _moan := 0.0
var _anim := 0.0
var _rng := RandomNumberGenerator.new()

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	_rng.randomize()
	_moan = 1.5 + _rng.randf() * 3.0

func _physics_process(delta: float) -> void:
	if state == "dead":
		return
	if ctl == null or ctl.state != "play":
		velocity = Vector2.ZERO
		_animate(delta, false)
		return
	match state:
		"drift":
			_timer -= delta
			if _move_to(target, DRIFT_SPEED, 24.0) or _timer <= 0.0:
				state = "huddle"
		"flinch":
			_timer -= delta
			var away := _px2m(global_position - target).normalized()
			if away == Vector2.ZERO:
				away = Vector2(0, -1)
			_move_to(global_position + _m2px(away * 2.0), FLEE_SPEED)
			if _timer <= 0.0:
				state = "huddle"
		_:
			velocity = Vector2.ZERO
	# 呻吟：淡琥珀声纹（只是给玩家的提示，谁也不惊动）
	if state != "saved":
		_moan -= delta
		if _moan <= 0.0:
			_moan = 3.5 + _rng.randf() * 2.5
			ctl.emit_noise(global_position, 2.2, "half")
	_animate(delta, velocity.length() > 4.0)

func hear(pos: Vector2, kind: String) -> void:
	if state in ["dead", "saved"]:
		return
	if kind == "gun":
		state = "flinch"
		target = pos
		_timer = 2.2
	elif kind in ["can", "search"] and state != "flinch":
		state = "drift"
		target = pos
		_timer = 12.0

## 喂过药：缩回蒸汽管下的雪窝里睡着，清杀队的光锥扫过也认不出他。
func save() -> void:
	state = "saved"
	resolved = "saved"
	velocity = Vector2.ZERO
	collision_layer = 0
	sprite.self_modulate = Color(1.0, 0.94, 0.86)

## 清杀队会不会朝他开枪
func is_target() -> bool:
	return state != "dead" and state != "saved"

func hit(dmg: float, by: String) -> void:
	if state == "dead":
		return
	hp -= dmg
	if hp <= 0.0:
		die(by)
	else:
		state = "flinch"
		_timer = 1.5

func die(by: String) -> void:
	if state == "dead":
		return
	state = "dead"
	killed_by = by
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	sprite.position = Vector2.ZERO
	sprite.frame = sprite.frame - sprite.frame % 8 + 6
	sprite.self_modulate = Color(0.75, 0.75, 0.78)
	ctl.on_half_killed(self, by)

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
	facing = lerp_angle(facing, atan2(dm.y, dm.x), 0.15)
	return false

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
	_anim += delta
	var col := 5
	if state == "flinch":
		col = 7 if not moving else 1 + int(_anim * 9.0) % 4
	elif moving:
		col = 1 + int(_anim * 4.5) % 4
	elif state == "saved":
		col = 5
		row = 0
	# 高烧发抖：没睡着的时候一直在抖
	sprite.position.x = sin(_anim * 37.0) * 0.6 if state in ["huddle", "drift"] else 0.0
	sprite.frame = row * 8 + col
