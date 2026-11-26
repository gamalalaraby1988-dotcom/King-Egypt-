extends Node
## Authenticated friend graph client. Uses the player's own Supabase session only.

signal friends_updated(friends: Array)
signal requests_updated(requests: Array)
signal operation_finished(operation: String, success: bool, result_code: String)
signal connection_state_changed(connected: bool, message: String)

var _http: HTTPRequest
var _active_action := ""
var _request_token := ""
var _request_user_id := ""
var _refresh_stage := ""
var _friends: Array = []
var _requests: Array = []

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.name = "PlayerFriendsHTTPRequest"
	_http.timeout = 20.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	if PlayerAccountAuthClient.has_signal("session_expired"):
		PlayerAccountAuthClient.session_expired.connect(clear_session)

func refresh() -> void:
	if not bool(ProjectSettings.get_setting("player_friends/enabled", false)):
		connection_state_changed.emit(false, "خدمة الأصدقاء غير مفعلة على الخادم الحالي بعد.")
		return
	if not _has_session():
		connection_state_changed.emit(false, "سجّل الدخول إلى حساب اللاعب لعرض الأصدقاء.")
		return
	if not _active_action.is_empty():
		return
	_refresh_stage = "requests"
	_start_rpc("list_friend_requests", {}, "refresh_requests")

func send_friend_request(player_code: String) -> void:
	var code := player_code.strip_edges().to_upper()
	if not _valid_player_code(code):
		operation_finished.emit("send", false, "invalid_player_code")
		return
	_start_rpc("send_friend_request", {"p_player_code": code}, "send")

func respond_friend_request(request_id: String, accept: bool) -> void:
	if request_id.strip_edges().is_empty():
		operation_finished.emit("respond", false, "invalid_request")
		return
	_start_rpc("respond_friend_request", {"p_request_id": request_id, "p_accept": accept}, "respond")

func remove_friend(player_code: String) -> void:
	var code := player_code.strip_edges().to_upper()
	if not _valid_player_code(code):
		operation_finished.emit("remove", false, "invalid_player_code")
		return
	_start_rpc("remove_friend", {"p_player_code": code}, "remove")

func block_player(player_code: String) -> void:
	var code := player_code.strip_edges().to_upper()
	if not _valid_player_code(code):
		operation_finished.emit("block", false, "invalid_player_code")
		return
	_start_rpc("block_player", {"p_player_code": code}, "block")

func clear_session() -> void:
	_active_action = ""
	_request_token = ""
	_request_user_id = ""
	_refresh_stage = ""
	_friends.clear()
	_requests.clear()
	friends_updated.emit([])
	requests_updated.emit([])
	connection_state_changed.emit(false, "انتهت جلسة الحساب. سجّل الدخول مجددًا.")

func _has_session() -> bool:
	return PlayerAccountAuthClient.has_active_session() and not PlayerAccountAuthClient.get_access_token().is_empty() and not PlayerAccountAuthClient.get_user_id().is_empty()

func _valid_player_code(code: String) -> bool:
	if code.length() != 10:
		return false
	for character in code:
		if not (character in "0123456789ABCDEF"):
			return false
	return true

func _start_rpc(rpc_name: String, payload: Dictionary, action: String) -> void:
	if not bool(ProjectSettings.get_setting("player_friends/enabled", false)):
		operation_finished.emit(action, false, "backend_not_enabled")
		return
	if not _has_session():
		operation_finished.emit(action, false, "authentication_required")
		return
	if not _active_action.is_empty():
		operation_finished.emit(action, false, "request_in_progress")
		return
	var base_url := str(ProjectSettings.get_setting("founder/auth/api_base_url", "")).strip_edges().trim_suffix("/")
	var publishable_key := str(ProjectSettings.get_setting("founder/auth/publishable_key", "")).strip_edges()
	if not base_url.begins_with("https://") or publishable_key.is_empty():
		operation_finished.emit(action, false, "service_not_configured")
		return
	var token: String = PlayerAccountAuthClient.get_access_token()
	var user_id: String = PlayerAccountAuthClient.get_user_id()
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"apikey: " + publishable_key,
		"Authorization: Bearer " + token
	])
	var error := _http.request(
		base_url + "/rest/v1/rpc/" + rpc_name,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if error != OK:
		operation_finished.emit(action, false, "network_unavailable")
		return
	_active_action = action
	_request_token = token
	_request_user_id = user_id

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var action := _active_action
	var request_token := _request_token
	var request_user_id := _request_user_id
	_active_action = ""
	_request_token = ""
	_request_user_id = ""
	if request_token.is_empty() or request_user_id.is_empty() or not _has_session() or request_token != PlayerAccountAuthClient.get_access_token() or request_user_id != PlayerAccountAuthClient.get_user_id():
		_refresh_stage = ""
		if _has_session():
			call_deferred("refresh")
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_refresh_stage = ""
		if action.begins_with("refresh_"):
			connection_state_changed.emit(false, "تعذر تحميل بيانات الأصدقاء من الخادم.")
		else:
			operation_finished.emit(action, false, "server_error")
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if action == "refresh_requests" or action == "refresh_friends":
		if not (parsed is Array):
			_refresh_stage = ""
			connection_state_changed.emit(false, "استجابة غير صالحة من خدمة الأصدقاء.")
			return
		if action == "refresh_requests":
			_requests = parsed
			requests_updated.emit(_requests.duplicate(true))
			_refresh_stage = "friends"
			_start_rpc("list_friends", {}, "refresh_friends")
			return
		_friends = parsed
		friends_updated.emit(_friends.duplicate(true))
		_refresh_stage = ""
		connection_state_changed.emit(true, "تم تحديث قائمة الأصدقاء والطلبات من الخادم.")
		return
	var result_code := str(parsed)
	var success := result_code in ["sent", "accepted", "declined", "removed", "blocked", "unblocked"]
	operation_finished.emit(action, success, result_code)
	if success:
		call_deferred("refresh")
