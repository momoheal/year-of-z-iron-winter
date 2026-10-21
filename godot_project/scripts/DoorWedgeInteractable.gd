extends StaticBody2D
class_name DoorWedgeInteractable
## Supports Aleksei's Railway Spike Crowbar (Лом) Door Wedge (Hold E 1.2s -> Lock 15.0s)
## and Under-Fence 12cm Gap Aluminum Lunchbox Push.

@export var is_wire_mesh_12cm_gap: bool = false
var wedged_time_remaining: float = 0.0
var lunchbox_pushed: bool = false

signal door_wedged(duration: float)
signal lunchbox_delivered()

func _process(delta: float) -> void:
	if wedged_time_remaining > 0.0:
		wedged_time_remaining = maxf(0.0, wedged_time_remaining - delta)

func apply_crowbar_wedge() -> void:
	wedged_time_remaining = 15.0
	emit_signal("door_wedged", wedged_time_remaining)

func push_lunchbox_under_12cm_gap() -> void:
	if is_wire_mesh_12cm_gap and not lunchbox_pushed:
		lunchbox_pushed = true
		LogbookManager.record_real_name(
			"north_canopy_loader",
			"北雨棚铁丝网门内高热装卸工 (已推入黑麦铝饭盒·存活)",
			"North Canopy Quarantined Loader (Fed Buckwheat Lunchbox · Alive)"
		)
		emit_signal("lunchbox_delivered")
