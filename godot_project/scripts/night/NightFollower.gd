extends CharacterBody2D
## NightFollower.gd — 夜潜伙伴跟随者 + 伙伴实时特性。
##
## 跟随：Stand 立绘 + Walk0..Walk7 八帧步态 + 朝向翻转 + 走路浮动。
## 战役出发时由 RaidBridge.cfg.mate 决定带谁（"" = 没带，不生成）；
## F2 独立跑默认灰烬，可用 --mate=ash/anna/gulya/pavel/ivan/yelena/zakhar 指定。
##
## 实时特性（_update_perks，按 mate_id 分）：
##   ash  嗅觉：6m 内标出容器(📦)与生物；三态分辨——狂暴者"!"吠、半人"?"呜咽、幸存者"♥"摇尾。
##   anna 辨认半人：8m 内把半人标成"半人"黄字；狂暴者视听范围缩短由 NightExplore 处理。
##   ivan 撤离点常亮：在撤离点放常驻光圈 + "撤离"标记。
##   yelena 的 C 停步命令和 zakhar 的搜尸/抢掠/背叛均由 NightExplore 处理。
## 注：帕维尔撬锁 / 伊万显隐藏容器需要夜潜先引入"上锁 / 隐藏容器"机制（当前没有），另批做。

const Arsenal := preload("res://scripts/night/Arsenal.gd")
const COMPANION_WEAPONS := {
	"anna": "pistol", "gulya": "pistol", "pavel": "shotgun",
	"ivan": "rifle", "yelena": "rifle", "zakhar": "pistol",
}
const PORTRAITS := {
	"ash": "res://art/30_props/PRP_Ash_Stand.png",
	"anna": "res://art/30_props/PRP_Anna_Stand.png",
	"gulya": "res://art/30_props/PRP_Gulya_Stand.png",
	"pavel": "res://art/30_props/PRP_Pavel_Stand.png",
	"ivan": "res://art/30_props/PRP_Ivan_Stand.png",
	"yelena": "res://art/30_props/PRP_Yelena_Stand.png",
	"zakhar": "res://art/30_props/PRP_Zakhar_Stand.png",
}
const PIVOTS := {
	"ash": Vector2(48, 76),
	"anna": Vector2(36, 108),
	"gulya": Vector2(36, 108),
	"pavel": Vector2(36, 108),
	"ivan": Vector2(36, 108),
	"yelena": Vector2(36, 108),
	"zakhar": Vector2(36, 108),
}
const WALK_FRAME_TIME := 0.125
const PAW_STEP_M := 1.4             # 爪印间距（米）；人形伙伴按靴印走同样的间距
const SUPPORT_SCAN_RANGE := 7.0    # 只支援玩家附近的交战，避免伙伴追敌离队
const SUPPORT_ATTACK_RANGE := 1.6
const SUPPORT_FIRE_RANGE := 8.2
const SUPPORT_ATTACK_COOLDOWN := 1.3
const SENSE_RANGE := 6.0            # 灰烬嗅觉半径（米）
const ANNA_RANGE := 8.0             # 安娜辨认半人半径（米）
const PPM := 64.0                   # 与 NightExplore 一致
const SQ := 0.62

@export var mate_id := "ash"
@export var player_target: Node2D = null
@export var follow_dist := 64.0
@export var move_speed := 220.0
@export var teleport_dist := 460.0

var ctl: Node = null                # NightExplore 引用（_spawn_follower 注入）
var _nav = preload("res://scripts/night/NavGrid.gd").Agent.new()   # 跟随也走共享网格，从窄口绕过来

var _sprite: Sprite2D
var _t := 0.0
var _moving := false
var _tex_stand: Texture2D = null
var _tex_walk: Array = []
var _walk_by_direction: Dictionary = {}
var _active_walk: Array = []
var _facing := ""
var _frame := 0
var _frame_t := 0.0
var _support_attack_t := 0.0
var _attack_anim_t := 0.0
var _attack_dir := Vector2.RIGHT
var _aim_dir := Vector2.RIGHT
var _weapon_id := ""
var _weapon_sprite: Sprite2D
var _muzzle_flash: Sprite2D
var _muzzle_light: PointLight2D
var _muzzle_t := 0.0

var _sense_t := 0.0
var _paw_m := 0.0                   # 距上一个爪印走了多少米
var _marked := {}                   # Node2D -> Label（持续标记）
var _barked := {}                   # 已叫声提示过的目标
var _exit_beacon := false           # 伊万：撤离点光圈是否已放


func _ready() -> void:
	collision_layer = 0
	collision_mask = player_target.collision_mask if is_instance_valid(player_target) else 1
	_sprite = Sprite2D.new()
	_sprite.centered = false
	var stand_path: String = PORTRAITS.get(mate_id, PORTRAITS["ash"])
	if ResourceLoader.exists(stand_path):
		_tex_stand = load(stand_path)
		_sprite.texture = _tex_stand
	for i in range(8):
		var suffix := "Walk%d" % i
		var p := "res://art/30_props/PRP_%s_%s.png" % [mate_id.capitalize(), suffix]
		if ResourceLoader.exists(p):
			_tex_walk.append(load(p))
	var base_direction := "E" if mate_id == "ash" else "S"
	_walk_by_direction[base_direction] = _tex_walk
	for direction in (["N", "S"] if mate_id == "ash" else ["N", "E"]):
		var frames: Array = []
		for i in range(8):
			var p := "res://art/30_props/PRP_%s_Walk%s%d.png" % [mate_id.capitalize(), direction, i]
			if ResourceLoader.exists(p):
				frames.append(load(p))
		if frames.size() == 8:
			_walk_by_direction[direction] = frames
	_active_walk = _tex_walk
	_sprite.offset = -PIVOTS.get(mate_id, Vector2(36, 108))
	add_child(_sprite)
	var col := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 9.0
	col.shape = circ
	add_child(col)
	if mate_id != "ash":
		_setup_attack_weapon()
	# 呼吸白气（可复用 Breath 节点，随机相位）：狼犬嘴在前、人形嘴在上方。
	var breath = load("res://scripts/night/Breath.gd").new()
	add_child(breath)
	breath.position = Vector2(26, -58) if mate_id == "ash" else Vector2(8, -84)


func _setup_attack_weapon() -> void:
	_weapon_id = String(COMPANION_WEAPONS.get(mate_id, "pistol"))
	var w: Dictionary = Arsenal.spec(_weapon_id)
	_weapon_sprite = Sprite2D.new()
	_weapon_sprite.name = "CompanionWeapon"
	_weapon_sprite.texture = load(String(w.get("tex", "")))
	_weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_weapon_sprite.centered = false
	_weapon_sprite.light_mask = 2
	add_child(_weapon_sprite)
	_muzzle_flash = Sprite2D.new()
	_muzzle_flash.name = "CompanionMuzzleFlash"
	_muzzle_flash.texture = load("res://art/50_vfx/VFX_MuzzleFlash_Sheet.png")
	_muzzle_flash.hframes = 4
	_muzzle_flash.light_mask = 2
	_muzzle_flash.z_index = 3
	_muzzle_flash.visible = false
	add_child(_muzzle_flash)
	_muzzle_light = PointLight2D.new()
	_muzzle_light.name = "CompanionMuzzleLight"
	_muzzle_light.texture = load("res://art/50_vfx/VFX_Light_Radial_Soft.png")
	_muzzle_light.texture_scale = 1.2
	_muzzle_light.light_mask = 2
	_muzzle_light.energy = 0.0
	add_child(_muzzle_light)
	_pose_companion_weapon()


func _dist_m(a: Vector2, b: Vector2) -> float:
	var d := a - b
	return Vector2(d.x / PPM, d.y / (PPM * SQ)).length()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player_target):
		return
	var to_player: Vector2 = player_target.global_position - global_position
	var dist := to_player.length()
	if dist > teleport_dist:
		global_position = player_target.global_position - to_player.normalized() * (follow_dist * 0.6)
		velocity = Vector2.ZERO
		return
	var support_target := _find_support_target()
	var chase_target := support_target if mate_id == "ash" else null
	var goal: Vector2 = chase_target.global_position if chase_target != null else player_target.global_position
	var to_goal := goal - global_position
	var move_dist := dist
	var should_move := dist > follow_dist
	if chase_target != null:
		move_dist = to_goal.length()
		should_move = _dist_m(global_position, goal) > SUPPORT_ATTACK_RANGE
	_moving = should_move
	if _moving:
		var wp: Vector2 = _nav.next(ctl.get("nav") if ctl != null else null, global_position,
			goal, delta)
		var dir := (wp - global_position).normalized()
		if chase_target != null:
			move_dist = to_goal.length()
		var spd := move_speed * clampf(move_dist / (follow_dist * 2.0), 0.85, 1.7)
		velocity = dir * spd
		_update_facing(dir)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * delta * 6.0)
	move_and_slide()
	_drop_track(delta)
	_update_combat_support(support_target, delta)
	_update_walk_anim(delta)
	_update_perks(delta)


func _find_support_target() -> Node2D:
	if ctl == null or ctl.state != "play" or not is_instance_valid(player_target):
		return null
	var best: Node2D = null
	var best_dist := INF
	for enemy in ctl.soldiers + ctl.rabids:
		if not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		if enemy.is_in_group("night_osk"):
			if enemy.state != "alert":
				continue
		elif enemy.state not in ["chase", "windup", "lunge"]:
			continue
		if _dist_m(enemy.global_position, player_target.global_position) > SUPPORT_SCAN_RANGE:
			continue
		var d := _dist_m(global_position, enemy.global_position)
		if d < best_dist:
			best_dist = d
			best = enemy
	return best


func _update_combat_support(target: Node2D, delta: float) -> void:
	_support_attack_t = maxf(0.0, _support_attack_t - delta)
	if target == null or not is_instance_valid(target) or not target.has_method("is_alive") \
		or not bool(target.call("is_alive")):
		return
	var ranged := mate_id != "ash"
	var attack_range := SUPPORT_FIRE_RANGE if ranged else SUPPORT_ATTACK_RANGE
	if ranged:
		_aim_dir = (target.global_position - global_position).normalized()
		_update_facing(_aim_dir)
		_pose_companion_weapon()
	if _dist_m(global_position, target.global_position) > attack_range or _support_attack_t > 0.0:
		return
	_support_attack_t = SUPPORT_ATTACK_COOLDOWN
	var damage := 26.0 if mate_id == "ash" else 22.0
	ctl.companion_attack(self, target, damage)


func _update_facing(dir: Vector2) -> void:
	if dir.length_squared() < 0.0001:
		return
	_aim_dir = dir.normalized()
	var direction: String
	if absf(dir.x) > absf(dir.y):
		direction = "E" if dir.x > 0.0 else "W"
	else:
		direction = "S" if dir.y > 0.0 else "N"
	var source_direction := "E" if direction == "W" else direction
	_sprite.flip_h = direction == "W"
	var frames: Array = _walk_by_direction.get(source_direction, _tex_walk)
	if _facing != direction:
		_facing = direction
		_frame = 0
		_frame_t = 0.0
	_active_walk = frames


## 伙伴走过的痕迹。速度是「屏幕像素 / 秒」，y 已经被 SQ 压过 ——
## 换算成米要分别除 PPM 和 PPM·SQ；朝向角也要反压缩（/ SQ），否则印子是歪的。
func _drop_track(delta: float) -> void:
	if not _moving or ctl == null or not ctl.has_method("footprint"):
		return
	_paw_m += Vector2(velocity.x / PPM, velocity.y / (PPM * SQ)).length() * delta
	if _paw_m < PAW_STEP_M:
		return
	_paw_m = 0.0
	ctl.footprint(global_position, atan2(velocity.y / SQ, velocity.x),
		"paw" if mate_id == "ash" else "boot")


func _update_walk_anim(delta: float) -> void:
	_t += delta
	_sprite.position = Vector2.ZERO
	if _moving and _active_walk.size() >= 2:
		_frame_t += delta
		while _frame_t >= WALK_FRAME_TIME:
			_frame_t -= WALK_FRAME_TIME
			_frame = (_frame + 1) % _active_walk.size()
		_sprite.texture = _active_walk[_frame]
		_sprite.position.y = sin(_t * 14.0) * 1.4
	else:
		if _tex_stand != null:
			_sprite.texture = _tex_stand
		_frame = 0
		_frame_t = 0.0
		_sprite.position.y = 0.0
	_update_attack_anim(delta)


## 人形伙伴沿用军械库武器贴图、握把锚点和枪口焰，不改角色碰撞或缩放。
func _pose_companion_weapon(recoil := 0.0) -> void:
	if _weapon_sprite == null:
		return
	var w: Dictionary = Arsenal.spec(_weapon_id)
	var dir := _aim_dir.normalized()
	if dir.length_squared() < 0.001:
		dir = Vector2.RIGHT
	var flip := dir.x < 0.0
	var grip: Vector2 = w["grip"]
	var hand := Vector2(35.0, -70.0)
	if _facing == "N":
		hand = Vector2(30.0, -77.0)
	elif _facing == "S":
		hand = Vector2(41.0, -63.0)
	var scale_k := float(w.get("scale", 0.45))
	_weapon_sprite.position = hand - dir * recoil
	_weapon_sprite.z_index = 0 if _facing == "N" else 2
	_weapon_sprite.scale = Vector2(scale_k, scale_k)
	_weapon_sprite.rotation = dir.angle() + float(w.get("hold_rot", 0.0)) * (-1.0 if flip else 1.0)
	_weapon_sprite.flip_v = flip
	_weapon_sprite.offset = Vector2(-grip.x, grip.y - _weapon_sprite.texture.get_height() if flip else -grip.y)
	if _muzzle_flash != null:
		var muzzle_offset: Vector2 = w.get("muzzle", grip) - grip
		if flip:
			muzzle_offset.y = -muzzle_offset.y
		var muzzle_pos: Vector2 = _weapon_sprite.transform * muzzle_offset
		_muzzle_flash.position = muzzle_pos + dir * 5.0
		_muzzle_flash.rotation = _weapon_sprite.rotation
		_muzzle_light.position = muzzle_pos
		_muzzle_flash.visible = _muzzle_t > 0.0
		if _muzzle_t > 0.0:
			_muzzle_flash.frame = mini(3, int((1.0 - _muzzle_t / 0.08) * 4.0))
			_muzzle_flash.scale = Vector2(0.42, 0.42)
			_muzzle_light.energy = 2.1 * clampf(_muzzle_t / 0.08, 0.0, 1.0)
		else:
			_muzzle_light.energy = 0.0


## 敌人受击时触发单次动作：人形武器后坐，灰烬向前扑再收回。
func play_attack(target: Node2D) -> void:
	if is_instance_valid(target):
		_attack_dir = (target.global_position - global_position).normalized()
		_aim_dir = _attack_dir
		_update_facing(_attack_dir)
	_attack_anim_t = 0.25
	if mate_id != "ash":
		_muzzle_t = 0.08
		_pose_companion_weapon(4.5)
		_muzzle_flash.visible = true


func _update_attack_anim(delta: float) -> void:
	var envelope := 0.0
	if _attack_anim_t > 0.0:
		_attack_anim_t = maxf(0.0, _attack_anim_t - delta)
		envelope = sin(clampf(1.0 - _attack_anim_t / 0.25, 0.0, 1.0) * PI)
		_sprite.position += _attack_dir * envelope * (10.0 if mate_id == "ash" else 2.5)
	_muzzle_t = maxf(0.0, _muzzle_t - delta)
	if _weapon_sprite != null:
		var recoil := 4.5 * (1.0 - clampf(_attack_anim_t / 0.25, 0.0, 1.0)) if _attack_anim_t > 0.0 else 0.0
		_pose_companion_weapon(recoil)


# ---------------------------------------------------------------------------
# 伙伴实时特性
# ---------------------------------------------------------------------------
func _update_perks(delta: float) -> void:
	if ctl == null:
		return
	_sense_t += delta
	if _sense_t < 0.35:
		return
	_sense_t = 0.0
	match mate_id:
		"ash":
			_sense_ash()
		"anna":
			_sense_anna()
		"ivan":
			_sense_ivan()
		"pavel":
			_sense_pavel()


func _in_range(n: Node2D, rng: float) -> bool:
	return is_instance_valid(n) and _dist_m(global_position, n.global_position) <= rng


func _mark(target: Node2D, txt: String, col: Color, yoff: float) -> void:
	if not is_instance_valid(target) or _marked.has(target):
		return
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.position = Vector2(-10, yoff)
	lbl.z_index = 60
	target.add_child(lbl)
	_marked[target] = lbl


func _sweep(keep: Dictionary) -> void:
	# 清理离开范围 / 已失效目标的标记与叫声记录
	for t in _marked.keys():
		if not is_instance_valid(t) or not keep.has(t):
			if is_instance_valid(_marked[t]):
				_marked[t].queue_free()
			_marked.erase(t)
			_barked.erase(t)


func _bark(target: Node2D, text: String, sfx_name: String) -> void:
	if _barked.has(target):
		return
	_barked[target] = true
	ctl.spawn_float(global_position + Vector2(0, -96), text, Color("#fde68a"))
	if sfx_name != "":
		ctl.sfx.play_at(sfx_name, global_position, -4.0)


func _sense_ash() -> void:
	var keep := {}
	for c in ctl.containers:
		if _in_range(c, SENSE_RANGE):
			_mark(c, "📦", Color("#9fb4c8"), -56.0)
			keep[c] = true
	for r in ctl.rabids:
		if _in_range(r, SENSE_RANGE):
			_mark(r, "!", Color("#f87171"), -92.0)
			keep[r] = true
			_bark(r, "灰烬炸毛狂吠！", "snarl")
	for h in ctl.halfs:
		if _in_range(h, SENSE_RANGE):
			_mark(h, "?", Color("#facc15"), -92.0)
			keep[h] = true
			_bark(h, "灰烬低声呜咽", "growl")
	for s in ctl.survivors:
		if _in_range(s, SENSE_RANGE):
			_mark(s, "♥", Color("#63d18a"), -92.0)
			keep[s] = true
			_bark(s, "灰烬摇尾", "")
	_sweep(keep)


func _sense_anna() -> void:
	var keep := {}
	for h in ctl.halfs:
		if _in_range(h, ANNA_RANGE):
			_mark(h, "半人", Color("#facc15"), -92.0)
			keep[h] = true
	_sweep(keep)


func _sense_ivan() -> void:
	if not _exit_beacon:
		_exit_beacon = true
		if ctl.has_node("Markers/Exit"):
			var exit: Node2D = ctl.get_node("Markers/Exit")
			# 常驻光圈（与夜潜灯光同素材）+ 撤离标记
			var glow := Sprite2D.new()
			glow.texture = load("res://art/50_vfx/VFX_Light_Radial_Soft.png")
			glow.modulate = Color(0.45, 0.95, 0.6, 0.5)
			# 这张灯光图是黑底无 alpha：必须加色混合，否则会画出一个黑方块
			var glow_mat := CanvasItemMaterial.new()
			glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			glow.material = glow_mat
			glow.scale = Vector2(1.4, 1.4)
			glow.z_index = -1
			exit.add_child(glow)
			_mark(exit, "撤离", Color("#63d18a"), -48.0)
	# 显隐藏容器：8m 内把「隐藏」箱显形并标出，使其可搜刮
	for c in ctl.containers:
		if bool(c.get_meta("hidden", false)) and not bool(c.get_meta("revealed", false)) and _in_range(c, ANNA_RANGE):
			c.set_meta("revealed", true)
			c.modulate = Color(1, 1, 1, 0.85)
			_mark(c, "隐藏", Color("#7fb2e0"), -56.0)
			ctl.spawn_float(c.global_position + Vector2(0, -90), "伊万发现了暗格", Color("#7fb2e0"))


func _sense_pavel() -> void:
	# 标出 6m 内的焊死箱（可撬）
	var keep := {}
	for c in ctl.containers:
		if bool(c.get_meta("locked", false)) and _in_range(c, SENSE_RANGE):
			_mark(c, "🔒", Color("#e0a34a"), -56.0)
			keep[c] = true
	_sweep(keep)
