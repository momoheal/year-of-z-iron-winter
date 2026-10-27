class_name EventCatalog
extends RefCounted
## EventCatalog.gd — 扫描并索引所有 EventData .tres。
##
## 内容全部来自 res://data/events/ 下的资源文件，
## 新增 / 删除一个 .tres 即自动纳入，无需改本脚本。

const EVENTS_DIR := "res://data/events/"

var _by_id: Dictionary = {}
var _all: Array[EventData] = []

func load_all() -> void:
	_by_id.clear()
	_all.clear()
	var dir := DirAccess.open(EVENTS_DIR)
	if dir == null:
		push_warning("EventCatalog: cannot open " + EVENTS_DIR)
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var ev = load(EVENTS_DIR + fname)
			if ev is EventData and ev.id != "":
				_all.append(ev)
				_by_id[ev.id] = ev
		fname = dir.get_next()
	dir.list_dir_end()

func count() -> int:
	return _all.size()

func get_event(event_id: String) -> EventData:
	return _by_id.get(event_id)

func all_events() -> Array[EventData]:
	return _all

func events_for_phase(phase: String) -> Array[EventData]:
	var out: Array[EventData] = []
	for ev in _all:
		if ev.phase == "any" or ev.phase == phase:
			out.append(ev)
	return out

## 按 trigger_chance 先过滤、再按 weight 加权随机抽取。
func roll_event(phase: String, rng: RandomNumberGenerator) -> EventData:
	var pool := events_for_phase(phase)
	var weighted: Array = []
	var total := 0
	for ev in pool:
		if rng.randf() <= ev.trigger_chance:
			total += max(1, ev.weight)
			weighted.append([ev, total])
	if total <= 0:
		return null
	var pick := rng.randi_range(1, total)
	for pair in weighted:
		if pick <= pair[1]:
			return pair[0]
	return null
