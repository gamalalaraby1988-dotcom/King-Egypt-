extends RefCounted
## Merges only explicitly supplied profile/settings keys into the latest file snapshot.
## This prevents a stale settings form from replacing wallet, receipts, ledger, or ownership data.

static func save_sections(
	file_path: String,
	section_updates: Dictionary,
	temp_path: String = "",
	backup_path: String = ""
) -> bool:
	if file_path.strip_edges().is_empty() or section_updates.is_empty():
		return false
	for section_name in section_updates:
		if str(section_name) not in ["profile", "settings"]:
			return false
		if not (section_updates[section_name] is Dictionary):
			return false

	var config := ConfigFile.new()
	var load_error := config.load(file_path)
	if load_error != OK and FileAccess.file_exists(file_path):
		return false

	for section_name in section_updates:
		var section_data: Dictionary = section_updates[section_name]
		for key in section_data:
			config.set_value(str(section_name), str(key), section_data[key])

	var resolved_temp := temp_path if not temp_path.is_empty() else file_path + ".tmp"
	var resolved_backup := backup_path if not backup_path.is_empty() else file_path + ".backup"
	if config.save(resolved_temp) != OK:
		return false

	var original_exists := FileAccess.file_exists(file_path)
	var original_absolute := ProjectSettings.globalize_path(file_path)
	var temp_absolute := ProjectSettings.globalize_path(resolved_temp)
	var backup_absolute := ProjectSettings.globalize_path(resolved_backup)
	var pending_absolute := backup_absolute + ".pending"

	if original_exists and not FileAccess.file_exists(resolved_backup):
		if DirAccess.copy_absolute(original_absolute, backup_absolute) != OK:
			DirAccess.remove_absolute(temp_absolute)
			return false

	if original_exists:
		if FileAccess.file_exists(pending_absolute):
			DirAccess.remove_absolute(pending_absolute)
		if DirAccess.rename_absolute(original_absolute, pending_absolute) != OK:
			DirAccess.remove_absolute(temp_absolute)
			return false
		if DirAccess.rename_absolute(temp_absolute, original_absolute) != OK:
			DirAccess.rename_absolute(pending_absolute, original_absolute)
			return false
		DirAccess.remove_absolute(pending_absolute)
	else:
		if DirAccess.rename_absolute(temp_absolute, original_absolute) != OK:
			DirAccess.remove_absolute(temp_absolute)
			return false
	return true
