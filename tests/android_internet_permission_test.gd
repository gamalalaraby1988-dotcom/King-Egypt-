extends SceneTree

func _initialize() -> void:
	var presets := ConfigFile.new()
	var error := presets.load("res://export_presets.cfg")
	if error != OK:
		push_error("Android export preset could not be loaded: %s" % error_string(error))
		quit(1)
		return
	if not bool(presets.get_value("preset.0.options", "permissions/internet", false)):
		push_error("Android export preset must enable the INTERNET permission for Supabase Auth and online services.")
		quit(1)
		return
	print("Android INTERNET permission contract test passed.")
	quit(0)
