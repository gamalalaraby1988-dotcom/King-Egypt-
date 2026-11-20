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
	for required_control in ["KingOfEgyptBrand", "BalanceValue", "BetValue", "WinValue", "DecreaseBetButton", "IncreaseBetButton", "MaxBetButton", "SpinButton", "AutoButton", "LeaveSeatButton", "MinimumBetNote"]:
		if controls.find_child(required_control, true, false) == null:
			push_error("Missing chip/bet display control: " + required_control)
			machine.queue_free()
			quit(1)
			return
	var bet_label := controls.find_child("BetValue", true, false) as Label
	var minimum_note := controls.find_child("MinimumBetNote", true, false) as Label
	if bet_label == null or not bet_label.text.contains("10") or minimum_note == null or not minimum_note.text.contains("10"):
		push_error("The displayed minimum bet must be 10 game chips.")
		machine.queue_free()
		quit(1)
		return
	for control_name in ["DecreaseBetButton", "IncreaseBetButton", "MaxBetButton"]:
		var bet_button := controls.find_child(control_name, true, false) as Button
		if bet_button == null or not bet_button.disabled:
			push_error("Bet controls must remain disabled until server authority is connected.")
			machine.queue_free()
			quit(1)
			return
	var blue_button := controls.find_child("IncreaseBetButton", true, false) as Button
	var blue_style := blue_button.get_theme_stylebox("normal") as StyleBoxFlat
	if blue_style == null or blue_style.border_color.b < blue_style.border_color.r:
		push_error("Bet adjustment controls must use blue styling.")
		machine.queue_free()
		quit(1)
		return

	var auto_button := controls.find_child("AutoButton", true, false) as Button
	if auto_button == null or not auto_button.disabled:
		push_error("AUTO must remain disabled until the trusted server controller is connected.")
		machine.queue_free()
		quit(1)
		return
	var leave_button := controls.find_child("LeaveSeatButton", true, false) as Button
	if leave_button == null or leave_button.text != "🚪 مغادرة المقعد":
		push_error("The approved dark-blue leave-seat control is missing.")
		machine.queue_free()
		quit(1)
		return
	var auto_button_style := auto_button.get_theme_stylebox("normal") as StyleBoxFlat
	if auto_button_style == null or auto_button_style.border_color.r < auto_button_style.border_color.g:
		push_error("AUTO must use red styling.")
		machine.queue_free()
		quit(1)
		return

	var spin_button := controls.find_child("SpinButton", true, false) as Button
	if spin_button == null or not spin_button.disabled:
		push_error("Spin must remain disabled until a trusted game controller is connected.")
		machine.queue_free()
		quit(1)
		return

	if spin_button.text != "SPIN":
		push_error("Manual SPIN mode must be the default visual state.")
		machine.queue_free()
		quit(1)
		return
	var spin_style := spin_button.get_theme_stylebox("normal") as StyleBoxFlat
	if spin_style == null or spin_style.border_color.g < spin_style.border_color.r:
		push_error("Manual SPIN mode must use green styling.")
		machine.queue_free()
		quit(1)
		return
	machine.call("set_auto_play_mode_visual", true)
	var auto_mode_style := auto_button.get_theme_stylebox("normal") as StyleBoxFlat
	var manual_mode_style := spin_button.get_theme_stylebox("normal") as StyleBoxFlat
	if spin_button.text != "SPIN" or auto_button.text != "AUTO" or auto_mode_style == null or auto_mode_style.border_color.r < auto_mode_style.border_color.g or manual_mode_style == null or manual_mode_style.border_color.g < manual_mode_style.border_color.r:
		push_error("Separate AUTO red and SPIN green controls must retain their approved colors.")
		machine.queue_free()
		quit(1)
		return
	machine.call("set_auto_play_mode_visual", false)

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
