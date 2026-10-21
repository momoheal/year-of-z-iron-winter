extends CharacterBody2D
class_name WolfdogAsh
## Companion AI for Siberian Wolfdog "Ash" (Пепел).
## Trails 1.5m (96px) behind Aleksei (ignoring player collision on Layer 5)
## and provides 100% accurate Tri-State Olfactory identification.

enum OlfactoryState {
	FOLLOW_IDLE,
	BARK_RABID,        # Type I: Febrile Rabid (>40C) -> Bristles & Barks
	WHIMPER_REGRESSING,# Type II: Regressing Half-Human (Choice A / Anna 0419) -> Whimpers
	WAG_CIVILIAN       # Type III: Recovered / Desperate Kin -> Wags Tail & Touches Boot
}

@export var player_target: Node2D
const FOLLOW_DIST_PX: float = 96.0 # 1.5 meters
const MOVE_SPEED: float = 210.0

var current_state: OlfactoryState = OlfactoryState.FOLLOW_IDLE
signal olfactory_state_changed(new_state: OlfactoryState)

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player_target):
		return
	var to_player: Vector2 = player_target.global_position - global_position
	if to_player.length() > FOLLOW_DIST_PX:
		velocity = to_player.normalized() * MOVE_SPEED
		move_and_slide()
	else:
		velocity = Vector2.ZERO

func evaluate_nearby_entity(entity_category: String) -> void:
	var next_state: OlfactoryState = OlfactoryState.FOLLOW_IDLE
	match entity_category:
		"RABID":
			next_state = OlfactoryState.BARK_RABID
		"REGRESSING_HALF_HUMAN":
			next_state = OlfactoryState.WHIMPER_REGRESSING
		"RECOVERED_CIVILIAN":
			next_state = OlfactoryState.WAG_CIVILIAN
	if next_state != current_state:
		current_state = next_state
		emit_signal("olfactory_state_changed", current_state)
