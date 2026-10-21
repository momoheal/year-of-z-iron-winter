extends CharacterBody2D
class_name PlayerAleksei
## 3C Controller for Aleksei Morozov (1m = 64px).
## Handles Crouch Stealth (Steam-Pipe Concealment), Tin Can Lure ("Borrowing the Knife"),
## Collarbone Blade Jam QTE (6 presses in 1.5s), and PTSD Thirst Tinnitus.

const PX_PER_M: float = 64.0
const SPEED_CROUCH: float = 1.6 * PX_PER_M
const SPEED_WALK: float = 3.2 * PX_PER_M
const SPEED_SPRINT: float = 5.0 * PX_PER_M

@export var glasses_cracked: bool = false
@export var current_weapon: String = "crowbar" # "crowbar" | "cleaver" | "shotgun"
@export var empty_tin_cans: int = 5

var is_crouching: bool = false
var in_steam_pipe_shadow: bool = false
var in_frozen_slush: bool = false
var heart_rate_bpm: float = 76.0

# Collarbone Blade Jam QTE State
var blade_jam_active: bool = false
var blade_jam_presses: int = 0
var blade_jam_timer: float = 0.0
const BLADE_JAM_REQUIRED: int = 6
const BLADE_JAM_WINDOW: float = 1.5

signal blade_jam_started()
signal blade_jam_progress(presses: int, required: int)
signal blade_jam_resolved(target_node: Node2D)

func _physics_process(delta: float) -> void:
	if blade_jam_active:
		_process_blade_jam_qte(delta)
		return

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	is_crouching = Input.is_action_pressed("crouch")
	var is_sprinting: bool = Input.is_action_pressed("sprint") and not is_crouching

	var spd: float = SPEED_WALK
	var ripple_m: float = 2.5
	if is_crouching:
		spd = SPEED_CROUCH
		ripple_m = 0.8
	elif is_sprinting:
		spd = SPEED_SPRINT
		ripple_m = 7.5

	if in_frozen_slush:
		spd *= 0.65
		ripple_m *= 2.0

	velocity = input_dir * spd
	move_and_slide()

	# Orient 90-deg vision cone toward cursor
	look_at(get_global_mouse_position())

	if input_dir.length_squared() > 0.01 and Engine.get_physics_frames() % 24 == 0:
		AcousticRippleBus.emit_sound_meters(global_position, ripple_m, "footstep")

func is_concealed_from_searchlight() -> bool:
	return is_crouching and in_steam_pipe_shadow

func throw_empty_tin_can(target_world_pos: Vector2) -> void:
	if empty_tin_cans <= 0:
		return
	empty_tin_cans -= 1
	# 9.0m metallic clang lures O.S.K. Purge Soldiers to eliminate Rabid Infected
	AcousticRippleBus.emit_sound_meters(
		target_world_pos,
		9.0,
		"tin_can_lure",
		"哐当！空沙丁鱼罐头声波 (9.0m)",
		"CLANG! Sardine Tin Lure (9.0m)"
	)

func trigger_collarbone_blade_jam() -> void:
	blade_jam_active = true
	blade_jam_presses = 0
	blade_jam_timer = BLADE_JAM_WINDOW
	heart_rate_bpm = 175.0
	emit_signal("blade_jam_started")

func _process_blade_jam_qte(delta: float) -> void:
	blade_jam_timer -= delta
	if Input.is_action_just_pressed("attack_primary"):
		blade_jam_presses += 1
		emit_signal("blade_jam_progress", blade_jam_presses, BLADE_JAM_REQUIRED)
		if blade_jam_presses >= BLADE_JAM_REQUIRED:
			blade_jam_active = false
			LogbookManager.ptsd_thirst_unlocked = true
			emit_signal("blade_jam_resolved", null)
	elif blade_jam_timer <= 0.0:
		# Reset timer for greybox forgiving retry or knockdown
		blade_jam_timer = BLADE_JAM_WINDOW

func drink_water() -> void:
	if LogbookManager.ptsd_thirst_unlocked:
		heart_rate_bpm = 152.0
		LogbookManager.emit_signal("ptsd_thirst_triggered")
	else:
		heart_rate_bpm = maxf(72.0, heart_rate_bpm - 15.0)
