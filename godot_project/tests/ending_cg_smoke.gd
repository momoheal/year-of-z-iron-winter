extends SceneTree
## Verifies all five campaign endings have a loadable CG and that mapped aftermath pages resolve.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --path godot_project -s res://tests/ending_cg_smoke.gd

const CutsceneData := preload("res://scripts/data/CutsceneData.gd")
const CampaignSim := preload("res://scripts/CampaignSim.gd")

const EXPECTED := {
	"ENDING_A_RETURN_HOME": "res://art/60_ui/cg/cg_aftermath_a_602.jpg",
	"ENDING_B_FLAWED_LIBERATION": "res://art/60_ui/cg/cg_tower302_aleksei_at_transmitter.jpg",
	"ENDING_C_NUMBNESS": "res://art/60_ui/cg/cg_ending_crawl_back_cellar_alt.jpg",
	"TRUE_ALPHA_HELLO_LANA": "res://art/60_ui/cg/cg_ending_true_alpha_hello_lana.jpg",
	"TRUE_BETA_OUTLAND_FIRE": "res://art/60_ui/cg/cg_ending_true_beta_outland_fire.jpg",
}
const EXPECTED_MAIN_CGS := [
	"cg_aftermath_a_602.jpg",
	"cg_tower302_aleksei_at_transmitter.jpg",
	"cg_ending_crawl_back_cellar_alt.jpg",
	"cg_ending_true_alpha_hello_lana.jpg",
	"cg_ending_true_beta_outland_fire.jpg",
]
const EXPECTED_AFTERMATH := {
	"ENDING_A_RETURN_HOME": "cg_aftermath_a_602.jpg",
	"ENDING_B_FLAWED_LIBERATION": "cg_aftermath_b_release.jpg",
	"ENDING_C_NUMBNESS": "cg_aftermath_c_numb.jpg",
	"TRUE_ALPHA_HELLO_LANA": "cg_aftermath_true_alpha.jpg",
	"TRUE_BETA_OUTLAND_FIRE": "cg_aftermath_true_beta.jpg",
}

var passes := 0
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _assert(ok: bool, label: String, detail: String = "") -> void:
	if ok:
		passes += 1
		print("  PASS  ", label)
	else:
		failures.append(label + ((" — " + detail) if detail != "" else ""))
		print("  FAIL  ", label, "  ", detail)

func _run() -> void:
	print("== ending_cg_smoke ==")
	_assert(CutsceneData.ENDING_SCENES.size() == 5 and EXPECTED.size() == 5,
		"the cutscene map contains exactly five endings")

	var sim := CampaignSim.new()
	sim.new_game()
	var ending_keys: Array[String] = [sim.ending_key()]
	sim.mother_alive = false
	ending_keys.append(sim.ending_key())
	sim.flags["truth"] = true
	sim.tally = 5
	ending_keys.append(sim.ending_key())
	sim.tally = 0
	sim.mother_alive = true
	ending_keys.append(sim.ending_key())
	sim.flags.erase("betrayed")
	sim.mother_alive = false
	ending_keys.append(sim.ending_key())
	var observed := {}
	for key in ending_keys:
		observed[key] = true
	_assert(observed.size() == EXPECTED.size(), "campaign state resolves to five unique ending keys", str(observed.keys()))
	for key in EXPECTED:
		_assert(CutsceneData.ENDING_SCENES.has(key), "%s has a cutscene mapping" % key)
		var path := CutsceneData.ending_scene(key)
		_assert(path == String(EXPECTED[key]) and ResourceLoader.exists(path), "%s main CG exists" % key, path)
		var texture := ResourceLoader.load(path) as Texture2D
		_assert(texture != null, "%s main CG loads as Texture2D" % key, path)
		if texture != null:
			_assert(texture.get_width() >= 1280 and texture.get_height() >= 720,
				"%s main CG has presentation resolution" % key, "%dx%d" % [texture.get_width(), texture.get_height()])
		var pages: Array = CutsceneData.ending_slides(key, key != "ENDING_C_NUMBNESS")
		var aftermath: Array = CutsceneData.ending_aftermath(key)
		var main_index := 1 if key == "ENDING_C_NUMBNESS" else 0
		var expected_count := aftermath.size() + 1 + main_index
		_assert(pages.size() == expected_count and String(pages[main_index].get("img", "")) == path,
			"%s replay deck orders main CG before aftermath" % key)
		for page in pages:
			var image_path := String(page.get("img", ""))
			_assert(ResourceLoader.exists(image_path) and (ResourceLoader.load(image_path) as Texture2D) != null,
				"%s slide image loads" % key, image_path)

	var mapped_assets := ""
	for key in CutsceneData.ENDING_SCENES:
		for page in CutsceneData.ending_slides(key):
			mapped_assets += " " + String(page.get("img", ""))
	for name in EXPECTED_MAIN_CGS:
		_assert(mapped_assets.contains(name), "%s main CG is wired into a five-ending scene" % name)
	var seen_aftermath := {}
	for key in EXPECTED_AFTERMATH:
		var aftermath: Array = CutsceneData.ending_aftermath(key)
		var expected_name := String(EXPECTED_AFTERMATH[key])
		_assert(aftermath.size() == 1 and String(aftermath[0].get("img", "")).ends_with(expected_name),
			"%s has its dedicated aftermath CG" % key, str(aftermath))
		_assert(not seen_aftermath.has(expected_name), "%s aftermath CG is unique" % key, expected_name)
		seen_aftermath[expected_name] = true

	print("== RESULT: %d passed, %d failed ==" % [passes, failures.size()])
	for failure in failures:
		print("  FAILED: ", failure)
	quit(0 if failures.is_empty() else 1)
