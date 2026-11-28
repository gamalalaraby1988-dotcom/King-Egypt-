extends SceneTree

func _initialize() -> void:
	var layout := FileAccess.get_file_as_string("res://scripts/approved_city_layout.gd")
	var main_script := FileAccess.get_file_as_string("res://scripts/main.gd")
	var failures: Array[String] = []

	var layout_contracts := [
		"_build_royal_ship_boarding_bridge()",
		"bridge.name = \"RoyalCivilizationsShipBoardingBridge\"",
		"var deck_length := 120.0",
		"ship.position = Vector3(-45.0, 0.0, 216.0)",
		"ship.rotation.y = PI * 0.5",
		"Vector3(120.0, 0.18, 240.0)",
		"_add_jet_ski_gate(course, \"Start\", 96.0, \"START\")"
	]
	for contract in layout_contracts:
		if not layout.contains(contract):
			failures.append("Missing waterfront/ship contract: " + contract)

	var road_contracts := [
		"const CITY_SAFE_Z_MAX := 245.0",
		"Vector3(220, 0.08, 14)",
		"Vector3(12, 0.075, 118)",
		"Vector3(132, 0.075, 12)"
	]
	for contract in road_contracts:
		if not main_script.contains(contract):
			failures.append("Missing expanded road/safety contract: " + contract)

	if failures.is_empty():
		print("Expanded city master plan contract tests passed: independent ship bridge, enlarged sea, unchanged race gates, wider roads, and extended safe boundary.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		push_error("Expanded city master plan contract tests failed.")
		quit(1)
