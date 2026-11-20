extends Node
## Local PIN gate for an already verified founder entitlement.
## This is a device convenience lock, not proof of founder ownership.

const STORE_PATH := "user://founder_pin.cfg"
const PBKDF2_ITERATIONS := 12000
const MAX_ATTEMPTS := 5
const LOCK_SECONDS := 60

var _salt := PackedByteArray()
var _digest := PackedByteArray()
var _attempts := 0
var _locked_until := 0

func _ready() -> void:
	_load_store()

func is_pin_configured() -> bool:
	return _salt.size() >= 16 and _digest.size() == 32

func is_locked() -> bool:
	return int(Time.get_unix_time_from_system()) < _locked_until

func lock_seconds_remaining() -> int:
	return maxi(0, _locked_until - int(Time.get_unix_time_from_system()))

func setup_pin(pin: String, confirmation: String) -> bool:
	if not _valid_pin(pin) or pin != confirmation or is_pin_configured():
		return false
	_salt = Crypto.new().generate_random_bytes(16)
	if _salt.size() != 16:
		_salt.clear()
		return false
	_digest = _pbkdf2(pin.to_utf8_buffer(), _salt, PBKDF2_ITERATIONS)
	_attempts = 0
	_locked_until = 0
	return _save_store()

func verify_pin(pin: String) -> bool:
	if not is_pin_configured() or is_locked() or not _valid_pin(pin):
		return false
	var candidate := _pbkdf2(pin.to_utf8_buffer(), _salt, PBKDF2_ITERATIONS)
	if candidate.size() == _digest.size() and candidate == _digest:
		_attempts = 0
		_locked_until = 0
		_save_store()
		return true
	_attempts += 1
	if _attempts >= MAX_ATTEMPTS:
		_attempts = 0
		_locked_until = int(Time.get_unix_time_from_system()) + LOCK_SECONDS
	_save_store()
	return false

func _valid_pin(pin: String) -> bool:
	if pin.length() != 6:
		return false
	for i in range(pin.length()):
		if pin.unicode_at(i) < 48 or pin.unicode_at(i) > 57:
			return false
	return true

func _pbkdf2(password: PackedByteArray, salt: PackedByteArray, iterations: int) -> PackedByteArray:
	# PBKDF2-HMAC-SHA256, one 32-byte output block.
	var block := salt.duplicate()
	block.append(0)
	block.append(0)
	block.append(0)
	block.append(1)
	var u := _hmac_sha256(password, block)
	var output := u.duplicate()
	for i in range(1, iterations):
		u = _hmac_sha256(password, u)
		for j in range(output.size()):
			output[j] = output[j] ^ u[j]
	return output

func _hmac_sha256(key: PackedByteArray, data: PackedByteArray) -> PackedByteArray:
	return Crypto.new().hmac_digest(HashingContext.HASH_SHA256, key, data)

func _load_store() -> void:
	var config := ConfigFile.new()
	if config.load(STORE_PATH) != OK:
		return
	var salt_value: Variant = config.get_value("pin", "salt", "")
	var digest_value: Variant = config.get_value("pin", "digest", "")
	if salt_value is String and digest_value is String:
		_salt = Marshalls.base64_to_raw(salt_value)
		_digest = Marshalls.base64_to_raw(digest_value)
	_attempts = clampi(int(config.get_value("lockout", "attempts", 0)), 0, MAX_ATTEMPTS - 1)
	_locked_until = maxi(0, int(config.get_value("lockout", "locked_until", 0)))

func _save_store() -> bool:
	var config := ConfigFile.new()
	config.set_value("pin", "salt", Marshalls.raw_to_base64(_salt))
	config.set_value("pin", "digest", Marshalls.raw_to_base64(_digest))
	config.set_value("lockout", "attempts", _attempts)
	config.set_value("lockout", "locked_until", _locked_until)
	return config.save(STORE_PATH) == OK
