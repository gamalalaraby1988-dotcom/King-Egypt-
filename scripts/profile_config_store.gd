extends RefCounted
## Shared atomic writer for local player profiles.
## Authenticated accounts use separate files; the legacy file remains the guest/offline profile.
static var _write_in_progress := false
static var _active_account_id := ""
static var _active_profile_path := "user://kings_city_profile.cfg"
static var _active_account_key := ""
static var _account_switch_in_progress := false

static func begin_account_switch(user_id: String) -> bool:
	_account_switch_in_progress = true
	if not set_active_account(user_id):
		_account_switch_in_progress = false
		return false
	return true

static func complete_account_switch() -> void:
	_account_switch_in_progress = false

static func is_account_switch_in_progress() -> bool:
	return _account_switch_in_progress

static func set_active_account(user_id: String) -> bool:
	var normalized := user_id.strip_edges()
	if normalized.is_empty():
		_active_account_id = ""
		_active_account_key = ""
		_active_profile_path = "user://kings_city_profile.cfg"
		return true
	if normalized.length() > 128:
		return false
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return false
	context.update(normalized.to_utf8_buffer())
	var account_key := context.finish().hex_encode()
	var directory := ProjectSettings.globalize_path("user://accounts")
	if DirAccess.make_dir_recursive_absolute(directory) != OK and not DirAccess.dir_exists_absolute(directory):
		return false
	_active_account_id = normalized
	_active_account_key = account_key
	_active_profile_path = "user://accounts/player_%s.cfg" % account_key
	return true

static func get_active_account_id() -> String:
	return _active_account_id

static func get_active_profile_path() -> String:
	return _active_profile_path

static func get_active_scoped_path(legacy_path: String) -> String:
	if _active_account_key.is_empty():
		return legacy_path
	var file_name := legacy_path.get_file()
	return "user://accounts/player_%s.%s" % [_active_account_key, file_name]


static func save_sections(file_path: String, section_updates: Dictionary, temp_path: String = "", backup_path: String = "") -> bool:
	if file_path.strip_edges().is_empty() or section_updates.is_empty():
		return false
	for section_name in section_updates:
		if str(section_name) not in ["profile", "settings"] or not (section_updates[section_name] is Dictionary):
			return false
	var config := ConfigFile.new()
	var load_error := config.load(file_path)
	if load_error != OK and FileAccess.file_exists(file_path):
		return false
	for section_name in section_updates:
		var section_data: Dictionary = section_updates[section_name]
		for key in section_data:
			config.set_value(str(section_name), str(key), section_data[key])
	return _write_config(config, file_path, temp_path, backup_path)

static func save_config_snapshot(config: ConfigFile, file_path: String, temp_path: String, backup_path: String) -> bool:
	if config == null or file_path.strip_edges().is_empty() or temp_path.strip_edges().is_empty() or backup_path.strip_edges().is_empty():
		return false
	return _write_config(config, file_path, temp_path, backup_path)

static func _write_config(config: ConfigFile, file_path: String, temp_path: String, backup_path: String) -> bool:
	if _write_in_progress:
		push_warning("ProfileConfigStore: nested profile write rejected.")
		return false
	_write_in_progress = true
	var resolved_temp := temp_path if not temp_path.is_empty() else file_path + ".tmp"
	var resolved_backup := backup_path if not backup_path.is_empty() else file_path + ".backup"
	var result := false
	if config.save(resolved_temp) != OK:
		_write_in_progress = false
		return false
	var original_exists := FileAccess.file_exists(file_path)
	var original_absolute := ProjectSettings.globalize_path(file_path)
	var temp_absolute := ProjectSettings.globalize_path(resolved_temp)
	var backup_absolute := ProjectSettings.globalize_path(resolved_backup)
	var pending_absolute := backup_absolute + ".pending"
	if original_exists and not FileAccess.file_exists(resolved_backup):
		if DirAccess.copy_absolute(original_absolute, backup_absolute) != OK:
			DirAccess.remove_absolute(temp_absolute)
			_write_in_progress = false
			return false
	if original_exists:
		if FileAccess.file_exists(pending_absolute):
			DirAccess.remove_absolute(pending_absolute)
		if DirAccess.rename_absolute(original_absolute, pending_absolute) != OK:
			DirAccess.remove_absolute(temp_absolute)
			_write_in_progress = false
			return false
		if DirAccess.rename_absolute(temp_absolute, original_absolute) != OK:
			DirAccess.rename_absolute(pending_absolute, original_absolute)
			_write_in_progress = false
			return false
		DirAccess.remove_absolute(pending_absolute)
		result = true
	else:
		result = DirAccess.rename_absolute(temp_absolute, original_absolute) == OK
		if not result:
			DirAccess.remove_absolute(temp_absolute)
	_write_in_progress = false
	return result
