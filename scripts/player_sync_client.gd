extends Node
## Durable client outbox for non-authoritative player sync observations.
## Never send balances, purchases, ownership, rewards, or founder/admin claims.

signal sync_finished(success: bool, accepted: int, duplicates: int, message: String)
signal outbox_changed(pending_count: int)
signal preference_snapshot_received(revision: int, settings: Dictionary)
signal preference_snapshot_finished(success: bool, message: String)
signal progress_observations_received(observations: Array, trust_label: String)
signal progress_observations_finished(success: bool, message: String)
signal verified_reward_claim_finished(success: bool, result: Dictionary, message: String)

const OUTBOX_PATH := "user://player_sync_outbox.cfg"
const PROGRESS_REVIEW_PATH := "user://player_sync_progress_review.cfg"
const SYNC_ENABLED_SETTING := "player_sync/enabled"
const REWARDS_ENABLED_SETTING := "game_rewards/enabled"
const MAX_PENDING_EVENTS := 500
const MAX_BATCH_SIZE := 50
const ALLOWED_EVENT_TYPES := [
	"setting_changed",
	"mission_progress_observed",
	"achievement_progress_observed",
	"activity_progress_observed"
]

var _http: HTTPRequest
var _snapshot_http: HTTPRequest
var _progress_http: HTTPRequest
var _progress_request_active := false
var _progress_request_token := ""
var _reward_claim_http: HTTPRequest
var _reward_claim_active := false
var _reward_claim_token := ""
var _snapshot_action := ""
var _snapshot_revision := 0
var _snapshot_request_active := false
var _access_token := ""
var _session_user_id := ""
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
	_snapshot_http = HTTPRequest.new()
	_snapshot_http.name = "PlayerPreferenceSnapshotHTTPRequest"
	_snapshot_http.timeout = 25.0
	add_child(_snapshot_http)
	_snapshot_http.request_completed.connect(_on_snapshot_request_completed)
	_progress_http = HTTPRequest.new()
	_progress_http.name = "PlayerProgressRecoveryHTTPRequest"
	_progress_http.timeout = 25.0
	add_child(_progress_http)
	_progress_http.request_completed.connect(_on_progress_recovery_completed)
	_reward_claim_http = HTTPRequest.new()
	_reward_claim_http.name = "VerifiedRewardClaimHTTPRequest"
	_reward_claim_http.timeout = 25.0
	add_child(_reward_claim_http)
	_reward_claim_http.request_completed.connect(_on_verified_reward_claim_completed)
	_retry_timer = Timer.new()
	_retry_timer.one_shot = true
	_retry_timer.timeout.connect(flush_pending)
	add_child(_retry_timer)
	_load_outbox()


func set_session_access_token(access_token: String, user_id: String) -> void:
	_access_token = access_token.strip_edges()
	_session_user_id = user_id.strip_edges()
	if _access_token.is_empty() or _session_user_id.is_empty():
		clear_session_access_token()
		push_warning("Player sync session requires both an access token and an authenticated account ID.")
		return
	if bool(ProjectSettings.get_setting(SYNC_ENABLED_SETTING, false)):
		call_deferred("fetch_preference_snapshot")
		call_deferred("fetch_progress_observations")
		call_deferred("flush_pending")


func clear_session_access_token() -> void:
	_access_token = ""
	_session_user_id = ""
	_snapshot_action = ""
	_snapshot_request_active = false
	_progress_request_active = false
	_progress_request_token = ""
	_reward_claim_active = false
	_reward_claim_token = ""
	if is_instance_valid(_retry_timer):
		_retry_timer.stop()



func get_preference_snapshot_revision() -> int:
	return _snapshot_revision


func fetch_preference_snapshot() -> void:
	if not bool(ProjectSettings.get_setting(SYNC_ENABLED_SETTING, false)):
		return
	if _access_token.is_empty() or _snapshot_request_active:
		return
	_start_snapshot_request("get_player_preference_snapshot", {}, "fetch")


func save_preference_snapshot(settings: Dictionary) -> void:
	if not bool(ProjectSettings.get_setting(SYNC_ENABLED_SETTING, false)):
		preference_snapshot_finished.emit(false, "مزامنة الحساب معطلة حاليًا في إعدادات اللعبة.")
		return
	if _access_token.is_empty() or _snapshot_request_active:
		preference_snapshot_finished.emit(false, "سجّل الدخول أولًا أو انتظر انتهاء طلب الإعدادات.")
		return
	if not _is_valid_preference_snapshot(settings):
		preference_snapshot_finished.emit(false, "تحتوي الإعدادات على قيمة غير مسموحة.")
		return
	_start_snapshot_request("save_player_preference_snapshot", {
		"p_expected_revision": _snapshot_revision,
		"p_settings": settings.duplicate(true)
	}, "save")


func _is_valid_preference_snapshot(settings: Dictionary) -> bool:
	if settings.size() > 3:
		return false
	if settings.has("locale") and (typeof(settings.locale) != TYPE_STRING or str(settings.locale) not in ["auto", "ar", "en"]):
		return false
	if settings.has("volume") and (typeof(settings.volume) != TYPE_INT or int(settings.volume) < 0 or int(settings.volume) > 100):
		return false
	if settings.has("quality") and (typeof(settings.quality) != TYPE_INT or int(settings.quality) not in [0, 1, 2]):
		return false
	return true


func _start_snapshot_request(rpc_name: String, payload: Dictionary, action: String) -> void:
	var base_url := str(ProjectSettings.get_setting("founder/auth/api_base_url", "")).strip_edges().trim_suffix("/")
	var publishable_key := str(ProjectSettings.get_setting("founder/auth/publishable_key", "")).strip_edges()
	if not base_url.begins_with("https://") or publishable_key.is_empty():
		preference_snapshot_finished.emit(false, "إعدادات مزامنة الحساب غير مكتملة.")
		return
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"apikey: " + publishable_key,
		"Authorization: Bearer " + _access_token
	])
	var request_body := JSON.stringify(payload) if action == "save" else "{}"
	var error := _snapshot_http.request(
		base_url + "/rest/v1/rpc/" + rpc_name,
		headers,
		HTTPClient.METHOD_POST,
		request_body
	)
	if error != OK:
		preference_snapshot_finished.emit(false, "تعذر بدء مزامنة إعدادات الحساب.")
		return
	_snapshot_action = action
	_snapshot_request_active = true


func _on_snapshot_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var action := _snapshot_action
	_snapshot_action = ""
	_snapshot_request_active = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		preference_snapshot_finished.emit(false, "تعذر جلب أو حفظ إعدادات الحساب. بقيت الإعدادات المحلية دون تغيير.")
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if parsed is Array and parsed.size() == 1:
		parsed = parsed[0]
	if not (parsed is Dictionary):
		preference_snapshot_finished.emit(false, "استجابة إعدادات الحساب غير صالحة.")
		return
	if action == "fetch":
		var revision := int(parsed.get("revision", -1))
		var settings_value: Variant = parsed.get("settings", {})
		if revision < 0 or not (settings_value is Dictionary) or not _is_valid_preference_snapshot(settings_value):
			preference_snapshot_finished.emit(false, "بيانات إعدادات الحساب غير صالحة؛ لم تُطبق.")
			return
		_snapshot_revision = revision
		preference_snapshot_received.emit(revision, settings_value.duplicate(true))
		preference_snapshot_finished.emit(true, "تم جلب إعدادات الحساب.")
		return
	if action == "save":
		if bool(parsed.get("conflict", false)):
			_snapshot_revision = int(parsed.get("revision", _snapshot_revision))
			preference_snapshot_finished.emit(false, "توجد إعدادات أحدث على جهاز آخر؛ جارٍ جلب النسخة الأحدث.")
			call_deferred("fetch_preference_snapshot")
			return
		if not bool(parsed.get("saved", false)):
			preference_snapshot_finished.emit(false, "لم يؤكد الخادم حفظ إعدادات الحساب.")
			return
		_snapshot_revision = int(parsed.get("revision", _snapshot_revision))
		preference_snapshot_finished.emit(true, "تمت مزامنة إعدادات الحساب.")
		return
	preference_snapshot_finished.emit(false, "حالة مزامنة غير معروفة.")



func fetch_progress_observations() -> void:
	if not bool(ProjectSettings.get_setting(SYNC_ENABLED_SETTING, false)):
		return
	if _access_token.is_empty() or _progress_request_active:
		return
	var base_url := str(ProjectSettings.get_setting("founder/auth/api_base_url", "")).strip_edges().trim_suffix("/")
	var publishable_key := str(ProjectSettings.get_setting("founder/auth/publishable_key", "")).strip_edges()
	if not base_url.begins_with("https://") or publishable_key.is_empty():
		progress_observations_finished.emit(false, "إعدادات استعادة التقدم غير مكتملة.")
		return
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"apikey: " + publishable_key,
		"Authorization: Bearer " + _access_token
	])
	var error := _progress_http.request(
		base_url + "/rest/v1/rpc/get_player_progress_observations",
		headers,
		HTTPClient.METHOD_POST,
		"{}"
	)
	if error != OK:
		progress_observations_finished.emit(false, "تعذر بدء استعادة سجل التقدم.")
		return
	_progress_request_active = true
	_progress_request_token = _access_token


func _on_progress_recovery_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_progress_request_active = false
	var request_token := _progress_request_token
	_progress_request_token = ""
	if request_token.is_empty() or request_token != _access_token:
		if not _access_token.is_empty():
			call_deferred("fetch_progress_observations")
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		progress_observations_finished.emit(false, "تعذر جلب سجل التقدم؛ لم تتغير بيانات اللعب.")
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if parsed is Array and parsed.size() == 1:
		parsed = parsed[0]
	if not (parsed is Dictionary):
		progress_observations_finished.emit(false, "استجابة سجل التقدم غير صالحة.")
		return
	if bool(parsed.get("authoritative", true)) or str(parsed.get("trust", "")) != "unverified_client_observations":
		progress_observations_finished.emit(false, "رفضت اللعبة استجابة لا تحمل تصنيف الثقة المطلوب.")
		return
	var observations_value: Variant = parsed.get("observations", [])
	if not (observations_value is Array) or observations_value.size() > 500:
		progress_observations_finished.emit(false, "قائمة التقدم المستعادة غير صالحة.")
		return
	var clean_observations: Array[Dictionary] = []
	for item in observations_value:
		if not (item is Dictionary):
			progress_observations_finished.emit(false, "تحتوي قائمة التقدم على سجل غير صالح.")
			return
		var key := str(item.get("progress_key", ""))
		var value: Variant = item.get("progress_value", -1)
		if key.length() < 1 or key.length() > 80 or typeof(value) != TYPE_INT or int(value) < 0 or int(value) > 1000000:
			progress_observations_finished.emit(false, "تحتوي قائمة التقدم على قيمة خارج الحدود.")
			return
		if not (key.begins_with("mission.") or key.begins_with("achievement.") or key.begins_with("activity.")):
			progress_observations_finished.emit(false, "تحتوي قائمة التقدم على نوع غير مسموح.")
			return
		clean_observations.append({
			"progress_key": key,
			"progress_value": int(value),
			"updated_at": str(item.get("updated_at", ""))
		})
	var config := ConfigFile.new()
	var load_error := config.load(PROGRESS_REVIEW_PATH)
	if load_error != OK and FileAccess.file_exists(PROGRESS_REVIEW_PATH):
		progress_observations_finished.emit(false, "تعذر قراءة ملف مراجعة التقدم المحلي؛ لم تتم الكتابة فوقه.")
		return
	config.set_value("recovery", "trust", "unverified_client_observations")
	config.set_value("recovery", "authoritative", false)
	config.set_value("recovery", "observations", clean_observations)
	config.set_value("recovery", "fetched_at", Time.get_datetime_string_from_system(true))
	if config.save(PROGRESS_REVIEW_PATH) != OK:
		progress_observations_finished.emit(false, "تعذر حفظ سجل التقدم المستعاد محليًا.")
		return
	progress_observations_received.emit(clean_observations.duplicate(true), "غير معتمد — يحتاج تحققًا خادميًا")
	progress_observations_finished.emit(true, "تم حفظ سجل التقدم للمراجعة فقط؛ لم يُعتمد داخل اللعب ولم تُمنح مكافآت.")


func claim_verified_activity_reward(proof_id: String) -> void:
	if not bool(ProjectSettings.get_setting(REWARDS_ENABLED_SETTING, false)):
		verified_reward_claim_finished.emit(false, {}, "اعتماد المكافآت Online مغلق حتى اكتمال النشر والاختبار.")
		return
	if _access_token.is_empty() or _reward_claim_active:
		verified_reward_claim_finished.emit(false, {}, "سجّل الدخول أولًا أو انتظر انتهاء طلب المكافأة الحالي.")
		return
	var uuid_pattern := RegEx.new()
	uuid_pattern.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$")
	if uuid_pattern.search(proof_id.strip_edges()) == null:
		verified_reward_claim_finished.emit(false, {}, "معرّف إثبات المكافأة غير صالح.")
		return
	var base_url := str(ProjectSettings.get_setting("founder/auth/api_base_url", "")).strip_edges().trim_suffix("/")
	var publishable_key := str(ProjectSettings.get_setting("founder/auth/publishable_key", "")).strip_edges()
	if not base_url.begins_with("https://") or publishable_key.is_empty():
		verified_reward_claim_finished.emit(false, {}, "إعدادات الحساب غير مكتملة.")
		return
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"apikey: " + publishable_key,
		"Authorization: Bearer " + _access_token
	])
	var error := _reward_claim_http.request(
		base_url + "/rest/v1/rpc/claim_verified_activity_reward",
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify({"p_proof_id": proof_id.strip_edges().to_lower()})
	)
	if error != OK:
		verified_reward_claim_finished.emit(false, {}, "تعذر بدء طلب اعتماد المكافأة.")
		return
	_reward_claim_active = true
	_reward_claim_token = _access_token


func _on_verified_reward_claim_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_reward_claim_active = false
	var request_token := _reward_claim_token
	_reward_claim_token = ""
	if request_token.is_empty() or request_token != _access_token:
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		verified_reward_claim_finished.emit(false, {}, "لم يعتمد الخادم المكافأة؛ لم تُجرَ أي إضافة محلية.")
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if parsed is Array and parsed.size() == 1:
		parsed = parsed[0]
	if not (parsed is Dictionary):
		verified_reward_claim_finished.emit(false, {}, "استجابة اعتماد المكافأة غير صالحة.")
		return
	var duplicate := bool(parsed.get("duplicate", false))
	var claimed := bool(parsed.get("claimed", false))
	if not claimed and not duplicate:
		verified_reward_claim_finished.emit(false, parsed.duplicate(true), "لم يؤكد الخادم اعتماد المكافأة.")
		return
	verified_reward_claim_finished.emit(true, parsed.duplicate(true), "المكافأة معتمدة خادميًا." if claimed else "هذه المكافأة سبق اعتمادها؛ لم يتكرر الصرف.")


func get_unverified_progress_observations() -> Array[Dictionary]:
	var config := ConfigFile.new()
	if config.load(PROGRESS_REVIEW_PATH) != OK:
		return []
	var stored: Variant = config.get_value("recovery", "observations", [])
	if not (stored is Array):
		return []
	var result: Array[Dictionary] = []
	for item in stored:
		if item is Dictionary:
			result.append(item.duplicate(true))
	return result


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
	# Bind every event to the authenticated account active when it was created.
	# Events created without an account remain local-only and are never claimed by a later login.
	var event := {
		"event_id": event_id,
		"owner_user_id": _session_user_id,
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
			"volume":
				return typeof(value) == TYPE_INT and int(value) >= 0 and int(value) <= 100
			"quality":
				return typeof(value) == TYPE_INT and int(value) in [0, 1, 2]
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
	if _request_active or _access_token.is_empty() or _session_user_id.is_empty() or _events.is_empty():
		return

	var base_url := str(ProjectSettings.get_setting("founder/auth/api_base_url", "")).strip_edges().trim_suffix("/")
	var publishable_key := str(ProjectSettings.get_setting("founder/auth/publishable_key", "")).strip_edges()
	if not base_url.begins_with("https://") or publishable_key.is_empty():
		sync_finished.emit(false, 0, 0, "إعدادات مزامنة الحساب غير مكتملة.")
		return

	var batch: Array[Dictionary] = []
	_pending_event_ids.clear()
	for stored_event in _events:
		if str(stored_event.get("owner_user_id", "")) != _session_user_id:
			continue
		var event := {
			"event_id": str(stored_event.get("event_id", "")),
			"event_type": str(stored_event.get("event_type", "")),
			"payload": stored_event.get("payload", {}).duplicate(true) if stored_event.get("payload", {}) is Dictionary else {}
		}
		batch.append(event)
		_pending_event_ids.append(str(event.get("event_id", "")))
		if batch.size() >= MAX_BATCH_SIZE:
			break
	if batch.is_empty():
		return

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


func _on_request_completed(result: int, response_code: int, response_headers: PackedStringArray, body: PackedByteArray) -> void:
	_request_active = false
	if result != HTTPRequest.RESULT_SUCCESS:
		_pending_event_ids.clear()
		sync_finished.emit(false, 0, 0, "تعذرت المزامنة الآن. ستبقى الأحداث في قائمة الانتظار.")
		_schedule_retry()
		return
	if response_code == 429:
		_pending_event_ids.clear()
		_retry_delay_seconds = maxf(_retry_delay_seconds, _get_retry_after_seconds(response_headers))
		sync_finished.emit(false, 0, 0, "الخادم طلب تهدئة طلبات المزامنة؛ ستبقى الأحداث محفوظة.")
		_schedule_retry()
		return
	if response_code < 200 or response_code >= 300:
		_pending_event_ids.clear()
		sync_finished.emit(false, 0, 0, "رفض الخادم الدفعة أو تعذر قبولها. ستبقى الأحداث محفوظة للمراجعة.")
		if response_code >= 500:
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
			var restored: Dictionary = item.duplicate(true)
			# Legacy events have no owner and deliberately remain local-only.
			# Never attach them to whichever account happens to log in next.
			if not restored.has("owner_user_id"):
				restored["owner_user_id"] = ""
			_events.append(restored)
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


func _get_retry_after_seconds(response_headers: PackedStringArray) -> float:
	for header in response_headers:
		var parts := header.split(":", true, 1)
		if parts.size() == 2 and parts[0].strip_edges().to_lower() == "retry-after":
			var parsed := parts[1].strip_edges().to_float()
			if parsed > 0.0:
				return clampf(parsed, 5.0, MAX_RETRY_DELAY_SECONDS)
	return 60.0
