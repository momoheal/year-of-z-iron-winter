extends SceneTree
## 地面贴花层 smoke（headless）。
## 覆盖：地面变换矩阵的正确性（det ≡ SQ、θ=90° 的轴向）/ add_decal 的挂载与灯掩码 /
##       marks·tracks 双池容量与隔离 / 脚印左右交替与落点 / 走路真的踩出印子 /
##       血泊尺寸档位 / 弹孔材质选择 / _ray_stop 的"打空"标志与打空不留孔。
##
## 为什么专门盯变换矩阵：贴花用的是 diag(1, SQ)·R(θ)，
## 写成 sprite.rotation + sprite.scale.y 会在 θ=90° 时把压缩轴转到 X 上 ——
## 结果是任何一张贴花在南北向都会胖一倍。这里用 det 恒定 + 轴向断言把这个坑钉死。
##
## Run: Godot --headless --path godot_project -s tests/night_decals_smoke.gd

const SQ := 0.62
const PPM := 64.0
const GY := PPM * SQ
# 容量在这里写成字面量：测试是用来钉住契约的，跟着实现走就没意义了
const MARKS_CAP := 48
const TRACKS_CAP := 64
const BLOOD_KEYS := ["blood_s", "blood_m", "blood_l", "blood_trail"]

var passes: int = 0
var failures: Array[String] = []


func _init() -> void:
	_guard.call_deferred()
	_run.call_deferred()


## 看门狗：协程里一旦抛脚本错误，_run 会静默死掉、quit() 永远不执行，
## Godot 就会空转到 CI 超时才被杀（日志里什么都看不到）。有这个至少能拿到退出码 1。
func _guard() -> void:
	await create_timer(150.0).timeout
	printerr("!! night_decals_smoke watchdog timeout — _run 协程多半已经因脚本错误中断")
	quit(1)


func _assert(cond: bool, n: String, detail: String = "") -> void:
	if cond:
		passes += 1
		print("  PASS  ", n)
	else:
		failures.append(n + ((" — " + detail) if detail != "" else ""))
		print("  FAIL  ", n, "  ", detail)


func _scene() -> Node:
	for c in root.get_children():
		if c.name == "NightExplore":
			root.remove_child(c)
			c.free()
	var s: Node = (load("res://scenes/night_explore.tscn") as PackedScene).instantiate()
	root.add_child(s)
	return s


func _physics(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame


func _m(x: float, y: float) -> Vector2:
	return Vector2(x * PPM, y * GY)


func _run() -> void:
	print("== night decals smoke ==")
	var s := _scene()
	await _physics(3)
	_assert(s.state == "play", "starts in play")

	# ---------------------------------------------------------------- 1. 变换矩阵
	var near := 1e-4
	for deg in [0.0, 30.0, 45.0, 90.0, 180.0, 225.0]:
		var t: Transform2D = s._ground_transform(deg_to_rad(deg), Vector2.ZERO)
		_assert(absf(t.determinant() - SQ) < near, "det == SQ at %d°" % int(deg),
			"det=%.6f" % t.determinant())
	var t0: Transform2D = s._ground_transform(0.0, Vector2.ZERO)
	_assert(t0.x.length() > 0.999 and t0.y.length() < 0.621,
		"θ=0 keeps X un-squashed, squashes Y", "|x|=%.4f |y|=%.4f" % [t0.x.length(), t0.y.length()])
	var t90: Transform2D = s._ground_transform(PI * 0.5, Vector2.ZERO)
	_assert(absf(t90.x.x) < near and absf(t90.x.y - SQ) < near,
		"θ=90° maps local +X to (0, +SQ) — the squash follows the print", str(t90.x))
	var t45: Transform2D = s._ground_transform(PI * 0.25, Vector2.ZERO)
	_assert(absf(t45.x.length() - t45.y.length()) < near,
		"θ=45° has equal axis lengths (0.832 each) — squat is isotropic here",
		"|x|=%.4f |y|=%.4f" % [t45.x.length(), t45.y.length()])

	# ---------------------------------------------------------------- 2. add_decal
	var decals := s.get_node("Decals")
	var at := _m(20.0, 12.0)
	var d: Sprite2D = s.add_decal("blood_m", at, 0.5, "marks")
	_assert(d != null and d.get_parent() == decals, "add_decal parents into $Decals")
	_assert(d.light_mask == 2, "decal light_mask = 2 (matches Ground)", str(d.light_mask))
	_assert(absf(d.transform.determinant() - SQ) < near, "decal transform carries the ground squash")
	_assert(absf(d.global_position.x - at.x) < 0.01, "decal sits on the given x", "%.2f" % d.global_position.x)
	_assert(s.add_decal("no_such_key", at) == null, "unknown key returns null")
	var n_before := decals.get_child_count()
	s.add_decal("no_such_key", at)
	_assert(decals.get_child_count() == n_before, "unknown key adds nothing")

	# ---------------------------------------------------------------- 3. 双池
	var s2 := _scene()
	await _physics(2)
	for i in 60:
		s2.add_decal("blood_s", _m(10.0 + i * 0.05, 12.0), 0.0, "marks")
	_assert(s2._marks.size() == MARKS_CAP, "marks pool capped",
		"%d / %d" % [s2._marks.size(), MARKS_CAP])
	var marks_alive := 0
	for sp in s2._marks:
		if is_instance_valid(sp):
			marks_alive += 1
	_assert(marks_alive == MARKS_CAP, "marks entries stay valid", str(marks_alive))

	var marks_before: int = s2._marks.size()
	for i in 90:
		s2.footprint(_m(10.0, 12.0 + i * 0.02), 0.0)
	_assert(s2._tracks.size() == TRACKS_CAP, "tracks pool capped",
		"%d / %d" % [s2._tracks.size(), TRACKS_CAP])
	_assert(s2._marks.size() == marks_before,
		"footprints never evict blood marks", "%d -> %d" % [marks_before, s2._marks.size()])

	# 复现长时间夜潜：旧脚印自然褪去，再继续走到容量上限。
	var expired: Sprite2D = s2.add_decal("paw", at, 0.0, "tracks", 0.05)
	await create_timer(0.15).timeout
	_assert(not is_instance_valid(expired) and s2._tracks.size() == TRACKS_CAP - 1,
		"faded footprint leaves the pool")
	for i in range(TRACKS_CAP + 1):
		var track: Sprite2D = s2.footprint(at + Vector2(i, 0), 0.0)
		if not is_instance_valid(track):
			_assert(false, "footprints continue after a faded entry reaches the head of the pool")
			break
	_assert(s2._tracks.size() == TRACKS_CAP, "tracks stay capped after fading and adding more prints")

	# ---------------------------------------------------------------- 4. 脚印
	var s3 := _scene()
	await _physics(2)
	var base := _m(20.0, 12.0)
	var a: Sprite2D = s3.footprint(base, 0.0)
	var b: Sprite2D = s3.footprint(base, 0.0)
	_assert(a.texture.resource_path.ends_with("Boot_L.png") or a.texture.resource_path.ends_with("Boot_R.png"),
		"boot print uses a boot texture", a.texture.resource_path)
	_assert(a.texture != b.texture, "consecutive prints alternate left / right",
		"%s vs %s" % [a.texture.resource_path.get_file(), b.texture.resource_path.get_file()])
	# 所有贴花都会统一抬高 4 px（压在脚下而不是长在小腿上），比较位移时要扣掉
	var lift := Vector2(0, -4)
	var off_a: Vector2 = a.global_position - base - lift
	var lateral := absf(off_a.y) / GY
	_assert(lateral > 0.05 and lateral < 0.30,
		"print is offset to the side of the foot (not dead centre)", "%.2f m" % lateral)
	_assert(absf(off_a.x) < 0.01, "lateral offset is purely sideways at angle 0", str(off_a))
	var paw: Sprite2D = s3.footprint(base, 0.0, "paw")
	_assert(paw.texture.resource_path.ends_with("Footprint_Paw.png"), "paw kind uses the paw texture")
	_assert((paw.global_position - base - lift).length() < 0.01, "paw print is not offset laterally",
		str(paw.global_position - base - lift))

	# ---------------------------------------------------------------- 5. 走路真的踩出来
	var s4 := _scene()
	await _physics(3)
	for so in s4.soldiers:
		so.ctl = null
	for r in s4.rabids:
		r.ctl = null
	var t_before: int = s4._tracks.size()
	Input.action_press("move_right")
	await _physics(34)
	Input.action_release("move_right")
	await _physics(2)
	var walked: int = s4._tracks.size() - t_before
	# 走 2.6 m/s、步距 0.45 s ≈ 1.17 m：34 帧（0.57 s）应该踩出 2 个
	_assert(walked >= 2, "walking leaves prints on the ground", "%d prints in 34 frames" % walked)

	# ---------------------------------------------------------------- 6. 血泊与弹孔
	var s5 := _scene()
	await _physics(2)
	var m0: int = s5._marks.size()
	s5._splat(_m(20.0, 12.0), "l")
	_assert(s5._marks.size() > m0, "kill spawns a blood pool decal")
	var keys_ok := true
	for k in BLOOD_KEYS:
		if s5.add_decal(k, _m(10.0, 10.0)) == null:
			keys_ok = false
	_assert(keys_ok, "all blood / trail keys resolve", str(BLOOD_KEYS))

	# 材质：有 meta 就听 meta 的，没有就掷骰且必落在三种之内
	var body := StaticBody2D.new()
	body.set_meta("surface", "metal")
	s5.add_child(body)
	_assert(s5._bullet_key(body) == "bullet_metal", "collider meta 'surface' wins")
	body.set_meta("surface", "nonsense")
	var seen := {}
	for i in 200:
		seen[s5._bullet_key(body)] = true
	_assert(seen.size() >= 2, "unknown surface falls back to a roll", str(seen.keys()))
	var seen_bare := {}
	for i in 200:
		seen_bare[s5._bullet_key(null)] = true
	_assert(seen_bare.size() == 3, "bare collider rolls snow / wood / metal", str(seen_bare.keys()))

	# ---------------------------------------------------------------- 7. _ray_stop 的 hit 标志
	# 挪到地图外，免得打到角色 / 场景里的墙
	var off := Vector2(-6000, -6000)
	var far: Dictionary = s5._ray_stop(off, Vector2(-1, 0), 3.0)
	_assert(far.has("hit") and far.has("pos") and far.has("col"),
		"_ray_stop returns {pos, hit, col}", str(far.keys()))
	_assert(far["hit"] == false, "empty space reports hit = false")

	# 往正上方戳一个实体，应当命中
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(240, 160)
	cs.shape = rect
	wall.add_child(cs)
	wall.global_position = off + Vector2(0, -100)
	s5.add_child(wall)
	await _physics(2)
	var hit: Dictionary = s5._ray_stop(off, Vector2(0, -1), 4.0)
	_assert(hit["hit"] == true, "solid wall reports hit = true", str(hit["pos"]))
	_assert(hit["col"] == wall, "_ray_stop returns the collider so the hole can pick a material")

	# 打空不留孔
	var n1: int = s5._marks.size()
	s5._cast_shot(off, Vector2(-1, 0), 6.0, 30.0)
	_assert(s5._marks.size() == n1, "a shot into thin air leaves no bullet hole",
		"%d -> %d" % [n1, s5._marks.size()])
	# 打到东西就留孔
	var n2: int = s5._marks.size()
	s5._cast_shot(off, Vector2(0, -1), 4.0, 30.0)
	_assert(s5._marks.size() == n2 + 1, "a shot into a wall leaves one hole",
		"%d -> %d" % [n2, s5._marks.size()])

	print("== night decals: %d passed / %d failed ==" % [passes, failures.size()])
	for f in failures:
		print("  !! ", f)
	# run_tests.py 只认这两种汇总行之一，少一行整套就会被当成 0 通过
	print("RESULT: %d passed, %d failed" % [passes, failures.size()])
	quit(0 if failures.is_empty() else 1)
