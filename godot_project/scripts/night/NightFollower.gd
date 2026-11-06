extends CharacterBody2D
## NightFollower.gd — 夜潜伙伴跟随者（第一版：可玩可测）。
##
## 以小人实体跟在玩家身后：静态立绘 + 走路浮动 + 朝向翻转（行走帧动画后补）。
## 战役出发时由 RaidBridge.cfg.mate 决定带谁（"" = 这一夜没带，不生成）；
## F2 独立跑 night_*.tscn 时默认灰烬，可用 --mate=ash/anna/gulya/pavel/ivan 指定。
## 纯跟随：不参与战斗 / 敌人仇恨 / 搜刮判定（后续可接灰烬嗅觉三态等特性）。

const PORTRAITS := {
	"ash": "res://art/30_props/PRP_Ash_Stand.png",
	"anna": "res://art/30_props/PRP_Anna_Stand.png",
	"gulya": "res://art/30_props/PRP_Gulya_Stand.png",
	"pavel": "res://art/30_props/PRP_Pavel_Stand.png",
	"ivan": "res://art/30_props/PRP_Ivan_Stand.png",
}
# 立绘 pivot（脚底中心）：人形 72×112 pivot(36,108)，灰烬 96×80 pivot(48,76)
const PIVOTS := {
	"ash": Vector2(48, 76),
	"anna": Vector2(36, 108),
	"gulya": Vector2(36, 108),
	"pavel": Vector2(36, 108),
	"ivan": Vector2(36, 108),
}

@export var mate_id := "ash"
@export var player_target: Node2D = null
@export var follow_dist := 64.0      # 超过这个距离就跟上
@export var move_speed := 220.0
@export var teleport_dist := 460.0   # 落太远（被地形卡住 / 玩家冲刺）直接传到侧后

var _sprite: Sprite2D
var _t := 0.0
var _moving := false


func _ready() -> void:
	collision_layer = 0                                       # 不被敌人 / 玩家当碰撞目标
	collision_mask = player_target.collision_mask if is_instance_valid(player_target) else 1
	_sprite = Sprite2D.new()
	_sprite.centered = false
	var tex: String = PORTRAITS.get(mate_id, PORTRAITS["ash"])
	if ResourceLoader.exists(tex):
		_sprite.texture = load(tex)
	var piv: Vector2 = PIVOTS.get(mate_id, Vector2(36, 108))
	_sprite.offset = -piv                                     # 脚底 pivot 对齐节点原点
	add_child(_sprite)
	var col := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 9.0
	col.shape = circ
	add_child(col)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player_target):
		return
	var to_player: Vector2 = player_target.global_position - global_position
	var dist := to_player.length()
	if dist > teleport_dist:
		# 落太远 → 传到玩家侧后，避免被地形永久卡住
		global_position = player_target.global_position - to_player.normalized() * (follow_dist * 0.6)
		velocity = Vector2.ZERO
		return
	_moving = dist > follow_dist
	if _moving:
		var dir := to_player.normalized()
		# 速度随距离略增，保证能追上冲刺的玩家
		var spd := move_speed * clampf(dist / (follow_dist * 2.0), 0.85, 1.7)
		velocity = dir * spd
		if absf(dir.x) > 0.1:
			_sprite.flip_h = dir.x > 0.0                        # 立绘（狼犬朝左）向右走时镜像
	else:
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * delta * 6.0)
	move_and_slide()
	# 走路浮动：移动时轻微上下，模拟迈步（无帧动画的第一版）
	_t += delta
	_sprite.position.y = sin(_t * 14.0) * 1.6 if _moving else 0.0
