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

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 20.0
	add_child(_http)

func is_authenticated() -> bool:
	return not access_token.is_empty() and not user_id.is_empty()

func sign_in_with_password(email: String, password: String) -> bool:
	# لا تحتفظ بجلسة سابقة إذا فشلت محاولة تسجيل الدخول الجديدة.
	if _request_in_flight:
		request_failed.emit("هناك طلب اتصال جارٍ؛ انتظر حتى ينتهي.")
		return false
	_clear_session()
	if email.strip_edges().is_empty() or password.is_empty():
		request_failed.emit("أدخل البريد وكلمة المرور.")
		return false
	var result := await _send_json(
		HTTPClient.METHOD_POST,
		"/auth/v1/token?grant_type=password",
		{"email": email.strip_edges(), "password": password},
		""
	)
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
	auth_changed.emit(true, user_id)
	await fetch_economy_snapshot()
	return true

func refresh_session() -> bool:
	if refresh_token.is_empty():
		request_failed.emit("لا توجد جلسة قابلة للتجديد؛ سجّل الدخول مجددًا.")
		return false
	var result := await _send_json(
		HTTPClient.METHOD_POST,
		"/auth/v1/token?grant_type=refresh_token",
		{"refresh_token": refresh_token},
		""
	)
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
	var result := await _send_json(
		HTTPClient.METHOD_POST,
		"/rest/v1/rpc/get_my_test_economy_snapshot",
		{},
		access_token
	)
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

func sign_out() -> void:
	if not access_token.is_empty():
		await _send_json(HTTPClient.METHOD_POST, "/auth/v1/logout", {}, access_token)
	_clear_session()

func _clear_session() -> void:
	access_token = ""
	refresh_token = ""
	user_id = ""
	economy_snapshot.clear()
	auth_changed.emit(false, "")

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
		return {"ok": false, "message": "فشل الاتصال بالخادم (%s)." % str(transport_result)}
	if status_code < 200 or status_code >= 300:
		var message := "رفض الخادم الطلب (HTTP %s)." % str(status_code)
		if parsed is Dictionary:
			message = str(parsed.get("msg", parsed.get("message", parsed.get("error_description", message))))
		return {"ok": false, "message": message}
	return {"ok": true, "data": parsed}
