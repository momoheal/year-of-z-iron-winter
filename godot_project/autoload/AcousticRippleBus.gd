extends Node
## Global Autoload: Broadcasts 2D Acoustic Ripples (Footsteps, Tin Can Lures,
## Suppressed AKM Bursts, and Regressing Half-Human Cries) across Novorsk-17.

signal ripple_emitted(world_pos: Vector2, radius_px: float, ripple_type: String, label_zh: String, label_en: String)

const PX_PER_METER: float = 64.0

func emit_sound_meters(world_pos: Vector2, radius_meters: float, ripple_type: String, label_zh: String = "", label_en: String = "") -> void:
	var radius_px: float = radius_meters * PX_PER_METER
	emit_signal("ripple_emitted", world_pos, radius_px, ripple_type, label_zh, label_en)
