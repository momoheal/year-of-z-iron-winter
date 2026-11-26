extends RefCounted
## NightLighting.gd — 夜潜里手电光的共用设置（玩家与清杀兵共用，避免两份拷贝漂移）。


## 「Objects」这一层光照亮角色和道具，必须和地面光束用同一套墙体遮挡，
## 否则可见光锥会穿墙漏出来。pivot 下没有 Objects 灯时什么也不做。
static func configure_objects_occlusion(pivot: Node) -> void:
	if pivot == null:
		return
	var objects_light := pivot.get_node_or_null("Objects") as PointLight2D
	if objects_light == null:
		return
	objects_light.shadow_enabled = true
	objects_light.shadow_filter = 1
	objects_light.shadow_filter_smooth = 1.5
	objects_light.shadow_item_cull_mask = 1
