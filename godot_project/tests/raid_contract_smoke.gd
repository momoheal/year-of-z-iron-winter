extends "res://tests/smoke_kit.gd"
## Headless smoke test — 夜潜交接契约（M1 / T01–T03）
##
## Run:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path godot_project -s tests/raid_contract_smoke.gd
##
## 覆盖：RaidConfig 与旧 cfg 互转 / 每次出发唯一 raid_id /
##       四种收场（extracted / downed / dawn / abort，外加 frozen → downed）的既有损失规则 /
##       携带物：出发只扣一次、节点化路径不重复归还、灰盒路径剩余原样归还 /
##       弹药只记录不入库 / 良知与卌一次性入账 / 拒收错误局标识与非法收场 /
##       同一结果提交两次，第二次不改仓库、良知、卌、地点余量、日期 /
##       真实场景往返：节点化夜潜 → build_raid_result → 回 campaign.tscn → take_sim。
##
## 成功输出：RAID_CONTRACT_SMOKE_PASS

const Data := preload("res://scripts/CampaignData.gd")
const SimScript := preload("res://scripts/CampaignSim.gd")
const RaidConfig := preload("res://scripts/raid/RaidConfig.gd")
const RaidResult := preload("res://scripts/raid/RaidResult.gd")
const RaidSimScript := preload("res://scripts/RaidSim.gd")

const LOC := "coldstore"            # 开局就能去的主线地点（节点化场景 night_coldstore.tscn）



func _init() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _bridge() -> Node:
	return root.get_node_or_null("RaidBridge")


## 新开一局并从 602 室出发去 LOC，携带 load。返回 sim（已在 raid 阶段）。
func _depart(load: Dictionary):
	var sim = SimScript.new()
	sim.phase = "base"
	sim.add_item("asp", 2)
	sim.add_item("water", 2)
	sim.add_item("band", 2)
	sim.add_item("can", 2)
	sim.load = load.duplicate()
	var ok: bool = sim.depart(Data.loc(LOC))
	_assert(ok, "depart to %s succeeds" % LOC)
	return sim


## 状态快照：重复提交前后逐项比较。
func _snap(sim) -> Dictionary:
	return {
		"stash": sim.stash.duplicate(true),
		"conscience": sim.conscience,
		"tally": sim.tally,
		"nodes": sim.nodes.duplicate(true),
		"day": sim.day,
		"phase": sim.phase,
		"flags": sim.flags.duplicate(true),
		"mates": sim.mates.duplicate(true),
		"report": sim.last_report.duplicate(true),
		"log": sim.log.size(),
		"night_complete": sim.night_complete,
		"sound_on": sim.sound_on,
		"weapon_mods": sim.weapon_mods.duplicate(true),
	}


## 照 NightExplore.build_raid_result 的口径造一份节点化结果：携带物已并入 pack，refund_load 恒为空。
func _night_result(sim, reason: String, pack: Array, conscience: float, tally: int):
	var res = RaidResult.from_raid_sim(sim.raid, reason)
	res.raid_id = String(_bridge().cfg.get("raid_id", ""))
	res.pack.clear()
	for id in pack:
		res.pack.append(String(id))
	res.refund_load = {}
	res.hp = 80.0
	res.warmth = 55.0
	res.ammo = 7
	res.conscience_delta = conscience
	res.tally_delta = tally
	res.tally_reason_zh = "测试：灭口"
	res.tally_reason_en = "test: kill"
	res.sound_on = false
	res.add_event("good", "带回 %d 件物资" % pack.size(), "Brought back %d items" % pack.size())
	return res


func _run() -> void:
	print("== raid_contract_smoke ==")
	await _frames(1)
	_section_config()
	_section_end_reasons()
	_section_greybox_refund()
	_section_rejections()
	_section_result_roundtrip()
	await _section_scene_roundtrip()
	await _section_recovery()
	await _section_visual_interp()
	_section_save_boundaries()
	_section_t04_deferred()

	print("")
	print("==== RESULT: %d passed, %d failed ====" % [passes, failures.size()])
	if failures.is_empty():
		print("RAID_CONTRACT_SMOKE_PASS")
	else:
		for f in failures:
			print("  FAILED: ", f)
		print("RAID_CONTRACT_SMOKE_FAIL")
	var b := _bridge()
	if b != null:
		b.clear()
	quit(0 if failures.is_empty() else 1)


# ---------------------------------------------------------------------------
# 1. RaidConfig ↔ 旧 cfg；raid_id 唯一且三处一致
# ---------------------------------------------------------------------------
func _section_config() -> void:
	print("-- config")
	var load := {"can": 1, "water": 1, "asp": 1, "band": 0}
	var sim = _depart(load)
	var cfg: Dictionary = _bridge().cfg
	var rid := String(cfg.get("raid_id", ""))
	_assert(rid != "", "cfg carries a raid_id", rid)
	_assert(sim.current_raid_id == rid, "campaign tracks the same open raid_id", sim.current_raid_id)
	_assert(String(sim.raid.raid_id) == rid, "RaidSim container carries the raid_id")
	_assert(_bridge().raid_id() == rid, "RaidBridge.raid_id() exposes it")
	_assert(cfg["weapon"] is Dictionary and String(cfg["weapon"]["id"]) == String(sim.best_weapon()["id"]),
		"cfg.weapon stays the whole weapon Dictionary (legacy readers)")
	var conf = RaidConfig.from_dict(cfg)
	_assert(conf.weapon_id == String(sim.best_weapon()["id"]), "RaidConfig keeps only the weapon id", conf.weapon_id)
	_assert(conf.loc_id == LOC and conf.night_seconds > 0.0, "RaidConfig loc_id / night_seconds")
	var back: Dictionary = conf.to_dict()
	var same := true
	for k in cfg.keys():
		if not back.has(k) or str(back[k]) != str(cfg[k]):
			same = false
			print("    cfg key differs: ", k)
	_assert(same and back.size() == cfg.size(), "RaidConfig.to_dict() reproduces the legacy cfg exactly")
	_assert(int(cfg["load"]["water"]) == 1 and int(cfg["load"]["can"]) == 1, "cfg.load is the carried Dictionary")
	_assert(int(sim.stash.get("water", 0)) == 2 and int(sim.stash.get("can", 0)) == 3,
		"departure deducts the carried items exactly once",
		"water=%d can=%d" % [int(sim.stash.get("water", 0)), int(sim.stash.get("can", 0))])
	var conf2 = RaidConfig.from_dict({"weapon": "mosin", "loc": Data.loc(LOC)})
	_assert(conf2.weapon_id == "mosin" and String(conf2.to_dict()["weapon"]["id"]) == "mosin",
		"RaidConfig accepts a bare weapon id and expands it back")
	var other = _depart({})
	_assert(other.current_raid_id != rid, "every departure gets a new raid_id", other.current_raid_id)
	_bridge().clear()


# ---------------------------------------------------------------------------
# 2. 四种收场（节点化口径）+ 重复提交
# ---------------------------------------------------------------------------
func _section_end_reasons() -> void:
	print("-- end reasons (node raid)")
	var pack := ["water", "asp", "scrap", "scrap", "band"]   # 前三件里有两件是出发带的携带物
	var expect := {
		"extracted": {"water": 1, "asp": 1, "scrap": 2, "band": 1},
		"dawn": {"water": 1, "scrap": 1, "band": 1},          # 下标 0、2、4 隔项保留
		"downed": {},
		"abort": {},
		"frozen": {},                                         # 冻倒按 downed
	}
	for reason in expect.keys():
		var sim = _depart({"water": 1, "asp": 1, "band": 1, "can": 0})
		var stash0: Dictionary = sim.stash.duplicate()
		var c0: float = sim.conscience
		var t0: int = sim.tally
		var day0: int = sim.day
		var visits0 := int(sim.node_state(LOC)["visits"])
		var left0 := float(sim.node_state(LOC)["left"])
		var ammo0 := int(sim.stash.get("ammo", 0))
		var res = _night_result(sim, reason, pack, -4.0, 1)
		var rep: Dictionary = sim.submit_raid_result(res)
		var settled := String(RaidResult.normalize_reason(reason))
		_assert(not rep.is_empty() and sim.phase == "report", "%s: settles onto the report" % reason, sim.last_rejection)
		_assert(String(rep.get("reason", "")) == settled, "%s: report reason is %s" % [reason, settled])
		var ok := true
		var detail := ""
		for id in ["water", "asp", "band", "scrap", "can"]:
			var want := int(stash0.get(id, 0)) + int(expect[reason].get(id, 0))
			if int(sim.stash.get(id, 0)) != want:
				ok = false
				detail += "%s %d≠%d " % [id, int(sim.stash.get(id, 0)), want]
		_assert(ok, "%s: stash gains follow the loss rule, carried items not refunded twice" % reason, detail)
		var lost_want: int = int({"extracted": 0, "dawn": 2}.get(settled, 5))
		var lost_n := 0
		for k in rep.get("lost", {}):
			lost_n += int(rep["lost"][k])
		_assert(lost_n == lost_want, "%s: report lists %d items left behind" % [reason, lost_want], str(rep.get("lost", {})))
		var hp_want := 58 if settled == "dawn" else 80
		_assert(int(rep["hp"]) == hp_want, "%s: report hp %d" % [reason, hp_want], str(rep["hp"]))
		_assert(is_equal_approx(sim.conscience, c0 - 4.0), "%s: conscience delta applied once" % reason, str(sim.conscience))
		_assert(sim.tally == t0 + 1, "%s: one tally stroke applied" % reason, str(sim.tally))
		_assert(int(sim.node_state(LOC)["visits"]) == visits0 + 1, "%s: node visit counted" % reason)
		_assert(is_equal_approx(float(sim.node_state(LOC)["left"]), clampf(left0 - 0.5, 0.05, 1.0)),
			"%s: node remaining drops by half" % reason)
		_assert(sim.day == day0, "%s: settlement does not advance the day" % reason)
		_assert(int(sim.stash.get("ammo", 0)) == ammo0, "%s: ammo is reported, not banked" % reason)
		_assert(not sim.sound_on, "%s: the night's mute setting comes home" % reason)
		_assert(sim.raid == null and not sim.has_open_raid(), "%s: raid closed" % reason)
		# --- 同一结果第二次提交 ---
		var before := _snap(sim)
		var rep2: Dictionary = sim.submit_raid_result(res)
		_assert(rep2.is_empty() and sim.last_rejection == "already_settled",
			"%s: second submit is rejected as already settled" % reason, sim.last_rejection)
		_assert(str(_snap(sim)) == str(before), "%s: second submit changes nothing" % reason)
		var rep3: Dictionary = sim.finish_raid(settled)
		_assert(rep3.is_empty() and str(_snap(sim)) == str(before), "%s: legacy finish_raid after settlement is a no-op" % reason)
		# 次日只由「回 602 室」推进一次
		sim.to_base()
		sim.advance_day()
		_assert(sim.day == day0 + 1, "%s: next day advances exactly once" % reason)
		_assert(sim.submit_raid_result(res).is_empty() and sim.day == day0 + 1,
			"%s: a stale result after the next day is still rejected" % reason)
	_bridge().clear()


# ---------------------------------------------------------------------------
# 3. 灰盒 RaidSim 适配：剩余携带物原样归还（含倒下 / 放弃），只还一次
# ---------------------------------------------------------------------------
func _section_greybox_refund() -> void:
	print("-- greybox adapter")
	for reason in ["extracted", "dawn", "downed", "abort"]:
		var sim = _depart({"water": 1, "band": 2, "asp": 0, "can": 0})
		var stash0: Dictionary = sim.stash.duplicate()
		sim.raid.pack.clear()
		sim.raid.pack.append("scrap")
		sim.raid.pack.append("wire")
		sim.raid.load["water"] = 0          # 夜里喝掉了一壶
		var rep: Dictionary = sim.finish_raid(reason)
		_assert(not rep.is_empty(), "greybox %s: legacy finish_raid settles through the adapter" % reason)
		_assert(int(sim.stash.get("water", 0)) == int(stash0.get("water", 0)), "greybox %s: consumed water not refunded" % reason)
		_assert(int(sim.stash.get("band", 0)) == int(stash0.get("band", 0)) + 2,
			"greybox %s: unused bandages refunded once" % reason)
		var scrap_want := int(stash0.get("scrap", 0)) + (1 if reason in ["extracted", "dawn"] else 0)
		_assert(int(sim.stash.get("scrap", 0)) == scrap_want, "greybox %s: pack follows the loss rule" % reason)
		var before := _snap(sim)
		_assert(sim.finish_raid(reason).is_empty() and str(_snap(sim)) == str(before),
			"greybox %s: second finish_raid changes nothing" % reason)
	_bridge().clear()


# ---------------------------------------------------------------------------
# 4. 拒收：错误局标识 / 非法收场 / 没有出发
# ---------------------------------------------------------------------------
func _section_rejections() -> void:
	print("-- rejections")
	var sim = _depart({"water": 1, "asp": 0, "band": 0, "can": 0})
	var before := _snap(sim)
	var wrong = _night_result(sim, "extracted", ["scrap"], 3.0, 0)
	wrong.raid_id = "d1-elsewhere-99"
	_assert(sim.submit_raid_result(wrong).is_empty() and sim.last_rejection == "wrong_raid",
		"a result for another raid_id is rejected", sim.last_rejection)
	var bad = _night_result(sim, "cutscene", ["scrap"], 3.0, 0)
	_assert(sim.submit_raid_result(bad).is_empty() and sim.last_rejection == "bad_reason",
		"an illegal end reason is rejected", sim.last_rejection)
	var nameless = _night_result(sim, "extracted", ["scrap"], 3.0, 0)
	nameless.raid_id = ""
	_assert(sim.submit_raid_result(nameless).is_empty() and sim.last_rejection == "no_raid_id",
		"a result without raid_id is rejected", sim.last_rejection)
	_assert(sim.submit_raid_result(null).is_empty(), "a null result is rejected")
	_assert(str(_snap(sim)) == str(before) and sim.has_open_raid() and sim.raid != null,
		"rejections leave the open raid and all state untouched")
	var good = _night_result(sim, "extracted", ["scrap"], 3.0, 0)
	_assert(not sim.submit_raid_result(good).is_empty(), "the right result is still accepted afterwards")
	var fresh = SimScript.new()
	_assert(fresh.submit_raid_result(good).is_empty() and fresh.last_rejection == "no_open_raid",
		"a campaign that never departed rejects results", fresh.last_rejection)
	# 卌划痕上限 5（结算口径与 add_tally 一致）
	var sim2 = _depart({})
	sim2.tally = 4
	sim2.submit_raid_result(_night_result(sim2, "extracted", [], 0.0, 3))
	_assert(sim2.tally == 5, "tally strokes clamp at 5", str(sim2.tally))
	# 放弃出发（场景切换失败）关闭当前局，之后的结果一律拒收
	var sim3 = _depart({"water": 1, "asp": 0, "band": 0, "can": 0})
	var late = _night_result(sim3, "extracted", ["scrap"], 0.0, 0)
	sim3.cancel_departure()
	_assert(not sim3.has_open_raid() and sim3.submit_raid_result(late).is_empty(),
		"cancel_departure closes the raid so a late result cannot settle")
	_bridge().clear()


# ---------------------------------------------------------------------------
# 5. RaidResult ↔ Dictionary
# ---------------------------------------------------------------------------
func _section_result_roundtrip() -> void:
	print("-- result dictionary")
	var r = RaidResult.create()
	r.raid_id = "d2-yard-3"
	r.loc_id = "yard"
	r.reason = "dawn"
	r.pack.append("dial")
	r.ammo = 5
	r.conscience_delta = -2.5
	r.tally_delta = 1
	r.coldstore_trace = true
	r.salvaged_weapons.append("mosin")
	r.add_event("note", "测试", "test")
	var d: Dictionary = r.to_dict()
	var r2 = RaidResult.from_dict(d)
	_assert(str(r2.to_dict()) == str(d), "RaidResult survives a Dictionary round trip")
	_assert(r2.sound_on == null and r2.weapon_mods == null, "unset preferences stay null (= leave campaign as is)")
	_assert(RaidResult.from_dict({"reason": "frozen"}).reason == "downed", "frozen normalises to downed")


# ---------------------------------------------------------------------------
# 6. 真实场景往返：campaign → 节点化夜潜 → 回 campaign.tscn
# ---------------------------------------------------------------------------
func _section_scene_roundtrip() -> void:
	print("-- scene round trip")
	var sim = _depart({"water": 1, "asp": 1, "band": 0, "can": 1})
	var L: Dictionary = Data.loc(LOC)
	var stash0: Dictionary = sim.stash.duplicate()
	var c0: float = sim.conscience
	var day0: int = sim.day
	var night: Node = (load(String(L["scene"])) as PackedScene).instantiate()
	root.add_child(night)
	await _frames(3)
	_assert(night.in_campaign, "night scene picks the raid up from RaidBridge")
	_assert(night.pack.count("water") == 1 and night.pack.count("asp") == 1,
		"carried water / aspirin enter the night pack", str(night.pack))
	night.pack.append("scrap")
	night.conscience = 2.0
	night.tally = 0
	# 过场 / 交互状态下的 Enter 不能结束夜潜
	night._return_to_campaign("cutscene")
	# T04：夜里触发的旗标 / 看完的引导只记在本地，结算时才写回战役
	night._set_campaign_flag("redzone_mother_seen")
	night._on_coach_finished()
	_assert(not sim.flags.has("redzone_mother_seen") and not bool(sim.seen.get("night", false)),
		"night-time flags and tutorial progress do not touch the campaign before settlement")
	_assert(night._campaign_flag("redzone_mother_seen"), "the night itself already treats the flag as set")
	_assert(sim.raid != null and sim.has_open_raid(), "a non-end state does not settle the raid")
	var res = night.build_raid_result("extracted")
	_assert(res.raid_id == sim.current_raid_id, "build_raid_result carries the bridge raid_id")
	_assert(res.refund_load.is_empty(), "node raid never refunds load separately")
	_assert(res.pack.size() == night.pack.size(), "result pack mirrors the night pack")
	# 天亮前的反馈：背包行预告隔项保留；最后 15 秒催一次（只一次）
	night.night_left = 10.0
	night.update_dawn()
	_assert(night.dawn_final_cued, "the final dawn warning fires inside the last 15 s")
	night._refresh_hud()
	_assert(String(night._lbl_bag.text).contains("天亮被抓只保得住"), "the bag line previews what survives dawn",
		String(night._lbl_bag.text))
	night.night_left = 9.0
	night.update_dawn()
	night.state = "extracted"
	night._return_to_campaign("extracted")
	await _frames(4)
	_assert(sim.phase == "report" and sim.raid == null, "returning settles the raid once")
	_assert(int(sim.stash.get("scrap", 0)) == int(stash0.get("scrap", 0)) + 1
		and int(sim.stash.get("water", 0)) == int(stash0.get("water", 0)) + 1,
		"extracted haul (including carried water) banks exactly once")
	_assert(is_equal_approx(sim.conscience, c0 + 2.0), "night conscience applied once", str(sim.conscience))
	_assert(bool(sim.flags.get("redzone_mother_seen", false)) and bool(sim.seen.get("night", false)),
		"night flags and tutorial progress arrive with the settlement")
	var campaign := current_scene
	_assert(campaign != null and campaign.get("sim") == sim, "campaign.tscn takes the same sim back from the bridge")
	var before := _snap(sim)
	# 同帧第二次触发（按钮 + Enter）：不能再结算，也不能把战役换成新档
	night._return_to_campaign("extracted")
	await _frames(4)
	_assert(str(_snap(sim)) == str(before), "a second return does not settle again")
	_assert(sim.day == day0, "the day is not advanced by the night")
	night.queue_free()
	if current_scene != null:
		current_scene.queue_free()
	await _frames(2)


# ---------------------------------------------------------------------------
# 7. 异常路径：桥上没有 sim / 节点化夜潜没交结果就回到战役
# ---------------------------------------------------------------------------
func _campaign_scene() -> Node:
	var c: Node = (load("res://scenes/campaign.tscn") as PackedScene).instantiate()
	root.add_child(c)
	return c


func _section_recovery() -> void:
	print("-- recovery")
	_bridge().begin(null, {"pack_max": 8})
	var c := _campaign_scene()
	await _frames(2)
	_assert(c.get("sim") != null and not _bridge().active,
		"bridge without a sim: campaign opens a fresh game instead of crashing")
	c.queue_free()
	await _frames(2)
	var sim = _depart({"water": 1, "asp": 1, "band": 0, "can": 0})
	var water_after_depart := int(sim.stash.get("water", 0))
	sim.pending_scene = ""          # 模拟：已经切进夜潜场景，然后没有提交结果就回来了
	var c2 := _campaign_scene()
	await _frames(2)
	_assert(c2.get("sim") == sim, "the same sim comes back from the bridge")
	_assert(sim.phase == "map" and sim.raid == null and not sim.has_open_raid(),
		"an unsettled node raid is cancelled, not run as a greybox raid", sim.phase)
	_assert(int(sim.stash.get("water", 0)) == water_after_depart + 1,
		"cancelling refunds the carried items once")
	_assert(int(sim.node_state(LOC)["visits"]) == 0 and not sim.night_complete,
		"a cancelled night does not count as a visit")
	# 结算页「睡到明天」重复触发只能推进一天
	var s3 = _depart({})
	s3.submit_raid_result(_night_result(s3, "extracted", ["scrap"], 0.0, 0))
	c2.sim = s3
	c2.hud.bind_campaign(s3, c2)
	var d0: int = s3.day
	s3.flags["story_slide_queue"] = []          # 不让首访冷库的剧情幻灯拦住「睡到明天」
	s3.story_open = false
	c2.hud._report_sleep()
	var d1: int = s3.day
	c2.hud._report_sleep()
	_assert(d1 <= d0 + 1 and s3.day == d1 and s3.phase != "report",
		"sleeping from the report twice never advances more than one day", "%d → %d → %d" % [d0, d1, s3.day])
	c2.queue_free()
	await _frames(2)
	_bridge().clear()


# ---------------------------------------------------------------------------
# 8. 玩家渲染插值：显示位置落在上一 tick 与这一 tick 之间，传送立即生效
# ---------------------------------------------------------------------------
func _section_visual_interp() -> void:
	print("-- render interpolation")
	_bridge().clear()
	var night: Node = (load("res://scenes/night_explore.tscn") as PackedScene).instantiate()
	root.add_child(night)
	await _frames(3)
	var pl = night.player
	_assert(pl.has_method("visual_position"), "player exposes visual_position()")
	night.state = "play"
	pl.frozen = false
	Input.action_press("move_right")
	for i in 6:
		await physics_frame
		await process_frame
	var v: Vector2 = pl.visual_position()
	var lo := minf(pl._prev_pos.x, pl._cur_pos.x) - 0.01
	var hi := maxf(pl._prev_pos.x, pl._cur_pos.x) + 0.01
	_assert(v.x >= lo and v.x <= hi, "visual position stays between the last two physics ticks",
		"%f not in [%f, %f]" % [v.x, lo, hi])
	_assert(pl._cur_pos.x > pl._prev_pos.x, "walking right advances the physics position")
	Input.action_release("move_right")
	var far: Vector2 = pl.global_position + Vector2(640, 0)
	pl.global_position = far
	_assert(pl.visual_position() == far, "a teleport shows up immediately (no slide from the old spot)")
	var shape := pl.get_node("Shape") as Node2D
	_assert(is_equal_approx(shape.position.y, -2.0), "collision shape is never offset by the visual interpolation")
	# HUD 按变化刷新：不变的帧不重排文字，变化的那一帧立刻刷新
	night.set_process(false)
	night._hud_tick(0.0)
	var n0: int = night.hud_full_refreshes
	for i in 3:
		night._hud_tick(0.01)
	_assert(night.hud_full_refreshes == n0, "unchanged frames skip the full HUD refresh",
		"%d → %d" % [n0, night.hud_full_refreshes])
	night.cans += 4
	night._hud_tick(0.01)
	_assert(night.hud_full_refreshes == n0 + 1 and String(night._lbl_status.text).contains("罐头 %d" % night.cans),
		"a change refreshes the HUD on the next frame", String(night._lbl_status.text))
	night._hud_tick(0.2)
	_assert(night.hud_full_refreshes == n0 + 2, "the HUD never stays stale longer than HUD_MAX_STALE")
	night.queue_free()
	await _frames(2)


# ---------------------------------------------------------------------------
# 9. 存档边界：空档位 / 结算页存档读回 / 读档后旧结果一律拒收
# ---------------------------------------------------------------------------
func _section_save_boundaries() -> void:
	print("-- save boundaries")
	var SG := root.get_node("SaveGame")
	var slot := 3
	SG.delete_save(slot)
	var fresh = SimScript.new()
	_assert(not SG.has_save(slot) and not SG.load_into(fresh, slot) and fresh.phase == "title",
		"an empty slot loads nothing and leaves the campaign untouched")
	var sim = _depart({"water": 1, "asp": 1, "band": 0, "can": 0})
	var res = _night_result(sim, "dawn", ["water", "asp", "scrap", "scrap"], -1.0, 0)
	sim.submit_raid_result(res)
	_assert(not SG.save(_depart({})) , "a save in the middle of a raid is refused")
	_assert(SG.save(sim, slot), "the report screen saves")
	var loaded = SimScript.new()
	_assert(SG.load_into(loaded, slot), "the report save loads back")
	_assert(str(loaded.stash) == str(sim.stash) or _same_counts(loaded.stash, sim.stash),
		"stash after reload equals the settled stash")
	_assert(loaded.day == sim.day and loaded.phase == "base", "reloading a report save lands in 602 on the same day",
		"%d %s" % [loaded.day, loaded.phase])
	_assert(is_equal_approx(loaded.conscience, sim.conscience) and loaded.tally == sim.tally,
		"conscience / tally survive the reload")
	var lost_n := 0
	for k in loaded.last_report.get("lost", {}):
		lost_n += int(loaded.last_report["lost"][k])
	_assert(lost_n == 2, "the left-behind list survives the save round trip", str(loaded.last_report.get("lost", {})))
	_assert(not loaded.has_open_raid() and loaded.submit_raid_result(res).is_empty()
		and loaded.last_rejection == "no_open_raid", "a pre-save result cannot settle into the reloaded campaign")
	SG.delete_save(slot)
	_bridge().clear()


func _same_counts(a: Dictionary, b: Dictionary) -> bool:
	for k in a.keys() + b.keys():
		if int(a.get(k, 0)) != int(b.get(k, 0)):
			return false
	return true


# ---------------------------------------------------------------------------
# 10. T04：节点化地点只建轻量当局容器；灰盒 RaidSim 夜里不写战役，结算时一次性入账
# ---------------------------------------------------------------------------
func _section_t04_deferred() -> void:
	print("-- T04 deferred writes")
	var node_sim = _depart({})
	_assert(node_sim.raid != null and node_sim.raid.get("is_attempt") == true and node_sim.greybox_raid() == null,
		"a node-scene departure builds only the light attempt container, not a greybox map")
	_bridge().clear()
	var sim = SimScript.new()
	sim.phase = "base"
	sim.force_greybox = true
	_assert(sim.depart(Data.loc(LOC)) and sim.greybox_raid() != null, "force_greybox still builds the greybox RaidSim")
	var R = sim.raid
	var c0: float = sim.conscience
	var t0: int = sim.tally
	var left0 := float(sim.node_state(LOC)["left"])
	var half = RaidSimScript.Ent.new()
	half.kind = "half"
	half.x = R.player.x
	half.y = R.player.y
	R.choice_ent = half
	R.choice_open = true
	R.set_choice(2)                      # A3：撬棍灭口 —— 良知 −10、卌 +1、betrayed
	R.node_left_delta = 0.3              # 夜里搜走的余量
	_assert(is_equal_approx(sim.conscience, c0) and sim.tally == t0 and not sim.flags.has("betrayed")
		and is_equal_approx(float(sim.node_state(LOC)["left"]), left0),
		"a greybox choice no longer writes the campaign mid-raid")
	R.finish("abort")
	sim.finish_raid("abort")
	_assert(is_equal_approx(sim.conscience, c0 - 10.0) and sim.tally == t0 + 1 and bool(sim.flags.get("betrayed", false)),
		"the deferred conscience / tally / flag land at settlement, even on abort")
	_assert(is_equal_approx(float(sim.node_state(LOC)["left"]), clampf(left0 - 0.3 - 0.5, 0.05, 1.0)),
		"searched-out node stock is applied before the per-visit drop")
	var snap := _snap(sim)
	_assert(sim.finish_raid("abort").is_empty() and str(_snap(sim)) == str(snap), "deferred writes are not applied twice")
	_bridge().clear()
