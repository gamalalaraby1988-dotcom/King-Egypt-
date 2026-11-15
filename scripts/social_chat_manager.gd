extends Node
## Authenticated REST RPC bridge for test social features.
signal operation_completed(action: String, data: Variant)
signal operation_failed(action: String, message: String)
signal realtime_event(topic: String, event_name: String, payload: Dictionary)
signal realtime_status_changed(status: String)

const SUPABASE_URL := "https://unwrlvyjrtdwobcktetd.supabase.co"
const SUPABASE_PUBLISHABLE_KEY := "sb_publishable_BrWeMmhyOpL73Uca40Ug0Q_8Zgw55si"

var _http: HTTPRequest
var _pending_action := ""
var _realtime_socket: WebSocketPeer
var _realtime_topics: Dictionary = {}
var _realtime_join_refs: Dictionary = {}
var _realtime_ref := 0
var _realtime_heartbeat_elapsed := 0.0
var _realtime_retry_elapsed := 0.0
var _realtime_retry_delay := 2.0
var _realtime_connected := false
var _realtime_last_token := ""
var _realtime_player_code := ""
var _realtime_group_id := ""
var _realtime_direct_id := ""

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.name = "SocialRpcHTTPRequest"
	_http.timeout = 20.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

func list_friends() -> bool:
	return _rpc("list_test_friends", {}, "friends_list")

func send_friend_request(player_code: String) -> bool:
	return _rpc("send_test_friend_request", {"p_player_code": player_code}, "friend_request")

static func is_valid_player_code(player_code: String) -> bool:
	var validator := RegEx.new()
	if validator.compile("^[A-Z0-9]{10}$") != OK:
		return false
	return validator.search(player_code.strip_edges().to_upper()) != null

func block_player(player_code: String) -> bool:
	var clean_code := player_code.strip_edges().to_upper()
	if not is_valid_player_code(clean_code):
		operation_failed.emit("block_player", "رمز اللاعب غير صالح.")
		return false
	return _rpc("block_test_player", {"p_player_code": clean_code}, "block_player")

func list_blocked_players() -> bool:
	return _rpc("list_my_test_blocked_players", {}, "blocked_list")

func unblock_player(player_code: String) -> bool:
	var clean_code := player_code.strip_edges().to_upper()
	if not is_valid_player_code(clean_code):
		operation_failed.emit("unblock_player", "رمز اللاعب غير صالح.")
		return false
	return _rpc("unblock_my_test_player", {"p_player_code": clean_code}, "unblock_player")

func report_player(player_code: String, reason: String, details: String) -> bool:
	var clean_code := player_code.strip_edges().to_upper()
	var clean_details := details.strip_edges()
	if not is_valid_player_code(clean_code) or clean_details.length() > 300:
		operation_failed.emit("report_player", "بيانات البلاغ غير صالحة.")
		return false
	if not ["harassment", "spam", "inappropriate_name", "cheating", "other"].has(reason):
		operation_failed.emit("report_player", "اختر سببًا صحيحًا للبلاغ.")
		return false
	return _rpc("report_my_test_player", {
		"p_player_code": clean_code,
		"p_reason": reason,
		"p_details": clean_details
	}, "report_player")

func open_direct_conversation(player_code: String) -> bool:
	return _rpc("open_test_direct_conversation", {"p_player_code": player_code}, "direct_open")

func read_direct_messages(conversation_id: String) -> bool:
	if conversation_id.is_empty():
		return false
	return _rpc("read_test_direct_messages", {
		"p_conversation_id": conversation_id,
		"p_before_message_id": null,
		"p_limit": 50
	}, "direct_read")

func send_direct_message(conversation_id: String, body: String) -> bool:
	var clean_body := body.strip_edges()
	if conversation_id.is_empty() or clean_body.is_empty() or clean_body.length() > 300:
		operation_failed.emit("direct_send", "رسالة غير صالحة أو محادثة غير محددة.")
		return false
	return _rpc("send_test_direct_message", {
		"p_conversation_id": conversation_id,
		"p_body": clean_body
	}, "direct_send")

func check_moderator_access() -> bool:
	return _rpc("is_my_test_moderator", {}, "moderator_check")

func list_moderation_reports() -> bool:
	return _rpc("list_test_player_reports_for_moderation", {}, "moderation_reports")

func set_moderation_report_status(report_id: String, status: String) -> bool:
	if report_id.is_empty() or not ["reviewing", "resolved", "dismissed"].has(status):
		operation_failed.emit("moderation_update", "طلب مراجعة غير صالح.")
		return false
	return _rpc("set_test_player_report_status", {
		"p_report_id": report_id,
		"p_status": status
	}, "moderation_update")

func _rpc(function_name: String, payload: Dictionary, action: String) -> bool:
	if not AuthManager.is_authenticated():
		operation_failed.emit(action, "سجّل الدخول أولًا.")
		return false
	if not _pending_action.is_empty() or _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		operation_failed.emit(action, "هناك طلب اجتماعي آخر قيد التنفيذ.")
		return false
	_pending_action = action
	var headers := PackedStringArray([
		"apikey: " + SUPABASE_PUBLISHABLE_KEY,
		"Authorization: Bearer " + AuthManager.get_access_token(),
		"Content-Type: application/json",
		"Accept: application/json"
	])
	var endpoint := SUPABASE_URL + "/rest/v1/rpc/" + function_name
	var error := _http.request(endpoint, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		_pending_action = ""
		operation_failed.emit(action, "تعذر بدء الاتصال بالخادم.")
		return false
	return true

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var action := _pending_action
	_pending_action = ""
	if action.is_empty():
		return
	if result != HTTPRequest.RESULT_SUCCESS:
		operation_failed.emit(action, "تعذر الاتصال بخدمة التواصل.")
		return
	var text_body := body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text_body)
	if response_code < 200 or response_code >= 300:
		operation_failed.emit(action, "رفض الخادم الطلب (HTTP %d)." % response_code)
		return
	operation_completed.emit(action, parsed)

func create_chat_group() -> bool:
	return _rpc("create_my_test_chat_group", {}, "group_create")

func get_chat_group() -> bool:
	return _rpc("get_my_test_chat_group", {}, "group_info")

func invite_chat_group_member(player_code: String) -> bool:
	return _rpc("invite_my_test_chat_group_member", {"p_player_code": player_code}, "group_invite")

func respond_chat_group_invite(invite_id: String, accept: bool) -> bool:
	return _rpc("respond_my_test_chat_group_invite", {"p_invite_id": invite_id, "p_accept": accept}, "group_invite_response")

func send_chat_message(channel: String, body: String) -> bool:
	return _rpc("send_my_test_chat_message", {"p_channel": channel, "p_body": body}, "chat_send")

func read_chat_messages(channel: String) -> bool:
	return _rpc("read_my_test_chat_messages", {
		"p_channel": channel,
		"p_before_message_id": null,
		"p_limit": 50
	}, "chat_read")

func _process(delta: float) -> void:
	if not AuthManager.is_authenticated():
		if _realtime_socket != null and _realtime_socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
			_realtime_socket.close()
		_realtime_socket = null
		_realtime_connected = false
		_realtime_topics.clear()
		_realtime_join_refs.clear()
		_realtime_player_code = ""
		_realtime_group_id = ""
		_realtime_direct_id = ""
		return
	if _realtime_socket == null:
		_realtime_retry_elapsed += delta
		if _realtime_retry_elapsed >= _realtime_retry_delay:
			_connect_realtime_socket()
		return
	_realtime_socket.poll()
	var state := _realtime_socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _realtime_connected:
			_realtime_connected = true
			_realtime_retry_elapsed = 0.0
			_realtime_retry_delay = 2.0
			_realtime_last_token = AuthManager.get_access_token()
			realtime_status_changed.emit("متصل")
			for topic in _realtime_topics.keys():
				_join_realtime_topic(str(topic))
		var token := AuthManager.get_access_token()
		if not token.is_empty() and token != _realtime_last_token:
			_realtime_last_token = token
			for topic in _realtime_join_refs.keys():
				_send_realtime_frame("realtime:" + str(topic), "access_token", {"access_token": token}, str(_realtime_join_refs[topic]))
		_realtime_heartbeat_elapsed += delta
		if _realtime_heartbeat_elapsed >= 25.0:
			_realtime_heartbeat_elapsed = 0.0
			_send_realtime_frame("phoenix", "heartbeat", {}, "")
		while _realtime_socket.get_available_packet_count() > 0:
			_handle_realtime_packet(_realtime_socket.get_packet())
	elif state == WebSocketPeer.STATE_CLOSED:
		if _realtime_connected:
			_realtime_connected = false
			_realtime_join_refs.clear()
			realtime_status_changed.emit("انقطع الاتصال؛ جارٍ إعادة المحاولة")
		_realtime_retry_elapsed += delta
		if _realtime_retry_elapsed >= _realtime_retry_delay:
			_realtime_retry_elapsed = 0.0
			_realtime_retry_delay = min(_realtime_retry_delay * 2.0, 10.0)
			_connect_realtime_socket()


func connect_realtime() -> void:
	if not AuthManager.is_authenticated():
		return
	_realtime_topics["chat:public:messages"] = true
	if not _realtime_player_code.is_empty():
		_realtime_topics["chat:invites:" + _realtime_player_code] = true
	if _realtime_socket == null or _realtime_socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		_realtime_retry_elapsed = _realtime_retry_delay
		_connect_realtime_socket()


func _connect_realtime_socket() -> void:
	if not AuthManager.is_authenticated():
		return
	_realtime_socket = WebSocketPeer.new()
	var endpoint := SUPABASE_URL.replace("https://", "wss://") + "/realtime/v1/websocket?apikey=" + SUPABASE_PUBLISHABLE_KEY.uri_encode() + "&vsn=1.0.0"
	var error := _realtime_socket.connect_to_url(endpoint)
	if error != OK:
		_realtime_socket = null
		_realtime_retry_elapsed = 0.0
		realtime_status_changed.emit("تعذر فتح اتصال الدردشة اللحظية")
		return
	_realtime_connected = false
	_realtime_join_refs.clear()


func get_realtime_identity() -> bool:
	return _rpc("get_my_test_chat_realtime_identity", {}, "chat_identity")


func list_chat_group_invites() -> bool:
	return _rpc("list_my_test_chat_group_invites", {}, "chat_invites")


func set_realtime_player_code(player_code: String) -> void:
	_realtime_player_code = player_code.strip_edges().to_upper()
	if not _realtime_player_code.is_empty():
		_subscribe_realtime_topic("chat:invites:" + _realtime_player_code)


func subscribe_group_chat(group_id: String) -> void:
	if _realtime_group_id == group_id:
		return
	if not _realtime_group_id.is_empty():
		_leave_realtime_topic("chat:group:" + _realtime_group_id)
	_realtime_group_id = group_id
	if not group_id.is_empty():
		_subscribe_realtime_topic("chat:group:" + group_id)


func subscribe_direct_chat(conversation_id: String) -> void:
	if _realtime_direct_id == conversation_id:
		return
	if not _realtime_direct_id.is_empty():
		_leave_realtime_topic("chat:direct:" + _realtime_direct_id)
	_realtime_direct_id = conversation_id
	if not conversation_id.is_empty():
		_subscribe_realtime_topic("chat:direct:" + conversation_id)


func _subscribe_realtime_topic(topic: String) -> void:
	_realtime_topics[topic] = true
	if _realtime_connected:
		_join_realtime_topic(topic)


func _leave_realtime_topic(topic: String) -> void:
	_realtime_topics.erase(topic)
	if _realtime_join_refs.has(topic) and _realtime_connected:
		_send_realtime_frame("realtime:" + topic, "phx_leave", {}, str(_realtime_join_refs[topic]))
	_realtime_join_refs.erase(topic)


func _join_realtime_topic(topic: String) -> void:
	if not _realtime_connected or _realtime_join_refs.has(topic):
		return
	_realtime_ref += 1
	var join_ref := str(_realtime_ref)
	_realtime_join_refs[topic] = join_ref
	var payload := {
		"config": {
			"broadcast": {"ack": false, "self": false},
			"presence": {"enabled": false},
			"postgres_changes": [],
			"private": true
		},
		"access_token": AuthManager.get_access_token()
	}
	_send_realtime_frame("realtime:" + topic, "phx_join", payload, join_ref)


func _send_realtime_frame(topic: String, event_name: String, payload: Dictionary, join_ref: String) -> void:
	if _realtime_socket == null or _realtime_socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_realtime_ref += 1
	var frame := {"topic": topic, "event": event_name, "payload": payload, "ref": str(_realtime_ref)}
	if not join_ref.is_empty():
		frame["join_ref"] = join_ref
	_realtime_socket.send_text(JSON.stringify(frame))


func _handle_realtime_packet(packet: PackedByteArray) -> void:
	var parsed: Variant = JSON.parse_string(packet.get_string_from_utf8())
	if not parsed is Dictionary:
		return
	var topic := str(parsed.get("topic", "")).trim_prefix("realtime:")
	var event_name := str(parsed.get("event", ""))
	var payload: Variant = parsed.get("payload", {})
	if event_name == "phx_reply":
		if payload is Dictionary and str(payload.get("status", "")) == "error":
			realtime_status_changed.emit("رفض الخادم قناة: " + topic)
		elif payload is Dictionary and str(payload.get("status", "")) == "ok":
			realtime_status_changed.emit("القنوات اللحظية جاهزة")
		return
	if event_name == "phx_error" or event_name == "phx_close":
		_realtime_join_refs.erase(topic)
		return
	if event_name == "broadcast" and payload is Dictionary:
		var broadcast_event := str(payload.get("event", ""))
		var broadcast_payload: Variant = payload.get("payload", {})
		if broadcast_payload is Dictionary:
			realtime_event.emit(topic, broadcast_event, broadcast_payload)
