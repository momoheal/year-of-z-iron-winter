extends CPUParticles2D
## Breath.gd — 严寒呼吸白气（可复用节点）：挂在玩家 / 伙伴 / 夜潜 NPC 嘴部，
## 每 ~3.4s 呼出一小团白雾（软圆粒子，上升 + 膨胀 + 淡出）。one_shot + 随机相位周期 restart，
## 避免所有实体同步呼气。纯视觉氛围，不影响玩法与性能（每实体 amount=6、短寿命）。
##
## 贴图：以前用的 VFX_Light_Radial_Soft.png 是给 PointLight2D 用的「黑底无 alpha」灯光图，
## 拿来当普通粒子贴图时黑底会原样画出来 —— 每口气都是一个半透明方块。
## 现在改用程序生成的径向渐变（中心不透明 → 边缘 alpha 0），所有 Breath 共用一张，
## 不依赖导入管线，边缘必然是圆的。

@export var period := 3.4
var _t := 0.0

static var _puff: GradientTexture2D


## 软圆白雾贴图（64×64，alpha 径向衰减）。静态缓存：全场景只生成一次。
static func puff_texture() -> Texture2D:
	if _puff == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([
			Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.32), Color(1, 1, 1, 0.0)])
		_puff = GradientTexture2D.new()
		_puff.gradient = g
		_puff.width = 64
		_puff.height = 64
		_puff.fill = GradientTexture2D.FILL_RADIAL
		_puff.fill_from = Vector2(0.5, 0.5)
		_puff.fill_to = Vector2(0.5, 0.0)       # 半径 = 半张图：四角落在 alpha 0 之外
	return _puff


func _ready() -> void:
	amount = 6
	lifetime = 1.6
	one_shot = true
	explosiveness = 0.55
	emitting = false
	texture = puff_texture()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR    # 项目默认最近邻，白雾要柔边
	direction = Vector2(0.25, -1.0)
	spread = 24.0
	gravity = Vector2(0, -10)
	initial_velocity_min = 10.0
	initial_velocity_max = 24.0
	damping_min = 6.0
	damping_max = 10.0
	scale_amount_min = 0.22
	scale_amount_max = 0.42
	# 呼出后逐渐散开变大
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.45))
	grow.add_point(Vector2(1.0, 1.6))
	scale_amount_curve = grow
	z_index = 5
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	grad.colors = PackedColorArray([
		Color(0.9, 0.94, 1.0, 0.0), Color(0.9, 0.94, 1.0, 0.42), Color(0.9, 0.94, 1.0, 0.0)])
	color_ramp = grad
	_t = randf_range(0.0, period)      # 随机相位，避免同步呼气


func _process(delta: float) -> void:
	_t += delta
	if _t >= period:
		_t = 0.0
		restart()
