extends SceneTree
## Headless smoke test for the night-exploration art slice (scenes/night_explore.tscn).
## Run:  Godot_v4.7.2-stable_win64_console.exe --headless --path godot_project -s tests/night_explore_smoke.gd
##
## 覆盖：资产装配 / 节点接线 / 移动与碰撞 / 冻雪泥 / 噪声→调查 / 视线遮挡（车厢挡探照灯）/
##       搜刮掉落 / 车厢必出透析液 / 被清杀兵发现 / 撤离 / 体温 / 三方潜行（狂暴者、借刀杀人）/
##       回退半人的道德抉择（缺药 / 喂药 / 绕开 / 撬棍 / 清杀队误杀，良知与卌的口径）/
##       天亮最后 20% 的天色渐变（P1.5）/ 程序化音效与定位（P2.5）/ 镜头震动 /
##       战役 cfg 口径（pack_max · load · night · cold · sound_on）。

var passes: int = 0
var failures: Array[String] = []

const PPM := 64.0
const GY := 39.68

func _init() -> void:
	_run.call_deferred()

func _assert(cond: bool, n: String, detail: String = "") -> void:
	if cond:
		passes += 1
		print("  PASS  ", n)
	else:
		failures.append(n + ((" — " + detail) if detail != "" else ""))
		print("  FAIL  ", n, "  ", detail)

func _m(x: float, y: float) -> Vector2:
	return Vector2(x * PPM, y * GY)

func _scene() -> Node:
	for c in root.get_children():
		if c.name == "NightExplore":
			root.remove_child(c)
			c.free()
	var s: Node = (load("res://scenes/night_explore.tscn") as PackedScene).instantiate()
	root.add_child(s)
	return s

func _physics(n: int) -> void:
	# 游戏逻辑（update_dawn / _update_post / _apply_shake）在 _process（idle）里。
	# headless 下连续 await physics_frame 会在一个 idle 周期内追赶多个物理帧，
	# 可能 0 个 idle frame，故每个物理帧后显式等一个 idle frame。
	for i in n:
		await physics_frame
		await process_frame

func _release() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "crouch", "sprint", "interact"]:
		Input.action_release(a)

func _freeze_soldiers(s: Node) -> void:
	for o in s.soldiers:
		o.process_mode = Node.PROCESS_MODE_DISABLED
	for n in s.get_tree().get_nodes_in_group("night_searchlight"):
		n.process_mode = Node.PROCESS_MODE_DISABLED
	_freeze_rabids(s)

func _freeze_rabids(s: Node) -> void:
	for r in s.rabids:
		r.process_mode = Node.PROCESS_MODE_DISABLED

func _find(arr: Array, nm: String):
	for o in arr:
		if String(o.name) == nm:
			return o
	return null

func _run() -> void:
	print("== night_explore smoke ==")
	var s := _scene()
	await _physics(3)

	# --- 1. 资产装配 ---
	var sprites := s.find_children("*", "Sprite2D", true, false)
	var missing := 0
	for sp in sprites:
		if (sp as Sprite2D).texture == null:
			missing += 1
	_assert(sprites.size() >= 30 and missing == 0, "all Sprite2D have textures", "%d sprites, %d missing" % [sprites.size(), missing])
	var lights := s.find_children("*", "PointLight2D", true, false)
	_assert(lights.size() >= 15, "2D light rig present", str(lights.size()))
	var occ := s.find_children("*", "LightOccluder2D", true, false)
	_assert(occ.size() >= 8, "light occluders on props", str(occ.size()))
	_assert(s.get_node("Ground").texture.get_width() == 3072, "baked ground 3072px wide")
	_assert(FileAccess.file_exists("res://art/night_yard_manifest.json"), "art manifest exists")

	# --- 2. 接线 ---
	_assert(s.soldiers.size() == 2, "two OSK patrols wired", str(s.soldiers.size()))
	_assert(s.containers.size() >= 7, "searchable containers", str(s.containers.size()))
	_assert(s.slush.size() == 5, "slush zones", str(s.slush.size()))
	_assert(s.warm_lights.size() == 1, "brazier warm zone")
	_assert(s.state == "play", "starts in play")

	# --- 3. 移动 / 碰撞 ---
	_freeze_soldiers(s)
	var p = s.player
	var x0: float = p.global_position.x
	Input.action_press("move_right")
	await _physics(30)
	_release()
	_assert(p.global_position.x > x0 + 40.0, "player walks east", "%.1f -> %.1f" % [x0, p.global_position.x])
	Input.action_press("move_up")
	await _physics(60)
	_release()
	_assert(p.global_position.y >= 3.0 * GY - 2.0, "facade blocks walking north", "%.1f" % p.global_position.y)
	p.global_position = _m(17.5, 20.5)
	Input.action_press("move_down")
	await _physics(40)
	_release()
	_assert(p.global_position.y < 21.5 * GY, "fence blocks outside the gap", "%.1f" % p.global_position.y)
	p.global_position = _m(21.8, 20.5)
	Input.action_press("move_down")
	await _physics(70)
	_release()
	_assert(p.global_position.y > 21.6 * GY, "fence gap is passable", "%.1f" % p.global_position.y)

	# --- 4. 冻雪泥 ---
	_assert(s.is_slush(_m(17.0, 29.6)), "slush detected at zone center")
	_assert(not s.is_slush(_m(8.0, 6.0)), "no slush in clean yard")

	# --- 5. 噪声 → 调查 ---
	var osk = s.soldiers[0]
	osk.state = "patrol"
	s.emit_noise(osk.global_position + Vector2(200, 0), 9.0, "can")
	_assert(osk.state == "investigate", "can noise makes OSK investigate", osk.state)
	var far = s.soldiers[1]
	far.state = "patrol"
	s.emit_noise(_m(2.0, 38.0), 2.5, "step")
	_assert(far.state == "patrol", "quiet step far away is not heard", far.state)

	# --- 6. 视线 ---
	var sl: Node2D = s.get_tree().get_nodes_in_group("night_searchlight")[0]
	p.global_position = _m(38.0, 28.5)          # 两条轨道之间的开阔地
	p.crouching = false
	var ang := atan2((p.global_position.y - sl.global_position.y) / 0.62, p.global_position.x - sl.global_position.x)
	_assert(s.can_see_player(sl.global_position, 26.0, deg_to_rad(11.0), ang, true) > 0.0, "beam sees player in the open")
	p.global_position = _m(32.0, 36.0)          # 车厢南侧：光束从东北方来，被车厢挡住
	ang = atan2((p.global_position.y - sl.global_position.y) / 0.62, p.global_position.x - sl.global_position.x)
	var seen_behind: float = s.can_see_player(sl.global_position, 26.0, deg_to_rad(11.0), ang, true)
	_assert(seen_behind == 0.0, "boxcar blocks the searchlight", str(seen_behind))
	p.global_position = _m(18.0, 16.8)          # 蒸汽管北侧
	p.crouching = true
	var eye := _m(18.0, 19.5)
	var a2 := atan2((p.global_position.y - eye.y) / 0.62, p.global_position.x - eye.x)
	_assert(s.can_see_player(eye, 11.0, deg_to_rad(22.5), a2, false) == 0.0, "crouching behind steam pipe hides")
	p.crouching = false
	_assert(s.can_see_player(eye, 11.0, deg_to_rad(22.5), a2, false) > 0.0, "standing behind steam pipe is visible")

	# --- 7. 搜刮 ---
	var dump: Node2D = s.get_node("World/Props/Dumpster")
	p.global_position = dump.global_position + Vector2(0, 14)
	await _physics(2)
	Input.action_press("interact")
	await _physics(160)
	_release()
	_assert(bool(dump.get_meta("searched", false)), "dumpster searched after holding E")
	_assert(s.pack.size() >= 2, "loot added to bag (on top of the water flask)", str(s.pack))
	var box: Node2D = s.get_node("World/Props/Boxcar03")
	p.global_position = s.interact_point(box) + Vector2(0, 16)
	await _physics(2)
	Input.action_press("interact")
	await _physics(160)
	_release()
	_assert(s.pack.has("dial"), "boxcar No.3 always yields dialysis fluid", str(s.pack))

	# --- 8. 体温 ---
	var w0: float = s.warmth
	p.global_position = _m(30.0, 12.0)
	await _physics(60)
	_assert(s.warmth < w0, "warmth decays in the cold")
	var w1: float = s.warmth
	p.global_position = _m(24.0, 11.0)
	await _physics(60)
	_assert(s.warmth > w1, "brazier warms the player")

	# --- 9. 撤离 ---
	p.global_position = s.exit_px + Vector2(0, 20)
	await _physics(2)
	Input.action_press("interact")
	await _physics(130)
	_release()
	_assert(s.state == "extracted", "extract at boiler vent", s.state)

	# --- 10. 被发现 ---
	s = _scene()
	await _physics(3)
	_freeze_rabids(s)
	# 冻结的敌人节点仍在场景里，清杀兵的 _engage_rabids 会瞄准它们并提前 return，
	# 导致看不到玩家。这里把它们移到场景外，确保只测「手电发现玩家」这一条。
	for r in s.rabids + s.halfs:
		r.global_position = Vector2(-5000, -5000)
	var rail = s.soldiers[0]
	for o in s.soldiers:
		if String(o.name) == "OSK_Rail":
			rail = o
	rail.facing = 0.0
	rail.state = "pause"
	# 让清杀兵确定性地停在原地（pause 会扫视，故给足 timer 并把扫视中心锁定朝右），
	# 否则 timer=0 会立即转 patrol 走开，测试就依赖 headless 追赶时序而不稳定。
	rail.set("_look_base", 0.0)
	rail.set("_timer", 30.0)
	s.player.global_position = rail.global_position + Vector2(4.0 * PPM, 0)
	await _physics(300)
	_assert(s.state == "caught", "OSK flashlight catches a standing player", s.state)

	# --- 11. 三方潜行：狂暴者 ---
	s = _scene()
	await _physics(3)
	_assert(s.rabids.size() == 4, "four rabids wired", str(s.rabids.size()))
	var brute = _find(s.rabids, "Rabid_Brute")
	_assert(brute != null and brute.brute and brute.hp > 150.0, "brute variant is tougher")
	_freeze_soldiers(s)
	for r in s.rabids:
		r.process_mode = Node.PROCESS_MODE_INHERIT
	p = s.player
	p.global_position = s.exit_px + Vector2(0, 20)
	var rw = _find(s.rabids, "Rabid_West")
	s.emit_noise(rw.global_position + Vector2(160, 0), 9.0, "can")
	_assert(rw.state == "investigate", "rabid follows the can noise", rw.state)
	var rc = _find(s.rabids, "Rabid_Car")
	p.global_position = rc.global_position + Vector2(-4.0 * PPM, 0)
	p.crouching = false
	_assert(s.rabid_sees_player(rc), "rabid sees a player 4m away in the open")
	rc.global_position = _m(18.0, 19.0)
	p.global_position = _m(18.0, 16.6)
	p.crouching = true
	_assert(not s.rabid_sees_player(rc), "crouching behind the steam pipe hides from rabids")
	p.crouching = false
	_assert(s.rabid_sees_player(rc), "standing behind the steam pipe is seen by rabids")
	# 扑咬：0.45s 预警后掉血
	p.global_position = _m(30.0, 11.0)
	rc.global_position = p.global_position + Vector2(0.9 * PPM, 0)
	rc.state = "chase"
	var saw_windup := false
	for i in 90:
		await physics_frame
		if rc.state == "windup":
			saw_windup = true
	_assert(saw_windup, "rabid telegraphs a 0.45s windup before biting")
	_assert(s.hp < 100.0, "rabid bite damages the player", str(s.hp))

	# 借刀杀人：清杀兵光锥里的狂暴者会被击毙，枪声引来下一只
	s = _scene()
	await _physics(3)
	for n in s.get_tree().get_nodes_in_group("night_searchlight"):
		n.process_mode = Node.PROCESS_MODE_DISABLED
	var yard = _find(s.soldiers, "OSK_Yard")
	yard.process_mode = Node.PROCESS_MODE_DISABLED
	s.player.global_position = s.exit_px + Vector2(0, 20)
	var rs = _find(s.soldiers, "OSK_Rail")
	rs.global_position = _m(4.0, 29.6)
	rs.state = "pause"
	rs.set("_timer", 99.0)
	rs.set("_look_base", 0.0)
	rs.facing = 0.0
	var bait = _find(s.rabids, "Rabid_West")
	bait.global_position = rs.global_position + Vector2(6.0 * PPM, 0)
	bait.home = bait.global_position
	var tower = _find(s.rabids, "Rabid_Tower")
	for i in 200:
		await physics_frame
		await process_frame
		if not bait.is_alive():
			break
	_assert(not bait.is_alive(), "OSK shoots a rabid in its flashlight cone")
	_assert(s.borrowed == 1, "borrowed-knife kill is counted", str(s.borrowed))
	_assert(s.get_node("Decals").get_child_count() >= 1, "blood decal left on the snow")
	_assert(tower.state in ["investigate", "chase"], "gunshot draws the next rabid", tower.state)

	# 被扑倒
	s.damage_player(200.0, null)
	_assert(s.state == "downed", "player downed at 0 HP", s.state)

	# --- 12. 回退半人 · 道德抉择 ---
	s = _scene()
	await _physics(3)
	_freeze_soldiers(s)
	_assert(s.halfs.size() == 2, "two half-humans wired", str(s.halfs.size()))
	var h1 = _find(s.halfs, "Half_0388")
	var h2 = _find(s.halfs, "Half_0507")
	_assert(h1 != null and h1.get_node("Sprite").texture.resource_path.ends_with("CHR_04_HalfHuman_Sheet.png"),
		"half-human uses CHR_04 sheet")
	_assert(s.pack.has("water"), "Aleksei leaves with a hot-water flask", str(s.pack))
	var crate: Node2D = s.get_node("World/Props/CrateStack")
	_assert(String(crate.get_meta("guaranteed", "")) == "asp", "crate stack guarantees aspirin")
	p = s.player
	p.global_position = h1.global_position + Vector2(40, 0)
	_assert(s.nearest_half() == h1, "half-human is interactable up close")
	s.open_choice(h1)
	_assert(s.state == "choice", "E opens the choice and pauses the yard", s.state)
	_assert(not s.choose(0), "feeding without aspirin is refused")
	_assert(s.state == "choice" and s.choice_msg != "", "refusal keeps the panel open with a reason")
	s.pack.append("asp")
	_assert(s.choose(0), "feeding aspirin + hot water succeeds")
	_assert(s.state == "play" and h1.state == "saved", "half-human sleeps off the fever", h1.state)
	_assert(is_equal_approx(s.conscience, 7.0) and s.half_saved == 1, "conscience +7, one saved", str(s.conscience))
	_assert(not s.pack.has("asp") and not s.pack.has("water") and s.pack.has("intel"),
		"medicine consumed, got Old Ivan's slip", str(s.pack))
	_assert(s.nearest_half() == null, "a resolved half-human can't be chosen again")
	# 清杀兵认不出睡着的半人；但会打死被绕开的那个（误杀）
	var rs2 = _find(s.soldiers, "OSK_Rail")
	rs2.process_mode = Node.PROCESS_MODE_INHERIT
	rs2.global_position = h1.global_position + Vector2(-5.0 * PPM, 0)
	rs2.state = "pause"
	rs2.set("_timer", 99.0)
	rs2.set("_look_base", 0.0)
	rs2.facing = 0.0
	p.global_position = s.exit_px + Vector2(0, 20)
	await _physics(60)
	_assert(h1.is_alive(), "OSK doesn't shoot the saved half-human")
	p.global_position = h2.global_position + Vector2(40, 0)
	s.open_choice(h2)
	s.choose(1)
	_assert(h2.resolved == "left" and is_equal_approx(s.conscience, 5.0), "walking away costs 2 conscience",
		str(s.conscience))
	p.global_position = s.exit_px + Vector2(0, 20)
	h2.process_mode = Node.PROCESS_MODE_DISABLED
	rs2.global_position = h2.global_position + Vector2(-5.0 * PPM, 0)
	rs2.facing = 0.0
	var saw_warn := false
	for i in 120:
		await physics_frame
		if rs2.aim_target == h2:
			saw_warn = true
		if not h2.is_alive():
			break
	_assert(saw_warn, "OSK aims at the half-human (overlay warns before the shot)")
	_assert(not h2.is_alive() and s.half_lost == 1, "OSK mistakes the half-human for a rabid")
	_assert(is_equal_approx(s.conscience, 1.0), "the OSK kill costs 4 more conscience", str(s.conscience))
	_assert(s.tally == 0, "no tally stroke when you didn't swing the crowbar", str(s.tally))
	# 撬棍灭口
	s = _scene()
	await _physics(3)
	_freeze_soldiers(s)
	var h3 = _find(s.halfs, "Half_0388")
	s.player.global_position = h3.global_position + Vector2(40, 0)
	s.open_choice(h3)
	s.choose(2)
	_assert(not h3.is_alive() and s.tally == 1 and is_equal_approx(s.conscience, -10.0),
		"crowbar: tally +1, conscience −10", "%d %f" % [s.tally, s.conscience])
	_assert(s.half_lost == 0, "your own stroke isn't booked as an OSK misfire")
	# 罐头会把半人引过去；枪声会把他吓跑
	var h4 = _find(s.halfs, "Half_0507")
	s.emit_noise(h4.global_position + Vector2(200, 0), 9.0, "can")
	_assert(h4.state == "drift", "a thrown can lures the half-human too", h4.state)
	s.emit_noise(h4.global_position + Vector2(100, 0), 10.0, "gun")
	_assert(h4.state == "flinch", "gunfire makes the half-human flee", h4.state)
	var r5 = _find(s.rabids, "Rabid_Tower")
	var st5: String = r5.state
	s.emit_noise(r5.global_position + Vector2(30, 0), 3.0, "half")
	_assert(r5.state == st5, "rabids ignore half-human moans", r5.state)

	# --- 13. 天亮：夜长最后 20% 的天色渐变（P1.5）---
	s = _scene()
	await _physics(3)
	_freeze_soldiers(s)
	_assert(is_zero_approx(s.dawn_progress()), "no dawn clock when running the slice alone",
		str(s.dawn_progress()))
	s.in_campaign = true
	s.night_max = 100.0
	s.night_left = 100.0
	_assert(is_zero_approx(s.dawn_progress()), "the first 80% of the night stays dark")
	s.night_left = 21.0
	_assert(is_zero_approx(s.dawn_progress()), "still dark just above the 20% window")
	s.night_left = 10.0
	_assert(is_equal_approx(s.dawn_progress(), 0.5), "halfway through the last 20%",
		str(s.dawn_progress()))
	await _physics(2)
	_assert(s.dawn_cued, "the dawn cue (horn + hint) fires once")
	var mat: ShaderMaterial = s.post.material
	_assert(mat != null and float(mat.get_shader_parameter("dawn")) > 0.4,
		"post shader receives the dawn factor", str(mat.get_shader_parameter("dawn")))
	var cm: CanvasModulate = s.get_node("CanvasModulate")
	_assert(cm.color.r > 0.4, "CanvasModulate lifts from night blue toward dawn grey", str(cm.color))
	var snowp: GPUParticles2D = s.get_node("Camera2D/Snow")
	_assert(snowp.modulate.a < 1.0, "the blizzard thins out at dawn", str(snowp.modulate.a))
	_assert(is_equal_approx(float(mat.get_shader_parameter("frost")),
		clampf((35.0 - s.warmth) / 35.0, 0.0, 1.0)), "frost still follows body warmth")
	s.night_left = 0.05
	await _physics(8)
	_assert(s.state == "dawn", "the night ends on dawn", s.state)
	_assert(is_equal_approx(s.dawn_t, 1.0), "the sky is fully lit when dawn breaks", str(s.dawn_t))

	# --- 14. 声音（P2.5）：程序化音色库 / 定位 / 面具呼吸 / 环境层 / 心跳 ---
	s = _scene()
	await _physics(3)
	_assert(s.sfx != null and s.sfx.has_method("play_at") and s.sfx.has_method("attach_loop"),
		"NightSfx drives the scene audio")
	for nm in ["step_snow", "step_ice", "step_rail", "growl", "snarl", "bite", "moan",
			"mask_breath", "radio", "klaxon", "gunshot", "swing", "crowbar_hit", "rummage",
			"can_throw", "dawn_horn", "freeze", "chill", "heartbeat",
			"beep", "can", "wedge", "akm", "bonejam", "thirst"]:
		_assert(s.sfx.has_stream(nm), "synth bank has " + nm)
	_assert(s.sfx.stream_count() >= 25, "synth bank baked at startup", str(s.sfx.stream_count()))
	_assert(s.sfx.ambient_count() >= 3, "AMB_* layers handed to NightSfx", str(s.sfx.ambient_count()))
	var breath: Array = s.soldiers[0].find_children("*", "AudioStreamPlayer2D", true, false)
	_assert(breath.size() == 1, "every OSK trooper carries one breathing loop", str(breath.size()))
	_assert(breath[0].stream != null and is_equal_approx(breath[0].max_distance, 4.0 * 64.0),
		"mask breathing is audible inside 4 m", str(breath[0].max_distance))
	_assert(s.step_sound(_m(20.0, 8.0), false) == "step_snow", "packed snow in the yard")
	_assert(s.step_sound(_m(20.0, 26.4), false) == "step_rail", "sleepers and steel near the rail centre")
	_assert(s.step_sound(_m(17.0, 29.6), true) == "step_ice", "black ice cracks underfoot")
	var rip0: int = s.ripples.size()
	s.emit_noise(_m(20.0, 10.0), 9.0, "can")
	s.emit_noise(_m(20.0, 10.0), 3.0, "gun", true)
	_assert(s.ripples.size() == rip0 + 2, "quiet=true still draws the ripple (no double gunshot)",
		str(s.ripples.size()))
	_freeze_soldiers(s)
	var osk0 = s.soldiers[0]
	osk0.process_mode = Node.PROCESS_MODE_INHERIT
	osk0.state = "alert"
	osk0.suspicion = 1.0
	await _physics(2)
	_assert(s.sfx.tension > 0.9, "an alerted trooper drives the heartbeat", str(s.sfx.tension))
	osk0.state = "patrol"
	osk0.suspicion = 0.0
	await _physics(2)
	_assert(s.sfx.tension < 0.2, "the heartbeat stops when the yard is quiet again", str(s.sfx.tension))

	# --- 15. 镜头震动 ---
	s = _scene()
	await _physics(3)
	_freeze_soldiers(s)
	_assert(is_zero_approx(s.shake) and s.cam.offset == Vector2.ZERO, "the camera is still at rest")
	s.damage_player(9.0, null)
	_assert(s.shake > 0.4, "a bite kicks the camera", str(s.shake))
	_assert(s.punch > 0.5, "damage also punches the zoom in", str(s.punch))
	await _physics(2)
	_assert(s.cam.offset.length() > 0.5, "shake lands on Camera2D.offset", str(s.cam.offset))
	_assert(s.cam.zoom.x > 1.0, "the punch-in zooms slightly", str(s.cam.zoom))
	var k0: float = s.shake
	await _physics(90)
	_assert(s.shake < k0 * 0.2, "trauma decays", str(s.shake))
	_assert(s.cam.offset == Vector2.ZERO and is_zero_approx(s.cam.rotation)
		and is_equal_approx(s.cam.zoom.x, 1.0), "the camera recentres once the shake is gone",
		"%s %f" % [str(s.cam.offset), s.cam.zoom.x])
	var gs = s.soldiers[0]
	s.player.global_position = gs.global_position + Vector2(2.0 * PPM, 0)
	s.on_soldier_fired(gs, s.player.global_position)
	var near_shake: float = s.shake
	s.shake = 0.0
	s.player.global_position = gs.global_position + Vector2(24.0 * PPM, 0)
	s.on_soldier_fired(gs, s.player.global_position)
	_assert(near_shake > 0.3 and s.shake < near_shake * 0.5, "distant gunfire shakes less",
		"%f vs %f" % [s.shake, near_shake])

	# --- 16. 战役口径：cfg 读取 / cold / 静音跟随（P1.4 · P1.5 · P2.5）---
	# SceneTree 脚本不直接解析 autoload 全局名，动态取节点。
	var bridge := root.get_node_or_null("RaidBridge")
	bridge.begin(null, {"pack_max": 11, "day": 3, "cold": 1.5, "night": 216.0,
		"sound_on": false, "load": {"water": 1, "asp": 2, "band": 1, "can": 2}})
	s = _scene()
	# 初始夜长预算在 _ready 里设置、跑帧前精确等于 cfg.night（倒计时还没开始）。
	_assert(is_equal_approx(s.night_max, 216.0) and is_equal_approx(s.night_left, 216.0),
		"night budget from cfg.night", "%f/%f" % [s.night_max, s.night_left])
	await _physics(3)
	_assert(s.in_campaign, "RaidBridge.active puts the slice into campaign mode")
	_assert(s.bag_max == 11, "pack cap from cfg.pack_max", str(s.bag_max))
	_assert(s.day_n == 3, "HUD night counter from cfg.day", str(s.day_n))
	_assert(s.cans == 2, "tin cans from cfg.load.can", str(s.cans))
	_assert(s.pack.count("asp") == 2 and s.pack.count("water") == 1 and s.pack.count("band") == 1,
		"the loadout enters the pack", str(s.pack))
	_assert(is_equal_approx(s.cold, 1.5), "cold factor from cfg.cold", str(s.cold))
	_assert(is_equal_approx(s.sfx.cold, 1.5), "NightSfx gets the same cold factor (wind gain)")
	_assert(s.muted and AudioServer.is_bus_mute(0), "the campaign's mute follows you into the yard")
	_freeze_soldiers(s)
	s.player.global_position = _m(30.0, 12.0)
	var wc: float = s.warmth
	await _physics(60)
	var cold_loss: float = wc - s.warmth
	root.get_node("RaidBridge").clear()
	AudioServer.set_bus_mute(0, false)
	s = _scene()
	await _physics(3)
	_freeze_soldiers(s)
	_assert(not s.in_campaign and is_zero_approx(s.dawn_progress()), "F2 alone has no dawn clock")
	_assert(s.pack.has("water") and s.cans == 3 and s.bag_max == 8,
		"F2 alone keeps the greybox defaults", str(s.pack))
	s.player.global_position = _m(30.0, 12.0)
	var wb: float = s.warmth
	await _physics(60)
	var base_loss: float = wb - s.warmth
	_assert(cold_loss > base_loss * 1.3, "cfg.cold=1.5 burns body heat faster",
		"%f vs %f" % [cold_loss, base_loss])

	print("==== RESULT: %d passed, %d failed ====" % [passes, failures.size()])
	if failures.is_empty():
		print("NIGHT_EXPLORE_SMOKE_PASS")
		quit(0)
	else:
		for f in failures:
			print("  FAILED:", f)
		print("NIGHT_EXPLORE_SMOKE_FAIL")
		quit(1)
