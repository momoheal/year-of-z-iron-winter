class_name EventData
extends Resource
## EventData.gd — 数据驱动的交互事件模板。
##
## 用法（第一阶段验收）：在文件系统里右键复制一份 .tres，
## 改标题、描述、概率与选项里的数字，游戏里即可刷出新事件，
## 全程不需要写任何新代码。

@export var id: String = ""

@export_multiline var title_zh: String = ""
@export_multiline var title_en: String = ""
@export_multiline var desc_zh: String = ""
@export_multiline var desc_en: String = ""

@export var phase: String = "any"                 ## 限定出现阶段（any 表示不限）
@export_range(0.0, 1.0, 0.05) var trigger_chance: float = 1.0
@export var weight: int = 1                        ## 随机抽取权重
@export var art_tag: String = ""                  ## 后续视听层用的标记

@export var options: Array[EventOptionData] = []
