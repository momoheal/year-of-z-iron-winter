extends RefCounted
## Run through the campaign entry point with --headless -- --check-export.

const Data := preload("res://scripts/CampaignData.gd")
const MAX_PCK_BYTES := 600 * 1024 * 1024
const PROCESS_ART_DIRS := [
	"res://art/generation_runs",
	"res://art/10_characters/generation_runs",
	"res://art/30_props/generation_runs",
]


static func run(tree: SceneTree) -> void:
	var pack := OS.get_executable_path().get_basename() + ".pck"
	var pack_size := FileAccess.get_size(pack)
	if pack_size <= 0 or pack_size > MAX_PCK_BYTES:
		_fail(tree, "PCK is missing or exceeds 600 MiB: %d bytes" % pack_size)
		return
	for path in PROCESS_ART_DIRS:
		if DirAccess.dir_exists_absolute(path):
			_fail(tree, "Process artwork is present in the PCK: " + path)
			return
	var lines := Data.script_scene("1-2")
	if lines.is_empty() or lines[0].get("zh") != "白昼。城北四号铁路冷库。":
		_fail(tree, "The cold-storage scene's opening line is missing from the exported dialogue")
		return
	var err := tree.change_scene_to_file("res://scenes/night_coldstore.tscn")
	if err != OK:
		_fail(tree, "Could not load the cold-storage night map: " + error_string(err))
		return
	await tree.scene_changed
	if tree.current_scene.get("level_id") != "coldstore":
		_fail(tree, "The cold-storage night map did not initialize")
		return
	print("EXPORT_CHECK_PASS: PCK %.1f MiB; cold-storage map and dialogue loaded" % (float(pack_size) / 1048576.0))
	tree.quit()


static func _fail(tree: SceneTree, message: String) -> void:
	push_error("EXPORT_CHECK_FAIL: " + message)
	tree.quit(1)
