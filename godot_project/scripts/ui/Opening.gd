extends "res://scripts/ui/StorySlides.gd"
## 新游戏的故事开场：六页图片幻灯（世界观 → 母亲 → 签字 → 拉娜被带走 → 封楼 → 通风口）。
## 其中「封楼」一页叠了用游戏角色精灵做的实时小演出。
## 继续存档不播；标题页可以「回看序章」。空格 / 回车 / 点击推进，Esc 跳过。
## 播放逻辑全在 StorySlides.gd，页面内容在 scripts/data/CutsceneData.gd 的 PROLOGUE。

const CutsceneData := preload("res://scripts/data/CutsceneData.gd")


func _ready() -> void:
	heading_zh = "序章 · 诺沃斯克-17"
	heading_en = "PROLOGUE · NOVORSK-17"
	if slides.is_empty():
		slides = CutsceneData.PROLOGUE.duplicate(true)
	super._ready()
