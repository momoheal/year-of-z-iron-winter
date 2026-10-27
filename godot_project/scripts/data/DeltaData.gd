class_name DeltaData
extends Resource
## DeltaData.gd — 一条可序列化的数值变化（纯数据，无任何逻辑）。
##
## 由 EventOptionData 携带，事件结算时统一应用。
## target 取值：
##   "item"   背包物品（key = 物品 id，如 "scrap"）
##   "stat"   核心指标（key = hp / warmth / sanity / progress ...）
##   "flag"   剧情标记（key = 标记 id，amount 通常为 1）
##   "crisis" 危机（key = 危机 id，amount 正=升级，负=缓解）

@export var target: String = "item"
@export var key: String = ""          ## 物品 id / 指标 id / 标记 id / 危机 id
@export var amount: int = 0           ## 正 = 获得 / 恢复；负 = 消耗 / 扣减
@export var label_zh: String = ""
@export var label_en: String = ""
