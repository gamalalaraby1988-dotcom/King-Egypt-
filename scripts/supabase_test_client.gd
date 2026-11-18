extends Node
## عميل Supabase Auth وقراءة اقتصاد الحساب التجريبي فقط.
## لا يحتوي على service_role ولا ينفذ أي تعديل للأرصدة.

signal auth_changed(is_authenticated: bool, user_id: String)
signal economy_snapshot_received(snapshot: Dictionary)
signal request_failed(message: String)

const SUPABASE_URL := "https://unwrlvyjrtdwobcktetd.supabase.co"
const SUPABASE_PUBLISHABLE_KEY := "sb_publishable_BrWeMmhyOpL73Uca40Ug0_8Zgw55si"
const TEST_AUTH_USER_ID := "2e991d5c-4a28-4d93-a111-28043a1a9063"

var access_token := ""
var refresh_token := ""
var user_id := ""
var economy_snapshot: Dictionary = {}
var _http: HTTPRequest
var _request_in_flight := false
var _session_generation := 0
var _pending_logout_token := ""
var _realtime_socket: WebSocketPeer
var _realtime_topic := ""
var _realtime_join_ref := ""
var _realtime_join_sent := false
var _realtime_ref := 0
var _heartbeat_elapsed := 0.0

signal social_event(event_name: String, payload: Dictionary)

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 20.0
	add_child(_http)

func _process(delta: float) -> void:
	if not is_instance_valid(_realtime_socket):
		return
	_realtime_socket.poll()
	if _realtime_socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		if not _realtime_join_sent:
			_join_realtime_topic()
		_heartbeat_elapsed += delta
		if _heartbeat_elapsed >= 20.0:
			_heartbeat_elapsed = 0.0
			_send_realtime_frame("phoenix", "heartbeat", {}, "")
		while is_instance_valid(_realtime_socket) and _realtime_socket.get_available_packet_count() > 0:
			var packet := _realtime_socket.get_packet()
			if not _realtime_socket.was_string_packet():
				continue
			var parsed: Variant = JSON.parse_string(packet.get_string_from_utf8())
			if parsed is Dictionary:
				_handle_realtime_frame(parsed)

func is_authenticated() -> bool:
	return not access_token.is_empty() and not user_id.is_empty()

func sign_in_with_password(email: String, password: String) -> bool:
	# لا تحتفظ بجلسة سابقة إذا فشلت محاولة تسجيل الدخول الجديدة.
	if _request_in_flight:
		request_failed.emit("هناك طلب اتصال جارٍ؛ انتظر حتى ينتهي.")
		return false
	_clear_session()
	var attempt_generation := _session_generation
	if email.strip_edges().is_empty() or password.is_empty():
		request_failed.emit("أدخل البريد وكلمة المرور.")
		return false
	var result := await _send_json(
		HTTPClient.METHOD_POST,
		"/auth/v1/token?grant_type=password",
		{"email": email.strip_edges(), "password": password},
		""
	)
	if attempt_generation != _session_generation:
		var cancelled_data: Dictionary = result.get("data", {}) if result.get("data", {}) is Dictionary else {}
		var cancelled_access := str(cancelled_data.get("access_token", ""))
		if bool(result.get("ok", false)) and not cancelled_access.is_empty():
			await _send_json(HTTPClient.METHOD_POST, "/auth/v1/logout", {}, cancelled_access)
		return false
	if not bool(result.get("ok", false)):
		request_failed.emit(str(result.get("message", "تعذر تسجيل الدخول.")))
		return false
	var data: Dictionary = result.get("data", {})
	var user: Dictionary = data.get("user", {})
	var returned_user_id := str(user.get("id", ""))
	var returned_access := str(data.get("access_token", ""))
	var returned_refresh := str(data.get("refresh_token", ""))
	if returned_user_id.is_empty() or returned_access.is_empty() or returned_refresh.is_empty():
		request_failed.emit("استجابة تسجيل الدخول غير مكتملة.")
		return false
	if returned_user_id != TEST_AUTH_USER_ID:
		await _send_json(HTTPClient.METHOD_POST, "/auth/v1/logout", {}, returned_access)
		request_failed.emit("هذا الحساب ليس حساب الاختبار المخصص للمشروع.")
		return false
	access_token = returned_access
	refresh_token = returned_refresh
	user_id = returned_user_id
	var login_access_token := access_token
	await fetch_economy_snapshot()
	# لا تطلق حدث المزامنة قبل انتهاء طلب لقطة الاقتصاد؛ عميل HTTP واحد فقط.
	if not is_authenticated() or access_token != login_access_token:
		return false
	auth_changed.emit(true, user_id)
	return true

func refresh_session() -> bool:
	if _request_in_flight:
		request_failed.emit("هناك طلب اتصال جارٍ؛ أعد المحاولة بعد انتهائه.")
		return false
	if refresh_token.is_empty():
		request_failed.emit("لا توجد جلسة قابلة للتجديد؛ سجّل الدخول مجددًا.")
		return false
	var refresh_generation := _session_generation
	var result := await _send_json(
		HTTPClient.METHOD_POST,
		"/auth/v1/token?grant_type=refresh_token",
		{"refresh_token": refresh_token},
		""
	)
	if refresh_generation != _session_generation:
		var cancelled_data: Dictionary = result.get("data", {}) if result.get("data", {}) is Dictionary else {}
		var cancelled_access := str(cancelled_data.get("access_token", ""))
		if bool(result.get("ok", false)) and not cancelled_access.is_empty():
			await _send_json(HTTPClient.METHOD_POST, "/auth/v1/logout", {}, cancelled_access)
		return false
	if not bool(result.get("ok", false)):
		_clear_session()
		request_failed.emit(str(result.get("message", "انتهت الجلسة؛ سجّل الدخول مجددًا.")))
		return false
	var data: Dictionary = result.get("data", {})
	var user: Dictionary = data.get("user", {})
	var returned_user_id := str(user.get("id", ""))
	var returned_access := str(data.get("access_token", ""))
	var returned_refresh := str(data.get("refresh_token", ""))
	if returned_user_id != TEST_AUTH_USER_ID or returned_access.is_empty() or returned_refresh.is_empty():
		_clear_session()
		request_failed.emit("تعذر التحقق من حساب الاختبار أو أن استجابة تجديد الجلسة غير مكتملة.")
		return false
	access_token = returned_access
	refresh_token = returned_refresh
	user_id = returned_user_id
	auth_changed.emit(true, user_id)
	return true

func fetch_economy_snapshot() -> bool:
	if not is_authenticated():
		request_failed.emit("يجب تسجيل الدخول أولًا.")
		return false
	var request_token := access_token
	var result := await _send_json(
		HTTPClient.METHOD_POST,
		"/rest/v1/rpc/get_my_test_economy_snapshot",
		{},
		request_token
	)
	# قد يضغط المستخدم على تسجيل الخروج أثناء انتظار الشبكة؛ لا تُعد لقطة بعد إنهاء الجلسة.
	if not is_authenticated() or access_token != request_token:
		return false
	if not bool(result.get("ok", false)):
		request_failed.emit(str(result.get("message", "تعذرت قراءة رصيد الاختبار.")))
		return false
	var data: Variant = result.get("data", [])
	if not (data is Array) or data.is_empty() or not (data[0] is Dictionary):
		request_failed.emit("لم يُعثر على حساب اقتصاد تجريبي مرتبط بهذا المستخدم.")
		return false
	economy_snapshot = data[0].duplicate(true)
	economy_snapshot_received.emit(economy_snapshot.duplicate(true))
	return true

func change_test_display_name(new_name: String) -> Dictionary:
	if not is_authenticated():
		return {"ok": false, "error_code": "authentication_required", "message": "يجب تسجيل الدخول بحساب الاختبار أولًا."}
	var normalized_name := new_name.strip_edges()
	if normalized_name.is_empty() or normalized_name.length() > 24:
		return {"ok": false, "error_code": "invalid_display_name", "message": "يجب أن يكون الاسم من 1 إلى 24 حرفًا."}
	var request_token := access_token
	var result := await _send_json(
		HTTPClient.METHOD_POST,
		"/rest/v1/rpc/change_my_test_display_name",
		{"p_new_display_name": normalized_name},
		request_token
	)
	if not is_authenticated() or access_token != request_token:
		return {"ok": false, "error_code": "session_changed", "message": "تغيرت الجلسة أثناء الطلب؛ لم يتم اعتماد النتيجة."}
	if not bool(result.get("ok", false)):
		return {
			"ok": false,
			"error_code": "server_request_failed",
			"message": str(result.get("message", "تعذر تغيير الاسم من الخادم."))
		}
	var data: Variant = result.get("data", [])
	if not (data is Array) or data.is_empty() or not (data[0] is Dictionary):
		return {"ok": false, "error_code": "invalid_server_response", "message": "استجابة تغيير الاسم من الخادم غير مكتملة."}
	var row: Dictionary = data[0]
	var succeeded := bool(row.get("success", false))
	var error_code := str(row.get("error_code", ""))
	var error_messages := {
		"authentication_required": "انتهت جلسة الاختبار؛ سجّل الدخول مجددًا.",
		"invalid_display_name": "الاسم غير صالح؛ استخدم من 1 إلى 24 حرفًا.",
		"test_account_not_linked": "حساب الاختبار غير مرتبط بملف لاعب.",
		"name_unchanged": "هذا هو اسمك الحالي بالفعل.",
		"daily_limit_reached": "استخدمت تغيير الاسم اليوم؛ انتظر حتى الموعد الذي يحدده الخادم.",
		"display_name_taken": "هذا الاسم مستخدم بالفعل؛ اختر اسمًا آخر."
	}
	return {
		"ok": succeeded,
		"error_code": error_code,
		"display_name": str(row.get("current_display_name", "")),
		"next_change_at": str(row.get("next_change_at", "")),
		"message": "تم تغيير الاسم على الخادم." if succeeded else str(error_messages.get(error_code, "لم يوافق الخادم على تغيير الاسم."))
	}

func sign_out() -> void:
	disconnect_test_realtime()
	var token_to_revoke := access_token
	_clear_session()
	# امسح الجلسة محليًا فورًا، ثم نفّذ الإبطال بعد انتهاء طلب HTTP الجاري.
	if token_to_revoke.is_empty():
		return
	if _request_in_flight:
		_pending_logout_token = token_to_revoke
		return
	await _send_json(HTTPClient.METHOD_POST, "/auth/v1/logout", {}, token_to_revoke)

func _flush_pending_logout() -> void:
	if _pending_logout_token.is_empty() or _request_in_flight:
		return
	var token_to_revoke := _pending_logout_token
	_pending_logout_token = ""
	await _send_json(HTTPClient.METHOD_POST, "/auth/v1/logout", {}, token_to_revoke)

func _clear_session() -> void:
	disconnect_test_realtime()
	_session_generation += 1
	access_token = ""
	refresh_token = ""
	user_id = ""
	economy_snapshot.clear()
	auth_changed.emit(false, "")


func fetch_test_display_name() -> Dictionary:
	if not is_authenticated():
		return {"ok": false, "error_code": "authentication_required", "message": "يجب تسجيل الدخول أولًا."}
	var request_token := access_token
	var result := await _send_json(
		HTTPClient.METHOD_POST,
		"/rest/v1/rpc/get_my_test_display_name",
		{},
		request_token
	)
	if not is_authenticated() or access_token != request_token:
		return {"ok": false, "error_code": "session_changed", "message": "تغيرت الجلسة أثناء مزامنة الاسم."}
	if not bool(result.get("ok", false)):
		return {"ok": false, "error_code": "server_request_failed", "message": str(result.get("message", "تعذر جلب اسم الحساب من الخادم."))}
	var data: Variant = result.get("data", [])
	if not (data is Array):
		return {"ok": false, "error_code": "invalid_server_response", "message": "استجابة اسم الحساب من الخادم غير صالحة."}
	if data.is_empty():
		return {"ok": true, "display_name": "", "last_name_change_at": "", "next_change_at": ""}
	if not (data[0] is Dictionary):
		return {"ok": false, "error_code": "invalid_server_response", "message": "بيانات اسم الحساب من الخادم غير مكتملة."}
	var row: Dictionary = data[0]
	var raw_name: Variant = row.get("display_name", null)
	return {
		"ok": true,
		"display_name": str(raw_name).strip_edges() if raw_name is String else "",
		"last_name_change_at": str(row.get("last_name_change_at", "")),
		"next_change_at": str(row.get("next_change_at", ""))
	}


func _call_test_social_rpc(function_name: String, payload: Dictionary = {}) -> Dictionary:
	if not is_authenticated():
		return {"ok": false, "message": "سجّل الدخول بحساب الاختبار أولًا."}
	var allowed_functions := [
		"ensure_my_test_player_account",
		"list_test_friends",
		"list_test_friend_requests",
		"send_test_friend_request",
		"respond_test_friend_request",
		"open_test_direct_conversation",
		"read_test_direct_messages",
		"send_test_direct_message"
	]
	if not allowed_functions.has(function_name):
		return {"ok": false, "message": "طلب اجتماعي غير مسموح."}
	var request_token := access_token
	var result := await _send_json(
		HTTPClient.METHOD_POST,
		"/rest/v1/rpc/" + function_name,
		payload,
		request_token
	)
	if not is_authenticated() or access_token != request_token:
		return {"ok": false, "message": "تغيرت جلسة الاختبار أثناء الطلب."}
	if not bool(result.get("ok", false)):
		var message := str(result.get("message", "تعذر تنفيذ طلب الأصدقاء."))
		request_failed.emit(message)
		return {"ok": false, "message": message}
	return {"ok": true, "data": result.get("data", [])}

func ensure_test_player_account() -> Dictionary:
	return await _call_test_social_rpc("ensure_my_test_player_account")

func list_test_friends() -> Dictionary:
	return await _call_test_social_rpc("list_test_friends")

func list_test_friend_requests() -> Dictionary:
	return await _call_test_social_rpc("list_test_friend_requests")

func send_test_friend_request(player_code: String) -> Dictionary:
	var code := player_code.strip_edges().to_upper()
	if code.is_empty() or code.length() > 32:
		return {"ok": false, "message": "رمز اللاعب غير صالح."}
	return await _call_test_social_rpc("send_test_friend_request", {"p_player_code": code})

func respond_test_friend_request(request_id: String, accept: bool) -> Dictionary:
	if not _is_uuid(request_id):
		return {"ok": false, "message": "طلب الصداقة غير صالح."}
	return await _call_test_social_rpc("respond_test_friend_request", {
		"p_request_id": request_id,
		"p_accept": accept
	})

func open_test_direct_conversation(player_code: String) -> Dictionary:
	var code := player_code.strip_edges().to_upper()
	if code.is_empty() or code.length() > 32:
		return {"ok": false, "message": "رمز اللاعب غير صالح."}
	return await _call_test_social_rpc("open_test_direct_conversation", {"p_player_code": code})

func read_test_direct_messages(conversation_id: String, before_message_id: int = 0, limit: int = 50) -> Dictionary:
	if not _is_uuid(conversation_id):
		return {"ok": false, "message": "معرّف المحادثة غير صالح."}
	return await _call_test_social_rpc("read_test_direct_messages", {
		"p_conversation_id": conversation_id,
		"p_before_message_id": before_message_id if before_message_id > 0 else null,
		"p_limit": clampi(limit, 1, 100)
	})

func send_test_direct_message(conversation_id: String, body: String) -> Dictionary:
	var clean_body := body.strip_edges()
	if not _is_uuid(conversation_id) or clean_body.is_empty() or clean_body.length() > 2000:
		return {"ok": false, "message": "الرسالة أو المحادثة غير صالحة."}
	return await _call_test_social_rpc("send_test_direct_message", {
		"p_conversation_id": conversation_id,
		"p_body": clean_body
	})

func _is_uuid(value: String) -> bool:
	var expression := RegEx.new()
	expression.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$")
	return expression.search(value) != null

func connect_test_direct_realtime(conversation_id: String) -> bool:
	if not is_authenticated() or not _is_uuid(conversation_id):
		return false
	var topic := "chat:direct:" + conversation_id
	if _realtime_topic == topic and is_instance_valid(_realtime_socket):
		return true
	disconnect_test_realtime()
	_realtime_socket = WebSocketPeer.new()
	_realtime_topic = topic
	_realtime_join_ref = ""
	_realtime_join_sent = false
	_heartbeat_elapsed = 0.0
	var url := SUPABASE_URL.replace("https://", "wss://") + "/realtime/v1/websocket?apikey=" + SUPABASE_PUBLISHABLE_KEY.uri_encode() + "&vsn=1.0.0"
	var error := _realtime_socket.connect_to_url(url)
	if error != OK:
		_realtime_socket = null
		_realtime_topic = ""
		request_failed.emit("تعذر بدء اتصال المحادثة المباشر.")
		return false
	return true

func disconnect_test_realtime() -> void:
	if is_instance_valid(_realtime_socket):
		if _realtime_socket.get_ready_state() == WebSocketPeer.STATE_OPEN and _realtime_join_sent:
			_send_realtime_frame("realtime:" + _realtime_topic, "phx_leave", {}, _realtime_join_ref)
		_realtime_socket.close()
	_realtime_socket = null
	_realtime_topic = ""
	_realtime_join_ref = ""
	_realtime_join_sent = false
	_heartbeat_elapsed = 0.0

func _join_realtime_topic() -> void:
	if not is_authenticated() or _realtime_topic.is_empty() or _realtime_join_sent:
		return
	_realtime_join_ref = str(_realtime_ref + 1)
	var payload := {
		"config": {
			"broadcast": {"ack": false, "self": false},
			"presence": {"enabled": false, "key": ""},
			"postgres_changes": [],
			"private": true
		},
		"access_token": access_token
	}
	_send_realtime_frame("realtime:" + _realtime_topic, "phx_join", payload, _realtime_join_ref)
	_realtime_join_sent = true

func _send_realtime_frame(topic: String, event_name: String, payload: Dictionary, join_ref: String) -> void:
	if not is_instance_valid(_realtime_socket) or _realtime_socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_realtime_ref += 1
	var message := {
		"topic": topic,
		"event": event_name,
		"payload": payload,
		"ref": str(_realtime_ref)
	}
	if not join_ref.is_empty():
		message["join_ref"] = join_ref
	_realtime_socket.send_text(JSON.stringify(message))

func _handle_realtime_frame(message: Dictionary) -> void:
	var event_name := str(message.get("event", ""))
	if event_name == "phx_reply":
		var reply: Variant = message.get("payload", {})
		if reply is Dictionary and str(reply.get("status", "")) == "error":
			request_failed.emit("رفض الخادم الاشتراك في قناة المحادثة المباشرة.")
			disconnect_test_realtime()
		return
	if event_name == "phx_error" or event_name == "phx_close":
		request_failed.emit("انقطع اتصال المحادثة المباشر؛ أعد فتح المحادثة للمحاولة.")
		disconnect_test_realtime()
		return
	if event_name != "broadcast":
		return
	var outer_payload: Variant = message.get("payload", {})
	if not outer_payload is Dictionary:
		return
	var event_key := str(outer_payload.get("event", ""))
	var body: Variant = outer_payload.get("payload", {})
	if body is Dictionary and not event_key.is_empty():
		social_event.emit(event_key, body.duplicate(true))

func _send_json(method: int, path: String, payload: Dictionary, bearer: String) -> Dictionary:
	if _request_in_flight:
		return {"ok": false, "message": "يوجد طلب HTTP آخر قيد التنفيذ."}
	var headers := PackedStringArray([
		"apikey: " + SUPABASE_PUBLISHABLE_KEY,
		"Content-Type: application/json"
	])
	if not bearer.is_empty():
		headers.append("Authorization: Bearer " + bearer)
	var body := JSON.stringify(payload) if not payload.is_empty() else "{}"
	_request_in_flight = true
	var request_error := _http.request(SUPABASE_URL + path, headers, method, body)
	if request_error != OK:
		_request_in_flight = false
		return {"ok": false, "message": "تعذر بدء اتصال الشبكة (%s)." % str(request_error)}
	var response: Array = await _http.request_completed
	_request_in_flight = false
	var transport_result := int(response[0])
	var status_code := int(response[1])
	var response_body := (response[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(response_body)
	if transport_result != HTTPRequest.RESULT_SUCCESS:
		await _flush_pending_logout()
		return {"ok": false, "message": "فشل الاتصال بالخادم (%s)." % str(transport_result)}
	if status_code < 200 or status_code >= 300:
		var message := "رفض الخادم الطلب (HTTP %s)." % str(status_code)
		if parsed is Dictionary:
			message = str(parsed.get("msg", parsed.get("message", parsed.get("error_description", message))))
		await _flush_pending_logout()
		return {"ok": false, "message": message}
	await _flush_pending_logout()
	return {"ok": true, "data": parsed}
