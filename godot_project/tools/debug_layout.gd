extends SceneTree
## 临时布局调试：检查 EventPopup 与面板的实际几何。

func _init() -> void:
	_dbg.call_deferred()

func _dbg() -> void:
	var demo = load("res://scenes/event_demo.tscn").instantiate()
	root.add_child(demo)
	for i in 3:
		await process_frame
	var popup = demo.popup
	print("root size=", root.size)
	print("demo size=", demo.size, " pos=", demo.global_position)
	print("popup size=", popup.size, " pos=", popup.global_position, " visible=", popup.visible)
	print("popup anchors L=", popup.anchor_left, " T=", popup.anchor_top,
		" R=", popup.anchor_right, " B=", popup.anchor_bottom)
	print("popup offsets L=", popup.offset_left, " T=", popup.offset_top,
		" R=", popup.offset_right, " B=", popup.offset_bottom)
	print("popup h/grow=", popup.grow_horizontal, " v/grow=", popup.grow_vertical,
		" hflags=", popup.size_flags_horizontal, " vflags=", popup.size_flags_vertical)
	var panel = popup._panel
	print("panel BEFORE show: size=", panel.size, " pos=", panel.global_position)

	popup.show_event(demo.catalog.all_events()[0])
	for i in 3:
		await process_frame
	print("panel AFTER show: size=", panel.size, " pos=", panel.global_position)
	print("panel anchors L=", panel.anchor_left, " T=", panel.anchor_top,
		" R=", panel.anchor_right, " B=", panel.anchor_bottom)
	print("panel offsets L=", panel.offset_left, " T=", panel.offset_top,
		" R=", panel.offset_right, " B=", panel.offset_bottom)
	print("grow H=", panel.grow_horizontal, " V=", panel.grow_vertical)
	quit()
