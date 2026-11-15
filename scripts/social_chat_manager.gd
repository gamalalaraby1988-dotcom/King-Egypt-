extends Node
## Authenticated REST RPC bridge for test social features.
signal operation_completed(action: String, data: Variant)
signal operation_failed(action: String, message: String)

const SUPABASE_URL := "https://unwrlvyjrtdwobcktetd.supabase.co"
const SUPABASE_PUBLISHABLE_KEY := "sb_publishable_BrWeMmhyOpL73Uca40Ug0Q_8Zgw55si"

var _http: HTTPRequest
var _pending_action := ""

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
