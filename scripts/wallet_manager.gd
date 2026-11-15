extends Node
## خدمة محفظة محلية موحدة. الخادم الموثوق مطلوب لحماية اقتصاد اللعب الجماعي.

const DEFAULT_PROFILE_PATH := "user://kings_city_profile.cfg"
const DEFAULT_TEMP_PATH := "user://kings_city_profile.wallet.tmp"
const DEFAULT_BACKUP_PATH := "user://kings_city_profile.pre_wallet_backup.cfg"
var profile_path := DEFAULT_PROFILE_PATH
var temp_path := DEFAULT_TEMP_PATH
var backup_path := DEFAULT_BACKUP_PATH
var test_storage_enabled := false
var _default_profile_existed_before_test := false
var _default_profile_snapshot := PackedByteArray()
const SCHEMA_VERSION := 1
const MAX_BALANCE := 2000000000
const CURRENCIES := ["money", "chips", "gems"]

var balances: Dictionary = {"money": 0, "chips": 0, "gems": 0}
var receipts: Dictionary = {}
var ledger: Array = []
var initialized := false
var _session_user_id := ""
var _session_generation := -1

func _ready() -> void:
	var raw_args := OS.get_cmdline_args()
	var user_args := OS.get_cmdline_user_args()
	var running_wallet_test := raw_args.has("res://tests/wallet_manager_test.gd") or raw_args.has("--script=res://tests/wallet_manager_test.gd")
	if running_wallet_test and not user_args.has("--wallet-test"):
		push_error("Wallet test refused to initialize without its isolated-storage flag.")
		return
	if user_args.has("--wallet-test"):
		_default_profile_existed_before_test = FileAccess.file_exists(DEFAULT_PROFILE_PATH)
		if _default_profile_existed_before_test:
			_default_profile_snapshot = FileAccess.get_file_as_bytes(DEFAULT_PROFILE_PATH)
		var suffix := str(Time.get_ticks_usec())
		profile_path = "user://ci_wallet_fixture_%s.cfg" % suffix
		temp_path = "user://ci_wallet_fixture_%s.wallet.tmp" % suffix
		backup_path = "user://ci_wallet_fixture_%s.backup.cfg" % suffix
		test_storage_enabled = true
		initialize_wallet()
		return
	if not AccountDataSession.session_ready.is_connected(_on_account_session_ready):
		AccountDataSession.session_ready.connect(_on_account_session_ready)
	if not AccountDataSession.session_invalidated.is_connected(_on_account_session_invalidated):
		AccountDataSession.session_invalidated.connect(_on_account_session_invalidated)
	if AccountDataSession.is_ready():
		_on_account_session_ready(AccountDataSession.get_user_id(), AccountDataSession.get_generation(), AccountDataSession.get_profile_path())

func _on_account_session_ready(user_id: String, generation: int, account_profile_path: String) -> void:
	if not AuthManager.is_session_current(user_id, generation) or not AccountDataSession.is_session_current(user_id, generation):
		return
	_session_user_id = user_id
	_session_generation = generation
	profile_path = account_profile_path
	temp_path = account_profile_path + ".tmp"
	backup_path = account_profile_path + ".backup"
	balances = {"money": 0, "chips": 0, "gems": 0}
	receipts = {}
	ledger = []
	initialized = false
	initialize_wallet()

func _on_account_session_invalidated(_previous_user_id: String, _generation: int) -> void:
	initialized = false
	_session_user_id = ""
	_session_generation = -1
	balances = {"money": 0, "chips": 0, "gems": 0}
	receipts = {}
	ledger = []

func _can_access_profile() -> bool:
	if test_storage_enabled:
		return true
	return initialized and AccountDataSession.is_session_current(_session_user_id, _session_generation) and AuthManager.is_session_current(_session_user_id, _session_generation)

func default_profile_unchanged_after_test() -> bool:
	var exists_now := FileAccess.file_exists(DEFAULT_PROFILE_PATH)
	if exists_now != _default_profile_existed_before_test:
		return false
	if not exists_now:
		return true
	return FileAccess.get_file_as_bytes(DEFAULT_PROFILE_PATH) == _default_profile_snapshot

func initialize_wallet() -> bool:
	var config := ConfigFile.new()
	var err := config.load(profile_path)
	if err != OK and FileAccess.file_exists(profile_path):
		push_error("Wallet: profile file is unreadable; wallet initialization stopped.")
		return false

	var stored_version := int(config.get_value("wallet", "schema_version", 0)) if err == OK else 0
	var stored_balances: Variant = config.get_value("wallet", "balances", null) if err == OK else null
	var stored_receipts: Variant = config.get_value("wallet", "receipts", {}) if err == OK else {}
	var stored_ledger: Variant = config.get_value("wallet", "ledger", []) if err == OK else []

	if stored_version == SCHEMA_VERSION and stored_balances is Dictionary:
		for currency in CURRENCIES:
			var value: Variant = stored_balances.get(currency, 0)
			if not _valid_amount(value):
				push_error("Wallet: invalid saved balance; wallet initialization stopped.")
				return false
			balances[currency] = int(value)
		receipts = stored_receipts if stored_receipts is Dictionary else {}
		ledger = stored_ledger if stored_ledger is Array else []
		initialized = true
		return true

	# One-time migration: carry forward existing money/chips exactly; gems start at zero.
	var legacy_money: Variant = config.get_value("profile", "money", 0) if err == OK else 0
	var legacy_chips: Variant = config.get_value("profile", "chips", 0) if err == OK else 0
	if not _valid_amount(legacy_money) or not _valid_amount(legacy_chips):
		push_error("Wallet: legacy balances invalid; migration stopped to protect player data.")
		return false
	balances = {"money": int(legacy_money), "chips": int(legacy_chips), "gems": 0}
	receipts = {}
	ledger = [{
		"transaction_id": "wallet_migration_v1",
		"kind": "migration",
		"money": int(legacy_money),
		"chips": int(legacy_chips),
		"gems": 0,
		"timestamp": Time.get_datetime_string_from_system(true)
	}]
	return _persist_wallet(config)

func get_balance(currency: String) -> int:
	if not _can_access_profile() or not CURRENCIES.has(currency):
		return 0
	_refresh_legacy_balances()
	return int(balances[currency])

func get_balances() -> Dictionary:
	if initialized:
		_refresh_legacy_balances()
	return balances.duplicate(true)

func _refresh_legacy_balances() -> void:
	# المال والرقائق ما زالا يُحدّثان عبر أنظمة اللعبة القديمة؛ اقرأ آخر قيمهما المحفوظة.
	var config := ConfigFile.new()
	if config.load(profile_path) != OK:
		return
	for currency in ["money", "chips"]:
		var value: Variant = config.get_value("profile", currency, balances[currency])
		if _valid_amount(value):
			balances[currency] = int(value)

func save_profile_update(config: ConfigFile, money_value: int, chips_value: int) -> bool:
	# حفظ بيانات اللاعب وتغيير أرصدته وسجل المحفظة في الملف الذري نفسه.
	if not _can_access_profile() or not _valid_amount(money_value) or not _valid_amount(chips_value):
		return false
	var next_balances := balances.duplicate(true)
	var next_ledger := ledger.duplicate(true)
	var timestamp := Time.get_datetime_string_from_system(true)
	for currency in ["money", "chips"]:
		var target := money_value if currency == "money" else chips_value
		var previous := int(next_balances[currency])
		if previous == target:
			continue
		next_ledger.append({
			"transaction_id": "profile_update_%s_%s" % [currency, str(Time.get_ticks_usec())],
			"kind": "profile_update",
			"currency": currency,
			"amount": absi(target - previous),
			"balance_before": previous,
			"balance_after": target,
			"reason": "Saved through the existing player progression flow",
			"timestamp": timestamp
		})
		next_balances[currency] = target
	config.set_value("profile", "money", money_value)
	config.set_value("profile", "chips", chips_value)
	config.set_value("wallet", "schema_version", SCHEMA_VERSION)
	config.set_value("wallet", "balances", next_balances)
	config.set_value("wallet", "receipts", receipts)
	config.set_value("wallet", "ledger", next_ledger)
	if not _atomic_save(config):
		return false
	balances = next_balances
	ledger = next_ledger
	return true

func get_recent_transactions(limit: int = 5) -> Array:
	var result: Array = []
	var count := mini(maxi(limit, 0), 20)
	for index in range(ledger.size() - 1, maxi(ledger.size() - count - 1, -1), -1):
		result.append(ledger[index].duplicate(true))
	return result

func has_transaction(transaction_id: String) -> bool:
	return receipts.has(transaction_id)

func purchase_once(transaction_id: String, currency: String, amount: int, reason: String, profile_updates: Dictionary = {}) -> bool:
	# يطبق الخصم وتحديث الملكية/الإيصال في الملف نفسه؛ لا توجد ملكية دون خصم ناجح.
	if not _can_access_profile() or transaction_id.strip_edges().is_empty() or not CURRENCIES.has(currency):
		return false
	if amount < 0 or amount > MAX_BALANCE or receipts.has(transaction_id):
		return false
	var config := ConfigFile.new()
	if config.load(profile_path) != OK:
		return false
	_refresh_legacy_balances()
	var current := int(balances[currency])
	if current < amount:
		return false
	var next_value := current - amount
	var next_balances := balances.duplicate(true)
	next_balances[currency] = next_value
	var next_receipts := receipts.duplicate(true)
	var timestamp := Time.get_datetime_string_from_system(true)
	next_receipts[transaction_id] = timestamp
	var next_ledger := ledger.duplicate(true)
	next_ledger.append({
		"transaction_id": transaction_id,
		"kind": "purchase",
		"currency": currency,
		"amount": amount,
		"balance_before": current,
		"balance_after": next_value,
		"reason": reason.substr(0, 120),
		"timestamp": timestamp
	})
	for key in profile_updates:
		config.set_value("profile", str(key), profile_updates[key])
	if currency == "money" or currency == "chips":
		config.set_value("profile", currency, next_value)
	config.set_value("wallet", "schema_version", SCHEMA_VERSION)
	config.set_value("wallet", "balances", next_balances)
	config.set_value("wallet", "receipts", next_receipts)
	config.set_value("wallet", "ledger", next_ledger)
	if not _atomic_save(config):
		return false
	balances = next_balances
	receipts = next_receipts
	ledger = next_ledger
	return true

func credit(transaction_id: String, currency: String, amount: int, reason: String = "") -> bool:
	return _transact(transaction_id, currency, amount, "credit", reason)

func debit(transaction_id: String, currency: String, amount: int, reason: String = "") -> bool:
	return _transact(transaction_id, currency, amount, "debit", reason)

func _transact(transaction_id: String, currency: String, amount: int, kind: String, reason: String) -> bool:
	if not _can_access_profile() or transaction_id.strip_edges().is_empty() or not CURRENCIES.has(currency):
		return false
	if amount <= 0 or amount > MAX_BALANCE or receipts.has(transaction_id):
		return false
	var config := ConfigFile.new()
	if config.load(profile_path) != OK:
		return false
	_refresh_legacy_balances()
	var current := int(balances[currency])
	if kind == "debit" and current < amount:
		return false
	var next_value := current + amount if kind == "credit" else current - amount
	if next_value < 0 or next_value > MAX_BALANCE:
		return false

	var next_balances := balances.duplicate(true)
	next_balances[currency] = next_value
	var next_receipts := receipts.duplicate(true)
	var timestamp := Time.get_datetime_string_from_system(true)
	next_receipts[transaction_id] = timestamp
	var next_ledger := ledger.duplicate(true)
	next_ledger.append({
		"transaction_id": transaction_id,
		"kind": kind,
		"currency": currency,
		"amount": amount,
		"balance_before": current,
		"balance_after": next_value,
		"reason": reason.substr(0, 120),
		"timestamp": timestamp
	})
	if currency == "money" or currency == "chips":
		config.set_value("profile", currency, next_value)
	config.set_value("wallet", "schema_version", SCHEMA_VERSION)
	config.set_value("wallet", "balances", next_balances)
	config.set_value("wallet", "receipts", next_receipts)
	config.set_value("wallet", "ledger", next_ledger)
	if not _atomic_save(config):
		return false
	balances = next_balances
	receipts = next_receipts
	ledger = next_ledger
	return true

func _persist_wallet(config: ConfigFile) -> bool:
	config.set_value("wallet", "schema_version", SCHEMA_VERSION)
	config.set_value("wallet", "balances", balances)
	config.set_value("wallet", "receipts", receipts)
	config.set_value("wallet", "ledger", ledger)
	if not _atomic_save(config):
		return false
	initialized = true
	return true

func _atomic_save(config: ConfigFile) -> bool:
	if config.save(temp_path) != OK:
		return false
	var original_exists := FileAccess.file_exists(profile_path)
	if original_exists and not FileAccess.file_exists(backup_path):
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(profile_path), ProjectSettings.globalize_path(backup_path)) != OK:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
			return false
	var original_path := ProjectSettings.globalize_path(profile_path)
	var temp_path := ProjectSettings.globalize_path(temp_path)
	var backup_path := ProjectSettings.globalize_path(backup_path)
	if original_exists:
		var rotate_error := DirAccess.rename_absolute(original_path, backup_path + ".pending")
		if rotate_error != OK:
			DirAccess.remove_absolute(temp_path)
			return false
		var install_error := DirAccess.rename_absolute(temp_path, original_path)
		if install_error != OK:
			DirAccess.rename_absolute(backup_path + ".pending", original_path)
			return false
		DirAccess.remove_absolute(backup_path + ".pending")
	else:
		if DirAccess.rename_absolute(temp_path, original_path) != OK:
			DirAccess.remove_absolute(temp_path)
			return false
	return true

func _valid_amount(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0 and float(value) <= float(MAX_BALANCE) and floorf(float(value)) == float(value)
