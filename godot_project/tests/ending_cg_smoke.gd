extends SceneTree
## Verifies all five campaign endings have a loadable CG and that mapped aftermath pages resolve.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --path godot_project -s res://tests/ending_cg_smoke.gd

const CutsceneData := preload("res://scripts/data/CutsceneData.gd")
const CampaignSim := preload("res://scripts/CampaignSim.gd")

const EXPECTED := {
	"ENDING_A_RETURN_HOME": "res://art/60_ui/cg/cg_aftermath_a_602.jpg",
	"ENDING_B_FLAWED_LIBERATION": "res://art/60_ui/cg/cg_ending_broadcast_breach_302_alt.jpg",
	"ENDING_C_NUMBNESS": "res://art/60_ui/cg/cg_ending_crawl_back_cellar_alt.jpg",
	"TRUE_ALPHA_HELLO_LANA": "res://art/60_ui/cg/cg_ending_true_alpha_hello_lana.jpg",
	"TRUE_BETA_OUTLAND_FIRE": "res://art/60_ui/cg/cg_ending_true_beta_outland_fire.jpg",
}
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
	sim.tally = 1
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
		var context := {"crag_rescue_all": true}
		var path := CutsceneData.ending_scene(key, context)
		_assert(path == String(EXPECTED[key]), "%s main CG matches this route" % key, path)
		var texture := ResourceLoader.load(path) as Texture2D
		_assert(texture != null, "%s main CG loads as Texture2D" % key, path)
		if texture != null:
			var ratio := float(texture.get_width()) / texture.get_height()
			_assert(absf(ratio - 16.0 / 9.0) < 0.03, "%s main CG is widescreen" % key)
		var pages: Array = CutsceneData.ending_slides(key, false, context)
		var aftermath: Array = CutsceneData.ending_aftermath(key)
		var lead := 1 if key == "ENDING_C_NUMBNESS" else 0
		_assert(pages.size() == aftermath.size() + 1 + lead and String(pages[lead].get("img", "")) == path,
			"%s replay orders the main CG after any prologue and before aftermath" % key)
		if lead == 1:
			_assert(String(pages[0]["img"]).ends_with("cg_room602_empty_bed_folded_scarf.jpg"),
				"ending C begins at the empty bed")
		for page in pages:
			var image_path := String(page.get("img", ""))
			_assert(ResourceLoader.exists(image_path) and (ResourceLoader.load(image_path) as Texture2D) != null,
				"%s slide image loads" % key, image_path)

	var b_key := "ENDING_B_FLAWED_LIBERATION"
	var old_save: Array = CutsceneData.ending_slides(b_key)
	var lana_only: Array = CutsceneData.ending_slides(b_key, true, {"crag_rescue_lana": true})
	_assert(String(old_save[0]["img"]).ends_with("cg_tower302_aleksei_at_transmitter.jpg")
		and ResourceLoader.exists(String(old_save[0]["img"])), "legacy B uses the transmitter CG")
	_assert(String(lana_only[1]["zh"]).contains("车门还开着吗") and old_save[1]["zh"] != lana_only[1]["zh"],
		"Lana only and unknown legacy scope have distinct epilogues")
	var witnessed: Array = CutsceneData.ending_slides(b_key, true,
		{"pasha_witness_seen": true, "pasha_survived_to_crag": true})
	_assert(witnessed.size() == old_save.size() + 1 and String(witnessed.back()["zh"]).contains("帮我系上"),
		"Pasha's aftermath is appended only when both conditions are met")
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
