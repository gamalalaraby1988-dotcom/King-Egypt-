extends SceneTree

func _initialize() -> void:
	var layout := FileAccess.get_file_as_string("res://scripts/approved_city_layout.gd")
	var main_script := FileAccess.get_file_as_string("res://scripts/main.gd")
	var city_map := FileAccess.get_file_as_string("res://scripts/city_map.gd")
	var jobs := FileAccess.get_file_as_string("res://scripts/city_jobs_catalog.gd")
	var npcs := FileAccess.get_file_as_string("res://scripts/city_npc_population.gd")
	var failures: Array[String] = []

	var layout_contracts := [
		"_build_royal_ship_boarding_bridge()",
		"bridge.name = \"RoyalCivilizationsShipBoardingBridge\"",
		"var deck_length := 120.0",
		"ship.position = Vector3(-45.0, 0.0, -657.0)",
		"ship.rotation.y = PI * 0.5",
		"Vector3(440.0, 0.18, 280.0)",
		"_add_jet_ski_gate(course, \"Start\", 96.0, \"START\")",
		"Vector3(120, 0, -45)",
		"Vector3(150, 0, 112.50)",
		"station.position = Vector3(-148.0, 0.0, 57.0)",
		"beach.position = Vector3(180.0, 0.0, -430.0)",
		"mountain.position = Vector3(130, 0, 390)"
	]
	for contract in layout_contracts:
		if not layout.contains(contract):
			failures.append("Missing expanded district/waterfront contract: " + contract)

	var road_contracts := [
		"const CITY_SAFE_X_LIMIT := 280.0",
		"const CITY_SAFE_Z_MIN := -850.0",
		"const CITY_SAFE_Z_MAX := 600.0",
		"Vector3(160, 1, 1000)",
		"Vector3(220, 1, 418)",
		"Vector3(340, 0.08, 14)",
		"RoyalLoopRoad_NorthWestTurn",
		"RoyalLoopRoad_NorthEastTurn",
		"RoyalLoopRoad_SouthWestTurn",
		"RoyalLoopRoad_SouthEastTurn",
		"func _create_rotated_box",
		"Vector3(10, 0.08, 55)",
		"Vector3(-130, 0.01, 402.5)",
		"MainRoad_South",
		"Vector3(0, 0.0, 540)",
		"Vector3(440, 1, 240)",
		"Ground_North_Beach",
		"Vector3(440, 1, 180)",
		"Vector3(0, -0.55, -430)",
		"Ground_Center_South",
		"Vector3(-130, 0, 370)",
		"Vector3(-130, 0, 450)",
		"DesertDistrictRingConnector",
		"PyramidsDistrictRingConnector",
		"KingsMountainRingConnector",
		"Vector3(0, 0.0, -315)",
		"const JET_SKI_LAUNCH_POSITION := Vector3(0.0, 0.34, -514.0)",
		"bridge.rotation.y = PI",
		"Vector3(264, 0.075, 12)",
		"Vector3(264.0, 0.14, 1.7)"
	]
	for contract in road_contracts:
		if not main_script.contains(contract):
			failures.append("Missing expanded road/terrain contract: " + contract)

	if not main_script.contains("MainRoad_South") or not main_script.contains("DesertDistrictRingConnector") or not main_script.contains("PyramidsDistrictRingConnector") or not main_script.contains("KingsMountainRingConnector"):
		failures.append("Southern districts are not connected to the continuous perimeter road.")
	for turn_name in ["RoyalLoopRoad_NorthWestTurn", "RoyalLoopRoad_NorthEastTurn", "RoyalLoopRoad_SouthWestTurn", "RoyalLoopRoad_SouthEastTurn"]:
		if not main_script.contains(turn_name):
			failures.append("The royal loop road is missing a rounded corner: " + turn_name)
	if not main_script.contains('Vector3(10, 0.08, 55), Vector3(-130, 0.01, 402.5)'):
		failures.append("The desert camp approach does not meet its ring-road connector.")
	if main_script.contains("BeachAccessRoad_West") or main_script.contains("BeachAccessConnector_West"):
		failures.append("West beach spurs still cut across the ship/pyramid sightline.")
	if not city_map.contains('"key": "desert_camp", "position": Vector3(-130.0, 0.0, 370.0)'):
		failures.append("Desert camp navigation was not moved to the southern desert district.")
	if not city_map.contains('"key": "pyramids_camp", "position": Vector3(-130.0, 0.0, 450.0)'):
		failures.append("Pyramids navigation was not moved to the southern landmark district.")
	if not city_map.contains('"key": "royal_ship", "position": Vector3(-45.0, 0.0, 216.0)'):
		failures.append("Navigation map does not point to the relocated civilizations ship.")
	if not city_map.contains('"key": "restaurant", "position": Vector3(120.0, 0.0, -35.4)'):
		failures.append("Restaurant navigation was not moved with the restaurant.")
	if not jobs.contains("const FUEL_STATION := Vector3(-150.00, 0.15, 57.00)"):
		failures.append("Delivery jobs still target the old fuel station.")
	if not jobs.contains("Vector3(133.00, 0.15, -35.25)"):
		failures.append("Delivery drop-off coordinates were not expanded.")
	if not npcs.contains("Vector3(-34, 0, -45)"):
		failures.append("NPC spawn positions were not redistributed across the wider city.")

	if failures.is_empty():
		print("Expanded city master plan contract tests passed: separated districts, expanded land/roads, synchronized map/jobs/NPCs, independent ship pier, and unchanged race gates.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		push_error("Expanded city master plan contract tests failed.")
		quit(1)
