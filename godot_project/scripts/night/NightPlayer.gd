extends CharacterBody2D
## NightPlayer.gd — 阿列克谢：移动 / 姿态 / 朝向 / 手电 / 脚步噪声 / 精灵表动画。
##
## 世界单位：屏幕像素；地面 1 米 = (64, 39.68) px。速度与噪声半径都按「逻辑米」给出。
## 精灵表 CHR_01_Aleksei_Sheet：12 列 × 3 行（S / E / N），W = E 水平翻转。

const NightLighting := preload("res://scripts/night/NightLighting.gd")
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
# 渲染插值：移动在物理帧（60 Hz）里算，显示器刷新率更高时画面会一顿一顿。
# 只把可见子节点按物理帧的插值比例平移到「上一帧 → 这一帧」之间，碰撞与逻辑位置不变。
var _prev_pos := Vector2.ZERO
var _cur_pos := Vector2.ZERO
var _visual_base: Array = []          # [[Node2D, 原始本地坐标], …]（不含碰撞体）

@onready var sprite: Sprite2D = $Sprite
@onready var flash_pivot: Node2D = $Flashlight/Pivot
@onready var flashlight: Node2D = $Flashlight

func _ready() -> void:
	_configure_flashlight_occlusion()
	for c in get_children():
		if c is Node2D and not (c is CollisionShape2D or c is CollisionPolygon2D):
			_visual_base.append([c, (c as Node2D).position])
	snap_visual()


## 传送（出生点、剧情挪位）后调用：插值从新位置重新开始，不会从旧位置滑过来。
func snap_visual() -> void:
	_prev_pos = global_position
	_cur_pos = global_position


## 本帧应该画在哪：物理位置在上一 tick 与这一 tick 之间按插值比例取点。
## 两个 tick 之间被代码直接改过位置（传送）就直接用当前位置。
func visual_position() -> Vector2:
	if global_position != _cur_pos:
		return global_position
	return _prev_pos.lerp(_cur_pos, clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0))


func _process(_delta: float) -> void:
	var off := visual_position() - global_position
	for pair in _visual_base:
		var n = pair[0]
		if is_instance_valid(n):
			n.position = pair[1] + off


func _configure_flashlight_occlusion() -> void:
	# The Objects pass lights characters and props; it must use the same wall
	# occluders as the ground pass or the visible cone leaks through walls.
	NightLighting.configure_objects_occlusion(flash_pivot)


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
	# 插值起点 = 本 tick 移动前的位置（期间若被传送，起点就是传送后的位置，不会从旧处滑过来）
	_prev_pos = global_position
	move_and_slide()
	_cur_pos = global_position
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
			# 脚印踩在「落脚」这一帧，和脚步声明明同步 ——
			# 一个 _step 是秒不是米（蹲 0.62 / 走 0.45 / 冲刺 0.3），
			# 实际步距约 0.71 / 1.17 / 1.32 米，肉眼刚好。
			ctl.footprint(global_position, facing)
			_step = 0.62 if crouching else (0.3 if sprinting else 0.45)
	else:
		_step = 0.0
	_animate(delta, spd)

func _animate(delta: float, spd: float) -> void:
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
	var col := 0
	if moving:
		_anim += delta * spd / SPEED_WALK
	# 12 列：0 待机 / 1-8 行走 / 9 蹲伏 / 10-11 蹲走
	if crouching:
		col = 9 if not moving else 10 + int(_anim * 4.0) % 2
	else:
		col = 0 if not moving else 1 + int(_anim * 7.0) % 8
	sprite.frame = row * 12 + col

func toggle_flashlight() -> void:
	flashlight_on = not flashlight_on
