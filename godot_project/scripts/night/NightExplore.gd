extends Node2D
## NightExplore.gd — 「夜间广轨货场」（L03 · yard）夜潜美术切片的总控。
##
## 与 Campaign.gd 的 _draw() 灰盒不同，这个场景是完整的节点化 2.5D 场景：
##   Ground（烘焙地面，light_mask=2）+ World（Y-sort 的道具 / 角色精灵）
##   + 2D 灯光（Ground 灯投影 / Objects 灯不投影）+ CanvasModulate 夜色 + 雪粒子 + 后处理。
## 玩法是 Exploration Demo 的子集：三方潜行（玩家 / 灰鳞狂暴者 / ОСК 清杀队）、手电、噪声、
## 扔罐头借刀杀人、搜刮、体温、撤离；外加回退半人的道德抉择（良知 / 卌 划痕，口径与 RaidSim 抉择 A 一致）。
## 物品与容器掉落表直接读 CampaignData，后续可以把本场景接进 CampaignSim 的夜潜阶段。
##
## 操作：WASD 移动 · 鼠标朝向 · Ctrl 蹲伏 · Shift 冲刺 · 长按 E 搜刮/撤离 · G 扔罐头
##       F 手电 · M 静音 · R 重来 · Esc 返回战役
##       靠近半人按 E → 抉择面板：1 喂药退烧 / 2 绕开 / 3 撬棍灭口 / Esc 先不决定
##
## P1.5 天亮：战役里 cfg.night 是这一夜的秒数，最后 DAWN_WINDOW（20%）开始「天色渐变」——
##      后处理 dawn 参数抬曝光 / 退冷调 / 化霜，CanvasModulate 由夜青转黎明清灰，风雪变薄，
##      远处一声调车汽笛；到点按 dawn 结束（背包保留一半、生命 −22，由 CampaignSim.finish_raid 结）。
## P2.5 声音：NightSfx 程序化合成 + AudioStreamPlayer2D 定位；emit_noise() 的声纹同时是真声音，
##      清杀兵的面具呼吸挂在兵身上（4 米内可闻），紧张度驱动心跳。
## 手感：受伤 / 枪声 / 扑咬 / 警报 / 结局都往 shake 里加创伤量，镜头按 shake² 抖动并轻微推镜。

const Data := preload("res://scripts/CampaignData.gd")
const SfxScript := preload("res://scripts/night/NightSfx.gd")

const PPM := 64.0
const SQ := 0.62
const SEARCH_TIME := 2.2
const EXTRACT_TIME := 1.6
const REACH := 1.45
const WARMTH_DECAY := 100.0 / 240.0
const WARMTH_FIRE := 7.0
const CAN_RANGE := 9.0
const CAN_NOISE := 9.0
const CORPSE_CATS := ["med", "val", "intel"]
# ---- 天亮（P1.5）----
const DAWN_WINDOW := 0.2                                  # 夜长最后 20% 开始天亮
const NIGHT_MOD := Color(0.27, 0.32, 0.45)                # 与场景里 CanvasModulate 的初值一致
const DAWN_MOD := Color(0.60, 0.575, 0.565)               # 黎明前的清灰（比夜色亮、比白天冷）
const DAWN_SNOW_A := 0.5                                  # 天亮时雪粒子留多少
# ---- 声音（P2.5）----
const MASK_BREATH_M := 4.0                                # 面具呼吸的可闻半径（规划 P2.5：4 米）
const WARMTH_CHILL_AT := [35.0, 20.0, 8.0]                # 失温提示音的三个档
# ---- 镜头震动 ----
const SHAKE_PX := 16.0                                    # shake=1 时的最大位移（像素）
const SHAKE_DECAY := 0.85                                 # 每秒衰减（外加 0.9×shake 的自衰减）
const STEP_RAIL_BAND := 0.95                              # 距轨心这么近就算踩在枕木 / 钢轨上
const DEFAULT_RAIL_Y := [26.0, 33.0]                      # 关卡没给 rail_y 元数据时的兜底（yard）

# P1: 是否从战役出发（RaidBridge 持有 sim/cfg）。false = F2 独立灰盒跑。
var in_campaign := false
var bag_max := 8
var night_left := 0.0
var night_max := 0.0
var abort_pending := false
var abort_timer := 0.0
var cold := 1.0                # cfg.cold：体温下降倍率，同时决定风雪音量（P1.4 / P2.5）
var day_n := 1                 # cfg.day：HUD 标题里的「第 N 夜」

# 关卡身份：由 build_scene.py 写在根节点的 metadata 上（没有就用 yard 的口径，兼容旧场景 / F2）
var level_id := "yard"
var level_zh := "夜间广轨货场"
var level_en := "Broad-Gauge Freight Yard"
var objective_zh := "目标：三号车厢的透析液（门口有狂暴者）· 用 G 罐头把它引进清杀队的光锥"
var extract_zh := "回锅炉房通风口撤离"     # 提示里会补「（长按 E）」，别自己再写一遍
var prize := "dial"            # 本关的关键物资（yard = 妈妈的透析液）
var rail_y: Array = []         # 铁轨中心线（米）→ 脚步材质

# 天亮（P1.5）
var dawn_t := 0.0              # 夜长最后 20% 的进度 0..1（未缓动）
var dawn_cued := false         # 「天边发白」的提示 / 汽笛只放一次
var chill_step := 0            # 失温提示音打到第几档

# 镜头震动 / 推镜
var shake := 0.0               # 创伤量 0..1（实际位移按 shake²）
var punch := 0.0               # 受伤时的推镜量
var _shake_t := 0.0

var state := "play"            # play | choice | caught | frozen | downed | extracted | dawn | abort
var pack: Array[String] = []
var warmth := 100.0
var hp := 100.0
var hurt := 0.0                # 受伤闪红计时
var borrowed := 0              # 借刀杀人：清杀队替你清掉的狂暴者
var rabids: Array = []
var halfs: Array = []
# 道德账（接进战役时按同样口径回写 CampaignSim：raid_add_conscience / raid_add_tally）
var conscience := 0.0          # 本夜良知变化
var tally := 0                 # 卌 划痕（亲手灭口才划）
var half_saved := 0
var half_lost := 0             # 被清杀队误杀的半人
var choice_half = null       # NightHalf
var choice_msg := ""
var cans := 3
var search_target: Node2D = null
var search_prog := 0.0
var extract_prog := 0.0
var exit_px := Vector2.ZERO
var ripples: Array[Dictionary] = []
var floats: Array[Dictionary] = []
var thrown: Array[Dictionary] = []
var soldiers: Array = []
var containers: Array = []
var slush: Array = []          # [center_m: Vector2, radii_m: Vector2]
var warm_lights: Array = []    # [pos_px, radius_m]
var fade_props: Array = []
var caught_by := ""
var muted := false
var t := 0.0

var player
var font: SystemFont
var sfx
var rng := RandomNumberGenerator.new()
var _search_noise := 0.0

@onready var cam: Camera2D = $Camera2D
@onready var post: ColorRect = $Post/Grade
@onready var hud_root: Control = $HUD/Root
@onready var night_mod: CanvasModulate = get_node_or_null("CanvasModulate")
@onready var snow_back: GPUParticles2D = get_node_or_null("Camera2D/Snow")
@onready var snow_front: GPUParticles2D = get_node_or_null("FrontSnow/Flakes")

var _lbl_status: Label
var _lbl_bag: Label
var _lbl_hint: Label
var _lbl_center: Label
var _bar_warm: ProgressBar
var _bar_hp: ProgressBar
var _choice_panel: PanelContainer
var _choice_lbl: Label

static func to_m(p: Vector2) -> Vector2:
	return Vector2(p.x / PPM, p.y / (PPM * SQ))

static func dist_m(a: Vector2, b: Vector2) -> float:
	return to_m(a - b).length()

func _ready() -> void:
	rng.randomize()
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK SC", "Noto Sans SC", "Microsoft YaHei", "SimHei",
		"PingFang SC", "Segoe UI", "Arial"])
	sfx = SfxScript.new()
	sfx.name = "NightSfx"
	add_child(sfx)
	_read_level_meta()
	# P1: 战役出发 → 读 cfg 初始化背包 / 携带物 / 天亮倒计时；F2 独立跑用灰盒默认。
	in_campaign = RaidBridge.active
	var cfg: Dictionary = RaidBridge.cfg if in_campaign else {}
	if in_campaign:
		bag_max = int(cfg.get("pack_max", 8))
		var ld: Dictionary = cfg.get("load", {})
		for i in int(ld.get("water", 0)):
			pack.append("water")
		for i in int(ld.get("asp", 0)):
			pack.append("asp")
		for i in int(ld.get("band", 0)):
			pack.append("band")
		cans = int(ld.get("can", 0))
		night_max = float(cfg.get("night", 120.0))
		night_left = night_max
		cold = clampf(float(cfg.get("cold", 1.0)), 0.2, 2.0)     # P1.4：体温下降速度 × cold
		day_n = maxi(1, int(cfg.get("day", 1)))
		muted = not bool(cfg.get("sound_on", true))               # 战役里关过音效就别在这儿突然响
	else:
		pack.append("water")       # F2 出门前灌的热水壶 —— 喂半人退烧要用
		cans = 3
	player = $World/Player
	player.ctl = self
	for s in get_tree().get_nodes_in_group("night_osk"):
		s.ctl = self
		soldiers.append(s)
	for n in get_tree().get_nodes_in_group("night_searchlight"):
		n.ctl = self
	for r in get_tree().get_nodes_in_group("night_rabid"):
		r.ctl = self
		rabids.append(r)
	for h in get_tree().get_nodes_in_group("night_half"):
		h.ctl = self
		halfs.append(h)
	containers = get_tree().get_nodes_in_group("night_container")
	fade_props = get_tree().get_nodes_in_group("night_fade")
	for z in get_tree().get_nodes_in_group("night_slush"):
		slush.append([to_m(z.global_position), Vector2(float(z.get_meta("rx", 1.0)), float(z.get_meta("ry", 1.0)))])
	for w in get_tree().get_nodes_in_group("night_warm"):
		warm_lights.append([w.global_position, float(w.get_meta("radius", 2.5))])
	exit_px = $Markers/Exit.global_position
	player.global_position = $Markers/Spawn.global_position
	cam.global_position = player.global_position
	cam.reset_smoothing()
	_wire_audio()
	_build_hud()


## 关卡身份：build_scene.py 把这些写在根节点的 metadata 上，多张图共用同一个脚本。
## 旧场景 / 手工场景没有元数据时退回 yard 的口径（F2 独立跑也是这套）。
func _read_level_meta() -> void:
	level_id = String(get_meta("level_id", level_id))
	level_zh = String(get_meta("level_zh", level_zh))
	level_en = String(get_meta("level_en", level_en))
	objective_zh = String(get_meta("objective_zh", objective_zh))
	extract_zh = String(get_meta("extract_zh", extract_zh))
	prize = String(get_meta("prize", prize))
	var raw := String(get_meta("rail_y", ""))
	rail_y = []
	if raw.strip_edges() == "":
		rail_y = DEFAULT_RAIL_Y.duplicate()
	else:
		for part in raw.split(","):
			var v := part.strip_edges()
			if v != "":
				rail_y.append(float(v))


## P2.5：环境层交给 NightSfx（风雪随 cfg.cold 变强、天亮退去），清杀兵挂上面具呼吸循环。
func _wire_audio() -> void:
	for a in get_tree().get_nodes_in_group("night_ambient"):
		_loop_audio(a)
	if sfx.ambient_count() == 0:
		# 兼容没有 night_ambient 分组的场景：扫全树，跳过 NightSfx 自己的声部
		var found: Array = find_children("*", "AudioStreamPlayer", true, false)
		found.append_array(find_children("*", "AudioStreamPlayer2D", true, false))
		for a in found:
			if a == sfx or sfx.is_ancestor_of(a):
				continue
			_loop_audio(a)
	sfx.set_cold(cold)
	sfx.set_muted(muted)
	if muted:
		AudioServer.set_bus_mute(0, true)
	for sd in soldiers:
		sfx.attach_loop(sd, "mask_breath", MASK_BREATH_M, -7.0)


func _exit_tree() -> void:
	# M 键 / 战役带过来的静音是按主总线做的，别把它留给下一个场景
	AudioServer.set_bus_mute(0, false)

func _loop_audio(p: Node) -> void:
	var s = p.get("stream")
	if s is AudioStreamWAV:
		var w := (s as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
		p.set("stream", w)
		p.call("play")
	sfx.register_ambient(p, _ambient_role(String(p.name)))


## 环境层的角色（按节点名认）：wind 随 cfg.cold / 天亮变化，其余只做基准音量。
func _ambient_role(node_name: String) -> String:
	var n := node_name.to_lower()
	if n.begins_with("wind"):
		return "wind"
	if n.begins_with("fire"):
		return "fire"
	if n.begins_with("steam"):
		return "steam"
	if n.begins_with("lamp"):
		return "lamp"
	return ""

# ============================================================================
# 主循环
# ============================================================================
func _process(delta: float) -> void:
	t += delta
	hurt = maxf(0.0, hurt - delta)
	cam.global_position = player.global_position + Vector2(0, -40)
	_apply_shake(delta)
	if abort_pending:
		abort_timer -= delta
		if abort_timer <= 0.0:
			abort_pending = false
	if state == "play":
		_update_interact(delta)
		_update_warmth(delta)
		if in_campaign:
			night_left = maxf(0.0, night_left - delta)
			update_dawn()
			if night_left <= 0.0:
				_end("dawn")
	_update_fx(delta)
	_update_fade()
	_update_post()
	_refresh_hud()
	$OverlayLayer/Overlay.queue_redraw()

# ============================================================================
# 天亮（P1.5）：夜长最后 DAWN_WINDOW 里的天色渐变
# ============================================================================
## 天亮进度 0..1：只在战役模式（有 cfg.night）里推进；F2 独立跑恒为 0。
func dawn_progress() -> float:
	if not in_campaign or night_max <= 0.0:
		return 0.0
	var win := night_max * DAWN_WINDOW
	if night_left >= win:
		return 0.0
	return clampf(1.0 - night_left / win, 0.0, 1.0)


## 送进后处理 / CanvasModulate 的缓动值（smoothstep，别让天色线性发白）。
func dawn_grade() -> float:
	return smoothstep(0.0, 1.0, dawn_t)


func update_dawn() -> void:
	dawn_t = dawn_progress()
	if dawn_t > 0.0 and not dawn_cued:
		dawn_cued = true
		sfx.play("dawn_horn", -3.0)          # 远处调车机车的汽笛：诺沃斯克-17 的黎明是工业的
		add_shake(0.12)
		spawn_float(player.global_position + Vector2(0, -150),
			"天边发白了 —— %s" % extract_zh, Color("#fcd34d"))

func _update_interact(delta: float) -> void:
	var h = nearest_half()
	if h != null and Input.is_action_just_pressed("interact"):
		open_choice(h)
		return
	var holding := Input.is_action_pressed("interact")
	var near_exit := dist_m(player.global_position, exit_px) <= REACH
	var c := nearest_container()
	player.frozen = false
	if holding and near_exit and c == null:
		extract_prog += delta / EXTRACT_TIME
		player.frozen = true
		if extract_prog >= 1.0:
			_end("extracted")
		return
	extract_prog = 0.0
	if holding and c != null:
		if search_target != c:
			search_target = c
			search_prog = 0.0
		search_prog += delta / SEARCH_TIME
		player.frozen = true
		_search_noise -= delta
		if _search_noise <= 0.0:
			emit_noise(c.global_position, 1.5, "search")
			_search_noise = 0.7
		if search_prog >= 1.0:
			_finish_search(c)
	else:
		search_target = null
		search_prog = 0.0

func nearest_container() -> Node2D:
	var best: Node2D = null
	var bd := REACH
	for c in containers:
		if bool(c.get_meta("searched", false)):
			continue
		var d := dist_m(player.global_position, interact_point(c))
		if d < bd:
			bd = d
			best = c
	return best

func nearest_half():
	var best = null
	var bd := REACH * 1.2
	for h in halfs:
		if not h.is_alive() or h.resolved != "":
			continue
		var d := dist_m(player.global_position, h.global_position)
		if d < bd:
			bd = d
			best = h
	return best

# ============================================================================
# 道德抉择：回退半人（与 RaidSim.set_choice 抉择 A 同口径：A1 +7 / A2 −2 / A3 −10 且卌 +1）
# ============================================================================
func open_choice(h) -> void:
	if state != "play" or h == null or h.resolved != "" or not h.is_alive():
		return
	choice_half = h
	choice_msg = ""
	state = "choice"           # 世界暂停：清杀兵 / 狂暴者 / 半人都看 ctl.state
	player.frozen = true
	search_target = null
	search_prog = 0.0
	_show_choice()

func close_choice() -> void:
	if state != "choice":
		return
	state = "play"
	choice_half = null
	player.frozen = false
	_choice_panel.visible = false

func has_medicine() -> bool:
	return pack.has("asp") and pack.has("water")

## idx: 0 喂药退烧 · 1 绕开 · 2 撬棍灭口。返回 false = 没执行（缺药），面板保持打开。
func choose(idx: int) -> bool:
	if state != "choice" or choice_half == null:
		return false
	var h = choice_half
	var top: Vector2 = h.global_position + Vector2(0, -124)
	match idx:
		0:
			if not has_medicine():
				choice_msg = "你翻遍口袋：没有阿司匹林，或者热水壶已经空了。"
				_show_choice()
				return false
			pack.erase("asp")
			pack.erase("water")
			conscience += 7.0
			half_saved += 1
			h.save()
			if pack.size() < bag_max:
				pack.append("intel")
			spawn_float(top, "他的瞳孔回色了：「……水塔下面，找戴蓝毛线帽的老头……」", Color("#34d399"))
			sfx.play("beep")
		1:
			conscience -= 2.0
			h.resolved = "left"
			spawn_float(top, "你绕开了他。他还在烧。", Color("#94a3b8"))
		_:
			conscience -= 10.0
			tally += 1
			h.resolved = "mercy"
			sfx.play("swing", -6.0)
			sfx.play_at("crowbar_hit", h.global_position, -2.0)
			add_shake(0.2)
			h.die("player")
	close_choice()
	return true

func on_half_killed(h, by: String) -> void:
	_splat(h.global_position)
	if by == "player":
		spawn_float(h.global_position + Vector2(0, -124), "撬棍落下。日志背面多了一道卌。", Color("#fbbf24"))
		return
	h.resolved = "osk"
	half_lost += 1
	conscience -= 4.0
	spawn_float(h.global_position + Vector2(0, -124), "清杀队打死了半人 %s —— 他还有瞳孔。" % h.tag,
		Color("#fca5a5"))

func interact_point(c: Node2D) -> Vector2:
	return c.global_position + Vector2(c.get_meta("interact_offset", Vector2.ZERO))

func _finish_search(c: Node2D) -> void:
	c.set_meta("searched", true)
	var spr := c.get_node_or_null("Sprite") as CanvasItem
	if spr != null:
		spr.self_modulate = Color(0.78, 0.8, 0.86)
	var kind := String(c.get_meta("container", "crate"))
	var got: Array[String] = []
	var g := String(c.get_meta("guaranteed", ""))
	if g != "":
		got.append(g)
	var cats: Array = Data.CONTAINER_CATS.get(kind, CORPSE_CATS)
	var n := 1 + (1 if rng.randf() < 0.45 else 0)
	for i in n:
		var pool: Array = Data.LOOT_CATS[cats[rng.randi() % cats.size()]]
		got.append(String(pool[rng.randi() % pool.size()]))
	var names: Array[String] = []
	for id in got:
		if pack.size() >= bag_max:
			spawn_float(c.global_position + Vector2(0, -90), "背包满了 · Bag full", Color("#fbbf24"))
			break
		pack.append(id)
		names.append(item_name(id))
	if not names.is_empty():
		spawn_float(c.global_position + Vector2(0, -90), "+ " + "、".join(names), Color("#fde68a"))
	if g != "":
		var note := "拿到了 %s" % item_name(g)
		if g == "dial":
			note = "找到了妈妈的透析液"
		spawn_float(c.global_position + Vector2(0, -122), note, Color("#7dd3fc"))
	sfx.play("beep")
	search_target = null
	search_prog = 0.0

func item_name(id: String) -> String:
	var it: Dictionary = Data.ITEMS.get(id, {})
	return String(it.get("zh", id))

func _update_warmth(delta: float) -> void:
	var near_fire := false
	for w in warm_lights:
		if dist_m(player.global_position, w[0]) <= float(w[1]):
			near_fire = true
	if near_fire:
		warmth = minf(100.0, warmth + WARMTH_FIRE * delta)
	else:
		# P1.4：战役 cfg.cold 越大掉得越快（yard 1.0 / 下穿道 1.3 / 白桦林 1.5）
		warmth -= WARMTH_DECAY * cold * delta * (1.25 if player.on_slush else 1.0)
	# 失温分档提示（声音 + 浮字），别让玩家只盯着体温条
	var step := 0
	for thr in WARMTH_CHILL_AT:
		if warmth <= float(thr):
			step += 1
	if step > chill_step:
		chill_step = step
		sfx.play("chill", -8.0)
		spawn_float(player.global_position + Vector2(0, -146),
			"你在失温 —— 找火堆，或者回 602 室", Color("#bae6fd"))
	if warmth <= 0.0:
		warmth = 0.0
		_end("frozen")

func is_slush(p: Vector2) -> bool:
	var m := to_m(p)
	for z in slush:
		var d: Vector2 = (m - z[0]) / z[1]
		if d.length_squared() <= 0.9:
			return true
	return false

func is_lit(p: Vector2) -> bool:
	for w in warm_lights:
		if dist_m(p, w[0]) <= float(w[1]) * 1.8:
			return true
	return false

# ============================================================================
# 感知：清杀兵手电 / 探照灯塔
# ============================================================================
func can_see_player(origin: Vector2, range_m: float, half: float, facing: float, is_beam: bool) -> float:
	if state != "play":
		return 0.0
	var p: Vector2 = player.global_position
	var d := to_m(p - origin)
	var dist := d.length()
	var rng_m := range_m * (1.3 if (player.flashlight_on and not is_beam) else 1.0)
	if dist > rng_m:
		return 0.0
	var in_cone := absf(angle_difference(facing, d.angle())) <= half
	if not in_cone:
		if is_beam or dist > 1.6:
			return 0.0
	var mask := 1 | (2 if player.crouching else 0)
	var q := PhysicsRayQueryParameters2D.create(origin, p, mask)
	if not get_world_2d().direct_space_state.intersect_ray(q).is_empty():
		return 0.0
	if is_beam:
		return 1.0
	var f := 1.0 - dist / rng_m * 0.55
	if player.crouching:
		f *= 0.5
	if player.sprinting:
		f *= 1.4
	if player.flashlight_on:
		f *= 1.5
	elif not is_lit(p):
		f *= 0.7
	return f

func los_clear(a: Vector2, b: Vector2, mask: int) -> bool:
	var q := PhysicsRayQueryParameters2D.create(a, b, mask)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()

## 狂暴者视线：360°，近距离；墙挡，蹲在低矮掩体后也挡；开手电更远。
func rabid_sees_player(r: Node2D) -> bool:
	if state != "play":
		return false
	var p: Vector2 = player.global_position
	var dist := dist_m(p, r.global_position)
	var rng_m: float = r.SIGHT * (1.3 if player.flashlight_on else 1.0) * (0.7 if player.crouching else 1.0)
	if dist > rng_m:
		return false
	return los_clear(r.global_position, p, 1 | (2 if player.crouching else 0))

## 三色声纹：灰白=玩家 / 暗红=狂暴者 / 冷蓝=清杀队；琥珀=罐头。
## 谁听得见：清杀兵听玩家与罐头；狂暴者听一切人造声音（含枪声），不理同类的低吼和半人的呻吟；
## 半人被罐头 / 搜刮声吸引，听见枪声就逃。
## P2.5：声纹同时是真声音 —— quiet=true 表示只画波纹（例：子弹落点的二次标记，别重复响一枪）。
func emit_noise(pos: Vector2, radius_m: float, kind: String, quiet := false) -> void:
	var col := Color("#cbd5e1")
	match kind:
		"can":
			col = Color("#fbbf24")
		"search":
			col = Color("#e2c48a")
		"rabid":
			col = Color("#b91c1c")
		"gun":
			col = Color("#7dd3fc")
		"half":
			col = Color("#fcd9a0")
	ripples.append({"pos": pos, "r": 0.0, "max": radius_m, "col": col, "life": 1.0})
	if not quiet:
		_voice_noise(pos, radius_m, kind)
	if kind not in ["rabid", "gun", "half"]:
		for s in soldiers:
			if dist_m(s.global_position, pos) <= radius_m:
				s.hear(pos, kind)
	if kind not in ["rabid", "half"]:
		for r in rabids:
			if r.is_alive() and dist_m(r.global_position, pos) <= radius_m:
				r.hear(pos, kind)
		for h in halfs:
			if h.is_alive() and dist_m(h.global_position, pos) <= radius_m:
				h.hear(pos, kind)


## 噪声 → 世界里的声音（AudioStreamPlayer2D，按 RADIUS_M 衰减，闭眼也能定位）。
func _voice_noise(pos: Vector2, radius_m: float, kind: String) -> void:
	match kind:
		"step":
			sfx.play_at(step_sound(pos, is_slush(pos)), pos, -7.0, 0.09)
		"can":
			sfx.play_at("can", pos, -2.0)
		"search":
			sfx.play_at("rummage", pos, -9.0)
		"gun":
			sfx.play_at("gunshot", pos, 0.0, 0.03)
		"rabid":
			# 半径大的那声是追击时的嘶吼，小的是游荡时的低吼（NightRabid 用 4.5 / 3.2 区分）
			sfx.play_at("snarl" if radius_m > 4.0 else "growl", pos, -3.0)
		"half":
			sfx.play_at("moan", pos, -5.0)
		"hit":
			sfx.play_at("bite", pos, -2.0)


## 脚下是什么：冻雪泥 / 黑冰 → 冰面脆响；轨心 ±0.95m → 枕木与钢轨；其余 → 踩实的雪。
func step_sound(pos: Vector2, on_slush: bool) -> String:
	if on_slush:
		return "step_ice"
	var y := to_m(pos).y
	for band in rail_y:
		if absf(y - float(band)) <= STEP_RAIL_BAND:
			return "step_rail"
	return "step_snow"

func damage_player(amount: float, _by: Node) -> void:
	if state != "play":
		return
	hp = maxf(0.0, hp - amount)
	hurt = 0.35
	# 被咬：颅内的闷响 + 定位在伤口上的撕咬声 + 一脚踹在镜头上
	sfx.play("bonejam", -8.0)
	add_shake(0.55)
	punch = 1.0
	emit_noise(player.global_position, 6.0, "hit")
	spawn_float(player.global_position + Vector2(0, -120), "-%d 被咬了！" % int(amount), Color("#f87171"))
	if hp <= 0.0:
		_end("downed")

func on_soldier_fired(s: Node2D, at: Vector2) -> void:
	# 枪声的震动按距离衰减：贴脸 0.5，26 米外只剩 0.06 的闷响
	var d := dist_m(player.global_position, s.global_position)
	add_shake(clampf(0.5 * (1.0 - d / 26.0), 0.06, 0.5))
	emit_noise(s.global_position, 10.0, "gun")
	emit_noise(at, 3.0, "gun", true)      # 落点只画波纹

## 狂暴者起跳（NightRabid 从 windup 切到 lunge 时调）：嘶吼 + 近距离的一震。
func on_rabid_lunge(r: Node2D) -> void:
	sfx.play_at("snarl", r.global_position, -2.0)
	var d := dist_m(player.global_position, r.global_position)
	if d <= 9.0:
		add_shake(clampf(0.34 * (1.0 - d / 9.0), 0.05, 0.34))

## 狂暴者第一次看见你（NightRabid 从游荡切到 chase 时调）。
func on_rabid_spotted(r: Node2D) -> void:
	sfx.play_at("snarl", r.global_position, -1.0)
	if dist_m(player.global_position, r.global_position) <= 7.0:
		add_shake(0.18)

func _splat(pos: Vector2) -> void:
	var splat := Sprite2D.new()
	splat.texture = load("res://art/50_vfx/VFX_Blood_Splat.png")
	splat.light_mask = 2
	splat.position = pos + Vector2(0, -4)
	splat.rotation = rng.randf() * 0.4 - 0.2
	$Decals.add_child(splat)

func on_rabid_killed(r: Node2D, by: String) -> void:
	_splat(r.global_position)
	sfx.play_at("bonejam", r.global_position, -6.0)      # 一百公斤的东西倒在雪里
	if by != "":
		borrowed += 1
		spawn_float(r.global_position + Vector2(0, -130), "借刀杀人：清杀队替你清掉 1 只狂暴者", Color("#7dd3fc"))

func raise_alarm(pos: Vector2, _by: Node) -> void:
	sfx.play("radio", -4.0)
	sfx.play_at("klaxon", pos, -6.0)
	add_shake(0.3)
	spawn_float(pos + Vector2(0, -120), "探照灯锁定！", Color("#f43f5e"))
	for s in soldiers:
		if dist_m(s.global_position, pos) <= 30.0:
			s.alert_to(pos)

func on_soldier_alert(_s: Node) -> void:
	sfx.play("radio", -3.0)          # 面具里的电台叫了一声：他们开始喊人了
	add_shake(0.16)

func caught(by: Node) -> void:
	if state != "play":
		return
	caught_by = String(by.name)
	if by is Node2D:
		sfx.play_at("gunshot", (by as Node2D).global_position, 0.0, 0.02)
	add_shake(0.95)
	_end("caught")

func _end(reason: String) -> void:
	state = reason
	player.frozen = true
	sfx.set_tension(0.0)             # 心跳停下：这一夜已经结束了
	match reason:
		"extracted":
			sfx.play("beep")
			add_shake(0.12)
		"dawn":
			sfx.play("dawn_horn", -2.0)
			add_shake(0.18)
		"abort":
			sfx.play("thirst")
		"frozen":
			sfx.play("freeze", -2.0)
			add_shake(0.25)
		"downed":
			sfx.play("bonejam", -2.0)
			add_shake(0.7)
		"caught":
			sfx.play("klaxon", -5.0)
			add_shake(0.9)

# P1: 把夜潜结果填进 RaidSim 数据容器，走 CampaignSim.finish_raid 统一结算，
#     再切回 campaign.tscn（_ready 会 take_sim 取回原 sim）。
func _return_to_campaign(reason: String) -> void:
	if not in_campaign:
		return
	var sim = RaidBridge.sim
	if sim == null or sim.raid == null:
		RaidBridge.clear()
		get_tree().change_scene_to_file("res://scenes/campaign.tscn")
		return
	var R = sim.raid
	R.pack = pack.duplicate()
	R.player.hp = hp
	R.player.warmth = warmth
	R.load = {}            # 携带消耗品已并入 pack，finish_raid 不再重复归还
	R.half_saved = half_saved
	R.killed = borrowed    # 借刀杀人清掉的狂暴者
	R.looted = _count_searched()
	R.total_cont = containers.size()
	R.events = []
	if not pack.is_empty():
		R.add_event("good", "带回 %d 件物资" % pack.size(), "Brought back %d items" % pack.size())
	if half_saved > 0:
		R.add_event("good", "救下半人 %d 名" % half_saved, "Saved %d half-humans" % half_saved)
	if borrowed > 0:
		R.add_event("knife", "借刀杀人 ×%d" % borrowed, "Borrowed knife ×%d" % borrowed)
	if half_lost > 0:
		R.add_event("witness", "清杀队误杀半人 %d 名" % half_lost, "OSK gunned down %d half-humans" % half_lost)
	if reason == "dawn":
		R.add_event("note", "天亮前没回到撤离点：只带得回一半。", "Caught by dawn: only half the haul comes home.")
	# 道德账回写
	if conscience != 0.0:
		sim.raid_add_conscience(conscience)
	if tally > 0:
		sim.raid_add_tally(tally, "夜潜%s：亲手灭口" % level_zh, "%s: mercy kill" % level_en)
	sim.sound_on = not muted        # 战役里的音效开关跟着人走
	sim.finish_raid(reason)
	get_tree().change_scene_to_file("res://scenes/campaign.tscn")

func _count_searched() -> int:
	var n := 0
	for c in containers:
		if bool(c.get_meta("searched", false)):
			n += 1
	return n

# ============================================================================
# 输入
# ============================================================================
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if state == "choice":
			match k:
				KEY_1, KEY_KP_1:
					choose(0)
				KEY_2, KEY_KP_2:
					choose(1)
				KEY_3, KEY_KP_3:
					choose(2)
				KEY_ESCAPE:
					close_choice()
			get_viewport().set_input_as_handled()
			return
		match k:
			KEY_F:
				if state == "play":
					player.toggle_flashlight()
					sfx.play("wedge")
			KEY_G:
				if state == "play":
					_throw_can(get_global_mouse_position())
			KEY_M:
				muted = not muted
				sfx.set_muted(muted)
				AudioServer.set_bus_mute(0, muted)
			KEY_R:
				# 战役模式禁止重来（不能刷物资）；F2 独立跑可重开
				if not in_campaign:
					get_tree().reload_current_scene()
			KEY_ESCAPE:
				if state == "play":
					if in_campaign:
						if abort_pending:
							abort_pending = false
							_end("abort")
						else:
							abort_pending = true
							abort_timer = 2.5
					else:
						get_tree().change_scene_to_file("res://scenes/campaign.tscn")
				elif state != "choice":
					# 结束画面：战役回写结算，F2 重开
					if in_campaign:
						_return_to_campaign(state)
					else:
						get_tree().reload_current_scene()
			KEY_ENTER, KEY_KP_ENTER:
				if state != "play":
					if in_campaign:
						_return_to_campaign(state)
					else:
						get_tree().reload_current_scene()

func _throw_can(target: Vector2) -> void:
	if cans <= 0:
		spawn_float(player.global_position + Vector2(0, -120), "没有空罐头了", Color("#94a3b8"))
		return
	var from: Vector2 = player.global_position
	var d := to_m(target - from)
	if d.length() > CAN_RANGE:
		d = d.normalized() * CAN_RANGE
		target = from + Vector2(d.x * PPM, d.y * PPM * SQ)
	cans -= 1
	sfx.play_at("can_throw", from, -8.0)
	thrown.append({"from": from, "to": target, "t": 0.0, "dur": 0.25 + d.length() / CAN_RANGE * 0.5})

# ============================================================================
# 表现
# ============================================================================
func spawn_float(pos: Vector2, txt: String, col: Color) -> void:
	floats.append({"pos": pos, "txt": txt, "col": col, "life": 2.2})

func _update_fx(delta: float) -> void:
	for r in ripples:
		r["r"] = float(r["r"]) + delta * maxf(6.0, float(r["max"]) * 2.2)
		r["life"] = clampf(1.0 - float(r["r"]) / maxf(0.01, float(r["max"])), 0.0, 1.0)
	ripples = ripples.filter(func(r): return float(r["life"]) > 0.0)
	for f in floats:
		f["life"] = float(f["life"]) - delta
		f["pos"] = Vector2(f["pos"]) + Vector2(0, -22.0 * delta)
	floats = floats.filter(func(f): return float(f["life"]) > 0.0)
	var landed: Array = []
	for c in thrown:
		c["t"] = float(c["t"]) + delta / float(c["dur"])
		if float(c["t"]) >= 1.0:
			landed.append(c)
	for c in landed:
		thrown.erase(c)
		emit_noise(c["to"], CAN_NOISE, "can")   # 波纹 + 落在世界里的哐啷声（_voice_noise）

func _update_fade() -> void:
	var p: Vector2 = player.global_position
	for n in fade_props:
		var spr := n.get_node_or_null("Sprite") as Sprite2D
		if spr == null:
			continue
		var r := spr.get_rect()
		var top_left: Vector2 = n.global_position + r.position
		var behind: bool = p.y < n.global_position.y and p.x > top_left.x and p.x < top_left.x + r.size.x \
			and p.y > top_left.y + 20.0
		var target := 0.55 if behind else 1.0
		spr.modulate.a = move_toward(spr.modulate.a, target, get_process_delta_time() * 3.0)

func _update_post() -> void:
	var g := dawn_grade()
	var mat := post.material as ShaderMaterial
	if mat != null:
		var alarm := 0.0
		for s in soldiers:
			alarm = maxf(alarm, clampf(float(s.suspicion), 0.0, 1.0) if s.state == "alert" else 0.0)
		for r in rabids:
			if r.state in ["windup", "lunge"]:
				alarm = maxf(alarm, 0.6)
		if state == "caught" or state == "downed":
			alarm = 1.0
		alarm = maxf(alarm, hurt / 0.35)
		mat.set_shader_parameter("frost", clampf((35.0 - warmth) / 35.0, 0.0, 1.0))
		mat.set_shader_parameter("alarm", alarm)
		mat.set_shader_parameter("dawn", g)
		mat.set_shader_parameter("cam_offset", cam.get_screen_center_position())
	# 天亮：夜色（CanvasModulate）由夜青转黎明清灰，暴风雪变薄
	if night_mod != null:
		night_mod.color = NIGHT_MOD.lerp(DAWN_MOD, g)
	var snow_a := lerpf(1.0, DAWN_SNOW_A, g)
	if snow_back != null:
		snow_back.modulate.a = snow_a
	if snow_front != null:
		snow_front.modulate.a = snow_a
	# P2.5：风声随天亮退去；紧张度驱动心跳
	sfx.set_dawn(g)
	sfx.set_tension(tension_level())


## 紧张度 0..1：清杀兵的怀疑 / 警戒、狂暴者的追击与起跳、结局。喂给 NightSfx 的心跳。
func tension_level() -> float:
	var k := 0.0
	for s in soldiers:
		if s.state == "alert":
			k = maxf(k, clampf(float(s.suspicion), 0.0, 1.0))
		elif s.state in ["investigate", "search"]:
			k = maxf(k, 0.2 + 0.35 * clampf(float(s.suspicion), 0.0, 1.0))
	for r in rabids:
		if not r.is_alive():
			continue
		if r.state in ["windup", "lunge"]:
			k = 1.0
		elif r.state == "chase":
			k = maxf(k, clampf(1.0 - dist_m(player.global_position, r.global_position) / 14.0, 0.35, 1.0))
	if state in ["caught", "downed"]:
		k = 1.0
	return clampf(k, 0.0, 1.0)


## 镜头震动：trauma 模型（shake² 决定幅度），受伤 / 枪声 / 扑咬 / 警报 / 结局都往里加。
func add_shake(amount: float) -> void:
	shake = clampf(shake + amount, 0.0, 1.0)


func _apply_shake(delta: float) -> void:
	punch = maxf(0.0, punch - delta * 3.2)
	var z := 1.0 + punch * 0.06
	if not is_equal_approx(cam.zoom.x, z):
		cam.zoom = Vector2(z, z)
	if shake <= 0.0:
		if cam.offset != Vector2.ZERO:
			cam.offset = Vector2.ZERO
		if not is_zero_approx(cam.rotation):
			cam.rotation = 0.0
		return
	_shake_t += delta * (16.0 + 30.0 * shake)
	shake = maxf(0.0, shake - delta * (SHAKE_DECAY + 0.9 * shake))
	var k := shake * shake
	var amp := SHAKE_PX * k
	cam.offset = Vector2(
		sin(_shake_t * 1.7) + 0.4 * sin(_shake_t * 4.3),
		cos(_shake_t * 2.1) + 0.35 * cos(_shake_t * 5.1)) * amp * 0.72
	cam.rotation = sin(_shake_t * 1.3) * 0.014 * k

# ============================================================================
# HUD
# ============================================================================
func _build_hud() -> void:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.06, 0.72)
	sb.border_color = Color(0.2, 0.27, 0.33, 0.8)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(24, 24)
	hud_root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	var title := _label("%s · 第 %d 夜   %s" % [level_zh, day_n, level_en.to_upper()], 17, Color("#cbd5e1"))
	v.add_child(title)
	var row := HBoxContainer.new()
	row.add_child(_label("体温 WARMTH ", 14, Color("#94a3b8")))
	_bar_warm = ProgressBar.new()
	_bar_warm.custom_minimum_size = Vector2(220, 14)
	_bar_warm.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#f59e0b")
	_bar_warm.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.12, 0.15, 0.9)
	_bar_warm.add_theme_stylebox_override("background", bg)
	row.add_child(_bar_warm)
	v.add_child(row)
	var row2 := HBoxContainer.new()
	row2.add_child(_label("健康 HEALTH ", 14, Color("#94a3b8")))
	_bar_hp = ProgressBar.new()
	_bar_hp.custom_minimum_size = Vector2(220, 14)
	_bar_hp.show_percentage = false
	var fill2 := StyleBoxFlat.new()
	fill2.bg_color = Color("#e05656")
	_bar_hp.add_theme_stylebox_override("fill", fill2)
	_bar_hp.add_theme_stylebox_override("background", bg)
	row2.add_child(_bar_hp)
	v.add_child(row2)
	_lbl_status = _label("", 14, Color("#94a3b8"))
	v.add_child(_lbl_status)
	_lbl_bag = _label("", 14, Color("#e2e8f0"))
	_lbl_bag.custom_minimum_size = Vector2(420, 0)
	_lbl_bag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_lbl_bag)

	_lbl_hint = _label("", 15, Color(0.8, 0.85, 0.9, 0.85))
	_lbl_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_lbl_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_hint.offset_left = -760
	_lbl_hint.offset_right = 760
	_lbl_hint.offset_top = -64
	_lbl_hint.offset_bottom = -30
	hud_root.add_child(_lbl_hint)

	_choice_panel = PanelContainer.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.04, 0.03, 0.02, 0.9)
	csb.border_color = Color("#b45309")
	csb.set_border_width_all(2)
	csb.set_content_margin_all(22)
	_choice_panel.add_theme_stylebox_override("panel", csb)
	_choice_panel.set_anchors_preset(Control.PRESET_CENTER)
	_choice_panel.offset_left = -430
	_choice_panel.offset_right = 430
	_choice_panel.offset_top = -170
	_choice_panel.offset_bottom = 170
	_choice_panel.visible = false
	hud_root.add_child(_choice_panel)
	_choice_lbl = _label("", 17, Color("#e2e8f0"))
	_choice_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_choice_panel.add_child(_choice_lbl)

	_lbl_center = _label("", 30, Color("#f1f5f9"))
	_lbl_center.set_anchors_preset(Control.PRESET_CENTER)
	_lbl_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_center.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_center.offset_left = -700
	_lbl_center.offset_right = 700
	_lbl_center.offset_top = -170
	_lbl_center.offset_bottom = 170
	_lbl_center.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_lbl_center.add_theme_constant_override("outline_size", 8)
	hud_root.add_child(_lbl_center)

func _show_choice() -> void:
	var h = choice_half
	if h == null or _choice_lbl == null:
		return
	var med := has_medicine()
	var lines: Array[String] = [
		"抉择 · 他在发烧（半人 %s）" % h.tag,
		"",
		"一个半人缩在雪里发抖。瞳孔还在，但烫得吓人。",
		"清杀队分不清他和狂暴者 —— 手电扫到就开枪。",
		"",
		"[1]  喂阿司匹林 + 热水（各 1）　良知 +7" + ("" if med else "　—— 缺药"),
		"[2]  绕开，别惹麻烦　良知 −2",
		"[3]  撬棍灭口，划一道卌　良知 −10",
		"[Esc]  先不决定（他会继续烧）",
	]
	if choice_msg != "":
		lines.append("")
		lines.append(choice_msg)
	_choice_lbl.text = "\n".join(lines)
	_choice_panel.visible = true

func _label(txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _refresh_hud() -> void:
	if _bar_warm == null:
		return
	_bar_warm.value = warmth
	_bar_hp.value = hp
	var stance := "蹲伏" if player.crouching else ("冲刺" if player.sprinting else "步行")
	var light := "手电 开" if player.flashlight_on else "手电 关"
	var lit := "（暴露）" if player.flashlight_on or is_lit(player.global_position) else "（暗处）"
	var ground := " · 冻雪泥！" if player.on_slush else ""
	var chasing := 0
	for r in rabids:
		if r.state in ["chase", "windup", "lunge"]:
			chasing += 1
	var threat := (" · 被 %d 只狂暴者盯上" % chasing) if chasing > 0 else ""
	var dawn_str := ""
	if in_campaign and state == "play":
		dawn_str = (" · 天色发白 %ds！" if dawn_t > 0.0 else " · 天亮 %ds") % maxi(0, int(ceil(night_left)))
	_lbl_status.text = "%s · %s%s · 空罐头 ×%d · 借刀 ×%d · 良知 %+d · 卌 %d%s%s%s" % [
		stance, light, lit, cans, borrowed, int(conscience), tally, ground, threat, dawn_str]
	var names: Array[String] = []
	for id in pack:
		names.append(item_name(id))
	_lbl_bag.text = "背包 %d/%d：%s" % [pack.size(), bag_max, "、".join(names) if not names.is_empty() else "—"]
	var has_prize := pack.has(prize)
	if abort_pending:
		_lbl_hint.text = "再按 Esc 放弃这次夜潜？（背包清空，活着回 602 室）"
	elif dawn_t > 0.0:
		_lbl_hint.text = "天要亮了 —— %s（长按 E）" % extract_zh
	elif has_prize:
		_lbl_hint.text = "%s到手 —— %s（长按 E）" % [item_name(prize), extract_zh] \
			+ ("   ·   R 重来  Esc 返回战役" if not in_campaign else "")
	else:
		_lbl_hint.text = objective_zh + "   ·   Ctrl 蹲  Shift 跑  E 搜刮  F 手电  G 罐头"
	var again_hint := "R / Enter 重来" if not in_campaign else "Enter 回 602 室"
	match state:
		"play", "choice":
			_lbl_center.text = ""
		"caught":
			_lbl_center.text = "被清杀队发现\nОСК открыл огонь\n\n%s" % again_hint
			_lbl_center.add_theme_color_override("font_color", Color("#fca5a5"))
		"downed":
			_lbl_center.text = "被狂暴者扑倒了\n高烧的身体烫得像炉子。\n\n%s" % again_hint
			_lbl_center.add_theme_color_override("font_color", Color("#fca5a5"))
		"frozen":
			_lbl_center.text = "体温耗尽，倒在了雪里\n\n%s" % again_hint
			_lbl_center.add_theme_color_override("font_color", Color("#bae6fd"))
		"dawn":
			_lbl_center.text = "天亮了\n你连滚带爬回到撤离点——只带得回一半。\n\n%s" % again_hint
			_lbl_center.add_theme_color_override("font_color", Color("#bae6fd"))
		"abort":
			_lbl_center.text = "你放弃了这次夜潜\n背包里的东西全留在了雪里。\n\n%s" % again_hint
			_lbl_center.add_theme_color_override("font_color", Color("#f59e0b"))
		"extracted":
			var names2: Array[String] = []
			for id in pack:
				names2.append(item_name(id))
			var line := ""
			if prize == "dial":
				line = "妈妈今晚有透析液了。" if has_prize else "空着手回去，妈妈还在等透析液。"
			else:
				line = "带回来的东西能换明天的口粮和药。" if not pack.is_empty() \
					else "空着手回去，602 室还是冷的。"
			var moral := "良知 %+d · 救下半人 %d · 误杀 %d · 卌 %d" % [int(conscience), half_saved, half_lost, tally]
			_lbl_center.text = "撤离成功 · %d 件物资 · 借刀 ×%d\n%s\n%s\n%s\n\n%s" % [
				pack.size(), borrowed, "、".join(names2), line, moral,
				"R / Enter 再来一夜   Esc 返回战役" if not in_campaign else "Enter 回 602 室 · 结算"]
			_lbl_center.add_theme_color_override("font_color", Color("#bbf7d0"))
