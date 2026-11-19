extends Node
## Durable client outbox for non-authoritative player sync observations.
## Never send balances, purchases, ownership, rewards, or founder/admin claims.

signal sync_finished(success: bool, accepted: int, duplicates: int, message: String)
signal outbox_changed(pending_count: int)

const OUTBOX_PATH := "user://player_sync_outbox.cfg"
const SYNC_ENABLED_SETTING := "player_sync/enabled"
const MAX_PENDING_EVENTS := 500
const MAX_BATCH_SIZE := 50
const ALLOWED_EVENT_TYPES := [
	"setting_changed",
	"mission_progress_observed",
	"achievement_progress_observed",
	"activity_progress_observed"
]

var _http: HTTPRequest
var _access_token := ""
var _events: Array[Dictionary] = []
var _pending_event_ids: Array[String] = []
var _request_active := false
var _retry_timer: Timer
var _retry_delay_seconds := 5.0
const MAX_RETRY_DELAY_SECONDS := 300.0


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.name = "PlayerSyncHTTPRequest"
	_http.timeout = 25.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	_retry_timer = Timer.new()
	_retry_timer.one_shot = true
	_retry_timer.timeout.connect(flush_pending)
	add_child(_retry_timer)
	_load_outbox()


func set_session_access_token(access_token: String) -> void:
	_access_token = access_token.strip_edges()
	if not _access_token.is_empty():
		call_deferred("flush_pending")


func clear_session_access_token() -> void:
	_access_token = ""
	if is_instance_valid(_retry_timer):
		_retry_timer.stop()


func get_pending_count() -> int:
	return _events.size()


func enqueue_event(event_type: String, payload: Dictionary) -> bool:
	if not _is_valid_event_payload(event_type, payload):
		return false
	if _events.size() >= MAX_PENDING_EVENTS:
		push_warning("Player sync outbox is full; the event was not discarded or overwritten.")
		return false

	var event_id := _create_event_uuid()
	if event_id.is_empty():
		return false
	var event := {
		"event_id": event_id,
		"event_type": event_type,
		"payload": payload.duplicate(true)
	}
	_events.append(event)
	if not _save_outbox():
		_events.pop_back()
		return false
	outbox_changed.emit(_events.size())
	if not _access_token.is_empty():
		call_deferred("flush_pending")
	return true


func _is_valid_event_payload(event_type: String, payload: Dictionary) -> bool:
	if not ALLOWED_EVENT_TYPES.has(event_type) or JSON.stringify(payload).to_utf8_buffer().size() > 8192:
		return false
	if event_type == "setting_changed":
		if payload.size() != 2 or not payload.has("key") or not payload.has("value"):
			return false
		var key := str(payload.get("key", ""))
		var value: Variant = payload.get("value")
		match key:
			"locale":
				return typeof(value) == TYPE_STRING and str(value).length() <= 16
			"camera_sensitivity":
				return typeof(value) in [TYPE_FLOAT, TYPE_INT] and float(value) >= 0.1 and float(value) <= 3.0
			"music_enabled", "sfx_enabled":
				return typeof(value) == TYPE_BOOL
			"control_layout":
				return typeof(value) == TYPE_STRING and str(value) in ["classic", "left_handed"]
			_:
				return false
	if payload.size() != 2 or not payload.has("progress_key") or not payload.has("progress_value"):
		return false
	var progress_key: Variant = payload.get("progress_key")
	var progress_value: Variant = payload.get("progress_value")
	return typeof(progress_key) == TYPE_STRING and str(progress_key).length() >= 1 and str(progress_key).length() <= 80 and typeof(progress_value) == TYPE_INT and int(progress_value) >= 0 and int(progress_value) <= 1000000


func enqueue_setting_change(setting_key: String, value: Variant) -> bool:
	return enqueue_event("setting_changed", {"key": setting_key, "value": value})


func enqueue_progress_observation(event_type: String, progress_key: String, progress_value: int) -> bool:
	return enqueue_event(event_type, {
		"progress_key": progress_key,
		"progress_value": progress_value
	})


func flush_pending() -> void:
	if not bool(ProjectSettings.get_setting(SYNC_ENABLED_SETTING, false)):
		return
	if _request_active or _access_token.is_empty() or _events.is_empty():
		return

	var base_url := str(ProjectSettings.get_setting("founder/auth/api_base_url", "")).strip_edges().trim_suffix("/")
	var publishable_key := str(ProjectSettings.get_setting("founder/auth/publishable_key", "")).strip_edges()
	if not base_url.begins_with("https://") or publishable_key.is_empty():
		sync_finished.emit(false, 0, 0, "إعدادات مزامنة الحساب غير مكتملة.")
		return

	var batch: Array[Dictionary] = []
	_pending_event_ids.clear()
	for index in range(mini(MAX_BATCH_SIZE, _events.size())):
		var event: Dictionary = _events[index].duplicate(true)
		batch.append(event)
		_pending_event_ids.append(str(event.get("event_id", "")))

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"apikey: " + publishable_key,
		"Authorization: Bearer " + _access_token
	])
	var payload := JSON.stringify({"events": batch})
	var error := _http.request(
		base_url + "/functions/v1/player-sync",
		headers,
		HTTPClient.METHOD_POST,
		payload
	)
	if error != OK:
		_pending_event_ids.clear()
		sync_finished.emit(false, 0, 0, "تعذر بدء مزامنة التقدم. ستبقى الأحداث محفوظة على الجهاز.")
		_schedule_retry()
		return
	_request_active = true


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_request_active = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_pending_event_ids.clear()
		sync_finished.emit(false, 0, 0, "تعذرت المزامنة الآن. ستبقى الأحداث في قائمة الانتظار.")
		_schedule_retry()
		return

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary) or not bool(parsed.get("ok", false)):
		_pending_event_ids.clear()
		sync_finished.emit(false, 0, 0, "استجابة المزامنة غير صالحة. لم تُحذف البيانات المحلية.")
		_schedule_retry()
		return

	var result_value: Variant = parsed.get("result", {})
	if not (result_value is Dictionary):
		_pending_event_ids.clear()
		sync_finished.emit(false, 0, 0, "تعذر تأكيد نتيجة المزامنة. ستبقى الأحداث محفوظة.")
		_schedule_retry()
		return

	var accepted := int(result_value.get("accepted", 0))
	var duplicates := int(result_value.get("duplicates", 0))
	if accepted < 0 or duplicates < 0 or accepted + duplicates != _pending_event_ids.size():
		_pending_event_ids.clear()
		sync_finished.emit(false, 0, 0, "لم يكتمل تأكيد كل أحداث الدفعة؛ لم تُحذف البيانات المحلية.")
		_schedule_retry()
		return

	_remove_confirmed_events()
	_pending_event_ids.clear()
	_retry_delay_seconds = 5.0
	if is_instance_valid(_retry_timer):
		_retry_timer.stop()
	sync_finished.emit(true, accepted, duplicates, "تم تسجيل أحداث المزامنة بأمان. لا يعني ذلك اعتماد مكافآت أو أرصدة.")
	outbox_changed.emit(_events.size())

	# Continue in bounded batches. Each accepted batch is removed only after server confirmation.
	if not _events.is_empty() and not _access_token.is_empty():
		call_deferred("flush_pending")


func _remove_confirmed_events() -> void:
	var confirmed: Dictionary = {}
	for event_id in _pending_event_ids:
		confirmed[event_id] = true
	var remaining: Array[Dictionary] = []
	for event in _events:
		if not confirmed.has(str(event.get("event_id", ""))):
			remaining.append(event)
	_events = remaining
	# If saving fails, the previous queue is safe to resend because event IDs are idempotent.
	if not _save_outbox():
		push_warning("Could not persist the reduced sync outbox; already accepted events may be retried safely.")


func _create_event_uuid() -> String:
	var crypto := Crypto.new()
	var bytes := crypto.generate_random_bytes(16)
	if bytes.size() != 16:
		return ""
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8),
		hex.substr(8, 4),
		hex.substr(12, 4),
		hex.substr(16, 4),
		hex.substr(20, 12)
	]


func _load_outbox() -> void:
	var config := ConfigFile.new()
	if config.load(OUTBOX_PATH) != OK:
		return
	var stored: Variant = config.get_value("outbox", "events", [])
	if not (stored is Array):
		return
	# Never truncate a previously persisted queue on load. The enqueue cap only
	# prevents adding more events; already stored events remain available to retry.
	for item in stored:
		if item is Dictionary:
			_events.append(item.duplicate(true))
	outbox_changed.emit(_events.size())


func _save_outbox() -> bool:
	var config := ConfigFile.new()
	config.set_value("outbox", "events", _events)
	return config.save(OUTBOX_PATH) == OK


func _schedule_retry() -> void:
	if not bool(ProjectSettings.get_setting(SYNC_ENABLED_SETTING, false)):
		return
	if _access_token.is_empty() or _events.is_empty() or not is_instance_valid(_retry_timer):
		return
	_retry_timer.start(_retry_delay_seconds)
	_retry_delay_seconds = minf(_retry_delay_seconds * 2.0, MAX_RETRY_DELAY_SECONDS)
