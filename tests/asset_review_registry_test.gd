extends SceneTree

func _initialize() -> void:
	call_deferred("_run_asset_registry_test")

func _run_asset_registry_test() -> void:
	var errors := AssetReviewRegistry.validate_manifest()
	if not errors.is_empty():
		for message in errors:
			push_error(message)
		quit(1)
		return

	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/asset_registry.json"))
	var assets: Array = parsed.get("assets", [])
	if assets.is_empty():
		push_error("The asset registry must track existing project assets.")
		quit(1)
		return
	var gate_found := false
	for item in assets:
		if str(item.get("path", "")) == "res://assets/models/royal_gate.glb":
			gate_found = true
			if str(item.get("status", "")) in ["approved", "integrated"]:
				push_error("An existing asset cannot be marked approved without an explicit review record.")
				quit(1)
				return
	if not gate_found:
		push_error("The existing royal gate GLB must be listed in the registry.")
		quit(1)
		return
	print("Asset review registry contract passed.")
	quit(0)
