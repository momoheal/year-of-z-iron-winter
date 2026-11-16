extends Node2D
## NightSearchlight.gd — 货场探照灯塔：在扇区内往复扫描；照到玩家后锁定跟踪并呼叫清杀队。
##
## 节点放在灯塔脚下（地面投影点），视线检测从这里出发：车厢 / 煤水塔 / 报废车能挡住光束。
## 判定与 OSK 共用锥形视线、单位换算和遮挡射线；探照灯范围仍按各关卡单独配置。
## 光束里蹲下没用，只有躲在低矮掩体后面蹲下才不算被照到。

const SQ := 0.62
const BEAM_TEXTURE_HALF_DEG := 11.3

@export var sweep_min_deg := 146.0
@export var sweep_max_deg := 188.0
@export var period := 11.0
@export var range_m := 26.0
@export var half_deg := 11.0

var ctl
var angle := 0.0
var lock := 0.0
var tracking := false
var _t := 0.0
var _shadow_mask := -1

@onready var pivot: Node2D = $Rig/Pivot
@onready var rig: Node2D = $Rig
@onready var ground_light: PointLight2D = $Rig/Pivot/Ground
@onready var objects_light: PointLight2D = $Rig/Pivot/Objects

func _ready() -> void:
	angle = deg_to_rad((sweep_min_deg + sweep_max_deg) * 0.5)
	# The beam texture has a baked-in ~11.3° half-angle. Scale only its
	# vertical axis so the rendered footprint matches the detection cone.
	var half := deg_to_rad(clampf(half_deg, 1.0, 45.0))
	var texture_half := deg_to_rad(BEAM_TEXTURE_HALF_DEG)
	rig.scale = Vector2(1.0, SQ * tan(half) / tan(texture_half))

func _physics_process(delta: float) -> void:
	if ctl == null:
		return
	_sync_light_occlusion()
	_t += delta
	var playing: bool = ctl.state == "play"
	if tracking and playing:
		var to_p: Vector2 = ctl.player.global_position - global_position
		angle = lerp_angle(angle, atan2(to_p.y / SQ, to_p.x), minf(1.0, 3.0 * delta))
	else:
		var u := 0.5 + 0.5 * sin(_t * TAU / period)
		angle = lerp_angle(angle, deg_to_rad(lerpf(sweep_min_deg, sweep_max_deg, u)), minf(1.0, 2.0 * delta))
	pivot.rotation = angle
	if not playing:
		return
	var vis: float = ctl.can_see_player(global_position, range_m, deg_to_rad(half_deg), angle, true)
	if vis > 0.0:
		lock += delta
		if lock > 0.55 and not tracking:
			tracking = true
			ctl.raise_alarm(ctl.player.global_position, self)
		if tracking and lock > 2.6:
			ctl.caught(self)
	else:
		lock = maxf(0.0, lock - delta * 0.6)
		if tracking and lock <= 0.0:
			tracking = false

func _sync_light_occlusion() -> void:
	if ctl.player == null:
		return
	# Physics LOS ignores low cover for standing players and includes it while
	# crouching; mirror that mask in both rendered light passes.
	var mask := 1 | (2 if ctl.player.crouching else 0)
	if mask == _shadow_mask:
		return
	_shadow_mask = mask
	for light in [ground_light, objects_light]:
		light.shadow_enabled = true
		light.shadow_filter = 1
		light.shadow_filter_smooth = 1.5
		light.shadow_item_cull_mask = mask

## Used by NightExplore.is_lit() so illumination and OSK awareness share
## exactly the same cone geometry and obstruction rules.
func illuminates_point(point: Vector2) -> bool:
	if ctl == null or ctl.player == null:
		return false
	return ctl.has_clear_vision(global_position, point, range_m, deg_to_rad(half_deg), angle, true)
