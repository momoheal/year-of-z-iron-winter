extends "res://tests/smoke_kit.gd"
## Headless smoke — AI 脚步 + 遮挡衰减（P2.5 收尾）。
## 守三件事：
##   1) 遮挡口径是纯函数：被 layer-1 挡住就按 NightSfx.OCCLUSION_DB 压低音量；
##   2) 遮挡声走「压低首声 + 轻量延迟反射」，不引入外部音频文件；
##   3) 狂暴者 / 清杀兵 / 半人 / 伙伴的 _physics_process 真的会调 ctl.ai_step，
##      且脚步是低频的、只出声不产生噪声半径（不会反过来惊动 AI）。
## Run: Godot_v4.7.2-stable_win64 --headless --path godot_project -s tests/night_ai_step_smoke.gd

const NightSfx := preload("res://scripts/night/NightSfx.gd")



class SfxSpy extends Node:
	var calls: Array = []
	func play_at(sname: String, pos: Vector2, db: float = 0.0, jitter: float = 0.09) -> void:
		calls.append({"kind": "direct", "sname": sname, "db": db, "pos": pos})
	func play_at_occluded(sname: String, pos: Vector2, db: float = 0.0, jitter: float = 0.09) -> void:
		calls.append({"kind": "occluded", "sname": sname, "db": db, "pos": pos})


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== night_ai_step_smoke ==")
	_occlusion_contract()
	_echo_queue()
	_scene_steps()
	print("== RESULT: %d passed, %d failed ==" % [passes, failures.size()])
	for f in failures:
		print("   FAILED: ", f)
	quit(0 if failures.is_empty() else 1)


func _steps(calls: Array) -> int:
	var n := 0
	for c in calls:
		if String(c["sname"]).begins_with("step_"):
			n += 1
	return n


func _first_step(calls: Array) -> Dictionary:
	for c in calls:
		if String(c["sname"]).begins_with("step_"):
			return c
	return {}


# 1) 纯口径：遮挡 = 压低固定的 dB
func _occlusion_contract() -> void:
	print("[occlusion contract]")
	_assert(NightSfx.OCCLUSION_DB < 0.0, "遮挡衰减量为负（更闷更小声）", str(NightSfx.OCCLUSION_DB))
	_assert(is_equal_approx(NightSfx.occluded_db(true, -13.0), -13.0),
		"视线通畅时用原始 db", str(NightSfx.occluded_db(true, -13.0)))
	_assert(is_equal_approx(NightSfx.occluded_db(false, -13.0), -13.0 + NightSfx.OCCLUSION_DB),
		"被遮挡时按 OCCLUSION_DB 压低", str(NightSfx.occluded_db(false, -13.0)))


# 2) 遮挡声：首声压低 + 一声轻量延迟反射（纯合成，不读音频文件）
func _echo_queue() -> void:
	print("[occluded playback]")
	var sfx: Node = NightSfx.new()
	root.add_child(sfx)                    # _ready() 烘焙 CACHE
	var idx: int = int(sfx.get("_next_pos"))
	sfx.call("play_at_occluded", "step_snow", Vector2.ZERO, -13.0)
	var q: Array = sfx.get("_echo_queue")
	_assert(q.size() == 1, "遮挡脚步排了一声延迟反射", str(q.size()))
	var voices: Array = sfx.get("_pos")
	var first: AudioStreamPlayer2D = voices[idx]
	_assert(is_equal_approx(first.volume_db, -13.0),
		"首声按传入 db 播放", str(first.volume_db))
	sfx.call("_process", 0.1)              # 延迟到点
	var q2: Array = sfx.get("_echo_queue")
	_assert(q2.is_empty(), "延迟反射到点后出声并出队", str(q2.size()))
	var second: AudioStreamPlayer2D = voices[(idx + 1) % voices.size()]
	_assert(is_equal_approx(second.volume_db, -13.0 - 7.0),
		"反射声比首声更轻", str(second.volume_db))
	root.remove_child(sfx)
	sfx.free()


# 3) 场景端到端：脚步调用 + 遮挡衰减 + 低频 + 不产噪声 + AI 接线
func _scene_steps() -> void:
	print("[scene footsteps]")
	var s: Node = (load("res://scenes/night_explore.tscn") as PackedScene).instantiate()
	root.add_child(s)
	var spy := SfxSpy.new()
	s.sfx = spy
	var r = s.rabids[0]
	var rip0: int = int(s.ripples.size())

	# 无遮挡：player 在 (2000,1000)，r 在其右侧 200px（已验证 layer-1 通畅）
	s.player.global_position = Vector2(2000, 1000)
	r.global_position = s.player.global_position + Vector2(200, 0)
	s.ai_footstep(r.global_position, r)
	var c0: Dictionary = _first_step(spy.calls)
	_assert(not c0.is_empty() and String(c0["kind"]) == "direct",
		"视线通畅时脚步直达播放", str(spy.calls))
	_assert(not c0.is_empty() and is_equal_approx(float(c0["db"]), -13.0),
		"通畅脚步用 AI_STEP_DB 口径", str(c0))
	_assert(int(s.ripples.size()) == rip0, "AI 脚步不产生噪声半径（只是给玩家听）")

	# 遮挡：两人一起站到 Dumpster（layer-1，x≈510..632 / y≈341..384）的中腰高度，
	# 水平射线正好穿过它；只把玩家放到 Spawn 会从垃圾箱底下绕过去，不算遮挡。
	spy.calls.clear()
	s.player.global_position = Vector2(452.92, 362.5)
	r.global_position = s.player.global_position + Vector2(200, 0)
	s.ai_footstep(r.global_position, r)
	var c1: Dictionary = _first_step(spy.calls)
	_assert(not c1.is_empty() and String(c1["kind"]) == "occluded",
		"被掩体挡住时脚步走衰减口径", str(spy.calls))
	_assert(not c1.is_empty() and is_equal_approx(float(c1["db"]), -13.0 + NightSfx.OCCLUSION_DB),
		"遮挡脚步的 db 比通畅时低 OCCLUSION_DB", str(c1))
	_assert(int(s.ripples.size()) == rip0, "遮挡脚步同样不惊动 AI")

	# 低频：累计到间隔才响，站着不动不响
	spy.calls.clear()
	s.player.global_position = Vector2(2000, 1000)
	r.global_position = s.player.global_position + Vector2(200, 0)
	r.velocity = Vector2(120, 0)
	s.ai_step(r, 0.2)
	s.ai_step(r, 0.2)
	_assert(_steps(spy.calls) == 0, "脚步低频：没到间隔不出声", str(spy.calls))
	s.ai_step(r, 0.1)
	_assert(_steps(spy.calls) == 1, "累计到间隔才出一声", str(spy.calls))
	r.velocity = Vector2.ZERO
	s.ai_step(r, 1.0)
	_assert(_steps(spy.calls) == 1, "站着不动不出脚步")

	# 接线：AI 自己的 _physics_process 会调 ctl.ai_step（狂暴者示例）
	spy.calls.clear()
	var r2 = s.rabids[1]
	r2.ctl = s
	r2.state = "chase"
	r2.target = r2.global_position + Vector2(300, 0)
	r2._physics_process(0.5)
	_assert(_steps(spy.calls) >= 1, "狂暴者走路自己会出脚步", str(spy.calls))

	root.remove_child(s)
	s.free()
