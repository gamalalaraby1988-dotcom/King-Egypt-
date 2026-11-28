extends SceneTree

func _initialize() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/main.gd")
	if source.is_empty():
		push_error("Could not read main.gd for entry controls contract test.")
		quit(1)
		return

	var facebook_start := source.find("facebook_button.name = \"FacebookEntryButton\"")
	var facebook_end := source.find("content.add_child(facebook_button)", facebook_start)
	if facebook_start < 0 or facebook_end < 0:
		push_error("Facebook entry control was not found.")
		quit(1)
		return
	var facebook_block := source.substr(facebook_start, facebook_end - facebook_start)
	if facebook_block.contains("facebook_button.disabled = true"):
		push_error("Facebook entry control must remain interactive and report provider availability.")
		quit(1)
		return
	if not facebook_block.contains("facebook_button.pressed.connect"):
		push_error("Facebook entry control has no action.")
		quit(1)
		return

	if not source.contains("offline_icon.pressed.connect(_select_offline_mode)"):
		push_error("Offline entry control is missing its direct offline action.")
		quit(1)
		return
	if not source.contains("account_icon.pressed.connect(_show_account_entry)"):
		push_error("Account entry control is missing its action.")
		quit(1)
		return
	if not source.contains("options_icon.pressed.connect(_show_game_options)"):
		push_error("Entry options control is missing its action.")
		quit(1)
		return

	print("Entry controls interactivity contract test passed.")
	quit(0)
