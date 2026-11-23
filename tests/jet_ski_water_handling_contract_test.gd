extends SceneTree

const JET_SKI_SCRIPT = preload("res://scripts/jet_ski_controller.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	if not is_equal_approx(JET_SKI_SCRIPT.steering_authority(0.0, 15.0, 0.12), 0.12):
		failures.append("Jet ski steering should retain only its low-speed steering authority at rest.")
	if not is_equal_approx(JET_SKI_SCRIPT.steering_authority(15.0, 15.0, 0.12), 1.0):
		failures.append("Jet ski steering authority should reach full response at maximum speed.")
	if JET_SKI_SCRIPT.steering_authority(7.5, 15.0, 0.12) <= 0.12:
		failures.append("Jet ski steering authority should increase smoothly with forward speed.")
	if not is_equal_approx(JET_SKI_SCRIPT.apply_water_resistance(8.0, 2.0, 0.5), 7.0):
		failures.append("Water resistance should smoothly reduce speed after throttle release.")
	if not is_equal_approx(JET_SKI_SCRIPT.apply_water_resistance(0.5, 4.0, 1.0), 0.0):
		failures.append("Water resistance should not reverse the craft after it stops.")
	if not is_equal_approx(JET_SKI_SCRIPT.apply_water_resistance(8.0, -2.0, 0.5), 8.0):
		failures.append("Negative water resistance must not accelerate the craft.")

	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	for required_contract in [
		"func _mount_player_jet_ski() -> void:",
		"player.reparent(city_jet_ski, true)",
		"player.visible = true",
		"player.sitting = true",
		"JetSkiCamera",
		"func _exit_player_jet_ski(server_position: Variant = null) -> void:",
		"_jet_ski_unmount_pending = false",
		"func _recover_jet_ski_occupancy() -> void:",
		"JET_SKI_BOARDING_RADIUS",
		"_is_local_city_interaction_allowed()"
	]:
		if not main_source.contains(required_contract):
			failures.append("Jet ski rider integration is missing contract: %s" % required_contract)

	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("Royal jet ski water handling contract tests passed.")
	quit(0)
