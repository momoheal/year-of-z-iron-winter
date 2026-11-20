extends SceneTree
## Captures every playable map with its runtime map plate and minimap.
## Set MAP_PREVIEW_DIR to keep the QA screenshots outside the project tree.

const LEVELS := [
	["yard", "res://scenes/night_explore.tscn"],
	["marshalling", "res://scenes/night_marshalling.tscn"],
	["manor", "res://scenes/night_manor.tscn"],
	["mine", "res://scenes/night_mine.tscn"],
	["market", "res://scenes/night_market.tscn"],
	["coldstore", "res://scenes/night_coldstore.tscn"],
	["canteen", "res://scenes/night_canteen.tscn"],
	["sanitarium", "res://scenes/night_sanitarium.tscn"],
	["boiler", "res://scenes/night_boiler.tscn"],
	["underpass", "res://scenes/night_underpass.tscn"],
	["greenhouse", "res://scenes/night_greenhouse.tscn"],
	["archive", "res://scenes/night_archive.tscn"],
	["workshop", "res://scenes/night_workshop.tscn"],
	["birch", "res://scenes/night_birch.tscn"],
	["station_buran_yard", "res://scenes/night_station_buran_yard.tscn"],
	["eagle_beak_cliff", "res://scenes/night_eagle_beak_cliff.tscn"],
	["broadcast_tower_302", "res://scenes/night_broadcast_tower_302.tscn"],

]

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _run() -> void:
	var out_dir := OS.get_environment("MAP_PREVIEW_DIR")
	var only_level := OS.get_environment("MAP_PREVIEW_LEVEL")
	if out_dir == "":
		out_dir = ProjectSettings.globalize_path("res://.map_art_preview")
	DirAccess.make_dir_recursive_absolute(out_dir)
	for entry in LEVELS:
		if only_level != "" and String(entry[0]) != only_level:
			continue
		var packed := load(String(entry[1])) as PackedScene
		if packed == null:
			push_error("Could not load %s" % String(entry[1]))
			_failed = true
			continue
		var scene := packed.instantiate()
		root.add_child(scene)
		await _frames(25)
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var path := out_dir.path_join("map_%s.png" % String(entry[0]))
		var err := image.save_png(path)
		print("[map-preview] %s -> %s (%dx%d)" % [String(entry[0]), path, image.get_width(), image.get_height()])
		if err != OK:
			push_error("Could not save %s: %s" % [path, error_string(err)])
			_failed = true
		root.remove_child(scene)
		scene.free()
		await _frames(2)
	quit(1 if _failed else 0)
