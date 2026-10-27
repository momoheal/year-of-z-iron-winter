class_name EventOptionData
extends Resource
## EventOptionData.gd — 事件的一个可选抉择（对应 UI 上的一个按钮）。
##
## 全部后果都用 DeltaData 表达，不包含任何脚本逻辑，
## 因此可以在编辑器检视器里直接改，无需写代码。

@export var id: String = "opt"
@export_multiline var label_zh: String = ""
@export_multiline var label_en: String = ""

@export_range(0.0, 1.0, 0.05) var success_chance: float = 1.0

@export var costs: Array[DeltaData] = []          ## 一旦选择即付出（无论成败）
@export var on_success: Array[DeltaData] = []    ## 判定成功时应用
@export var on_failure: Array[DeltaData] = []    ## 判定失败时应用

@export_multiline var result_text_zh: String = ""
@export_multiline var result_text_en: String = ""
