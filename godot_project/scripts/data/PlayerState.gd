class_name PlayerState
extends RefCounted
## PlayerState.gd — 轻量状态容器（背包 + 核心指标 + 剧情标记）。
##
## 是数据管线里 DeltaData 的落点，也是「零和博弈」数值表的载体（阶段2）。
## 第一阶段只提供最小读写能力。

var items: Dictionary = {}                 ## 物品 id -> 数量
var stats: Dictionary = {
	"hp": 100,
	"warmth": 100,
	"sanity": 100,
	"progress": 0,
}
var flags: Dictionary = {}

func reset(starting_items: Dictionary = {}) -> void:
	items = starting_items.duplicate()
	stats = {"hp": 100, "warmth": 100, "sanity": 100, "progress": 0}
	flags = {}

func item_count(key: String) -> int:
	return items.get(key, 0)

func stat_value(key: String) -> float:
	return stats.get(key, 0)

## 统一入口：应用一条 delta，返回变化后的当前值。
func apply_delta(target: String, key: String, amount: int) -> int:
	match target:
		"item":
			items[key] = maxi(0, items.get(key, 0) + amount)
			return items[key]
		"stat":
			stats[key] = stats.get(key, 0) + amount
			return stats[key]
		"flag":
			flags[key] = amount
			return amount
		"crisis":
			flags["crisis_" + key] = flags.get("crisis_" + key, 0) + amount
			return flags["crisis_" + key]
	return 0
