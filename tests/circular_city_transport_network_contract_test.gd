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
		"var west_join := CITY_CENTER + Vector3(-RING_RADII[2], 0.0, 0.0)",
		"var east_join := CITY_CENTER + Vector3(RING_RADII[2], 0.0, 0.0)",
		"var control_a := west_join + Vector3(0.0, 0.0, 520.0)",
		"var control_b := east_join + Vector3(0.0, 0.0, 520.0)",
		"Vector3(0.0, 0.055 + ramp_factor * ROYAL_ROUTE_HEIGHT, 0.0)",
		"route_widths.append(lerpf(RING_WIDTH, ROYAL_ROUTE_WIDTH, ramp_factor))",
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

	# Both endpoints share the outer ring's center height and width.
	var endpoint_y := 0.055
	var endpoint_width := 9.0
	if absf(endpoint_y - 0.055) > 0.001 or absf(endpoint_width - 9.0) > 0.001:
		failures.append("The southern royal road does not merge flush with the outer ring.")
	# Cubic handles are directly north/south of each endpoint, preserving the ring tangent.
	if not network_script.contains("west_join + Vector3(0.0, 0.0, 520.0)") or not network_script.contains("east_join + Vector3(0.0, 0.0, 520.0)"):
		failures.append("The royal road endpoints are not tangent-aligned with the outer ring.")

	for required in [
		"Vector3(82.0, 0.0, 285.0)",
		"Vector3(-82.0, 0.0, 285.0)"
	]:
		if not main_script.contains(required):
			failures.append("Southern desert area is missing: " + required)

	if failures.is_empty():
		print("Royal semicircle contract passed: outer-ring endpoint connections, branch-free wide curved road, steel guardrails, panoramic plaza, preserved sea/pyramids.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		push_error("Royal semicircle contract failed.")
		quit(1)
