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
##       F 手电 · M 静音 · F5 重来（仅独立跑）· Esc 暂停菜单（继续 / 音量 / 放弃夜潜 / 退出）
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
const Beats := preload("res://scripts/night/LevelBeats.gd")
const Arsenal := preload("res://scripts/night/Arsenal.gd")
const Zones := preload("res://scripts/night/NightZones.gd")
const TEX_GLOW := preload("res://art/50_vfx/VFX_Light_Radial_Soft.png")
const TEX_BLOOD := preload("res://art/50_vfx/VFX_Blood_Mist.png")
const TEX_SPARK := preload("res://art/50_vfx/VFX_Impact_Spark.png")
const SovietUI := preload("res://scripts/ui/SovietUI.gd")
const SovietMeter := preload("res://scripts/ui/SovietMeter.gd")
const SovietChrome := preload("res://scripts/ui/SovietChrome.gd")
const SovietStarMeter := preload("res://scripts/ui/SovietStarMeter.gd")
const PauseMenuScript := preload("res://scripts/ui/PauseMenu.gd")

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
const INTERIOR_MOD := Color(0.40, 0.45, 0.58)             # 室内关：抬一点冷色底光，别让地面材质黑成一片
const DAWN_MOD := Color(0.60, 0.575, 0.565)               # 黎明前的清灰（比夜色亮、比白天冷）
const DAWN_SNOW_A := 0.5                                  # 天亮时雪粒子留多少
const INTERIOR_LEVELS := ["canteen", "sanitarium", "boiler", "underpass", "workshop", "greenhouse", "archive"] # 室内关：雪只在地面贴图里，不挂满屏飘雪
var base_mod := NIGHT_MOD                                 # 夜色基准：室内关换成 INTERIOR_MOD
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
var _pause: CanvasLayer = null      # Esc 暂停菜单（第一次按 Esc 时才建）
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
var mate_id := ""                # 本夜所带伙伴（_spawn_follower 写入；gulya 用于急救）
var _gulya_used := false         # 古丽娅「每夜救一次重伤」是否已用
var hurt := 0.0                # 受伤闪红计时
var borrowed := 0              # 借刀杀人：清杀队替你清掉的狂暴者
var rabids: Array = []
var halfs: Array = []
# 道德账（接进战役时按同样口径回写 CampaignSim：raid_add_conscience / raid_add_tally）
# --- 三区（白 / 红 / 黑）---
var zones: Array = []          # [{id, rects:[Rect2 米]}]，来自场景根的 metadata/zones
var zone_id := ""              # 玩家当前所在区（"" = 老场景没划分区）
var zone_time := 0.0           # 在当前区连续待了多久（红区「禁止进入」的宽限计时）
var zone_warned := false       # 红区提示只弹一次
var zone_curfew := false       # 红区：已经被清杀队盯上
var zone_seen := {}            # 已经进过的区（只报一次「进入黑区」）
var markets: Array = []        # 黑市（night_market）
var market_used := false       # 黑市一夜只做一次买卖
var survivors: Array = []      # 黑区的幸存者（night_survivor）
var survivor_seen := {}

var conscience := 0.0          # 本夜良知变化
var tally := 0                 # 卌 划痕（亲手灭口才划）
var half_saved := 0
var half_lost := 0             # 被清杀队误杀的半人
var choice_half = null       # NightHalf
var choice_msg := ""
var cans := 3

# ---- 战斗（P5）----
var weapons: Array[String] = ["crowbar"]
var w_idx := 0
var weapon := "crowbar"
var mag: Dictionary = {}                  # 武器 id → 弹匣内
var reserve: Dictionary = {}              # 武器 id → 备弹
var cool := 0.0                           # 攻击冷却
var reload_left := 0.0                    # 装填剩余时间（>0 = 正在装填）
var swing_t := 0.0                        # 挥击动画剩余时间
var muzzle_t := 0.0                       # 枪口焰剩余时间
var tracers: Array[Dictionary] = []       # 曳光：{from, to, life}
var impacts: Array[Dictionary] = []       # 弹着：{pos, life}
var casings: Array[Dictionary] = []       # 弹壳：{pos, vel, life}
var hit_marks: Array[Dictionary] = []     # 命中标记：{pos, life, kill}
var soldier_kills := 0
var rabid_kills := 0
var _w_sprite: Sprite2D = null
var _flash_sprite: Sprite2D = null
var _flash_light: PointLight2D = null
var _aim_noise := 0.0
var search_target: Node2D = null
var search_prog := 0.0
var extract_prog := 0.0
var exit_px := Vector2.ZERO
var ripples: Array[Dictionary] = []
var floats: Array[Dictionary] = []
var thrown: Array[Dictionary] = []
var soldiers: Array = []
var containers: Array = []
var _lock_hint_t := 0.0
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
var _lbl_zone: Label
var _lbl_bag: Label
var _lbl_hint: Label
var _lbl_center: Label
var _lbl_clock: Label
var _lbl_target: Label
var _lbl_bearing: Label
var _lbl_exit: Label
var _lbl_threat: Label
var _lbl_landmarks: Label
var _lbl_weapon: Label
var _m_warm
var _m_hp
var _lbl_warm_val: Label
var _lbl_hp_val: Label
var _chrome
var _brief_card: PanelContainer
var _brief_lbl: Label
var _choice_panel: PanelContainer
var _choice_head: Label
var _choice_lbl: Label
var _osk_bark_panel: PanelContainer = null
var _osk_bark_portrait: TextureRect = null
var _osk_bark_speaker: Label = null
var _osk_bark_label: Label = null
var _osk_bark_life := 0.0
var _osk_bark_priority := 0
var osk_last_bark: Dictionary = {}
var _hit_stop_serial := 0

# ============================================================================
# 关卡导演（LevelBeats.gd 的数据在这里跑）
# ============================================================================
var beats: Dictionary = {}
var landmarks: Array = []              # 本关地标（米制坐标）
var landmark_seen: Array[String] = []
var objective_px := Vector2.ZERO       # 关键物资所在容器的交互点（方位读数用）
var brief_t := 0.0                     # 开场档案卡剩余时间
var beat_events: Array = []            # 本关环境节拍
var beat_timer := 0.0                  # 距离下一次节拍
var beat_phase := ""                   # "" | warn | live
var beat_t := 0.0
var beat_idx := 0
var beat_flare := 0.0                  # 炉口爆燃的视觉强度 0..1
var beat_rake: Sprite2D = null         # 溜放中的车皮
var beat_rake_lane := 0.0
var beat_shoved := false               # 本次溜放是否已经被刮倒过
var _rake_rumble := 0.0                # 车皮轮轨声的节拍
var switch_thrown := false             # 转辙器是否已经扳到另一股
var forklift_used := false             # 叉车只能发动一次
var door_wedged := false               # 冷库铁门已被撬棍卡死（coldstore 的 wedge 机关）
var _flare_light: PointLight2D = null   # 炉口爆燃用的补光灯（不抢 NightFlicker 的火苗）
var _furnace_px := Vector2.ZERO

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
	# 室内关（食堂后厨 / 疗养院地下室）：关全屏飘雪、抬底光、风声退到窗外 + 房间低鸣
	if level_id in INTERIOR_LEVELS:
		for p in [snow_back, snow_front]:
			if p != null:
				p.emitting = false
				p.visible = false
		base_mod = INTERIOR_MOD
		if night_mod != null:
			night_mod.color = base_mod
		sfx.set_interior(true)
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
	_setup_special_containers()
	for m in get_tree().get_nodes_in_group("night_market"):
		markets.append(m)
	for sv in get_tree().get_nodes_in_group("night_survivor"):
		survivors.append(sv)
	fade_props = get_tree().get_nodes_in_group("night_fade")
	for z in get_tree().get_nodes_in_group("night_slush"):
		slush.append([to_m(z.global_position), Vector2(float(z.get_meta("rx", 1.0)), float(z.get_meta("ry", 1.0)))])
	for w in get_tree().get_nodes_in_group("night_warm"):
		warm_lights.append([w.global_position, float(w.get_meta("radius", 2.5))])
	exit_px = $Markers/Exit.global_position
	player.global_position = $Markers/Spawn.global_position
	cam.global_position = player.global_position
	cam.reset_smoothing()
	_setup_breath()
	_wire_audio()
	_init_beats()
	_init_weapons()
	_build_hud()
	_init_post_defaults()
	_spawn_follower()


func _spawn_follower() -> void:
	## 伙伴跟随：战役出发时 RaidBridge.cfg.mate 指定带谁（"" = 没带，不生成）；
	## F2 独立跑默认灰烬，可用 --mate=ash/anna/gulya/pavel/ivan 覆盖。
	mate_id = ""
	var rb := get_node_or_null("/root/RaidBridge")
	if rb != null and rb.active:
		mate_id = String(rb.cfg.get("mate", ""))
		if mate_id == "":
			return                                  # 战役这一夜没带伙伴 → 无跟随者
	else:
		mate_id = "ash"
		for a in OS.get_cmdline_args():
			if a.begins_with("--mate="):
				mate_id = a.substr(7)
	var script = load("res://scripts/night/NightFollower.gd")
	if script == null:
		return
	var f = script.new()
	f.mate_id = mate_id
	f.player_target = player
	f.ctl = self
	$World.add_child(f)
	f.global_position = player.global_position + Vector2(-48, 28)
	f.z_index = player.z_index


## 显式初始化后处理 shader 参数。未 set 过的 ShaderMaterial，get_shader_parameter
## 返回 null（即使 shader 里有默认值），这会让刚 _ready 后的断言 / float() 转换失败。
## 只设 shader 参数，不碰 sfx / 夜色 / 雪（那些等第一帧 _update_post 自然驱动）。
func _init_post_defaults() -> void:
	var mat := post.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("frost", clampf((35.0 - warmth) / 35.0, 0.0, 1.0))
	mat.set_shader_parameter("alarm", 0.0)
	mat.set_shader_parameter("dawn", 0.0)
	mat.set_shader_parameter("cam_offset", cam.get_screen_center_position())


## 关卡身份：build_scene.py 把这些写在根节点的 metadata 上，多张图共用同一个脚本。
## 旧场景 / 手工场景没有元数据时退回 yard 的口径（F2 独立跑也是这套）。
func _read_level_meta() -> void:
	level_id = String(get_meta("level_id", level_id))
	level_zh = String(get_meta("level_zh", level_zh))
	level_en = String(get_meta("level_en", level_en))
	objective_zh = String(get_meta("objective_zh", objective_zh))
	extract_zh = String(get_meta("extract_zh", extract_zh))
	prize = String(get_meta("prize", prize))
	# rail_y 元数据缺失 → 用兜底（yard）；写成空串 → 这张图没有铁轨（manor）
	rail_y = []
	if has_meta("rail_y"):
		for part in String(get_meta("rail_y", "")).split(","):
			var v := part.strip_edges()
			if v != "":
				rail_y.append(float(v))
	else:
		rail_y = DEFAULT_RAIL_Y.duplicate()
	# 三区：没有 metadata/zones 的老场景 → zones 为空，全套分区逻辑自动不生效
	zones = Zones.parse(String(get_meta("zones", "")))
	zone_id = ""
	zone_time = 0.0


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
	Engine.time_scale = 1.0
	_hit_stop_serial += 1
	# M 键 / 战役带过来的静音是按主总线做的，别把它留给下一个场景
	AudioServer.set_bus_mute(0, false)
	# 暂停菜单开着时切场景 / 退出：别把整棵树留在暂停态
	if is_inside_tree():
		get_tree().paused = false

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
func _setup_breath() -> void:
	# 呼吸白气统一用 Breath.gd（可复用、随机相位）：玩家 + 夜潜 NPC（清杀兵/狂暴者/半人/幸存者）。
	var b = load("res://scripts/night/Breath.gd").new()
	player.add_child(b)
	b.position = Vector2(8, -82)
	for arr in [soldiers, rabids, halfs, survivors]:
		for n in arr:
			if is_instance_valid(n):
				var nb = load("res://scripts/night/Breath.gd").new()
				n.add_child(nb)
				nb.position = Vector2(6, -72)

func _process(delta: float) -> void:
	t += delta
	hurt = maxf(0.0, hurt - delta)
	if _osk_bark_life > 0.0:
		_osk_bark_life = maxf(0.0, _osk_bark_life - delta)
		if _osk_bark_life <= 0.0:
			_osk_bark_priority = 0
			if _osk_bark_panel != null:
				_osk_bark_panel.visible = false
	cam.global_position = player.global_position + Vector2(0, -40)
	_apply_shake(delta)
	if state == "play":
		_update_zone(delta)
		_update_interact(delta)
		_update_combat(delta)
		_update_warmth(delta)
		_update_director(delta)
		if in_campaign:
			night_left = maxf(0.0, night_left - delta)
			update_dawn()
			if night_left <= 0.0:
				_end("dawn")
	_update_brief(delta)
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
	var mech := nearest_mechanism()
	if mech != null and Input.is_action_just_pressed("interact"):
		use_mechanism(mech)
		return
	var mkt := nearest_market()
	if mkt != null and Input.is_action_just_pressed("interact"):
		trade_market(mkt)
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
		var locked := bool(c.get_meta("locked", false))
		if locked and mate_id != "pavel":
			# 焊死的箱子：只有帕维尔的撬棍能开
			search_prog = 0.0
			search_target = null
			_lock_hint_t -= delta
			if _lock_hint_t <= 0.0:
				_lock_hint_t = 1.6
				spawn_float(c.global_position + Vector2(0, -90), "焊死了——需要帕维尔的撬棍", Color("#fbbf24"))
			return
		if search_target != c:
			search_target = c
			search_prog = 0.0
		search_prog += delta / (SEARCH_TIME * (1.8 if locked else 1.0))
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

func _setup_special_containers() -> void:
	## 每关放一个「焊死」箱（帕维尔可撬）与一个「隐藏」箱（伊万可显形）。
	## 运行时按索引确定性选取，不重生成场景，便于测试与平衡。
	var n := containers.size()
	if n == 0:
		return
	var li := n / 2
	containers[li].set_meta("locked", true)
	if n >= 2:
		var hi := n - 1
		if hi == li:
			hi = 0
		containers[hi].set_meta("hidden", true)
		containers[hi].modulate = Color(1, 1, 1, 0)   # 未显形前不可见


func nearest_container() -> Node2D:
	var best: Node2D = null
	var bd := REACH
	for c in containers:
		if bool(c.get_meta("searched", false)):
			continue
		if bool(c.get_meta("hidden", false)) and not bool(c.get_meta("revealed", false)):
			continue
		var d := dist_m(player.global_position, interact_point(c))
		if d < bd:
			bd = d
			best = c
	return best

# ============================================================================
# 三区（白 / 红 / 黑）：进区提示、红区禁止进入的盘问、黑区资源加成
# ============================================================================
func _update_zone(delta: float) -> void:
	if zones.is_empty():
		return
	var z := Zones.zone_at(zones, to_m(player.global_position))
	if z != zone_id:
		var prev := zone_id
		zone_id = z
		zone_time = 0.0
		zone_warned = false
		zone_curfew = false
		_on_zone_enter(prev, z)
	if zone_id == "red":
		# 白区户口进红区：先警告，再被盘问 —— 站在管制带里不动不是办法
		zone_time += delta
		if not zone_warned and zone_time >= Zones.CURFEW_WARN:
			zone_warned = true
			spawn_float(player.global_position + Vector2(0, -160), "红区 · 白区居民禁止进入", Color("#f87171"))
			sfx.play("beep", -6.0)
		if not zone_curfew and zone_time >= Zones.CURFEW_CHALLENGE:
			zone_curfew = true
			_curfew_challenge()
	_survivor_lines()


func _on_zone_enter(_from: String, to: String) -> void:
	if to == "":
		return
	var inf := Zones.info(to)
	if inf.is_empty() or bool(zone_seen.get(to, false)):
		return
	zone_seen[to] = true
	spawn_float(player.global_position + Vector2(0, -176), String(inf["zh"]), inf["hud_col"])
	if to == "black":
		sfx.play("radio", -12.0)


func _curfew_challenge() -> void:
	var best: Node2D = null
	var bd := 1e9
	for s in soldiers:
		if bool(s.dead):
			continue
		var d := dist_m(s.global_position, player.global_position)
		if d < bd:
			bd = d
			best = s
	spawn_float(player.global_position + Vector2(0, -176), "管制带 · 出示通行证！", SovietUI.SIGNAL)
	add_shake(0.14)
	if best != null:
		best.alert_to(player.global_position)
		on_soldier_alert(best)


## 黑市：一罐罐头换 8 发，一夜一次。只换手里已有的枪。
func nearest_market() -> Node2D:
	var best: Node2D = null
	var bd := REACH * 1.4
	for m in markets:
		var d := dist_m(player.global_position, (m as Node2D).global_position)
		if d < bd:
			bd = d
			best = m
	return best


func trade_market(m: Node2D) -> bool:
	if market_used:
		spawn_float(m.global_position + Vector2(0, -110), "摊主：今晚就这样了", Color("#94a3b8"))
		return false
	var wid := ""
	for w in ["rifle", "shotgun", "pistol"]:
		if weapons.has(w):
			wid = w
			break
	if wid == "":
		spawn_float(m.global_position + Vector2(0, -110), "摊主：你连枪都没有", Color("#94a3b8"))
		return false
	var cost := int(m.get_meta("cans", 1))
	var gain := int(m.get_meta("ammo", 8))
	if cans < cost:
		spawn_float(m.global_position + Vector2(0, -110), "摊主：罐头拿来", Color("#fbbf24"))
		return false
	var cap := int(Arsenal.spec(wid).get("reserve_max", 32))
	var cur := int(reserve.get(wid, 0))
	var add := mini(gain, cap - cur)
	if add <= 0:
		spawn_float(m.global_position + Vector2(0, -110), "摊主：你弹袋是满的", Color("#94a3b8"))
		return false
	cans -= cost
	reserve[wid] = cur + add
	market_used = true
	spawn_float(m.global_position + Vector2(0, -110),
		"黑市：−%d 罐头 · +%d %s" % [cost, add, Arsenal.short_zh(wid)], SovietUI.SIGNAL)
	sfx.play("click", -2.0)
	emit_noise(m.global_position, 2.0, "search")
	return true


## 幸存者：走近了说一句话（不挡路、不交互，纯气氛 + 黑区有人在的证明）
func _survivor_lines() -> void:
	for sv in survivors:
		var n := sv as Node2D
		if survivor_seen.has(n.name):
			continue
		if dist_m(player.global_position, n.global_position) > 2.4:
			continue
		survivor_seen[n.name] = true
		var role := String(n.get_meta("role", "survivor"))
		var line := "「不想变成账本上的死数字，就别站在探照灯底下！」"
		if role == "trader":
			line = "「黑麦罐头换步枪子弹，一物换一物，眼泪和良心在这儿免谈。」"
		spawn_float(n.global_position + Vector2(0, -120), line, Color("#c7d2fe"))


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
			spawn_float(top, "他眼底的紫黑血翳一点点退去，瞳孔重新聚起了人的光彩：「……谢谢你没拿撬棍砸死我……去西站水塔底下，找那个戴蓝毛线帽的老列车长……」", Color("#34d399"))
			sfx.play("beep")
		1:
			conscience -= 2.0
			h.resolved = "left"
			spawn_float(top, "你绕开了他。身后的呜咽仍在追你，仿佛那不是他的声音，而是你自己的。", Color("#94a3b8"))
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
		# 抉择面板之外也灭得了口（撬棍 / 枪）：账一样要记，但别重复记
		if h.resolved != "mercy":
			h.resolved = "mercy"
			tally += 1
			conscience -= 10.0
		spawn_float(h.global_position + Vector2(0, -124), "撬棍落下。日志背面多了一道卌；你忽然不敢确定，这一道究竟记的是他，还是你。", Color("#fbbf24"))
		return
	h.resolved = "osk"
	half_lost += 1
	conscience -= 4.0
	spawn_float(h.global_position + Vector2(0, -124), "清杀队打死了半人 %s —— 他方才还会喊渴，眼睛里还映着灯。" % h.tag,
		Color("#fca5a5"))

func interact_point(c: Node2D) -> Vector2:
	return c.global_position + Vector2(c.get_meta("interact_offset", Vector2.ZERO))

func _finish_search(c: Node2D) -> void:
	if bool(c.get_meta("locked", false)):
		c.set_meta("locked", false)
		spawn_float(c.global_position + Vector2(0, -120), "帕维尔撬开了焊死的箱子", Color("#7fb2e0"))
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
	# 黑区：离白区最远，东西也最多 —— 同一个容器多翻一件
	var n := 1 + (1 if rng.randf() < 0.45 else 0) + Zones.loot_bonus(Zones.zone_at(zones, to_m(c.global_position)))
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
	for id in got:
		ammo_from_item(id)
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
	if level_id in INTERIOR_LEVELS:
		# 室内：瓷砖 / 水磨石是脆的「咔」，湿混凝土与地坪漆是闷硬的一脚，不再是踩雪
		return "step_tile" if level_id == "canteen" else "step_concrete"
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
		_check_downed()

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
	if by == "player":
		rabid_kills += 1
		spawn_float(r.global_position + Vector2(0, -130), "亲手放倒 1 只狂暴者", Color("#fca5a5"))
	elif by != "":
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

func show_osk_bark(kind: String) -> void:
	var data: Dictionary = Data.OSK_BARKS.get(kind, {})
	if data.is_empty():
		return
	var priority: int = {"warning": 1, "chase": 2, "execute": 3, "death": 4}.get(kind, 0)
	if _osk_bark_life > 0.45 and priority < _osk_bark_priority:
		return
	var lines: Array = data.get("lines", [])
	if lines.is_empty():
		return
	var line: Dictionary = lines[rng.randi_range(0, lines.size() - 1)]
	var mood := String(data.get("mood", "calm"))
	var file := "Calm"
	match mood:
		"intense": file = "Intense"
		"death": file = "Death"
	_osk_bark_life = 3.4 if kind != "death" else 4.2
	_osk_bark_priority = priority
	osk_last_bark = {"kind": kind, "mood": mood, "zh": String(line.get("zh", ""))}
	if _osk_bark_portrait != null:
		_osk_bark_portrait.texture = load("res://art/10_characters/portraits/PRT_OSK_%s.png" % file)
	if _osk_bark_speaker != null:
		_osk_bark_speaker.text = "ОСК · " + String(data.get("speaker_zh", "清杀队"))
	if _osk_bark_label != null:
		_osk_bark_label.text = String(line.get("zh", ""))
	if _osk_bark_panel != null:
		_osk_bark_panel.visible = true

func on_soldier_warning(_s: Node) -> void:
	show_osk_bark("warning")
	sfx.play("radio", -8.0)

func on_soldier_alert(_s: Node) -> void:
	show_osk_bark("chase")
	sfx.play("radio", -3.0)          # 面具里的电台叫了一声：他们开始喊人了
	add_shake(0.16)

func caught(by: Node) -> void:
	if state != "play":
		return
	show_osk_bark("execute")
	caught_by = String(by.name)
	if by is Node2D:
		sfx.play_at("gunshot", (by as Node2D).global_position, 0.0, 0.02)
	add_shake(0.95)
	_end("caught")

func _check_downed() -> void:
	## 古丽娅「每夜救一次重伤」：本夜带古丽娅且急救还没用过，hp 归零不死、拉回 40。
	if mate_id == "gulya" and not _gulya_used:
		_gulya_used = true
		hp = 40.0
		spawn_float(player.global_position + Vector2(0, -150), "古丽娅急救：这一夜她把你拉了回来", Color("#63d18a"))
		return
	_end("downed")


func _end(reason: String) -> void:
	state = reason
	player.frozen = true
	# 环境的节拍也停下：别让画面在某次爆燃的红里定格
	beat_phase = ""
	beat_flare = 0.0
	if beat_rake != null and is_instance_valid(beat_rake):
		beat_rake.queue_free()
		beat_rake = null
	muzzle_t = 0.0
	reload_left = 0.0
	if _flash_sprite != null:
		_flash_sprite.visible = false
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
	R.killed = borrowed + rabid_kills    # 借刀杀人 + 亲手放倒的狂暴者
	# 枪里的余弹带回去（战役结算里武器行显示「弹匣 / 备弹」）
	match String(R.weapon.get("id", "")):
		"mosin":
			R.ammo = int(mag.get("rifle", 0)) + int(reserve.get("rifle", 0))
		"shotgun":
			R.ammo = int(mag.get("shotgun", 0)) + int(reserve.get("shotgun", 0))
	R.looted = _count_searched()
	R.total_cont = containers.size()
	R.events = []
	if not pack.is_empty():
		R.add_event("good", "带回 %d 件物资" % pack.size(), "Brought back %d items" % pack.size())
	if half_saved > 0:
		R.add_event("good", "救下半人 %d 名" % half_saved, "Saved %d half-humans" % half_saved)
	if borrowed > 0:
		R.add_event("knife", "借刀杀人 ×%d" % borrowed, "Borrowed knife ×%d" % borrowed)
	if rabid_kills > 0:
		R.add_event("good", "亲手放倒狂暴者 ×%d" % rabid_kills, "Rabids put down ×%d" % rabid_kills)
	if soldier_kills > 0:
		R.add_event("witness", "打死清杀兵 ×%d" % soldier_kills, "OSK soldiers killed ×%d" % soldier_kills)
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
# 暂停菜单（Esc）：SceneTree.paused 冻结世界；放弃夜潜 / 退出游戏走这里
# ============================================================================
func open_pause() -> void:
	if state != "play":
		return
	if _pause == null:
		_pause = PauseMenuScript.new()
		_pause.name = "PauseMenu"
		if in_campaign:
			_pause.abort_label = "放弃这次夜潜"
			_pause.abort_hint = "背包清空，活着回 602 室"
		else:
			_pause.abort_label = "返回战役"
			_pause.abort_hint = "F2 独立跑：回到战役标题页"
		_pause.abort_requested.connect(_on_pause_abort)
		_pause.quit_requested.connect(_on_pause_quit)
		add_child(_pause)
	search_target = null
	search_prog = 0.0
	extract_prog = 0.0
	_pause.open()


func close_pause() -> void:
	if _pause != null:
		_pause.close()


func is_paused() -> bool:
	return _pause != null and _pause.is_open()


func _on_pause_abort() -> void:
	if in_campaign:
		_end("abort")
	else:
		get_tree().change_scene_to_file("res://scenes/campaign.tscn")


## 退出游戏：战役存档停在出发前的 602 室（夜潜中途不存档），这一夜等于没发生。
func _on_pause_quit() -> void:
	get_tree().paused = false
	RaidBridge.clear()
	get_tree().quit()


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
			KEY_1, KEY_KP_1, KEY_2, KEY_KP_2, KEY_3, KEY_KP_3, KEY_4, KEY_KP_4:
				# 1~4 换家伙（撬棍 / ТТ / 莫辛 / 双管）—— 只切已经到手的
				if state == "play":
					var slot := {KEY_1: 0, KEY_KP_1: 0, KEY_2: 1, KEY_KP_2: 1,
						KEY_3: 2, KEY_KP_3: 2, KEY_4: 3, KEY_KP_4: 3}
					if slot.has(k):
						swap_weapon(int(slot[k]))
			KEY_F5:
				# 战役模式禁止重来（不能刷物资）；F2 独立跑可重开
				if not in_campaign:
					get_tree().reload_current_scene()
			KEY_ESCAPE:
				if state == "play":
					open_pause()
					get_viewport().set_input_as_handled()
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
# 战斗（P5）：撬棍 / ТТ-33 / 莫辛纳甘 / 截短双管
# ============================================================================
## 战役里的武器 id（CampaignData.WEAPONS）→ 军械库 id。
## 砍骨刀不是撬棍，但都是「贴上去、安静、慢」的一类，共用手感。
const CARRY_MAP := {
	"fist": "crowbar", "crowbar": "crowbar", "cleaver": "crowbar",
	"shotgun": "shotgun", "mosin": "rifle",
}

## 开场带什么：撬棍永远在；枪按战役里已经拼出来的算，F2 独立跑给手枪 + 步枪做验收。
func _init_weapons() -> void:
	weapons.clear()
	mag.clear()
	reserve.clear()
	_add_weapon("crowbar")
	var carried: Array[String] = []
	if in_campaign:
		# CampaignSim.depart() 写的是整张武器表（RaidSim 也按 Dictionary 读），F2 单独跑时才可能是 id 字符串
		var wv: Variant = RaidBridge.cfg.get("weapon", "crowbar")
		var bridged: String = String(wv.get("id", "crowbar")) if wv is Dictionary else String(wv)
		carried.append(String(CARRY_MAP.get(bridged, "crowbar")))
		carried.append("pistol")            # 缴获的 ТТ 是阿列克谢的底牌
	else:
		carried = ["pistol", "rifle"]
	for id in carried:
		_add_weapon(String(id))
	w_idx = 0
	for i in weapons.size():
		if weapons[i] != "crowbar":
			w_idx = i
			break
	weapon = weapons[w_idx]

	# 手里的家伙：一张会跟着朝向转的精灵 + 枪口焰 + 一点补光
	_w_sprite = Sprite2D.new()
	_w_sprite.name = "Weapon"
	_w_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_w_sprite.light_mask = 2
	_w_sprite.z_index = 2
	player.add_child(_w_sprite)

	_flash_sprite = Sprite2D.new()
	_flash_sprite.name = "MuzzleFlash"
	_flash_sprite.texture = load("res://art/50_vfx/VFX_MuzzleFlash_Sheet.png")
	_flash_sprite.hframes = 4
	_flash_sprite.light_mask = 2
	_flash_sprite.z_index = 3
	_flash_sprite.visible = false
	player.add_child(_flash_sprite)

	_flash_light = PointLight2D.new()
	_flash_light.name = "MuzzleLight"
	_flash_light.texture = TEX_GLOW
	_flash_light.texture_scale = 2.2
	_flash_light.energy = 0.0
	_flash_light.light_mask = 3
	player.add_child(_flash_light)
	_pose_weapon(true)


func _add_weapon(id: String) -> void:
	if not Arsenal.has(id) or weapons.has(id):
		return
	weapons.append(id)
	mag[id] = Arsenal.start_mag(id)
	reserve[id] = Arsenal.start_reserve(id)


func cur_w() -> Dictionary:
	return Arsenal.spec(weapon)


func cur_is_gun() -> bool:
	return Arsenal.is_gun(weapon)


## 已经到手的武器列表（HUD 的 1~4 槽位用）
func weapon_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in Arsenal.ORDER.size():
		var id := String(Arsenal.ORDER[i])
		out.append({"id": id, "owned": weapons.has(id), "slot": i + 1,
			"label": Arsenal.short_zh(id)})
	return out


func swap_weapon(slot: int) -> void:
	var order := Arsenal.ORDER
	if slot < 0 or slot >= order.size():
		return
	var id := String(order[slot])
	if not weapons.has(id) or id == weapon:
		return
	weapon = id
	w_idx = slot
	reload_left = 0.0
	cool = 0.0
	swing_t = 0.0
	_pose_weapon(true)
	sfx.play("click", -10.0)
	spawn_float(player.global_position + Vector2(0, -120), Arsenal.name_zh(id), SovietUI.OCHRE)


func _pose_weapon(refresh_texture := false) -> void:
	if _w_sprite == null:
		return
	var w := cur_w()
	if refresh_texture or _w_sprite.texture == null:
		_w_sprite.texture = load(String(w.get("tex", "")))
	var s := float(w.get("scale", 0.5))
	_w_sprite.scale = Vector2(s, s)
	_w_sprite.rotation = player.facing
	_w_sprite.flip_v = cos(player.facing) < 0.0


## 每帧的战斗状态：冷却 / 收尾装填 / 握枪姿势 / 枪口焰衰减 / 攻击输入。
func _update_combat(delta: float) -> void:
	cool = maxf(0.0, cool - delta)
	swing_t = maxf(0.0, swing_t - delta)
	muzzle_t = maxf(0.0, muzzle_t - delta)
	if reload_left > 0.0:
		reload_left -= delta
		if reload_left <= 0.0:
			_finish_reload()
	if _flash_sprite != null:
		_flash_sprite.visible = muzzle_t > 0.0
		if muzzle_t > 0.0:
			var k := clampf(1.0 - muzzle_t / 0.07, 0.0, 0.999)
			_flash_sprite.frame = int(k * 4.0)
			var dir := _aim_vec()
			_flash_sprite.position = Vector2(dir.x, dir.y) * (34.0 + 8.0 * k) + Vector2(0, -44)
			_flash_sprite.scale = Vector2(0.55, 0.55)
	if _flash_light != null:
		_flash_light.energy = 2.6 * clampf(muzzle_t / 0.07, 0.0, 1.0)
		_flash_light.position = _w_sprite.position if _w_sprite != null else Vector2.ZERO
	_pose_weapon()
	if Input.is_action_just_pressed("reload"):
		start_reload()
	if player.frozen:
		return
	var w := cur_w()
	if String(w.get("kind", "melee")) == "melee":
		if Input.is_action_pressed("attack_primary") and cool <= 0.0:
			melee_swing()
		return
	if Input.is_action_just_pressed("attack_primary"):
		shoot()


## 朝向：地面坐标里指向鼠标的单位向量（y 已除以压缩比）。
func _aim_vec() -> Vector2:
	return Vector2(cos(player.facing), sin(player.facing))


func start_reload() -> void:
	if not cur_is_gun():
		return
	if reload_left > 0.0:
		return
	var id := weapon
	if int(mag.get(id, 0)) >= int(cur_w().get("mag", 0)):
		return
	if int(reserve.get(id, 0)) <= 0:
		sfx.play("click", -8.0)
		spawn_float(player.global_position + Vector2(0, -120), "没有备用弹药了", SovietUI.ASH)
		return
	reload_left = float(cur_w().get("reload", 1.4))
	sfx.play("reload", -3.0)
	emit_noise(player.global_position, 4.0, "search")


func _finish_reload() -> void:
	var id := weapon
	var cap := int(cur_w().get("mag", 0))
	var have := int(mag.get(id, 0))
	var pool := int(reserve.get(id, 0))
	var need := cap - have
	var take := mini(need, pool)
	mag[id] = have + take
	reserve[id] = pool - take
	sfx.play("click", -12.0)


func shoot() -> void:
	if reload_left > 0.0 or cool > 0.0:
		return
	var w := cur_w()
	var id := weapon
	if int(mag.get(id, 0)) <= 0:
		sfx.play("click", -6.0)
		start_reload()
		return
	mag[id] = int(mag.get(id, 0)) - 1
	cool = 1.0 / maxf(0.2, float(w.get("rate", 2.0)))
	muzzle_t = 0.07
	var noise := float(w.get("noise", 26.0))
	var origin: Vector2 = player.global_position + Vector2(0, -40)
	var dir := _aim_vec()
	# 声纹 + AI：枪声自己不听「gunshot」，用这支枪的音色（步枪 / 双管各有各的响）
	sfx.play_at(String(w.get("sfx", "gunshot")), origin, 0.0, 0.02)
	emit_noise(player.global_position, noise, "gun", true)
	for s in soldiers:
		if s.is_alive() and dist_m(s.global_position, player.global_position) <= noise * 0.8:
			s.alert_to(player.global_position)          # 枪声：整片巡逻朝你压过来
	add_shake(clampf(0.22 + float(w.get("dmg", 40.0)) / 600.0, 0.2, 0.42))
	punch = 0.5
	casings.append({"pos": origin + Vector2(cos(player.facing - 1.2) * 10.0, -18.0),
		"vel": Vector2(randf_range(-40.0, 40.0), randf_range(-90.0, -40.0)), "life": 1.1})
	# 逐颗弹丸做命中
	var pellets := int(w.get("pellets", 1))
	var spread := float(w.get("spread", 1.0))
	var reach := float(w.get("reach", 16.0))
	var dmg := float(w.get("dmg", 40.0))
	for i in pellets:
		var ang: float = float(player.facing) + deg_to_rad(randf_range(-spread, spread))
		_cast_shot(origin, Vector2(cos(ang), sin(ang)), reach, dmg)


## 一发（或一颗弹丸）：先看有没有打到人，再看打到哪儿。
func _cast_shot(origin: Vector2, dir: Vector2, reach_m: float, dmg: float) -> void:
	var hit := _hit_enemy(origin, dir, reach_m)
	var to := _ray_stop(origin, dir, reach_m)
	if not hit.is_empty():
		var node: Node2D = hit["node"]
		to = origin + _m_dir_px(dir) * (float(hit["t"]) * PPM)
		_damage_enemy(node, dmg, "player")
		hit_marks.append({"pos": node.global_position + Vector2(0, -46), "life": 0.45,
			"kill": node.has_method("is_alive") and not node.is_alive()})
		_spawn_vfx(TEX_BLOOD, to, 0.9, 0.35)
	else:
		_spawn_vfx(TEX_SPARK, to, 0.75, 0.2)
	tracers.append({"from": origin, "to": to, "life": 0.07})


func _m_dir_px(dir: Vector2) -> Vector2:
	return Vector2(dir.x, dir.y * SQ).normalized()


## 子弹会被什么挡住：只有墙 / 车厢 / 大件（物理层 1）。
func _ray_stop(origin: Vector2, dir: Vector2, reach_m: float) -> Vector2:
	var dpx := _m_dir_px(dir)
	var to := origin + dpx * (reach_m * PPM)
	var q := PhysicsRayQueryParameters2D.create(origin, to, 1)
	var res := get_world_2d().direct_space_state.intersect_ray(q)
	if res.is_empty():
		return to
	return res["position"]


## 射线上的第一个活人（含清杀兵 / 狂暴者 / 半人）。返回 {node, t}，t 为逻辑米。
func _hit_enemy(origin: Vector2, dir: Vector2, reach_m: float) -> Dictionary:
	var best := {}
	var bd := reach_m
	for e in _combat_targets():
		# 枪从胸口高度出去：目标也按胸口高度算，别让「脚的偏移」变成固定偏斜
		var rel := to_m((e.global_position + Vector2(0, -40)) - origin)
		var t := rel.dot(dir)
		if t <= 0.15 or t > reach_m:
			continue
		var perp := absf(rel.cross(dir))
		if perp > _hit_radius(e):
			continue
		if not los_clear(origin, e.global_position, 1):
			continue
		if t < bd:
			bd = t
			best = {"node": e, "t": t}
	return best


func _combat_targets() -> Array:
	var out: Array = []
	for s in soldiers:
		if s.is_alive():
			out.append(s)
	for r in rabids:
		if r.is_alive():
			out.append(r)
	for h in halfs:
		if h.is_alive():
			out.append(h)
	return out


func _hit_radius(e: Node) -> float:
	if e.is_in_group("night_osk"):
		return float(Arsenal.HIT_R["soldier"])
	if e.is_in_group("night_rabid"):
		return float(Arsenal.HIT_R["rabid"])
	return float(Arsenal.HIT_R["half"])


func _damage_enemy(e: Node, dmg: float, by: String, melee := false) -> void:
	if not e.has_method("hit"):
		return
	# 命中确认的三段式：极短停帧 → 敌人暖白闪 → 震动/命中标记/血雾。
	# 只冻结几十毫秒，不改变武器伤害、AI 判定或战役结算。
	var spr = e.get("sprite")
	if spr is Sprite2D:
		spr.modulate.r = 2.4
		spr.modulate.g = 1.9
		spr.modulate.b = 1.35
		var flash: Tween = spr.create_tween().set_parallel(true)
		flash.tween_property(spr, "modulate:r", 1.0, 0.13)
		flash.tween_property(spr, "modulate:g", 1.0, 0.13)
		flash.tween_property(spr, "modulate:b", 1.0, 0.13)
	hit_stop(0.058 if melee else 0.028)
	e.hit(dmg, by)


## 撬棍：扇形近战。安静，但要贴到 1.9m 内，而且一次只能挑一个。
func melee_swing() -> void:
	var w := cur_w()
	cool = 1.0 / maxf(0.3, float(w.get("rate", 1.4)))
	swing_t = 0.24
	sfx.play_at("swing", player.global_position, -3.0, 0.08)
	var reach := float(w.get("reach", 1.9))
	var half := float(w.get("arc", 0.85))
	var dir := _aim_vec()
	var best: Node = null
	var bd := reach
	for e in _combat_targets():
		var rel := to_m(e.global_position - player.global_position)
		var d := rel.length()
		if d > reach or d < 0.01:
			continue
		if absf(angle_difference(dir.angle(), rel.angle())) > half:
			continue
		if not los_clear(player.global_position, e.global_position, 1):
			continue
		if d < bd:
			bd = d
			best = e
	if best != null:
		_damage_enemy(best, float(w.get("dmg", 34.0)), "player", true)
		sfx.play_at("crowbar_hit", best.global_position, 0.0)
		add_shake(0.46)
		punch = 0.85
		hit_marks.append({"pos": best.global_position + Vector2(0, -46), "life": 0.45,
			"kill": not best.has_method("is_alive") or not best.is_alive()})
		_spawn_vfx(TEX_BLOOD,
			best.global_position + Vector2(0, -44), 1.15, 0.36)
	emit_noise(player.global_position, float(w.get("noise", 4.5)), "step", true)


func _spawn_vfx(tex: Texture2D, pos: Vector2, scale_k: float, life: float) -> void:
	impacts.append({"pos": pos, "life": life, "tex": tex.resource_path, "scale": scale_k})


## 搜到弹药类物品 → 补备弹（武器没到手时也能先攒着）
func ammo_from_item(item_id: String) -> void:
	var gain: Dictionary = Arsenal.ammo_for(item_id)
	if gain.is_empty():
		return
	var got: Array[String] = []
	for id in gain.keys():
		if not weapons.has(String(id)):
			continue
		var cap := int(Arsenal.spec(String(id)).get("reserve_max", 32))
		var cur := int(reserve.get(String(id), 0))
		var add := mini(int(gain[id]), cap - cur)
		if add <= 0:
			continue
		reserve[String(id)] = cur + add
		got.append("+%d %s" % [add, Arsenal.short_zh(String(id))])
	if not got.is_empty():
		spawn_float(player.global_position + Vector2(0, -150), "弹药 " + "、".join(got), SovietUI.SIGNAL)


# ============================================================================
# 战斗的后果（敌人那边回调过来）
# ============================================================================
func on_soldier_hurt(s: Node, _by: String) -> void:
	sfx.play_at("bonejam", s.global_position, -6.0)
	add_shake(0.12)


func on_soldier_killed(s: Node, _by: String) -> void:
	show_osk_bark("death")
	soldier_kills += 1
	conscience -= 0.5
	_splat(s.global_position)
	sfx.play_at("bonejam", s.global_position, -4.0)
	spawn_float(s.global_position + Vector2(0, -140),
		"清杀兵倒了 —— 剩下的人会搜得更凶", SovietUI.BLOOD_LIT)
	# 同僚倒下：附近的人直接压过来
	for other in soldiers:
		if other != s and other.is_alive() and dist_m(other.global_position, s.global_position) <= 34.0:
			other.alert_to(s.global_position)


# ============================================================================
# 表现
# ============================================================================
const FLOAT_LINE := 24.0         # 浮字行高：同一处同时冒出几句时往上错开一行
const FLOAT_MAX := 6             # 屏幕上同时最多几句浮字，多了挤掉最旧的

func spawn_float(pos: Vector2, txt: String, col: Color) -> void:
	var wrapped := Data.wrap_float_text(txt)
	var rows := wrapped.split("\n")
	var p := pos - Vector2(0, FLOAT_LINE * (rows.size() - 1))
	for _i in 8:
		var clash := false
		for f in floats:
			var q: Vector2 = f["pos"]
			if absf(q.x - p.x) < 320.0 and absf(q.y - p.y) < FLOAT_LINE:
				clash = true
				break
		if not clash:
			break
		p.y -= FLOAT_LINE
	var life := 2.2 if rows.size() == 1 else clampf(2.2 + txt.length() * 0.055, 3.5, 7.0)
	floats.append({"pos": p, "txt": wrapped, "col": col, "life": life})
	while floats.size() > FLOAT_MAX:
		floats.pop_front()

func _update_fx(delta: float) -> void:
	for r in ripples:
		r["r"] = float(r["r"]) + delta * maxf(6.0, float(r["max"]) * 2.2)
		r["life"] = clampf(1.0 - float(r["r"]) / maxf(0.01, float(r["max"])), 0.0, 1.0)
	ripples = ripples.filter(func(r): return float(r["life"]) > 0.0)
	for f in floats:
		f["life"] = float(f["life"]) - delta
		f["pos"] = Vector2(f["pos"]) + Vector2(0, -22.0 * delta)
	floats = floats.filter(func(f): return float(f["life"]) > 0.0)
	for tr in tracers:
		tr["life"] = float(tr["life"]) - delta
	tracers = tracers.filter(func(x): return float(x["life"]) > 0.0)
	for im in impacts:
		im["life"] = float(im["life"]) - delta
	impacts = impacts.filter(func(x): return float(x["life"]) > 0.0)
	for hm in hit_marks:
		hm["life"] = float(hm["life"]) - delta
	hit_marks = hit_marks.filter(func(x): return float(x["life"]) > 0.0)
	var settled: Array[Dictionary] = []
	for c in casings:
		c["life"] = float(c["life"]) - delta
		var v: Vector2 = c["vel"]
		v.y += 240.0 * delta
		c["vel"] = v
		c["pos"] = Vector2(c["pos"]) + v * delta
		if float(c["life"]) > 0.0:
			settled.append(c)
	casings = settled
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
		alarm = maxf(alarm, beat_flare)          # 炉口爆燃：整屏泛红，但不是警报 —— 是炉膛
		mat.set_shader_parameter("frost", clampf((35.0 - warmth) / 35.0, 0.0, 1.0))
		mat.set_shader_parameter("alarm", alarm)
		mat.set_shader_parameter("dawn", g)
		mat.set_shader_parameter("cam_offset", cam.get_screen_center_position())
	# 炉口爆燃：补光灯顶上（火焰那两盏归 NightFlicker 管，别去抢）
	if _flare_light != null and is_instance_valid(_flare_light):
		_flare_light.energy = 3.4 * beat_flare
	# 天亮：夜色（CanvasModulate）由夜青转黎明清灰，暴风雪变薄
	if night_mod != null:
		night_mod.color = base_mod.lerp(DAWN_MOD, g)
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


func hit_stop(duration: float) -> void:
	_hit_stop_serial += 1
	var serial := _hit_stop_serial
	Engine.time_scale = 0.08
	await get_tree().create_timer(duration, true, false, true).timeout
	if serial == _hit_stop_serial:
		Engine.time_scale = 1.0


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
# 关卡导演：档案头 / 地标勘踏 / 环境节拍 / 专属机关
#   数据源：scripts/night/LevelBeats.gd（三张图共用本脚本，差异全在数据里）
#   原则：不新增美术资产、不改场景文件；一切都挂在已有节点与已有音色上。
# ============================================================================
func _init_beats() -> void:
	beats = Beats.for_level(level_id)
	landmarks = beats.get("landmarks", []).duplicate(true)
	beat_events = beats.get("events", []).duplicate(true)
	landmark_seen = []
	brief_t = 7.5 if not (beats.get("brief", []) as Array).is_empty() else 0.0
	beat_timer = float(beats.get("first_beat", 0.0))
	beat_phase = ""
	beat_t = 0.0
	beat_idx = 0
	beat_flare = 0.0
	beat_rake = null
	switch_thrown = false
	forklift_used = false
	door_wedged = false
	objective_px = _find_objective_point()
	_gather_furnace_lights()


## 关键物资在哪：优先找「必出 prize」的容器，找不到就退回撤离点（HUD 不会指错方向）。
func _find_objective_point() -> Vector2:
	for c in containers:
		if String(c.get_meta("guaranteed", "")) == prize:
			return interact_point(c)
	for c in containers:
		if String(c.get_meta("guaranteed", "")) != "":
			return interact_point(c)
	return exit_px


## 炉口：manor 的 Lights/Furnace（挂着 NightFlicker 的火苗调制）。
## 爆燃不能去改那两盏灯的能量 —— NightFlicker 每帧会把它们写回基础值；
## 所以在 Lights 下单独挂一盏「补光」灯，只由爆燃驱动，平时 energy = 0。
func _gather_furnace_lights() -> void:
	_flare_light = null
	_furnace_px = Vector2.ZERO
	var node := get_node_or_null("Lights/Furnace") as Node2D
	if node == null:
		return
	_furnace_px = node.global_position
	var tex: Texture2D = TEX_GLOW
	if tex == null:
		return
	var flare := PointLight2D.new()
	flare.name = "FlareBurst"
	flare.texture = tex
	flare.color = Color(1.0, 0.72, 0.42)
	flare.energy = 0.0
	flare.texture_scale = 3.6
	flare.light_mask = 3
	var parent := node.get_parent()
	if parent == null:
		return
	parent.add_child(flare)
	flare.global_position = _furnace_px
	_flare_light = flare


func _m_px(pos: Array) -> Vector2:
	## 米制坐标（x 东 / y 南）→ 像素（地面按 SQ 压缩）
	return Vector2(float(pos[0]) * PPM, float(pos[1]) * PPM * SQ)


func _update_brief(delta: float) -> void:
	if brief_t <= 0.0:
		if _brief_card != null and _brief_card.visible:
			_brief_card.visible = false
		return
	brief_t = maxf(0.0, brief_t - delta)
	if _brief_card == null:
		return
	_brief_card.visible = true
	# 前 1s 淡入、最后 1.6s 淡出
	var a := clampf(minf((7.5 - brief_t) * 2.5, brief_t / 1.6), 0.0, 1.0)
	_brief_card.modulate.a = a


func _update_director(delta: float) -> void:
	_update_landmarks()
	_update_beats(delta)


func _update_landmarks() -> void:
	for l in landmarks:
		var nm := String(l.get("name", ""))
		if nm == "" or nm in landmark_seen:
			continue
		var p := _m_px(l.get("pos", [0.0, 0.0]))
		if dist_m(player.global_position, p) <= float(l.get("radius", 4.0)):
			landmark_seen.append(nm)
			sfx.play("beep", -9.0)
			add_shake(0.05)
			spawn_float(player.global_position + Vector2(0, -158), "勘踏 · " + nm, SovietUI.OCHRE)
			var note := String(l.get("note", ""))
			if note != "":
				spawn_float(player.global_position + Vector2(0, -136), note, SovietUI.BONE_DIM)


# ---------------------------------------------------------------------------
# 环境节拍
# ---------------------------------------------------------------------------
func _update_beats(delta: float) -> void:
	if beat_events.is_empty():
		return
	var ev: Dictionary = beat_events[beat_idx % beat_events.size()]
	var warn := float(ev.get("warn", 2.0))
	var live := float(ev.get("live", 2.0))
	if beat_phase == "":
		beat_timer -= delta
		if beat_timer <= 0.0:
			_begin_beat(ev)
		return
	beat_t += delta
	if beat_phase == "warn":
		if beat_t >= warn:
			_go_live_beat(ev)
	elif beat_phase == "live":
		_tick_beat(ev, delta)
		if beat_t >= warn + live:
			_end_beat(ev)


func _begin_beat(ev: Dictionary) -> void:
	beat_phase = "warn"
	beat_t = 0.0
	beat_shoved = false
	match String(ev.get("kind", "")):
		"hump":
			sfx.play("klaxon", -11.0)
			spawn_float(player.global_position + Vector2(0, -172), "驼峰溜放 —— 股道上来车皮了", SovietUI.SIGNAL)
		"flare":
			sfx.play("klaxon", -9.0)
			spawn_float(player.global_position + Vector2(0, -172), "炉膛要爆燃 —— 找影子", SovietUI.SIGNAL)


func _go_live_beat(ev: Dictionary) -> void:
	beat_phase = "live"
	match String(ev.get("kind", "")):
		"hump":
			_spawn_rake(ev)
			add_shake(0.12)
			sfx.play("crowbar_hit", -12.0)
		"flare":
			add_shake(0.1)
			sfx.play_at("gunshot", _furnace_px, -16.0)      # 一声闷响：炉膛吞了一口气


func _tick_beat(ev: Dictionary, delta: float) -> void:
	var warn := float(ev.get("warn", 2.0))
	var live := float(ev.get("live", 2.0))
	var k := clampf((beat_t - warn) / maxf(0.01, live), 0.0, 1.0)
	match String(ev.get("kind", "")):
		"hump":
			_tick_hump(ev, k, delta)
		"flare":
			_tick_flare(ev, k)


# --- 驼峰溜放 ----------------------------------------------------------------
func _spawn_rake(ev: Dictionary) -> void:
	var tex := load("res://art/30_props/PRP_Buran_Boxcar03.png") as Texture2D
	if tex == null:
		return
	beat_rake_lane = float(ev.get("lane_alt" if switch_thrown else "lane", 15.6))
	var spr := Sprite2D.new()
	spr.name = "HumpRake"
	spr.texture = tex
	spr.centered = false
	spr.light_mask = 2
	spr.offset = Vector2(-468, -410)                       # 与场景里那节闷罐车同一套定位
	spr.modulate = Color(0.34, 0.36, 0.42, 0.92)          # 夜色里的剪影
	spr.position = Vector2(float(ev.get("from", 43.0)) * PPM, beat_rake_lane * PPM * SQ)
	spr.z_index = 0
	$World.add_child(spr)
	# 挂在车皮上的一盏小灯：能看见它正在扫过来
	var lamp := PointLight2D.new()
	lamp.texture = TEX_GLOW
	lamp.color = Color(1.0, 0.86, 0.62)
	lamp.energy = 1.25
	lamp.texture_scale = 1.4
	lamp.light_mask = 3
	lamp.position = Vector2(300, -170)
	spr.add_child(lamp)
	beat_rake = spr


func _tick_hump(ev: Dictionary, k: float, delta: float) -> void:
	var from_x := float(ev.get("from", 43.0))
	var to_x := float(ev.get("to", 1.0))
	if beat_rake != null and is_instance_valid(beat_rake):
		var x := lerpf(from_x, to_x, k)
		beat_rake.position.x = x * PPM
		# 车皮每滑一段就轧一次道岔：轮轨声是真实的声音，会引来狂暴者
		_rake_rumble -= delta
		if _rake_rumble <= 0.0:
			_rake_rumble = 0.34
			sfx.play_at("step_rail", beat_rake.position, -11.0)
	if beat_shoved:
		return
	var lane := beat_rake_lane
	var pos_m := to_m(player.global_position)
	var rake_m := lerpf(from_x, to_x, k)
	if absf(pos_m.y - lane) <= 1.15 and absf(rake_m - pos_m.x) <= float(ev.get("shove", 2.2)):
		beat_shoved = true
		hp = maxf(0.0, hp - 9.0)
		warmth = maxf(0.0, warmth - 6.0)
		hurt = 0.45
		add_shake(0.7)
		punch = 1.0
		emit_noise(player.global_position, 12.0, "can")
		spawn_float(player.global_position + Vector2(0, -140), "被溜放的车皮刮倒了 —— 整个货场都听见了",
			Color("#f87171"))
		if hp <= 0.0:
			_check_downed()


# --- 炉口爆燃 ----------------------------------------------------------------
func _tick_flare(ev: Dictionary, k: float) -> void:
	var peak := sin(clampf(k * 1.25, 0.0, 1.0) * PI)
	beat_flare = maxf(0.0, minf(1.0, peak * 1.15))
	if beat_shoved:
		return
	var origin := _m_px(ev.get("pos", [34.0, 4.6]))
	if _furnace_px != Vector2.ZERO:
		origin = _furnace_px
	var radius := float(ev.get("radius", 22.0))
	if dist_m(player.global_position, origin) > radius:
		return
	# 蹲下 + 有遮挡（松树 / 车皮 / 钢管）= 影子够短，炉火照不到你
	var mask := 1 | (2 if player.crouching else 0)
	if player.crouching and not los_clear(origin, player.global_position, mask):
		return
	if not los_clear(origin, player.global_position, 1):
		return
	beat_shoved = true
	spawn_float(player.global_position + Vector2(0, -140), "炉口爆燃 —— 你的影子被钉在雪地上",
		Color("#fca5a5"))
	# 附近的清杀队会顺着这片亮压过来；狂暴者也会被惊动
	for s in soldiers:
		if dist_m(s.global_position, player.global_position) <= 34.0:
			s.alert_to(player.global_position)
	emit_noise(player.global_position, 10.0, "can", true)


func _end_beat(ev: Dictionary) -> void:
	beat_phase = ""
	beat_t = 0.0
	beat_idx += 1
	beat_timer = float(ev.get("period", 30.0))
	if beat_rake != null and is_instance_valid(beat_rake):
		beat_rake.queue_free()
		beat_rake = null
	beat_flare = 0.0


# ---------------------------------------------------------------------------
# 关卡机关（靠近按 E）
# ---------------------------------------------------------------------------
func nearest_mechanism() -> Dictionary:
	for m in beats.get("mechanisms", []):
		if String(m.get("kind", "")) == "forklift" and forklift_used:
			continue
		if String(m.get("kind", "")) == "wedge" and door_wedged:
			continue
		var node := get_node_or_null(String(m.get("node", ""))) as Node2D
		if node == null:
			continue
		if dist_m(player.global_position, node.global_position) <= float(m.get("radius", 2.4)):
			var out: Dictionary = m.duplicate()
			out["node2d"] = node
			return out
	return {}


func use_mechanism(m: Dictionary) -> void:
	match String(m.get("kind", "")):
		"switch":
			switch_thrown = not switch_thrown
			sfx.play_at("wedge", (m["node2d"] as Node2D).global_position, -3.0)
			emit_noise((m["node2d"] as Node2D).global_position, 7.0, "can")
			spawn_float(player.global_position + Vector2(0, -138),
				"%s 已扳向 %s 股" % [String(m.get("label", "转辙器")),
					"2" if switch_thrown else "1"], SovietUI.OCHRE)
			add_shake(0.08)
		"forklift":
			forklift_used = true
			var node := m["node2d"] as Node2D
			sfx.play_at("crowbar_hit", node.global_position, 0.0)
			sfx.play("klaxon", -8.0)
			emit_noise(node.global_position, 16.0, "can")
			add_shake(0.28)
			spawn_float(player.global_position + Vector2(0, -138),
				"叉车轰的一声窜出去 —— 16 米内的东西都朝那边去了", SovietUI.SIGNAL)
		"wedge":
			door_wedged = true
			var node := m["node2d"] as Node2D
			sfx.play_at("crowbar_hit", node.global_position, 0.0)
			sfx.play_at("wedge", node.global_position, -2.0)
			emit_noise(node.global_position, 12.0, "can")
			add_shake(0.22)
			spawn_float(player.global_position + Vector2(0, -138),
				"%s 被撬棍卡死了" % String(m.get("label", "铁门")), SovietUI.OCHRE)


# ============================================================================
# HUD
# ============================================================================
func _build_hud() -> void:
	# ---- 全屏金属框：暗角 / 角码 / 铆钉 / 扫描线 / 红星厂标 ----
	_chrome = SovietChrome.new()
	_chrome.name = "Chrome"
	_chrome.font = font
	_chrome.zone = String(beats.get("zone", "НОВОРСК-17 · ЖЕЛЕЗНАЯ ЗИМА"))
	_chrome.code = String(beats.get("code", ""))
	_chrome.accent = beats.get("accent", SovietUI.BLOOD)
	hud_root.add_child(_chrome)

	# ---- 左上：夜潜工作日志（档案牌） ----
	var left := PanelContainer.new()
	left.name = "Dossier"
	left.add_theme_stylebox_override("panel", SovietUI.plate(SovietUI.IRON, SovietUI.STEEL, 2, 18))
	left.position = Vector2(26, 22)
	left.custom_minimum_size = Vector2(572, 0)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(lv)

	# 红章条：档案号 + 天亮倒计时
	var stamp_row := PanelContainer.new()
	stamp_row.add_theme_stylebox_override("panel", SovietUI.stamp(7))
	stamp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lv.add_child(stamp_row)
	var sh := HBoxContainer.new()
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp_row.add_child(sh)
	var code_lbl := _mono_label(String(beats.get("code", "ДЕЛО № 17")), 11, SovietUI.BONE)
	code_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(code_lbl)
	_lbl_clock = _mono_label("", 11, SovietUI.BONE)
	sh.add_child(_lbl_clock)

	var title := _label(level_zh, 26, SovietUI.BONE)
	title.add_theme_font_override("font", SovietUI.display_font())
	lv.add_child(title)
	var sub := _mono_label("%s  ·  第 %s 夜" % [level_en.to_upper(), SovietUI.night_zh(day_n)],
		11, SovietUI.BONE_DIM)
	lv.add_child(sub)
	lv.add_child(SovietUI.rule(SovietUI.STEEL, 1))

	# 双星生命仪表：红色生命、钠灯黄体温；每半个星角代表 10%。
	var stars := HBoxContainer.new()
	stars.name = "StarVitals"
	stars.add_theme_constant_override("separation", 24)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lv.add_child(stars)
	var warm_row := _meter_row(stars, "体温", "ТЕПЛО", SovietUI.SIGNAL)
	_m_warm = warm_row[0]
	_lbl_warm_val = warm_row[1]
	var hp_row := _meter_row(stars, "生命", "ЗДОРОВЬЕ", SovietUI.BLOOD_LIT)
	_m_hp = hp_row[0]
	_lbl_hp_val = hp_row[1]

	lv.add_child(SovietUI.rule(SovietUI.STEEL, 1))
	_lbl_status = _mono_label("", 12, SovietUI.BONE)
	lv.add_child(_lbl_status)
	_lbl_zone = _mono_label("", 12, SovietUI.BONE_DIM)
	lv.add_child(_lbl_zone)
	_lbl_weapon = _mono_label("", 12, SovietUI.BONE)
	_lbl_weapon.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_weapon.custom_minimum_size = Vector2(520, 0)
	lv.add_child(_lbl_weapon)
	_lbl_bag = _label("", 12, SovietUI.OCHRE)
	_lbl_bag.custom_minimum_size = Vector2(520, 0)
	_lbl_bag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lv.add_child(_lbl_bag)

	# ---- 右上：任务卡（目标方位 / 撤离方位 / 威胁 / 勘踏） ----
	var right := PanelContainer.new()
	right.name = "Mission"
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.offset_left = -506
	right.offset_right = -26
	right.offset_top = 22
	right.offset_bottom = 22
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.grow_vertical = Control.GROW_DIRECTION_END
	right.add_theme_stylebox_override("panel", SovietUI.plate(SovietUI.IRON, SovietUI.STEEL, 2, 16))
	right.custom_minimum_size = Vector2(480, 0)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 5)
	rv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(rv)
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", SovietUI.stamp(6))
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rv.add_child(head)
	var head_lbl := _mono_label("ЦЕЛЬ · 今夜任务", 11, SovietUI.BONE)
	head.add_child(head_lbl)
	_lbl_target = _label(objective_zh, 13, SovietUI.BONE)
	_lbl_target.custom_minimum_size = Vector2(430, 0)
	rv.add_child(_lbl_target)
	_lbl_bearing = _mono_label("", 13, SovietUI.OCHRE)
	rv.add_child(_lbl_bearing)
	_lbl_exit = _mono_label("", 13, SovietUI.CRT)
	rv.add_child(_lbl_exit)
	rv.add_child(SovietUI.rule(SovietUI.STEEL, 1))
	_lbl_threat = _mono_label("", 12, SovietUI.SIGNAL)
	rv.add_child(_lbl_threat)
	_lbl_landmarks = _mono_label("", 11, SovietUI.ASH)
	rv.add_child(_lbl_landmarks)

	# ---- 底部：电传打字机（长按 E 的提示都从这里打出来） ----
	var bar := PanelContainer.new()
	bar.name = "Teletype"
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 26
	bar.offset_right = -26
	bar.offset_top = -84
	bar.offset_bottom = -26
	bar.add_theme_stylebox_override("panel",
		SovietUI.plate(Color(0.035, 0.04, 0.042, 0.94), SovietUI.STEEL, 1, 10))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(bar)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 12)
	bh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(bh)
	var tt := PanelContainer.new()
	tt.add_theme_stylebox_override("panel", SovietUI.plate(Color("0d1a12"), SovietUI.CRT, 1, 6))
	tt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bh.add_child(tt)
	var tt_lbl := _mono_label("ТЕЛЕТАЙП", 10, SovietUI.CRT)
	tt.add_child(tt_lbl)
	_lbl_hint = _label("", 14, SovietUI.BONE)
	_lbl_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bh.add_child(_lbl_hint)
	var tail := _mono_label("№ 0420", 10, SovietUI.BONE_DIM)
	bh.add_child(tail)

	# ---- 清杀队短对白：右下角头像，不暂停战斗、不挡住底部操作提示 ----
	_osk_bark_panel = PanelContainer.new()
	_osk_bark_panel.name = "OSKBark"
	_osk_bark_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_osk_bark_panel.offset_left = -610
	_osk_bark_panel.offset_right = -26
	_osk_bark_panel.offset_top = -288
	_osk_bark_panel.offset_bottom = -102
	_osk_bark_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_osk_bark_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_osk_bark_panel.add_theme_stylebox_override("panel",
		SovietUI.plate(Color(0.035, 0.04, 0.042, 0.96), SovietUI.BLOOD_LIT, 2, 12))
	_osk_bark_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_osk_bark_panel.visible = false
	hud_root.add_child(_osk_bark_panel)
	var oh := HBoxContainer.new()
	oh.add_theme_constant_override("separation", 14)
	oh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_osk_bark_panel.add_child(oh)
	_osk_bark_portrait = TextureRect.new()
	_osk_bark_portrait.custom_minimum_size = Vector2(132, 132)
	_osk_bark_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_osk_bark_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_osk_bark_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oh.add_child(_osk_bark_portrait)
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 8)
	ov.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ov.alignment = BoxContainer.ALIGNMENT_CENTER
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oh.add_child(ov)
	_osk_bark_speaker = _mono_label("ОСК · 清杀队", 12, SovietUI.BLOOD_LIT)
	ov.add_child(_osk_bark_speaker)
	_osk_bark_label = _label("", 17, SovietUI.BONE)
	_osk_bark_label.custom_minimum_size = Vector2(398, 0)
	_osk_bark_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_osk_bark_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(_osk_bark_label)

	# ---- 开场档案卡（七秒后自己淡掉） ----
	_brief_card = PanelContainer.new()
	_brief_card.name = "Brief"
	_brief_card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_brief_card.offset_left = -360
	_brief_card.offset_right = 360
	_brief_card.offset_top = 300
	_brief_card.offset_bottom = 300
	_brief_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_brief_card.grow_vertical = Control.GROW_DIRECTION_END
	_brief_card.add_theme_stylebox_override("panel",
		SovietUI.plate(Color(0.04, 0.042, 0.045, 0.96), beats.get("accent", SovietUI.BLOOD), 2, 20))
	_brief_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(_brief_card)
	_brief_lbl = _label("", 14, SovietUI.BONE)
	_brief_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_brief_card.add_child(_brief_lbl)

	# ---- 中央读数（结局 / 被发现 / 天亮） ----
	_lbl_center = _label("", 30, SovietUI.BONE)
	_lbl_center.add_theme_font_override("font", SovietUI.display_font())
	_lbl_center.set_anchors_preset(Control.PRESET_CENTER)
	_lbl_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_center.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_center.offset_left = -700
	_lbl_center.offset_right = 700
	_lbl_center.offset_top = -170
	_lbl_center.offset_bottom = 170
	_lbl_center.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	_lbl_center.add_theme_constant_override("outline_size", 9)
	hud_root.add_child(_lbl_center)

	# ---- 道德抉择：一张没人愿意填的问询单 ----
	_choice_panel = PanelContainer.new()
	_choice_panel.add_theme_stylebox_override("panel",
		SovietUI.plate(Color(0.045, 0.04, 0.035, 0.97), SovietUI.OCHRE_DIM, 2, 22))
	_choice_panel.set_anchors_preset(Control.PRESET_CENTER)
	_choice_panel.offset_left = -440
	_choice_panel.offset_right = 440
	_choice_panel.offset_top = -190
	_choice_panel.offset_bottom = 190
	_choice_panel.visible = false
	hud_root.add_child(_choice_panel)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 10)
	_choice_panel.add_child(cv)
	var ch := PanelContainer.new()
	ch.add_theme_stylebox_override("panel", SovietUI.stamp(6))
	cv.add_child(ch)
	_choice_head = _mono_label("ОПРОСНЫЙ ЛИСТ · 问询单", 11, SovietUI.BONE)
	ch.add_child(_choice_head)
	_choice_lbl = _label("", 17, SovietUI.BONE)
	_choice_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(_choice_lbl)

	_update_brief_text()
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
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _mono_label(txt: String, size: int, col: Color) -> Label:
	var l := _label(txt, size, col)
	l.add_theme_font_override("font", SovietUI.mono_font())
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


## 一枚十格五角星仪表：返回 [仪表, 数值 Label]（体温 / 健康共用一套）
func _meter_row(parent: Node, zh: String, ru: String, col: Color) -> Array:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.custom_minimum_size = Vector2(226, 0)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(head)
	var nm := _label("%s  %s" % [zh, ru], 12, SovietUI.BONE_DIM)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	var val := _mono_label("100%", 12, col)
	head.add_child(val)
	var m = SovietStarMeter.new()
	m.name = "StarMeter_" + zh
	m.fill = col
	m.fill_low = SovietUI.FROST if zh == "体温" else Color("e04432")
	m.track = SovietUI.INK
	m.edge = SovietUI.OCHRE_DIM if zh == "体温" else SovietUI.STEEL_LIT
	m.custom_minimum_size = Vector2(104, 94)
	m.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(m)
	return [m, val]


## 开场档案卡：这是什么地方 / 危险度 / 夜长 / 从哪儿出去
func _update_brief_text() -> void:
	if _brief_lbl == null:
		return
	var lines: Array[String] = []
	lines.append(String(beats.get("stamp", "СССР")) + "　·　" + String(beats.get("zone", "")))
	lines.append("")
	for b in beats.get("brief", []):
		lines.append(String(b))
	lines.append("")
	lines.append("危险度 %s　·　夜长 %s　·　撤离：%s" % [
		SovietUI.danger_pips(int(beats.get("danger", 3))),
		SovietUI.clock(night_max) if in_campaign else "无限制（F2 独立跑）",
		extract_zh])
	_brief_lbl.text = "\n".join(lines)


## 核心体温在仪表上的颜色：正常是钠灯的琥珀，失温转霜蓝
func _warm_color() -> Color:
	if warmth <= 20.0:
		return SovietUI.FROST
	if warmth <= 35.0:
		return SovietUI.SIGNAL
	return SovietUI.OCHRE


func _nearest_unvisited_landmark() -> Dictionary:
	var best: Dictionary = {}
	var bd := 1e9
	for l in landmarks:
		if String(l.get("name", "")) in landmark_seen:
			continue
		var p := _m_px(l.get("pos", [0.0, 0.0]))
		var d := dist_m(player.global_position, p)
		if d < bd:
			bd = d
			best = l
	return best


func _refresh_hud() -> void:
	if _m_warm == null:
		return
	_m_warm.set_value(warmth / 100.0)
	_m_hp.set_value(hp / 100.0)
	_m_warm.fill = _warm_color()
	_lbl_warm_val.text = SovietUI.pct(warmth / 100.0)
	_lbl_hp_val.text = SovietUI.pct(hp / 100.0)
	_lbl_warm_val.add_theme_color_override("font_color", _warm_color())
	_lbl_hp_val.add_theme_color_override("font_color",
		SovietUI.BLOOD_LIT if hp <= 35.0 else SovietUI.BONE_DIM)

	# --- 时钟（战役里是离天亮还有多久；F2 独立跑是自由行动） ---
	if in_campaign:
		_lbl_clock.text = ("天亮 %s" if dawn_t <= 0.0 else "发白 %s") % SovietUI.clock(night_left)
		_lbl_clock.add_theme_color_override("font_color",
			SovietUI.SIGNAL if dawn_t > 0.0 else SovietUI.BONE)
	else:
		_lbl_clock.text = "СВОБОДНЫЙ РЕЙД"
		_lbl_clock.add_theme_color_override("font_color", SovietUI.BONE_DIM)

	# --- 姿态 / 读数一行 ---
	var stance := "蹲伏" if player.crouching else ("冲刺" if player.sprinting else "步行")
	var light := "手电开" if player.flashlight_on else "手电关"
	var lit := "暴露" if player.flashlight_on or is_lit(player.global_position) else "暗处"
	_lbl_status.text = "%s │ %s %s │ 罐头 %d │ 借刀 %d │ 良知 %+d │ 卌 %s" % [
		stance, light, lit, cans, borrowed, int(conscience), SovietUI.tally_glyphs(tally)]

	# --- 当前所在区（白 / 红 / 黑）---
	if _lbl_zone != null:
		if zone_id == "":
			_lbl_zone.text = ""
		else:
			var inf := Zones.info(zone_id)
			var line := String(inf.get("zh", zone_id))
			if zone_id == "red":
				line += "  ·  禁止进入（白区户口）"
			elif zone_id == "black":
				line += "  ·  尸群无上限"
			_lbl_zone.text = "所在区  " + line
			_lbl_zone.add_theme_color_override("font_color", inf.get("hud_col", SovietUI.BONE_DIM))

	# --- 手里的家伙 ---
	var wspec := cur_w()
	var slots: Array[String] = []
	for sl in weapon_slots():
		if bool(sl["owned"]):
			var tag := "%d·%s" % [int(sl["slot"]), String(sl["label"])]
			slots.append("[%s]" % tag if String(sl["id"]) == weapon else tag)
	var wline := Arsenal.label(weapon, int(mag.get(weapon, 0)), int(reserve.get(weapon, 0)))
	if reload_left > 0.0:
		wline += "  装填中…"
	elif cur_is_gun() and int(mag.get(weapon, 0)) == 0:
		wline += "  空仓 · R 装填"
	_lbl_weapon.text = "%s\n%s" % [wline, "　".join(slots)]
	_lbl_weapon.add_theme_color_override("font_color",
		SovietUI.SIGNAL if cur_is_gun() and int(mag.get(weapon, 0)) == 0 else SovietUI.BONE)

	var names: Array[String] = []
	for id in pack:
		names.append(item_name(id))
	_lbl_bag.text = "背包 %d/%d：%s" % [pack.size(), bag_max,
		"、".join(names) if not names.is_empty() else "—"]

	# --- 右上：目标方位 / 撤离方位 / 威胁 / 勘踏 ---
	var has_prize := pack.has(prize)
	if has_prize:
		_lbl_target.text = "%s 已经在背包里 —— 回撤离点。" % item_name(prize)
		_lbl_bearing.text = "目标方位  已完成"
		_lbl_bearing.add_theme_color_override("font_color", SovietUI.ASH)
	else:
		_lbl_target.text = objective_zh
		_lbl_bearing.text = "目标方位  " + SovietUI.bearing_line(to_m(objective_px - player.global_position))
		_lbl_bearing.add_theme_color_override("font_color", SovietUI.OCHRE)
	_lbl_exit.text = "撤离方位  " + SovietUI.bearing_line(to_m(exit_px - player.global_position))

	var chasing := 0
	for r in rabids:
		if r.state in ["chase", "windup", "lunge"]:
			chasing += 1
	var threats: Array[String] = []
	if chasing > 0:
		threats.append("被 %d 只狂暴者盯上" % chasing)
	var near_s = null
	var near_d := 1e9
	for s in soldiers:
		if not s.is_alive():
			continue
		var d := dist_m(player.global_position, s.global_position)
		if d < near_d:
			near_d = d
			near_s = s
	if near_s != null and near_d <= 26.0:
		var head := "最近清杀兵 %dm %s" % [int(round(near_d)),
			SovietUI.bearing_zh(to_m(near_s.global_position - player.global_position))]
		if near_s.state == "alert":
			head = "清杀兵锁定！ " + head
		threats.append(head)
	if player.on_slush:
		threats.append("脚下冻雪泥（噪声 ×2）")
	if beat_phase == "warn":
		threats.append("环境警报：" + ("溜放车皮" if String(beat_events[beat_idx % beat_events.size()].get("kind", "")) == "hump" else "炉口爆燃"))
	elif beat_phase == "live":
		threats.append("环境警报：正在进行")
	_lbl_threat.text = "\n".join(threats) if not threats.is_empty() else "没有异常动静。雪在响。"
	_lbl_threat.add_theme_color_override("font_color",
		SovietUI.BLOOD_LIT if (chasing > 0 or (near_s != null and near_s.state == "alert")) else SovietUI.SIGNAL)

	var lmk := "勘踏 %d/%d" % [landmark_seen.size(), landmarks.size()]
	var nxt := _nearest_unvisited_landmark()
	if not nxt.is_empty():
		lmk += "　·　未勘：%s %s" % [String(nxt.get("name", "")),
			SovietUI.bearing_line(to_m(_m_px(nxt.get("pos", [0.0, 0.0])) - player.global_position))]
	if not beat_events.is_empty() and beat_phase == "":
		lmk += "　·　下次节拍 %ds" % int(ceil(maxf(0.0, beat_timer)))
	_lbl_landmarks.text = lmk

	# --- 底栏：电传提示 ---
	var mech := nearest_mechanism()
	var near_half = nearest_half()
	if dawn_t > 0.0:
		_lbl_hint.text = "天要亮了 —— %s（长按 E）" % extract_zh
	elif has_prize:
		_lbl_hint.text = "%s到手 —— %s（长按 E）" % [item_name(prize), extract_zh] \
			+ ("　·　F5 重来　Esc 返回战役" if not in_campaign else "")
	elif not mech.is_empty():
		_lbl_hint.text = "E · " + String(mech.get("prompt", ""))
	elif near_half != null:
		_lbl_hint.text = "E · 半人 %s 在发烧 —— 喂药 / 绕开 / 灭口" % near_half.tag
	elif dist_m(player.global_position, exit_px) <= REACH:
		_lbl_hint.text = "长按 E · " + extract_zh
	else:
		_lbl_hint.text = objective_zh + "　·　左键 攻击　R 装填　1~4 换家伙　Ctrl 蹲　E 搜刮　F 手电　Esc 暂停"

	# --- 屏幕边框：警报时边缘渗红 ---
	if _chrome != null:
		var d := clampf(maxf(tension_level(), beat_flare), 0.0, 1.0)
		if state in ["caught", "downed"]:
			d = 1.0
		_chrome.set_danger(d)

	# --- 中央读数 ---
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
			_lbl_center.add_theme_color_override("font_color", SovietUI.SIGNAL)
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
			var moral := "良知 %+d · 救下半人 %d · 误杀 %d · 卌 %s" % [int(conscience), half_saved, half_lost,
				SovietUI.tally_glyphs(tally)]
			var lmk_line := "勘踏 %d/%d · 借刀 ×%d" % [landmark_seen.size(), landmarks.size(), borrowed]
			_lbl_center.text = "撤离成功 · %d 件物资\n%s\n%s\n%s\n%s\n\n%s" % [
				pack.size(), "、".join(names2), line, moral, lmk_line,
				"R / Enter 再来一夜　Esc 返回战役" if not in_campaign else "Enter 回 602 室 · 结算"]
			_lbl_center.add_theme_color_override("font_color", Color("#bbf7d0"))
