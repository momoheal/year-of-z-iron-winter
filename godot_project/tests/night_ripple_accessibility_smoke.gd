extends SceneTree
## Headless smoke — 声纹可访问性冗余（FIX-P0-3）
##
## Run: Godot_v4.7.2-stable_win64 --headless --path godot_project -s tests/night_ripple_accessibility_smoke.gd
##
## 覆盖（全部是纯数据 / 设置读写 / 源码契约，不依赖帧循环、不触发 _draw）：
##   1) 六个色组各有一套线型 + 图标，六者互异；
##   2) 形状冗余默认常开（shape_always_on 恒 true），colorblind 只加粗 + 加标签；
##   3) 别名归一（step / hit / 未知 kind）与缺字段的 ripple 都不崩；
##   4) SaveGame 色觉辅助设置读写往返，且不覆盖已有音量设置、不动存档格式与 VERSION；
##   5) 源码契约：NightExplore.gd 的 ripple 带 kind、NightOverlay.gd 调用了冗余绘制；
##   6) night_explore.tscn 仍能实例化且挂着 NightOverlay 脚本（绘制分支可 parse）。
##
## 成功输出：RESULT: N passed, 0 failed

const RippleStyle := preload("res://scripts/night/NightRippleStyle.gd")
const OverlayScript := preload("res://scripts/night/NightOverlay.gd")
## 注意：不要在此 preload PauseMenu.gd —— 它第 44 行的 SaveGame 全局标识符在
## `-s` 脚本顶层的编译上下文里解析不到（autoload 尚未注册为编译期全局名），
## 会报 "Identifier not found: SaveGame" 并让本套件挂住。
## PauseMenu 的 headless 运行由既有 save_pause_smoke.gd（实例化真实菜单）覆盖。

var passes: int = 0
var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _assert(cond: bool, n: String, detail: String = "") -> void:
	if cond:
		passes += 1
		print("  PASS  ", n)
	else:
		failures.append(n + ((" — " + detail) if detail != "" else ""))
		print("  FAIL  ", n, "  ", detail)


func _src(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


func _walk(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		out.append(c)
		out.append_array(_walk(c))
	return out


func _run() -> void:
	print("==== Ripple accessibility smoke ====")

	# ---- 1. 六色组形状互异 -------------------------------------------------
	var groups: Array = RippleStyle.color_groups()
	_assert(groups.size() == 6, "恰好六个色组", str(groups.size()))
	var patterns: Array = []
	var glyphs: Array = []
	var labels: Array = []
	var tags: Array = []
	for k in groups:
		var st: Dictionary = RippleStyle.style_for(String(k))
		patterns.append(String(st["pattern"]))
		glyphs.append(String(st["glyph"]))
		labels.append(String(st["label"]))
		tags.append(String(st["tag"]))
	var uniq_p: Dictionary = {}
	var uniq_g: Dictionary = {}
	var uniq_l: Dictionary = {}
	var uniq_t: Dictionary = {}
	for p in patterns: uniq_p[p] = true
	for g in glyphs: uniq_g[g] = true
	for l in labels: uniq_l[l] = true
	for t in tags: uniq_t[t] = true
	_assert(uniq_p.size() == 6, "六种线型互异（灰度可辨第一重）", str(patterns))
	_assert(uniq_g.size() == 6, "六种中心图标互异（灰度可辨第二重）", str(glyphs))
	_assert(uniq_l.size() == 6, "六个单字标签互异", str(labels))
	_assert(uniq_t.size() == 6, "六个拉丁缩写互异（验收图用）", str(tags))

	# ---- 2. 形状冗余默认常开，colorblind 只是增强 --------------------------
	var always_on := true
	var cb_only_enhances := true
	for k in groups:
		var fake := {"pos": Vector2.ZERO, "r": 1.0, "col": Color.WHITE, "life": 1.0, "kind": String(k)}
		var off: Dictionary = RippleStyle.visual_for(fake, false)
		var on: Dictionary = RippleStyle.visual_for(fake, true)
		if not bool(off["shape_always_on"]) or not bool(on["shape_always_on"]):
			always_on = false
		if String(off["pattern"]) != String(on["pattern"]) or String(off["glyph"]) != String(on["glyph"]):
			cb_only_enhances = false
		if bool(off["show_label"]) or not bool(on["show_label"]):
			cb_only_enhances = false
		if float(on["width"]) <= float(off["width"]):
			cb_only_enhances = false
	_assert(always_on, "形状冗余无条件常开（不依赖设置开关）")
	_assert(cb_only_enhances, "色觉辅助只加粗/放大/加标签，不改线型与图标")

	# ---- 3. 别名归一与缺字段容错 -------------------------------------------
	_assert(RippleStyle.canonical("step") == "", "step 归一到默认灰白组")
	_assert(RippleStyle.canonical("hit") == "", "hit 归一到默认灰白组")
	_assert(RippleStyle.canonical("osk") == "gun", "osk 归一到冷蓝组")
	_assert(RippleStyle.canonical("nonexistent_kind") == "", "未知 kind 不崩，退回默认组")
	var no_kind := {"pos": Vector2.ZERO, "col": Color.WHITE}
	var v_no: Dictionary = RippleStyle.visual_for(no_kind, false)
	_assert(String(v_no["pattern"]) == "solid", "缺 kind 字段的旧 ripple 仍拿到默认形状")
	var legacy := {"pos": Vector2.ZERO, "r": 1.0, "col": Color.WHITE, "life": 1.0}
	_assert(not String(RippleStyle.visual_for(legacy, true)["label"]).is_empty(),
		"旧结构 ripple 在色觉辅助下也有标签")

	# ---- 4. 设置读写往返（测试隔离，不碰玩家真实 settings.cfg）--------------
	var SG := root.get_node("SaveGame")
	_assert(SG.VERSION == 1, "战役存档 VERSION 未变（仍为 1）", str(SG.VERSION))
	_assert(String(SG.SAVE_PATH) == "user://campaign_save.json", "存档路径/磁盘格式未变")
	var test_cfg := "user://ripple_accessibility_settings_test.cfg"
	SG.settings_path = test_cfg
	if FileAccess.file_exists(test_cfg):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_cfg))
	SG.master_volume = 0.73
	SG.colorblind_mode = false
	SG.save_settings()
	var c1 := ConfigFile.new()
	var load_ok := (c1.load(test_cfg) == OK)
	_assert(load_ok, "settings.cfg 可写可读")
	if load_ok:
		_assert(is_equal_approx(float(c1.get_value("audio", "master_volume", -1.0)), 0.73),
			"原有 audio/master_volume 仍在")
		_assert(c1.has_section("accessibility"), "新增 accessibility section")
		_assert(not bool(c1.get_value("accessibility", "colorblind_mode", true)),
			"默认关闭色觉辅助（但形状冗余仍常开）")
	SG.set_colorblind_mode(true)
	var c2 := ConfigFile.new()
	if c2.load(test_cfg) == OK:
		_assert(bool(c2.get_value("accessibility", "colorblind_mode", false)), "开启后落盘为 true")
		_assert(is_equal_approx(float(c2.get_value("audio", "master_volume", -1.0)), 0.73),
			"写色觉辅助不会抹掉音量设置")
	SG.colorblind_mode = false
	SG.load_settings()
	_assert(bool(SG.colorblind_mode), "load_settings 能读回色觉辅助")
	SG.set_colorblind_mode(false)
	_assert(not bool(SG.colorblind_mode), "可关闭，关闭后形状冗余仍由 visual_for 保证")
	if FileAccess.file_exists(test_cfg):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_cfg))
	SG.settings_path = ""

	# ---- 5. 源码契约（防后续合并丢字段 / 丢调用）----------------------------
	var ne := _src("res://scripts/night/NightExplore.gd")
	_assert(ne.contains("\"kind\": kind"), "NightExplore.gd:977 的 ripple 携带 kind")
	_assert(ne.contains("ripples.append({\"pos\": pos"), "emit_noise 仍在写 ripple（玩法数值未动）")
	var no := _src("res://scripts/night/NightOverlay.gd")
	_assert(no.contains("_draw_ripple_redundancy(r, rad, c)"), "NightOverlay 调用了冗余绘制分支")
	_assert(no.contains("func _ellipse_styled"), "NightOverlay 有六线型绘制函数")
	_assert(no.contains("func _glyph"), "NightOverlay 有六图标绘制函数")
	_assert(no.contains("0.85, 0.82, 0.75"), "冗余层用骨白高对比，不沿用暗红原色")

	# ---- 6. 场景 / 脚本可加载（绘制分支 headless 不崩）----------------------
	_assert(OverlayScript != null, "NightOverlay.gd 可 preload（语法通过）")
	var sc: Node = (load("res://scenes/night_explore.tscn") as PackedScene).instantiate()
	var has_overlay := false
	for n in _walk(sc):
		if n.get_script() == OverlayScript:
			has_overlay = true
	_assert(has_overlay, "night_explore.tscn 挂着 NightOverlay 脚本")
	sc.free()

	# 设置入口用源码契约断言（不 preload PauseMenu.gd，理由见文件头）。
	# 运行期不崩由既有 save_pause_smoke.gd 实例化真实菜单覆盖。
	var pm_src := _src("res://scripts/ui/PauseMenu.gd")
	_assert(pm_src.contains("_cb_colorblind"), "暂停菜单有色觉辅助勾选框")
	_assert(pm_src.contains("色觉辅助"), "勾选框文案可达")
	_assert(pm_src.contains("SaveGame.set_colorblind_mode"), "勾选框接到 SaveGame 设置")
	var sg_src := _src("res://autoload/SaveGame.gd")
	_assert(sg_src.contains("func set_colorblind_mode"), "SaveGame 有设置写入口")
	_assert(sg_src.contains('"accessibility", "colorblind_mode"'), "设置落在独立 section")

	print("==== RESULT: %d passed, %d failed ====" % [passes, failures.size()])
	for f in failures:
		print("   FAILED: ", f)
	# quit() 不终止函数执行 —— 分开写 "if 有失败: quit(1)" 再 quit(0)，
	# 后者会覆盖前者，退出码永远是 0，CI 的 rc 判断就成了摆设。用单表达式。
	quit(0 if failures.is_empty() else 1)
