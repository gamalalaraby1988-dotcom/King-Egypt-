extends Node
## خدمة محفظة محلية موحدة. الخادم الموثوق مطلوب لحماية اقتصاد اللعب الجماعي.

const PROFILE_PATH := "user://kings_city_profile.cfg"
const TEMP_PATH := "user://kings_city_profile.wallet.tmp"
const BACKUP_PATH := "user://kings_city_profile.pre_wallet_backup.cfg"
const SCHEMA_VERSION := 1
const MAX_BALANCE := 2000000000
const CURRENCIES := ["money", "chips", "gems"]

var balances: Dictionary = {"money": 0, "chips": 0, "gems": 0}
var receipts: Dictionary = {}
var ledger: Array = []
var initialized := false

func _ready() -> void:
	initialize_wallet()

func initialize_wallet() -> bool:
	var config := ConfigFile.new()
	var err := config.load(PROFILE_PATH)
	if err != OK and FileAccess.file_exists(PROFILE_PATH):
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
	if not initialized or not CURRENCIES.has(currency):
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
	if config.load(PROFILE_PATH) != OK:
		return
	for currency in ["money", "chips"]:
		var value: Variant = config.get_value("profile", currency, balances[currency])
		if _valid_amount(value):
			balances[currency] = int(value)

func save_profile_update(config: ConfigFile, money_value: int, chips_value: int) -> bool:
	# حفظ بيانات اللاعب وتغيير أرصدته وسجل المحفظة في الملف الذري نفسه.
	if not initialized or not _valid_amount(money_value) or not _valid_amount(chips_value):
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

func has_transaction(transaction_id: String) -> bool:
	return receipts.has(transaction_id)

func credit(transaction_id: String, currency: String, amount: int, reason: String = "") -> bool:
	return _transact(transaction_id, currency, amount, "credit", reason)

func debit(transaction_id: String, currency: String, amount: int, reason: String = "") -> bool:
	return _transact(transaction_id, currency, amount, "debit", reason)

func _transact(transaction_id: String, currency: String, amount: int, kind: String, reason: String) -> bool:
	if not initialized or transaction_id.strip_edges().is_empty() or not CURRENCIES.has(currency):
		return false
	if amount <= 0 or amount > MAX_BALANCE or receipts.has(transaction_id):
		return false
	var config := ConfigFile.new()
	if config.load(PROFILE_PATH) != OK:
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
	if config.save(TEMP_PATH) != OK:
		return false
	var original_exists := FileAccess.file_exists(PROFILE_PATH)
	if original_exists and not FileAccess.file_exists(BACKUP_PATH):
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(PROFILE_PATH), ProjectSettings.globalize_path(BACKUP_PATH)) != OK:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))
			return false
	var original_path := ProjectSettings.globalize_path(PROFILE_PATH)
	var temp_path := ProjectSettings.globalize_path(TEMP_PATH)
	var backup_path := ProjectSettings.globalize_path(BACKUP_PATH)
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
