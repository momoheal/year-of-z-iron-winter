extends CharacterBody2D
## NightFollower.gd — 夜潜伙伴跟随者 + 伙伴实时特性。
##
## 跟随：Stand 立绘 + Walk0/Walk1 两帧迈步 + 朝向翻转 + 走路浮动。
## 战役出发时由 RaidBridge.cfg.mate 决定带谁（"" = 没带，不生成）；
## F2 独立跑默认灰烬，可用 --mate=ash/anna/gulya/pavel/ivan 指定。
##
## 实时特性（_update_perks，按 mate_id 分）：
##   ash  嗅觉：6m 内标出容器(📦)与生物；三态分辨——狂暴者"!"吠、半人"?"呜咽、幸存者"♥"摇尾。
##   anna 辨认半人：8m 内把半人标成"半人"黄字，避免当成狂暴者误杀。
##   ivan 撤离点常亮：在撤离点放常驻光圈 + "撤离"标记。
## 注：帕维尔撬锁 / 伊万显隐藏容器需要夜潜先引入"上锁 / 隐藏容器"机制（当前没有），另批做。

const PORTRAITS := {
	"ash": "res://art/30_props/PRP_Ash_Stand.png",
	"anna": "res://art/30_props/PRP_Anna_Stand.png",
	"gulya": "res://art/30_props/PRP_Gulya_Stand.png",
	"pavel": "res://art/30_props/PRP_Pavel_Stand.png",
	"ivan": "res://art/30_props/PRP_Ivan_Stand.png",
}
const PIVOTS := {
	"ash": Vector2(48, 76),
	"anna": Vector2(36, 108),
	"gulya": Vector2(36, 108),
	"pavel": Vector2(36, 108),
	"ivan": Vector2(36, 108),
}
const WALK_FRAME_TIME := 0.13
const PAW_STEP_M := 1.4             # 爪印间距（米）；人形伙伴按靴印走同样的间距
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
var _frame := 0
var _frame_t := 0.0

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
	for suffix in ["Walk0", "Walk1"]:
		var p := "res://art/30_props/PRP_%s_%s.png" % [mate_id.capitalize(), suffix]
		if ResourceLoader.exists(p):
			_tex_walk.append(load(p))
	_sprite.offset = -PIVOTS.get(mate_id, Vector2(36, 108))
	add_child(_sprite)
	var col := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 9.0
	col.shape = circ
	add_child(col)
	# 呼吸白气（可复用 Breath 节点，随机相位）：狼犬嘴在前、人形嘴在上方。
	var breath = load("res://scripts/night/Breath.gd").new()
	add_child(breath)
	breath.position = Vector2(26, -58) if mate_id == "ash" else Vector2(8, -84)


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
	_moving = dist > follow_dist
	if _moving:
		var wp: Vector2 = _nav.next(ctl.get("nav") if ctl != null else null, global_position,
			player_target.global_position, delta)
		var dir := (wp - global_position).normalized()
		var spd := move_speed * clampf(dist / (follow_dist * 2.0), 0.85, 1.7)
		velocity = dir * spd
		if absf(dir.x) > 0.1:
			_sprite.flip_h = dir.x > 0.0
	else:
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * delta * 6.0)
	move_and_slide()
	_drop_track(delta)
	_update_walk_anim(delta)
	_update_perks(delta)


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
	if _moving and _tex_walk.size() == 2:
		_frame_t += delta
		if _frame_t >= WALK_FRAME_TIME:
			_frame_t = 0.0
			_frame = 1 - _frame
			_sprite.texture = _tex_walk[_frame]
		_sprite.position.y = sin(_t * 14.0) * 1.4
	else:
		if _tex_stand != null:
			_sprite.texture = _tex_stand
		_frame = 0
		_frame_t = 0.0
		_sprite.position.y = 0.0


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
