extends SceneTree

const MASTER_PLAN = preload("res://scripts/city_master_plan.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	var building_ids: Array[String] = []
	for building in MASTER_PLAN.BUILDINGS:
		building_ids.append(str(building.get("id", "")))

	var development_source := FileAccess.get_file_as_string("res://scripts/development_manager.gd")
	if building_ids.size() != 27:
		failures.append("The canonical city plan must contain exactly 27 approved buildings.")
	if building_ids.has("marina_terminal"):
		failures.append("The removed marina terminal must not remain in the canonical city plan.")
	if MASTER_PLAN.get_building_by_id("royal_yacht_club").get("name", "") != "النادي الشاطئي الملكي":
		failures.append("The retained waterfront building must use the approved Royal Beach Club name.")
	if not development_source.contains("const TOTAL_BUILDINGS := 27"):
		failures.append("Development progression must use the 27-building city plan.")
	if not development_source.contains("Vector2i(4107, 4463)"):
		failures.append("The Royal Beach Club must absorb the retired marina level band.")
	if development_source.contains('"marina_terminal": {"stage_2"'):
		failures.append("The removed marina terminal must not retain a development reward slot.")
	if not development_source.contains("func _normalize_removed_marina_progress(saved_count: int) -> int:"):
		failures.append("Legacy progress must be normalized when the marina slot is removed.")
	if not development_source.contains("return saved_count - STAGES_PER_BUILDING"):
		failures.append("Progress after the retired marina slot must shift back by five stages.")
	if not development_source.contains("const TOTAL_STAGES := TOTAL_BUILDINGS * STAGES_PER_BUILDING"):
		failures.append("The total stage count must follow the corrected building count.")

	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("Development progression registry contract tests passed.")
	quit(0)
