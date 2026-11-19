extends Node
## هوية المؤسس الأساسية. لا تُفعّل إلا بتذكرة موقعة من خادم موثوق.
## بيانات الاعتماد الموقعة قابلة للاستخدام دون اتصال بعد التحقق، ولا تمنح صلاحيات إدارة خادمية.

const FOUNDER_ID := "king_of_egypt_city:founder:primary"
const FOUNDER_DISPLAY_NAME := "Gamal Alaraby"
const FOUNDER_TITLE := "FOUNDER"
const CACHE_PATH := "user://founder_entitlement.cfg"
const PUBLIC_KEY_SETTING := "founder/security/public_key_pem"
const MAX_CLOCK_SKEW_SECONDS := 300

var is_founder := false
var founder_subject_id := ""
var entitlement_expires_at := 0
var verification_status := "unverified"

func _ready() -> void:
	_load_cached_entitlement()

func get_founder_display_name() -> String:
	return FOUNDER_DISPLAY_NAME

func get_founder_title() -> String:
	return FOUNDER_TITLE

func get_founder_profile() -> Dictionary:
	return {
		"founder_id": FOUNDER_ID,
		"display_name": FOUNDER_DISPLAY_NAME,
		"title": FOUNDER_TITLE,
		"subject_id": founder_subject_id,
		"verified": is_founder
	}

## يستدعيها موصل المصادقة مستقبلًا بعد استلام payload وتوقيعه من الخادم.
## يجب أن تكون payload هي النص الأصلي الذي وقّعه الخادم دون إعادة تنسيقه.
func accept_signed_entitlement(payload: String, signature_base64: String) -> bool:
	if not _verify_entitlement(payload, signature_base64):
		_clear_active_identity()
		verification_status = "signature_rejected"
		return false
	var config := ConfigFile.new()
	config.set_value("entitlement", "payload", payload)
	config.set_value("entitlement", "signature", signature_base64)
	if config.save(CACHE_PATH) != OK:
		_clear_active_identity()
		verification_status = "cache_write_failed"
		return false
	return _activate_verified_payload(payload)

func _load_cached_entitlement() -> void:
	var config := ConfigFile.new()
	var error := config.load(CACHE_PATH)
	if error != OK:
		_clear_active_identity()
		verification_status = "no_cached_entitlement"
		return
	var payload_value: Variant = config.get_value("entitlement", "payload", "")
	var signature_value: Variant = config.get_value("entitlement", "signature", "")
	if not (payload_value is String and signature_value is String):
		_clear_active_identity()
		verification_status = "invalid_cache"
		return
	if not _verify_entitlement(payload_value, signature_value):
		_clear_active_identity()
		verification_status = "cached_entitlement_rejected"
		return
	_activate_verified_payload(payload_value)

func _verify_entitlement(payload: String, signature_base64: String) -> bool:
	var public_key_pem := str(ProjectSettings.get_setting(PUBLIC_KEY_SETTING, "")).strip_edges()
	if public_key_pem.is_empty() or payload.is_empty() or signature_base64.is_empty():
		return false

	var public_key := CryptoKey.new()
	if public_key.load_from_string(public_key_pem, true) != OK:
		push_warning("تعذر تحميل المفتاح العام للتحقق من هوية المؤسس.")
		return false

	var signature := Marshalls.base64_to_raw(signature_base64)
	if signature.is_empty():
		return false
	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK:
		return false
	if hashing.update(payload.to_utf8_buffer()) != OK:
		return false
	var digest := hashing.finish()
	var crypto := Crypto.new()
	if not crypto.verify(HashingContext.HASH_SHA256, digest, signature, public_key):
		return false

	var parsed := JSON.new()
	if parsed.parse(payload) != OK or not (parsed.data is Dictionary):
		return false
	var claims: Dictionary = parsed.data
	if str(claims.get("founder_id", "")) != FOUNDER_ID:
		return false
	if str(claims.get("subject_id", "")).strip_edges().is_empty():
		return false
	if claims.get("offline_allowed", false) != true:
		return false
	var issued_at: Variant = claims.get("issued_at", 0)
	var expires_at: Variant = claims.get("expires_at", 0)
	if not (issued_at is int or issued_at is float) or not (expires_at is int or expires_at is float):
		return false
	var now := int(Time.get_unix_time_from_system())
	if int(issued_at) > now + MAX_CLOCK_SKEW_SECONDS or int(expires_at) <= now:
		return false
	return true

func _activate_verified_payload(payload: String) -> bool:
	var parsed := JSON.new()
	if parsed.parse(payload) != OK or not (parsed.data is Dictionary):
		_clear_active_identity()
		return false
	var claims: Dictionary = parsed.data
	founder_subject_id = str(claims.get("subject_id", ""))
	entitlement_expires_at = int(claims.get("expires_at", 0))
	is_founder = not founder_subject_id.is_empty() and entitlement_expires_at > int(Time.get_unix_time_from_system())
	verification_status = "verified_offline" if is_founder else "expired"
	return is_founder

func _clear_active_identity() -> void:
	is_founder = false
	founder_subject_id = ""
	entitlement_expires_at = 0

## مسح تذكرة الجهاز عند تسجيل الخروج من حساب المؤسس.
func clear_entitlement() -> void:
	_clear_active_identity()
	var absolute_path := ProjectSettings.globalize_path(CACHE_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
	verification_status = "signed_out"
