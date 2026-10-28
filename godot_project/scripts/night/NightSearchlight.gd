extends Node2D
## NightSearchlight.gd — 货场探照灯塔：在扇区内往复扫描；照到玩家后锁定跟踪并呼叫清杀队。
##
## 节点放在灯塔脚下（地面投影点），视线检测从这里出发：车厢 / 煤水塔 / 报废车能挡住光束。
## 光束里蹲下没用，只有躲在低矮掩体后面蹲下才不算被照到。

const SQ := 0.62

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

@onready var pivot: Node2D = $Rig/Pivot

func _ready() -> void:
	angle = deg_to_rad((sweep_min_deg + sweep_max_deg) * 0.5)

func _physics_process(delta: float) -> void:
	if ctl == null:
		return
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
