extends SceneTree

func _initialize() -> void:
	var main_script := FileAccess.get_file_as_string("res://scripts/main.gd")
	var layout_script := FileAccess.get_file_as_string("res://scripts/approved_city_layout.gd")
	var network_script := FileAccess.get_file_as_string("res://scripts/circular_city_transport_network.gd")
	var failures: Array[String] = []

	for required in [
		"_create_circular_city_transport_network()",
		"res://scripts/circular_city_transport_network.gd",
		"func _create_circular_city_transport_network()"
	]:
		if not main_script.contains(required):
			failures.append("Main scene is missing circular transport integration: " + required)

	for required in [
		"const RING_RADII := [175.0, 215.0, 255.0]",
		"const RING_SEGMENTS := 32",
		"func _build_circular_rings()",
		"func _build_radial_shortcuts()",
		"for spoke_index in range(6)",
		"func _build_royal_panorama_link()",
		"const ROYAL_ROUTE_WIDTH := 34.0",
		"const ROYAL_ROUTE_SEGMENTS := 36",
		"RoyalSemicircleRoad_",
		"RoyalWestDesertBranch",
		"RoyalWestCenterBranch",
		"RoyalEastCenterBranch",
		"RoyalEastDesertBranch",
		"var branch_angles := [PI * 0.82, PI * 0.62, PI * 0.38, PI * 0.18]",
		"var desert_control := Vector3(0.0, 0.0, -550.0)",
		"func _build_short_branch(",
		"SteelGuardrail",
		"RoyalPanoramaPlazaDeck",
		"RoyalPanoramaFountainBase",
		"RoyalPanoramaCityEmblem"
	]:
		if not network_script.contains(required):
			failures.append("Royal semicircle transport network is missing: " + required)

	if layout_script.contains("\t_build_mountain_route()") or layout_script.contains("\t_build_mountain_animals()"):
		failures.append("The old steep mountain climb is still being spawned.")

	if not layout_script.contains('Vector3(440.0, 0.18, 280.0)') or not layout_script.contains('Vector3(0.0, 0.0, -270.0)'):
		failures.append("The existing sea and pyramid landmarks were unexpectedly changed.")

	for required in [
		"Vector3(82.0, 0.0, -285.0)",
		"Vector3(-82.0, 0.0, -285.0)"
	]:
		if not main_script.contains(required):
			failures.append("Northern desert area is missing: " + required)

	if failures.is_empty():
		print("Royal semicircle contract passed: first-ring connections, wide curved road, steel guardrails, panoramic plaza, preserved sea/pyramids.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		push_error("Royal semicircle contract failed.")
		quit(1)
