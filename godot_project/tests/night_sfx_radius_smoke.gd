extends "res://tests/smoke_kit.gd"
## Headless smoke test — 音频可闻半径契约（FIX-P0-6 防回归）。
## Run: Godot_v4.7.2-stable_win64 --headless --path godot_project -s tests/night_sfx_radius_smoke.gd
##
## 守着 NightSfx.play_at() 里的 RADIUS_M.get(sname, 18.0) 静默回退：
##   1) Arsenal.WEAPONS 里出现的每一个 sfx* id，RADIUS_M 都必须有显式键；
##   2) 每支武器的主音色可闻半径必须 ≥ 它的 noise 半径（AI 能听到的范围内玩家也能听到）；
##   3) 端到端：play_at() 落到 AudioStreamPlayer2D.max_distance 的值 = 显式半径 × PPM；
##   4) 音色库（CACHE）与 RADIUS_M 一一对应，不留缺键、不留孤立键。
## 全程从 Arsenal / NightSfx 的数据源动态取值，不写死音色清单；
## 不加载 night_explore.tscn，因此不受场景脚本改动影响。

const Arsenal := preload("res://scripts/night/Arsenal.gd")
const NightSfx := preload("res://scripts/night/NightSfx.gd")

var _sfx: Node = null


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== night_sfx_radius_smoke ==")
	_sfx = NightSfx.new()
	root.add_child(_sfx)          # 触发 _ready() → 烘焙 CACHE
	_arsenal_ids_have_radius()
	_radius_covers_noise()
	_play_at_uses_explicit_radius()
	_bank_matches_radius_table()
	root.remove_child(_sfx)
	_sfx.free()
	_sfx = null
	print("== RESULT: %d passed, %d failed ==" % [passes, failures.size()])
	for f in failures:
		print("   FAILED: ", f)
	# quit() 不终止函数执行 —— 分开写 "if 有失败: quit(1)" 再 quit(0)，
	# 后者会覆盖前者，退出码永远是 0，CI 的 rc 判断就成了摆设。用单表达式。
	quit(0 if failures.is_empty() else 1)


# ---------------------------------------------------------------------------
# 1) Arsenal 的每一个 sfx / sfx_hit id 都要有显式半径键
#    动态扫所有以 "sfx" 开头的字段，未来加 sfx_reload 之类也自动纳入。
# ---------------------------------------------------------------------------
func _arsenal_ids_have_radius() -> void:
	print("[arsenal sfx ids]")
	var seen: Dictionary = {}
	for id in Arsenal.WEAPONS.keys():
		var w: Dictionary = Arsenal.WEAPONS[id]
		for key in w.keys():
			if not String(key).begins_with("sfx"):
				continue
			var sid := String(w[key])
			if sid == "" or seen.has(sid):
				continue
			seen[sid] = true
			_assert(NightSfx.RADIUS_M.has(sid),
				"Arsenal[%s].%s = %s 有显式可闻半径" % [id, String(key), sid],
				"缺键 → play_at 静默回退 18m")


# ---------------------------------------------------------------------------
# 2) 可闻半径 ≥ AI 噪声半径：不能出现「敌人已压来，玩家却听不到枪声」
# ---------------------------------------------------------------------------
func _radius_covers_noise() -> void:
	print("[radius >= noise]")
	for id in Arsenal.WEAPONS.keys():
		var w: Dictionary = Arsenal.WEAPONS[id]
		var sid := String(w.get("sfx", ""))
		if sid == "":
			continue
		var noise := float(w.get("noise", 0.0))
		var r := float(NightSfx.RADIUS_M.get(sid, -1.0))
		_assert(r >= noise,
			"%s 的 %s：%.1fm ≥ noise %.1fm" % [String(id), sid, r, noise],
			"半径 %.1fm < noise %.1fm" % [r, noise])


# ---------------------------------------------------------------------------
# 3) 端到端：真的调一次 play_at()，核对落到播放器上的 max_distance
# ---------------------------------------------------------------------------
func _play_at_uses_explicit_radius() -> void:
	print("[play_at max_distance]")
	for id in Arsenal.WEAPONS.keys():
		var w: Dictionary = Arsenal.WEAPONS[id]
		var sid := String(w.get("sfx", ""))
		if sid == "" or not _sfx.has_stream(sid):
			continue
		var idx: int = _sfx._next_pos
		_sfx.play_at(sid, Vector2.ZERO)
		var p: AudioStreamPlayer2D = _sfx._pos[idx]
		var r := float(NightSfx.RADIUS_M.get(sid, -1.0))
		var want := r * NightSfx.PPM
		_assert(is_equal_approx(p.max_distance, want),
			"%s 的 %s 落到 %.0f px（%.1fm × PPM）" % [String(id), sid, p.max_distance, r],
			"实际 %.0f，期望 %.0f（18m 回退值 = 1152）" % [p.max_distance, want])


# ---------------------------------------------------------------------------
# 4) 音色库 ↔ 半径表一一对应；顺带 print 实测音色数（文档口径由发布域统一）
# ---------------------------------------------------------------------------
func _bank_matches_radius_table() -> void:
	print("[bank <-> radius table]")
	var bank: Dictionary = _sfx.CACHE
	var missing: Array = []
	for k in bank.keys():
		if not NightSfx.RADIUS_M.has(k):
			missing.append(k)
	_assert(missing.is_empty(), "音色库全部音色都有显式可闻半径", str(missing))
	var orphan: Array = []
	for k in NightSfx.RADIUS_M.keys():
		if not bank.has(k):
			orphan.append(k)
	_assert(orphan.is_empty(), "半径表没有指向不存在音色的孤立键", str(orphan))
	_assert(bank.size() == NightSfx.RADIUS_M.size(),
		"音色库与半径表键数一致", "%d vs %d" % [bank.size(), NightSfx.RADIUS_M.size()])
	print("  [info] CACHE 实测 %d 种音色，RADIUS_M %d 键" % [bank.size(), NightSfx.RADIUS_M.size()])
