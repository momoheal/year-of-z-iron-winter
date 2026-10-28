extends CharacterBody2D
## NightPlayer.gd — 阿列克谢：移动 / 姿态 / 朝向 / 手电 / 脚步噪声 / 精灵表动画。
##
## 世界单位：屏幕像素；地面 1 米 = (64, 39.68) px。速度与噪声半径都按「逻辑米」给出。
## 精灵表 CHR_01_Aleksei_Sheet：8 列 × 3 行（S / E / N），W = E 水平翻转。

const PPM := 64.0
const SQ := 0.62
const SPEED_WALK := 2.6
const SPEED_SNEAK := 1.15
const SPEED_SPRINT := 4.4
const NOISE_WALK := 2.5
const NOISE_SNEAK := 0.8
const NOISE_SPRINT := 7.5

var ctl                                # NightExplore
var facing := PI / 2.0                 # 世界角（0=东，PI/2=南）
var crouching := false
var sprinting := false
var moving := false
var on_slush := false
var flashlight_on := true
var frozen := false                    # 搜刮 / 撤离 / 结束时锁定移动

var _anim := 0.0
var _step := 0.0

@onready var sprite: Sprite2D = $Sprite
@onready var flash_pivot: Node2D = $Flashlight/Pivot
@onready var flashlight: Node2D = $Flashlight

func _physics_process(delta: float) -> void:
	if ctl == null:
		return
	var playing: bool = ctl.state == "play"
	var dir := Vector2.ZERO
	if playing and not frozen:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	crouching = playing and Input.is_action_pressed("crouch")
	sprinting = playing and not crouching and Input.is_action_pressed("sprint") and dir != Vector2.ZERO
	on_slush = ctl.is_slush(global_position)
	var spd := SPEED_SNEAK if crouching else (SPEED_SPRINT if sprinting else SPEED_WALK)
	if on_slush:
		spd *= 0.65
	velocity = Vector2(dir.x * PPM, dir.y * PPM * SQ) * spd
	move_and_slide()
	moving = dir != Vector2.ZERO and get_real_velocity().length() > 4.0

	# 朝向跟随鼠标（按地面坐标计算，抵消 y 压缩）
	var m := get_global_mouse_position() - global_position
	if m.length() > 6.0 and playing:
		facing = atan2(m.y / SQ, m.x)
	flash_pivot.rotation = facing
	flashlight.visible = flashlight_on

	# 脚步噪声
	if moving:
		_step -= delta
		if _step <= 0.0:
			var r := NOISE_SNEAK if crouching else (NOISE_SPRINT if sprinting else NOISE_WALK)
			if on_slush:
				r *= 2.0
			ctl.emit_noise(global_position, r, "step")
			_step = 0.62 if crouching else (0.3 if sprinting else 0.45)
	else:
		_step = 0.0
	_animate(delta, spd)

func _animate(delta: float, spd: float) -> void:
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
	if moving:
		_anim += delta * spd / SPEED_WALK
	if crouching:
		col = 5 if not moving else 6 + int(_anim * 4.0) % 2
	else:
		col = 0 if not moving else 1 + int(_anim * 7.0) % 4
	sprite.frame = row * 8 + col

func toggle_flashlight() -> void:
	flashlight_on = not flashlight_on
