extends RefCounted
## GymSim.gd — 《Z年纪事：凛冬铁轨》5 合 1 灰盒测试场 · 纯逻辑层（RefCounted）
##
## 1:1 对应 prototypes/Year_of_Z_Iron_Winter_Playable_Greybox_Gym.html 的 1100×680 逻辑竞技场：
##   Room A 探照灯「借刀杀人」+ 冻雪泥 + 高架蒸汽管
##   Room B 道钉撬棍卡门 15s + 12cm 门底推铝饭盒
##   Room C 电传「账面 0 人」+ 回退期半人【抉择 A】+《卌》字划痕
##   Room D 灰狼犬「灰烬」三态嗅觉 AI + 安娜 0419 证言
##   Room E 东街食堂砍骨刀 + 瓦西里锁骨卡刀 6 连按 QTE + PTSD 干渴耳鸣
##
## 与 HTML 一致：实体是普通数据对象（无 Node），逻辑按 60fps 帧参数书写，
## 这里用 f = dt*60 归一化，因此逐帧常量（2.6 px/帧 等）与原型完全相同。
## 渲染层 Gym.gd 只读取数据并在 _draw() 中立即模式绘制；HUD 读取同一份数据。
## 世界坐标单位 = 原型像素（1100×680，原点左上，x 东 y 南）。

const WORLD_W := 1100.0
const WORLD_H := 680.0
const PLAYER_R := 13.0

# 玩家速度（px / 帧 @60fps）
const SPEED_WALK := 2.6
const SPEED_CROUCH := 1.4
const SPEED_SPRINT := 4.3
const SLUSH_FACTOR := 0.65

# Room A 环境
const SLUSH_RECT := Rect2(65, 210, 155, 90)
const STEAM_PIPE_RECT := Rect2(155, 105, 140, 24)
const PIPE_SHADOW_PAD := Vector4(18, 28, 18, 38)   # 左 / 上 / 右 / 下 的隐匿判定外扩

# Room 区域（与 HTML ROOM_ZONES 完全一致）
const ROOM_ZONES := [
	{"id": "A", "rect": Rect2(20, 20, 420, 310),
		"zh": "ROOM A · 探照灯借刀与冻雪泥", "en": "ROOM A · Searchlight & Slush"},
	{"id": "B", "rect": Rect2(455, 20, 300, 310),
		"zh": "ROOM B · 撬棍卡门与门底推饭盒", "en": "ROOM B · Door Wedge & Fence Gap"},
	{"id": "C", "rect": Rect2(770, 20, 310, 310),
		"zh": "ROOM C · 账面0人与回退半人(卌)", "en": "ROOM C · Paper Dead & Choice A"},
	{"id": "D", "rect": Rect2(20, 350, 520, 310),
		"zh": "ROOM D · 灰狼犬「灰烬」三态嗅觉测试", "en": "ROOM D · Wolfdog 'Ash' Tri-State AI"},
	{"id": "E", "rect": Rect2(555, 350, 525, 310),
		"zh": "ROOM E · 东街食堂后厨(锁骨卡刀QTE)", "en": "ROOM E · East St. Kitchen (Blade Jam)"},
]

const ROOM_SPAWNS := {
	"A": Vector2(85, 145),
	"B": Vector2(525, 205),
	"C": Vector2(845, 185),
	"D": Vector2(115, 555),
	"E": Vector2(635, 500),
}

# 房间简报（与 HTML I18N rooms 一致）
const ROOM_BRIEF := {
	"A": {
		"zh": "按 [Ctrl] 蹲在高架蒸汽管旁可 100% 躲避内务清杀兵（ОСК）的 45° 探照灯。把鼠标指向游荡的灰鳞狂暴者并按 [G] 投掷空沙丁鱼罐头，清杀兵会立刻转向声源开火替你清场！",
		"en": "Hold [Ctrl] beside the overhead steam pipe for 100% concealment from the O.S.K. soldier's 45° searchlight. Aim at a roaming Rabid and press [G] to throw an empty sardine tin—the soldier will pivot and eliminate it for you!",
	},
	"B": {
		"zh": "靠近上方变形铁门按 [E] 可将撬棍插进导轨锁死门体 15 秒；靠近右侧带 12cm 底缝的铁丝网门按 [E]，用撬棍弯头把温热的黑麦铝饭盒推给里面快饿晕的装卸工。",
		"en": "Press [E] near the deformed steel door to jam your crowbar into the track for 15s; press [E] near the wire-mesh fence (12cm bottom gap) to push the warm buckwheat lunchbox through to the starving loader.",
	},
	"C": {
		"zh": "左侧电传终端报错【当前坐标0人】，按 [E] 在工作日志背面写下谢尔盖母子真名；右侧涵洞里蜷缩着手背灰鳞剥落的回退期半人，靠近按 [E] 触发【抉择 A（喂药 vs 撬棍灭口记划痕）】。",
		"en": "The teletype reads [0 PERSONS AT COORDINATE]—press [E] to write Sergey & Maria's real names in your Logbook. The Regressing Half-Human trembles in the culvert; press [E] for Choice A (Aspirin vs. Crowbar).",
	},
	"D": {
		"zh": "带着「灰烬」依次靠近三座苏式铁笼，观察狼犬对【Ⅰ狂暴者（狂吠）】、【Ⅱ皮带自缚的安娜0419（低鸣）】、【Ⅲ绑红塑料袋送胰岛素的父亲（摇尾）】的 100% 准确辨识，并在Ⅱ号笼按 [E] 听安娜说出妹妹的下落。",
		"en": "Walk past the 3 cages with Ash: [I Rabid → Bark], [II Self-bound Anna 0419 → Whimper], [III Father with insulin → Tail Wag]. Press [E] at Cage II to hear where Lana is.",
	},
	"E": {
		"zh": "先靠近备餐台按 [E] 拾取【东街宽背砍骨刀】，随后靠近右侧杂物间触发瓦西里破门扑击！按 [Space] 挥刀将 100% 触发【锁骨卡刀 6 连按 QTE】，听他在瞳孔回色时喊出“……Пить（渴）……”，并解锁按 [Q] 喝水的 PTSD 幻听。",
		"en": "Press [E] at the butcher block for the [East St. Cleaver], then approach the pantry: Vasily bursts out in 40°C delirium! Press [Space] to strike—triggering the 6-hit Collarbone Blade Jam QTE, his eyes clearing as he whispers '…Пить (Thirsty)…', unlocking PTSD when you drink [Q].",
	},
}

# 5 项灰盒验证任务
const TASKS := [
	{"id": "A", "zh": "Room A：投掷空罐头[G]诱使清杀兵射杀狂暴者（借刀）",
		"en": "Room A: Throw Tin Can [G] so O.S.K. shoots the Rabid Infected"},
	{"id": "B", "zh": "Room B：用道钉撬棍卡死变形门[E] & 门底推铝饭盒",
		"en": "Room B: Wedge Steel Door [E] & Push Lunchbox Under Fence"},
	{"id": "C", "zh": "Room C：记录谢尔盖母子真名 & 抉择A处置回退半人",
		"en": "Room C: Record Sergey's Real Name & Resolve Choice A"},
	{"id": "D", "zh": "Room D：带灰狼犬「灰烬」嗅探三座铁笼并对话安娜(0419)",
		"en": "Room D: Test Ash at 3 Cages & Speak to Anna (0419)"},
	{"id": "E", "zh": "Room E：拾取砍骨刀触发瓦西里【锁骨卡刀QTE】与渴耳鸣",
		"en": "Room E: Equip Cleaver, Trigger Vasily Collarbone Jam QTE & PTSD"},
]

# ============================================================================
# 数据实体
# ============================================================================
class Player extends RefCounted:
	var x: float = 85.0
	var y: float = 145.0
	var angle: float = 0.0
	var hp: float = 100.0
	var bpm: float = 76.0
	var crouching := false
	var sprinting := false
	var in_pipe_shadow := false
	var in_slush := false
	var cans := 5
	var weapon := "crowbar"      # "crowbar" | "cleaver"
	var swing_frames: float = 0.0

class Dog extends RefCounted:
	var x: float = 60.0
	var y: float = 155.0
	var state := "follow"        # follow | bark | whimper | wag

class Soldier extends RefCounted:
	var x: float = 245.0
	var y: float = 65.0
	var patrol_min_x: float = 165.0
	var patrol_max_x: float = 380.0
	var dir: int = 1
	var angle: float = PI / 2.0
	var target_angle: float = PI / 2.0
	var alert_frames: float = 0.0
	var fire_cd: float = 0.0

class Rabid extends RefCounted:
	var id := ""
	var x: float = 0.0
	var y: float = 0.0
	var hp: float = 100.0
	var alive := true
	var phase: float = 0.0

class DoorB extends RefCounted:
	var x: float = 545.0
	var y: float = 115.0
	var w: float = 85.0
	var h: float = 14.0
	var wedge_frames: float = 0.0
	var ever_wedged := false

class FenceBox extends RefCounted:
	var x: float = 655.0
	var y: float = 235.0
	var delivered := false

class TerminalC extends RefCounted:
	var x: float = 845.0
	var y: float = 105.0
	var recorded := false

class HalfHuman extends RefCounted:
	var x: float = 985.0
	var y: float = 235.0
	var status := "unresolved"   # unresolved | saved_A1 | killed_A3

class CageD extends RefCounted:
	var id := ""
	var kind := "rabid"          # rabid | anna | father
	var x: float = 0.0
	var y: float = 0.0
	var inspected := false

class Cleaver extends RefCounted:
	var x: float = 650.0
	var y: float = 560.0
	var taken := false

class Vasily extends RefCounted:
	var x: float = 960.0
	var y: float = 495.0
	var state := "locked"        # locked | charging | jammed | resolved
	var last_words_frames: float = 0.0

class Ripple extends RefCounted:
	var x: float = 0.0
	var y: float = 0.0
	var r: float = 4.0
	var max_r: float = 48.0
	var color := "#94a3b8"
	var zh := ""
	var en := ""

class Bootprint extends RefCounted:
	var x: float = 0.0
	var y: float = 0.0
	var life: float = 240.0

class Tracer extends RefCounted:
	var sx: float = 0.0
	var sy: float = 0.0
	var tx: float = 0.0
	var ty: float = 0.0
	var life: float = 10.0

class FloatText extends RefCounted:
	var x: float = 0.0
	var y: float = 0.0
	var zh := ""
	var en := ""
	var color := "#fde047"
	var life: float = 95.0

class ThrownCan extends RefCounted:
	var x: float = 0.0
	var y: float = 0.0
	var tx: float = 0.0
	var ty: float = 0.0
	var progress: float = 0.0

# ============================================================================
# 运行时状态
# ============================================================================
var player: Player = Player.new()
var dog: Dog = Dog.new()
var soldier: Soldier = Soldier.new()
var rabids: Array[Rabid] = []

var door_b: DoorB = DoorB.new()
var fence_box: FenceBox = FenceBox.new()
var terminal: TerminalC = TerminalC.new()
var half_human: HalfHuman = HalfHuman.new()
var cages: Array[CageD] = []
var cleaver: Cleaver = Cleaver.new()
var vasily: Vasily = Vasily.new()

var ripples: Array[Ripple] = []
var bootprints: Array[Bootprint] = []
var bullets: Array[Tracer] = []
var floats: Array[FloatText] = []
var thrown_cans: Array[ThrownCan] = []

var feed: Array[Dictionary] = []

var mouse: Vector2 = Vector2(250, 185)
var tick: int = 0
var time: float = 0.0

# 姿态 / 世界反馈
var foot_acc: float = 0.0
var ambient_acc: float = 0.0
var footstep_hold: float = 0.0
var shots_fired: int = 0

# QTE / 叙事状态
var qte_active := false
var qte_count := 0
var qte_needed := 6
var tally_strokes := 0
var ptsd_unlocked := false
var ptsd_flash: float = 0.0
var glasses_cracked := false
var logbook_open := false
var choice_modal_open := false
var muted := false
var lang := "zh"

# 音效事件队列：Gym.gd 每帧 drain 后播放对应程序化音效（对应 HTML playSfx 调用点）
var sfx_events: Array[String] = []

var tasks_done: Dictionary = {"A": false, "B": false, "C": false, "D": false, "E": false}
var verified_names: Array[Dictionary] = []
var completion_announced := false

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# ============================================================================
# 初始化 / 重置
# ============================================================================
func _init() -> void:
	rng.seed = 20261022
	reset()

func reset() -> void:
	var lb := _logbook()
	if lb != null and lb.has_method("reset_logbook"):
		lb.call("reset_logbook")
	tick = 0
	time = 0.0
	foot_acc = 0.0
	ambient_acc = 0.0
	shots_fired = 0
	qte_active = false
	qte_count = 0
	tally_strokes = 0
	ptsd_unlocked = false
	ptsd_flash = 0.0
	choice_modal_open = false
	logbook_open = false
	completion_announced = false
	mouse = Vector2(250, 185)

	player = Player.new()
	dog = Dog.new()
	player.x = ROOM_SPAWNS["A"].x
	player.y = ROOM_SPAWNS["A"].y
	dog.x = 60.0
	dog.y = 155.0

	soldier = Soldier.new()
	rabids = []
	var r1 := Rabid.new()
	r1.id = "rab1"
	r1.x = 355.0
	r1.y = 225.0
	r1.phase = 0.0
	rabids.append(r1)
	var r2 := Rabid.new()
	r2.id = "rab2"
	r2.x = 395.0
	r2.y = 265.0
	r2.phase = 2.0
	rabids.append(r2)

	door_b = DoorB.new()
	fence_box = FenceBox.new()
	terminal = TerminalC.new()
	half_human = HalfHuman.new()

	cages = []
	var c1 := CageD.new()
	c1.id = "cage1"
	c1.kind = "rabid"
	c1.x = 115.0
	c1.y = 445.0
	cages.append(c1)
	var c2 := CageD.new()
	c2.id = "cage2"
	c2.kind = "anna"
	c2.x = 275.0
	c2.y = 445.0
	cages.append(c2)
	var c3 := CageD.new()
	c3.id = "cage3"
	c3.kind = "father"
	c3.x = 435.0
	c3.y = 445.0
	cages.append(c3)

	cleaver = Cleaver.new()
	vasily = Vasily.new()

	ripples = []
	bootprints = []
	bullets = []
	floats = []
	thrown_cans = []
	feed = []
	sfx_events = []

	tasks_done = {"A": false, "B": false, "C": false, "D": false, "E": false}
	verified_names = [
		{
			"id": "katya_602",
			"zh": "卡佳妈妈 (第3居住区602室 · 尿毒症腹透锚点)",
			"en": "Mama Katya (District 3 Apt 602 · Peritoneal Dialysis Anchor)",
		}
	]

	add_feed(
		"【系统初始化】欢迎进入诺沃斯克-17（Новорск-17）5合1灰盒测试场。你可以自由走动，或按 1~5 快速传送到 Room A~E。",
		"[SYSTEM INIT] Welcome to the Novorsk-17 5-in-1 Greybox Gym. Walk freely, or press 1–5 to teleport to Room A–E.",
		"text-slate-300"
	)

# ============================================================================
# 小工具
# ============================================================================
func tr2(zh: String, en: String) -> String:
	return zh if lang == "zh" else en

func dist(ax: float, ay: float, bx: float, by: float) -> float:
	var dx := ax - bx
	var dy := ay - by
	return sqrt(dx * dx + dy * dy)

func player_dist(x: float, y: float) -> float:
	return dist(player.x, player.y, x, y)

func _sfx(name: String) -> void:
	sfx_events.append(name)

func drain_sfx() -> Array[String]:
	var out: Array[String] = []
	for e in sfx_events:
		out.append(e)
	sfx_events.clear()
	return out

func add_feed(zh: String, en: String, color: String = "text-slate-300") -> void:
	feed.push_front({
		"zh": zh,
		"en": en,
		"color": color,
		"time": Time.get_time_string_from_system(),
	})
	if feed.size() > 40:
		feed.resize(40)

func spawn_ripple(x: float, y: float, max_r: float, color: String, zh: String = "", en: String = "") -> void:
	var rp := Ripple.new()
	rp.x = x
	rp.y = y
	rp.r = 4.0
	rp.max_r = max_r
	rp.color = color
	rp.zh = zh
	rp.en = en
	ripples.append(rp)

func spawn_float(x: float, y: float, zh: String, en: String, color: String = "#fde047") -> void:
	var ft := FloatText.new()
	ft.x = x
	ft.y = y
	ft.zh = zh
	ft.en = en
	ft.color = color
	ft.life = 95.0
	floats.append(ft)

func set_task(task_id: String, done: bool = true) -> void:
	if not tasks_done.has(task_id):
		return
	if tasks_done[task_id] == done:
		return
	tasks_done[task_id] = done
	if done:
		var done_count := tasks_done_count()
		if done_count >= 5 and not completion_announced:
			completion_announced = true
			add_feed(
				"【5/5 灰盒验证全部通过】A~E 五个核心机制闭环已完成。可以按 F1 进入 Room A 夜潜垂直切片继续测试。",
				"[5/5 GREYBOX VERIFIED] All five core mechanic loops are closed. Press F1 to enter the Room A night-stalk vertical slice.",
				"text-emerald-300"
			)
		else:
			add_feed(
				"【验证清单 %d/5】Room %s 机制已通过。" % [done_count, task_id],
				"[CHECKLIST %d/5] Room %s mechanic verified." % [done_count, task_id],
				"text-emerald-300"
			)

func tasks_done_count() -> int:
	var n := 0
	for k in tasks_done.keys():
		if tasks_done[k]:
			n += 1
	return n

func current_room() -> Dictionary:
	for rm in ROOM_ZONES:
		var r: Rect2 = rm["rect"]
		if player.x >= r.position.x and player.x <= r.position.x + r.size.x \
				and player.y >= r.position.y and player.y <= r.position.y + r.size.y:
			return rm
	return ROOM_ZONES[0]

func stance_key() -> String:
	if player.in_pipe_shadow:
		return "stealth"
	if player.in_slush:
		return "slush"
	if player.sprinting:
		return "sprint"
	if player.crouching:
		return "crouch"
	return "walk"

func stance_text() -> String:
	match stance_key():
		"stealth":
			return tr2("STEALTH（蒸汽管阴影隐匿）", "STEALTH (Pipe Shadow Hidden)")
		"slush":
			return tr2("SLUSH（涉雪泥减速）", "SLUSH (-35% Speed)")
		"sprint":
			return tr2("SPRINT（恐慌冲刺）", "SPRINT (Loud Ripple)")
		"crouch":
			return tr2("CROUCH（蹲伏潜行）", "CROUCH (Sneaking)")
		_:
			return tr2("WALK（正常步行）", "WALK (Normal)")

func dog_state_text() -> String:
	match dog.state:
		"bark":
			return tr2("🔥 炸毛狂吠（发现狂暴者!）", "🔥 BRISTLING BARK (Rabid Ahead!)")
		"whimper":
			return tr2("💧 压耳低鸣（回退期活人!）", "💧 LOW WHIMPER (Regressing Human!)")
		"wag":
			return tr2("🐾 摇尾碰靴（安全/求救家属）", "🐾 WAGGING TAIL (Safe Civilian)")
		_:
			return tr2("🐾 巡航跟随", "🐾 Trailing")

func weapon_text() -> String:
	if player.weapon == "cleaver":
		return tr2("东街生锈砍骨刀 (Секач)", "East St. Butcher Cleaver (Секач)")
	return tr2("铸铁道钉撬棍 (Лом)", "Railway Crowbar (Лом)")

func vision_radius() -> float:
	return 165.0 if glasses_cracked else 275.0

func wedge_seconds() -> float:
	return door_b.wedge_frames / 60.0

func tally_stroke_marks() -> int:
	return clampi(tally_strokes, 0, 5)

# ============================================================================
# LogbookManager 同步（跨场景持久化；无 autoload 时静默跳过）
# ============================================================================
func _logbook() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var root := (loop as SceneTree).root
		if root != null:
			return root.get_node_or_null("LogbookManager")
	return null

func _sync_tally(amount: int, zh: String, en: String) -> void:
	var lb := _logbook()
	if lb != null and lb.has_method("add_tally_strokes"):
		lb.call("add_tally_strokes", amount, zh, en)

func _sync_name(entry_id: String, zh: String, en: String) -> void:
	var lb := _logbook()
	if lb != null and lb.has_method("record_real_name"):
		lb.call("record_real_name", entry_id, zh, en)

func _sync_ptsd() -> void:
	var lb := _logbook()
	if lb != null:
		lb.set("ptsd_thirst_unlocked", true)

func add_verified(entry_id: String, zh: String, en: String) -> void:
	for item in verified_names:
		if item.get("id", "") == entry_id:
			return
	verified_names.append({"id": entry_id, "zh": zh, "en": en})
	_sync_name(entry_id, zh, en)

func add_tally(amount: int, zh: String, en: String) -> void:
	tally_strokes = clampi(tally_strokes + amount, 0, 5)
	_sync_tally(amount, zh, en)

# ============================================================================
# 交互动作
# ============================================================================
func toggle_crouch() -> void:
	player.crouching = not player.crouching
	if player.crouching:
		player.sprinting = false

func toggle_logbook() -> void:
	logbook_open = not logbook_open

func toggle_lang() -> void:
	lang = "en" if lang == "zh" else "zh"

func toggle_glasses() -> void:
	glasses_cracked = not glasses_cracked

func toggle_mute() -> void:
	muted = not muted

func teleport(room_id: String) -> void:
	if not ROOM_SPAWNS.has(room_id):
		return
	var p: Vector2 = ROOM_SPAWNS[room_id]
	player.x = p.x
	player.y = p.y
	dog.x = p.x - 24.0
	dog.y = p.y + 10.0
	player.crouching = false
	player.sprinting = false
	_sfx("beep")
	add_feed(
		"【快速传送】已移动到 Room %s。" % room_id,
		"[TELEPORT] Moved to Room %s." % room_id,
		"text-sky-300"
	)

func throw_can() -> void:
	if player.cans <= 0:
		add_feed("空沙丁鱼罐头已用完！", "Out of empty sardine tin cans!", "text-rose-400")
		return
	player.cans -= 1
	_sfx("can")
	var c := ThrownCan.new()
	c.x = player.x
	c.y = player.y
	c.tx = clampf(mouse.x, 10.0, WORLD_W - 10.0)
	c.ty = clampf(mouse.y, 10.0, WORLD_H - 10.0)
	c.progress = 0.0
	thrown_cans.append(c)

func interact() -> void:
	var px := player.x
	var py := player.y

	# --- Room B：变形铁门卡撬棍 ---
	if dist(px, py, door_b.x + door_b.w * 0.5, door_b.y) < 65.0:
		door_b.wedge_frames = 15.0 * 60.0
		door_b.ever_wedged = true
		_sfx("wedge")
		spawn_float(door_b.x + 40.0, door_b.y - 12.0,
			"🔧 道钉撬棍已卡死导轨 (15.0s)", "🔧 Crowbar Wedged Door (15.0s)", "#fbbf24")
		add_feed(
			"【Room B · 撬棍卡门】你将俄式铸铁道钉撬棍死死插进变形铁门导轨，门体已物理锁死 15 秒！",
			"[Room B · Door Wedge] You jammed your cast-iron railway crowbar into the door track—locked shut for 15 seconds!",
			"text-amber-300"
		)
		_check_room_b()
		return

	# --- Room B：12cm 门底推饭盒 ---
	if dist(px, py, fence_box.x, fence_box.y) < 70.0 and not fence_box.delivered:
		fence_box.delivered = true
		_sfx("wedge")
		spawn_float(fence_box.x, fence_box.y - 15.0,
			"🍱 已从12cm门底窄缝推入铝饭盒！", "🍱 Pushed Buckwheat Lunchbox Under 12cm Gap!", "#34d399")
		add_verified("loader_north_canopy",
			"北雨棚铁丝网门内高热装卸工 (已推入黑麦铝饭盒·存活)",
			"North Canopy Quarantined Loader (Fed Buckwheat Lunchbox · Alive)")
		add_feed(
			"【Room B · 门底推饭盒】你用道钉撬棍弯头将装满热黑麦的铝饭盒从 12cm 排水缝推了进去。门内刮烂的手臂缩回阴影里，狼吞虎咽起来。",
			"[Room B · Under-Fence Delivery] Using your crowbar hook, you pushed the warm buckwheat lunchbox through the 12cm drainage gap. The raw-boned arm withdrew into the dark to eat.",
			"text-emerald-300"
		)
		_check_room_b()
		return

	# --- Room C：账面死人电传终端 ---
	if dist(px, py, terminal.x, terminal.y) < 75.0 and not terminal.recorded:
		terminal.recorded = true
		_sfx("beep")
		spawn_float(terminal.x, terminal.y - 15.0,
			"✍️ 已在日志背面记录：谢尔盖、玛丽亚", "✍️ Recorded Real Names: Sergey & Maria", "#34d399")
		add_verified("sergey_maria",
			"谢尔盖、玛丽亚 (南库3号柱滞留活人 · 电传报错0人)",
			"Sergey & Maria (Cold Storage Pillar 3 Survivors · Scanner Read 0)")
		add_feed(
			"【Room C · 账面死人】苏制电传终端红灯闪烁：『档案0892已移交，当前坐标在册人数：0』。你翻开《工作日志》背面，用钢笔写下了谢尔盖与玛丽亚的真名。",
			"[Room C · The Paper Dead] The Soviet terminal flashes: 'CURRENT COORDINATE HEADCOUNT: 0.' You opened the back of your Logbook and wrote Sergey and Maria's real names.",
			"text-emerald-300"
		)
		_check_room_c()
		return

	# --- Room C：回退期半人 抉择 A ---
	if dist(px, py, half_human.x, half_human.y) < 75.0 and half_human.status == "unresolved":
		choice_modal_open = true
		return

	# --- Room D：安娜 0419 ---
	var cage2: CageD = cages[1]
	if dist(px, py, cage2.x, cage2.y) < 80.0:
		cage2.inspected = true
		_sfx("beep")
		spawn_float(cage2.x, cage2.y - 20.0,
			"🔑 安娜(0419)：拉娜在铁壳号第三节车厢！",
			"🔑 Anna (0419): Sister Lana is in Carriage No. 3!", "#38bdf8")
		add_verified("anna_0419",
			"安娜 (0419号自愈吹哨人) & 妹妹拉娜 (0420号·锁在三号车厢)",
			"Anna (File 0419 Recovered Witness) & Sister Lana (0420 · In Carriage No. 3)")
		add_feed(
			"【Room D · 安娜0419证言】用皮带自缚双手熬过退烧的安娜认出了拉娜的照片：『阿列克谢！拉娜的烧已经退了，她昨晚被清杀队锁进了铁壳号第三节闷罐车厢！』",
			"[Room D · Anna 0419 Testimony] Self-bound Anna recognized Lana's photo: 'Alyosha! Lana's fever broke—last night they locked her inside Carriage No. 3 of the Buran!'",
			"text-cyan-300"
		)
		set_task("D")
		return

	# --- Room E：拾取砍骨刀 ---
	if dist(px, py, cleaver.x, cleaver.y) < 70.0 and not cleaver.taken:
		cleaver.taken = true
		player.weapon = "cleaver"
		_sfx("wedge")
		spawn_float(cleaver.x, cleaver.y - 15.0,
			"🔪 已拾取：东街宽背生锈砍骨刀", "🔪 Equipped: East St. Rusty Butcher Cleaver", "#f87171")
		add_feed(
			"【Room E · 备餐砧板】你从冻硬的甜菜头旁抓起了那把宽背生锈砍骨刀。靠近右侧杂物间木门将触发瓦西里破门冲锋！",
			"[Room E · Butcher Block] You picked up the wide-backed rusty butcher cleaver. Approach the right pantry door to trigger Vasily's breach!",
			"text-amber-300"
		)
		return

	add_feed(
		"附近没有可交互的目标。请靠近铁门、铁丝网、电传终端、涵洞半人、安娜铁笼或厨房砧板后按 [E]。",
		"No interactive target in range. Move closer to doors, terminals, NPCs, or the butcher block and press [E].",
		"text-slate-400"
	)

func _check_room_b() -> void:
	if door_b.ever_wedged and fence_box.delivered:
		set_task("B")

func _check_room_c() -> void:
	if terminal.recorded and half_human.status != "unresolved":
		set_task("C")

func choose_a(choice: String) -> void:
	choice_modal_open = false
	match choice:
		"A1":
			half_human.status = "saved_A1"
			_sfx("beep")
			spawn_float(half_human.x, half_human.y - 20.0,
				"💊 [A1] 已喂阿司匹林温水 (良知▲ · +0划痕)",
				"💊 [A1] Fed Aspirin Water (+0 Strokes)", "#34d399")
			add_verified("culvert_youth",
				"广轨涵洞退烧青年 (获阿司匹林救助 · 证实拉娜在三号车厢)",
				"Culvert Recovered Youth (Saved via Choice A1 · Confirmed Lana in Car 3)")
			add_feed(
				"【Room C · 抉择 A1 完成】青年喝下阿司匹林温水后停止了抽搐，感激地告诉你老伊万在西站水塔的暗号。工作日志保持 0 道划痕！",
				"[Room C · Choice A1 Complete] The youth's fever subsided after drinking the aspirin water. He shared Old Ivan's water-tower cipher. Logbook remains at 0 strokes!",
				"text-emerald-300"
			)
			_check_room_c()
		"A3":
			half_human.status = "killed_A3"
			_sfx("bonejam")
			add_tally(2,
				"Room C 抉择 A3：撬棍灭口回退期半人",
				"Room C Choice A3: Crowbar execution of a regressing human")
			player.cans += 2
			spawn_float(half_human.x, half_human.y - 20.0,
				"🩸 [A3] 撬棍灭口搜刮 (+2道卌字血划痕!)",
				"🩸 [A3] Crowbar Execution (+2 Tally Strokes!)", "#f43f5e")
			add_feed(
				"【Room C · 抉择 A3 警告】你用撬棍砸死了正在退烧的半人青年，搜出两只罐头，并在《工作日志》背面划下了两道刺眼的血痕（卌）！",
				"[Room C · Choice A3 Warning] You executed the regressing youth with your crowbar, looted two tins, and carved 2 blood strokes (卌) onto the back of your Work Logbook!",
				"text-rose-400"
			)
			_check_room_c()
		_:
			# A2：暂时退开，不处置
			add_feed(
				"【抉择 A2】你退开半步，把选择留到下一次呼吸。",
				"[Choice A2] You step back and leave the choice for another breath.",
				"text-slate-400"
			)

func swing() -> void:
	if qte_active:
		qte_hit()
		return
	player.swing_frames = 14.0
	_sfx("wedge")
	var d := player_dist(vasily.x, vasily.y)
	if d < 75.0 and (vasily.state == "charging" or vasily.state == "locked"):
		vasily.state = "jammed"
		qte_active = true
		qte_count = 0
		_sfx("bonejam")
		add_feed(
			"【锁骨卡刀】砍骨刀深陷瓦西里左锁骨缝，卡住了！在 1.5 秒节奏内连按 [Space] / 鼠标左键 6 次把刀拔出来！",
			"[Collarbone Jam] The cleaver is wedged in Vasily's left collarbone! Mash [Space] / Left Click 6 times to wrench it free!",
			"text-rose-300"
		)

func qte_hit() -> void:
	if not qte_active:
		return
	qte_count += 1
	_sfx("wedge")
	if qte_count >= qte_needed:
		qte_count = qte_needed
		qte_active = false
		vasily.state = "resolved"
		vasily.last_words_frames = 240.0
		ptsd_unlocked = true
		_sync_ptsd()
		player.bpm = 168.0
		_sfx("thirst")
		spawn_float(vasily.x, vasily.y - 22.0,
			"💧 瓦西里瞳孔回色：“……Пить（渴）……”",
			"💧 Vasily's eyes clear to blue: '…Пить (Thirsty)…'", "#38bdf8")
		add_verified("vasily_fyodorovich",
			"瓦西里·费奥多罗维奇 (东街食堂 · 锁骨卡刀，死前瞳孔回色喊出“Пить渴”)",
			"Vasily Fyodorovich (East St. Canteen · Eyes cleared before dying, whispered 'Пить')")
		add_feed(
			"【Room E · 锁骨卡刀与觉醒】你拔出了卡在瓦西里左锁骨缝里的砍骨刀！随着鲜血喷涌，他眼中的紫黑血翳消退，恢复了二十岁小伙子清澈的蓝眼睛，吐出半个俄语词：『……Пить（渴）……』！你已解锁永久【PTSD 干渴耳鸣】。",
			"[Room E · Collarbone Blade Jam] You wrenched the cleaver free! As his fever broke in blood loss, Vasily's eyes cleared to blue and he whispered: '…Пить (Thirsty)…'! Unlocked permanent [PTSD Thirst Tinnitus].",
			"text-rose-300"
		)
		set_task("E")

func drink() -> void:
	if ptsd_unlocked:
		_sfx("thirst")
		ptsd_flash = 90.0
		player.bpm = 152.0
		spawn_float(player.x, player.y - 24.0,
			"🧠 [PTSD耳鸣] 喉咙像吞了火炭，耳边回荡：“……Пить（渴）……”",
			"🧠 [PTSD TINNITUS] Throat burns like charcoal—echoing: '…Пить (Thirsty)…'", "#f43f5e")
		add_feed(
			"【PTSD 干渴幻听触发】你仰头喝下一口冰水，但吞咽末尾耳道里再次响起瓦西里临死前带着血泡的气音：『……Пить（渴）……』，心率飙升至 152 BPM！",
			"[PTSD Thirst Tinnitus] You swallowed cold water, but at the end of the gulp Vasily's dying whisper echoed: '…Пить (Thirsty)…'! Heart rate spiked to 152 BPM!",
			"text-rose-400"
		)
	else:
		_sfx("beep")
		player.bpm = maxf(72.0, player.bpm - 15.0)
		spawn_float(player.x, player.y - 18.0,
			"💧 喝水平复心率 (-15 BPM)", "💧 Drank Water (-15 BPM)", "#38bdf8")
		add_feed("【喝水】冰水滑过喉咙，心率降下来了。", "[Drink] Cold water slides down; your heart rate settles.", "text-sky-300")

# ============================================================================
# 主更新（对应 HTML updateGame；逐帧常量以 f = dt*60 归一化）
# ============================================================================
func update(dt: float, move: Vector2, sprint_held: bool, mouse_world: Vector2) -> void:
	dt = clampf(dt, 0.0, 0.05)
	var f := dt * 60.0
	time += dt
	tick += 1
	mouse = mouse_world
	var p := player

	if ptsd_flash > 0.0:
		ptsd_flash = maxf(0.0, ptsd_flash - f)
	if p.swing_frames > 0.0:
		p.swing_frames = maxf(0.0, p.swing_frames - f)
	if door_b.wedge_frames > 0.0:
		door_b.wedge_frames = maxf(0.0, door_b.wedge_frames - f)
	if vasily.last_words_frames > 0.0:
		vasily.last_words_frames = maxf(0.0, vasily.last_words_frames - f)

	# ---------------- 1. 移动与姿态 ----------------
	var moving := move.length() > 0.05
	p.sprinting = moving and sprint_held
	if p.sprinting:
		p.crouching = false

	p.in_slush = SLUSH_RECT.has_point(Vector2(p.x, p.y))
	var shadow := Rect2(
		STEAM_PIPE_RECT.position.x - PIPE_SHADOW_PAD.x,
		STEAM_PIPE_RECT.position.y - PIPE_SHADOW_PAD.y,
		STEAM_PIPE_RECT.size.x + PIPE_SHADOW_PAD.x + PIPE_SHADOW_PAD.z,
		STEAM_PIPE_RECT.size.y + PIPE_SHADOW_PAD.y + PIPE_SHADOW_PAD.w)
	p.in_pipe_shadow = p.crouching and shadow.has_point(Vector2(p.x, p.y))

	var speed := SPEED_WALK
	if p.crouching:
		speed = SPEED_CROUCH
	if p.sprinting:
		speed = SPEED_SPRINT
	if p.in_slush:
		speed *= SLUSH_FACTOR

	if moving and not qte_active:
		var n := move.normalized()
		p.x = clampf(p.x + n.x * speed * f, 30.0, WORLD_W - 30.0)
		p.y = clampf(p.y + n.y * speed * f, 30.0, WORLD_H - 30.0)

		# 足音波纹 / 雪泥靴印
		foot_acc += f
		var interval := 14.0 if p.sprinting else 26.0
		if foot_acc >= interval:
			foot_acc = 0.0
			var rr := 18.0
			if p.sprinting:
				rr = 115.0
			elif not p.crouching:
				rr = 48.0
			if p.in_slush:
				rr *= 1.85
			spawn_ripple(p.x, p.y, rr, "#38bdf8" if p.in_slush else "#94a3b8")
			if p.in_slush:
				var bp := Bootprint.new()
				bp.x = p.x
				bp.y = p.y
				bp.life = 240.0
				bootprints.append(bp)

	# 90° 视野扇形跟随鼠标
	p.angle = atan2(mouse.y - p.y, mouse.x - p.x)

	# ---------------- 2. 灰狼犬「灰烬」跟随 + 三态嗅觉 ----------------
	var target_x := p.x - cos(p.angle) * 28.0
	var target_y := p.y - sin(p.angle) * 28.0
	dog.x += (target_x - dog.x) * minf(1.0, 0.09 * f)
	dog.y += (target_y - dog.y) * minf(1.0, 0.09 * f)

	var near_rabid_a := false
	for r in rabids:
		if r.alive and player_dist(r.x, r.y) < 130.0:
			near_rabid_a = true
	var near_cage1 := player_dist(cages[0].x, cages[0].y) < 95.0
	var near_vasily := vasily.state == "charging" and player_dist(vasily.x, vasily.y) < 150.0
	var near_half := half_human.status == "unresolved" and player_dist(half_human.x, half_human.y) < 115.0
	var near_cage2 := player_dist(cages[1].x, cages[1].y) < 95.0
	var near_cage3 := player_dist(cages[2].x, cages[2].y) < 95.0
	var near_sergey := player_dist(terminal.x, terminal.y) < 95.0

	if near_rabid_a or near_cage1 or near_vasily:
		dog.state = "bark"
	elif near_half or near_cage2:
		dog.state = "whimper"
	elif near_cage3 or near_sergey:
		dog.state = "wag"
	else:
		dog.state = "follow"

	# 铁笼靠近即视为已嗅探
	for cg in cages:
		if player_dist(cg.x, cg.y) < 95.0:
			cg.inspected = true

	# ---------------- 3. 投掷空罐头 → 落地声波 → 清杀兵调查 ----------------
	for i in range(thrown_cans.size() - 1, -1, -1):
		var tc := thrown_cans[i]
		tc.progress += 0.06 * f
		if tc.progress >= 1.0:
			spawn_ripple(tc.tx, tc.ty, 145.0, "#f59e0b",
				"哐当！空铁罐声波", "CLANG! Tin Can Lure")
			if dist(tc.tx, tc.ty, soldier.x, soldier.y) < 380.0:
				soldier.target_angle = atan2(tc.ty - soldier.y, tc.tx - soldier.x)
				soldier.alert_frames = 150.0
				add_feed(
					"【声波诱敌】空罐头在冻土上叮当作响，内务清杀兵的探照灯转向了声源。",
					"[Acoustic Lure] The tin can clatters across frozen dirt—the O.S.K. searchlight swings toward the noise.",
					"text-amber-300"
				)
			thrown_cans.remove_at(i)

	# ---------------- 4. O.S.K. 清杀兵巡逻 / 开火 ----------------
	var osk := soldier
	if osk.alert_frames > 0.0:
		osk.alert_frames = maxf(0.0, osk.alert_frames - f)
		var diff := wrapf(osk.target_angle - osk.angle, -PI, PI)
		osk.angle += diff * minf(1.0, 0.14 * f)
	else:
		osk.x += float(osk.dir) * 0.85 * f
		if osk.x > osk.patrol_max_x:
			osk.dir = -1
		if osk.x < osk.patrol_min_x:
			osk.dir = 1
		osk.target_angle = PI / 2.0 + float(osk.dir) * 0.25
		osk.angle += (osk.target_angle - osk.angle) * minf(1.0, 0.08 * f)

	if osk.fire_cd > 0.0:
		osk.fire_cd = maxf(0.0, osk.fire_cd - f)

	# 光锥内的狂暴者：无条件开火（借刀杀人）
	for rab in rabids:
		if not rab.alive:
			continue
		rab.x += sin(tick * 0.04 + rab.phase) * 0.35 * f
		var d_osk := dist(rab.x, rab.y, osk.x, osk.y)
		var ang := atan2(rab.y - osk.y, rab.x - osk.x)
		var adiff := absf(wrapf(ang - osk.angle, -PI, PI))
		if d_osk < 260.0 and adiff < 0.48 and osk.fire_cd <= 0.0:
			osk.fire_cd = 35.0
			shots_fired += 1
			_sfx("akm")
			_fire_bullet(osk.x, osk.y, rab.x, rab.y)
			rab.hp -= 55.0
			spawn_float(rab.x, rab.y - 14.0,
				"💥 清杀队消音点射! (-55)", "💥 O.S.K. Suppressed Burst! (-55)", "#f87171")
			if rab.hp <= 0.0:
				rab.alive = false
				spawn_float(rab.x, rab.y - 26.0,
					"✅ 借刀杀人成功！狂暴者已清除",
					"✅ 'Borrowed Knife' Kill Confirmed!", "#34d399")
				add_feed(
					"【Room A · 借刀杀人验证通过】内务清杀兵（ОСК）被空罐头声响吸引，用消音 AKM 替你射杀了灰鳞狂暴者！",
					"[Room A · 'Borrowing the Knife' Verified] Lured by your tin can, the O.S.K. soldier eliminated the Rabid with a suppressed AKM burst!",
					"text-emerald-300"
				)
				set_task("A")

	# 玩家暴露在探照灯下（未蹲进蒸汽管阴影）
	var d_player := dist(p.x, p.y, osk.x, osk.y)
	var ang_p := atan2(p.y - osk.y, p.x - osk.x)
	var p_diff := absf(wrapf(ang_p - osk.angle, -PI, PI))
	if d_player < 215.0 and p_diff < 0.38 and not p.in_pipe_shadow and osk.fire_cd <= 0.0:
		osk.fire_cd = 50.0
		shots_fired += 1
		_sfx("akm")
		_fire_bullet(osk.x, osk.y, p.x, p.y)
		p.hp = maxf(15.0, p.hp - 12.0)
		p.bpm = minf(185.0, p.bpm + 25.0)
		spawn_float(p.x, p.y - 20.0,
			"⚠️ 暴露在清杀队探照灯下！请按 [Ctrl] 躲到蒸汽管后",
			"⚠️ Spotted by O.S.K. Searchlight! Hold [Ctrl] behind the pipe!", "#ef4444")

	# ---------------- 5. 环境声波线索 ----------------
	ambient_acc += f
	if ambient_acc >= 95.0:
		ambient_acc = 0.0
		if half_human.status == "unresolved":
			spawn_ripple(half_human.x, half_human.y, 65.0, "#e2e8f0",
				"“……Воды（水）……拉娜在三号车厢……”", "'…Воды (Water)… Lana is in Car 3…'")
		if not fence_box.delivered:
			spawn_ripple(fence_box.x + 28.0, fence_box.y, 55.0, "#f59e0b",
				"刺啦——门底窄缝刮擦声", "Scrape—hand reaching under 12cm gap")

	# ---------------- 6. Room E 瓦西里破门 ----------------
	if vasily.state == "locked" and cleaver.taken and player_dist(vasily.x, vasily.y) < 155.0:
		vasily.state = "charging"
		_sfx("bonejam")
		spawn_ripple(vasily.x, vasily.y, 120.0, "#ef4444",
			"砰！！瓦西里高烧破门扑出！", "CRASH!! Vasily breaches the pantry door!")
		add_feed(
			"【Room E · 危机爆发】杂物间木门炸裂！高烧 40℃ 的瓦西里冲了出来，快按 [Space] 或点击鼠标挥动砍骨刀自卫！",
			"[Room E · Breach] The pantry door explodes! Delirious with 40°C fever, Vasily charges—press [Space] to swing your cleaver!",
			"text-rose-400"
		)

	if vasily.state == "charging" and not qte_active:
		var a := atan2(p.y - vasily.y, p.x - vasily.x)
		vasily.x += cos(a) * 1.35 * f
		vasily.y += sin(a) * 1.35 * f
		if player_dist(vasily.x, vasily.y) < 34.0:
			swing()

	# ---------------- 7. 波纹 / 靴印 / 弹道 / 浮字 衰减 ----------------
	for i in range(ripples.size() - 1, -1, -1):
		var rp := ripples[i]
		rp.r += 1.4 * f
		if rp.r >= rp.max_r:
			ripples.remove_at(i)
	for i in range(bootprints.size() - 1, -1, -1):
		var bp := bootprints[i]
		bp.life -= f
		if bp.life <= 0.0:
			bootprints.remove_at(i)
	for i in range(bullets.size() - 1, -1, -1):
		var b := bullets[i]
		b.life -= f
		if b.life <= 0.0:
			bullets.remove_at(i)
	for i in range(floats.size() - 1, -1, -1):
		var ft := floats[i]
		ft.y -= 0.35 * f
		ft.life -= f
		if ft.life <= 0.0:
			floats.remove_at(i)

func _fire_bullet(sx: float, sy: float, tx: float, ty: float) -> void:
	var b := Tracer.new()
	b.sx = sx
	b.sy = sy
	b.tx = tx
	b.ty = ty
	b.life = 10.0
	bullets.append(b)
