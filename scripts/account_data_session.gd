extends Node
## Coordinates the active authenticated profile session for local cache data.

signal session_ready(user_id: String, generation: int, profile_path: String)
signal session_invalidated(previous_user_id: String, generation: int)

const PROFILE_ROOT := "user://accounts"
var _active_user_id := ""
var _active_generation := -1
var _active_profile_path := ""
var _ready_for_profile := false

func _ready() -> void:
	if not AuthManager.session_changed.is_connected(_on_session_changed):
		AuthManager.session_changed.connect(_on_session_changed)
	if AuthManager.is_authenticated():
		_on_session_changed("", AuthManager.get_authenticated_user_id(), AuthManager.get_session_generation())

func _on_session_changed(previous_user_id: String, current_user_id: String, generation: int) -> void:
	_invalidate(previous_user_id, generation)
	if current_user_id.is_empty() or not AuthManager.is_session_current(current_user_id, generation):
		return
	var uuid_pattern := RegEx.new()
	uuid_pattern.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
	if uuid_pattern.search(current_user_id) == null:
		push_error("AccountDataSession rejected a non-UUID user identity.")
		return
	var directory := "%s/%s" % [PROFILE_ROOT, current_user_id]
	var absolute_directory := ProjectSettings.globalize_path(directory)
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK and not DirAccess.dir_exists_absolute(absolute_directory):
		push_error("AccountDataSession could not create the account cache directory.")
		return
	if not AuthManager.is_session_current(current_user_id, generation):
		return
	_active_user_id = current_user_id
	_active_generation = generation
	_active_profile_path = directory + "/profile.cfg"
	_ready_for_profile = true
	session_ready.emit(_active_user_id, _active_generation, _active_profile_path)

func _invalidate(previous_user_id: String, generation: int) -> void:
	var old_uid := _active_user_id if not _active_user_id.is_empty() else previous_user_id
	_ready_for_profile = false
	_active_user_id = ""
	_active_generation = -1
	_active_profile_path = ""
	if not old_uid.is_empty():
		session_invalidated.emit(old_uid, generation)

func is_ready() -> bool:
	return _ready_for_profile and AuthManager.is_session_current(_active_user_id, _active_generation)

func is_session_current(user_id: String, generation: int) -> bool:
	return is_ready() and user_id == _active_user_id and generation == _active_generation

func get_user_id() -> String:
	return _active_user_id if is_ready() else ""

func get_generation() -> int:
	return _active_generation if is_ready() else -1

func get_profile_path() -> String:
	return _active_profile_path if is_ready() else ""
