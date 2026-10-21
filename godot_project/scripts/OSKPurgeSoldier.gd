extends CharacterBody2D
class_name OSKPurgeSoldier
## MVD Special Sanitary Purge Detachment (ОСК) AI.
## Features a 45-deg Searchlight Cone (14m = 896px) and unconditional fire logic:
## Lured by Tin Can acoustic ripples ("Borrowing the Knife") to eliminate Rabid Infected.

const SEARCHLIGHT_RANGE_PX: float = 14.0 * 64.0
const SEARCHLIGHT_HALF_ANGLE_RAD: float = deg_to_rad(22.5)

var investigate_target: Vector2 = Vector2.ZERO
var alert_timer: float = 0.0

func _ready() -> void:
	AcousticRippleBus.ripple_emitted.connect(_on_acoustic_ripple)

func _on_acoustic_ripple(world_pos: Vector2, radius_px: float, ripple_type: String, _zh: String, _en: String) -> void:
	if global_position.distance_to(world_pos) <= radius_px + 220.0:
		if ripple_type in ["tin_can_lure", "sprint", "shotgun"]:
			investigate_target = world_pos
			alert_timer = 4.0
			look_at(investigate_target)

func can_see_target(target: Node2D) -> bool:
	if target.has_method("is_concealed_from_searchlight") and target.is_concealed_from_searchlight():
		return false
	var to_target: Vector2 = target.global_position - global_position
	if to_target.length() > SEARCHLIGHT_RANGE_PX:
		return false
	var forward: Vector2 = Vector2.RIGHT.rotated(global_rotation)
	var angle_diff: float = absf(forward.angle_to(to_target.normalized()))
	return angle_diff <= SEARCHLIGHT_HALF_ANGLE_RAD
