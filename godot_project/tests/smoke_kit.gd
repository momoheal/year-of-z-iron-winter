extends SceneTree
## smoke_kit.gd — 冒烟测试的公共底座：通过 / 失败计数与断言。
##
## 用法：测试脚本第一行写 `extends "res://tests/smoke_kit.gd"`，直接用 passes / failures / _assert。
## 文件名不以 _smoke.gd 结尾，tools/run_tests.py 不会把它当成一套测试来跑。

var passes: int = 0
var failures: Array[String] = []


func _assert(cond: bool, name: String, detail: String = "") -> void:
	if cond:
		passes += 1
		print("  PASS  ", name)
	else:
		failures.append(name + ((" — " + detail) if detail != "" else ""))
		print("  FAIL  ", name, "  ", detail)
