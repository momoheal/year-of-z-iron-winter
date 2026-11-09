extends CPUParticles2D
## Breath.gd — 严寒呼吸白气（可复用节点）：挂在玩家 / 伙伴 / 夜潜 NPC 嘴部，
## 每 ~3.4s 呼出一小团白雾（软圆粒子，上升 + 淡出）。one_shot + 随机相位周期 restart，
## 避免所有实体同步呼气。纯视觉氛围，不影响玩法与性能（每实体 amount=5、短寿命）。

@export var period := 3.4
var _t := 0.0


func _ready() -> void:
	amount = 5
	lifetime = 1.5
	one_shot = true
	emitting = false
	texture = load("res://art/50_vfx/VFX_Light_Radial_Soft.png")
	direction = Vector2(0.25, -1.0)
	spread = 22.0
	gravity = Vector2(0, -12)
	initial_velocity_min = 12.0
	initial_velocity_max = 26.0
	scale_amount_min = 0.05
	scale_amount_max = 0.1
	z_index = 5
	var grad := Gradient.new()
	grad.set_color(0, Color(0.9, 0.94, 1.0, 0.4))
	grad.set_color(1, Color(0.9, 0.94, 1.0, 0.0))
	color_ramp = grad
	_t = randf_range(0.0, period)      # 随机相位，避免同步呼气


func _process(delta: float) -> void:
	_t += delta
	if _t >= period:
		_t = 0.0
		restart()
