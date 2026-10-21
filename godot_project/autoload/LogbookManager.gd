extends Node
## Global Autoload: Manages Aleksei's Dual-Sided Work Logbook (Рабочий Журнал),
## Russian 5-Stroke Guilt Tally (卌), PTSD Thirst Tinnitus, and 5-Ending Resolution.

signal tally_updated(current_strokes: int, reason_zh: String, reason_en: String)
signal real_name_recorded(entry_id: String, name_zh: String, name_en: String)
signal ptsd_thirst_triggered()

var tally_strokes: int = 0
var truth_alive: bool = true          # Set by Act II Choice B (B2/B3 = true, B1 = false)
var mother_alive: bool = true         # Set by Chapter 8 Dialysis Watershed
var ptsd_thirst_unlocked: bool = false # Set after Room E / L05 Vasily Collarbone Blade Jam

var verified_names: Array[Dictionary] = [
	{
		"id": "katya_602",
		"zh": "卡佳妈妈 (第3居住区602室 · 尿毒症腹透锚点)",
		"en": "Mama Katya (District 3 Apt 602 · Peritoneal Dialysis Anchor)"
	}
]

func add_tally_strokes(amount: int, reason_zh: String, reason_en: String) -> void:
	tally_strokes = clampi(tally_strokes + amount, 0, 5)
	emit_signal("tally_updated", tally_strokes, reason_zh, reason_en)

func record_real_name(entry_id: String, name_zh: String, name_en: String) -> void:
	for item in verified_names:
		if item["id"] == entry_id:
			return
	verified_names.append({"id": entry_id, "zh": name_zh, "en": name_en})
	emit_signal("real_name_recorded", entry_id, name_zh, name_en)

func is_conscience_passed() -> bool:
	return truth_alive and (tally_strokes == 0)

func resolve_ending(gate_d_choice: String) -> String:
	match gate_d_choice:
		"D2":
			return "ENDING_A_FIRING_SQUAD_MERCY"
		"D3":
			return "ENDING_C_ABSURD_NUMBNESS"
		"D1":
			if not is_conscience_passed():
				return "ENDING_B_ABSURD_LIBERATION"
			return "TRUE_ENDING_ALPHA_HELLO_LANA" if mother_alive else "TRUE_ENDING_BETA_OUTLAND_FIRE"
		_:
			return "ENDING_C_ABSURD_NUMBNESS"
