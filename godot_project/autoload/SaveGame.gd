extends Node
## SaveGame.gd — 战役存档 + 玩家设置（autoload）。
##
## 存什么：CampaignSim 的「跨夜」状态（天数 / 母亲 / 透析液 / 良知 / 卌 / 仓库 / 同伴 / 旗标 /
## 真名 / 剧情 / 地点余量 / 日志 / 随机数状态）。不存夜潜进行中的状态 —— 存档点只有两个：
##   · 回到 602 室（phase = base）：新开局、睡觉、结算后进入次日；
##   · 结算页（phase = report）：夜潜的收获已经入账但还没过夜。
##     读这种档时会补走一次 to_base + advance_day，等价于玩家在结算页按了「回 602 室」。
## 自动存档由 Campaign._process 在 (phase, day) 变化时触发，CampaignSim 本身不碰磁盘。
##
## 格式：JSON（不用 str_to_var / ConfigFile 存战役 —— 那两种能反序列化出 Object）。
## JSON 的数字一律是 float，所以读档时逐字段还原 int。
##
## 测试隔离：用 `godot -s tests/xxx.gd` 跑时主循环是带脚本的 SceneTree，
## 此时自动换用 *_test 路径，跑测试永远不会覆盖玩家的真实存档和设置。

const VERSION := 1
const SAVE_PATH := "user://campaign_save.json"
const SAVE_PATH_TEST := "user://campaign_save_test.json"
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_PATH_TEST := "user://settings_test.cfg"

## 留空 = 按运行模式自动选（见 _is_test_run）；测试可显式改。
var save_path := ""
var settings_path := ""

## 主音量 0..1（暂停菜单里的滑块）；只作用于主总线音量，M 键静音另算。
var master_volume := 1.0


func _ready() -> void:
	load_settings()


static func _is_test_run() -> bool:
	var loop := Engine.get_main_loop()
	return loop != null and loop.get_script() != null


func _save_file() -> String:
	if save_path != "":
		return save_path
	return SAVE_PATH_TEST if _is_test_run() else SAVE_PATH


func _settings_file() -> String:
	if settings_path != "":
		return settings_path
	return SETTINGS_PATH_TEST if _is_test_run() else SETTINGS_PATH


# ============================================================================
# 战役存档
# ============================================================================
## 最近一次 save() 失败的原因（空串 = 成功或没尝试）。界面用它告诉玩家「这次没存上」。
var last_error := ""
## 最近一次 read_raw() 实际读的是哪一份："main" / "backup" / "tmp" / ""（没有可用存档）。
var last_load_source := ""

## 一份存档必须有的字段：缺了就当坏档，不拿它覆盖备份、也不拿来读。
const REQUIRED_KEYS := ["version", "day", "phase", "stash", "nodes"]


func has_save() -> bool:
	return not read_raw().is_empty()


func delete_save() -> void:
	var p := _save_file()
	for f in [p, p + ".bak", p + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))


## 写档。只接受 base / report 两个安全点；其余阶段返回 false 不写（不算失败，last_error 为空）。
##
## 步骤（每一步检查返回值，任何一步失败都至少留下一份可读的旧档）：
##   1. 写 .tmp，再读回来校验（JSON 能解析、版本对、必需字段齐全）；
##   2. 旧主档本身可读时才复制成 .bak —— 坏主档不会顶掉好备份；
##   3. 删旧主档 → .tmp 改名为主档；改名失败就用 .bak 把主档补回来。
## Windows 上「删 + 改名」不是原子操作；第 2 步的备份就是为这两步之间崩溃准备的。
func save(sim) -> bool:
	last_error = ""
	if sim == null or not (String(sim.phase) in ["base", "report"]):
		return false
	var p := _save_file()
	var tmp := p + ".tmp"
	var bak := p + ".bak"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return _fail("无法写入临时存档（%s）" % error_string(FileAccess.get_open_error()))
	f.store_string(JSON.stringify(to_dict(sim), "\t"))
	f.close()
	if _parse_file(tmp).is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		return _fail("临时存档写入后校验失败（磁盘已满或被占用？）")
	var abs_p := ProjectSettings.globalize_path(p)
	if FileAccess.file_exists(p) and not _parse_file(p).is_empty():
		var e := DirAccess.copy_absolute(abs_p, ProjectSettings.globalize_path(bak))
		if e != OK:
			# 备份不了就不动主档：旧档还在，只是这次没存上
			return _fail("无法备份上一份存档（%s）" % error_string(e))
	if FileAccess.file_exists(p) or DirAccess.dir_exists_absolute(abs_p):
		var e2 := DirAccess.remove_absolute(abs_p)
		if e2 != OK:
			return _fail("无法替换旧存档（%s）" % error_string(e2))
	var e3 := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), abs_p)
	if e3 != OK:
		if FileAccess.file_exists(bak):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(bak), abs_p)
		return _fail("存档改名失败（%s），已从备份恢复上一份" % error_string(e3))
	return true


func _fail(msg: String) -> bool:
	last_error = msg
	push_warning("SaveGame: " + msg)
	return false


## 读出原始字典。按「主档 → 备份 → 残留的 .tmp」顺序找第一份**校验通过**的，
## 不按修改时间挑最新的（最新的那份可能正是写坏的那份）。都不可用 → 空字典。
func read_raw() -> Dictionary:
	var p := _save_file()
	for pair in [[p, "main"], [p + ".bak", "backup"], [p + ".tmp", "tmp"]]:
		var d := _parse_file(String(pair[0]))
		if not d.is_empty():
			last_load_source = String(pair[1])
			return d
	last_load_source = ""
	return {}


## 读一份存档文件并校验；不存在 / 损坏 / 版本不认识 / 缺字段 → 空字典。
func _parse_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	# JSON.new().parse 返回错误码而不是往日志里刷 ERROR：坏档是可预期的情况
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not (json.data is Dictionary):
		return {}
	var d: Dictionary = json.data
	if int(d.get("version", 0)) != VERSION:
		return {}
	for k in REQUIRED_KEYS:
		if not d.has(k):
			return {}
	return d


## 标题页「继续」按钮上显示的摘要。
func summary() -> Dictionary:
	var d := read_raw()
	if d.is_empty():
		return {}
	return {
		"day": int(d.get("day", 1)),
		"mother_alive": bool(d.get("mother_alive", true)),
		"tally": int(d.get("tally", 0)),
		"saved_at": String(d.get("saved_at", "")),
		"source": last_load_source,          # "backup" / "tmp" 时标题页提示「从备份恢复」
	}


## 读档进 sim。成功后 sim.phase == "base"。
func load_into(sim) -> bool:
	var d := read_raw()
	if d.is_empty() or sim == null:
		return false
	apply(sim, d)
	return true


static func to_dict(sim) -> Dictionary:
	return {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"phase": String(sim.phase),
		"day": int(sim.day),
		"mother_alive": bool(sim.mother_alive),
		"dial": float(sim.dial),
		"conscience": float(sim.conscience),
		"tally": int(sim.tally),
		"stash": sim.stash.duplicate(true),
		"mates": sim.mates.duplicate(true),
		"flags": sim.flags.duplicate(true),
		"names": Array(sim.names),
		"story_done": sim.story_done.duplicate(true),
		"nodes": sim.nodes.duplicate(true),
		"log": Array(sim.log).duplicate(true),
		"events_log": Array(sim.events_log).duplicate(true),
		"mate": String(sim.mate),
		"load": sim.load.duplicate(true),
		"last_report": sim.last_report.duplicate(true),
		"lang": String(sim.lang),
		"sound_on": bool(sim.sound_on),
		"finished_demo": bool(sim.finished_demo),
		"day_message": String(sim.day_message),
		"selected_loc": String(sim.selected_loc),
		# RNG 状态是 64 位整数，JSON 的 double 存不下 —— 按字符串存
		"rng_state": str(sim.rng.state),
	}


static func apply(sim, d: Dictionary) -> void:
	sim.new_game()                       # 先回到干净的默认值，再逐项覆盖（缺字段的旧档也能读）
	sim.day = int(d.get("day", 1))
	sim.mother_alive = bool(d.get("mother_alive", true))
	sim.dial = float(d.get("dial", 2.0))
	sim.conscience = float(d.get("conscience", 50.0))
	sim.tally = int(d.get("tally", 0))
	sim.stash = _int_values(d.get("stash", {}))
	sim.load = _int_values(d.get("load", {}))
	sim.mates = _bool_values(d.get("mates", sim.mates))
	sim.flags = _dict(d.get("flags", {}))
	sim.story_done = _dict(d.get("story_done", {}))
	var nodes: Dictionary = sim.nodes
	var saved_nodes := _dict(d.get("nodes", {}))
	for id in saved_nodes:
		var st := _dict(saved_nodes[id])
		nodes[String(id)] = {
			"visits": int(st.get("visits", 0)),
			"left": float(st.get("left", 1.0)),
			"hint": int(st.get("hint", 0)),
		}
	sim.names.clear()
	for n in d.get("names", []):
		sim.names.append(String(n))
	sim.log.clear()
	for e in d.get("log", []):
		sim.log.append(_log_entry(e))
	sim.events_log.clear()
	for e in d.get("events_log", []):
		sim.events_log.append(_log_entry(e))
	sim.mate = String(d.get("mate", "none"))
	sim.last_report = _dict(d.get("last_report", {}))
	sim.lang = String(d.get("lang", "zh"))
	sim.sound_on = bool(d.get("sound_on", true))
	sim.finished_demo = bool(d.get("finished_demo", false))
	sim.day_message = String(d.get("day_message", ""))
	sim.selected_loc = String(d.get("selected_loc", ""))
	var rs := String(d.get("rng_state", ""))
	if rs.is_valid_int():
		sim.rng.state = rs.to_int()
	if String(d.get("phase", "base")) == "report":
		# 结算页存的档：收获已入账，补走「回 602 室 → 过夜」
		sim.to_base()
		sim.advance_day()
	else:
		sim.phase = "base"
	sim._sync_logbook()


static func _dict(v) -> Dictionary:
	return (v as Dictionary).duplicate(true) if v is Dictionary else {}


static func _int_values(v) -> Dictionary:
	var out := {}
	if v is Dictionary:
		for k in v:
			out[String(k)] = int(v[k])
	return out


static func _bool_values(v) -> Dictionary:
	var out := {}
	if v is Dictionary:
		for k in v:
			out[String(k)] = bool(v[k])
	return out


static func _log_entry(e) -> Dictionary:
	if not (e is Dictionary):
		return {"day": 0, "zh": "", "en": ""}
	return {"day": int(e.get("day", 0)), "zh": String(e.get("zh", "")), "en": String(e.get("en", ""))}


# ============================================================================
# 设置（音量）—— ConfigFile 只存几个标量
# ============================================================================
func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	_apply_volume()
	save_settings()


func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_settings_file()) == OK:
		master_volume = clampf(float(cfg.get_value("audio", "master_volume", 1.0)), 0.0, 1.0)
	_apply_volume()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.save(_settings_file())
