extends SceneTree

class RejectingAutoNavigationPlayer:
	extends Node3D

	func begin_auto_navigation() -> bool:
		return false


func _initialize() -> void:
	call_deferred("_run_social_validation_tests")

func _run_social_validation_tests() -> void:
	await process_frame
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("Social chat validation test watchdog expired.")
		quit(1)
	)
	print("SOCIAL_TEST_STAGE: autoload_ready")
	var mission_manager_script: Script = load("res://scripts/mission_manager.gd")
	if mission_manager_script == null:
		push_error("MissionManager script could not be loaded for shared-location route validation.")
		quit(1)
		return
	var route_probe: Node = mission_manager_script.new()
	root.add_child(route_probe)
	if bool(route_probe.call("should_cancel_shared_location_walk_for_activity", false, false)):
		push_error("Shared-location walking was cancelled without an active mission or job.")
		quit(1)
		return
	if not bool(route_probe.call("should_cancel_shared_location_walk_for_activity", true, false)) or not bool(route_probe.call("should_cancel_shared_location_walk_for_activity", false, true)) or not bool(route_probe.call("should_cancel_shared_location_walk_for_activity", true, true)):
		push_error("Shared-location walking was not cancelled when a mission or job became active.")
		quit(1)
		return
	var navigation_state_probe := Node3D.new()
	navigation_state_probe.position = Vector3.ZERO
	root.add_child(navigation_state_probe)
	route_probe.set("player", navigation_state_probe)
	route_probe.set("landmark_navigation_active", true)
	route_probe.set("landmark_navigation_target", Vector3(12.0, 0.0, 12.0))
	route_probe.set("landmark_navigation_key", "existing_landmark")
	route_probe.set("landmark_navigation_name", "وجهة سابقة")
	var rejected_navigation_started: bool = route_probe.call("navigate_to_landmark", "shared_location", Vector3(200.0, 0.0, 0.0))
	if rejected_navigation_started or not bool(route_probe.get("landmark_navigation_active")) or route_probe.get("landmark_navigation_target") != Vector3(12.0, 0.0, 12.0) or str(route_probe.get("landmark_navigation_key")) != "existing_landmark" or str(route_probe.get("landmark_navigation_name")) != "وجهة سابقة":
		push_error("A rejected shared-location destination overwrote the player's existing navigation state.")
		quit(1)
		return
	var rejecting_player := RejectingAutoNavigationPlayer.new()
	root.add_child(rejecting_player)
	route_probe.set("player", rejecting_player)
	route_probe.set("landmark_navigation_active", true)
	route_probe.set("landmark_navigation_target", Vector3(18.0, 0.0, 18.0))
	route_probe.set("landmark_navigation_key", "existing_landmark")
	route_probe.set("landmark_navigation_name", "وجهة سابقة")
	var rejected_riding_navigation: bool = route_probe.call("navigate_to_landmark", "shared_location", Vector3(48.0, 0.0, 48.0))
	if rejected_riding_navigation or not bool(route_probe.get("landmark_navigation_active")) or route_probe.get("landmark_navigation_target") != Vector3(18.0, 0.0, 18.0) or str(route_probe.get("landmark_navigation_key")) != "existing_landmark" or str(route_probe.get("landmark_navigation_name")) != "وجهة سابقة":
		push_error("A player unable to start auto-walking overwrote the existing navigation state.")
		quit(1)
		return
	rejecting_player.free()
	navigation_state_probe.free()
	var valid_shared_route: PackedVector3Array = route_probe.call("build_shared_location_route_from", Vector3.ZERO, Vector3(48.0, 0.0, 48.0))
	if valid_shared_route.size() < 2 or valid_shared_route[0].distance_to(Vector3.ZERO) > 0.1 or valid_shared_route[valid_shared_route.size() - 1].distance_to(Vector3(48.0, 0.0, 48.0)) > 0.1:
		push_error("A valid in-city shared-location scooter route was not built from road waypoints.")
		quit(1)
		return
	var route_deviation_probe := PackedVector3Array([Vector3.ZERO, Vector3(10.0, 0.0, 0.0), Vector3(20.0, 0.0, 0.0)])
	if not bool(route_probe.call("is_position_near_shared_location_route", Vector3(5.0, 0.0, 1.0), route_deviation_probe, 0, 8.0)):
		push_error("A scooter positioned beside its active route was incorrectly marked as deviated.")
		quit(1)
		return
	if bool(route_probe.call("is_position_near_shared_location_route", Vector3(5.0, 0.0, 12.0), route_deviation_probe, 0, 8.0)):
		push_error("A scooter far from its active route was not detected as deviated.")
		quit(1)
		return
	if bool(route_probe.call("is_position_near_shared_location_route", Vector3(5.0, 0.0, 1.0), route_deviation_probe, 0, -1.0)):
		push_error("Invalid route deviation limits should be rejected.")
		quit(1)
		return
	if not bool(route_probe.call("is_position_near_shared_location_route", Vector3(15.0, 0.0, 1.0), route_deviation_probe, 1, 8.0)):
		push_error("Route deviation validation failed while checking the remaining route segments.")
		quit(1)
		return
	if bool(route_probe.call("is_position_near_shared_location_route", Vector3(INF, 0.0, 0.0), route_deviation_probe, 0, 8.0)):
		push_error("Non-finite vehicle positions must never pass route deviation validation.")
		quit(1)
		return
	var single_point_route := PackedVector3Array([Vector3(4.0, 0.0, 4.0)])
	if not bool(route_probe.call("is_position_near_shared_location_route", Vector3(5.0, 0.0, 4.0), single_point_route, 0, 2.0)):
		push_error("A one-point route should validate nearby positions without indexing a missing segment.")
		quit(1)
		return
	if bool(route_probe.call("is_position_near_shared_location_route", Vector3(8.0, 0.0, 4.0), single_point_route, 0, 2.0)):
		push_error("A one-point route should reject positions outside its allowed deviation.")
		quit(1)
		return
	# افحص وصلات شبكة الطرق فقط؛ الوصلتان من/إلى الموقع قد تكونان مائلتين داخل الساحة الجانبية.
	for route_index in range(1, valid_shared_route.size() - 2):
		var previous_point: Vector3 = valid_shared_route[route_index - 1]
		var current_point: Vector3 = valid_shared_route[route_index]
		var delta_x := absf(current_point.x - previous_point.x)
		var delta_z := absf(current_point.z - previous_point.z)
		if delta_x > 0.1 and delta_z > 0.1:
			push_error("A shared-location scooter road segment cuts diagonally across the city grid.")
			quit(1)
			return
	var far_shared_route: PackedVector3Array = route_probe.call("build_shared_location_route_from", Vector3.ZERO, Vector3(200.0, 0.0, 0.0))
	if not far_shared_route.is_empty():
		push_error("A shared-location scooter route accepted a destination far outside the city road network.")
		quit(1)
		return
	var offroad_start_route: PackedVector3Array = route_probe.call("build_shared_location_route_from", Vector3(200.0, 0.0, 0.0), Vector3.ZERO)
	if not offroad_start_route.is_empty():
		push_error("A shared-location scooter route accepted a starting position far outside the city road network.")
		quit(1)
		return
	var non_finite_start_route: PackedVector3Array = route_probe.call("build_shared_location_route_from", Vector3(INF, 0.0, 0.0), Vector3.ZERO)
	if not non_finite_start_route.is_empty():
		push_error("A shared-location route accepted an infinite starting coordinate.")
		quit(1)
		return
	var non_finite_destination_route: PackedVector3Array = route_probe.call("build_shared_location_route_from", Vector3.ZERO, Vector3(0.0, NAN, 0.0))
	if not non_finite_destination_route.is_empty():
		push_error("A shared-location route accepted a NaN destination coordinate.")
		quit(1)
		return
	var elevated_destination_route: PackedVector3Array = route_probe.call("build_shared_location_route_from", Vector3.ZERO, Vector3(0.0, 101.0, 0.0))
	if not elevated_destination_route.is_empty():
		push_error("A shared-location route accepted a destination outside the supported vertical world bounds.")
		quit(1)
		return
	for invalid_route_pair in [
		[Vector3(251.0, 0.0, 0.0), Vector3.ZERO],
		[Vector3.ZERO, Vector3(-251.0, 0.0, 0.0)],
		[Vector3(0.0, -10.1, 0.0), Vector3.ZERO],
		[Vector3.ZERO, Vector3(0.0, -10.1, 0.0)],
		[Vector3(0.0, 0.0, 251.0), Vector3.ZERO],
		[Vector3.ZERO, Vector3(0.0, 0.0, -251.0)]
	]:
		var rejected_route: PackedVector3Array = route_probe.call("build_shared_location_route_from", invalid_route_pair[0], invalid_route_pair[1])
		if not rejected_route.is_empty():
			push_error("A shared-location route accepted a start or destination outside the world coordinate bounds.")
			quit(1)
			return
	var marker_probe := Node3D.new()
	marker_probe.visible = true
	route_probe.add_child(marker_probe)
	route_probe.set("shared_location_marker", marker_probe)
	var player_script: Script = load("res://scripts/player.gd")
	if player_script == null:
		push_error("Player script could not be loaded for auto-navigation cleanup validation.")
		quit(1)
		return
	var player_probe: CharacterBody3D = player_script.new() as CharacterBody3D
	var camera_pivot_probe := Node3D.new()
	camera_pivot_probe.name = "CameraPivot"
	player_probe.add_child(camera_pivot_probe)
	if player_probe == null:
		push_error("Player auto-navigation test instance could not be created.")
		quit(1)
		return
	route_probe.add_child(player_probe)
	route_probe.set("player", player_probe)
	if not player_probe.call("begin_auto_navigation"):
		push_error("Player did not enter shared-location auto-navigation test state.")
		quit(1)
		return
	player_probe.call("set_auto_navigation_direction", Vector3(1.0, 0.0, 0.0))
	player_probe.velocity = Vector3(4.0, 0.0, 2.0)
	if not bool(player_probe.get("auto_navigation_active")):
		push_error("Player auto-navigation did not activate before activity interruption.")
		quit(1)
		return
	route_probe.set("landmark_navigation_key", "shared_location")
	route_probe.set("landmark_navigation_active", true)
	route_probe.set("landmark_route_points", valid_shared_route)
	route_probe.set("landmark_route_index", 1)
	route_probe.set("navigation_arrival_remaining", 2.0)
	route_probe.set("navigation_off_route_time", 1.5)
	route_probe.set("navigation_route_notice_remaining", 3.0)
	route_probe.call("_stop_shared_location_navigation_for_activity")
	if bool(route_probe.get("landmark_navigation_active")) or str(route_probe.get("landmark_navigation_key")) != "":
		push_error("Starting an activity did not clear shared-location navigation state.")
		quit(1)
		return
	if not (route_probe.get("landmark_route_points") as PackedVector3Array).is_empty() or int(route_probe.get("landmark_route_index")) != 0:
		push_error("Starting an activity did not clear the shared-location route and waypoint index.")
		quit(1)
		return
	if marker_probe.visible:
		push_error("Starting an activity did not hide the shared-location marker.")
		quit(1)
		return
	if bool(player_probe.get("auto_navigation_active")) or not (player_probe.get("auto_navigation_direction") as Vector3).is_zero_approx() or not is_zero_approx(player_probe.velocity.x) or not is_zero_approx(player_probe.velocity.z):
		push_error("Starting an activity did not stop the player's automatic walking movement.")
		quit(1)
		return
	if not is_zero_approx(float(route_probe.get("navigation_arrival_remaining"))) or not is_zero_approx(float(route_probe.get("navigation_off_route_time"))) or not is_zero_approx(float(route_probe.get("navigation_route_notice_remaining"))):
		push_error("Starting an activity did not reset shared-navigation timers.")
		quit(1)
		return
	# الانتقال إلى الاسكوتر يجب أن يلغي مسار مشاركة الموقع القديم فقط، لا أي ملاحة أخرى.
	player_probe.call("begin_auto_navigation")
	player_probe.call("set_auto_navigation_direction", Vector3(1.0, 0.0, 0.0))
	route_probe.set("landmark_navigation_key", "shared_location")
	route_probe.set("landmark_navigation_active", true)
	route_probe.set("landmark_route_points", valid_shared_route)
	route_probe.set("landmark_route_index", 1)
	marker_probe.visible = true
	if not bool(route_probe.call("cancel_shared_location_navigation")):
		push_error("Explicit shared-location cancellation did not report that it cancelled an active route.")
		quit(1)
		return
	if bool(route_probe.get("landmark_navigation_active")) or str(route_probe.get("landmark_navigation_key")) != "" or not (route_probe.get("landmark_route_points") as PackedVector3Array).is_empty() or marker_probe.visible or bool(player_probe.get("auto_navigation_active")):
		push_error("Explicit shared-location cancellation left walking, route, or marker state active.")
		quit(1)
		return
	if bool(route_probe.call("cancel_shared_location_navigation")):
		push_error("Cancelling an already inactive shared-location route reported a false cancellation.")
		quit(1)
		return
	route_probe.set("landmark_navigation_key", "existing_landmark")
	route_probe.set("landmark_navigation_active", true)
	if bool(route_probe.call("cancel_shared_location_navigation")) or not bool(route_probe.get("landmark_navigation_active")) or str(route_probe.get("landmark_navigation_key")) != "existing_landmark":
		push_error("Shared-location cancellation incorrectly cleared an unrelated landmark route.")
		quit(1)
		return
	route_probe.set("landmark_navigation_key", "shared_location")
	route_probe.set("landmark_navigation_active", false)
	# الوصول إلى الموقع يوقف المشي ويزيل العلامة والمسار ويبدأ مهلة الوصول.
	player_probe.call("begin_auto_navigation")
	player_probe.call("set_auto_navigation_direction", Vector3(0.0, 0.0, -1.0))
	player_probe.velocity = Vector3(3.0, 0.0, 1.0)
	route_probe.set("landmark_navigation_key", "shared_location")
	route_probe.set("landmark_navigation_active", true)
	route_probe.set("landmark_route_points", valid_shared_route)
	route_probe.set("landmark_route_index", 1)
	marker_probe.visible = true
	route_probe.call("_complete_shared_location_navigation")
	if bool(route_probe.get("landmark_navigation_active")) or not (route_probe.get("landmark_route_points") as PackedVector3Array).is_empty() or int(route_probe.get("landmark_route_index")) != 0 or marker_probe.visible or bool(player_probe.get("auto_navigation_active")) or float(route_probe.get("navigation_arrival_remaining")) <= 0.0 or not player_probe.velocity.is_zero_approx():
		push_error("Arriving at a shared location did not stop movement and clear navigation state.")
		quit(1)
		return
	# إعادة حساب المسار بعد الخروج عنه تستخدم مسار الموقع الآمن نفسه.
	player_probe.global_position = Vector3.ZERO
	route_probe.set("landmark_navigation_target", Vector3(48.0, 0.0, 48.0))
	route_probe.set("landmark_navigation_key", "shared_location")
	route_probe.set("landmark_navigation_active", true)
	route_probe.set("landmark_route_points", PackedVector3Array([Vector3.ZERO, Vector3(1.0, 0.0, 1.0)]))
	if not bool(route_probe.call("_recalculate_active_landmark_route")):
		push_error("A valid shared-location route could not be recalculated after leaving the route.")
		quit(1)
		return
	var recalculated_route: PackedVector3Array = route_probe.get("landmark_route_points")
	if recalculated_route.size() < 2 or recalculated_route[recalculated_route.size() - 1].distance_to(Vector3(48.0, 0.0, 48.0)) > 0.1:
		push_error("Off-route recalculation did not preserve the validated shared-location destination.")
		quit(1)
		return
	# تحديث التوجيه بعد الابتعاد يجب أن يعيد بناء المسار ويعرض إشعار إعادة الحساب فقط عند النجاح.
	player_probe.global_position = Vector3(24.0, 0.0, 24.0)
	route_probe.set("landmark_navigation_target", Vector3(48.0, 0.0, 48.0))
	route_probe.set("landmark_navigation_key", "shared_location")
	route_probe.set("landmark_navigation_active", true)
	route_probe.set("landmark_route_points", PackedVector3Array([Vector3.ZERO, Vector3(1.0, 0.0, 1.0)]))
	route_probe.set("landmark_route_index", 1)
	route_probe.set("navigation_off_route_time", 1.25)
	route_probe.call("_update_landmark_route_deviation")
	var rerouted_points: PackedVector3Array = route_probe.get("landmark_route_points")
	if not bool(route_probe.get("landmark_navigation_active")) or rerouted_points.size() < 2 or rerouted_points[rerouted_points.size() - 1].distance_to(Vector3(48.0, 0.0, 48.0)) > 0.1 or float(route_probe.get("navigation_route_notice_remaining")) <= 0.0:
		push_error("A successful off-route update did not rebuild the safe route and show its recalculation notice.")
		quit(1)
		return
	player_probe.global_position = Vector3.ZERO
	# فشل إعادة حساب المسار يجب أن يلغي المتابعة دون عرض إشعار نجاح إعادة التوجيه.
	marker_probe.visible = true
	route_probe.set("landmark_navigation_target", Vector3(300.0, 0.0, 0.0))
	route_probe.set("landmark_navigation_key", "shared_location")
	route_probe.set("landmark_navigation_active", true)
	route_probe.set("landmark_route_points", valid_shared_route)
	route_probe.set("navigation_route_notice_remaining", 0.0)
	if bool(route_probe.call("_recalculate_active_landmark_route")) or bool(route_probe.get("landmark_navigation_active")) or marker_probe.visible or not (route_probe.get("landmark_route_points") as PackedVector3Array).is_empty():
		push_error("An invalid shared-location reroute did not safely cancel and clear navigation.")
		quit(1)
		return
	if float(route_probe.get("navigation_route_notice_remaining")) != 0.0:
		push_error("A failed shared-location reroute left a misleading reroute-success notice.")
		quit(1)
		return
	# التدخل اليدوي يلغي توجيه الموقع فقط، دون فتح نافذة إلغاء مهمة.
	player_probe.call("begin_auto_navigation")
	player_probe.call("set_auto_navigation_direction", Vector3(0.0, 0.0, -1.0))
	player_probe.set("auto_navigation_cancelled", true)
	route_probe.set("landmark_navigation_key", "shared_location")
	route_probe.set("landmark_navigation_active", true)
	route_probe.set("landmark_route_points", valid_shared_route)
	route_probe.set("landmark_route_index", 1)
	marker_probe.visible = true
	route_probe.call("_cancel_shared_location_navigation_for_manual_input")
	if bool(route_probe.get("landmark_navigation_active")) or str(route_probe.get("landmark_navigation_key")) != "" or not (route_probe.get("landmark_route_points") as PackedVector3Array).is_empty() or marker_probe.visible or bool(player_probe.get("auto_navigation_active")):
		push_error("Manual movement did not cleanly cancel shared-location navigation.")
		quit(1)
		return
	var main_script: Script = load("res://scripts/main.gd")
	if main_script == null:
		push_error("Main scene script could not be loaded for vehicle-follow cleanup validation.")
		quit(1)
		return
	var main_probe: Node3D = main_script.new() as Node3D
	if main_probe == null:
		push_error("Main scene test instance could not be created.")
		quit(1)
		return
	route_probe.name = "MissionManager"
	marker_probe.visible = true
	root.remove_child(route_probe)
	main_probe.add_child(route_probe)
	# فشل بناء وجهة جديدة بالاسكوتر يجب ألا يمحو مسارًا صالحًا قيد المتابعة.
	var invalid_route_vehicle_script: Script = load("res://scripts/vehicle_controller.gd")
	var invalid_route_vehicle: CharacterBody3D = invalid_route_vehicle_script.new() as CharacterBody3D
	root.add_child(invalid_route_vehicle)
	invalid_route_vehicle.global_position = Vector3(200.0, 0.0, 0.0)
	main_probe.set("city_vehicle", invalid_route_vehicle)
	main_probe.set("vehicle_occupied", true)
	var preserved_vehicle_route := PackedVector3Array([Vector3(4.0, 0.0, 4.0), Vector3(8.0, 0.0, 8.0)])
	main_probe.set("_shared_location_vehicle_following", true)
	main_probe.set("_shared_location_vehicle_target", Vector3(8.0, 0.0, 8.0))
	main_probe.set("_shared_location_vehicle_route", preserved_vehicle_route)
	main_probe.set("_shared_location_vehicle_route_index", 1)
	if bool(main_probe.call("begin_shared_location_navigation", Vector3.ZERO)):
		push_error("An unreachable new scooter destination unexpectedly started navigation.")
		quit(1)
		return
	if not bool(main_probe.get("_shared_location_vehicle_following")) or (main_probe.get("_shared_location_vehicle_route") as PackedVector3Array) != preserved_vehicle_route or int(main_probe.get("_shared_location_vehicle_route_index")) != 1 or main_probe.get("_shared_location_vehicle_target") != Vector3(8.0, 0.0, 8.0):
		push_error("A rejected scooter destination overwrote the previously active vehicle route.")
		quit(1)
		return
	main_probe.set("vehicle_occupied", false)
	root.remove_child(invalid_route_vehicle)
	invalid_route_vehicle.free()
	main_probe.set("_shared_location_vehicle_following", true)
	main_probe.set("_shared_location_vehicle_target", Vector3(24.0, 0.0, 24.0))
	main_probe.set("_shared_location_vehicle_route", PackedVector3Array([Vector3.ZERO, Vector3(24.0, 0.0, 24.0)]))
	main_probe.set("_shared_location_vehicle_route_index", 1)
	main_probe.call("_update_shared_location_vehicle_follow")
	if bool(main_probe.get("_shared_location_vehicle_following")) or not (main_probe.get("_shared_location_vehicle_route") as PackedVector3Array).is_empty() or int(main_probe.get("_shared_location_vehicle_route_index")) != 0:
		push_error("Losing vehicle occupancy did not clear the scooter's shared-location follow state.")
		quit(1)
		return
	if marker_probe.visible or not (main_probe.get("_shared_location_vehicle_target") as Vector3).is_zero_approx():
		push_error("Losing vehicle occupancy did not hide the shared-location marker and clear its target.")
		quit(1)
		return
	# Every vehicle-follow termination path shares the same complete cleanup.
	main_probe.set("_shared_location_vehicle_following", true)
	main_probe.set("_shared_location_vehicle_target", Vector3(12.0, 0.0, 8.0))
	main_probe.set("_shared_location_vehicle_route", PackedVector3Array([Vector3.ZERO, Vector3(12.0, 0.0, 8.0)]))
	main_probe.set("_shared_location_vehicle_route_index", 1)
	marker_probe.visible = true
	main_probe.call("_clear_shared_location_vehicle_follow")
	if bool(main_probe.get("_shared_location_vehicle_following")) or not (main_probe.get("_shared_location_vehicle_target") as Vector3).is_zero_approx() or not (main_probe.get("_shared_location_vehicle_route") as PackedVector3Array).is_empty() or int(main_probe.get("_shared_location_vehicle_route_index")) != 0 or marker_probe.visible:
		push_error("Shared-location vehicle follow cleanup did not reset every state field and hide the marker.")
		quit(1)
		return
	# النزول من المركبة يجب أن يمسح الهدف والفهرس أيضًا، حتى عند غياب لاعب الاختبار.
	var vehicle_script: Script = load("res://scripts/vehicle_controller.gd")
	var vehicle_probe := vehicle_script.new() as CharacterBody3D
	if vehicle_probe == null:
		push_error("Vehicle controller test instance could not be created.")
		quit(1)
		return
	root.add_child(vehicle_probe)
	main_probe.set("city_vehicle", vehicle_probe)
	main_probe.set("vehicle_occupied", true)
	main_probe.set("_shared_location_vehicle_following", true)
	main_probe.set("_shared_location_vehicle_target", Vector3(18.0, 0.0, 9.0))
	main_probe.set("_shared_location_vehicle_route", PackedVector3Array([Vector3.ZERO, Vector3(18.0, 0.0, 9.0)]))
	main_probe.set("_shared_location_vehicle_route_index", 1)
	vehicle_probe.call("set_auto_navigation_controls", 2.5, 0.6)
	marker_probe.visible = true
	main_probe.call("_exit_player_vehicle")
	if bool(main_probe.get("_shared_location_vehicle_following")) or not (main_probe.get("_shared_location_vehicle_target") as Vector3).is_zero_approx() or not (main_probe.get("_shared_location_vehicle_route") as PackedVector3Array).is_empty() or int(main_probe.get("_shared_location_vehicle_route_index")) != 0:
		push_error("Exiting the vehicle left stale shared-location follow state.")
		quit(1)
		return
	if marker_probe.visible or float(vehicle_probe.get("auto_navigation_speed")) >= 0.0 or bool(vehicle_probe.get("drive_pressed")) or not bool(vehicle_probe.get("brake_pressed")):
		push_error("Exiting the vehicle did not stop auto-drive and hide the shared-location marker.")
		quit(1)
		return
	# أي تدخل يدوي من أزرار المركبة يجب أن يوقف متابعة الموقع فورًا.
	main_probe.set("vehicle_occupied", true)
	for control_case in [
		{"method": "set_drive", "args": [true]},
		{"method": "set_brake", "args": [true]},
		{"method": "set_reverse", "args": [true]},
		{"method": "set_steering", "args": [0.5]}
	]:
		main_probe.set("_shared_location_vehicle_following", true)
		main_probe.set("_shared_location_vehicle_target", Vector3(18.0, 0.0, 9.0))
		main_probe.set("_shared_location_vehicle_route", PackedVector3Array([Vector3.ZERO, Vector3(18.0, 0.0, 9.0)]))
		main_probe.set("_shared_location_vehicle_route_index", 1)
		vehicle_probe.call("set_auto_navigation_controls", 2.5, 0.6)
		marker_probe.visible = true
		vehicle_probe.callv(str(control_case["method"]), control_case["args"])
		if not bool(vehicle_probe.get("auto_navigation_interrupted")):
			push_error("A manual vehicle control did not mark shared-location following as interrupted.")
			quit(1)
			return
		main_probe.call("_update_shared_location_vehicle_follow")
		if bool(main_probe.get("_shared_location_vehicle_following")) or not (main_probe.get("_shared_location_vehicle_route") as PackedVector3Array).is_empty() or marker_probe.visible:
			push_error("Manual vehicle input did not stop auto-follow and clear its route and marker.")
			quit(1)
			return
	# بدء مهمة أو وظيفة أثناء متابعة الاسكوتر يجب أن ينهي المتابعة ويوقف المحرك.
	for activity_case in [
		{"mission_running": true, "job_running": false},
		{"mission_running": false, "job_running": true}
	]:
		route_probe.set("mission_running", bool(activity_case["mission_running"]))
		route_probe.set("job_running", bool(activity_case["job_running"]))
		main_probe.set("vehicle_occupied", true)
		main_probe.set("_shared_location_vehicle_following", true)
		main_probe.set("_shared_location_vehicle_target", Vector3(18.0, 0.0, 9.0))
		main_probe.set("_shared_location_vehicle_route", PackedVector3Array([Vector3.ZERO, Vector3(18.0, 0.0, 9.0)]))
		main_probe.set("_shared_location_vehicle_route_index", 1)
		vehicle_probe.call("set_auto_navigation_controls", 2.5, 0.6)
		marker_probe.visible = true
		main_probe.call("_update_shared_location_vehicle_follow")
		if bool(main_probe.get("_shared_location_vehicle_following")) or not (main_probe.get("_shared_location_vehicle_route") as PackedVector3Array).is_empty() or marker_probe.visible:
			push_error("Starting a mission or job did not cancel scooter shared-location following.")
			quit(1)
			return
		if float(vehicle_probe.get("auto_navigation_speed")) >= 0.0 or bool(vehicle_probe.get("drive_pressed")) or not bool(vehicle_probe.get("brake_pressed")):
			push_error("Starting a mission or job did not stop scooter auto-drive.")
			quit(1)
			return
	route_probe.set("mission_running", false)
	route_probe.set("job_running", false)
	# لا تُنهِ متابعة الاسكوتر قبل الوصول الفعلي إلى نطاق الوجهة النهائي (2 متر).
	main_probe.set("vehicle_occupied", true)
	vehicle_probe.global_position = Vector3(18.0, 0.0, 11.5)
	main_probe.set("_shared_location_vehicle_following", true)
	main_probe.set("_shared_location_vehicle_target", Vector3(18.0, 0.0, 9.0))
	main_probe.set("_shared_location_vehicle_route", PackedVector3Array([Vector3.ZERO, Vector3(18.0, 0.0, 9.0)]))
	main_probe.set("_shared_location_vehicle_route_index", 1)
	vehicle_probe.call("set_auto_navigation_controls", 2.5, 0.0)
	marker_probe.visible = true
	main_probe.call("_update_shared_location_vehicle_follow")
	if not bool(main_probe.get("_shared_location_vehicle_following")) or int(main_probe.get("_shared_location_vehicle_route_index")) != 1 or not marker_probe.visible:
		push_error("Scooter navigation completed while still 2.5 meters from the final destination.")
		quit(1)
		return
	# عند وصول الاسكوتر إلى آخر نقطة، يجب إنهاء التوجيه وإخفاء العلامة تلقائيًا.
	main_probe.set("vehicle_occupied", true)
	vehicle_probe.global_position = Vector3(18.0, 0.0, 9.0)
	main_probe.set("_shared_location_vehicle_following", true)
	main_probe.set("_shared_location_vehicle_target", Vector3(18.0, 0.0, 9.0))
	main_probe.set("_shared_location_vehicle_route", PackedVector3Array([Vector3(18.0, 0.0, 9.0)]))
	main_probe.set("_shared_location_vehicle_route_index", 0)
	vehicle_probe.call("set_auto_navigation_controls", 2.5, 0.0)
	marker_probe.visible = true
	main_probe.call("_update_shared_location_vehicle_follow")
	if bool(main_probe.get("_shared_location_vehicle_following")) or not (main_probe.get("_shared_location_vehicle_route") as PackedVector3Array).is_empty() or int(main_probe.get("_shared_location_vehicle_route_index")) != 0:
		push_error("Reaching the final scooter waypoint did not complete shared-location navigation.")
		quit(1)
		return
	if marker_probe.visible or float(vehicle_probe.get("auto_navigation_speed")) >= 0.0 or bool(vehicle_probe.get("drive_pressed")) or not bool(vehicle_probe.get("brake_pressed")):
		push_error("Reaching the shared-location destination did not stop the scooter and hide its marker.")
		quit(1)
		return
	main_probe.set("vehicle_occupied", false)
	root.remove_child(vehicle_probe)
	vehicle_probe.free()
	main_probe.remove_child(route_probe)
	main_probe.free()
	route_probe.free()
	var vehicle_controller_script: Script = load("res://scripts/vehicle_controller.gd")
	if vehicle_controller_script == null:
		push_error("Vehicle controller script could not be loaded for scooter follow validation.")
		quit(1)
		return
	var vehicle_control_probe: CharacterBody3D = vehicle_controller_script.new()
	vehicle_control_probe.set_auto_navigation_controls(3.0, 0.4)
	if not is_equal_approx(float(vehicle_control_probe.get("auto_navigation_speed")), 3.0) or not bool(vehicle_control_probe.get("drive_pressed")) or bool(vehicle_control_probe.get("brake_pressed")) or not is_equal_approx(float(vehicle_control_probe.get("steering_input")), 0.4) or bool(vehicle_control_probe.get("auto_navigation_interrupted")):
		push_error("Scooter auto-follow did not initialize its forward and steering controls correctly.")
		quit(1)
		return
	vehicle_control_probe.set_brake(true)
	if not bool(vehicle_control_probe.get("auto_navigation_interrupted")) or not is_equal_approx(float(vehicle_control_probe.get("auto_navigation_speed")), -1.0) or not bool(vehicle_control_probe.get("brake_pressed")):
		push_error("Manual braking did not interrupt scooter auto-follow.")
		quit(1)
		return
	vehicle_control_probe.set_auto_navigation_controls(9.0, 2.0)
	if not is_equal_approx(float(vehicle_control_probe.get("auto_navigation_speed")), 6.0) or not is_equal_approx(float(vehicle_control_probe.get("steering_input")), 1.0):
		push_error("Scooter auto-follow controls were not clamped to safe configured limits.")
		quit(1)
		return
	vehicle_control_probe.set_steering(-0.5)
	if not bool(vehicle_control_probe.get("auto_navigation_interrupted")) or not is_equal_approx(float(vehicle_control_probe.get("auto_navigation_speed")), -1.0):
		push_error("Manual steering did not interrupt scooter auto-follow.")
		quit(1)
		return
	vehicle_control_probe.set_auto_navigation_controls(2.0, -0.2)
	vehicle_control_probe.clear_auto_navigation_controls()
	if not is_equal_approx(float(vehicle_control_probe.get("auto_navigation_speed")), -1.0) or bool(vehicle_control_probe.get("drive_pressed")) or not bool(vehicle_control_probe.get("brake_pressed")) or not is_zero_approx(float(vehicle_control_probe.get("steering_input"))):
		push_error("Clearing scooter auto-follow did not return controls to a safe stopped state.")
		quit(1)
		return
	vehicle_control_probe.free()
	var shared_location_hud_script: Script = load("res://scripts/city_hud.gd")
	if shared_location_hud_script == null:
		push_error("City HUD script could not be loaded for shared-location validation.")
		quit(1)
		return
	var location_probe: Node = shared_location_hud_script.new()
	var camera_forward := Vector3(0.0, 0.0, -1.0)
	var camera_right := Vector3(1.0, 0.0, 0.0)
	var arrow_cases := [
		{"direction": Vector3(0.0, 0.0, -1.0), "expected": -PI * 0.5},
		{"direction": Vector3(1.0, 0.0, 0.0), "expected": 0.0},
		{"direction": Vector3(0.0, 0.0, 1.0), "expected": PI * 0.5},
		{"direction": Vector3(-1.0, 0.0, 0.0), "expected": -PI}
	]
	for arrow_case in arrow_cases:
		var arrow_rotation := float(location_probe.call("calculate_shared_location_arrow_rotation", arrow_case["direction"], camera_forward, camera_right))
		if not is_equal_approx(wrapf(arrow_rotation - float(arrow_case["expected"]), -PI, PI), 0.0):
			push_error("The shared-location direction arrow points incorrectly for a camera-relative cardinal direction.")
			quit(1)
			return
	var rotated_camera_forward := Vector3(1.0, 0.0, 0.0)
	var rotated_camera_right := Vector3(0.0, 0.0, 1.0)
	var rotated_arrow := float(location_probe.call("calculate_shared_location_arrow_rotation", Vector3(1.0, 0.0, 0.0), rotated_camera_forward, rotated_camera_right))
	if not is_equal_approx(rotated_arrow, -PI * 0.5):
		push_error("The shared-location arrow did not account for a camera rotated by 90 degrees.")
		quit(1)
		return
	var zero_basis_arrow := float(location_probe.call("calculate_shared_location_arrow_rotation", Vector3(1.0, 0.0, 0.0), Vector3.ZERO, camera_right))
	if not is_equal_approx(zero_basis_arrow, 0.0):
		push_error("The shared-location arrow calculation did not safely handle a degenerate camera basis.")
		quit(1)
		return
	var pitched_forward := Vector3(0.0, 0.8, -0.6)
	var pitched_right := Vector3(1.0, 0.0, 0.0)
	var pitched_arrow := float(location_probe.call("calculate_shared_location_arrow_rotation", Vector3(1.0, 0.0, 0.0), pitched_forward, pitched_right))
	if not is_equal_approx(pitched_arrow, 0.0):
		push_error("The shared-location arrow skewed when the camera was pitched.")
		quit(1)
		return
	var vertical_camera_arrow := float(location_probe.call("calculate_shared_location_arrow_rotation", Vector3(0.0, 0.0, -1.0), Vector3.UP, Vector3.RIGHT))
	if not is_equal_approx(vertical_camera_arrow, -PI * 0.5):
		push_error("The shared-location arrow did not retain a stable heading when the camera pointed vertically.")
		quit(1)
		return
	if not bool(location_probe.call("should_hide_shared_location_arrow", 2.1, false)):
		push_error("The walking direction arrow did not hide inside its 2.5-meter arrival threshold.")
		quit(1)
		return
	if bool(location_probe.call("should_hide_shared_location_arrow", 2.1, true)) or not bool(location_probe.call("should_hide_shared_location_arrow", 2.0, true)):
		push_error("The scooter direction arrow did not stay visible until its 2-meter arrival threshold.")
		quit(1)
		return
	if bool(location_probe.call("should_hide_shared_location_arrow", 2.6, false)):
		push_error("The walking direction arrow disappeared before its 2.5-meter arrival threshold.")
		quit(1)
		return
	if not location_probe.call("parse_shared_location_message", "KINGLOC1|nan|0|0").is_empty():
		push_error("A non-finite shared-location coordinate was accepted.")
		quit(1)
		return
	if not location_probe.call("parse_shared_location_message", "KINGLOC1|0|inf|0").is_empty():
		push_error("An infinite shared-location coordinate was accepted.")
		quit(1)
		return
	if not location_probe.call("build_shared_location_message", Vector3(INF, 0.0, 0.0)).is_empty():
		push_error("A non-finite local position was encoded as a shared location.")
		quit(1)
		return
	location_probe.free()
	var social := root.get_node_or_null("SocialChatManager")
	if social == null:
		push_error("SocialChatManager autoload did not initialize.")
		quit(1)
		return

	var invitation_overlay_script: Script = load("res://scripts/invitation_overlay.gd")
	if invitation_overlay_script == null:
		push_error("Unified invitation overlay script could not be loaded.")
		quit(1)
		return
	var expiry_probe: Control = invitation_overlay_script.new()
	if not is_equal_approx(expiry_probe.get_panel_width_for_viewport(360.0), 314.0):
		push_error("The invitation panel width changed unexpectedly on a standard 360px phone screen.")
		quit(1)
		return
	if not is_equal_approx(expiry_probe.get_panel_width_for_viewport(320.0), 296.0):
		push_error("The invitation panel did not shrink to preserve margins on a 320px phone screen.")
		quit(1)
		return
	if not is_equal_approx(expiry_probe.get_panel_width_for_viewport(240.0), 216.0):
		push_error("The invitation panel did not adapt to a narrow 240px viewport.")
		quit(1)
		return
	for viewport_width in [20.0, 180.0, 200.0, 240.0, 320.0, 360.0, 800.0, 1280.0]:
		var panel_layout: Vector2 = expiry_probe.get_panel_layout_for_viewport(viewport_width)
		if panel_layout.x < 0.0 or panel_layout.y < 0.0 or panel_layout.x * 2.0 + panel_layout.y > viewport_width:
			push_error("The invitation panel or its horizontal margins escaped the viewport after a portrait/landscape size change.")
			quit(1)
			return
	for viewport_height in [20.0, 180.0, 240.0, 320.0, 360.0, 800.0, 1280.0]:
		var vertical_layout: Vector2 = expiry_probe.get_panel_vertical_layout(viewport_height)
		if vertical_layout.x < 0.0 or vertical_layout.y < 0.0 or vertical_layout.x + vertical_layout.y > viewport_height:
			push_error("The invitation panel escaped the viewport height after switching to landscape orientation.")
			quit(1)
			return
	var known_created_at := "2026-11-16T10:00:00"
	var known_created_timestamp := float(Time.get_unix_time_from_datetime_string(known_created_at))
	var anchored_deadline: float = expiry_probe.resolve_invitation_expiry({"created_at": known_created_at}, known_created_timestamp + 10.0)
	if not is_equal_approx(anchored_deadline, known_created_timestamp + 30.0):
		push_error("A server creation timestamp did not anchor the invitation to its original 30-second lifetime.")
		quit(1)
		return
	var extended_deadline: float = expiry_probe.resolve_invitation_expiry({"created_at": known_created_at, "expires_at": known_created_timestamp + 90.0}, known_created_timestamp + 10.0)
	if not is_equal_approx(extended_deadline, known_created_timestamp + 30.0):
		push_error("A supplied invitation deadline extended the approved 30-second lifetime.")
		quit(1)
		return
	var anchored_shortened_deadline: float = expiry_probe.resolve_invitation_expiry({"created_at": known_created_at, "expires_at": known_created_timestamp + 20.0}, known_created_timestamp + 10.0)
	if not is_equal_approx(anchored_shortened_deadline, known_created_timestamp + 20.0):
		push_error("A shorter supplied invitation deadline was not respected.")
		quit(1)
		return
	var receipt_deadline: float = expiry_probe.resolve_invitation_expiry({"expires_at": 2000.0}, 1000.0)
	if not is_equal_approx(receipt_deadline, 1030.0):
		push_error("An invitation without a trustworthy creation timestamp did not receive a 30-second receipt cap.")
		quit(1)
		return
	var malformed_created_deadline: float = expiry_probe.resolve_invitation_expiry({"created_at": "not-a-date"}, 1000.0)
	if not is_equal_approx(malformed_created_deadline, 1030.0):
		push_error("An invitation with a malformed creation timestamp was granted a fresh lifetime.")
		quit(1)
		return
	var future_created_deadline: float = expiry_probe.resolve_invitation_expiry({"created_at": "2026-11-17T10:00:00"}, 1000.0)
	if not is_equal_approx(future_created_deadline, 1030.0):
		push_error("An invitation with a future creation timestamp was granted a fresh lifetime.")
		quit(1)
		return
	expiry_probe.free()
	var compact_overlay: Control = invitation_overlay_script.new()
	root.add_child(compact_overlay)
	await process_frame
	var content_scroll := compact_overlay.get_node_or_null("UnifiedInvitationPanel/InvitationContentScroll")
	if not content_scroll is ScrollContainer:
		push_error("The invitation panel did not create its compact-height scroll container.")
		quit(1)
		return
	if content_scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED or content_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_AUTO:
		push_error("The invitation panel scroll container does not preserve vertical-only compact content scrolling.")
		quit(1)
		return
	var accept_button := compact_overlay.find_child("AcceptInvitationButton", true, false)
	var decline_button := compact_overlay.find_child("DeclineInvitationButton", true, false)
	if not accept_button is Button or not decline_button is Button:
		push_error("The invitation panel action buttons could not be found for touch-target validation.")
		quit(1)
		return
	if accept_button.custom_minimum_size.y < 44.0 or decline_button.custom_minimum_size.y < 44.0:
		push_error("Invitation accept/decline touch targets are smaller than the 44px mobile target.")
		quit(1)
		return
	var meeting_invite_accepted := [0]
	compact_overlay.invitation_accepted.connect(func(_item: Dictionary) -> void:
		meeting_invite_accepted[0] += 1
	)
	compact_overlay.call("enqueue_invitation", {
		"invite_id": "550e8400-e29b-41d4-a716-446655440101",
		"type": "group_meeting_invite",
		"title": "دعوة للتجمع",
		"expires_at": float(Time.get_unix_time_from_system()) + 25.0
	})
	await process_frame
	if not accept_button.disabled or not decline_button.disabled:
		push_error("An invitation without a server response flow exposed active accept/decline buttons.")
		quit(1)
		return
	compact_overlay.call("_finish_current", true)
	if meeting_invite_accepted[0] != 0 or compact_overlay.call("get_pending_invitation_count") != 1:
		push_error("An unsupported group-meeting invitation was incorrectly accepted or dismissed.")
		quit(1)
		return
	compact_overlay.call("clear_pending_invitations")
	compact_overlay.call("enqueue_invitation", {
		"invite_id": "550e8400-e29b-41d4-a716-446655440102",
		"type": "group_invite",
		"title": "دعوة للمجموعة",
		"expires_at": float(Time.get_unix_time_from_system()) + 25.0
	})
	await process_frame
	if accept_button.disabled or decline_button.disabled:
		push_error("A group invitation with a verified response flow was incorrectly disabled.")
		quit(1)
		return
	compact_overlay.queue_free()
	await process_frame
	var dedupe_overlay: Control = invitation_overlay_script.new()
	var expired_invitation_ids: Array[String] = []
	dedupe_overlay.invitation_expired.connect(func(invitation: Dictionary) -> void:
		expired_invitation_ids.append(str(invitation.get("invite_id", "")))
	)
	var duplicate_expired_invitation := {
		"invite_id": "550e8400-e29b-41d4-a716-446655440099",
		"expires_at": 1.0
	}
	dedupe_overlay.enqueue_invitation(duplicate_expired_invitation)
	dedupe_overlay.enqueue_invitation(duplicate_expired_invitation)
	if expired_invitation_ids.size() != 1:
		push_error("A repeated realtime delivery re-emitted the same expired invitation.")
		quit(1)
		return
	dedupe_overlay.clear_pending_invitations()
	dedupe_overlay.enqueue_invitation(duplicate_expired_invitation)
	if expired_invitation_ids.size() != 2:
		push_error("Invitation deduplication state was not cleared for a new account session.")
		quit(1)
		return
	dedupe_overlay.free()

	print("SOCIAL_TEST_STAGE: invitation_dedupe_complete")
	var city_hud_script: Script = load("res://scripts/city_hud.gd")
	if city_hud_script == null:
		push_error("City HUD script could not be loaded for group-gather guard tests.")
		quit(1)
		return
	var city_hud: CanvasLayer = city_hud_script.new()
	var gather_scene := Node3D.new()
	root.add_child(gather_scene)
	city_hud.main_scene = gather_scene
	city_hud.group_members.append({"player_id":"friend_test", "display_name":"صديق", "is_leader":false})
	city_hud.receive_group_member_positions([{
		"player_id":"friend_test",
		"display_name":"صديق",
		"position":Vector3(4, 0, 6)
	}])
	if not gather_scene.get_children().is_empty():
		push_error("Group position updates created a standalone gathering marker instead of keeping gathering tied to the leader's current location.")
		quit(1)
		return
	gather_scene.queue_free()
	if not city_hud.can_show_group_gather_button(true, 2, false):
		push_error("A group leader with another member outside an apartment should see the gather button.")
		quit(1)
		return
	if city_hud.can_show_group_gather_button(false, 2, false):
		push_error("A non-leader was allowed to see the group gather button.")
		quit(1)
		return
	if city_hud.can_show_group_gather_button(true, 1, false):
		push_error("A solo leader was allowed to see the group gather button.")
		quit(1)
		return
	if city_hud.can_show_group_gather_button(true, 2, true):
		push_error("The group gather button remained available inside a private apartment.")
		quit(1)
		return
	city_hud.group_meeting_status = Label.new()
	city_hud.call("_request_group_gather_invite")
	if city_hud.group_meeting_status.text != "لم تُرسل الدعوة: خدمة التجمع بين الأجهزة غير مفعّلة بعد.":
		push_error("The gather action did not clearly report that the backend service is unavailable.")
		quit(1)
		return
	for signal_info in city_hud.get_signal_list():
		if str(signal_info.get("name", "")) == "group_gather_invite_requested":
			push_error("The unsupported gather action still exposes an unused local signal.")
			quit(1)
			return
	if not city_hud.can_receive_social_invitation_event("group_invite"):
		push_error("A supported group invitation event was rejected.")
		quit(1)
		return
	if not city_hud.can_receive_social_invitation_event("chat_message") or not city_hud.can_receive_social_invitation_event("direct_message"):
		push_error("Supported realtime chat messages were rejected before reaching the chat renderer.")
		quit(1)
		return
	if city_hud.build_party_announcement_body("المخيم") != "🎉 بدأت حفلة جديدة في المخيم! تعالوا شاركونا." or city_hud.build_party_announcement_body("") != "🎉 بدأت حفلة جديدة في المدينة! تعالوا شاركونا.":
		push_error("The public party announcement did not include a clear location and invitation.")
		quit(1)
		return
	var party_chat_line: String = city_hud.format_public_chat_message("صاحب الحفلة", city_hud.build_party_announcement_body("المخيم"))
	if not party_chat_line.contains("[صاحب الحفلة]") or not party_chat_line.contains("المخيم") or not party_chat_line.contains("بدأت حفلة"):
		push_error("The public party chat line did not show the host name together with the party location.")
		quit(1)
		return
	var own_party_history_line: String = city_hud.format_public_chat_message("صاحب الحفلة", city_hud.build_party_announcement_body("المخيم"))
	if own_party_history_line.contains("[أنت]"):
		push_error("A host's own party announcement history hid the actual host display name.")
		quit(1)
		return
	var unsafe_party_line: String = city_hud.format_public_chat_message("[اسم]", "🎉 [المخيم]")
	if unsafe_party_line.contains("[اسم]") or unsafe_party_line.contains("[المخيم]"):
		push_error("A public party chat line allowed user-controlled BBCode brackets.")
		quit(1)
		return
	var direct_location_destination: Dictionary = city_hud.resolve_shared_location_chat_destination("الأصدقاء", " conversation-123 ")
	if direct_location_destination.get("kind", "") != "direct" or direct_location_destination.get("conversation_id", "") != "conversation-123":
		push_error("Shared-location routing did not preserve the selected direct conversation.")
		quit(1)
		return
	if not city_hud.resolve_shared_location_chat_destination("الأصدقاء", "").is_empty() or not city_hud.resolve_shared_location_chat_destination("غير معروف", "conversation-123").is_empty():
		push_error("Shared-location routing accepted a missing or unsupported conversation instead of blocking a possible public disclosure.")
		quit(1)
		return
	if city_hud.resolve_shared_location_chat_destination("العامة").get("kind", "") != "public" or city_hud.resolve_shared_location_chat_destination("المجموعة").get("kind", "") != "group":
		push_error("Shared-location routing did not recognize the explicit public and group channels.")
		quit(1)
		return
	var location_button_probe := Button.new()
	city_hud.set("social_chat_location_button", location_button_probe)
	city_hud.set("social_chat_channel", "الأصدقاء")
	city_hud.set("selected_friend_conversation_id", "")
	city_hud.call("_update_shared_location_button_state")
	if not location_button_probe.disabled:
		push_error("The location-share button stayed enabled without an open direct conversation.")
		quit(1)
		return
	if location_button_probe.tooltip_text != "اختر محادثة صالحة أولًا لمشاركة موقعك":
		push_error("The disabled location-share button did not explain how to enable it.")
		quit(1)
		return
	city_hud.set("selected_friend_conversation_id", "conversation-123")
	city_hud.call("_update_shared_location_button_state")
	if location_button_probe.disabled:
		push_error("The location-share button stayed disabled after a valid direct conversation was selected.")
		quit(1)
		return
	if location_button_probe.tooltip_text != "مشاركة موقعي في هذه المحادثة":
		push_error("The enabled location-share button did not show its current action.")
		quit(1)
		return
	city_hud.set("social_chat_channel", "غير معروف")
	city_hud.call("_update_shared_location_button_state")
	if not location_button_probe.disabled:
		push_error("The location-share button stayed enabled for an unsupported chat channel.")
		quit(1)
		return
	city_hud.set("social_chat_channel", "العامة")
	city_hud.call("_update_shared_location_button_state")
	if location_button_probe.disabled:
		push_error("The location-share button was disabled in the explicit public channel.")
		quit(1)
		return
	location_button_probe.free()
	var location_message: String = city_hud.build_shared_location_message(Vector3(12.5, 0.0, -34.25))
	var parsed_location: Dictionary = city_hud.parse_shared_location_message(location_message)
	if parsed_location.is_empty() or (parsed_location["position"] as Vector3).distance_to(Vector3(12.5, 0.0, -34.25)) > 0.01:
		push_error("A shared location message did not preserve the sender's in-city coordinates.")
		quit(1)
		return
	var boundary_location := Vector3(250.0, 100.0, -250.0)
	if city_hud.build_shared_location_message(boundary_location).is_empty():
		push_error("A shared location exactly on the supported world boundary was rejected.")
		quit(1)
		return
	for invalid_position in [Vector3(250.001, 0.0, 0.0), Vector3(0.0, 100.001, 0.0), Vector3(0.0, -10.001, 0.0), Vector3(NAN, 0.0, 0.0), Vector3(0.0, 0.0, INF)]:
		if not city_hud.build_shared_location_message(invalid_position).is_empty():
			push_error("An out-of-bounds or non-finite shared location was serialized.")
			quit(1)
			return
	for invalid_message in ["KINGLOC1|250.001|0|0", "KINGLOC1|0|100.001|0", "KINGLOC1|0|-10.001|0", "KINGLOC1|nan|0|0", "KINGLOC1|0|0|inf"]:
		if not city_hud.parse_shared_location_message(invalid_message).is_empty():
			push_error("An out-of-bounds or non-finite received shared location was accepted.")
			quit(1)
			return
	var location_chat_line: String = city_hud.format_public_chat_message("صديق", location_message)
	if not location_chat_line.contains("📍") or not location_chat_line.contains("متابعة") or not location_chat_line.contains("kingloc://"):
		push_error("A shared location chat message did not render a clickable follow action.")
		quit(1)
		return
	if not location_chat_line.contains("[صديق]") or location_chat_line.contains("[أنت]"):
		push_error("A shared-location history line did not preserve the original sender name.")
		quit(1)
		return
	var unsafe_location_line: String = city_hud.format_public_chat_message("[لاعب]", location_message)
	if unsafe_location_line.contains("[لاعب]") or not unsafe_location_line.contains("متابعة"):
		push_error("A shared-location chat line allowed sender-controlled BBCode or lost its follow action.")
		quit(1)
		return
	if not city_hud.parse_shared_location_uri("kingloc://12.5,nan,-34.25").is_empty() or not city_hud.parse_shared_location_uri("kingloc://12.5,0").is_empty():
		push_error("A malformed shared-location follow URI was accepted.")
		quit(1)
		return
	for invalid_location_uri in ["kingloc://250.001,0,0", "kingloc://0,100.001,0", "kingloc://0,-10.001,0", "kingloc://1e309,0,0", "kingloc://12.5,0,-34.25,extra"]:
		if not city_hud.parse_shared_location_uri(invalid_location_uri).is_empty():
			push_error("A malformed, non-finite, or out-of-bounds shared-location URI was accepted.")
			quit(1)
			return
	if not city_hud.parse_shared_location_uri("kingloc://12.5,0,-34.25").has("position"):
		push_error("A shared location follow link could not be parsed.")
		quit(1)
		return
	var boundary_uri_data: Dictionary = city_hud.parse_shared_location_uri("kingloc://250,100,-250")
	if boundary_uri_data.is_empty() or (boundary_uri_data["position"] as Vector3).distance_to(Vector3(250.0, 100.0, -250.0)) > 0.01:
		push_error("A valid shared-location follow link on the world boundary was rejected.")
		quit(1)
		return
	var malformed_location_line: String = city_hud.format_public_chat_message("صديق", "KINGLOC1|250.001|0|0")
	if malformed_location_line.contains("[url=kingloc://") or malformed_location_line.contains("متابعة"):
		push_error("An invalid shared-location message was rendered as an actionable follow link.")
		quit(1)
		return
	if not city_hud.parse_shared_location_message("KINGLOC1|9999|0|9999").is_empty():
		push_error("An out-of-bounds shared location was accepted.")
		quit(1)
		return
	if city_hud.can_receive_social_invitation_event("group_meeting_invite") or city_hud.can_receive_social_invitation_event("apartment_invite"):
		push_error("An unsupported gather or apartment invitation event was allowed into the invitation overlay.")
		quit(1)
		return
	city_hud.group_meeting_status.free()
	city_hud.group_meeting_status = null

	var male_portrait_scene: String = city_hud.get_friend_character_scene_path({"selected_character_id":"eg_m_adam"})
	var female_portrait_scene: String = city_hud.get_friend_character_scene_path({"selected_character_id":"eg_f_layan"})
	if male_portrait_scene != "res://scenes/characters/avatar_visual.tscn" or female_portrait_scene != "res://scenes/characters/avatar_visual.tscn":
		push_error("A supported male/female roster ID did not resolve to the in-game character preview scene.")
		quit(1)
		return
	var avatar_scene: PackedScene = load("res://scenes/characters/avatar_visual.tscn") as PackedScene
	if avatar_scene == null:
		push_error("The in-game character preview scene could not be loaded.")
		quit(1)
		return
	var male_avatar := avatar_scene.instantiate()
	root.add_child(male_avatar)
	male_avatar.call("apply_character_identity", "eg_m_adam")
	if str(male_avatar.get("current_outfit")) != "men_formal" or str(male_avatar.get("current_hairstyle")) != "short":
		push_error("A male roster identity did not apply its approved in-game character preset.")
		quit(1)
		return
	male_avatar.queue_free()
	var female_avatar := avatar_scene.instantiate()
	root.add_child(female_avatar)
	female_avatar.call("apply_character_identity", "eg_f_layan")
	if str(female_avatar.get("current_outfit")) != "women_formal" or str(female_avatar.get("current_hairstyle")) != "long":
		push_error("A female roster identity did not apply its approved in-game character preset.")
		quit(1)
		return
	female_avatar.queue_free()
	var male_portrait: Control = city_hud.call("_build_friend_character_portrait", {"selected_character_id":"eg_m_adam"}) as Control
	root.add_child(male_portrait)
	await process_frame
	await process_frame
	if not male_portrait is SubViewportContainer:
		push_error("A valid in-game male character did not produce a rendered viewport portrait.")
		quit(1)
		return
	var portrait_viewport := male_portrait.get_child(0) as SubViewport
	var portrait_world := portrait_viewport.get_child(0) as Node3D
	var portrait_character := portrait_world.get_child(2) as Node3D
	if portrait_viewport.size.x <= 0 or portrait_viewport.size.y <= 0 or portrait_character == null or str(portrait_character.get("current_outfit")) != "men_formal":
		push_error("The male friend portrait viewport did not render the selected in-game character preset.")
		quit(1)
		return
	male_portrait.free()
	var female_portrait: Control = city_hud.call("_build_friend_character_portrait", {"character_id":"eg_f_layan"}) as Control
	root.add_child(female_portrait)
	await process_frame
	await process_frame
	if not female_portrait is SubViewportContainer:
		push_error("A valid in-game female character did not produce a rendered viewport portrait.")
		quit(1)
		return
	var female_viewport := female_portrait.get_child(0) as SubViewport
	var female_world := female_viewport.get_child(0) as Node3D
	var female_character := female_world.get_child(2) as Node3D
	if female_viewport.size.x <= 0 or female_viewport.size.y <= 0 or female_character == null or str(female_character.get("current_outfit")) != "women_formal":
		push_error("The female friend portrait viewport did not render the selected in-game character preset.")
		quit(1)
		return
	female_portrait.free()
	var unknown_portrait: Control = city_hud.call("_build_friend_character_portrait", {"selected_character_id":"xx_m_unknown"}) as Control
	root.add_child(unknown_portrait)
	if unknown_portrait is SubViewportContainer or unknown_portrait.name != "FriendCharacterPortraitFallback":
		push_error("An unknown character did not receive the neutral in-game portrait fallback.")
		quit(1)
		return
	unknown_portrait.free()
	if city_hud.get_friend_character_scene_path({"selected_character_id":"xx_m_unknown"}) != "":
		push_error("An unknown character ID was allowed to resolve to a portrait scene.")
		quit(1)
		return
	if city_hud.get_friend_character_scene_path({"selected_character_id":"https://example.com/avatar.png"}) != "":
		push_error("The friend portrait resolver accepted an external image URL.")
		quit(1)
		return
	if city_hud.get_friend_character_scene_path({"selected_character_id":"../../outside"}) != "":
		push_error("The friend portrait resolver accepted a path traversal value.")
		quit(1)
		return
	if city_hud.get_friend_character_scene_path({"avatar_texture":null}) != "":
		push_error("The friend portrait resolver accepted a texture without an in-game character ID.")
		quit(1)
		return

	var online_invite_friends: Array = city_hud.get_online_group_invite_friends([
		{"player_code":"AB12CD34EF", "display_name":"متصل", "is_online":true},
		{"player_code":"CD34EF56GH", "display_name":"غير متصل", "is_online":false},
		{"player_code":"EF56GH78JK", "display_name":"حالة متصلة", "status":"online"},
		{"player_code":"GH78JK90LM", "display_name":"غير معروف"}
	])
	if online_invite_friends.size() != 2:
		push_error("The group invite picker did not restrict its results to explicitly online friends.")
		quit(1)
		return

	if city_hud.has_group_invite_presence_metadata([
		{"player_code":"AB12CD34EF", "display_name":"صديق"}
	]):
		push_error("The group invite picker treated a friend list without presence fields as having online status.")
		quit(1)
		return
	if not city_hud.has_group_invite_presence_metadata([
		{"player_code":"AB12CD34EF", "display_name":"صديق", "is_online":false}
	]):
		push_error("The group invite picker failed to recognize explicit offline presence metadata.")
		quit(1)
		return

	if str(online_invite_friends[0].get("player_code", "")) != "AB12CD34EF" or str(online_invite_friends[1].get("player_code", "")) != "EF56GH78JK":
		push_error("The group invite picker returned an offline or unknown-presence friend.")
		quit(1)
		return

	var deferred_invite := {"expires_at": 200.0}
	if not city_hud.resolve_deferred_invitation_acceptance(deferred_invite, true, 199.0):
		push_error("A still-valid queued invitation acceptance was changed.")
		quit(1)
		return
	if city_hud.resolve_deferred_invitation_acceptance(deferred_invite, true, 200.0):
		push_error("An expired queued invitation acceptance was not downgraded to decline.")
		quit(1)
		return
	if city_hud.resolve_deferred_invitation_acceptance({}, true, 100.0):
		push_error("A queued acceptance without a verified expiry deadline was allowed.")
		quit(1)
		return
	if city_hud.resolve_deferred_invitation_acceptance(deferred_invite, false, 199.0):
		push_error("A queued decline was incorrectly converted into acceptance.")
		quit(1)
		return
	var first_invite_id := "550e8400-e29b-41d4-a716-446655440000"
	var second_invite_id := "550e8400-e29b-41d4-a716-446655440001"
	if not city_hud.can_submit_group_invitation_response("", first_invite_id):
		push_error("A valid first group invitation response was blocked.")
		quit(1)
		return
	if city_hud.can_submit_group_invitation_response(first_invite_id, second_invite_id) or city_hud.can_submit_group_invitation_response("", ""):
		push_error("Overlapping or empty group invitation responses were allowed.")
		quit(1)
		return
	if city_hud.can_submit_group_invitation_response("", "invite-1"):
		push_error("A malformed group invitation UUID passed the HUD response guard.")
		quit(1)
		return
	if not city_hud.can_accept_social_invitation_payload("chat:invites:AB12CD34EF", "AB12CD34EF", first_invite_id):
		push_error("A valid private invitation topic and UUID were rejected.")
		quit(1)
		return
	if city_hud.can_accept_social_invitation_payload("chat:invites:OTHER12345", "AB12CD34EF", first_invite_id):
		push_error("An invitation from another player's private topic was accepted.")
		quit(1)
		return
	if city_hud.can_accept_social_invitation_payload("chat:invites:AB12CD34EF", "bad-code", first_invite_id):
		push_error("An invitation with an invalid local player code was accepted.")
		quit(1)
		return
	if city_hud.can_accept_social_invitation_payload("chat:invites:AB12CD34EF", "AB12CD34EF", "not-a-uuid"):
		push_error("An invitation with a malformed id was accepted into the HUD.")
		quit(1)
		return
	city_hud.free()

	print("SOCIAL_TEST_STAGE: hud_guards_complete")
	var saved_topics: Dictionary = social._realtime_topics.duplicate(true)
	var saved_join_refs: Dictionary = social._realtime_join_refs.duplicate(true)
	var saved_ready_topics: Dictionary = social._realtime_ready_topics.duplicate(true)
	social._realtime_topics = {"chat:direct:joined": true}
	social._realtime_join_refs = {"chat:direct:joined": "ci-join-ref"}
	social._realtime_ready_topics = {}
	if social.is_realtime_topic_subscribed("chat:direct:joined"):
		push_error("A pending realtime join was treated as ready before server acknowledgement.")
		quit(1)
		return
	social._realtime_ready_topics = {"chat:direct:joined": true}
	if not social.is_realtime_join_ack_current("chat:direct:joined", "ci-join-ref"):
		push_error("The current realtime join acknowledgement was not recognized.")
		quit(1)
		return
	if social.is_realtime_join_ack_current("chat:direct:joined", "stale-join-ref") or social.is_realtime_join_ack_current("chat:direct:unjoined", "ci-join-ref"):
		push_error("A stale or unrelated realtime join acknowledgement was accepted.")
		quit(1)
		return
	if not social.is_realtime_topic_subscribed("chat:direct:joined"):
		push_error("A server-acknowledged realtime topic was not recognized.")
		quit(1)
		return

	# Channel-level close/error must retry only the current join, never a stale ref.
	var saved_topic_retries: Dictionary = social._realtime_topic_retry_seconds.duplicate(true)
	var saved_topic_retry_attempts: Dictionary = social._realtime_topic_retry_attempts.duplicate(true)
	social._realtime_topics = {"chat:direct:retry": true}
	social._realtime_join_refs = {"chat:direct:retry": "active-ref"}
	social._realtime_ready_topics = {"chat:direct:retry": true}
	social._realtime_topic_retry_seconds = {}
	social._schedule_realtime_topic_retry("chat:direct:retry", "stale-ref")
	if not social._realtime_join_refs.has("chat:direct:retry") or not social._realtime_ready_topics.has("chat:direct:retry"):
		push_error("A stale channel failure cleared the current realtime join.")
		quit(1)
		return
	social._schedule_realtime_topic_retry("chat:direct:retry", "active-ref")
	if social._realtime_join_refs.has("chat:direct:retry") or social._realtime_ready_topics.has("chat:direct:retry"):
		push_error("A current channel failure did not clear its failed join state.")
		quit(1)
		return
	if social._take_due_realtime_topic_retries(1.0).size() != 0:
		push_error("A realtime channel retry fired before its backoff elapsed.")
		quit(1)
		return
	var due_retries: Array[String] = social._take_due_realtime_topic_retries(1.1)
	if due_retries.size() != 1 or due_retries[0] != "chat:direct:retry":
		push_error("A failed active realtime channel was not scheduled for retry.")
		quit(1)
		return
	social._realtime_topics = {"chat:direct:retry": true}
	social._realtime_join_refs = {"chat:direct:retry": "new-ref"}
	social._realtime_ready_topics = {}
	social._schedule_realtime_topic_retry("chat:direct:retry", "new-ref")
	social._leave_realtime_topic("chat:direct:retry")
	if social._realtime_topic_retry_seconds.has("chat:direct:retry"):
		push_error("Leaving a realtime topic did not cancel its pending retry.")
		quit(1)
		return
	social._realtime_topics = {"chat:direct:joined": true}
	social._realtime_join_refs = {"chat:direct:joined": "ci-join-ref"}
	social._realtime_ready_topics = {"chat:direct:joined": true}
	# Stop retrying after the configured limit instead of looping forever.
	social._realtime_topics = {"chat:direct:retry-limit": true}
	social._realtime_join_refs = {"chat:direct:retry-limit": "retry-ref-1"}
	social._realtime_ready_topics = {}
	social._realtime_topic_retry_seconds = {}
	social._realtime_topic_retry_attempts = {}
	for attempt in range(3):
		social._schedule_realtime_topic_retry("chat:direct:retry-limit", "retry-ref-%d" % (attempt + 1))
		if not social._realtime_topic_retry_seconds.has("chat:direct:retry-limit"):
			push_error("A realtime channel retry stopped before reaching its configured limit.")
			quit(1)
			return
		social._take_due_realtime_topic_retries(2.0)
		social._realtime_join_refs["chat:direct:retry-limit"] = "retry-ref-%d" % (attempt + 2)
	social._schedule_realtime_topic_retry("chat:direct:retry-limit", "retry-ref-%d" % 4)
	if social._realtime_topic_retry_seconds.has("chat:direct:retry-limit") or social._realtime_topic_retry_attempts.has("chat:direct:retry-limit"):
		push_error("A realtime channel continued retrying after the configured limit.")
		quit(1)
		return
	# Drop retry entries when the topic is no longer wanted or already has a live join.
	social._realtime_topics = {"chat:direct:active": true}
	social._realtime_join_refs = {"chat:direct:active": "live-ref"}
	social._realtime_topic_retry_seconds = {
		"chat:direct:removed": 0.0,
		"chat:direct:active": 0.0
	}
	var ignored_retries: Array[String] = social._take_due_realtime_topic_retries(0.0)
	if not ignored_retries.is_empty() or not social._realtime_topic_retry_seconds.is_empty():
		push_error("Obsolete or already-joined realtime topics were retried.")
		quit(1)
		return
	social._realtime_topic_retry_seconds = saved_topic_retries
	social._realtime_topic_retry_attempts = saved_topic_retry_attempts
	if social.is_realtime_topic_subscribed("chat:direct:unjoined") or social.is_realtime_topic_subscribed("chat:group:joined"):
		push_error("An unjoined realtime topic was treated as an active subscription.")
		quit(1)
		return
	social._realtime_topics = saved_topics
	social._realtime_join_refs = saved_join_refs
	social._realtime_ready_topics = saved_ready_topics

	print("SOCIAL_TEST_STAGE: realtime_retry_checks_complete")
	if not social.is_valid_player_code("AB12CD34EF"): 
		push_error("A valid ten-character player code was rejected.")
		quit(1)
		return
	if not social.is_valid_invite_id("550e8400-e29b-41d4-a716-446655440000"):
		push_error("A valid UUID invitation id was rejected.")
		quit(1)
		return
	if not social.is_valid_invite_id("550E8400-E29B-41D4-A716-446655440000"):
		push_error("A valid uppercase UUID invitation id was rejected.")
		quit(1)
		return
	if social.is_valid_invite_id("invite-1") or social.is_valid_invite_id("550e8400-e29b-41d4-a716-44665544000"):
		push_error("A malformed invitation id was accepted.")
		quit(1)
		return
	if social.respond_chat_group_invite("invite-1", true):
		push_error("A malformed invitation id was sent to the RPC layer.")
		quit(1)
		return
	if social.is_valid_player_code("AB12-CD34"):
		push_error("A player code containing punctuation was accepted.")
		quit(1)
		return
	if social.is_valid_player_code("AB12CD34E"):
		push_error("A player code shorter than ten characters was accepted.")
		quit(1)
		return

	print("SOCIAL_TEST_STAGE: id_validation_complete")
	social.set_realtime_player_code("bad-code")
	if not social._realtime_player_code.is_empty() or social._realtime_topics.has("chat:invites:BAD-CODE"):
		push_error("An invalid player identity created a realtime invitation subscription.")
		quit(1)
		return
	social.set_realtime_player_code("AB12CD34EF")
	if social._realtime_player_code != "AB12CD34EF" or not social._realtime_topics.has("chat:invites:AB12CD34EF"):
		push_error("A valid player identity did not create its invitation subscription.")
		quit(1)
		return
	social.set_realtime_player_code("")
	if not social._realtime_player_code.is_empty() or social._realtime_topics.has("chat:invites:AB12CD34EF"):
		push_error("Clearing a player identity left its realtime invitation subscription active.")
		quit(1)
		return

	print("SOCIAL_TEST_STAGE: player_code_checks_complete")
	social.subscribe_group_chat("group-a")
	if social._realtime_group_id != "group-a" or not social._realtime_topics.has("chat:group:group-a"):
		push_error("The initial group subscription was not registered.")
		quit(1)
		return
	social.subscribe_group_chat("group-b")
	if social._realtime_group_id != "group-b" or social._realtime_topics.has("chat:group:group-a") or not social._realtime_topics.has("chat:group:group-b"):
		push_error("Switching groups left the previous realtime group topic subscribed.")
		quit(1)
		return
	social.subscribe_group_chat("")
	if not social._realtime_group_id.is_empty() or social._realtime_topics.has("chat:group:group-b"):
		push_error("Leaving a group did not clear its realtime subscription.")
		quit(1)
		return

	print("SOCIAL_TEST_STAGE: group_subscription_checks_complete")
	social.subscribe_direct_chat("conversation-a")
	if social._realtime_direct_id != "conversation-a" or not social._realtime_topics.has("chat:direct:conversation-a"):
		push_error("The initial direct conversation subscription was not registered.")
		quit(1)
		return
	social.subscribe_direct_chat("conversation-b")
	if social._realtime_direct_id != "conversation-b" or social._realtime_topics.has("chat:direct:conversation-a") or not social._realtime_topics.has("chat:direct:conversation-b"):
		push_error("Switching direct conversations left the previous realtime topic subscribed.")
		quit(1)
		return
	social.subscribe_direct_chat("")
	if not social._realtime_direct_id.is_empty() or social._realtime_topics.has("chat:direct:conversation-b"):
		push_error("Closing a direct conversation did not clear its realtime subscription.")
		quit(1)
		return

	print("SOCIAL_TEST_STAGE: direct_subscription_checks_complete")
	if social.open_direct_conversation("bad-code"): 
		push_error("Invalid player code was accepted for direct conversation.")
		quit(1)
		return
	if social.invite_chat_group_member("bad-code"):
		push_error("Invalid player code was accepted for group invitation.")
		quit(1)
		return
	if social.send_chat_message("admin", "hello"):
		push_error("Unsupported chat channel was accepted.")
		quit(1)
		return
	if social.send_chat_message("public", "   "):
		push_error("Empty chat message was accepted.")
		quit(1)
		return
	if social.send_chat_message("group", "x".repeat(301)):
		push_error("Overlength chat message was accepted.")
		quit(1)
		return
	if social.read_chat_messages("private"):
		push_error("Unsupported chat read channel was accepted.")
		quit(1)
		return

	print("SOCIAL_TEST_STAGE: chat_input_checks_complete")
	var invitation_script: Script = load("res://scripts/invitation_overlay.gd")
	var invitation_overlay: Control = invitation_script.new()
	root.add_child(invitation_overlay)
	var invitation_now := float(Time.get_unix_time_from_system())
	var capped_deadline := float(invitation_overlay.call("resolve_invitation_expiry", {
		"expires_at": invitation_now + 90.0
	}, invitation_now))
	if capped_deadline > invitation_now + 30.0:
		push_error("A supplied invitation deadline extended the approved 30-second lifetime.")
		quit(1)
		return
	var stale_created_at := Time.get_datetime_string_from_unix_time(int(invitation_now) - 40)
	var stale_deadline := float(invitation_overlay.call("resolve_invitation_expiry", {
		"created_at": stale_created_at
	}, invitation_now))
	if stale_deadline > invitation_now - 9.0:
		push_error("An invitation created more than 30 seconds ago received a fresh lifetime.")
		quit(1)
		return
	var shortened_deadline := invitation_now + 8.0
	var server_shortened := float(invitation_overlay.call("resolve_invitation_expiry", {
		"expires_at": shortened_deadline
	}, invitation_now))
	if not is_equal_approx(server_shortened, shortened_deadline):
		push_error("A shorter server-provided invitation deadline was not preserved.")
		quit(1)
		return
	var already_expired_deadline := invitation_now - 3.0
	var server_expired := float(invitation_overlay.call("resolve_invitation_expiry", {
		"expires_at": already_expired_deadline
	}, invitation_now))
	if not is_equal_approx(server_expired, already_expired_deadline):
		push_error("An already-expired server invitation was extended locally.")
		quit(1)
		return
	var future_created_at := Time.get_datetime_string_from_unix_time(int(invitation_now) + 300)
	var future_timestamp_deadline := float(invitation_overlay.call("resolve_invitation_expiry", {
		"created_at": future_created_at
	}, invitation_now))
	if future_timestamp_deadline > invitation_now + 30.0 or future_timestamp_deadline < invitation_now + 29.0:
		push_error("A future creation timestamp bypassed the local invitation lifetime cap.")
		quit(1)
		return
	invitation_overlay.enqueue_invitation({
		"invite_id": "ci-account-a-invite",
		"type": "group_invite",
		"title": "CI invitation",
		"body": "Account A invitation",
		"expires_at": float(Time.get_unix_time_from_system()) + 60.0
	})
	if invitation_overlay.get_pending_invitation_count() != 1:
		push_error("Invitation overlay did not retain the active test invitation.")
		quit(1)
		return
	invitation_overlay.enqueue_invitation({
		"invite_id": "ci-account-a-invite",
		"title": "Duplicate invitation",
		"expires_at": float(Time.get_unix_time_from_system()) + 60.0
	})
	if invitation_overlay.get_pending_invitation_count() != 1:
		push_error("A duplicate active invitation was added to the queue.")
		quit(1)
		return
	var expired_count := [0]
	invitation_overlay.invitation_expired.connect(func(_item: Dictionary) -> void:
		expired_count[0] += 1
	)
	invitation_overlay.enqueue_invitation({
		"invite_id": "ci-already-expired",
		"title": "Expired invitation",
		"expires_at": float(Time.get_unix_time_from_system()) - 1.0
	})
	if expired_count[0] != 1 or invitation_overlay.get_pending_invitation_count() != 1:
		push_error("An already-expired invitation was queued instead of being rejected.")
		quit(1)
		return
	invitation_overlay.enqueue_invitation({
		"invite_id": "ci-account-b-invite",
		"type": "group_invite",
		"title": "Queued invitation",
		"expires_at": float(Time.get_unix_time_from_system()) + 60.0
	})
	invitation_overlay.enqueue_invitation({
		"invite_id": "ci-queued-expired",
		"title": "Queued invitation that expires during response",
		"expires_at": float(Time.get_unix_time_from_system()) + 1.0
	})
	# Simulate the accept/decline handler starting its RPC before the active
	# invitation is removed; queued items must stay hidden and keep expiring.
	invitation_overlay.call("set_response_pending", true)
	invitation_overlay.call("_finish_current", true)
	if invitation_overlay.get_pending_invitation_count() != 2 or not invitation_overlay._current.is_empty():
		push_error("Queued invitations became actionable while the previous response was pending.")
		quit(1)
		return
	# Simulate real elapsed wall-clock time, including time spent backgrounded.
	for queued_item in invitation_overlay._queue:
		if str(queued_item.get("invite_id", "")) == "ci-queued-expired":
			queued_item["expires_at"] = float(Time.get_unix_time_from_system()) - 1.0
	invitation_overlay.call("_tick", 0.0)
	if expired_count[0] != 2 or invitation_overlay.get_pending_invitation_count() != 1 or not invitation_overlay._current.is_empty():
		push_error("A queued invitation did not expire while the previous response was pending.")
		quit(1)
		return
	invitation_overlay.call("set_response_pending", false)
	if invitation_overlay.get_pending_invitation_count() != 1 or str(invitation_overlay.get_current_invitation().get("invite_id", "")) != "ci-account-b-invite":
		push_error("The next unexpired invitation was not shown after the pending response completed.")
		quit(1)
		return
	# The currently displayed invitation must also expire from its absolute
	# deadline, independently of frame delta or app pause duration.
	invitation_overlay._current["expires_at"] = float(Time.get_unix_time_from_system()) - 1.0
	invitation_overlay.call("_tick", 0.0)
	if expired_count[0] != 3 or invitation_overlay.get_pending_invitation_count() != 0 or invitation_overlay._panel.visible:
		push_error("The active invitation did not expire and close at its absolute deadline.")
		quit(1)
		return
	var accepted_count := [0]
	invitation_overlay.invitation_accepted.connect(func(_item: Dictionary) -> void:
		accepted_count[0] += 1
	)
	invitation_overlay.enqueue_invitation({
		"invite_id": "ci-late-tap-invite",
		"type": "group_invite",
		"title": "Late tap invitation",
		"expires_at": float(Time.get_unix_time_from_system()) + 60.0
	})
	invitation_overlay._current["expires_at"] = float(Time.get_unix_time_from_system()) - 1.0
	invitation_overlay.call("_finish_current", true)
	if accepted_count[0] != 0 or expired_count[0] != 4 or invitation_overlay.get_pending_invitation_count() != 0 or invitation_overlay._panel.visible:
		push_error("A late accept tap was emitted after the invitation deadline.")
		quit(1)
		return
	var declined_count := [0]
	invitation_overlay.invitation_declined.connect(func(_item: Dictionary) -> void:
		declined_count[0] += 1
	)
	invitation_overlay.enqueue_invitation({
		"invite_id": "ci-late-tap-decline-invite",
		"type": "group_invite",
		"title": "Late tap decline invitation",
		"expires_at": float(Time.get_unix_time_from_system()) + 60.0
	})
	invitation_overlay._current["expires_at"] = float(Time.get_unix_time_from_system()) - 1.0
	invitation_overlay.call("_finish_current", false)
	if declined_count[0] != 0 or expired_count[0] != 5 or invitation_overlay.get_pending_invitation_count() != 0 or invitation_overlay._panel.visible:
		push_error("A late decline tap was emitted after the invitation deadline.")
		quit(1)
		return
	invitation_overlay.clear_pending_invitations()
	if invitation_overlay.get_pending_invitation_count() != 0 or not invitation_overlay._current.is_empty() or invitation_overlay._panel.visible:
		push_error("A previous account's active or queued invitation survived account cleanup.")
		quit(1)
		return
	print("SOCIAL_TEST_STAGE: invitation_lifecycle_complete")
	print("Social chat input and invitation lifecycle validation tests passed.")
	quit(0)
