class_name EventResolver
extends RefCounted
## EventResolver.gd — 纯逻辑：把一个事件选项结算成一组待应用的 DeltaData。
##
## 不直接改背包、不碰节点，只负责掷骰判定 + 汇总 delta，
## 由上层（演示场景 / 真实 sim）决定如何应用与广播。

## 返回 { success, deltas: Array[DeltaData], result_text_zh, result_text_en }
func resolve_option(option: EventOptionData, rng: RandomNumberGenerator) -> Dictionary:
	var success: bool = rng.randf() <= option.success_chance
	var deltas: Array[DeltaData] = []
	for d in option.costs:
		deltas.append(d)
	var branch: Array[DeltaData] = option.on_success if success else option.on_failure
	for d in branch:
		deltas.append(d)
	var text_zh: String = option.result_text_zh
	var text_en: String = option.result_text_en
	return {
		"success": success,
		"deltas": deltas,
		"result_text_zh": text_zh,
		"result_text_en": text_en,
	}

## 把一条 delta 应用到状态容器（容器需实现 apply_delta(target, key, amount) -> int）。
func apply_delta(delta: DeltaData, state) -> int:
	return state.apply_delta(delta.target, delta.key, delta.amount)
