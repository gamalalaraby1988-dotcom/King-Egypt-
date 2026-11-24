extends SceneTree

const MASTER_PLAN = preload("res://scripts/city_master_plan.gd")
const DEVELOPMENT_MANAGER = preload("res://scripts/development_manager.gd")

func _initialize() -> void:
	call_deferred("_run_development_progression_registry_contract")

func _run_development_progression_registry_contract() -> void:
	var failures: Array[String] = []
	var manager := DEVELOPMENT_MANAGER.new()
	var building_ids: Array[String] = []
	for building in MASTER_PLAN.BUILDINGS:
		building_ids.append(str(building.get("id", "")))

	if building_ids.size() != DEVELOPMENT_MANAGER.TOTAL_BUILDINGS:
		failures.append("The canonical city plan and development progression must contain the same number of buildings.")
	if DEVELOPMENT_MANAGER.BUILDING_LEVEL_RANGES.size() != DEVELOPMENT_MANAGER.TOTAL_BUILDINGS:
		failures.append("Every approved development building must have exactly one level range.")
	if building_ids.has("marina_terminal"):
		failures.append("The removed marina terminal must not remain in the canonical city plan.")
	if DEVELOPMENT_MANAGER.BUILDING_MILESTONE_REWARDS.has("marina_terminal"):
		failures.append("The removed marina terminal must not retain a development reward slot.")
	var beach_club: Dictionary = {}
	for building in MASTER_PLAN.BUILDINGS:
		if str(building.get("id", "")) == "royal_yacht_club":
			beach_club = building
	if beach_club.get("name", "") != "النادي الشاطئي الملكي":
		failures.append("The retained waterfront building must use the approved Royal Beach Club name.")
	if DEVELOPMENT_MANAGER.BUILDING_LEVEL_RANGES[23] != Vector2i(4107, 4463):
		failures.append("The Royal Beach Club must absorb the retired marina level band to preserve the existing level scale.")
	if manager._normalize_removed_marina_progress(115) != 115:
		failures.append("Progress before the retired marina slot must remain unchanged.")
	for legacy_count in [116, 119, 120]:
		if manager._normalize_removed_marina_progress(legacy_count) != 115:
			failures.append("Partial progress inside the retired marina slot must collapse safely.")
	if manager._normalize_removed_marina_progress(121) != 116:
		failures.append("Progress after the retired marina slot must shift back by five stages.")
	if manager._normalize_removed_marina_progress(140) != 135:
		failures.append("Legacy maximum progress must clamp to the new 27-building stage total.")
	if manager._level_for_stage(1) != 1 or manager._level_for_stage(DEVELOPMENT_MANAGER.TOTAL_STAGES) != DEVELOPMENT_MANAGER.MAX_PLAYER_LEVEL:
		failures.append("Development level ranges must still cover levels 1 through 5000.")

	manager.free()
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("Development progression registry contract tests passed.")
	quit(0)
