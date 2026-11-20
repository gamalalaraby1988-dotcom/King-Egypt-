extends SceneTree

func _initialize() -> void:
	call_deferred("_run_arcade_machine_tests")

func _run_arcade_machine_tests() -> void:
	var machine_script := load("res://scripts/arcade_slot_machine.gd") as Script
	if machine_script == null:
		push_error("Royal slot machine script could not be loaded.")
		quit(1)
		return

	var machine := Node3D.new()
	machine.name = "ArcadeSlotMachineTest"
	machine.set_script(machine_script)
	machine.set("machine_id", "test_vip_machine")
	machine.set("machine_title", "Test Royal Slot")
	root.add_child(machine)
	await process_frame

	for required_path in [
		"PlayerSeat/SeatAnchor",
		"PlayerSeat/ExitAnchor",
		"InteractionArea/CollisionShape3D",
		"MachineCabinet",
		"ScreenGlass",
		"SlotMachineTouchLayer/SlotMachineControls"
	]:
		if machine.get_node_or_null(required_path) == null:
			push_error("Missing slot machine component: " + required_path)
			machine.queue_free()
			quit(1)
			return

	var controls := machine.get_node("SlotMachineTouchLayer/SlotMachineControls")
	var spin_button := controls.find_child("SpinButton", true, false) as Button
	if spin_button == null or not spin_button.disabled:
		push_error("Spin must remain disabled until a trusted game controller is connected.")
		machine.queue_free()
		quit(1)
		return

	if not machine.has_method("play_server_result"):
		push_error("Trusted result presentation entry point is missing.")
		machine.queue_free()
		quit(1)
		return

	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	if not main_source.contains("_create_european_vip_slot_machines(root, center)"):
		push_error("European VIP palace room does not create the approved slot machines.")
		machine.queue_free()
		quit(1)
		return
	if main_source.contains("CasinoMachinePedestal_") or main_source.contains("CasinoMachineScreen_"):
		push_error("Obsolete casino machine placeholders remain in main.gd.")
		machine.queue_free()
		quit(1)
		return

	var player_source := FileAccess.get_file_as_string("res://scripts/player.gd")
	if not player_source.contains("func set_arcade_seated") or not player_source.contains("func end_arcade_seat"):
		push_error("Player arcade seating lock/unlock methods are missing.")
		machine.queue_free()
		quit(1)
		return

	var avatar_source := FileAccess.get_file_as_string("res://scripts/avatar_visual.gd")
	if not avatar_source.contains('"celebrate"') or not avatar_source.contains('"disappointed"'):
		push_error("Seated win/loss reaction animation states are missing.")
		machine.queue_free()
		quit(1)
		return

	machine.queue_free()
	print("Arcade slot machine seating and safety contract tests passed.")
	quit(0)
