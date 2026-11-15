extends SceneTree
## Headless smoke test — 夜谈立绘情绪契约（角色重绘期间的防回归闸门）。
## Run: Godot_v4.7.2-stable_win64 --headless --path godot_project -s tests/night_portraits_smoke.gd
##
## 守的是 NightMonuments.portrait_path() 的静默回退：
##   找 PRT_<人>_<表情>.png，找不到（或没导入）就退回 PRT_<人>_Calm.png。
##   回退本身是好设计 —— 少一张图不至于让夜谈崩掉。代价是：整套「冷嘲」立绘
##   可以悄悄消失，没有任何测试会红，只是所有人的表情都变成一副面孔。
##
## 所以本测试把这份契约钉死：
##   1) SPEAKERS × MOOD_ZH 全矩阵都必须落到真实存在的文件；
##   2) 非 calm 表情不得落回 Calm 兜底 —— 落回就等于该表情的图丢了；
##   3) 剧本里出现的每一个 mood 都必须是 MOOD_ZH 声明过的键（防拼写漂移）；
##   4) 未知说话人退回主角，不返回空路径（防止头像框直接空白）。
##
## 为什么每条都要查两遍（ResourceLoader.exists + FileAccess.file_exists）：
##   ResourceLoader.exists() 认的是 .godot/imported 里的导入缓存，源 PNG 被删掉、
##   改名或漏提交之后它照样返回 true（实测）。只信它，测试就会在资产已经缺失时
##   亮绿灯，等于一块橡皮图章。FileAccess.file_exists() 查的是源文件在不在，
##   两个都过才算这张图真的可用。
##
## 注意与 story_emotions_smoke.gd 的分工：那边测的是 CampaignHUD 的预加载
## 表（calm/sad/intense 三档，全量 preload）；这边测的是夜谈的模板拼接路径
## （四档，含 wry）。两套表不是同一个来源，必须各自有人守。

const NightMonuments := preload("res://scripts/night/NightMonuments.gd")

const PRT_DIR := "res://art/10_characters/portraits/"

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


func _run() -> void:
	print("== night_portraits_smoke ==")
	_script_moods_are_declared()
	_matrix_resolves()
	_unknown_speaker_falls_back()
	print("== RESULT: %d passed, %d failed ==" % [passes, failures.size()])
	for f in failures:
		print("   FAILED: ", f)
	# quit() 不终止函数执行 —— 分开写 "if 有失败: quit(1)" 再 quit(0)，
	# 后者会覆盖前者，退出码永远是 0，CI 的 rc 判断就成了摆设。用单表达式。
	quit(0 if failures.is_empty() else 1)


# ---------------------------------------------------------------------------
# 1) 剧本里的表情标签必须都在 MOOD_ZH 里声明过。
#    写错一个字母（"wyr" / "Wry" / "wry "）不会报错，只会安静地退成平静，
#    台词的情绪就没了 —— 这类漂移只能靠比对两张表发现。
# ---------------------------------------------------------------------------
func _script_moods_are_declared() -> void:
	print("[script moods ⊆ MOOD_ZH]")
	var bad: Array[String] = []
	var used: Dictionary = {}
	var kinds := 0
	for table in [NightMonuments.KINDS, NightMonuments.POSTERS, NightMonuments.PROPS]:
		for kind in table.keys():
			var info: Dictionary = table[kind]
			if not (info is Dictionary):
				continue
			var lines: Dictionary = info.get("lines", {})
			if lines.is_empty():
				continue
			kinds += 1
			for who in lines.keys():
				var row: Array = lines[who]
				if row.size() < 2:
					continue
				var mood := String(row[0])
				used[mood] = int(used.get(mood, 0)) + 1
				if not NightMonuments.MOOD_ZH.has(mood):
					bad.append("%s/%s → \"%s\"" % [String(kind), String(who), mood])
	_assert(bad.is_empty(),
		"剧本里 %d 个条目、%d 种表情标签都在 MOOD_ZH 里声明过" % [kinds, used.size()],
		str(bad))
	var never: Array[String] = []
	for m in NightMonuments.MOOD_ZH.keys():
		if not used.has(m):
			never.append(String(m))
	_assert(never.is_empty(), "MOOD_ZH 声明的表情都真的被剧本用到（没有空档）", str(never))
	print("  [info] 台词表情分布：", _fmt(used))


# ---------------------------------------------------------------------------
# 2) SPEAKERS × MOOD_ZH 全矩阵：每格都要有真实存在的 PNG，且不得是 Calm 兜底。
# ---------------------------------------------------------------------------
func _matrix_resolves() -> void:
	print("[speakers × moods]")
	var fallback: Array[String] = []
	var checked := 0
	for who in NightMonuments.SPEAKERS.keys():
		var who_name := String(NightMonuments.SPEAKERS[who].get("prt", ""))
		if who_name == "":
			_assert(false, "说话人 %s 配了立绘名" % String(who), "prt 字段为空")
			continue
		var calm_path := PRT_DIR + "PRT_%s_Calm.png" % who_name
		for mood in NightMonuments.MOOD_ZH.keys():
			var p: String = NightMonuments.portrait_path(String(who), String(mood))
			checked += 1
			if not FileAccess.file_exists(p):
				_assert(false, "%s / %s 的源图在磁盘上" % [String(who), String(mood)],
					"文件缺失（导入缓存可能仍在，别被 ResourceLoader 骗了）：%s" % p)
				continue
			if not ResourceLoader.exists(p):
				_assert(false, "%s / %s 的立绘可被运行时加载" % [String(who), String(mood)],
					"文件在但没导入：%s" % p)
				continue
			if String(mood) != "calm" and p == calm_path:
				fallback.append("%s/%s" % [String(who), String(mood)])
	_assert(fallback.is_empty(),
		"%d 个（说话人 × 表情）组合全部有专属立绘，无静默退化" % checked,
		"以下表情掉回 Calm 兜底：%s" % str(fallback))


# ---------------------------------------------------------------------------
# 3) 未知说话人退回主角，不返回空路径 —— 否则头像框会直接开天窗。
# ---------------------------------------------------------------------------
func _unknown_speaker_falls_back() -> void:
	print("[unknown speaker]")
	var p: String = NightMonuments.portrait_path("nobody_here", "calm")
	_assert(p == PRT_DIR + "PRT_Aleksei_Calm.png",
		"未知说话人退回主角平静立绘", "实际 %s" % p)
	_assert(FileAccess.file_exists(p), "退回的立绘源图在磁盘上", p)
	_assert(ResourceLoader.exists(p), "退回的立绘可被运行时加载", p)


func _fmt(d: Dictionary) -> String:
	var ks: Array = d.keys()
	ks.sort()
	var parts: Array[String] = []
	for k in ks:
		parts.append("%s=%d" % [String(k), int(d[k])])
	return "  ".join(parts)
