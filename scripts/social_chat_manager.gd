extends Node
## Authenticated REST RPC bridge for test social features.
signal operation_completed(action: String, data: Variant)
signal operation_failed(action: String, message: String)
signal realtime_event(topic: String, event_name: String, payload: Dictionary)
signal realtime_status_changed(status: String)
signal city_presence_counts_changed(counts: Dictionary)

const SUPABASE_URL := "https://unwrlvyjrtdwobcktetd.supabase.co"
const SUPABASE_PUBLISHABLE_KEY := "sb_publishable_BrWeMmhyOpL73Uca40Ug0Q_8Zgw55si"

var _http: HTTPRequest
var _pending_action := ""
var _pending_user_id := ""
var _pending_session_generation := -1
var _rpc_queue: Array[Dictionary] = []
var _friend_requests_poll_elapsed := 0.0
var _friend_requests_poll_pending := false
const FRIEND_REQUESTS_POLL_INTERVAL := 30.0
var _realtime_socket: WebSocketPeer
var _realtime_topics: Dictionary = {}
var _realtime_join_refs: Dictionary = {}
var _realtime_ready_topics: Dictionary = {}
var _realtime_topic_retry_seconds: Dictionary = {}
var _realtime_topic_retry_attempts: Dictionary = {}
const REALTIME_TOPIC_RETRY_DELAY := 2.0
const MAX_REALTIME_TOPIC_RETRIES := 3
var _realtime_ref := 0
var _realtime_heartbeat_elapsed := 0.0
var _realtime_retry_elapsed := 0.0
var _realtime_retry_delay := 2.0
var _realtime_connected := false
var _realtime_last_token := ""
var _realtime_session_user_id := ""
var _realtime_session_generation := -1
var _realtime_player_code := ""
var _realtime_group_id := ""
var _realtime_direct_id := ""
const CITY_PRESENCE_TOPIC := "game:city:presence"
const CITY_SECTORS := ["north_west", "north_east", "south_west", "south_east", "south_center"]
var _city_presence_key := ""
var _city_presence_sector := "north_west"
var _city_presence_entries: Dictionary = {}

func _ready() -> void:
	_city_presence_key = _make_city_presence_key()
	if not AuthManager.session_changed.is_connected(_on_auth_session_changed):
		AuthManager.session_changed.connect(_on_auth_session_changed)

func _on_auth_session_changed(_previous_user_id: String, _current_user_id: String, _generation: int) -> void:
	# Cancel in-flight RPC work before releasing its account/session ownership.
	_rpc_queue.clear()
	_friend_requests_poll_elapsed = 0.0
	_friend_requests_poll_pending = false
	if not _pending_action.is_empty():
		_pending_action = ""
		_pending_user_id = ""
		_pending_session_generation = -1
		var previous_request := _http
		_http = null
		if is_instance_valid(previous_request):
			previous_request.cancel_request()
			previous_request.queue_free()
	# Never carry a prior account's realtime subscriptions into a new identity.
	if _realtime_socket != null:
		if _realtime_socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
			_realtime_socket.close()
		_realtime_socket = null
	_realtime_connected = false
	_realtime_topics.clear()
	_realtime_join_refs.clear()
	_realtime_ready_topics.clear()
	_realtime_topic_retry_seconds.clear()
	_realtime_topic_retry_attempts.clear()
	_realtime_last_token = ""
	_realtime_session_user_id = ""
	_realtime_session_generation = -1
	_realtime_player_code = ""
	_realtime_group_id = ""
	_realtime_direct_id = ""
	_city_presence_key = _make_city_presence_key()
	_clear_city_presence_state()
	_realtime_heartbeat_elapsed = 0.0
	_realtime_retry_elapsed = 0.0
	realtime_status_changed.emit("تم فصل الاتصال السابق؛ يلزم إعادة الاشتراك للحساب الحالي")

func _request_session_is_current(user_id: String, generation: int) -> bool:
	return not user_id.is_empty() and AuthManager.is_session_current(user_id, generation)

func _realtime_session_is_current() -> bool:
	return _request_session_is_current(_realtime_session_user_id, _realtime_session_generation)

func get_daily_chest_status() -> bool:
	return _rpc("get_my_test_daily_chest_status", {}, "daily_chest_status")

func claim_daily_chest_reward() -> bool:
	return _rpc("claim_my_test_daily_chest", {}, "daily_chest_claim")

func get_my_display_name() -> bool:
	return _rpc("get_my_test_display_name", {}, "display_name_get")

func change_my_display_name(new_name: String) -> bool:
	var clean_name := new_name.strip_edges()
	if clean_name.is_empty() or clean_name.length() > 24:
		operation_failed.emit("display_name_change", "الاسم يجب أن يكون من 1 إلى 24 حرفًا.")
		return false
	return _rpc("change_my_test_display_name", {"p_new_display_name": clean_name}, "display_name_change")

func list_friends() -> bool:
	return _rpc("list_test_friends", {}, "friends_list")

func list_friend_requests() -> bool:
	if _friend_requests_poll_pending:
		return false
	var started := _rpc("list_test_friend_requests", {}, "friend_requests_list")
	if started:
		_friend_requests_poll_pending = true
		_friend_requests_poll_elapsed = 0.0
	return started

func respond_friend_request(request_id: String, accept: bool) -> bool:
	var clean_id := request_id.strip_edges().to_lower()
	if not is_valid_invite_id(clean_id):
		operation_failed.emit("friend_request_response", "معرّف طلب الصداقة غير صالح.")
		return false
	return _rpc("respond_test_friend_request", {"p_request_id": clean_id, "p_accept": accept}, "friend_request_response")

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
	var clean_code := player_code.strip_edges().to_upper()
	if not is_valid_player_code(clean_code):
		operation_failed.emit("direct_open", "رمز اللاعب غير صالح.")
		return false
	return _rpc("open_test_direct_conversation", {"p_player_code": clean_code}, "direct_open")

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
	var request_user_id := AuthManager.get_authenticated_user_id()
	var request_generation := AuthManager.get_session_generation()
	if not _request_session_is_current(request_user_id, request_generation):
		operation_failed.emit(action, "انتهت جلسة الحساب؛ سجّل الدخول مرة أخرى.")
		return false
	var queued_request := {
		"function_name": function_name,
		"payload": payload.duplicate(true),
		"action": action,
		"user_id": request_user_id,
		"generation": request_generation
	}
	if not _pending_action.is_empty() or is_instance_valid(_http):
		_rpc_queue.append(queued_request)
		return true
	return _start_rpc_request(queued_request)

func _start_rpc_request(queued_request: Dictionary) -> bool:
	var action := str(queued_request.get("action", ""))
	var request_user_id := str(queued_request.get("user_id", ""))
	var request_generation := int(queued_request.get("generation", -1))
	if not _request_session_is_current(request_user_id, request_generation):
		return false
	var request := HTTPRequest.new()
	request.name = "SocialRpcHTTPRequest"
	request.timeout = 20.0
	add_child(request)
	_http = request
	_pending_action = action
	_pending_user_id = request_user_id
	_pending_session_generation = request_generation
	request.request_completed.connect(_on_request_completed.bind(action, request_user_id, request_generation, request))
	var headers := PackedStringArray([
		"apikey: " + SUPABASE_PUBLISHABLE_KEY,
		"Authorization: Bearer " + AuthManager.get_access_token(),
		"Content-Type: application/json",
		"Accept: application/json"
	])
	var endpoint := SUPABASE_URL + "/rest/v1/rpc/" + str(queued_request.get("function_name", ""))
	var error := request.request(endpoint, headers, HTTPClient.METHOD_POST, JSON.stringify(queued_request.get("payload", {})))
	if error != OK:
		if _http == request:
			_http = null
			_pending_action = ""
			_pending_user_id = ""
			_pending_session_generation = -1
		request.queue_free()
		if action == "friend_requests_list":
			_friend_requests_poll_pending = false
			_friend_requests_poll_elapsed = 0.0
		operation_failed.emit(action, "تعذر بدء الاتصال بالخادم.")
		return false
	return true

func _start_next_queued_rpc() -> void:
	while _rpc_queue.size() > 0:
		var queued_request: Dictionary = _rpc_queue.pop_front()
		if not _request_session_is_current(str(queued_request.get("user_id", "")), int(queued_request.get("generation", -1))):
			continue
		if _start_rpc_request(queued_request):
			return

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, action: String, request_user_id: String, request_generation: int, request: HTTPRequest) -> void:
	var owns_pending_slot := _http == request
	if owns_pending_slot:
		_http = null
		_pending_action = ""
		_pending_user_id = ""
		_pending_session_generation = -1
	if is_instance_valid(request):
		request.queue_free()
	if owns_pending_slot:
		_start_next_queued_rpc()
	if action == "friend_requests_list" and owns_pending_slot and _request_session_is_current(request_user_id, request_generation):
		_friend_requests_poll_pending = false
	# Request identity is immutable; an old callback can never inherit a newer account's pending metadata.
	if not owns_pending_slot or action.is_empty():
		return
	# A response from an account that signed out or switched identity is discarded.
	if not _request_session_is_current(request_user_id, request_generation):
		return
	if result != HTTPRequest.RESULT_SUCCESS:
		operation_failed.emit(action, "تعذر الاتصال بخدمة التواصل.")
		return
	var text_body := body.get_string_from_utf8()
	if response_code < 200 or response_code >= 300:
		operation_failed.emit(action, "رفض الخادم الطلب (HTTP %d)." % response_code)
		return
	var response_json := JSON.new()
	if response_json.parse(text_body) != OK:
		operation_failed.emit(action, "استجابة خدمة التواصل غير صالحة. حاول مرة أخرى.")
		return
	operation_completed.emit(action, response_json.data)

func start_test_party(station_key: String) -> bool:
	var clean_station_key := station_key.strip_edges()
	if clean_station_key.is_empty() or clean_station_key.length() > 80 or not clean_station_key.is_valid_identifier():
		operation_failed.emit("party_start", "معرّف محطة الحفلة غير صالح.")
		return false
	return _rpc("start_my_test_party", {"p_station_key": clean_station_key}, "party_start")

func create_chat_group() -> bool:
	return _rpc("create_my_test_chat_group", {}, "group_create")

func get_chat_group() -> bool:
	return _rpc("get_my_test_chat_group", {}, "group_info")

func invite_chat_group_member(player_code: String) -> bool:
	var clean_code := player_code.strip_edges().to_upper()
	if not is_valid_player_code(clean_code):
		operation_failed.emit("group_invite", "رمز اللاعب غير صالح.")
		return false
	return _rpc("invite_my_test_chat_group_member", {"p_player_code": clean_code}, "group_invite")

func is_valid_invite_id(invite_id: String) -> bool:
	var validator := RegEx.new()
	if validator.compile("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$") != OK:
		return false
	return validator.search(invite_id.strip_edges().to_lower()) != null


func respond_chat_group_invite(invite_id: String, accept: bool) -> bool:
	var clean_invite_id := invite_id.strip_edges().to_lower()
	if not is_valid_invite_id(clean_invite_id):
		operation_failed.emit("group_invite_response", "معرّف الدعوة غير صالح.")
		return false
	return _rpc("respond_my_test_chat_group_invite", {"p_invite_id": clean_invite_id, "p_accept": accept}, "group_invite_response")

func send_chat_message(channel: String, body: String) -> bool:
	var clean_channel := channel.strip_edges().to_lower()
	var clean_body := body.strip_edges()
	if not ["public", "group"].has(clean_channel) or clean_body.is_empty() or clean_body.length() > 300:
		operation_failed.emit("chat_send", "القناة أو نص الرسالة غير صالح.")
		return false
	return _rpc("send_my_test_chat_message", {"p_channel": clean_channel, "p_body": clean_body}, "chat_send")

func read_chat_messages(channel: String) -> bool:
	var clean_channel := channel.strip_edges().to_lower()
	if not ["public", "group"].has(clean_channel):
		operation_failed.emit("chat_read", "قناة المحادثة غير صالحة.")
		return false
	return _rpc("read_my_test_chat_messages", {
		"p_channel": clean_channel,
		"p_before_message_id": null,
		"p_limit": 50
	}, "chat_read")

func _process(delta: float) -> void:
	if _realtime_socket != null and not _realtime_session_is_current():
		_realtime_socket.close()
		_realtime_socket = null
		_realtime_connected = false
		# A stale socket must not replay topics or identities after reconnecting.
		_realtime_topics.clear()
		_realtime_join_refs.clear()
		_realtime_ready_topics.clear()
		_realtime_topic_retry_seconds.clear()
		_realtime_topic_retry_attempts.clear()
		_realtime_last_token = ""
		_realtime_session_user_id = ""
		_realtime_session_generation = -1
		_realtime_player_code = ""
		_realtime_group_id = ""
		_realtime_direct_id = ""
		_realtime_heartbeat_elapsed = 0.0
		_realtime_retry_elapsed = 0.0
		realtime_status_changed.emit("تم إلغاء اشتراكات جلسة منتهية")
	if not AuthManager.is_authenticated():
		_rpc_queue.clear()
		_friend_requests_poll_elapsed = 0.0
		_friend_requests_poll_pending = false
		if _realtime_socket != null and _realtime_socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
			_realtime_socket.close()
		_realtime_socket = null
		_realtime_connected = false
		_realtime_topics.clear()
		_realtime_join_refs.clear()
		_realtime_ready_topics.clear()
		_realtime_topic_retry_seconds.clear()
		_realtime_topic_retry_attempts.clear()
		_realtime_player_code = ""
		_realtime_group_id = ""
		_realtime_direct_id = ""
		_clear_city_presence_state()
		return
	_friend_requests_poll_elapsed += maxf(0.0, delta)
	if _friend_requests_poll_elapsed >= FRIEND_REQUESTS_POLL_INTERVAL and not _friend_requests_poll_pending:
		list_friend_requests()
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
		_process_realtime_topic_retries(delta)
	elif state == WebSocketPeer.STATE_CLOSED:
		if _realtime_connected:
			_realtime_connected = false
			_realtime_join_refs.clear()
			_realtime_ready_topics.clear()
			_clear_city_presence_state()
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
	_realtime_topics["party:city:events"] = true
	_realtime_topics[CITY_PRESENCE_TOPIC] = true
	if not _realtime_player_code.is_empty():
		_realtime_topics["chat:invites:" + _realtime_player_code] = true
	if _realtime_socket == null or _realtime_socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		_realtime_retry_elapsed = _realtime_retry_delay
		_connect_realtime_socket()


func _connect_realtime_socket() -> void:
	if not AuthManager.is_authenticated():
		return
	var socket_user_id := AuthManager.get_authenticated_user_id()
	var socket_generation := AuthManager.get_session_generation()
	if not _request_session_is_current(socket_user_id, socket_generation):
		return
	_realtime_session_user_id = socket_user_id
	_realtime_session_generation = socket_generation
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
	_realtime_ready_topics.clear()


func get_realtime_identity() -> bool:
	return _rpc("get_my_test_chat_realtime_identity", {}, "chat_identity")


func list_chat_group_invites() -> bool:
	return _rpc("list_my_test_chat_group_invites", {}, "chat_invites")


func set_realtime_player_code(player_code: String) -> void:
	var clean_code := player_code.strip_edges().to_upper()
	if clean_code == _realtime_player_code:
		return
	if not _realtime_player_code.is_empty():
		_leave_realtime_topic("chat:invites:" + _realtime_player_code)
	_realtime_player_code = ""
	if not is_valid_player_code(clean_code):
		return
	_realtime_player_code = clean_code
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
	_realtime_topic_retry_seconds.erase(topic)
	_realtime_topic_retry_attempts.erase(topic)
	_realtime_ready_topics.erase(topic)
	if _realtime_join_refs.has(topic) and _realtime_connected:
		_send_realtime_frame("realtime:" + topic, "phx_leave", {}, str(_realtime_join_refs[topic]))
	_realtime_join_refs.erase(topic)


func _join_realtime_topic(topic: String) -> void:
	if not _realtime_connected or _realtime_join_refs.has(topic):
		return
	_realtime_topic_retry_seconds.erase(topic)
	_realtime_ref += 1
	var join_ref := str(_realtime_ref)
	_realtime_ready_topics.erase(topic)
	_realtime_join_refs[topic] = join_ref
	var presence_enabled := topic == CITY_PRESENCE_TOPIC
	var payload := {
		"config": {
			"broadcast": {"ack": false, "self": false},
			"presence": {"enabled": presence_enabled, "key": _city_presence_key if presence_enabled else ""},
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


func _schedule_realtime_topic_retry(topic: String, failed_join_ref: String) -> void:
	# Ignore stale failures and channels the current account no longer wants.
	var active_join_ref := str(_realtime_join_refs.get(topic, ""))
	if not _realtime_topics.has(topic) or active_join_ref.is_empty():
		return
	if not failed_join_ref.is_empty() and active_join_ref != failed_join_ref:
		return
	_realtime_join_refs.erase(topic)
	_realtime_ready_topics.erase(topic)
	var attempts := int(_realtime_topic_retry_attempts.get(topic, 0)) + 1
	if attempts > MAX_REALTIME_TOPIC_RETRIES:
		_realtime_topic_retry_seconds.erase(topic)
		_realtime_topic_retry_attempts.erase(topic)
		realtime_status_changed.emit("تعذر استعادة القناة بعد عدة محاولات: " + topic)
		return
	_realtime_topic_retry_attempts[topic] = attempts
	_realtime_topic_retry_seconds[topic] = REALTIME_TOPIC_RETRY_DELAY


func _take_due_realtime_topic_retries(delta: float) -> Array[String]:
	var due_topics: Array[String] = []
	for topic_variant in _realtime_topic_retry_seconds.keys():
		var topic := str(topic_variant)
		if not _realtime_topics.has(topic) or _realtime_join_refs.has(topic):
			_realtime_topic_retry_seconds.erase(topic)
			continue
		var remaining := maxf(0.0, float(_realtime_topic_retry_seconds[topic]) - maxf(0.0, delta))
		if remaining <= 0.0:
			_realtime_topic_retry_seconds.erase(topic)
			due_topics.append(topic)
		else:
			_realtime_topic_retry_seconds[topic] = remaining
	return due_topics


func _process_realtime_topic_retries(delta: float) -> void:
	if not _realtime_connected or not _realtime_session_is_current():
		return
	for topic in _take_due_realtime_topic_retries(delta):
		_join_realtime_topic(topic)


func is_realtime_join_ack_current(topic: String, join_ref: String) -> bool:
	return not topic.is_empty() and not join_ref.is_empty() and _realtime_topics.has(topic) and str(_realtime_join_refs.get(topic, "")) == join_ref


func is_realtime_topic_subscribed(topic: String) -> bool:
	return not topic.is_empty() and _realtime_topics.has(topic) and _realtime_join_refs.has(topic) and _realtime_ready_topics.has(topic)


func _handle_realtime_packet(packet: PackedByteArray) -> void:
	if not _realtime_session_is_current():
		return
	var parsed: Variant = JSON.parse_string(packet.get_string_from_utf8())
	if not parsed is Dictionary:
		return
	var topic := str(parsed.get("topic", "")).trim_prefix("realtime:")
	var event_name := str(parsed.get("event", ""))
	var payload: Variant = parsed.get("payload", {})
	if event_name == "phx_reply":
		var reply_join_ref := str(parsed.get("join_ref", ""))
		if payload is Dictionary and str(payload.get("status", "")) == "error":
			_schedule_realtime_topic_retry(topic, reply_join_ref)
			realtime_status_changed.emit("تعذر الانضمام للقناة؛ ستتم إعادة المحاولة: " + topic)
		elif payload is Dictionary and str(payload.get("status", "")) == "ok":
			if is_realtime_join_ack_current(topic, reply_join_ref):
				_realtime_topic_retry_seconds.erase(topic)
				_realtime_topic_retry_attempts.erase(topic)
				_realtime_ready_topics[topic] = true
				if topic == CITY_PRESENCE_TOPIC:
					_send_city_presence_track()
				realtime_status_changed.emit("القنوات اللحظية جاهزة")
		return
	if event_name == "phx_error" or event_name == "phx_close":
		if topic == CITY_PRESENCE_TOPIC:
			_clear_city_presence_state()
		_schedule_realtime_topic_retry(topic, str(parsed.get("join_ref", "")))
		return
	if topic == CITY_PRESENCE_TOPIC and payload is Dictionary:
		if not is_realtime_topic_subscribed(CITY_PRESENCE_TOPIC):
			return
		if event_name == "presence_state":
			_apply_city_presence_state(payload)
			return
		if event_name == "presence_diff":
			_apply_city_presence_diff(payload)
			return
	if event_name == "broadcast" and payload is Dictionary:
		# Ignore packets for channels this session has not successfully joined.
		if not is_realtime_topic_subscribed(topic):
			return
		var broadcast_event := str(payload.get("event", ""))
		var broadcast_payload: Variant = payload.get("payload", {})
		if broadcast_payload is Dictionary:
			realtime_event.emit(topic, broadcast_event, broadcast_payload)

func _make_city_presence_key() -> String:
	return "session_%s_%s" % [str(Time.get_ticks_usec()), str(randi())]

func set_city_presence_sector(sector: String) -> void:
	var clean_sector := sector.strip_edges().to_lower()
	if clean_sector != "interior" and not CITY_SECTORS.has(clean_sector):
		return
	if clean_sector == _city_presence_sector:
		return
	_city_presence_sector = clean_sector
	if is_realtime_topic_subscribed(CITY_PRESENCE_TOPIC):
		_send_city_presence_track()

func get_city_presence_counts() -> Dictionary:
	return _build_city_presence_counts()

func _send_city_presence_track() -> void:
	if not is_realtime_topic_subscribed(CITY_PRESENCE_TOPIC) or not AuthManager.is_authenticated():
		return
	var join_ref := str(_realtime_join_refs.get(CITY_PRESENCE_TOPIC, ""))
	if join_ref.is_empty():
		return
	_send_realtime_frame("realtime:" + CITY_PRESENCE_TOPIC, "presence", {
		"type": "presence",
		"event": "track",
		"payload": {"sector": _city_presence_sector}
	}, join_ref)

func _extract_city_presence_sector(metas: Variant) -> String:
	if metas is Array:
		for index in range(metas.size() - 1, -1, -1):
			if metas[index] is Dictionary:
				var meta_sector := str(metas[index].get("sector", ""))
				if CITY_SECTORS.has(meta_sector) or meta_sector == "interior":
					return meta_sector
	elif metas is Dictionary:
		var payload_sector := str(metas.get("sector", ""))
		if CITY_SECTORS.has(payload_sector) or payload_sector == "interior":
			return payload_sector
	return ""

func _apply_city_presence_state(state: Dictionary) -> void:
	_city_presence_entries.clear()
	for presence_key in state.keys():
		var sector := _extract_city_presence_sector(state[presence_key])
		if not sector.is_empty():
			_city_presence_entries[str(presence_key)] = sector
	_emit_city_presence_counts()

func _apply_city_presence_diff(diff: Dictionary) -> void:
	var leaves: Variant = diff.get("leaves", {})
	if leaves is Dictionary:
		for presence_key in leaves.keys():
			_city_presence_entries.erase(str(presence_key))
	var joins: Variant = diff.get("joins", {})
	if joins is Dictionary:
		for presence_key in joins.keys():
			var sector := _extract_city_presence_sector(joins[presence_key])
			if not sector.is_empty():
				_city_presence_entries[str(presence_key)] = sector
	_emit_city_presence_counts()

func _build_city_presence_counts() -> Dictionary:
	var counts := {
		"north_west": 0,
		"north_east": 0,
		"south_west": 0,
		"south_east": 0,
		"south_center": 0
	}
	for sector_variant in _city_presence_entries.values():
		var sector := str(sector_variant)
		if counts.has(sector):
			counts[sector] = int(counts[sector]) + 1
	return counts

func _emit_city_presence_counts() -> void:
	city_presence_counts_changed.emit(_build_city_presence_counts())

func _clear_city_presence_state() -> void:
	_city_presence_entries.clear()
	_emit_city_presence_counts()
