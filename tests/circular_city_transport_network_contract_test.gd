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
		"RoyalPanoramaRamp_West",
		"RoyalPanoramaRamp_East",
		"RoyalPanoramaPlazaDeck",
		"RoyalPanoramaGroundTie_West",
		"RoyalPanoramaGroundTie_East"
	]:
		if not network_script.contains(required):
			failures.append("Circular transport network is missing: " + required)

	if layout_script.contains("\t_build_mountain_route()") or layout_script.contains("\t_build_mountain_animals()"):
		failures.append("The old steep mountain climb is still being spawned.")

	if not layout_script.contains('Vector3(440.0, 0.18, 280.0)') or not layout_script.contains('Vector3(0.0, 0.0, -270.0)'):
		failures.append("The existing sea and pyramid landmarks were unexpectedly changed.")

	if failures.is_empty():
		print("Circular city transport contract passed: three rings, six radial links, connected elevated panorama route, retired mountain climb, and preserved sea/pyramids.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		push_error("Circular city transport contract failed.")
		quit(1)
