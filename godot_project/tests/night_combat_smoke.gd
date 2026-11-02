extends SceneTree
## Headless smoke test for the combat slice (P5 / 撬棍与枪械).
## Run:  Godot_v4.7.2-stable_win64 --headless --path godot_project -s tests/night_combat_smoke.gd
##
## 三层覆盖：
##   1) 军械库：Arsenal 的表（四件家伙、近战/枪械、弹药换算）与美术资产是否都在。
##   2) 上场：开场拿了什么、切枪、装填、空仓、开枪扣弹 + 曳光 + 声纹 + 巡逻被惊动。
##   3) 命中：撬棍扇形打到狂暴者、枪械打死清杀兵（并触发「同僚倒下」）、
##      尸体不会再抓人；搜到弹药会补备弹。
##
## 全程直接调方法，不依赖帧循环 —— headless 里结果确定。

var passes: int = 0
var failures: Array[String] = []

const Arsenal := preload("res://scripts/night/Arsenal.gd")

var _s: Node = null


func _init() -> void:
	_run.call_deferred()


func _assert(cond: bool, n: String, detail: String = "") -> void:
	if cond:
		passes += 1
		print("  PASS  ", n)
	else:
		failures.append(n + ((" — " + detail) if detail != "" else ""))
		print("  FAIL  ", n, "  ", detail)


func _scene(path: String) -> Node:
	for c in root.get_children():
		if c.name == "NightExplore":
			root.remove_child(c)
			c.free()
	var s: Node = (load(path) as PackedScene).instantiate()
	root.add_child(s)
	return s


func _run() -> void:
	print("== night_combat_smoke ==")
	_arsenal()
	_yard()
	_melee()
	_guns()
	_soldier()
	_ammo()
	print("== RESULT: %d passed, %d failed ==" % [passes, failures.size()])
	for f in failures:
		print("   FAILED: ", f)
	if failures.size() > 0:
		quit(1)
	quit(0)


# ---------------------------------------------------------------------------
# 1) 军械库数据 + 资产
# ---------------------------------------------------------------------------
func _arsenal() -> void:
	print("[arsenal]")
	_assert(Arsenal.ORDER.size() == 4, "四件家伙", str(Arsenal.ORDER.size()))
	_assert(not Arsenal.is_gun("crowbar") and Arsenal.is_gun("pistol"), "撬棍近战 / 手枪枪械")
	_assert(Arsenal.is_gun("rifle") and Arsenal.is_gun("shotgun"), "步枪与双管都是枪械")
	_assert(Arsenal.spec("crowbar")["dmg"] == 34.0, "撬棍伤害与 CampaignData 对齐（34）")
	_assert(int(Arsenal.spec("pistol")["mag"]) == 8, "ТТ 弹匣 8 发")
	_assert(Arsenal.spec("shotgun")["pellets"] == 6, "双管一枪 6 颗弹丸")
	_assert(Arsenal.label("pistol", 5, 12).contains("5 / 12"), "弹量读数", Arsenal.label("pistol", 5, 12))
	_assert(not Arsenal.ammo_for("ammo").is_empty(), "步枪弹能换备弹")
	_assert(Arsenal.ammo_for("med").is_empty(), "药品不换弹药")
	# 美术资产必须都在（体素图缺了会静默变白框）
	for id in Arsenal.ORDER:
		var tex := String(Arsenal.spec(id)["tex"])
		_assert(ResourceLoader.exists(tex), "武器贴图存在：" + tex.get_file(), tex)
	for p in ["res://art/50_vfx/VFX_MuzzleFlash_Sheet.png", "res://art/50_vfx/VFX_Bullet_Tracer.png",
			"res://art/50_vfx/VFX_Impact_Spark.png", "res://art/50_vfx/VFX_Shell_Casing.png",
			"res://art/50_vfx/VFX_Blood_Mist.png"]:
		_assert(ResourceLoader.exists(p), "战斗 VFX 存在：" + p.get_file(), p)


# ---------------------------------------------------------------------------
# 2) 上场：装备 / 切枪 / 装填
# ---------------------------------------------------------------------------
func _yard() -> void:
	print("[loadout]")
	_s = _scene("res://scenes/night_explore.tscn")
	var s = _s
	_assert(s.weapons.has("crowbar"), "撬棍永远在手上")
	_assert(s.weapons.size() >= 2, "F2 独立跑至少带一支枪", str(s.weapons))
	_assert(s.weapon == "pistol", "开局默认掏枪（手枪优先）", s.weapon)
	_assert(s.get_node_or_null("World/Player/Weapon") != null, "手里的家伙建出来了")
	_assert(s.get_node_or_null("World/Player/MuzzleFlash") != null, "枪口焰精灵建出来了")
	_assert(s.get_node_or_null("World/Player/MuzzleLight") != null, "枪口补光建出来了")

	# 切到撬棍再切回来
	s.swap_weapon(0)
	_assert(s.weapon == "crowbar" and not s.cur_is_gun(), "1 号槽 = 撬棍（近战）")
	s.swap_weapon(1)
	_assert(s.weapon == "pistol", "2 号槽 = ТТ-33")
	s.swap_weapon(3)
	_assert(s.weapon == "pistol", "没到手的枪切不过去")

	# 装填：先打掉两发
	s.mag["pistol"] = 6
	var before := int(s.reserve["pistol"])
	s.start_reload()
	_assert(s.reload_left > 0.0, "开始装填")
	s.reload_left = 0.001
	s._update_combat(0.01)
	_assert(int(s.mag["pistol"]) == 8, "弹匣装满 8 发", str(s.mag["pistol"]))
	_assert(int(s.reserve["pistol"]) == before - 2, "备弹按实际补进去", str(s.reserve["pistol"]))


# ---------------------------------------------------------------------------
# 3) 撬棍：扇形近战
# ---------------------------------------------------------------------------
func _melee() -> void:
	print("[melee]")
	var s = _s
	s.swap_weapon(0)
	# 把一只狂暴者拉到面前（朝向 +x）
	var r = s.rabids[0]
	s.player.global_position = Vector2(3000, 2000)
	s.player.facing = 0.0
	r.global_position = s.player.global_position + Vector2(70, 0)     # 约 1.1m
	var hp0: float = r.hp
	s.cool = 0.0
	s.melee_swing()
	_assert(r.hp < hp0, "撬棍打中正前方的狂暴者", "%.0f -> %.0f" % [hp0, r.hp])
	_assert(s.hit_marks.size() >= 1, "出现命中标记")
	_assert(s.ripples.size() >= 1, "挥击有声纹（轻）")

	# 背后的目标打不到
	var r2 = s.rabids[1]
	r2.global_position = s.player.global_position - Vector2(70, 0)
	var hp2: float = r2.hp
	s.cool = 0.0
	s.melee_swing()
	_assert(is_equal_approx(r2.hp, hp2), "背后的目标吃不到棍子")

	# 三下打死（34 × 3 > 100）
	s.player.global_position = Vector2(3000, 2000)
	r.global_position = s.player.global_position + Vector2(60, 0)
	r.hp = 30.0
	s.cool = 0.0
	s.melee_swing()
	_assert(not r.is_alive(), "最后一棍放倒狂暴者")


# ---------------------------------------------------------------------------
# 4) 枪械：扣弹 / 曳光 / 声纹 / 惊动巡逻
# ---------------------------------------------------------------------------
func _guns() -> void:
	print("[guns]")
	var s = _s
	s.swap_weapon(1)
	# 站回出生点，把一个清杀兵摆在 3m 开外（枪口正对着他）
	s.player.global_position = s.get_node("Markers/Spawn").global_position
	s.player.facing = 0.0
	var dummy = s.soldiers[0]
	dummy.global_position = s.player.global_position + Vector2(200, 0)
	dummy.state = "patrol"
	dummy.hp = 100.0
	s.mag["pistol"] = 8
	s.cool = 0.0
	var rip0: int = s.ripples.size()
	s.shoot()
	_assert(dummy.hp < 100.0, "子弹打中了正前方的清杀兵", "%.0f" % dummy.hp)
	_assert(int(s.mag["pistol"]) == 7, "开枪扣一发", str(s.mag["pistol"]))
	_assert(s.tracers.size() >= 1, "画了曳光")
	_assert(s.ripples.size() > rip0, "枪声有 26m 的声纹")
	_assert(s.muzzle_t > 0.0, "枪口焰点亮")
	var alerted := 0
	for sol in s.soldiers:
		if sol.state == "alert":
			alerted += 1
	_assert(alerted >= 1, "枪声把巡逻惊动了", str(alerted))

	# 连射间隔：冷却没走完不许再开
	var mag_now := int(s.mag["pistol"])
	s.shoot()
	_assert(int(s.mag["pistol"]) == mag_now, "冷却中开不出第二枪")
	s.cool = 0.0
	s.shoot()
	_assert(int(s.mag["pistol"]) == mag_now - 1, "冷却走完能继续开")

	# 空仓：自动转装填
	s.mag["pistol"] = 0
	s.cool = 0.0
	s.shoot()
	_assert(s.reload_left > 0.0 and int(s.mag["pistol"]) == 0, "空仓自动装填")

	# 步枪：一枪 96，能一枪打死清杀兵
	s.swap_weapon(2)
	_assert(s.weapon == "rifle", "3 号槽 = 莫辛纳甘")
	_assert(int(s.mag["rifle"]) == 5, "莫辛 5 发", str(s.mag["rifle"]))
	_assert(float(Arsenal.spec("rifle")["dmg"]) >= 96.0, "莫辛一枪 96 点")


# ---------------------------------------------------------------------------
# 5) 清杀兵：中弹 → 死亡 → 不再抓人
# ---------------------------------------------------------------------------
func _soldier() -> void:
	print("[soldier]")
	var s = _s
	s.player.global_position = s.get_node("Markers/Spawn").global_position
	var sol = s.soldiers[0]
	sol.global_position = s.player.global_position + Vector2(260, 0)
	sol.state = "patrol"
	sol.hp = 100.0
	var hp0: float = sol.hp
	sol.hit(40.0, "player")
	_assert(sol.hp < hp0, "清杀兵会掉血", "%.0f" % sol.hp)
	_assert(sol.state == "alert", "中弹立刻转警戒（他知道你在哪）")
	sol.hit(200.0, "player")
	_assert(not sol.is_alive(), "血打空就是尸体")
	_assert(s.soldier_kills >= 1, "战果记在档案上", str(s.soldier_kills))
	_assert(s.conscience < 0.0, "打死清杀兵要记良知账", str(s.conscience))
	var others := 0
	for o in s.soldiers:
		if o != sol and o.is_alive() and o.state == "alert":
			others += 1
	_assert(others >= 1, "同僚倒下，附近的人压过来", str(others))
	# 尸体不会再抓人
	s.state = "play"
	sol._physics_process(0.016)
	_assert(s.state == "play", "尸体不会再触发被发现")


# ---------------------------------------------------------------------------
# 6) 弹药补给
# ---------------------------------------------------------------------------
func _ammo() -> void:
	print("[ammo]")
	var s = _s
	s.reserve["pistol"] = 0
	s.reserve["rifle"] = 0
	s.ammo_from_item("ammo")
	_assert(int(s.reserve["pistol"]) > 0, "搜到步枪弹 → 手枪也分到几发", str(s.reserve["pistol"]))
	_assert(int(s.reserve["rifle"]) > 0, "步枪弹补进步枪", str(s.reserve["rifle"]))
	var cap: int = int(Arsenal.spec("pistol")["reserve_max"])
	s.reserve["pistol"] = cap
	s.ammo_from_item("ammo")
	_assert(int(s.reserve["pistol"]) == cap, "备弹不会超过上限", str(s.reserve["pistol"]))
	# 关口：搜刮回来会把弹药接上（不重复加物品）
	var before := int(s.reserve["rifle"])
	s.ammo_from_item("bolt")
	_assert(int(s.reserve["rifle"]) >= before, "枪机也能拆出子弹")
