extends Sprite2D
## NightAnim.gd — 按 hframes 循环播放的精灵（火焰等），不依赖 SpriteFrames 资源。

@export var fps := 12.0
@export var random_start := true

var _t := 0.0

func _ready() -> void:
	if random_start:
		_t = randf() * 10.0

func _process(delta: float) -> void:
	_t += delta
	frame = int(_t * fps) % maxi(1, hframes * vframes)
